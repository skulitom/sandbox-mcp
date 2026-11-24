import json
import pathlib
import sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/"tools"))
from mcp_client import Client, ROOT

checks=[]
for version in ["2025-03-26","2025-11-25","2026-07-28"]:
    c=Client(version=version)
    try:
        if version >= "2026-07-28":assert version in c.initialized["supportedVersions"],c.initialized
        else:assert c.initialized["protocolVersion"]==version,c.initialized
        result=c.request("tools/list",{})
        names={t["name"] for t in result["tools"]}
        assert len(names)==35 and len(result["tools"])==35
        assert {"sandbox_flowmod_inspect","sandbox_flowmod_connect","sandbox_flowmod_disconnect","sandbox_flowmod_tune"}<=names
        assert {"sandbox_cogworks_mount","sandbox_cogworks_connect","sandbox_cogworks_inspect","sandbox_cogworks_drive"}<=names
        if version=="2026-07-28":
            assert result["resultType"]=="complete"
            assert result["ttlMs"]==0
        status=c.call("sandbox_status")
        assert status["version"]=="0.5.0"
        checks.append({"protocol":version,"lifecycle":"discovery" if version>="2026-07-28" else "initialize","tools":len(result["tools"]),"structured_result":True})
    finally:c.close()
(ROOT/"artifacts/protocol-evaluation.json").write_text(json.dumps(checks,indent=2))
print(json.dumps(checks,indent=2))
