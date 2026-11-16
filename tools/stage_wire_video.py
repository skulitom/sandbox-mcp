"""Stage a private filming session, preserving the user's current configuration."""
import json, pathlib, shutil, hashlib, datetime
ROOT=pathlib.Path(__file__).resolve().parents[1]
GAME=pathlib.Path(r'D:\Steam\steamapps\common\GarrysMod\garrysmod')
OUT=ROOT/'artifacts/wire-video'
OUT.mkdir(parents=True,exist_ok=True)
backup=OUT/('session-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
backup.mkdir()
manifest=[]
for name in ['config.cfg','autoexec.cfg','video.txt','videodefaults.txt','server.cfg','listenserver.cfg','mount.cfg']:
    src=GAME/'cfg'/name
    item={'name':name,'existed':src.exists()}
    if src.exists():
        shutil.copy2(src,backup/name)
        item['sha256']=hashlib.sha256(src.read_bytes()).hexdigest()
    manifest.append(item)
(backup/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8',newline='\n')
(OUT/'session.json').write_text(json.dumps({'backup':str(backup)},indent=2),encoding='utf-8',newline='\n')
prior=ROOT/'artifacts/release-session-20261115-010620'
shutil.copytree(prior/'sandbox_mcp_wire_test',GAME/'addons/sandbox_mcp_wire_test')
shutil.copy2(ROOT/'release/sandbox-mcp-0.1.0.gma',GAME/'addons/sandbox_mcp_package_test.gma')
autorun=GAME/'addons/sandbox_mcp_wire_video_fixture/lua/autorun'
autorun.mkdir(parents=True)
shutil.copy2(ROOT/'tests/package_fixture.lua',autorun/'sandbox_mcp_package_fixture.lua')
film=(ROOT/'tests/film_fixture.lua').read_text(encoding='utf-8').replace('sandbox_mcp_film','sandbox_mcp_wire_film')
film=film.replace('local origin=LerpVector', 'local origin=LerpVector')
film=film.replace('return {origin=origin,angles=(Vector(unpack(shot.focus))-origin):Angle()', '''local focus=Vector(unpack(shot.focus))
        if shot.follow then
            local target=Entity(shot.follow)
            if IsValid(target) then
                local delta=target:GetPos()-Vector(unpack(shot.anchor))
                origin=origin+delta focus=focus+delta
            end
        end
        return {origin=origin,angles=(focus-origin):Angle()''')
(autorun/'sandbox_mcp_wire_film.lua').write_text(film,encoding='utf-8',newline='\n')
(ROOT/'tests/wire_film_fixture.lua').write_text(film,encoding='utf-8',newline='\n')
cfg=GAME/'cfg/autoexec.cfg'
with cfg.open('a',encoding='utf-8',newline='\n') as f:f.write('\nbind F8 toggleconsole\n')
print(json.dumps({'backup':str(backup),'staged':True}))
