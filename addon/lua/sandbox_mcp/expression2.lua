-- Explicit opt-in: E2 retains Wiremod's normal player permissions and quotas.
local S,H=SandboxMCP,SandboxMCP.handlers
function S.requireE2Consent()
    if not S.e2Allowed then error("Expression 2 is off. The host can enable E2 code access in Q > Utilities > Sandbox MCP, then reconnect.",0) end
    if not E2Lib or not E2Lib.Compiler then error("Wiremod Expression 2 is unavailable",0) end
end
local function message(err)
    if istable(err) then return tostring(err.message or (err[1] and err[1].message) or "Compilation failed") end
    return tostring(err)
end
function S.validateE2(code)
    if not isstring(code) or #code<1 or #code>32768 then return {valid=false,error="Code must contain 1–32768 bytes"} end
    if not E2Lib or not E2Lib.Compiler then return {valid=false,error="Wiremod Expression 2 is unavailable"} end
    local ok,directives,buffer=E2Lib.PreProcessor.Execute(code)
    if not ok then return {valid=false,error=message(directives)} end
    local ok,tokens=E2Lib.Tokenizer.Execute(buffer)
    if not ok then return {valid=false,error=message(tokens)} end
    local ok,tree,dvars,files=E2Lib.Parser.Execute(tokens)
    if not ok then return {valid=false,error=message(tree)} end
    if files and #files>0 then return {valid=false,error="External includes are not supported; supply a self-contained chip"} end
    local ok,script,compiler=E2Lib.Compiler.Execute(tree,directives,dvars,{})
    if not ok then return {valid=false,error=message(script)} end
    local warnings={} for _,w in ipairs(compiler.warnings or {}) do warnings[#warnings+1]=message(w) end
    return {valid=true,name=directives.name,inputs=directives.inputs[1],input_types=directives.inputs[2],outputs=directives.outputs[1],output_types=directives.outputs[2],warnings=warnings}
end
function S.setupE2(e,code,run)
    if not e.SandboxMCPOriginalError then
        e.SandboxMCPOriginalError=e.Error
        e.Error=function(self,msg,overlay) self.SandboxMCPError=tostring(msg) return self.SandboxMCPOriginalError(self,msg,overlay) end
    end
    e.SandboxMCPError=nil e.SandboxMCPPaused=false
    e:Setup(code,{},not run,true)
    if not run and not e.error then S.stopE2(e) end
end
function S.stopE2(e)
    e:Destruct() e.error=true e.SandboxMCPPaused=true
    -- Stop actuators as well as timers. Wiremod supplies the neutral value for
    -- each port type; do not leave the previous throttle latched at its input.
    for name,p in pairs(e.Outputs or {}) do
        local datatype=WireLib.DT[p.Type]
        if datatype and datatype.Zero then WireLib.TriggerOutput(e,name,datatype.Zero()) end
    end
end
local function state(e)
    local context=e.context or {}
    return {ref=S.entityRef(e),name=e.name,paused=e.SandboxMCPPaused==true,error=e.SandboxMCPError,running=not e.error,ops=context.prf or 0,average_ops=context.prfcount or 0,cpu_seconds=context.timebench or 0,ports=S.wirePorts(e),code=e.original}
end
H.sandbox_e2=function(a)
    if a.action=="validate" then return S.validateE2(a.code) end
    local e=S.resolveEntity(a.ref,true)
    if e:GetClass()~="gmod_wire_expression2" then error("Select an Expression 2 chip",0) end
    if a.action=="status" then return state(e) end
    if not S.tracked[e] or S.tracked[e].wire~="expression2" then error("Only AI-created E2 chips can be programmed",0) end
    if a.action=="stop" then S.stopE2(e) return state(e) end
    S.requireE2Consent()
    if a.action=="run" then S.setupE2(e,e.original,true) return state(e) end
    if a.action~="upload" then error("action must be validate, upload, run, stop or status",0) end
    local validation=S.validateE2(a.code)
    if not validation.valid then return validation end
    local before=e.original local revision=(S.tracked[e].codeRevision or 0)+1
    -- Reject interface changes while wired; avoids silently dropping circuit links.
    local current=S.validateE2(before)
    local changed=util.TableToJSON({current.inputs,current.input_types,current.outputs,current.output_types})~=util.TableToJSON({validation.inputs,validation.input_types,validation.outputs,validation.output_types})
    if changed then
        for _,p in pairs(e.Inputs or {}) do if IsValid(p.Src) then error("Disconnect the chip before changing its port interface",0) end end
        for _,p in pairs(e.Outputs or {}) do if p.Connected and next(p.Connected) then error("Disconnect the chip before changing its port interface",0) end end
    end
    S.setupE2(e,a.code,false)
    if e.SandboxMCPError then local err=e.SandboxMCPError S.setupE2(e,before,false) error("Upload refused: "..err,0) end
    S.tracked[e].codeRevision=revision S.tracked[e].spec.settings.code=a.code
    local result=state(e)
    result.operation_id=S.operation("E2 code upload",{e},function()
        S.requireE2Consent() S.resolveEntity(S.entityRef(e),true)
        if S.tracked[e].codeRevision~=revision or e.original~=a.code then error("Chip code changed since upload",0) end
        S.setupE2(e,before,false) S.tracked[e].codeRevision=revision-1 S.tracked[e].spec.settings.code=before
    end)
    return result
end
