"""Real 0.2 MCP workflow tests; the private fixture only supplies controlled faults/host grants."""
import pathlib,sys,json,time,uuid
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client,ROOT
c=Client();checks=[];builds=[]
data=pathlib.Path(r'D:\Steam\steamapps\common\GarrysMod\garrysmod\data\sandbox_mcp_workflow_test')
def check(name,condition):
    assert condition,name
    checks.append(name);print('PASS',name,flush=True)
def fail(name,tool,args,fragment):
    try:c.call(tool,args)
    except RuntimeError as e:check(name,fragment.lower() in str(e).lower())
    else:raise AssertionError(name)
def fixture(action,**args):
    data.mkdir(parents=True,exist_ok=True);ident=uuid.uuid4().hex
    (data/'request.json').write_text(json.dumps(dict(id=ident,action=action,**args)),encoding='utf-8')
    until=time.time()+8
    while time.time()<until:
        try:
            r=json.loads((data/'response.json').read_text())
            if r['id']==ident:
                assert r['ok'],r
                time.sleep(.2)
                return r['result']
        except (FileNotFoundError,json.JSONDecodeError):pass
        time.sleep(.05)
    raise RuntimeError('Private fixture timeout')
def refs(result):return {e['label']:e['ref'] for e in result['entities']}
def create(args):
    r=c.call('sandbox_create',args);builds.append(r['build_id']);return r
def wire(ref):return c.call('sandbox_wire_ports',{'refs':[ref]})['entities'][0]
def val(ref,port='Out'):return next(p['value'] for p in wire(ref)['outputs'] if p['name']==port)
def link(fr,out,to,inp):return dict(**{'from':fr},output=out,to=to,input=inp)
try:
    models=c.call('sandbox_catalog',{'shape':'plate','physics_only':True,'min_size':[40,40,0],'max_size':[300,300,50],'limit':10})
    check('Asset filters return bounded physics plates',len(models['items'])>0 and all('plate' in x['model'] and 40<=x['size'][0]<=300 and 40<=x['size'][1]<=300 and x['size'][2]<=50 for x in models['items']))
    base={'name':'0.2 circuit','origin':[300,300,-80],'entities':[
      {'label':'source','kind':'wire','preset':'constant','settings':{'value':3}},
      {'label':'sum','kind':'wire','preset':'gate','settings':{'action':'+'},'pos':[55,0,0]},
      {'label':'lamp','kind':'wire','preset':'indicator','pos':[100,0,0]}],
      'links':[{'kind':'weld','a':'source','b':'sum'},{'kind':'weld','a':'sum','b':'lamp'}],
      'wire_links':[link('source','1','sum','A'),link('sum','Out','lamp','A')]}
    bad=json.loads(json.dumps(base));bad['wire_links'][1]['input']='MissingPort'
    before=c.call('sandbox_inspect',{'owned_only':True})['total']
    fail('Create with invalid circuit rolls back all parts','sandbox_create',bad,'rolled back')
    check('Failed circuit creation leaves no parts',c.call('sandbox_inspect',{'owned_only':True})['total']==before)
    b=create(base);r=refs(b)
    check('Create complete circuit atomically',val(r['sum'])==3)
    c.call('sandbox_wire_set',{'ref':r['source'],'value':.4})
    c.call('sandbox_blueprint',{'action':'save','build_id':b['build_id'],'name':'workflow_roundtrip','overwrite':True})
    exported=c.call('sandbox_blueprint',{'action':'export','name':'workflow_roundtrip'})['blueprint']
    check('Blueprint retains live source and both connection types',exported['entities'][0]['settings']['value']==.4 and len(exported['links'])==2 and len(exported['wire_links'])==2)
    c.call('sandbox_blueprint',{'action':'import','name':'workflow_import','blueprint':exported,'overwrite':True})
    loaded=c.call('sandbox_blueprint',{'action':'load','name':'workflow_import','origin':[300,550,-80],'angles':[0,90,0]});builds.append(loaded['build_id']);lr=refs(loaded)
    check('Imported blueprint restores functioning wires',abs(val(lr['sum'])-.4)<1e-6)
    check('Blueprint rotation preserves relative layout',abs(loaded['entities'][1]['pos'][1]-loaded['entities'][0]['pos'][1]-55)<.1)
    fail('Blueprint names cannot escape DATA','sandbox_blueprint',{'action':'load','name':'../config'},'Name must')
    fail('Saving requires explicit overwrite','sandbox_blueprint',{'action':'save','name':'workflow_roundtrip','build_id':b['build_id']},'already exists')
    c.call('sandbox_checkpoint',{'action':'save','name':'working','build_id':b['build_id']})
    c.call('sandbox_wire_set',{'ref':r['source'],'value':.9})
    restored=c.call('sandbox_checkpoint',{'action':'restore','name':'working'});builds.remove(b['build_id']);builds.append(restored['build_id']);r=refs(restored)
    check('Checkpoint replaces build and restores original circuit',restored['build_id']!=b['build_id'] and abs(val(r['sum'])-.4)<1e-6)
    batch=create({'name':'Batch failure test','origin':[700,300,-80],'entities':[{'label':n,'kind':'wire','preset':'gate','settings':{'action':'+'},'pos':[i*45,0,0]} for i,n in enumerate(['a','b','c'])]});br=refs(batch)
    fail('Proposed batch cycles rejected without partial wiring','sandbox_wire_batch',{'links':[link(br['a'],'Out',br['b'],'A'),link(br['b'],'Out',br['a'],'A')]},'cycle')
    check('Cycle left destination disconnected',not wire(br['b'])['inputs'][0].get('source'))
    fixture('fail_wire')
    fail('Runtime link failure rolls back earlier links','sandbox_wire_batch',{'links':[link(br['a'],'Out',br['b'],'A'),link(br['a'],'Out',br['c'],'A')]},'rolled back')
    check('Rollback restores all input sources',all(not p.get('source') for n in ['b','c'] for p in wire(br[n])['inputs']))
    linked=c.call('sandbox_wire_batch',{'links':[link(br['a'],'Out',br['b'],'A'),link(br['b'],'Out',br['c'],'A')]})
    c.call('sandbox_undo',{'operation_id':linked['operation_id']})
    check('One undo reverses entire Wire batch',all(not p.get('source') for n in ['b','c'] for p in wire(br[n])['inputs']))
    moved=c.call('sandbox_transform',{'build_id':restored['build_id'],'translation':[50,0,30],'rotation':[0,90,0]})
    check('Group transform preserves spacing',abs(moved['entities'][1]['pos'][1]-moved['entities'][0]['pos'][1]-55)<.1)
    c.call('sandbox_undo',{'operation_id':moved['operation_id']})
    aligned=c.call('sandbox_align',{'refs':[br['a']],'target':br['b'],'axis':'z','face':'max','gap':5})
    check('Alignment provides requested clearance',aligned['entities'][0]['bounds']['min'][2]>-80)
    c.call('sandbox_undo',{'operation_id':aligned['operation_id']})
    measured=c.call('sandbox_measure',{'refs':[r['source'],r['sum']],'seconds':.6,'interval':.1})
    check('Time-series captures actual Wire signals',len(measured['samples'])>=4 and abs(measured['samples'][-1]['entities'][1]['outputs']['Out']-.4)<1e-6)
    diag=c.call('sandbox_diagnose',{'build_id':restored['build_id']})
    check('Diagnostics report frozen parts and unused inputs',diag['frozen_parts']==3 and any(x['kind']=='unconnected_input' for x in diag['issues']))
    fixture('permissions',e2=False)
    code='@name MCP controller\n@inputs A\n@outputs Out\nOut = A * 2'
    check('E2 validation reports syntax errors',not c.call('sandbox_e2',{'action':'validate','code':'@outputs Out\nOut = ('})['valid'])
    fail('E2 creation requires separate host permission','sandbox_create',{'name':'Denied E2','entities':[{'label':'chip','kind':'wire','preset':'expression2','settings':{'code':code}}]},'Expression 2 is off')
    fixture('permissions',e2=True)
    e2=create({'name':'E2 native test','origin':[500,700,-80],'entities':[{'label':'source','kind':'wire','preset':'constant','settings':{'value':4}},{'label':'chip','kind':'wire','preset':'expression2','settings':{'code':code},'pos':[50,0,0]}],'wire_links':[link('source','1','chip','A')]});er=refs(e2)
    check('E2 creation compiles stopped',c.call('sandbox_e2',{'action':'status','ref':er['chip']})['paused'])
    running=c.call('sandbox_e2',{'action':'run','ref':er['chip']})
    check('E2 executes through real Wire input',running['running'] and val(er['chip'])==8)
    bad=c.call('sandbox_e2',{'action':'upload','ref':er['chip'],'code':'@outputs Out\nOut = ('})
    check('Bad E2 upload preserves working program',not bad['valid'] and val(er['chip'])==8)
    update=c.call('sandbox_e2',{'action':'upload','ref':er['chip'],'code':code.replace('* 2','* 3')})
    check('Valid E2 upload stays stopped',update['paused'])
    c.call('sandbox_e2',{'action':'run','ref':er['chip']})
    check('E2 revision uses existing Wire connection',val(er['chip'])==12)
    c.call('sandbox_undo',{'operation_id':update['operation_id']})
    c.call('sandbox_e2',{'action':'run','ref':er['chip']})
    check('E2 code undo restores behavior',val(er['chip'])==8)
    fail('Wired E2 interface change is refused','sandbox_e2',{'action':'upload','ref':er['chip'],'code':'@inputs Different\n@outputs Out\nOut = Different'},'Disconnect')
    stopped=c.call('sandbox_e2',{'action':'stop','ref':er['chip']})
    check('Stopping E2 clears output signals',stopped['paused'] and val(er['chip'])==0)
    manual=fixture('manual')
    fail('Manual props protected before handoff','sandbox_edit',{'items':[{'ref':manual['refs'][0],'color':[1,2,3]}]},'AI-created')
    grant=fixture('grant')
    granted=c.call('sandbox_blueprint',{'action':'export','build_id':grant['build_id']})['blueprint']
    check('Granted native weld exports without changing its settings',len(granted['entities'])==2 and len(granted['links'])==1)
    edit=c.call('sandbox_edit',{'items':[{'ref':manual['refs'][0],'color':[20,90,150]}]})
    check('Explicit host grant allows targeted edits',edit['entities'][0]['color']==[20,90,150])
    fixture('revoke')
    fail('Revocation blocks new edits','sandbox_edit',{'items':[{'ref':manual['refs'][0],'color':[1,2,3]}]},'AI-created')
    fail('Revocation also blocks historical undo','sandbox_undo',{'operation_id':edit['operation_id']},'revoked')
    fixture('cleanup')
    print(json.dumps({'passed':len(checks)},indent=2))
finally:
    for bid in builds:
        try:c.call('sandbox_cleanup',{'build_id':bid})
        except RuntimeError:pass
    (ROOT/'artifacts/workflow-evaluation.json').write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8',newline='\n')
    c.close()
