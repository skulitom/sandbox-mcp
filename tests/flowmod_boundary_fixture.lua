-- Private server-only fault injection. No consent changes; never package.
file.CreateDir("sandbox_mcp_flowmod_test")
local last=(util.JSONToTable(file.Read("sandbox_mcp_flowmod_test/request.json","DATA") or "{}") or {}).id
local originalControl
timer.Create("SandboxMCPFlowModBoundary",.05,0,function()
    local a=util.JSONToTable(file.Read("sandbox_mcp_flowmod_test/request.json","DATA") or "{}") or {}
    if not a.id or a.id==last then return end last=a.id
    local ok,result=pcall(function()
        if a.action=="clear" then
            hook.Remove("CanTool","SandboxMCPFlowDeny") hook.Remove("PlayerSpawnSENT","SandboxMCPFlowDeny")
            if originalControl then FlowMod.Control=originalControl originalControl=nil end
            return true
        elseif a.action=="deny" then
            hook.Add("CanTool","SandboxMCPFlowDeny",function(_,_,tool) if tool=="flowmod" then return false end end)
            return true
        elseif a.action=="deny_spawn" then
            hook.Add("PlayerSpawnSENT","SandboxMCPFlowDeny",function(_,class) if class=="flowmod_component" then return false end end)
            return true
        elseif a.action=="fail_control" then
            originalControl=originalControl or FlowMod.Control
            FlowMod.Control=function(...) local fn=originalControl FlowMod.Control=fn originalControl=nil fn(...) error("Injected after native control") end
            return true
        elseif a.action=="manual" then
            local e=SandboxMCP.resolveEntity(a.ref)
            FlowMod.Configure(SandboxMCP.owner,e,{pressure=a.pressure}) return true
        elseif a.action=="pause" then
            local e=SandboxMCP.resolveEntity(a.ref) local asm=FlowMod.AssemblyOf[e]
            asm.buildError="Injected test assembly fault" asm.nextAttempt=nil return true
        elseif a.action=="repair" then FlowMod.Dirty=true return true
        end
        error("Unknown private FlowMod boundary action")
    end)
    file.Write("sandbox_mcp_flowmod_test/response.json",util.TableToJSON({id=a.id,ok=ok,result=ok and result or tostring(result)}))
end)
