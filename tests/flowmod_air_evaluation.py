"""Real pneumatic circuit, limits and portable-import boundaries through MCP."""
import json,pathlib,sys,copy,time
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client,ROOT
c=Client();checks=[];builds=[]
def check(name,condition):
    assert condition,name
    checks.append(name); print('PASS',name,flush=True)
def fail(name,tool,args,fragment):
    try:c.call(tool,args)
    except RuntimeError as e:check(name,fragment.lower() in str(e).lower())
    else:raise AssertionError(name)
def part(label,kind,pos,**settings):return dict(label=label,kind='flowmod',pos=pos,flowmod=dict(kind=kind,medium='air',**settings))
def hose(a,pa,b,pb):return dict(a=a,port_a=pa,b=b,port_b=pb)
def read(ref):return c.call('sandbox_flowmod_inspect',{'refs':[ref]})['entities'][0]
def tune(ref,**args):return c.call('sandbox_flowmod_tune',dict(ref=ref,**args))
def count():return c.call('sandbox_inspect',{'owned_only':True,'limit':1})['total']
def create(spec):
    b=c.call('sandbox_create',spec);builds.append(b['build_id']);return b
spec=dict(name='MCP stored air lift',origin=[400,500,-125],entities=[
    dict(label='base',model='models/hunter/plates/plate1x1.mdl',pos=[0,0,0]),
    dict(label='load',model='models/hunter/plates/plate1x1.mdl',pos=[0,0,110],mass=20),
    part('compressor','compressor',[-130,80,12],pressure=8,flow=120),part('tank','airtank',[-130,0,0],volume=2),
    part('valve','valve',[-130,160,12],opening=.8),part('exhaust','exhaust',[-240,160,12]),
    part('cylinder','cylinder',[0,0,12],bore=50,stroke=80,anchors=dict(a='base',b='load',minimum=70))],
    links=[dict(kind='nocollide',a='base',b='load')],fluid_links=[hose('compressor','P','tank','IN'),hose('tank','OUT','valve','P'),hose('valve','T','exhaust','IN'),hose('valve','A','cylinder','A'),hose('valve','B','cylinder','B')])
try:
    b=create(copy.deepcopy(spec));r={e['label']:e['ref'] for e in b['entities']}
    check('Air circuit uses real air components',all(e['flowmod']['medium']=='air' for e in b['entities'] if 'flowmod' in e))
    fail('Partial anchor blueprint refuses external controller','sandbox_blueprint',{'action':'export','refs':[r['base']]},'connection leaves')
    temporary=c.call('sandbox_flowmod_connect',{'links':[hose(r['tank'],'AUX',r['exhaust'],'A')]})
    removed=c.call('sandbox_flowmod_disconnect',{'ref':temporary['hoses'][0]['ref']})
    fail('Stale hose undo reports replacement instead of silent success','sandbox_undo',{'operation_id':temporary['operation_id']},'removed or replaced')
    c.call('sandbox_undo',{'operation_id':removed['operation_id']})
    port=next(p for p in read(r['tank'])['ports'] if p['name']=='AUX')
    check('Disconnect undo restores its logical fluid connection',port['connected_to']['ref']==r['exhaust'])
    c.call('sandbox_flowmod_disconnect',{'ref':port['hose']})
    before=count()
    bad=copy.deepcopy(spec);bad['entities'][2]['flowmod']['pressure']=21
    fail('Air pressure limit validated before spawn','sandbox_create',bad,'range')
    bad=copy.deepcopy(spec);bad['entities'][2]['flowmod']['execute']='anything'
    fail('Unknown fluid settings rejected','sandbox_create',bad,'unsupported')
    bad=copy.deepcopy(spec);bad['entities'][6]['flowmod']['anchors']['point_a']=[0,0,999999]
    fail('Unbounded anchors rejected','sandbox_create',bad,'range')
    check('Invalid creations leave no new parts',count()==before)
    tune(r['compressor'],control=1)
    deadline=time.monotonic()+9
    while read(r['tank'])['ports'][0]['pressure_bar']<3 and time.monotonic()<deadline:time.sleep(.25)
    tune(r['compressor'],control=0)
    tank=read(r['tank'])
    check('Native compressor stores compressed air',tank['ports'][0]['pressure_bar']>=3 and tank['stored_air_standard_litres']>=8)
    fail('Pressurised tank cannot be shrunk unsafely','sandbox_flowmod_tune',{'ref':r['tank'],'settings':{'volume':.1}},'Vent')
    check('Rejected tank resize preserves original capacity',read(r['tank'])['settings']['volume']==2)
    tune(r['valve'],control=1)
    c.call('sandbox_edit',{'items':[{'ref':r['load'],'frozen':False}]})
    measure=c.call('sandbox_measure',{'refs':[r['load'],r['cylinder'],r['tank']],'seconds':2,'interval':.1})
    z=[row['entities'][0]['pos'][2] for row in measure['samples']]
    check('Stored air lifts a real load with compressor off',max(z)-min(z)>8 and read(r['compressor'])['control']==0)
    check('Stored gas decreases while doing mechanical work',read(r['tank'])['stored_air_standard_litres']<tank['stored_air_standard_litres'])
    (ROOT/'artifacts/flowmod-air-motion.json').write_text(json.dumps(measure,indent=2),encoding='utf-8')
    tune(r['valve'],control=0);c.call('sandbox_edit',{'items':[{'ref':r['load'],'frozen':True}]})
    data=c.call('sandbox_blueprint',{'action':'export','build_id':b['build_id']})['blueprint']
    bad=copy.deepcopy(data);bad['entities'][6]['flowmod']['anchors']['a']=r['base']
    c.call('sandbox_blueprint',{'action':'import','name':'flowmod-invalid-anchor-test','blueprint':bad,'overwrite':True})
    before=count()
    fail('Imported anchors cannot reconnect to old map refs','sandbox_blueprint',{'action':'load','name':'flowmod-invalid-anchor-test','origin':[750,400,-125]},'unknown anchor')
    check('Invalid import rolls back all spawned parts',count()==before)
    too_many=copy.deepcopy(data);too_many['fluid_links']*=26
    fail('Imported fluid links have a bounded count','sandbox_blueprint',{'action':'import','name':'flowmod-too-many-test','blueprint':too_many,'overwrite':True},'limits')
    # FlowMod's per-player quota applies equally to MCP-created parts.
    limit=c.call('sandbox_catalog',{'kind':'flowmod'})['limits']['parts_per_player']
    quota=dict(name='Quota rollback',origin=[700,500,-100],entities=[part('g'+str(i),'gauge',[0,0,0]) for i in range(limit)])
    fail('MCP creation respects FlowMod per-player quota','sandbox_create',quota,'limit reached')
    check('Quota failure leaves no partial machine',count()==before)
    diagnostic=c.call('sandbox_diagnose',{'build_id':b['build_id']})
    check('Diagnostics include actual fluid settings',sum('flowmod' in x for x in diagnostic['parts'])==5)
    print(json.dumps({'passed':len(checks),'checks':checks},indent=2))
finally:
    for bid in reversed(builds):
        try:c.call('sandbox_cleanup',{'build_id':bid})
        except RuntimeError as e:print('Cleanup failed',bid,e)
    (ROOT/'artifacts/flowmod-air-evaluation.json').write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8');c.close()
