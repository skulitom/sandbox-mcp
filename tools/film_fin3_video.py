"""Fin 3 production: public MCP builds/controls; private helper only films."""
import json,pathlib,time,subprocess,sys,shutil
from mcp_client import Client,ROOT
from dogfood_fin3 import build,launch
OUT=ROOT/'artifacts/fin3-video'
DATA=pathlib.Path(r'D:\Steam\steamapps\common\GarrysMod\garrysmod\data\sandbox_mcp_fin3_film')
for name in ['media','receipts','projects','output','tools']:(OUT/name).mkdir(parents=True,exist_ok=True)
for name in ['cutbolt.py','edit_video.py','score.py']:
    if not (OUT/'tools'/name).exists():shutil.copy2(ROOT/'artifacts/video/tools'/name,OUT/'tools'/name)
def shot(c,name,seconds,start,end,focus,actions=(),follow=None,fov=65):
    c.call('sandbox_view',{'restore':True})
    spec=dict(id=str(time.time_ns()),name=name,duration=seconds,**{'from':start,'to':end,'focus':focus},fov=fov)
    if follow:
        e=c.call('sandbox_inspect',{'refs':[follow]})['entities'][0];spec.update(follow=int(follow.split(':')[1]),anchor=e['pos'])
    (OUT/'projects'/(name+'-capture.json')).write_text(json.dumps(spec,indent=2),encoding='utf-8')
    DATA.mkdir(exist_ok=True);(DATA/'shot.json').write_text(json.dumps(spec),encoding='utf-8')
    pending=list(actions);until=time.monotonic()+240
    while time.monotonic()<until:
        try:
            p=json.loads((DATA/'progress.json').read_text())
            if p['id']==spec['id']:
                while pending and p['frame']>=pending[0][0]:pending.pop(0)[1]()
            r=json.loads((DATA/'done.json').read_text())
            if r['id']==spec['id']:break
        except (FileNotFoundError,json.JSONDecodeError):pass
        time.sleep(.04)
    else:raise RuntimeError('Capture pending; inspect progress before retry')
    assert r['width']==1920 and r['height']==1080,r
    (OUT/'receipts'/(name+'.json')).write_text(json.dumps(r,indent=2),encoding='utf-8');print('Captured',name,flush=True);time.sleep(4)
def ingest(name):
    r=json.loads((OUT/'receipts'/(name+'.json')).read_text())
    subprocess.run(['C:/ffmpeg/bin/ffmpeg.exe','-hide_banner','-loglevel','error','-n','-framerate','30','-i',str(DATA/name/'frame_%05d.jpg'),'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-map','0:v','-map','1:a','-frames:v',str(r['frames']),'-t',str(r['frames']/30),'-c:v','ffv1','-level','3','-coder','0','-context','0','-slicecrc','0','-threads','12','-pix_fmt','bgr0','-c:a','pcm_s16le',str(OUT/'media'/(name+'.mkv'))],check=True)
    print('Ingested',name,flush=True)
if __name__=='__main__':
    mode=sys.argv[1]
    if mode=='ingest':
        for name in sys.argv[2:]:ingest(name)
        sys.exit()
    c=Client(exe=ROOT/'target/release/sandbox-mcp.exe');created=[]
    def load(pos):
        b=c.call('sandbox_blueprint',{'action':'load','name':'mcp_fin3_glider','origin':pos});created.append(b['build_id']);return b
    try:
        old=json.loads((ROOT/'artifacts/fin3-flight/build.json').read_text())
        if any(b['id']==old['build_id'] for b in c.call('sandbox_inspect',{'owned_only':True,'limit':1})['builds']):c.call('sandbox_cleanup',{'build_id':old['build_id']})
        if mode in ('capture','flight'):
            b=load([-5000,-2000,-11600]);r=b['entities'][0]['ref']
            shot(c,'flight-front',5,[-4690,-2340,-11480],[-4760,-2320,-11490],[-5000,-2000,-11600],[(10,lambda:launch(c,b))],r,60)
            c.call('sandbox_cleanup',{'build_id':b['build_id']});created.remove(b['build_id'])
        if mode=='capture':
            built=[]
            def assemble():
                b=build(c,[0,-300,-12160]);built.append(b);created.append(b['build_id'])
            shot(c,'assemble',4,[270,-620,-12010],[230,-600,-12040],[0,-300,-12150],[(10,assemble)],fov=60)
            b=load([-5000,-2000,-11600]);r=b['entities'][0]['ref']
            shot(c,'flight-side',5,[-5080,-2370,-11500],[-5010,-2340,-11530],[-5000,-2000,-11600],[(10,lambda:launch(c,b))],r,60)
            c.call('sandbox_cleanup',{'build_id':b['build_id']});created.remove(b['build_id'])
            c.call('sandbox_cleanup',{'build_id':built[0]['build_id']});created.remove(built[0]['build_id'])
        if mode in ('capture','rotor'):
            b=c.call('sandbox_create',{'name':'Fin 3 propeller demonstrator','origin':[400,-500,-12200],'entities':[{'label':'rotor','model':'models/hunter/plates/plate05x2.mdl','mass':10,'color':[255,140,30],'material':'models/debug/debugwhite','fin3':{'kind':'propeller','forward':[0,0,1],'diameter':3,'pitch':20}}]});created.append(b['build_id']);r=b['entities'][0]['ref'];idx=r.split(':')[1]
            code='@name MCP Fin 3 propeller drive\n@persist R:entity\n@trigger none\nif (first()) { R = entity('+idx+') }\ninterval(20)\nR:applyTorque(vec(0,0,clamp((2000-R:angVelVector():z())*10,-20000,20000)))\n'
            chip=c.call('sandbox_create',{'name':'Wire motor for Fin 3','origin':[350,-500,-12260],'entities':[{'label':'motor','kind':'wire','preset':'expression2','settings':{'code':code}}]});created.append(chip['build_id']);cr=chip['entities'][0]['ref']
            def spin():
                c.call('sandbox_edit',{'items':[{'ref':r,'frozen':False}]});c.call('sandbox_e2',{'action':'run','ref':cr})
            shot(c,'rotor-rise',4,[700,-820,-12100],[670,-780,-12110],[400,-500,-12200],[(10,spin)],r,60)
            c.call('sandbox_e2',{'action':'stop','ref':cr})
        if mode in ('capture','fleet'):
            for y in [-600,-300,0]:load([0,y,-12150])
            shot(c,'fleet',3,[520,-740,-11880],[420,-700,-11930],[0,-300,-12150],fov=66)
    finally:
        for bid in reversed(created):
            try:c.call('sandbox_cleanup',{'build_id':bid})
            except RuntimeError:pass
        (OUT/'receipts'/('mcp-'+mode+'-transcript.json')).write_text(json.dumps(c.transcript,indent=2),encoding='utf-8');c.close()
