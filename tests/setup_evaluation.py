"""Exercise the actual local setup HTTP server in isolated user profiles."""
import json
import os
import pathlib
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request

ROOT=pathlib.Path(__file__).resolve().parents[1]
checks=[]
def check(name,condition):
    assert condition,name
    checks.append(name)
with tempfile.TemporaryDirectory(prefix="sandbox-mcp-setup-") as folder:
    root=pathlib.Path(folder)
    target=root/"roaming/Claude/claude_desktop_config.json"
    target.parent.mkdir(parents=True)
    original={"theme":"dark","mcpServers":{"existing":{"command":"keep-me","env":{"KEY":"test-sentinel"}}}}
    target.write_text(json.dumps(original))
    proc=subprocess.Popen([os.environ.get("SANDBOX_MCP_EXE",str(ROOT/"target/debug/sandbox-mcp.exe")),"setup","--no-browser","--profile-root",folder],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        url=json.loads(proc.stdout.readline())["setup_url"]
        origin=urllib.parse.urlsplit(url)
        origin=f"{origin.scheme}://{origin.netloc}"
        def request(route,body=None,valid_origin=True,base=url):
            headers={"Origin":origin if valid_origin else "https://untrusted.example"}
            if body is not None: headers["Content-Type"]="application/json"
            req=urllib.request.Request(base+route,data=json.dumps(body).encode() if body is not None else None,headers=headers)
            try:
                with urllib.request.urlopen(req,timeout=5) as r:return r.status,r.read()
            except urllib.error.HTTPError as e:return e.code,e.read()
        status,page=request("")
        check("Wizard served locally",status==200 and b"Your ideas." in page)
        status,data=request("api/state")
        state=json.loads(data)
        check("Five supported client profiles",len(state["clients"])==5)
        check("Wrong-origin install refused",request("api/install",{"client":"claude"},False)[0]==403)
        check("Wrong-token access refused",request("api/state",base=origin+"/wrong-token/")[0]==403)
        for client in ["claude","codex","cursor","copilot","vscode"]:
            status,raw=request("api/install",{"client":client})
            check(client+" install",status==200)
            result=json.loads(raw)
            check(client+" stable companion exists",pathlib.Path(result["installed_path"]).is_file())
            check(client+" repeat is idempotent",json.loads(request("api/install",{"client":client})[1])["backup"] is None)
        actual=json.loads(target.read_text())
        check("Other servers preserved",actual["mcpServers"]["existing"]==original["mcpServers"]["existing"])
        check("Other settings preserved",actual["theme"]=="dark")
        backups=list(target.parent.glob("*.bak"))
        check("Original configuration backed up",len(backups)==1 and json.loads(backups[0].read_text())==original)
        unknown=request("api/install",{"client":"../../not-allowed"})
        check("Unknown/path-like client refused",unknown[0]==400)
        request("api/close",{})
        proc.wait(timeout=5)
        check("Wizard closes cleanly",proc.returncode==0)
    finally:
        if proc.poll() is None:proc.kill();proc.wait()
(ROOT/"artifacts/setup-evaluation.json").write_text(json.dumps({"checks":checks},indent=2))
print(json.dumps({"passed":len(checks),"checks":checks},indent=2))
