"""Fault/permission fixture changes external conditions; mutations use MCP."""
import json,pathlib,sys,time
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client,ROOT
DATA=pathlib.Path(r'D:\Steam\steamapps\common\GarrysMod\garrysmod\data\sandbox_mcp_flowmod_test')
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
    raise RuntimeError('Private boundary fixture not responding')
c=Client();checks=[];b=None
def check(n,v):assert v,n;checks.append(n);print('PASS',n,flush=True)
def fail(n,tool,args,text):
    try:c.call(tool,args)
    except RuntimeError as e:check(n,text.lower() in str(e).lower())
    else:raise AssertionError(n)
def read(r):return c.call('sandbox_flowmod_inspect',{'refs':[r]})['entities'][0]
try:
    b=c.call('sandbox_create',{'name':'Flow permission checks','origin':[400,500,-100],'entities':[
        {'label':'pump','kind':'flowmod','flowmod':{'kind':'pump'}},
        {'label':'tank','kind':'flowmod','pos':[80,0,0],'flowmod':{'kind':'reservoir'}}]})
    r,t=[e['ref'] for e in b['entities']]
    fixture('deny')
    fail('Server CanTool denies tuning','sandbox_flowmod_tune',{'ref':r,'control':1},'denied')
    fail('Server CanTool denies connecting fluid ports','sandbox_flowmod_connect',{'links':[dict(a=r,port_a='T',b=t,port_b='T')]},'denied')
    fixture('clear');fixture('deny_spawn')
    fail('Server SENT permission denies spawning','sandbox_create',{'name':'Denied part','origin':[400,500,-100],'entities':[{'label':'p','kind':'flowmod','flowmod':{'kind':'pump'}}]},'not permitted')
    fixture('clear');fixture('fail_control')
    fail('Native error rolls back config and command','sandbox_flowmod_tune',{'ref':r,'settings':{'pressure':80},'control':1},'rolled back')
    state=read(r)
    check('Failed command leaves prior pressure and OFF state',state['settings']['pressure']==60 and state['control']==0 and state['state']=='OFF')
    op=c.call('sandbox_flowmod_tune',{'ref':r,'settings':{'pressure':80},'control':1})
    fixture('manual',ref=r,pressure=90)
    fail('Manual tool changes protect against stale undo','sandbox_undo',{'operation_id':op['operation_id']},'changed later')
    fixture('manual',ref=r,pressure=80);fixture('fail_control')
    fail('Undo failure rolls back its partial native changes','sandbox_undo',{'operation_id':op['operation_id']},'rolled back')
    check('Failed undo retains the applied state',read(r)['settings']['pressure']==80 and read(r)['control']==1)
    c.call('sandbox_undo',{'operation_id':op['operation_id']})
    check('Retry after native recovery restores original state',read(r)['settings']['pressure']==60 and read(r)['control']==0)
    fixture('pause',ref=r);time.sleep(.2)
    state=read(r)
    check('MCP telemetry reports native assembly pause',state['paused'] and 'paused' in state['fault'].lower() and all(p['flow_lpm']==0 for p in state['ports']))
    diagnosis=c.call('sandbox_diagnose',{'build_id':b['build_id']})
    check('Diagnosis surfaces the paused fluid assembly',any(i['kind']=='flowmod_fault' for i in diagnosis['issues']))
    fixture('repair');time.sleep(.2)
    check('MCP telemetry clears pause after native recovery',not read(r)['paused'])
finally:
    fixture('clear')
    if b:c.call('sandbox_cleanup',{'build_id':b['build_id']})
    (ROOT/'artifacts/flowmod-boundary-evaluation.json').write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8');c.close()
