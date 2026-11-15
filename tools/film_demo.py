"""Record native footage. Camera/capture fixture is private; every build/edit uses MCP."""
import json,pathlib,time,subprocess,sys
from mcp_client import Client,ROOT
out=ROOT/"artifacts/video"
for name in ["media","receipts","projects","output","tools"]:(out/name).mkdir(parents=True,exist_ok=True)
data=pathlib.Path(r"D:\Steam\steamapps\common\GarrysMod\garrysmod\data\sandbox_mcp_film")
c=Client()
def shot(name,seconds,start,end,focus,actions=None,fov=60):
    c.call("sandbox_view",{"restore":True})
    spec={"id":str(time.time_ns()),"name":name,"duration":seconds,"from":start,"to":end,"focus":focus,"fov":fov}
    (out/"projects"/(name+"-capture.json")).write_text(json.dumps(spec,indent=2))
    data.mkdir(parents=True,exist_ok=True)
    (data/"shot.json").write_text(json.dumps(spec))
    pending=list(actions or [])
    deadline=time.time()+150
    while time.time()<deadline:
        try:
            progress=json.loads((data/"progress.json").read_text())
            if progress["id"]==spec["id"]:
                while pending and progress["frame"]>=pending[0][0]:pending.pop(0)[1]()
            receipt=json.loads((data/"done.json").read_text())
            if receipt["id"]==spec["id"]:break
        except (FileNotFoundError,json.JSONDecodeError):pass
        time.sleep(.05)
    else:raise RuntimeError("Capture timed out; inspect before retrying")
    assert receipt["width"]==1920 and receipt["height"]==1080,receipt
    (out/"receipts"/(name+".json")).write_text(json.dumps(receipt,indent=2))
    subprocess.run(["C:/ffmpeg/bin/ffmpeg.exe","-hide_banner","-loglevel","error","-n","-framerate","30","-i",str(data/name/"frame_%05d.jpg"),"-f","lavfi","-i","anullsrc=r=48000:cl=stereo","-map","0:v","-map","1:a","-frames:v",str(receipt["frames"]),"-t",str(seconds),"-c:v","ffv1","-level","3","-threads","8","-pix_fmt","bgr0","-c:a","pcm_s16le",str(out/"media"/(name+".mkv"))],check=True)
    print("Captured",name,flush=True)
try:
    shot("wire-pulse",6,[700,610,10],[640,460,0],[380,400,-75])
    scene=json.loads((ROOT/"artifacts/dogfood/scene-result.json").read_text())
    blueprint=json.loads((ROOT/"artifacts/dogfood/scene-blueprint.json").read_text())
    c.call("sandbox_cleanup",{"build_id":scene["build_id"]})
    created=[]
    shot("gate-build",6,[850,-450,-10],[760,-540,20],[350,-700,-20],[(10,lambda:created.append(c.call("sandbox_create",blueprint)))],65)
    scene=created[0]
    (ROOT/"artifacts/dogfood/scene-result.json").write_text(json.dumps(scene,indent=2))
    shot("field-rover",6,[940,70,10],[970,-220,-5],[650,-200,-95])
    edit=[]
    def drop():edit.append(c.call("sandbox_edit",{"items":[{"ref":e["ref"],"frozen":False} for e in scene["entities"] if e["label"].startswith("orbit-marker")]}))
    def undo():c.call("sandbox_undo",{"operation_id":edit[0]["operation_id"]})
    shot("physics-undo",8,[750,-480,10],[760,-640,15],[350,-700,-35],[(30,drop),(160,undo)],65)
finally:
    (out/"receipts/mcp-filming-transcript.json").write_text(json.dumps(c.transcript,indent=2))
    c.close()
