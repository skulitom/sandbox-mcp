"""Native Wiremod demonstration. All contraption operations use real MCP."""
import json,pathlib,time,subprocess,sys,shutil
from mcp_client import Client,ROOT
from dogfood_launchpad import build,prepare,arm,reset,save
OUT=ROOT/'artifacts/wire-video'
DATA=pathlib.Path(r'D:\Steam\steamapps\common\GarrysMod\garrysmod\data\sandbox_mcp_wire_film')
for name in ['media','receipts','projects','output','tools']:(OUT/name).mkdir(parents=True,exist_ok=True)
for name in ['cutbolt.py','edit_video.py','score.py']:
    if not (OUT/'tools'/name).exists():shutil.copy2(ROOT/'artifacts/video/tools'/name,OUT/'tools'/name)
c=Client(exe=ROOT/'target/release/sandbox-mcp.exe')

def shot(name,seconds,start,end,focus,actions=(),fov=58,follow=None):
    c.call('sandbox_view',{'restore':True})
    spec={'id':str(time.time_ns()),'name':name,'duration':seconds,'from':start,'to':end,'focus':focus,'fov':fov}
    if follow:
        e=c.call('sandbox_inspect',{'refs':[follow]})['entities'][0]
        spec.update(follow=int(follow.split(':')[1]),anchor=e['pos'])
    (OUT/'projects'/(name+'-capture.json')).write_text(json.dumps(spec,indent=2),encoding='utf-8')
    DATA.mkdir(parents=True,exist_ok=True)
    (DATA/'shot.json').write_text(json.dumps(spec),encoding='utf-8')
    pending=list(actions);deadline=time.time()+240
    while time.time()<deadline:
        try:
            p=json.loads((DATA/'progress.json').read_text())
            if p['id']==spec['id']:
                while pending and p['frame']>=pending[0][0]:pending.pop(0)[1]()
            receipt=json.loads((DATA/'done.json').read_text())
            if receipt['id']==spec['id']:break
        except (FileNotFoundError,json.JSONDecodeError):pass
        time.sleep(.04)
    else:raise RuntimeError('Capture timed out; inspect before retry')
    assert receipt['width']==1920 and receipt['height']==1080,receipt
    (OUT/'receipts'/(name+'.json')).write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print('Captured',name,flush=True)
    # host_framerate transitions briefly pause Source timers; let the real
    # heartbeat catch up before starting the next MCP transaction.
    time.sleep(4)

def ingest(name):
    receipt=json.loads((OUT/'receipts'/(name+'.json')).read_text())
    dst=OUT/'media'/(name+'.mkv')
    subprocess.run(['C:/ffmpeg/bin/ffmpeg.exe','-hide_banner','-loglevel','error','-n','-framerate','30','-i',str(DATA/name/'frame_%05d.jpg'),'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-map','0:v','-map','1:a','-frames:v',str(receipt['frames']),'-t',str(receipt['frames']/30),'-c:v','ffv1','-level','3','-coder','0','-context','0','-slicecrc','0','-threads','12','-pix_fmt','bgr0','-c:a','pcm_s16le',str(dst)],check=True)
    print('Ingested',name,flush=True)

try:
    mode=sys.argv[1] if len(sys.argv)>1 else 'capture'
    if mode=='ingest':
        for name in sys.argv[2:]:ingest(name)
    else:
        s=json.loads((OUT/'launchpad.json').read_text())
        if mode=='capture':
            shot('rocket-reveal',5,[850,740,130],[920,530,105],[400,400,-10])
            c.call('sandbox_cleanup',{'build_id':s['result']['build_id']})
            created=[]
            shot('circuit-build',6,[760,660,140],[720,580,100],[475,400,-50],[(10,lambda:created.append(build(c)))],65)
            s=created[0]
        if mode!='control':
            prepare(c,s)
            shot('flight-track',7,[890,710,80],[790,610,40],[380,400,2],[(10,lambda:arm(c,s))],58,s['refs']['rocket-body'])
            save('flight-end-ports',c.call('sandbox_wire_ports',{'refs':[s['refs'][n] for n in ['height','speed','enable']]}))
        prepare(c,s)
        samples=[]
        def sample():samples.append(c.call('sandbox_wire_ports',{'refs':[s['refs'][n] for n in ['timer','height','speed','below-ceiling','enable']]}))
        shot('control-clean' if mode=='control' else 'live-control',7,[715,405,-60],[695,430,-68],[580,402,-89],[(10,lambda:arm(c,s)),(130,sample),(155,sample),(180,sample)],55)
        save('live-wire-readings',samples)
        reset(c,s)
        if mode!='control':shot('rocket-finale',4,[800,90,20],[910,200,90],[410,400,0],fov=62)
finally:
    if mode!='ingest':(OUT/'receipts'/('mcp-filming-'+mode+'-transcript.json')).write_text(json.dumps(c.transcript,indent=2),encoding='utf-8')
    c.close()
