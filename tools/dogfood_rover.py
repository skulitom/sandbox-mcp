"""Create a drivable cargo rover through MCP; then measure its settling."""
import json
import time
from mcp_client import Client, ROOT

out=ROOT/"artifacts/dogfood"
out.mkdir(parents=True,exist_ok=True)
c=Client()
start=time.monotonic()
try:
    ground=c.call("sandbox_trace",{"start":[650,-200,200],"end":[650,-200,-500]})
    parts=[{"label":"rover-chassis","kind":"vehicle","preset":"Jeep","pos":[0,0,0],"color":[220,170,65],"frozen":False}]
    for side in [-1,1]:
        parts.append({"label":f"cargo-pod-{side}","model":"models/props_c17/oildrum001.mdl","pos":[side*25,-62,15],"color":[45,170,180],"mass":5,"frozen":False})
        parts.append({"label":f"side-armour-{side}","model":"models/hunter/plates/plate075x1.mdl","pos":[side*40,-5,18],"angles":[90,0,0],"color":[180,140,60],"material":"models/debug/debugwhite","mass":3,"frozen":False})
        parts.append({"label":f"survey-light-{side}","kind":"light","pos":[side*28,55,32],"color":[90,220,220],"mass":1,"frozen":False})
    parts.append({"label":"rear-deck","model":"models/hunter/plates/plate1x1.mdl","pos":[0,-62,12],"color":[40,55,65],"material":"models/debug/debugwhite","mass":5,"frozen":False})
    links=[{"kind":"weld","a":"rover-chassis","b":p["label"]} for p in parts[1:]]
    scene={"name":"Field survey rover","origin":[650,-200,ground["position"][2]+45],"entities":parts,"links":links}
    (out/"rover-blueprint.json").write_text(json.dumps(scene,indent=2))
    created=c.call("sandbox_create",scene)
    (out/"rover-result.json").write_text(json.dumps(created,indent=2))
    settled=c.call("sandbox_observe",{"refs":[e["ref"] for e in created["entities"]],"seconds":3})
    (out/"rover-settling.json").write_text(json.dumps(settled,indent=2))
    c.call("sandbox_view",{"pos":[940,70,10],"look_at":[650,-200,-95],"fov":60})
    time.sleep(.5)
    c.call("sandbox_screenshot",{},out/"field-rover.jpg")
    print(json.dumps({"build_id":created["build_id"],"parts":len(created["entities"]),"constraints":created["connections"],"build_call_ms":created["elapsed_ms"],"workflow_seconds":round(time.monotonic()-start,2)}))
finally:
    (out/"rover-transcript.json").write_text(json.dumps(c.transcript,indent=2))
    c.close()
