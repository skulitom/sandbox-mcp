"""Install a marked package fixture; keep config isolation in FlowMod's harness."""
import argparse, hashlib, json, shutil, uuid
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
GAME=Path(r'D:\Steam\steamapps\common\GarrysMod\garrysmod')
DATA=GAME/'data/sandbox_mcp_release_test'
ADDONS=GAME/'addons'
MARKER='.sandbox-mcp-release-test'
NAMES=('sandbox_mcp_package_test','sandbox_mcp_release_fixture')

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def install():
    for name in NAMES:
        folder=ADDONS/name
        assert not folder.exists(),f'Archive previous owned test first: {folder}'
        folder.mkdir();(folder/MARKER).write_text(str(ROOT))
    shutil.copy2(ROOT/'release/sandbox-mcp-0.4.0.gma',ADDONS/NAMES[0]/'sandbox-mcp.gma')
    lua=ADDONS/NAMES[1]/'lua';(lua/'autorun').mkdir(parents=True)
    shutil.copy2(ROOT/'tests/flowmod_release_fixture.lua',lua/'autorun/sandbox_mcp_release_test.lua')
    shutil.copy2(ROOT/'tests/flowmod_boundary_fixture.lua',lua/'sandbox_mcp_flowmod_boundary.lua')
    prepare(False)

def prepare(absent):
    files={str(p.relative_to(ROOT/'addon/lua')).replace('\\','/'):digest(p) for p in (ROOT/'addon/lua').rglob('*.lua')}
    if not absent:
        flow=Path(r'C:\DEV\FlowMod\addon\lua')
        files.update({str(p.relative_to(flow)).replace('\\','/'):digest(p) for p in flow.rglob('*.lua')})
    DATA.mkdir(exist_ok=True)
    boot=dict(id=uuid.uuid4().hex,files=files,absent=absent)
    (DATA/'boot.json').write_text(json.dumps(boot))
    print(json.dumps(boot))

def check():
    boot=json.loads((DATA/'boot.json').read_text());ready=json.loads((DATA/'ready.json').read_text())
    assert ready['id']==boot['id'], 'Stale session'
    assert ready['version']=='0.4.0',ready
    assert ready['hashes']==boot['files'], 'Loaded runtime differs from source'
    assert ready['flowmod']==(not boot['absent']) and ready['wiremod']==(not boot['absent']),ready
    dest=ROOT/'artifacts'/('release-0.4-absent-runtime.json' if boot['absent'] else 'release-0.4-runtime.json')
    dest.write_text(json.dumps(ready,indent=2))
    print(f'PASS {len(ready["hashes"])} loaded Lua hashes, current boot, expected optional dependencies, 0.4.0')

def archive():
    # Caller must first verify the owned game has exited.
    dest=ROOT/'artifacts'/('release-fixtures-'+uuid.uuid4().hex[:8]);dest.mkdir()
    for name in NAMES:
        source=(ADDONS/name).resolve()
        assert source.parent==ADDONS.resolve() and (source/MARKER).read_text()==str(ROOT)
        target=(dest/name).resolve();assert target.is_relative_to(ROOT/'artifacts')
        shutil.move(str(source),str(target))
    print(f'Archived both owned fixture folders: {dest}')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['install','absent','check','archive']);a=p.parse_args()
    if a.action=='absent':prepare(True)
    else:globals()[a.action]()
