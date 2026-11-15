"""Real MCP -> real Wiremod integration. Run in the consenting Anode Sandbox."""
import json, pathlib, sys, time
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/"tools"))
from mcp_client import Client, ROOT
c=Client(); checks=[]; build=None
def check(name,condition):
    assert condition,name
    checks.append(name)
def fail(name,tool,args,text):
    try:c.call(tool,args)
    except RuntimeError as e:check(name,text.lower() in str(e).lower())
    else:raise AssertionError(name)
def ports(ref):return c.call("sandbox_wire_ports",{"refs":[ref]})["entities"][0]
def output(ref,name="Out"):
    return next(p["value"] for p in ports(ref)["outputs"] if p["name"]==name)
def connect(a,out,b,inp):return c.call("sandbox_wire_connect",{"from":a,"output":out,"to":b,"input":inp})
try:
    catalog=c.call("sandbox_catalog",{"kind":"wire"})
    check("Wire detected and eleven components discoverable",catalog["installed"] and len([i for i in catalog["items"] if i["kind"]=="component"])==11)
    specs=[("power","constant",{"value":2}),("button","button",{}),("sum","gate",{"action":"+"}),("lamp","indicator",{}),("screen","screen",{}),("speed","speedometer",{}),("gps","gps",{}),("thrust","thruster",{"force":400})]
    build=c.call("sandbox_create",{"name":"Wire integration evaluation","origin":[400,100,-80],"entities":[{"label":label,"kind":"wire","preset":preset,"settings":settings,"pos":[i*60,0,0]} for i,(label,preset,settings) in enumerate(specs)]})
    refs={e["label"]:e["ref"] for e in build["entities"]}
    check("Every advertised component spawns with physics",len(refs)==8 and all(e["physics"]["frozen"] for e in build["entities"]))
    check("Constant output name and value",output(refs["power"],"1")==2)
    connect(refs["power"],"1",refs["sum"],"A")
    connect(refs["button"],"Out",refs["sum"],"B")
    connect(refs["sum"],"Out",refs["screen"],"A")
    connect(refs["button"],"Out",refs["lamp"],"A")
    check("Real signal propagation through arithmetic gate",output(refs["sum"])==2)
    state=c.call("sandbox_wire_set",{"ref":refs["button"],"value":1})
    check("Button changes downstream gate and screen",output(refs["sum"])==3 and next(p["value"] for p in ports(refs["screen"])["inputs"] if p["name"]=="A")==3)
    color=c.call("sandbox_inspect",{"refs":[refs["lamp"]]})["entities"][0]["color"]
    check("Indicator changes actual rendered entity color",color==[30,240,170])
    c.call("sandbox_undo",{"operation_id":state["operation_id"]})
    check("Source undo propagates downstream",output(refs["sum"])==2)
    value=c.call("sandbox_wire_set",{"ref":refs["power"],"value":0.5})
    check("Changing constant preserves connections",output(refs["sum"])==0.5)
    c.call("sandbox_undo",{"operation_id":value["operation_id"]})
    fail("Occupied inputs require explicit disconnect","sandbox_wire_connect",{"from":refs["power"],"output":"1","to":refs["lamp"],"input":"A"},"already wired")
    fail("Typed ports reject vector-to-number","sandbox_wire_connect",{"from":refs["gps"],"output":"Vector","to":refs["sum"],"input":"C"},"type mismatch")
    fail("Feedback cycle rejected","sandbox_wire_connect",{"from":refs["sum"],"output":"Out","to":refs["button"],"input":"Set"},"cycle")
    fail("Unknown output rejected","sandbox_wire_connect",{"from":refs["power"],"output":"missing","to":refs["screen"],"input":"B"},"Unknown output")
    off=c.call("sandbox_wire_disconnect",{"to":refs["sum"],"input":"A"})
    check("Disconnect zeroes the actual signal",output(refs["sum"])==0)
    c.call("sandbox_undo",{"operation_id":off["operation_id"]})
    check("Disconnect undo restores signal",output(refs["sum"])==2)
    off=c.call("sandbox_wire_disconnect",{"to":refs["sum"],"input":"A"})
    replace=connect(refs["button"],"Out",refs["sum"],"A")
    fail("Undo refuses to overwrite later wiring","sandbox_undo",{"operation_id":off["operation_id"]},"changed")
    c.call("sandbox_undo",{"operation_id":replace["operation_id"]})
    c.call("sandbox_undo",{"operation_id":off["operation_id"]})
    fail("Unbounded setting rejected before spawning","sandbox_create",{"name":"Invalid force","entities":[{"label":"bad","kind":"wire","preset":"thruster","settings":{"force":999999}}]},"range")
    fail("Unadvertised entity class rejected","sandbox_create",{"name":"No arbitrary E2","entities":[{"label":"bad","kind":"wire","preset":"unrestricted_entity"}]},"Unknown Wire preset")
    existing=c.call("sandbox_inspect",{"limit":1})["entities"][0]["ref"]
    fail("Non-owned entity cannot be wired","sandbox_wire_connect",{"from":existing,"output":"Out","to":refs["screen"],"input":"B"},"AI-created")
    connect(refs["button"],"Out",refs["thrust"],"A")
    c.call("sandbox_edit",{"items":[{"ref":refs["thrust"],"frozen":False,"mass":30,"pos":[820,100,100],"angles":[180,0,0]}]})
    c.call("sandbox_wire_set",{"ref":refs["button"],"value":1})
    motion=c.call("sandbox_observe",{"refs":[refs["thrust"]],"seconds":0.6})["entities"][0]
    check("Real Wire thruster produces physical motion",motion["max_speed"]>80 and motion["finish"][2]>motion["start"][2]+20)
    c.call("sandbox_wire_set",{"ref":refs["button"],"value":0})
    c.call("sandbox_edit",{"items":[{"ref":refs["speed"],"frozen":False,"velocity":[200,0,0]}]})
    time.sleep(.1)
    check("Speed sensor reports physical velocity",output(refs["speed"])>100)
    check("GPS returns typed world-space vector",isinstance(output(refs["gps"],"Vector"),list))
    print(json.dumps({"passed":len(checks),"checks":checks},indent=2))
finally:
    if build:c.call("sandbox_cleanup",{"build_id":build["build_id"]})
    (ROOT/"artifacts/wire-evaluation.json").write_text(json.dumps({"checks":checks,"transcript":c.transcript},indent=2))
    c.close()
