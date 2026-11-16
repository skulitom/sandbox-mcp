"""Native Fin 3 integration through the released MCP surface, not mocked physics."""
import json, pathlib, sys, time
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client, ROOT
c=Client(exe=ROOT/'target/release/sandbox-mcp.exe'); checks=[]; builds=[]
def check(name,value):
    assert value,name
    checks.append(name);print('PASS',name,flush=True)
def fail(name,tool,args,expected):
    try:c.call(tool,args)
    except RuntimeError as ex:check(name,expected.lower() in str(ex).lower())
    else:raise AssertionError(name)
def create(name,parts):
    b=c.call('sandbox_create',{'name':name,'origin':[400,200,200],'entities':parts});builds.append(b['build_id']);return b
def read(ref):return c.call('sandbox_fin3_inspect',{'refs':[ref]})['entities'][0]
def apply(ref,spec):return c.call('sandbox_fin3_apply',{'items':[{'ref':ref,'fin3':spec}]})
def part(label,pos=None,spec=None):
    a={'label':label,'model':'models/hunter/plates/plate1x2.mdl','pos':pos or [0,0,0],'mass':20}
    if spec:a['fin3']=spec
    return a
fin={'kind':'fin','camber':25}
try:
    cat=c.call('sandbox_catalog',{'kind':'fin3'})
    check('Actual Workshop Fin 3 discovered',cat['installed'] and {'standard','flat','fighter'}<=set(x['id'] for x in cat['items']))
    b=create('Fin integration',[part('wing',spec=fin),part('spare',[0,160,0])]);wing,spare=[e['ref'] for e in b['entities']]
    check('Atomic create attaches actual fin',read(wing)['settings']['camber']==25)
    check('Area calculated from real prop geometry',read(wing)['telemetry']['surface_area_m2']>2)
    original=read(wing)['settings'];a=apply(wing,dict(fin,camber=40))
    check('Tune existing fin',read(wing)['settings']['camber']==40)
    c.call('sandbox_undo',{'operation_id':a['operation_id']})
    check('Targeted undo restores settings',read(wing)['settings']==original)
    a=c.call('sandbox_fin3_apply',{'items':[{'ref':wing,'remove':True}]})
    check('Remove leaves prop alive',not read(wing)['active'])
    c.call('sandbox_undo',{'operation_id':a['operation_id']})
    check('Remove undo reattaches fin',read(wing)['settings']==original)
    for title,spec,expected in [
        ('Parallel axes',dict(fin,forward=[0,0,1]),'perpendicular'),
        ('Non-unit axis',dict(fin,forward=[2,0,0]),'unit'),
        ('Unknown airfoil',dict(fin,airfoil='made-up'),'airfoil'),
        ('Camber limit',dict(fin,camber=101),'range'),
        ('Flat plate camber',dict(fin,airfoil='flat'),'camber'),
        ('Unknown setting',dict(fin,execute='anything'),'Unknown'),
        ('Propeller diameter',{'kind':'propeller','diameter':7},'range'),
        ('Fractional blade count',{'kind':'propeller','blades':2.5},'integer')]:
        fail(title,'sandbox_fin3_apply',{'items':[{'ref':wing,'fin3':spec}]},expected)
    fail('Invalid batch changes nothing','sandbox_fin3_apply',{'items':[{'ref':wing,'fin3':dict(fin,camber=60)},{'ref':spare,'fin3':dict(fin,up=[1,0,0])}]},'perpendicular')
    check('Earlier part preserved on validation failure',read(wing)['settings']==original)
    fail('Duplicate refs rejected','sandbox_fin3_apply',{'items':[{'ref':wing,'remove':True},{'ref':wing,'remove':True}]},'Duplicate')
    fail('Removal and settings conflict','sandbox_fin3_apply',{'items':[{'ref':wing,'remove':True,'fin3':fin}]},'not both')
    a=apply(wing,dict(fin,camber=35));later=apply(wing,dict(fin,camber=45))
    fail('Stale modifier undo rejected','sandbox_undo',{'operation_id':a['operation_id']},'changed')
    c.call('sandbox_undo',{'operation_id':later['operation_id']});c.call('sandbox_undo',{'operation_id':a['operation_id']})
    check('Sequential undo returns original state',read(wing)['settings']==original)
    prop={'kind':'propeller','forward':[0,0,1],'pitch':-20,'blades':3,'diameter':1.2,'invert':True}
    a=apply(spare,prop)
    check('Actual propeller settings and telemetry',read(spare)['settings']==prop and 'rpm' in read(spare)['telemetry'])
    exported=c.call('sandbox_blueprint',{'action':'export','build_id':b['build_id']})['blueprint']
    check('Blueprint captures both aerodynamic kinds',set(e['fin3']['kind'] for e in exported['entities'])=={'fin','propeller'})
    c.call('sandbox_blueprint',{'action':'save','build_id':b['build_id'],'name':'fin3-native-evaluation','overwrite':True})
    loaded=c.call('sandbox_blueprint',{'action':'load','name':'fin3-native-evaluation','origin':[800,200,200],'angles':[0,90,0]});builds.append(loaded['build_id'])
    check('Rotated blueprint keeps local axes and freezes physics',all(e['physics']['frozen'] and e['fin3']['active'] for e in loaded['entities']))
    check('Blueprint retains exact live settings',[e['fin3']['settings'] for e in loaded['entities']]==[original,prop])
    # Real Fin 3 lift: compare matched airborne props after one launch.
    lift=create('Native lift comparison',[part('aero',[0,0,300],fin),part('control',[0,200,300])])
    refs=[e['ref'] for e in lift['entities']]
    c.call('sandbox_edit',{'items':[{'ref':r,'frozen':False,'velocity':[1100,0,0]} for r in refs]})
    measure=c.call('sandbox_measure',{'refs':refs,'seconds':1.2,'interval':0.1})
    heights=[x['finish'][2] for x in measure['summary']]
    forces=[e['fin3'].get('telemetry',{}).get('lift_newtons',0) for row in measure['samples'] for e in row['entities']]
    check('Native lift measurably changes trajectory',heights[0]>heights[1]+30 and max(forces)>100)
    check('Time series includes native aerodynamic telemetry',any('angle_of_attack_degrees' in e['fin3'].get('telemetry',{}) for row in measure['samples'] for e in row['entities']))
    (ROOT/'artifacts/fin3-lift-measurement.json').write_text(json.dumps(measure,indent=2),encoding='utf-8')
    # Fin 3 server quotas are respected by a whole create batch; no residual props.
    before=c.call('sandbox_inspect',{'owned_only':True,'limit':1})['total']
    fail('Server fin quota respected','sandbox_create',{'name':'Over quota','entities':[part(f'quota-{i}',[i*60,0,0],fin) for i in range(21)]},'limit')
    check('Over-quota creation rolled back every prop',c.call('sandbox_inspect',{'owned_only':True,'limit':1})['total']==before)
    foreign=next(e['ref'] for e in c.call('sandbox_inspect',{'limit':100})['entities'] if not e['owned'])
    fail('Read-only entities cannot be modified','sandbox_fin3_apply',{'items':[{'ref':foreign,'fin3':fin}]},'AI-created')
    fail('Previous session refs rejected','sandbox_fin3_apply',{'items':[{'ref':'deadbeef:1:1','fin3':fin}]},'previous')
    print(json.dumps({'passed':len(checks),'checks':checks},indent=2))
finally:
    for bid in reversed(builds):
        try:c.call('sandbox_cleanup',{'build_id':bid})
        except RuntimeError:pass
    (ROOT/'artifacts/fin3-evaluation.json').write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8');c.close()
