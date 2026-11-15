"""Development/evaluation client. Talks real MCP stdio; no direct game-file commands.

Users run the portable Rust companion with their own MCP client; Python is only
used by this repository's repeatable protocol tests and dogfooding harness.
"""
import argparse
import base64
import json
import os
import pathlib
import queue
import subprocess
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]

class Client:
    def __init__(self, exe=None, game_dir=None, instance=None, version="2025-11-25"):
        args = [str(exe or os.environ.get("SANDBOX_MCP_EXE") or ROOT / "target/debug/sandbox-mcp.exe"), "serve"]
        if game_dir: args += ["--game-dir", str(game_dir)]
        if instance: args += ["--instance", instance]
        self.process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8")
        self.responses = queue.Queue()
        self.counter = 0
        self.transcript = []
        self.version = version
        def reader():
            for line in self.process.stdout:
                try: self.responses.put(json.loads(line))
                except ValueError: self.responses.put({"invalid_stdout": line})
            self.responses.put({"closed": True})
        threading.Thread(target=reader, daemon=True).start()
        if version >= "2026-07-28":
            self.initialized = self.request("server/discover", {})
        else:
            self.initialized = self.request("initialize", {"protocolVersion":version, "capabilities":{}, "clientInfo":{"name":"sandbox-mcp-evaluation","version":"0.1.0"}})
            self.send({"jsonrpc":"2.0","method":"notifications/initialized"})

    def send(self, value):
        self.process.stdin.write(json.dumps(value, separators=(",", ":")) + "\n")
        self.process.stdin.flush()

    def request(self, method, params):
        self.counter += 1
        if self.version >= "2026-07-28":
            params={**params,"_meta":{
                "io.modelcontextprotocol/protocolVersion":self.version,
                "io.modelcontextprotocol/clientInfo":{"name":"sandbox-mcp-evaluation","version":"0.1.0"},
                "io.modelcontextprotocol/clientCapabilities":{},
                "io.modelcontextprotocol/logLevel":"error"}}
        request = {"jsonrpc":"2.0", "id":self.counter, "method":method, "params":params}
        start = time.monotonic()
        self.send(request)
        while True:
            response = self.responses.get(timeout=40)
            if "closed" in response or "invalid_stdout" in response: raise RuntimeError(response)
            if response.get("id") == self.counter: break
        if "error" in response: raise RuntimeError(response["error"])
        result = response["result"]
        log_result = json.loads(json.dumps(result))
        for content in log_result.get("content", []):
            if content.get("type") == "image": content["data"] = f"<{len(content['data'])} base64 characters>"
        self.transcript.append({"request": request, "elapsed_ms": round((time.monotonic()-start)*1000), "result":log_result})
        return result

    def call(self, name, args=None, image_path=None):
        result = self.request("tools/call", {"name":name,"arguments":args or {}})
        for content in result.get("content", []):
            if content.get("type") == "image":
                if image_path:
                    pathlib.Path(image_path).parent.mkdir(parents=True, exist_ok=True)
                    pathlib.Path(image_path).write_bytes(base64.b64decode(content["data"]))
                content["data"] = "<image saved>" if image_path else "<image omitted>"
        if result.get("isError"): raise RuntimeError(result)
        return result.get("structuredContent", result)

    def close(self):
        self.process.stdin.close()
        try: self.process.wait(timeout=3)
        except subprocess.TimeoutExpired: self.process.kill(); self.process.wait()

if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("tool", nargs="?", default="sandbox_status")
    parser.add_argument("--args", default="{}")
    parser.add_argument("--file")
    parser.add_argument("--image")
    parser.add_argument("--log")
    parser.add_argument("--instance")
    options=parser.parse_args()
    client=Client(instance=options.instance)
    try:
        arguments=json.loads(pathlib.Path(options.file).read_text(encoding="utf-8-sig") if options.file else options.args)
        result=client.request("tools/list", {}) if options.tool=="list" else client.call(options.tool, arguments, options.image)
        print(json.dumps(result,indent=2))
    finally:
        if options.log: pathlib.Path(options.log).write_text(json.dumps(client.transcript,indent=2),encoding="utf-8")
        client.close()
