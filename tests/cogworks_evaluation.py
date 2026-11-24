"""Run against a consented Sandbox host with an open test area near the player."""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from mcp_client import Client, ROOT

def evaluate(client, absent):
    call = client.call
    catalog = call("sandbox_catalog", {"kind": "cogworks"})
    assert catalog["available"] == (not absent), catalog
    scene = call("sandbox_inspect", {"limit": 1})
    assert scene["map"]
    def reject(tool, args, message):
        try:
            call(tool, args)
        except RuntimeError as exc:
            assert message.lower() in str(exc).lower(), exc
        else:
            raise AssertionError(f"{tool} unexpectedly succeeded")
    options = ("mount", "inspect", "connect", "drive")
    if absent:
        for tool in options:
            reject("sandbox_cogworks_" + tool, {}, "optional Cogworks addon unavailable")
        p = call("sandbox_create", {"name": "standalone", "entities": [{"label":"box","model":"models/props_junk/wood_crate001a.mdl"}]})
        call("sandbox_cleanup", {"build_id":p["build_id"]})
        return {"absent": True, "core_create_cleanup": True}
    assert {"crank", "gear", "pedals", "petrol", "differential"} <= {p["kind"] for p in catalog["parts"]}
    x,y,z = scene["player"]["pos"]
    base = call("sandbox_create", {"name":"Mechanical test bench", "origin":[x,y+100,z+50],
        "entities":[{"label":"bench","model":"models/hunter/plates/plate2x2.mdl","frozen":True}]})
    support = base["entities"][0]
    ztop = support["bounds"]["max"][2] - support["pos"][2]
    undo = []
    def mount(**kwargs):
        args = dict(compact=True, **kwargs)
        if "mode" not in args:
            args.update(target=support["ref"], normal=[0,0,1])
        result = call("sandbox_cogworks_mount", args)
        undo.append(result["operation_id"])
        return result
    try:
        crank = mount(kind="crank", teeth=24, point=[0,0,ztop])
        gear = mount(kind="gear", teeth=12, mode="mesh", target=crank["ref"])
        hub = mount(kind="gear", teeth=12, mode="hub", target=gear["ref"])
        assert gear["ratio"] == -2 and hub["ratio"] == 1
        remote = mount(kind="gear", teeth=12, point=[0,28,ztop])
        ids = [p["ref"] for p in (crank,gear,hub,remote)]
        link = call("sandbox_cogworks_connect", {"from":hub["ref"],"to":remote["ref"]})
        undo.append(link["operation_id"])
        state = call("sandbox_cogworks_inspect", {"ref":hub["ref"]})
        assert remote["ref"] in state["neighbors"] and state["sockets"][0]["name"]=="shaft" and state["status"]
        reject("sandbox_cogworks_connect", {"from":hub["ref"],"to":remote["ref"]}, "already")
        reject("sandbox_cogworks_drive", {"ref":gear["ref"]}, "crank")
        readings = []
        for direction in (1,-1):
            call("sandbox_cogworks_drive", {"ref":crank["ref"],"direction":direction,"seconds":3})
            samples = call("sandbox_measure", {"refs":ids,"seconds":2,"interval":0.25})["samples"]
            # A shaft is a torque coupling and may slip transiently. Assert steady direction
            # and angular speed against the rigid meshed/hub pairs in one server tick.
            rpm = [e["cogworks"]["rpm"] for e in samples[-1]["entities"]]
            assert rpm[0]*direction > 1 and abs(rpm[1]/rpm[0]+2)<0.015 and abs(rpm[2]/rpm[1]-1)<0.015, rpm
            assert rpm[3]*rpm[2]>0, rpm
            readings.append(rpm)
        call("sandbox_undo", {"operation_id":undo.pop()})
        assert remote["ref"] not in call("sandbox_cogworks_inspect",{"ref":hub["ref"]})["neighbors"]
        belt=call("sandbox_cogworks_connect", {"from":hub["ref"],"to":remote["ref"],"kind":"belt"})
        undo.append(belt["operation_id"])
        return {"parts_available":catalog["total"],"rpm":readings,"shaft_and_belt":True,"targeted_undo":True}
    finally:
        for op in reversed(undo):
            call("sandbox_undo", {"operation_id":op})
        call("sandbox_cleanup", {"build_id":base["build_id"]})

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--instance", required=True)
    parser.add_argument("--game-dir", required=True)
    parser.add_argument("--absent", action="store_true")
    args = parser.parse_args()
    client = Client(exe=ROOT/"target/release/sandbox-mcp.exe", game_dir=args.game_dir, instance=args.instance)
    try:
        result=evaluate(client,args.absent)
        print(json.dumps(result,indent=2))
    finally:
        client.close()
        (ROOT/"artifacts"/("cogworks-absent.json" if args.absent else "cogworks-live.json")).write_text(json.dumps(client.transcript,indent=2))
