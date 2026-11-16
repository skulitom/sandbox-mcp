"""A real Wiremod launchpad built exclusively through Sandbox MCP's public tools."""
import itertools,json,pathlib,time,sys
from mcp_client import Client,ROOT
OUT=ROOT/'artifacts/wire-video'
OUT.mkdir(parents=True,exist_ok=True)

def save(name,value):
    (OUT/(name+'.json')).write_text(json.dumps(value,indent=2),encoding='utf-8',newline='\n')

def build(c):
    floor=c.call('sandbox_trace',{'start':[380,400,300],'end':[380,400,-500]})['position'][2]
    # The first trace can hit our previous build; use a clear point on the same plane.
    floor=c.call('sandbox_trace',{'start':[650,650,300],'end':[650,650,-500]})['position'][2]
    parts=[];rocket=[]
    def prop(label,model,pos,color=(225,235,240),moving=False,**kw):
        p=dict(label=label,model=model,pos=pos,color=list(color),material='models/debug/debugwhite',**kw)
        parts.append(p)
        if moving:rocket.append(label)
    def wire(label,preset,pos,settings=None,moving=False,**kw):
        parts.append(dict(label=label,kind='wire',preset=preset,pos=pos,settings=settings or {},**kw))
        if moving:rocket.append(label)
    prop('launch-pad','models/hunter/plates/plate4x4.mdl',[0,0,8],(24,34,49))
    prop('control-deck','models/hunter/plates/plate2x3.mdl',[170,0,38],(24,34,49))
    prop('rocket-body','models/hunter/tubes/tube1x1x4.mdl',[0,0,40],mass=80,moving=True)
    prop('nose','models/hunter/misc/cone1x1.mdl',[0,0,230],(255,115,25),mass=12,moving=True)
    for i,(x,y) in enumerate([(32,0),(-32,0),(0,32),(0,-32)]):
        prop('fin-'+str(i),'models/hunter/plates/plate05x1.mdl',[x,y,61],(255,115,25),angles=[90,0 if x else 90,0],mass=4,moving=True)
        wire('engine-'+str(i),'thruster',[x*.65,y*.65,34],{'force':110},angles=[180,0,0],mass=6,moving=True)
    wire('gps','gps',[0,0,80],mass=2,moving=True)
    wire('speed','speedometer',[0,0,120],mass=2,moving=True)
    wire('launch','button',[205,-68,47],angles=[0,0,0])
    wire('timer','gate',[145,-55,46],{'action':'timer'})
    wire('idle','gate',[115,-55,46],{'action':'not'})
    for label,value,pos in [('delay',3,[115,-25,46]),('ceiling',700,[115,0,46]),('datum',floor+80,[115,25,46]),('period',.25,[115,50,46]),('one',1,[115,75,46]),('timeout',6,[145,75,46])]:
        wire(label,'constant',pos,{'value':value})
    for i,(label,action) in enumerate([('countdown','-'),('ignition','>'),('height','-'),('below-ceiling','<'),('burn-window','<'),('enable','and'),('strobe','squarepulse')]):
        wire(label,'gate',[145+(i//4)*28,-25+(i%4)*25,46],{'action':action})
    wire('count-screen','screen',[205,-25,47],{'text_a':'T MINUS','text_b':'IGNITION'})
    wire('count-floor','gate',[175,75,46],{'action':'clamp'})
    wire('telemetry-screen','screen',[205,30,47],{'text_a':'ALTITUDE','text_b':'SPEED'})
    for i,(x,y) in enumerate([(-80,-80),(-80,80),(80,80),(80,-80)]):
        wire('beacon-'+str(i),'indicator',[x,y,23],{'low_color':[22,30,43],'high_color':[255,115,25]},material='models/debug/debugwhite')
    links=[{'kind':'weld','a':'rocket-body','b':label} for label in rocket if label!='rocket-body']
    links += [{'kind':'nocollide','a':a,'b':b} for a,b in itertools.combinations(rocket,2) if 'rocket-body' not in (a,b)]
    blueprint={'name':'MCP Wiremod launch laboratory','origin':[380,400,floor],'entities':parts,'links':links}
    r=c.call('sandbox_create',blueprint)
    refs={e['label']:e['ref'] for e in r['entities']}
    def link(a,out,b,inp):c.call('sandbox_wire_connect',{'from':refs[a],'output':out,'to':refs[b],'input':inp})
    link('launch','Out','timer','Run');link('launch','Out','idle','A');link('idle','Out','timer','Reset')
    link('delay','1','countdown','A');link('timer','Out','countdown','B')
    link('timer','Out','ignition','A');link('delay','1','ignition','B')
    link('gps','Z','height','A');link('datum','1','height','B')
    link('height','Out','below-ceiling','A');link('ceiling','1','below-ceiling','B')
    link('timer','Out','burn-window','A');link('timeout','1','burn-window','B')
    link('ignition','Out','enable','A');link('below-ceiling','Out','enable','B');link('burn-window','Out','enable','C')
    link('launch','Out','strobe','Run');link('idle','Out','strobe','Reset');link('period','1','strobe','PulseTime');link('period','1','strobe','GapTime');link('one','1','strobe','Max')
    for i in range(4):
        link('strobe','Out','beacon-'+str(i),'A');link('enable','Out','engine-'+str(i),'A')
    link('countdown','Out','count-floor','A');link('delay','1','count-floor','Max')
    link('count-floor','Out','count-screen','A');link('enable','Out','count-screen','B')
    link('height','Out','telemetry-screen','A');link('speed','Out','telemetry-screen','B')
    state={'blueprint':blueprint,'result':r,'refs':refs,'rocket':rocket,'floor':floor}
    save('launchpad',state)
    return state

def reset(c,s):
    c.call('sandbox_wire_set',{'ref':s['refs']['launch'],'value':0})
    c.call('sandbox_edit',{'items':[dict(ref=e['ref'],pos=e['pos'],angles=e['angles'],frozen=True,velocity=[0,0,0]) for e in s['result']['entities'] if e['label'] in s['rocket']]})

def prepare(c,s):
    reset(c,s)
    c.call('sandbox_edit',{'items':[{'ref':s['refs'][n],'frozen':False} for n in s['rocket']]})
    time.sleep(1)
    gps=c.call('sandbox_wire_ports',{'refs':[s['refs']['gps']]})['entities'][0]
    datum=next(p['value'] for p in gps['outputs'] if p['name']=='Z')
    c.call('sandbox_wire_set',{'ref':s['refs']['datum'],'value':datum})

def arm(c,s):
    return c.call('sandbox_wire_set',{'ref':s['refs']['launch'],'value':1})

if __name__=='__main__':
    c=Client(exe=ROOT/'target/release/sandbox-mcp.exe')
    try:
        mode=sys.argv[1] if len(sys.argv)>1 else 'build'
        if mode=='build':
            old=OUT/'launchpad.json'
            if old.exists():
                try:c.call('sandbox_cleanup',{'build_id':json.loads(old.read_text())['result']['build_id']})
                except RuntimeError:pass
            s=build(c)
        else:s=json.loads((OUT/'launchpad.json').read_text())
        if mode=='reset':reset(c,s)
        if mode=='test':
            prepare(c,s);arm(c,s);samples=[]
            for _ in range(16):
                time.sleep(.5)
                sample=c.call('sandbox_wire_ports',{'refs':[s['refs'][n] for n in ['timer','height','speed','enable']]})
                samples.append(sample)
                print([(e['ref'].split(':')[1],e['outputs']) for e in sample['entities']],flush=True)
            save('flight-test',samples)
            reset(c,s)
        c.call('sandbox_view',{'pos':[850,740,130],'look_at':[400,400,-10],'fov':58})
        time.sleep(.4)
        c.call('sandbox_screenshot',{'quality':95},OUT/'launchpad.jpg')
        print('Ready:',len(s['result']['entities']),'parts',flush=True)
    finally:save('launchpad-'+(sys.argv[1] if len(sys.argv)>1 else 'build')+'-transcript',c.transcript);c.close()
