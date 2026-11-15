"""Build, measure and save an E2/Wire hovercraft through public MCP tools."""
import json,time
from mcp_client import Client,ROOT
OUT=ROOT/'artifacts/v02-hovercraft';OUT.mkdir(parents=True,exist_ok=True)
c=Client();build=None
CODE='''@name Sandbox MCP hover controller
@inputs D1 D2 D3 D4 Front X
@outputs F1 F2 F3 F4 Forward Reverse
@persist L1 L2 L3 L4 LX LT
@trigger none
interval(50)
if (first()) { L1 = D1 L2 = D2 L3 = D3 L4 = D4 LX = X LT = curtime() }
Delta = max(curtime()-LT, 0.01)
F1 = clamp(0.38 + (130-D1)*0.005 - (D1-L1)*0.08, 0, 1)
F2 = clamp(0.38 + (130-D2)*0.005 - (D2-L2)*0.08, 0, 1)
F3 = clamp(0.38 + (130-D3)*0.005 - (D3-L3)*0.08, 0, 1)
F4 = clamp(0.38 + (130-D4)*0.005 - (D4-L4)*0.08, 0, 1)
Desired = clamp((Front-250)*0.2, -25, 35)
Velocity = (X-LX)/Delta
Drive = clamp((Desired-Velocity)*0.012, -1, 1)
Forward = max(Drive, 0)
Reverse = max(-Drive, 0)
L1 = D1 L2 = D2 L3 = D3 L4 = D4 LX = X LT = curtime()
'''
try:
    old=OUT/'build.json'
    if old.exists():
        try:c.call('sandbox_cleanup',{'build_id':json.loads(old.read_text())['build_id']})
        except RuntimeError:pass
    floor=c.call('sandbox_trace',{'start':[350,100,300],'end':[350,100,-500]})['position'][2]
    parts=[{'label':'deck','model':'models/hunter/plates/plate2x3.mdl','pos':[0,0,0],'mass':100,'color':[28,46,65],'material':'models/debug/debugwhite'}]
    def wire(label,preset,pos,settings=None,**kw):parts.append(dict(label=label,kind='wire',preset=preset,pos=pos,settings=settings or {},mass=2,**kw))
    wire('controller','expression2',[0,0,8],{'code':CODE})
    wire('gps','gps',[0,25,8])
    wire('gyro','gyroscope',[0,-25,8])
    wire('front','ranger',[60,0,0],{'range':1500},angles=[90,0,0])
    for i,(x,y) in enumerate([(-38,-58),(-38,58),(38,-58),(38,58)],1):
        wire('lift-'+str(i),'thruster',[x,y,-5],{'force':160},angles=[180,0,0])
        wire('height-'+str(i),'ranger',[x,y,-20],{'range':600,'show_beam':False},angles=[180,0,0])
    wire('forward','thruster',[-45,0,0],{'force':200},angles=[-90,0,0])
    wire('reverse','thruster',[45,0,0],{'force':200},angles=[90,0,0])
    wires=[]
    def link(a,out,b,inp):wires.append({'from':a,'output':out,'to':b,'input':inp})
    for i in range(1,5):link('height-'+str(i),'Dist','controller','D'+str(i));link('controller','F'+str(i),'lift-'+str(i),'A')
    link('front','Dist','controller','Front');link('gps','X','controller','X')
    link('controller','Forward','forward','A');link('controller','Reverse','reverse','A')
    links=[{'kind':'weld','a':'deck','b':p['label']} for p in parts[1:]]
    links += [{'kind':'nocollide','a':a['label'],'b':b['label']} for i,a in enumerate(parts[1:],1) for b in parts[i+1:]]
    build=c.call('sandbox_create',{'name':'MCP obstacle-aware hovercraft','origin':[350,100,floor+150],'entities':parts,'links':links,'wire_links':wires})
    old.write_text(json.dumps(build,indent=2),encoding='utf-8',newline='\n')
    refs={e['label']:e['ref'] for e in build['entities']}
    c.call('sandbox_checkpoint',{'action':'save','name':'hovercraft_ready','build_id':build['build_id']})
    c.call('sandbox_blueprint',{'action':'save','name':'mcp_hovercraft','build_id':build['build_id'],'overwrite':True})
    c.call('sandbox_e2',{'action':'run','ref':refs['controller']})
    c.call('sandbox_edit',{'items':[{'ref':e['ref'],'frozen':False} for e in build['entities']]})
    measured=c.call('sandbox_measure',{'refs':[refs[n] for n in ['deck','controller','front','gyro']],'seconds':20,'interval':.2})
    (OUT/'measurement.json').write_text(json.dumps(measured,indent=2),encoding='utf-8',newline='\n')
    c.call('sandbox_e2',{'action':'stop','ref':refs['controller']})
    c.call('sandbox_edit',{'items':[{'ref':e['ref'],'frozen':True} for e in build['entities']]})
    c.call('sandbox_view',{'pos':[850,450,190],'look_at':measured['summary'][0]['finish'],'fov':65})
    c.call('sandbox_screenshot',{'quality':90},OUT/'hovercraft.jpg')
    print(json.dumps({'summary':measured['summary'],'controller':c.call('sandbox_e2',{'action':'status','ref':refs['controller']})},indent=2))
finally:
    (OUT/'transcript.json').write_text(json.dumps(c.transcript,indent=2),encoding='utf-8',newline='\n');c.close()
