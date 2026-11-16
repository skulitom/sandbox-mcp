-- Optional FlowMod adapter. Original MIT code; all simulation stays in FlowMod.
local S,H=SandboxMCP,SandboxMCP.handlers
function S.flowmodAvailable()
    return istable(FlowMod) and isfunction(FlowMod.Create) and isfunction(FlowMod.AttachCylinder)
        and isfunction(FlowMod.Configure) and isfunction(FlowMod.Link)
end
local function requireFlow()
    if not S.flowmodAvailable() then error("FlowMod is not installed or loaded; install it separately and restart the map. Other MCP tools work without it.",0) end
    return FlowMod
end
local ranges={pressure={1,200},flow={.1,120},opening={0,1},volume={.1,100},bore={10,100},stroke={8,300}}
local tuning={pump={pressure=true,flow=true},compressor={pressure=true,flow=true},valve={opening=true},
    restrictor={opening=true},relief={pressure=true},airtank={volume=true}}
local function keys(a,allowed)
    if not istable(a) then error("Expected FlowMod settings object",0) end
    for k in pairs(a) do if not allowed[k] then error("Unknown or unsupported FlowMod setting: "..tostring(k),0) end end
end
local function number(k,v,medium)
    local r=ranges[k] return S.number(v,r[1],k=="pressure" and medium=="air" and 20 or r[2])
end
function S.validateFlowPart(p)
    local F=requireFlow() local a=p.flowmod
    keys(a,{kind=true,medium=true,pressure=true,flow=true,opening=true,volume=true,bore=true,stroke=true,anchors=true})
    local def=F.Definitions[a.kind] if not def then error("Unknown FlowMod kind; use sandbox_catalog kind=flowmod",0) end
    if a.medium and a.medium~="oil" and a.medium~="air" then error("FlowMod medium must be oil or air",0) end
    if a.medium and def.medium and a.medium~=def.medium then error("This component has a fixed fluid medium",0) end
    a.medium=def.medium or a.medium or "oil"
    for k in pairs(ranges) do if a[k]~=nil then number(k,a[k],a.medium) end end
    if a.anchors then
        if a.kind~="cylinder" then error("Only cylinders have anchors",0) end
        keys(a.anchors,{a=true,b=true,point_a=true,point_b=true,minimum=true})
        S.vector(a.anchors.point_a or {0,0,0}) S.vector(a.anchors.point_b or {0,0,0})
        if a.anchors.minimum~=nil then S.number(a.anchors.minimum,8,400) end
    end
    if p.preset or p.settings or p.fin3 then error("FlowMod parts use flowmod settings, not preset/settings/fin3",0) end
end
local function component(id,owned)
    local F=requireFlow() local e=S.resolveEntity(id,owned)
    if not F.IsComponent(e) then error("Select a FlowMod component",0) end
    if owned and not F.CanTouch(S.owner,e) then error("FlowMod ownership or server tool permission denied",0) end
    return e
end
local function anchor(e)
    local F=requireFlow() S.resolveEntity(S.entityRef(e),true)
    if not F.CanTouch(S.owner,e) then error("FlowMod anchor permission denied",0) end
    if e:GetClass()~="prop_physics" or IsValid(e:GetParent()) or e:GetPhysicsObjectCount()~=1 or not IsValid(e:GetPhysicsObject()) then
        error("Cylinder anchors require owned, unparented single-body physics props; a frozen prop can serve as ground",0)
    end
    return e:GetPhysicsObject()
end
function S.flowmodAttach(e,a,lookup)
    local F=requireFlow() local ea,eb=lookup(a.a),lookup(a.b)
    local pa,pb=anchor(ea),anchor(eb)
    return F.AttachCylinder(S.owner,e,ea,pa:LocalToWorld(S.vector(a.point_a or {0,0,0})),
        eb,pb:LocalToWorld(S.vector(a.point_b or {0,0,0})),a.minimum)
end
function S.flowmodRead(e)
    if not S.flowmodAvailable() or not FlowMod.IsComponent(e) then return nil end
    local F=FlowMod local assembly=F.AssemblyOf and F.AssemblyOf[e]
    local paused=assembly and assembly.lastSolve and not assembly.lastSolve.ok or false
    local out={kind=e.FlowKind,medium=e.FlowMedium,settings=table.Copy(e.FlowConfig),state=e:GetFlowState(),
        fault=e:GetFlowFault(),paused=paused,ports={},control=(e.FlowKind=="pump" or e.FlowKind=="compressor") and (e.FlowOn and 1 or 0) or e.FlowKind=="valve" and e.FlowDirection or nil}
    for _,port in ipairs(F.Definitions[e.FlowKind].ports) do
        local p={name=port,pressure_bar=e:GetFlowPortPressure(port),flow_lpm=0}
        for hose in pairs(F.Hoses) do if IsValid(hose) then
            local isA=hose:GetEndA()==e and hose:GetPortA()==port
            local isB=hose:GetEndB()==e and hose:GetPortB()==port
            if isA or isB then
                p.hose=S.entityRef(hose) p.connected_to={ref=S.entityRef(isA and hose:GetEndB() or hose:GetEndA()),port=isA and hose:GetPortB() or hose:GetPortA()}
                p.conductance=hose.FlowConductance p.flow_lpm=paused and 0 or hose:GetFlow()*(isA and 60 or -60)
            end
        end end
        out.ports[#out.ports+1]=p
    end
    if e.FlowKind=="airtank" then out.stored_air_standard_litres=e:GetFlowStoredAir() end
    if e.FlowAnchors then
        out.anchors={minimum=e.FlowMinimum}
        for i,k in ipairs({"a","b"}) do local a=e.FlowAnchors[i]
            out.anchors[k]={ref=a.entity:IsWorld() and "world" or S.entityRef(a.entity),point=S.xyz(a.local_pos)}
        end
        local ph=e.FlowPhysics local c=e.FlowNetwork and e.FlowNetwork.cylinders[e.FlowCylinder]
        out.actuator={length_su=ph and ph.length or 0,speed_mps=ph and ph.velocity or 0,force_newtons=not paused and c and c.force or 0}
    end
    return out
end
function S.flowmodCatalog(a)
    local installed=S.flowmodAvailable() local items={}
    if installed then for kind,def in pairs(FlowMod.Definitions) do
        if (kind.." "..def.name):lower():find((a.query or ""):lower(),1,true) then
            items[#items+1]={id=kind,name=def.name,medium=def.medium or "oil or air",ports=def.ports,tunable=tuning[kind] or {}}
        end
    end end
    table.sort(items,function(x,y)return x.id<y.id end)
    return {installed=installed,items=items,total=#items,ranges=ranges,
        limits=installed and {parts_per_player=GetConVar("flowmod_max_parts"):GetInt(),hoses_per_player=GetConVar("flowmod_max_hoses"):GetInt()} or nil,
        help="Create kind=flowmod with flowmod={kind,medium,...}. Starts off/hold and unpressurised. Positions must be within 800 Source units of the player. Oil pressure 1-200 bar; air 1-20 bar. Flow L/min (standard litres for air); bore mm; stroke Source units; tank volume litres. Cylinder anchors a/b are same-batch prop labels, point_a/point_b are local physics-body coordinates; minimum is retracted length in Source units. Frozen props serve as ground. fluid_links connect exact port names; each port accepts one hose, use tees to branch. For oil: reservoir T -> pump T, pump P -> valve P, valve T -> reservoir R1, valve A/B -> cylinder A/B. Air uses compressor, optional tank, valve and exhaust. Tune control=1 to start a source or extend a valve, 0 to stop/hold, -1 to retract a valve. flowmod_inspect and measure report actual native physics. Positive port flow leaves that component. Blueprints save configurations, not pressure or active commands; copied Wire sources can still activate a circuit. Optional Wiremod signals and fluid hoses are different connections."}
end
H.sandbox_flowmod_inspect=function(a)
    requireFlow() local out={}
    for _,e in ipairs(S.buildEntities(a,false)) do
        local data=S.flowmodRead(e) if data then data.ref=S.entityRef(e) out[#out+1]=data end
    end
    return {entities=out,units={pressure="gauge bar",flow="L/min; standard litres for air",force="N",length="Source units",speed="m/s"}}
end
-- Shared transaction for standalone hose batches and atomic scene creation.
function S.flowmodConnect(links,lookup,withUndo)
    local F=requireFlow()
    if not istable(links) or #links<1 or #links>128 then error("Use 1-128 fluid links",0) end
    local planned,used,entities={},{},{}
    for _,l in ipairs(links) do
        keys(l,{a=true,b=true,port_a=true,port_b=true,conductance=true})
        local a,b=lookup(l.a),lookup(l.b)
        component(S.entityRef(a),true) component(S.entityRef(b),true)
        if a==b then error("Choose different fluid components",0) end
        if a.FlowMedium~=b.FlowMedium then error("Oil and air ports cannot be connected",0) end
        for _,ep in ipairs({{a,l.port_a},{b,l.port_b}}) do
            if not table.HasValue(F.Definitions[ep[1].FlowKind].ports,ep[2]) then error("Unknown fluid port; inspect the component",0) end
            used[ep[1]]=used[ep[1]] or {}
            if used[ep[1]][ep[2]] then error("Duplicate fluid port in batch",0) end used[ep[1]][ep[2]]=true
        end
        if l.conductance~=nil then S.number(l.conductance,.001,10) end
        planned[#planned+1]={a=a,b=b,l=l} entities[#entities+1]=a entities[#entities+1]=b
    end
    local hoses={}
    local ok,why=pcall(function() for _,p in ipairs(planned) do hoses[#hoses+1]=F.Link(S.owner,p.a,p.l.port_a,p.b,p.l.port_b,p.l.conductance,true) end end)
    if not ok then for _,h in ipairs(hoses) do if IsValid(h) then h:Remove() end end error("Fluid batch rolled back: "..tostring(why),0) end
    local op
    if withUndo then op=S.operation("fluid hoses",entities,function()
        for _,e in ipairs(entities) do component(S.entityRef(e),true) end
        for _,h in ipairs(hoses) do if not IsValid(h) then error("A fluid hose was removed or replaced; inspect its ports before editing again",0) end end
        for _,h in ipairs(hoses) do h:Remove() end
    end) end
    local out={} for _,h in ipairs(hoses) do out[#out+1]={ref=S.entityRef(h),a=S.entityRef(h:GetEndA()),port_a=h:GetPortA(),b=S.entityRef(h:GetEndB()),port_b=h:GetPortB(),conductance=h.FlowConductance} end
    return {operation_id=op,hoses=out},hoses
end
H.sandbox_flowmod_connect=function(a)return S.flowmodConnect(a.links,function(id)return component(id,true)end,true)end
H.sandbox_flowmod_disconnect=function(a)
    local F=requireFlow() local h=S.resolveEntity(a.ref,false)
    if h:GetClass()~="flowmod_hose" or not F.CanTouch(S.owner,h) then error("Select an owned FlowMod hose",0) end
    local ea,eb=component(S.entityRef(h:GetEndA()),true),component(S.entityRef(h:GetEndB()),true)
    local pa,pb,g=h:GetPortA(),h:GetPortB(),h.FlowConductance
    h:Remove()
    local op=S.operation("disconnect fluid hose",{ea,eb},function()
        component(S.entityRef(ea),true) component(S.entityRef(eb),true)
        F.Link(S.owner,ea,pa,eb,pb,g,true)
    end)
    return {operation_id=op,disconnected=true}
end
local function same(a,b)
    for k,v in pairs(a) do if b[k]~=v then return false end end
    for k,v in pairs(b) do if a[k]~=v then return false end end return true
end
local wireNames={pressure="Pressure",flow="Flow",opening="Opening"}
local function checkSignals(e,settings,control)
    local names={}
    for k in pairs(settings) do if wireNames[k] then names[wireNames[k]]=true end end
    if control~=nil then names[e.FlowKind=="valve" and "Direction" or "On"]=true end
    for name in pairs(names) do if e.Inputs and e.Inputs[name] and IsValid(e.Inputs[name].Src) then error(name.." is Wire-driven; change its source or disconnect the signal first",0) end end
end
local function applyTune(F,e,settings,control)
    -- Configuration and command are one synchronous transaction. No solver tick
    -- runs between them; restore only these fields if an addon vetoes/throws.
    local config,on,direction,state=e.FlowConfig,e.FlowOn,e.FlowDirection,e:GetFlowState()
    local ok,why=pcall(function()
        F.Configure(S.owner,e,settings)
        if control~=nil and not F.Control(S.owner,e,control) then error("FlowMod rejected control",0) end
    end)
    if not ok then
        if IsValid(e) then
            e.FlowConfig=config e.FlowOn=on e.FlowDirection=direction e:SetFlowState(state) F.Dirty=true
        end
        error("FlowMod tuning rolled back: "..tostring(why),0)
    end
end
H.sandbox_flowmod_tune=function(a)
    local F=requireFlow() local e=component(a.ref,true) local settings=a.settings or {}
    keys(settings,tuning[e.FlowKind] or {})
    for k,v in pairs(settings) do number(k,v,e.FlowMedium) end
    local hasControl=e.FlowKind=="pump" or e.FlowKind=="compressor" or e.FlowKind=="valve"
    if a.control~=nil then
        if not hasControl then error("Only pumps, compressors and directional valves accept control",0) end
        S.number(a.control,e.FlowKind=="valve" and -1 or 0,1)
    end
    if next(settings)==nil and a.control==nil then error("Provide settings or control",0) end
    checkSignals(e,settings,a.control)
    local before=table.Copy(e.FlowConfig) local command=e.FlowKind=="valve" and e.FlowDirection or (e.FlowOn and 1 or 0)
    local revision=S.tracked[e].revision
    applyTune(F,e,settings,a.control)
    local after=table.Copy(e.FlowConfig) local applied=e.FlowKind=="valve" and e.FlowDirection or (e.FlowOn and 1 or 0)
    S.tracked[e].revision=revision+1
    local op=S.operation("FlowMod tune",{e},function()
        component(a.ref,true)
        local now=e.FlowKind=="valve" and e.FlowDirection or (e.FlowOn and 1 or 0)
        if S.tracked[e].revision~=revision+1 or not same(e.FlowConfig,after) or now~=applied then error("FlowMod component changed later; undo its later edits first",0) end
        checkSignals(e,settings,a.control)
        local restore={} for k in pairs(settings) do restore[k]=before[k] end
        applyTune(F,e,restore,a.control~=nil and command or nil)
        S.tracked[e].revision=revision
    end)
    return {operation_id=op,ref=a.ref,flowmod=S.flowmodRead(e)}
end
-- Portable graph capture rejects incomplete selections rather than retaining map IDs.
function S.flowmodBlueprint(entities,selected,data)
    if not S.flowmodAvailable() then return end
    local F=FlowMod data.fluid_links={}
    for i,e in ipairs(entities) do if F.IsComponent(e) then
        local spec=table.Copy(e.FlowConfig) spec.kind=e.FlowKind
        if e.FlowAnchors then
            local a,b=e.FlowAnchors[1],e.FlowAnchors[2]
            if not selected[a.entity] or not selected[b.entity] then error("Include both cylinder anchor props when saving a FlowMod blueprint; world anchors are not supported by MCP blueprints",0) end
            spec.anchors={a=selected[a.entity],b=selected[b.entity],point_a=S.xyz(a.local_pos),point_b=S.xyz(b.local_pos),minimum=e.FlowMinimum}
        end
        data.entities[i].kind="flowmod" data.entities[i].flowmod=spec
    end end
    for h in pairs(F.Hoses) do if IsValid(h) then
        local a,b=h:GetEndA(),h:GetEndB()
        if selected[a] or selected[b] then
            if not selected[a] or not selected[b] then error("A fluid hose leaves this selection; include both endpoints using refs",0) end
            data.fluid_links[#data.fluid_links+1]={a=selected[a],b=selected[b],port_a=h:GetPortA(),port_b=h:GetPortB(),conductance=h.FlowConductance}
        end
    end end
end
