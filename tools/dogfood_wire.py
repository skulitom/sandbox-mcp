"""Build a working Wiremod pulse sculpture using only the public MCP tools."""
import json, time
from mcp_client import Client, ROOT
out=ROOT/"artifacts/dogfood";out.mkdir(parents=True,exist_ok=True)
c=Client()
try:
    c.call("sandbox_catalog",{"kind":"wire"})
    floor=c.call("sandbox_trace",{"start":[380,400,300],"end":[380,400,-500]})["position"][2]
    parts=[{"label":"stage","model":"models/hunter/plates/plate3x3.mdl","pos":[0,0,5],"color":[30,40,55],"material":"models/debug/debugwhite"}]
    def wire(label,preset,pos,settings=None,**extra):
        parts.append(dict(label=label,kind="wire",preset=preset,pos=pos,settings=settings or {},**extra))
    wire("power","button",[80,-85,14],model="models/props_c17/clock01.mdl",angles=[0,0,0])
    wire("timing","constant",[70,70,14],{"value":0.6})
    wire("one","constant",[70,40,14],{"value":1})
    wire("pulse","gate",[45,0,14],{"action":"squarepulse"})
    wire("invert","gate",[45,30,14],{"action":"not"})
    wire("screen","screen",[80,0,14],{"text_a":"PULSE","text_b":"INVERSE"},angles=[0,0,0])
    for row in range(3):
        for col in range(5):
            wire(f"pixel-{row}-{col}","indicator",[-20,(col-2)*32,26+row*34],{"low_color":[18,25,42],"high_color":[40,220,245] if (col+row)%2==0 else [255,140,35]},material="models/debug/debugwhite")
    blueprint={"name":"Wiremod pulse laboratory","origin":[380,400,floor],"entities":parts}
    result=c.call("sandbox_create",blueprint)
    refs={e["label"]:e["ref"] for e in result["entities"]}
    c.call("sandbox_wire_ports",{"refs":[refs[n] for n in ["power","pulse","invert","screen"]]})
    def link(a,out,b,inp):return c.call("sandbox_wire_connect",{"from":refs[a],"output":out,"to":refs[b],"input":inp})
    link("power","Out","pulse","Run")
    link("timing","1","pulse","PulseTime");link("timing","1","pulse","GapTime")
    link("one","1","pulse","Max");link("pulse","Out","invert","A")
    link("pulse","Out","screen","A");link("invert","Out","screen","B")
    for row in range(3):
        for col in range(5):link("pulse" if (row+col)%2==0 else "invert","Out",f"pixel-{row}-{col}","A")
    c.call("sandbox_wire_set",{"ref":refs["power"],"value":1})
    c.call("sandbox_view",{"pos":[730,650,35],"look_at":[380,400,-75],"fov":58})
    time.sleep(.5)
    c.call("sandbox_screenshot",{"quality":95},out/"wire-pulse.jpg")
    for name,data in [("wire-blueprint",blueprint),("wire-result",result),("wire-transcript",c.transcript)]:
        (out/(name+".json")).write_text(json.dumps(data,indent=2))
    print(json.dumps({"build_id":result["build_id"],"parts":len(parts),"power_ref":refs["power"]}))
finally:c.close()
