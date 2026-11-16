"""Private fixture supplies external changes; all adapter mutations use real MCP."""
import json,pathlib,sys,time
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client,ROOT
DATA=pathlib.Path(r'D:\Steam\steamapps\common\GarrysMod\garrysmod\data\sandbox_mcp_fin3_test')
def fixture(action,**args):
    DATA.mkdir(exist_ok=True);a=dict(action=action,id=str(time.time_ns()),**args)
    (DATA/'request.json').write_text(json.dumps(a),encoding='utf-8')
    until=time.monotonic()+8
    while time.monotonic()<until:
        try:
            r=json.loads((DATA/'response.json').read_text(encoding='utf-8'))
            if r['id']==a['id']:
                assert r['ok'],r
                return r['result']
        except (FileNotFoundError,json.JSONDecodeError):pass
        time.sleep(.05)
    raise RuntimeError('Private fixture not responding')
if __name__=='__main__':
    c=Client(exe=ROOT/'target/release/sandbox-mcp.exe');checks=[];build=None
    def check(n,v):assert v,n;checks.append(n);print('PASS',n,flush=True)
    def fail(n,tool,args,text):
        try:c.call(tool,args)
        except RuntimeError as ex:check(n,text.lower() in str(ex).lower())
        else:raise AssertionError(n)
    def settings(r):return c.call('sandbox_fin3_inspect',{'refs':[r]})['entities'][0].get('settings')
    try:
        base=fixture('stats')
        build=c.call('sandbox_create',{'name':'Fin boundary checks','origin':[500,100,200],'entities':[{'label':str(i),'model':'models/hunter/plates/plate1x2.mdl','pos':[0,i*160,0]} for i in range(2)]})
        a,b=[e['ref'] for e in build['entities']];physical=fixture('stats',ref=a)['physics']
        item={'ref':a,'fin3':{'kind':'fin','camber':20}}
        fixture('deny',enabled=True)
        fail('Server CanTool respected','sandbox_fin3_apply',{'items':[item]},'denied')
        fixture('deny',enabled=False)
        fixture('fail_once')
        fail('Native second-part failure reported','sandbox_fin3_apply',{'items':[item,{'ref':b,'fin3':{'kind':'fin'}}]},'rolled back')
        check('Native failure restores both modifiers',settings(a) is None and settings(b) is None)
        check('Rollback restores Fin 3 quota accounting',fixture('stats')==base)
        check('Rollback restores drag and damping',fixture('stats',ref=a)['physics']==physical)
        op=c.call('sandbox_fin3_apply',{'items':[item]})
        fixture('manual_camber',ref=a,camber=50)
        fail('Manual camber change blocks stale undo','sandbox_undo',{'operation_id':op['operation_id']},'changed')
        fixture('manual_camber',ref=a,camber=20)
        c.call('sandbox_undo',{'operation_id':op['operation_id']})
        check('Fin undo restores original drag and damping',fixture('stats',ref=a)['physics']==physical)
        op=c.call('sandbox_fin3_apply',{'items':[{'ref':a,'fin3':{'kind':'propeller'}}]})
        c.call('sandbox_undo',{'operation_id':op['operation_id']})
        check('Propeller undo restores original drag and damping',fixture('stats',ref=a)['physics']==physical)
        fixture('parent',ref=a,to=b)
        fail('Parent physics outside edit scope rejected','sandbox_fin3_apply',{'items':[item]},'Unparent')
        fixture('parent',ref=a)
        check('Undo and failed edits leave quota unchanged',fixture('stats')==base)
    finally:
        fixture('deny',enabled=False)
        if build:c.call('sandbox_cleanup',{'build_id':build['build_id']})
        (ROOT/'artifacts/fin3-boundary-evaluation.json').write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8');c.close()
