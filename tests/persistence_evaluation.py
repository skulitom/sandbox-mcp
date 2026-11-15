"""Run after workflow_evaluation/dogfood_hovercraft and a full game restart."""
import json, pathlib, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from mcp_client import Client, ROOT
c=Client();checks=[];builds=[]
def check(name,condition):
    assert condition,name
    checks.append(name);print('PASS',name,flush=True)
try:
    before=json.loads((ROOT/'artifacts/v02-before-restart.json').read_text())
    current=c.call('sandbox_status')
    old={x['instance'] for x in before['instances']}
    connected=[x for x in current['instances'] if x['connected']]
    check('A different game instance is connected',len(connected)==1 and connected[0]['instance'] not in old)
    library=c.call('sandbox_blueprint',{'action':'list'})
    check('Blueprint library survives game restart',{'workflow_import','mcp_hovercraft'}<={x['name'] for x in library['items']})
    b=c.call('sandbox_blueprint',{'action':'load','name':'workflow_import','origin':[350,300,-80]});builds.append(b['build_id'])
    refs={e['label']:e['ref'] for e in b['entities']}
    ports=c.call('sandbox_wire_ports',{'refs':[refs['sum']]})['entities'][0]
    check('Saved circuit still propagates its saved constant',abs(next(p['value'] for p in ports['outputs'] if p['name']=='Out')-.4)<1e-6)
    h=c.call('sandbox_blueprint',{'action':'load','name':'mcp_hovercraft','origin':[350,100,2]});builds.append(h['build_id'])
    hr={e['label']:e['ref'] for e in h['entities']}
    check('Complete hovercraft restores frozen',len(h['entities'])==15 and h['connections']==105 and all(e['physics']['frozen'] for e in h['entities']))
    state=c.call('sandbox_e2',{'action':'status','ref':hr['controller']})
    check('Saved E2 is stopped with neutral outputs',state['paused'] and all(p['value']==0 for p in state['ports']['outputs']))
    ports=c.call('sandbox_wire_ports',{'refs':[e['ref'] for e in h['entities'] if e.get('wire_preset')]})['entities']
    check('All twelve hovercraft signal links are restored',sum(bool(p.get('source')) for e in ports for p in e['inputs'])==12)
    c.call('sandbox_e2',{'action':'run','ref':hr['controller']})
    values=c.call('sandbox_measure',{'refs':[hr['controller'],hr['front'],hr['gyro']],'seconds':.6,'interval':.1})['samples'][-1]['entities']
    check('Restored E2 and distance/attitude sensors run',values[0]['outputs']['F1']>0 and values[1]['outputs']['Dist']>0 and 'Pitch' in values[2]['outputs'])
    c.call('sandbox_e2',{'action':'stop','ref':hr['controller']})
    print(json.dumps({'passed':len(checks)}))
finally:
    for bid in builds:
        try:c.call('sandbox_cleanup',{'build_id':bid})
        except RuntimeError:pass
    (ROOT/'artifacts/persistence-evaluation.json').write_text(json.dumps({'checks':checks,'transcript':c.transcript},indent=2),encoding='utf-8',newline='\n')
    c.close()
