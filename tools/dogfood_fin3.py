"""Build, launch, measure and save a Fin 3 glider using only public MCP tools."""
import json,sys
from mcp_client import Client,ROOT
OUT=ROOT/'artifacts/fin3-flight';OUT.mkdir(parents=True,exist_ok=True)
def save(name,a):(OUT/(name+'.json')).write_text(json.dumps(a,indent=2),encoding='utf-8')
def build(c,origin=None,camber=20):
    white=[222,235,245];blue=[32,126,202];orange=[255,135,40]
    def p(label,model,pos,angles,mass,color,fin=None):
        a=dict(label=label,model=model,pos=pos,angles=angles,mass=mass,color=color,material='models/debug/debugwhite')
        if fin:a['fin3']=fin
        return a
    parts=[
        p('fuselage','models/hunter/blocks/cube05x4x025.mdl',[0,0,0],[0,90,0],25,blue,{'kind':'fin','airfoil':'flat','forward':[0,-1,0]}),
        p('main-wing','models/hunter/plates/plate1x4.mdl',[-12,0,10],[0,0,0],12,white,{'kind':'fin','camber':camber}),
        p('tailplane','models/hunter/plates/plate05x2.mdl',[-82,0,10],[0.3,0,0],3,orange,{'kind':'fin'}),
        p('rudder','models/hunter/plates/plate025x1.mdl',[-82,0,34],[0,0,90],2,blue,{'kind':'fin'}),
        p('canopy','models/hunter/blocks/cube025x025x025.mdl',[24,0,12],[0,0,0],2,orange),
    ]
    links=[{'kind':'weld','a':'fuselage','b':p['label']} for p in parts[1:]]
    links += [{'kind':'nocollide','a':a['label'],'b':b['label']} for i,a in enumerate(parts[1:],1) for b in parts[i+1:]]
    if origin is None:
        floor=c.call('sandbox_trace',{'start':[-5000,-2000,12000],'end':[-5000,-2000,-15000]})['position'][2]
        origin=[-5000,-2000,floor+1200]
    b=c.call('sandbox_create',{'name':'MCP Fin 3 glider','origin':origin,'entities':parts,'links':links})
    c.call('sandbox_checkpoint',{'action':'save','name':'fin3_glider_ready','build_id':b['build_id']})
    c.call('sandbox_blueprint',{'action':'save','name':'mcp_fin3_glider','build_id':b['build_id'],'overwrite':True})
    save('build',b);return b
def launch(c,b,speed=1200):
    c.call('sandbox_edit',{'items':[{'ref':e['ref'],'frozen':False,'velocity':[speed,0,0]} for e in b['entities']]})
def reset(c):
    b=c.call('sandbox_checkpoint',{'action':'restore','name':'fin3_glider_ready'})
    save('build',b);return b
if __name__=='__main__':
    c=Client(exe=ROOT/'target/release/sandbox-mcp.exe')
    try:
        mode=sys.argv[1] if len(sys.argv)>1 else 'build'
        b=build(c) if mode=='build' else reset(c)
        if mode in ('build','flight'):
            launch(c,b)
            m=c.call('sandbox_measure',{'refs':[e['ref'] for e in b['entities'][:4]],'seconds':4,'interval':.2});save('flight-measurement',m)
            print(json.dumps(m['summary'],indent=2))
            c.call('sandbox_edit',{'items':[{'ref':e['ref'],'frozen':True} for e in b['entities']]})
    finally:save('transcript-'+mode,c.transcript);c.close()
