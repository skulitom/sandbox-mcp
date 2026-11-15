"""Derive fixed fixture answers through MCP and compare the evaluation XML."""
import json
import pathlib
import sys
import xml.etree.ElementTree as ET
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/"tools"))
from mcp_client import Client, ROOT
c=Client()
try:
    c.call("sandbox_status")
    builds=c.call("sandbox_inspect",{"owned_only":True,"limit":1})["builds"]
    def parts(name):
        build=next(b for b in builds if b["name"]==name)
        items=[];offset=0
        while True:
            page=c.call("sandbox_inspect",{"build_id":build["id"],"limit":5,"offset":offset})
            items.extend(page["entities"])
            if "next_offset" not in page:break
            offset=page["next_offset"]
        return items
    gate=parts("Chromatic gate laboratory")
    rover=parts("Field survey rover")
    marker=[p for p in gate if p["label"].startswith("orbit-marker")]
    chassis=next(p for p in rover if p["label"]=="rover-chassis")
    total=sum(p["physics"]["mass"] for p in rover)
    oil=c.call("sandbox_catalog",{"query":"props_c17/oildrum001.mdl","limit":10})
    pods=[p for p in rover if p["label"].startswith("cargo-pod")]
    assert all(p["model"]==oil["items"][0]["model"] for p in pods)
    vehicles=c.call("sandbox_catalog",{"kind":"vehicles","query":"Jeep","limit":10})
    preset=next(p for p in vehicles["items"] if p["id"]=="Jeep")
    rings={p["label"]:p for p in gate if p["label"].startswith("gate-ring")}
    answers=["Chromatic gate laboratory",str(sum(p["physics"]["frozen"] for p in gate)),str(round(total-chassis["physics"]["mass"])),str(round(chassis["physics"]["mass"]/total*100)),max(marker,key=lambda p:p["pos"][2])["label"],",".join(map(str,min(marker,key=lambda p:p["pos"][2])["color"])),str(round(abs(rings["gate-ring-1"]["pos"][0]-rings["gate-ring-2"]["pos"][0]))),oil["items"][0]["model"],"Yes" if preset["class"]==chassis["class"] else "No",str(sum(not p["physics"]["frozen"] for p in rover))]
    expected=[p.findtext("answer") for p in ET.parse(ROOT/"tests/evaluation.xml").getroot().findall("qa_pair")]
    assert answers==expected,{"actual":answers,"expected":expected}
    (ROOT/"artifacts/readonly-evaluation.json").write_text(json.dumps({"passed":10,"answers":answers,"transcript":c.transcript},indent=2))
    print(json.dumps({"passed":10,"answers":answers}))
finally:c.close()
