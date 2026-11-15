-- PRIVATE integration fixture. Not included in addon/ or Workshop packages.
if SERVER then
    AddCSLuaFile() util.AddNetworkString("SandboxMCPWorkflowConsent")
    file.CreateDir("sandbox_mcp_workflow_test")
    local last,manual
    timer.Create("SandboxMCPWorkflowFixture",0.1,0,function()
        local a=util.JSONToTable(file.Read("sandbox_mcp_workflow_test/request.json","DATA") or "{}")
        if not a.id or a.id==last then return end last=a.id
        local p=player.GetHumans()[1] if not IsValid(p) then return end
        local ok,result=pcall(function()
            if a.action=="permissions" then net.Start("SandboxMCPWorkflowConsent") net.WriteBool(a.e2==true) net.Send(p) return true end
            if a.action=="manual" then
                manual={}
                for i=1,2 do
                    local e=ents.Create("prop_physics") e:SetModel("models/props_c17/oildrum001.mdl") e:SetPos(Vector(500+i*45,250,-80)) e:SetCreator(p) e:Spawn() e:GetPhysicsObject():EnableMotion(false) manual[i]=e
                end
                constraint.Weld(manual[1],manual[2],0,0,0,true,false)
                return {refs={SandboxMCP.entityRef(manual[1]),SandboxMCP.entityRef(manual[2])}}
            end
            if a.action=="grant" then return {build_id=SandboxMCP.grantAssembly(p,manual[1])} end
            if a.action=="revoke" then SandboxMCP.revokeGrants() return true end
            if a.action=="cleanup" then for _,e in ipairs(manual or {}) do if IsValid(e) then e:Remove() end end return true end
            if a.action=="fail_wire" then
                local original=WireLib.Link_End local count=0
                WireLib.Link_End=function(...) count=count+1 if count==2 then WireLib.Link_End=original error("Injected Wire link failure") end return original(...) end
                return true
            end
            error("Unknown private fixture action")
        end)
        file.Write("sandbox_mcp_workflow_test/response.json",util.TableToJSON({id=a.id,ok=ok,result=ok and result or tostring(result)}))
    end)
else
    net.Receive("SandboxMCPWorkflowConsent",function()
        local e2=net.ReadBool()
        net.Start("sandbox_mcp_consent") net.WriteBool(true) net.WriteBool(true) net.WriteBool(e2) net.SendToServer()
    end)
end
