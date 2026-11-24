"""Retain dependency copyright/license notices in the portable distribution."""
import json
import pathlib
import subprocess

ROOT=pathlib.Path(__file__).resolve().parents[1]
meta=json.loads(subprocess.check_output(["cargo","metadata","--format-version","1","--locked","--filter-platform","x86_64-pc-windows-msvc"],cwd=ROOT))
sections=["# Third-party notices\n\nSandbox MCP uses the following open-source dependencies.\nThe application itself is MIT licensed. Dependency licenses follow.\n"]
missing=[]
for package in sorted(meta["packages"],key=lambda p:p["name"]):
    if package["name"]=="sandbox-mcp":continue
    folder=pathlib.Path(package["manifest_path"]).parent
    candidates=[p for p in folder.iterdir() if p.is_file() and p.name.upper().startswith(("LICENSE","LICENCE","COPYING","NOTICE"))]
    sections.append(f"\n## {package['name']} {package['version']}\n\nDeclared license: {package.get('license','unspecified')}\n")
    if package.get("repository"):sections.append("Repository: "+package["repository"]+"\n")
    for p in sorted(candidates):sections.append(f"\n### {p.name}\n\n```text\n{p.read_text(encoding='utf-8',errors='replace')}\n```\n")
    if not candidates:missing.append(package["name"])
metadata_version = next(p["version"] for p in meta["packages"] if p["name"] == "sandbox-mcp")
target=ROOT/f"release/sandbox-mcp-{metadata_version}-windows-x64/THIRD-PARTY-NOTICES.md"
target.parent.mkdir(parents=True,exist_ok=True)
target.write_text("\n".join(sections),encoding="utf-8")
print(json.dumps({"path":str(target),"packages":len(meta["packages"])-1,"missing_license_files":missing}))
if missing:raise SystemExit(1)
