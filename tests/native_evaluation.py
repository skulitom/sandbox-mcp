"""Run against a connected Sandbox map. All world operations use real MCP."""
import json
import pathlib
import sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/"tools"))
from mcp_client import Client, ROOT

c=Client()
checks=[]
created=[]
def check(name,condition):
    assert condition,name
    checks.append(name)
def fails(name,tool,args,contains=None):
    try: c.call(tool,args)
    except RuntimeError as error:
        check(name,contains is None or contains.lower() in str(error).lower())
    else: raise AssertionError(name+" unexpectedly succeeded")
def build(name,parts):
    result=c.call("sandbox_create",{"name":name,"origin":[450,150,-140],"entities":parts})
    created.append(result)
    return result
cube="models/hunter/blocks/cube025x025x025.mdl"
try:
    names=[t["name"] for t in c.request("tools/list",{})["tools"]]
    check("27 advertised tools; no arbitrary Lua execution",len(names)==27 and not any("lua" in n for n in names))
    status=c.call("sandbox_status")
    check("Status never exposes authorization token",'"token"' not in json.dumps(status))
    initial=c.call("sandbox_inspect",{"owned_only":True,"limit":100})
    initial_refs={e["ref"] for e in initial["entities"]}
    catalog=c.call("sandbox_catalog",{"query":"hunter/plates/plate1x1","limit":1})
    check("Catalog bounds and pagination",catalog["items"][0]["bounds"]["max"][0]>20 and catalog["next_offset"]==1)
    trace=c.call("sandbox_trace",{"start":[450,150,100],"end":[450,150,-500]})
    check("Trace locates floor",trace["hit_world"] and trace["normal"][2]>.99)
    two=build("Evaluation cubes",[{"label":"alpha","model":cube,"pos":[0,0,100]},{"label":"beta","model":cube,"pos":[50,0,100]}])
    check("Named batch creates two frozen parts",len(two["entities"])==2 and all(e["physics"]["frozen"] for e in two["entities"]))
    refs=[e["ref"] for e in two["entities"]]
    before=c.call("sandbox_inspect",{"owned_only":True,"limit":100})["total"]
    fails("Invalid later model causes no partial spawn","sandbox_create",{"name":"Invalid batch","entities":[{"label":"ok","model":cube},{"label":"bad","model":"models/does_not_exist.mdl"}]},"valid")
    check("Failed batch preserves object count",c.call("sandbox_inspect",{"owned_only":True})["total"]==before)
    fails("Duplicate labels rejected","sandbox_create",{"name":"Duplicate","entities":[{"label":"a","model":cube},{"label":"a","model":cube}]},"Duplicate")
    fails("Traversal asset rejected","sandbox_create",{"name":"Traversal","entities":[{"label":"a","model":"../secret.mdl"}]},"relative")
    fails("Non-finite/out-of-range position rejected","sandbox_edit",{"items":[{"ref":refs[0],"pos":[999999,0,0]}]})
    player=c.call("sandbox_inspect",{"limit":1})["entities"][0]
    fails("Player cannot be edited","sandbox_edit",{"items":[{"ref":player["ref"],"pos":[0,0,0]}]},"AI-created")
    for kind in ["weld","nocollide","axis","rope"]:
        result=c.call("sandbox_connect",{"links":[{"kind":kind,"a":refs[0],"b":refs[1]}]})
        check(kind+" created",result["connections"]>=1)
        check(kind+" undo",c.call("sandbox_undo",{"operation_id":result["operation_id"]})["undone"])
    first=c.call("sandbox_edit",{"items":[{"ref":refs[0],"color":[1,2,3]}]})
    unrelated=c.call("sandbox_edit",{"items":[{"ref":refs[1],"color":[20,30,40]}]})
    check("Targeted undo preserves unrelated later work",c.call("sandbox_undo",{"operation_id":first["operation_id"]})["undone"])
    beta=c.call("sandbox_inspect",{"refs":[refs[1]]})["entities"][0]
    check("Unrelated edit still present",beta["color"]==[20,30,40])
    later=c.call("sandbox_edit",{"items":[{"ref":refs[1],"color":[50,60,70]}]})
    fails("Out-of-order edit undo is refused","sandbox_undo",{"operation_id":unrelated["operation_id"]},"later")
    c.call("sandbox_undo",{"operation_id":later["operation_id"]})
    c.call("sandbox_undo",{"operation_id":unrelated["operation_id"]})
    c.call("sandbox_edit",{"items":[{"ref":refs[0],"frozen":False}]})
    observed=c.call("sandbox_observe",{"refs":[refs[0]],"seconds":1})
    check("Physics sampling detects gravity",observed["entities"][0]["displacement"]>40 and observed["entities"][0]["max_speed"]>10)
    c.call("sandbox_undo",{"operation_id":two["operation_id"]})
    check("Create undo is idempotent",c.call("sandbox_undo",{"operation_id":two["operation_id"]})["already_undone"])
    fails("Deleted entity ref is rejected","sandbox_edit",{"items":[{"ref":refs[0],"mass":20}]},"Stale")
    for npc in ["npc_citizen","npc_headcrab"]:
        b=build("Evaluation "+npc,[{"label":"subject","kind":"npc","class":npc,"pos":[0,0,5]}])
        check(npc+" creates",b["entities"][0]["class"]==npc)
        c.call("sandbox_cleanup",{"build_id":b["build_id"]})
    remaining=c.call("sandbox_inspect",{"owned_only":True,"limit":100})
    check("Tests leave previous builds intact",{e["ref"] for e in remaining["entities"]}==initial_refs)
    fails("Solid camera position refused","sandbox_view",{"pos":[500,-500,-150],"look_at":[350,-700,-20]},"solid")
    c.call("sandbox_view",{"pos":[850,-450,-10],"look_at":[350,-700,-20],"fov":65})
    screenshot=ROOT/"artifacts/native-evaluation.jpg"
    c.call("sandbox_screenshot",{},screenshot)
    check("MCP screenshot returns a JPEG",screenshot.read_bytes().startswith(b"\xff\xd8"))
    c.call("sandbox_view",{"restore":True})
    print(json.dumps({"passed":len(checks),"checks":checks},indent=2))
finally:
    (ROOT/"artifacts/native-evaluation.json").write_text(json.dumps({"checks":checks,"transcript":c.transcript},indent=2))
    c.close()
