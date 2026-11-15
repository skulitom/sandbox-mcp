-- Private cinematic camera/capture fixture. Never included in the Workshop GMA.
local folder="sandbox_mcp_film"
if SERVER then
    AddCSLuaFile() util.AddNetworkString("SandboxMCPFilm") file.CreateDir(folder)
    local last
    timer.Create("SandboxMCPFilmPoll",0.1,0,function()
        local a=util.JSONToTable(file.Read(folder.."/shot.json","DATA") or "{}")
        if not a.id or a.id==last then return end last=a.id
        local p=player.GetHumans()[1] if not IsValid(p) then return end
        p:SetMoveType(MOVETYPE_NOCLIP) p:SetPos(Vector(unpack(a.from))-Vector(0,0,64)) p:GodEnable()
        net.Start("SandboxMCPFilm") net.WriteTable(a) net.Send(p)
    end)
    hook.Add("SetupPlayerVisibility","SandboxMCPFilmPVS",function()
        local a=util.JSONToTable(file.Read(folder.."/shot.json","DATA") or "{}")
        if a.from then AddOriginToPVS(Vector(unpack(a.from))) end
        if a.to then AddOriginToPVS(Vector(unpack(a.to))) end
    end)
else
    local shot,frame,ready
    net.Receive("SandboxMCPFilm",function()
        shot=net.ReadTable() frame=0 ready=CurTime()+1
        RunConsoleCommand("host_framerate","30")
        RunConsoleCommand("cl_drawhud","0") RunConsoleCommand("r_drawviewmodel","0")
        RunConsoleCommand("gmod_drawhelp","0") gui.HideGameUI()
        file.CreateDir(folder.."/"..shot.name)
    end)
    hook.Add("CalcView","SandboxMCPFilmCamera",function()
        if not shot then return end
        local t=math.Clamp(frame/(shot.duration*30),0,1) local ease=t*t*(3-2*t)
        local origin=LerpVector(ease,Vector(unpack(shot.from)),Vector(unpack(shot.to or shot.from)))
        return {origin=origin,angles=(Vector(unpack(shot.focus))-origin):Angle(),fov=shot.fov or 65,drawviewer=false}
    end)
    hook.Add("PostRender","SandboxMCPFilmCapture",function()
        if not shot or CurTime()<ready or gui.IsGameUIVisible() then return end
        local data=render.Capture({format="jpeg",quality=97,x=0,y=0,w=ScrW(),h=ScrH()})
        if not data then return end
        file.Write(string.format(folder.."/%s/frame_%05d.jpg",shot.name,frame),data)
        frame=frame+1
        if frame%10==0 then file.Write(folder.."/progress.json",util.TableToJSON({id=shot.id,frame=frame})) end
        if frame>=shot.duration*30 then
            file.Write(folder.."/done.json",util.TableToJSON({id=shot.id,name=shot.name,frames=frame,width=ScrW(),height=ScrH(),fps=30}))
            shot=nil RunConsoleCommand("host_framerate","0") RunConsoleCommand("cl_drawhud","1") RunConsoleCommand("r_drawviewmodel","1")
        end
    end)
end
