"""Adversarial local mailbox checks plus real MCP concurrency/version checks."""
import concurrent.futures
import json
import os
import pathlib
import sys
import time
import uuid
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/"tools"))
from mcp_client import Client, ROOT

checks=[]
c=Client()
def check(name,condition):
    assert condition,name
    checks.append(name)
try:
    status=c.call("sandbox_status")
    sessions=[s for s in status["instances"] if s["connected"]]
    assert len(sessions)==1
    session=sessions[0]
    root=pathlib.Path(status["game_dir"])/"data/sandbox_mcp/instances"/session["instance"]
    token=json.loads((root/"auth.json").read_text())["token"]
    payload={"name":"Transport evaluation","origin":[550,350,-130],"entities":[{"label":"test","model":"models/hunter/blocks/cube025x025x025.mdl"}]}
    def raw_request(**overrides):
        packet={"id":str(uuid.uuid4()),"instance":session["instance"],"token":token,"expires":int(time.time())+25,"tool":"sandbox_create","args":payload}
        packet.update(overrides)
        tmp=root/"requests"/(packet["id"]+".tmp")
        dest=tmp.with_suffix(".json")
        tmp.write_text(json.dumps(packet));os.replace(tmp,dest)
        result=root/"responses"/(packet["id"]+".json")
        end=time.monotonic()+5
        while not result.exists() and time.monotonic()<end:time.sleep(.04)
        data=json.loads(result.read_text());result.unlink()
        return data
    before=c.call("sandbox_inspect",{"owned_only":True})["total"]
    check("Wrong token rejected",raw_request(token="invalid")["ok"] is False)
    check("Wrong instance rejected",raw_request(instance="0"*24)["ok"] is False)
    check("Expired command rejected",raw_request(expires=int(time.time())-5)["ok"] is False)
    check("Future expiry rejected",raw_request(expires=int(time.time())+500)["ok"] is False)
    check("Invalid commands did not create entities",c.call("sandbox_inspect",{"owned_only":True})["total"]==before)
    result=c.call("sandbox_create",payload)
    repeated=raw_request(id=result["request_id"])
    check("Duplicate UUID returns original result",repeated["ok"] and repeated["data"]["build_id"]==result["build_id"])
    check("Duplicate UUID executes once",c.call("sandbox_inspect",{"owned_only":True})["total"]==before+1)
    stale=result["entities"][0]["ref"].split(":")
    stale[0]="0"*24
    response=c.request("tools/call",{"name":"sandbox_edit","arguments":{"items":[{"ref":":".join(stale),"mass":10}]}})
    check("Cross-session entity refs rejected",response.get("isError") is True)
    c.call("sandbox_cleanup",{"build_id":result["build_id"]})
    def worker(index):
        client=Client()
        try:return client.call("sandbox_inspect",{"owned_only":True})["total"]
        finally:client.close()
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        results=list(pool.map(worker,range(6)))
    check("Six simultaneous MCP clients get correct responses",results==[before]*6)
    print(json.dumps({"passed":len(checks),"checks":checks},indent=2))
finally:
    (ROOT/"artifacts/transport-evaluation.json").write_text(json.dumps({"checks":checks,"transcript":c.transcript},indent=2))
    c.close()
