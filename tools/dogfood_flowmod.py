"""Build and measure a twin-cylinder hydraulic lift through public MCP tools."""
import json
from mcp_client import Client,ROOT
OUT=ROOT/'artifacts/flowmod-dual-lift';OUT.mkdir(parents=True,exist_ok=True)
def save(name,data):(OUT/(name+'.json')).write_text(json.dumps(data,indent=2),encoding='utf-8')
def specification(origin):
    def prop(label,pos,mass,color):
        return dict(label=label,model='models/hunter/plates/plate2x2.mdl',pos=pos,mass=mass,
                    color=color,material='models/debug/debugwhite')
    def part(label,kind,pos,**options):return dict(label=label,kind='flowmod',pos=pos,flowmod=dict(kind=kind,**options))
    def hose(a,pa,b,pb):return dict(a=a,port_a=pa,b=b,port_b=pb)
    parts=[prop('base',[0,0,0],300,[40,70,95]),prop('platform',[0,0,65],200,[235,180,55]),
        part('reservoir','reservoir',[-130,-80,8]),part('pump','pump',[-130,0,16],pressure=40,flow=20),
        part('valve','valve',[-130,80,16],opening=.12),part('supply-tee','tee',[-60,80,16]),part('return-tee','tee',[60,80,16]),
        part('left-cylinder','cylinder',[-32,0,12],bore=40,stroke=80,anchors=dict(a='base',b='platform',point_a=[-32,0,0],point_b=[-32,0,0],minimum=25)),
        part('right-cylinder','cylinder',[32,0,12],bore=40,stroke=80,anchors=dict(a='base',b='platform',point_a=[32,0,0],point_b=[32,0,0],minimum=25)),
        dict(label='power',kind='wire',preset='constant',settings=dict(value=0),pos=[-195,0,25]),
        dict(label='direction',kind='wire',preset='constant',settings=dict(value=0),pos=[-195,80,25]),
        dict(label='pressure-display',kind='wire',preset='screen',settings=dict(text_a='Left bar',text_b='Right bar'),pos=[-190,40,60])]
    hoses=[hose('reservoir','T','pump','T'),hose('pump','P','valve','P'),hose('valve','T','reservoir','R1'),
        hose('valve','A','supply-tee','IN'),hose('valve','B','return-tee','IN'),
        hose('supply-tee','A','left-cylinder','A'),hose('supply-tee','B','right-cylinder','A'),
        hose('return-tee','A','left-cylinder','B'),hose('return-tee','B','right-cylinder','B')]
    signals=[dict(**{'from':'power'},output='1',to='pump',input='On'),dict(**{'from':'direction'},output='1',to='valve',input='Direction'),
        dict(**{'from':'left-cylinder'},output='PressureA',to='pressure-display',input='A'),dict(**{'from':'right-cylinder'},output='PressureA',to='pressure-display',input='B')]
    return dict(name='MCP twin-cylinder 200 kg lift',origin=origin,entities=parts,fluid_links=hoses,wire_links=signals,
                links=[dict(kind='nocollide',a='base',b='platform')])
if __name__=='__main__':
    c=Client();build=None
    try:
        # This reproducible Anode scene fits within the default gm_construct spawn reach.
        floor=c.call('sandbox_trace',{'start':[400,500,100],'end':[400,500,-400]})['position'][2]
        spec=specification([400,500,floor+8]);save('specification',spec)
        build=c.call('sandbox_create',spec);save('build',build)
        r={e['label']:e['ref'] for e in build['entities']}
        c.call('sandbox_blueprint',{'action':'save','build_id':build['build_id'],'name':'mcp_flowmod_dual_lift','overwrite':True})
        c.call('sandbox_flowmod_tune',{'ref':r['valve'],'settings':{'opening':.35}})
        c.call('sandbox_wire_set',{'ref':r['power'],'value':1})
        c.call('sandbox_wire_set',{'ref':r['direction'],'value':1})
        c.call('sandbox_edit',{'items':[dict(ref=r['platform'],frozen=False)]})
        measurement=c.call('sandbox_measure',{'refs':[r['platform'],r['left-cylinder'],r['right-cylinder']],'seconds':3,'interval':.1});save('motion',measurement)
        heights=[row['entities'][0]['pos'][2] for row in measurement['samples']]
        assert max(heights)-min(heights)>8,'Both actuators must lift the real platform'
        c.call('sandbox_wire_set',{'ref':r['direction'],'value':0})
        c.call('sandbox_view',{'pos':[665,755,65],'look_at':[330,515,-65],'fov':55})
        c.call('sandbox_screenshot',{'quality':92},image_path=OUT/'in-game.jpg')
        save('live',c.call('sandbox_flowmod_inspect',{'build_id':build['build_id']}))
        print(json.dumps(dict(build_id=build['build_id'],lift_su=max(heights)-min(heights),parts=len(build['entities']),blueprint='mcp_flowmod_dual_lift')))
    finally:
        c.call('sandbox_view',{'restore':True})
        if build:c.call('sandbox_cleanup',{'build_id':build['build_id']})
        save('transcript',c.transcript);c.close()
