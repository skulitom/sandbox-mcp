"""A reproducible scene built exclusively through the public MCP tools."""
import json
import math
import time
from mcp_client import Client, ROOT

out=ROOT / "artifacts/dogfood"
out.mkdir(parents=True,exist_ok=True)
c=Client()
start=time.monotonic()
try:
    ground=c.call("sandbox_trace",{"start":[350,-700,300],"end":[350,-700,-500]})
    z=ground["position"][2]
    colors=[[40,210,230],[245,130,50],[150,80,230]]
    parts=[]
    def prop(label,model,pos,color,angles=None):
        parts.append({"label":label,"model":model,"pos":pos,"color":color,"material":"models/debug/debugwhite","angles":angles or [0,0,0]})
    for i in range(3):
        prop(f"gate-ring-{i+1}","models/hunter/tubes/tube4x4x025.mdl",[-i*45,0,125],colors[i],[90,i*12,0])
        prop(f"walkway-{i+1}","models/hunter/plates/plate2x2.mdl",[80-i*95,0,5],[36,44,60])
    for i in range(16):
        angle=i*math.tau/16
        prop(f"orbit-marker-{i+1:02}","models/hunter/blocks/cube025x025x025.mdl",[25,math.cos(angle)*115,125+math.sin(angle)*115],colors[i%3],[i*11,i*22,45])
    for i in [-1,1]:
        prop(f"plinth-{i}","models/hunter/blocks/cube1x1x1.mdl",[80,i*130,24],[36,44,60])
        parts.append({"label":f"beacon-{i}","kind":"light","pos":[80,i*130,51],"color":colors[0 if i<0 else 1],"material":"models/debug/debugwhite"})
    scene={"name":"Chromatic gate laboratory","origin":[350,-700,z],"entities":parts}
    (out/"scene-blueprint.json").write_text(json.dumps(scene,indent=2))
    created=c.call("sandbox_create",scene)
    (out/"scene-result.json").write_text(json.dumps(created,indent=2))
    c.call("sandbox_view",{"pos":[850,-450,-10],"look_at":[350,-700,-20],"fov":65})
    time.sleep(.5)
    c.call("sandbox_screenshot",{},out/"chromatic-gate.jpg")
    print(json.dumps({"build_id":created["build_id"],"parts":len(created["entities"]),"build_call_ms":created["elapsed_ms"],"workflow_seconds":round(time.monotonic()-start,2),"image":str(out/"chromatic-gate.jpg")}))
finally:
    (out/"scene-transcript.json").write_text(json.dumps(c.transcript,indent=2))
    c.close()
