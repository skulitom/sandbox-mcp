"""Actual FlowMod + Wiremod through MCP stdio. No direct game-file mutations."""
import json, pathlib, sys, time, copy
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client, ROOT
c=Client(); checks=[]; builds=[]
def check(name,condition):
    assert condition,name
    checks.append(name); print('PASS',name,flush=True)
def fail(name,tool,args,fragment):
    try:c.call(tool,args)
    except RuntimeError as e:check(name,fragment.lower() in str(e).lower())
    else:raise AssertionError(name)
def inspect(ref):return c.call('sandbox_flowmod_inspect',{'refs':[ref]})['entities'][0]
def tune(ref,**args):return c.call('sandbox_flowmod_tune',dict(ref=ref,**args))
def undo(op):return c.call('sandbox_undo',{'operation_id':op['operation_id']})
def count():return c.call('sandbox_inspect',{'owned_only':True,'limit':1})['total']
def create(spec):
    b=c.call('sandbox_create',spec); builds.append(b['build_id']); return b
def fluid(a,pa,b,pb):return dict(a=a,port_a=pa,b=b,port_b=pb)
def part(label,kind,pos,**settings):return dict(label=label,kind='flowmod',pos=pos,flowmod=dict(kind=kind,**settings))
spec={'name':'MCP hydraulic lift','origin':[400,500,-125], 'entities':[
    dict(label='base',model='models/hunter/plates/plate1x1.mdl',pos=[0,0,0]),
    dict(label='load',model='models/hunter/plates/plate1x1.mdl',pos=[0,0,110],mass=100),
    part('reservoir','reservoir',[-130,0,0]),part('pump','pump',[-130,80,12],pressure=40,flow=12),
    part('valve','valve',[-130,160,12],opening=.12),
    part('cylinder','cylinder',[0,0,12],bore=40,stroke=80,anchors=dict(a='base',b='load',minimum=70)),
    dict(label='switch',kind='wire',preset='constant',pos=[-200,80,60],settings={'value':0}),
    dict(label='screen',kind='wire',preset='screen',pos=[-200,160,60])],
    'links':[dict(kind='nocollide',a='base',b='load')],
    'fluid_links':[fluid('reservoir','T','pump','T'),fluid('pump','P','valve','P'),fluid('valve','T','reservoir','R1'),fluid('valve','A','cylinder','A'),fluid('valve','B','cylinder','B')]}
try:
    cat=c.call('sandbox_catalog',{'kind':'flowmod'})
    check('Native optional adapter discovers twelve component kinds',cat['installed'] and len(cat['items'])==12)
    b=create(copy.deepcopy(spec));r={e['label']:e['ref'] for e in b['entities']}
    check('One atomic batch creates props fluid parts and Wire parts',len(b['entities'])==8 and b['connections']==6)
    check('Pump starts off and valve holds',inspect(r['pump'])['control']==0 and inspect(r['valve'])['control']==0)
    cyl=inspect(r['cylinder'])
    check('Cylinder anchors resolve stable created prop refs',cyl['anchors']['a']['ref']==r['base'] and cyl['anchors']['b']['ref']==r['load'])
    check('Five real fluid hoses attach exact named ports',sum('hose' in p for e in c.call('sandbox_flowmod_inspect',{'build_id':b['build_id']})['entities'] for p in e['ports'])==10)
    op=tune(r['pump'],settings={'pressure':50})
    later=tune(r['pump'],settings={'pressure':60})
    fail('Stale tuning undo refuses later changes','sandbox_undo',{'operation_id':op['operation_id']},'changed later')
    undo(later);undo(op)
    check('Sequential targeted undo restores original settings',inspect(r['pump'])['settings']['pressure']==40)
    fail('Unknown tuning field refused','sandbox_flowmod_tune',{'ref':r['pump'],'settings':{'bore':80}},'unsupported')
    fail('Read-only player cannot be tuned','sandbox_flowmod_tune',{'ref':c.call('sandbox_inspect',{'limit':1})['entities'][0]['ref'],'control':1},'AI-created')
    fail('Old instance refs refused','sandbox_flowmod_tune',{'ref':'deadbeef:1:1','control':1},'previous')
    before=count()
    bad=copy.deepcopy(spec);bad['name']='Invalid oil air mix';bad['entities'][4]['flowmod']['medium']='air'
    fail('Mixed-medium create rejected atomically','sandbox_create',bad,'cannot be connected')
    check('Failed create leaves no tracked parts',count()==before)
    bad=copy.deepcopy(spec);bad['entities'][5]['flowmod']['anchors']['b']='missing'
    fail('Unknown anchor create rolls back','sandbox_create',bad,'unknown anchor')
    check('Anchor failure leaves no tracked parts',count()==before)
    fail('Occupied fluid port refuses a new link','sandbox_flowmod_connect',{'links':[fluid(r['pump'],'P',r['reservoir'],'R2')]},'already connected')
    h=inspect(r['pump'])['ports'][1]['hose']
    disconnected=c.call('sandbox_flowmod_disconnect',{'ref':h})
    check('Specific hose disconnect leaves other lines intact','hose' not in inspect(r['pump'])['ports'][1])
    fail('Late invalid link rolls back earlier new hose','sandbox_flowmod_connect',{'links':[fluid(r['pump'],'P',r['reservoir'],'R2'),fluid(r['pump'],'T',r['reservoir'],'R1')]},'already connected')
    check('Failed link batch leaves free port free','hose' not in inspect(r['pump'])['ports'][1])
    new=c.call('sandbox_flowmod_connect',{'links':[fluid(r['pump'],'P',r['reservoir'],'R2')]})
    fail('Disconnect undo preserves later rewiring','sandbox_undo',{'operation_id':disconnected['operation_id']},'already connected')
    undo(new);undo(disconnected)
    check('Disconnect undo reconnects original endpoints',inspect(r['pump'])['ports'][1]['connected_to']['ref']==r['valve'])
    fail('Partial cylinder blueprint refuses missing anchors','sandbox_blueprint',{'action':'export','refs':[r['cylinder']]},'anchor props')
    fail('Partial fluid blueprint refuses external hose','sandbox_blueprint',{'action':'export','refs':[r['pump']]},'hose leaves')
    tune(r['pump'],control=1);tune(r['valve'],control=1)
    c.call('sandbox_edit',{'items':[{'ref':r['load'],'frozen':False}]})
    measured=c.call('sandbox_measure',{'refs':[r['load'],r['cylinder'],r['pump']],'seconds':3,'interval':.1})
    (ROOT/'artifacts/flowmod-motion.json').write_text(json.dumps(measured,indent=2),encoding='utf-8')
    z=[row['entities'][0]['pos'][2] for row in measured['samples']]
    forces=[row['entities'][1]['flowmod']['actuator']['force_newtons'] for row in measured['samples']]
    check('MCP controls lift a real 100 kg physics load',max(z)-min(z)>8 and max(forces)>500)
    check('Live pressure and flow telemetry stays attached to parts',any(abs(p['flow_lpm'])>.01 for row in measured['samples'] for p in row['entities'][2]['flowmod']['ports']))
    tune(r['valve'],control=0); tune(r['pump'],control=0)
    c.call('sandbox_edit',{'items':[{'ref':r['load'],'frozen':True}]})
    output=c.call('sandbox_wire_ports',{'refs':[r['switch']]})['entities'][0]['outputs'][0]['name']
    wiring=c.call('sandbox_wire_batch',{'links':[{'from':r['switch'],'output':output,'to':r['pump'],'input':'On'}, {'from':r['pump'],'output':'PressureP','to':r['screen'],'input':'A'}]})
    fail('Manual tuning does not fight wired control','sandbox_flowmod_tune',{'ref':r['pump'],'control':1},'Wire-driven')
    c.call('sandbox_wire_set',{'ref':r['switch'],'value':1});time.sleep(.3)
    check('Real Wire signal starts FlowMod pump',inspect(r['pump'])['control']==1)
    ports=c.call('sandbox_wire_ports',{'refs':[r['screen']]})['entities'][0]
    check('FlowMod output drives a real Wire screen',next(p for p in ports['inputs'] if p['name']=='A')['value']>1)
    c.call('sandbox_wire_set',{'ref':r['switch'],'value':0});time.sleep(.2)
    exported=c.call('sandbox_blueprint',{'action':'export','build_id':b['build_id']})['blueprint']
    check('Blueprint captures fluid graph and local anchors',len(exported['fluid_links'])==5 and exported['entities'][5]['flowmod']['anchors']['minimum']==70)
    check('Blueprint includes incoming and outgoing Wire signals',len(exported['wire_links'])==2)
    c.call('sandbox_blueprint',{'action':'import','name':'flowmod-native-test','blueprint':exported,'overwrite':True})
    loaded=c.call('sandbox_blueprint',{'action':'load','name':'flowmod-native-test','origin':[750,400,-125],'angles':[0,90,0]});builds.append(loaded['build_id'])
    lr={e['label']:e['ref'] for e in loaded['entities']}
    copied=inspect(lr['cylinder'])
    check('Rotated copy anchors only to new props',copied['anchors']['a']['ref']==lr['base'] and copied['anchors']['b']['ref']==lr['load'])
    check('Copy is frozen with sources off and no stored pressure',all(e['physics']['frozen'] for e in loaded['entities']) and inspect(lr['pump'])['control']==0 and max(p['pressure_bar'] for p in copied['ports'])<.01)
    check('Copy fluid graph has no original endpoint refs',all(p['connected_to']['ref'] in set(lr.values()) for e in c.call('sandbox_flowmod_inspect',{'build_id':loaded['build_id']})['entities'] for p in e['ports'] if 'connected_to' in p))
    c.call('sandbox_wire_set',{'ref':lr['switch'],'value':1});time.sleep(.2)
    check('Copied signal drives only copied pump',inspect(lr['pump'])['control']==1 and inspect(r['pump'])['control']==0)
    undo(wiring)
    check('Targeted signal undo disconnects FlowMod input',not next(p for p in c.call('sandbox_wire_ports',{'refs':[r['pump']]})['entities'][0]['inputs'] if p['name']=='On').get('source'))
    print(json.dumps({'passed':len(checks),'checks':checks},indent=2))
finally:
    for bid in reversed(builds):
        try:c.call('sandbox_cleanup',{'build_id':bid})
        except RuntimeError as e:print('Cleanup failed:',bid,e)
    (ROOT/'artifacts/flowmod-evaluation.json').write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8');c.close()
