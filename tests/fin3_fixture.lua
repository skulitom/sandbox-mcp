-- PRIVATE adversarial integration fixture. Never package under addon/.
if SERVER then AddCSLuaFile() end
if CLIENT then
    timer.Simple(3,function()
        net.Start("sandbox_mcp_consent") net.WriteBool(true) net.WriteBool(true) net.WriteBool(true) net.SendToServer()
        gui.HideGameUI()
    end)
    return
end
file.CreateDir("sandbox_mcp_fin3_test")
local last=(util.JSONToTable(file.Read("sandbox_mcp_fin3_test/request.json","DATA") or "{}") or {}).id
timer.Create("SandboxMCPFinFixture",0.05,0,function()
    local a=util.JSONToTable(file.Read("sandbox_mcp_fin3_test/request.json","DATA") or "{}")
    if not a.id or a.id==last then return end last=a.id
    local ok,result=pcall(function()
        local p=player.GetHumans()[1]
        if a.action=="stats" then
            local out={fins=Fin3.playerFinCount[p] or 0,propellers=Fin3.playerPropellerCount[p] or 0}
            if a.ref then
                local e=SandboxMCP.resolveEntity(a.ref) local ph=e:GetPhysicsObject()
                local linear,angular=ph:GetDamping() out.physics={drag=ph:IsDragEnabled(),linear=linear,angular=angular}
            end
            return out
        elseif a.action=="deny" then
            if a.enabled then hook.Add("CanTool","SandboxMCPFinDeny",function(_,_,tool) if tool=="fin3" or tool=="fin3_propeller" then return false end end)
            else hook.Remove("CanTool","SandboxMCPFinDeny") end
            return true
        elseif a.action=="fail_once" then
            local original=Fin3.fin.new local n=0
            Fin3.fin.new=function(...)
                n=n+1
                if n==2 then Fin3.fin.new=original error("Injected native fin creation failure") end
                return original(...)
            end
            return true
        elseif a.action=="manual_camber" then
            local e=SandboxMCP.resolveEntity(a.ref) Fin3.fins[e].camber=a.camber
            return true
        elseif a.action=="parent" then
            local e=SandboxMCP.resolveEntity(a.ref)
            e:SetParent(a.to and SandboxMCP.resolveEntity(a.to) or NULL)
            return true
        elseif a.action=="flatgrass" then RunConsoleCommand("changelevel","gm_flatgrass") return true
        elseif a.action=="quit" then RunConsoleCommand("quit") return true
        end
        error("Unknown private Fin test action")
    end)
    file.Write("sandbox_mcp_fin3_test/response.json",util.TableToJSON({id=a.id,ok=ok,result=ok and result or tostring(result)}))
end)
