-- PRIVATE packaged-release fixture. Never include this in addon/.
if SERVER then AddCSLuaFile() end
if CLIENT then
    timer.Simple(4,function()
        net.Start("sandbox_mcp_consent")
        net.WriteBool(true) net.WriteBool(true) net.WriteBool(true)
        net.SendToServer()
        gui.HideGameUI()
    end)
    return
end
include("sandbox_mcp_flowmod_boundary.lua")
file.CreateDir("sandbox_mcp_release_test")
local boot = util.JSONToTable(file.Read("sandbox_mcp_release_test/boot.json","DATA") or "{}")
hook.Add("PlayerInitialSpawn","SandboxMCPReleasePose",function(p)
    timer.Simple(2,function()
        if not IsValid(p) then return end
        p:SetPos(Vector(480,280,-80)) p:SetEyeAngles(Angle(15,95,0))
        p:SetMoveType(MOVETYPE_NOCLIP) p:GodEnable()
        local hashes = {}
        for name in pairs(boot.files or {}) do
            local body = file.Read(name,"LUA")
            hashes[name] = body and util.SHA256(body) or false
        end
        file.Write("sandbox_mcp_release_test/ready.json",util.TableToJSON({
            id=boot.id, version=SandboxMCP and SandboxMCP.version,
            flowmod=FlowMod~=nil, wiremod=WireLib~=nil, hashes=hashes,
            map=game.GetMap(), player=tostring(p:SteamID64())
        },true))
    end)
end)
