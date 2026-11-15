-- Optional adapter. Wiremod remains a separate addon; none of its code is bundled.
local S = SandboxMCP
local H = S.handlers
local presets = {
    constant={class="gmod_wire_value",model="models/jaanus/wiretool/wiretool_input.mdl",description="One numeric output named 1. settings.value defaults to 0."},
    button={class="gmod_wire_button",model="models/props_c17/clock01.mdl",description="Toggle button: Set input, Out output. settings.off/on default 0/1. Use E in game or wire_set 0/1."},
    gate={class="gmod_wire_gate",model="models/jaanus/wiretool/wiretool_gate.mdl",description="Logic/arithmetic/timed gate. settings.action selects an action from this catalog."},
    thruster={class="gmod_wire_thruster",model="models/props_c17/lampShade001a.mdl",description="A input drives thrust along local -Z (angles [180,0,0] pushes upward). settings.force defaults 1500 (1..10000); multiplier clamped to 0..1."},
    indicator={class="gmod_wire_indicator",model="models/hunter/blocks/cube025x025x025.mdl",description="A input interpolates red at 0 to green at 1. settings.low_color/high_color are RGB triples."},
    screen={class="gmod_wire_screen",model="models/props_lab/monitor01b.mdl",description="Numeric A/B inputs. settings.text_a/text_b label the screen."},
    speedometer={class="gmod_wire_speedometer",model="models/jaanus/wiretool/wiretool_speed.mdl",description="Live Out (Source units/sec), MPH and KPH outputs. Weld to a vehicle."},
    gps={class="gmod_wire_gps",model="models/jaanus/wiretool/wiretool_range.mdl",description="Live X/Y/Z and Vector position outputs."},
    expression2={class="gmod_wire_expression2",model="models/beer/wiremod/gate_e2.mdl",description="Expression 2 chip. settings.code compiles paused. Host must enable E2 code access; use sandbox_e2 to validate, upload, run, stop and inspect."},
    gyroscope={class="gmod_wire_gyroscope",model="models/jaanus/wiretool/wiretool_siren.mdl",description="Signed Pitch/Yaw/Roll and typed Angle outputs; weld to a vehicle for attitude feedback."},
    ranger={class="gmod_wire_ranger",model="models/jaanus/wiretool/wiretool_range.mdl",description="Distance sensor along local +Z. settings.range defaults 1024; show_beam defaults true. Dist, Pos, HitNormal and RangerData outputs."}
}
local allowedGates = {"+","-","*","/","abs","negate","clamp","=","<",">","and","or","not","sin","cos","timer","squarepulse","sawpulse"}
function S.wireAvailable() return WireLib~=nil and isfunction(WireLib.Link_Start) and scripted_ents.GetStored("gmod_wire_value")~=nil end
local function requireWire()
    if not S.wireAvailable() then error("Wiremod is not installed or loaded. Subscribe to Wiremod (Workshop 160250458), restart the map, then try again. Other Sandbox MCP tools work without it.",0) end
end
function S.wireCatalog(a)
    local query=string.lower(a.query or "") local items={}
    for id,p in pairs(presets) do
        if (id.." "..p.description):lower():find(query,1,true) then items[#items+1]={id=id,kind="component",class=p.class,model=p.model,description=p.description} end
    end
    if S.wireAvailable() then
        for _,id in ipairs(allowedGates) do
            local g=GateActions and GateActions[id]
            if g and not g.is_banned and (id.." "..g.name):lower():find(query,1,true) then
                items[#items+1]={id=id,kind="gate_action",name=g.name,inputs=g.inputs,outputs=g.outputs or {"Out"},timed=g.timed==true}
            end
        end
    end
    table.sort(items,function(a,b)return a.kind..a.id<b.kind..b.id end)
    local offset,limit=math.floor(S.number(a.offset or 0,0,100000)),math.floor(S.number(a.limit or 40,1,40))
    local page={} for i=offset+1,math.min(#items,offset+limit) do page[#page+1]=items[i] end
    return {installed=S.wireAvailable(),workshop_url="https://steamcommunity.com/sharedfiles/filedetails/?id=160250458",items=page,total=#items,next_offset=offset+#page<#items and offset+#page or nil,
        help="Create with kind=wire, preset=id and settings. Use wire_links in create or sandbox_wire_batch for complete circuits. E2 requires separate host permission and compiles paused; no arbitrary Wire entity spawning."}
end
function S.wireClass(preset) return presets[preset].class end
function S.validateWirePart(p)
    requireWire()
    local spec=presets[p.preset] if not spec then error("Unknown Wire preset; use sandbox_catalog kind=wire",0) end
    if not scripted_ents.GetStored(spec.class) then error("Wire component is unavailable: "..p.preset,0) end
    p.model=(p.model or spec.model):lower()
    if p.model:find("..",1,true) or p.model:find(":",1,true) or p.model:find("\\",1,true) or not util.IsValidProp(p.model) then error("Invalid Wire physics model",0) end
    if hook.Run("PlayerSpawnSENT",S.owner,spec.class)==false or hook.Run("PlayerSpawnProp",S.owner,p.model)==false then error("Server denied Wire component",0) end
    local q=p.settings or {} if not istable(q) then error("Wire settings must be an object",0) end
    local allowed={constant={value=true},button={off=true,on=true},gate={action=true},thruster={force=true},indicator={low_color=true,high_color=true},screen={text_a=true,text_b=true},speedometer={},gps={},expression2={code=true},gyroscope={},ranger={range=true,show_beam=true}}
    for key in pairs(q) do if not allowed[p.preset][key] then error("Unsupported setting "..tostring(key).." for "..p.preset,0) end end
    for _,key in ipairs({"value","off","on"}) do if q[key]~=nil then S.number(q[key],-1000000,1000000) end end
    if q.force~=nil then S.number(q.force,1,10000) end
    if q.range~=nil then S.number(q.range,1,65536) end
    if q.show_beam~=nil and not isbool(q.show_beam) then error("show_beam must be boolean",0) end
    for _,key in ipairs({"low_color","high_color"}) do if q[key] then if not istable(q[key]) or #q[key]~=3 then error("Color must be RGB",0) end for _,n in ipairs(q[key]) do S.number(n,0,255) end end end
    for _,key in ipairs({"text_a","text_b"}) do if q[key] and (not isstring(q[key]) or #q[key]>64) then error("Screen label must be at most 64 characters",0) end end
    if p.preset=="gate" then
        local g=GateActions and GateActions[q.action]
        if not table.HasValue(allowedGates,q.action) or not g or g.is_banned then error("Unsupported or banned gate; use sandbox_catalog kind=wire",0) end
    end
    if p.preset=="expression2" then
        S.requireE2Consent()
        local result=S.validateE2(q.code or "@name MCP chip\n@outputs Out\nOut = 0")
        if not result.valid then error("E2 compile error: "..result.error,0) end
    end
    p.settings=q
end
function S.setupWirePart(e,p)
    local limit=p.preset=="expression2" and "wire_expressions" or e:GetClass():sub(6).."s"
    if not S.owner:CheckLimit(limit) then error("Wiremod component limit reached",0) end
    e:SetPlayer(S.owner)
    local q=p.settings
    if p.preset=="constant" then e:Setup({{DataType="NORMAL",Value=tostring(q.value or 0)}})
    elseif p.preset=="button" then e:Setup(true,q.off or 0,q.on or 1,"",false)
    elseif p.preset=="gate" then e:Setup(q.action,false)
    elseif p.preset=="thruster" then e:Setup(q.force or 1500,0,1,"fire","same",true,true,false,"")
    elseif p.preset=="indicator" then local a,b=q.low_color or {235,50,70},q.high_color or {30,240,170} e:Setup(0,a[1],a[2],a[3],255,1,b[1],b[2],b[3],255)
    elseif p.preset=="screen" then e:Setup(false,false,q.text_a or "Signal A",q.text_b or "Signal B",false,false,true,false)
    elseif p.preset=="speedometer" then e:Setup(false,false)
    elseif p.preset=="gps" then e:Setup()
    elseif p.preset=="expression2" then S.setupE2(e,q.code or "@name MCP chip\n@outputs Out\nOut = 0",false)
    elseif p.preset=="gyroscope" then e:Setup(true)
    elseif p.preset=="ranger" then e:Setup(q.range or 1024,false,q.show_beam~=false,false,false,true,true,false,false,false,false,false,false,false,true,false) end
    S.owner:AddCount(limit,e) S.owner:AddCleanup("sents",e)
end
local function wireEntity(id,owned)
    requireWire() local e=S.resolveEntity(id,owned)
    if owned and not S.tracked[e].wire then error("Only AI-created Wire components can be wired",0) end
    if not e.Inputs and not e.Outputs then error("Entity has no Wire ports",0) end
    return e
end
local function serialValue(v)
    if isnumber(v) then return v==v and math.abs(v)<1e100 and v or "non-finite" end
    if isvector(v) then return S.xyz(v) end
    if isangle(v) then return {v.p,v.y,v.r} end
    if isstring(v) then return v:sub(1,512) end
    if isbool(v) then return v end
    if IsEntity(v) then return IsValid(v) and {ref=S.entityRef(v)} or "null entity" end
    return "complex value"
end
local function ports(e)
    local result={ref=S.entityRef(e),inputs={},outputs={}}
    for _,kind in ipairs({"inputs","outputs"}) do
        local selected = kind=="inputs" and (e.Inputs or {}) or (e.Outputs or {})
        for name,p in pairs(selected) do
            if #result[kind]>=128 then break end
            result[kind][#result[kind]+1]={name=name,type=p.Type,value=serialValue(p.Value),source=kind=="inputs" and IsValid(p.Src) and {ref=S.entityRef(p.Src),output=p.SrcId} or nil}
        end
        table.sort(result[kind],function(a,b)return a.name<b.name end)
    end
    return result
end
H.sandbox_wire_ports=function(a)
    if not istable(a.refs) or #a.refs<1 or #a.refs>32 then error("Use 1–32 Wire refs",0) end
    local results={} for _,id in ipairs(a.refs) do results[#results+1]=ports(wireEntity(id,false)) end
    return {entities=results}
end
local function input(e,name)
    local p=e.Inputs and e.Inputs[name] if not p then error("Unknown input; inspect sandbox_wire_ports",0) end return p
end
local function revision(e,name)
    local meta=S.tracked[e] meta.wireRevisions=meta.wireRevisions or {}
    return meta.wireRevisions[name] or 0
end
local function setRevision(e,name,value) S.tracked[e].wireRevisions[name]=value end
local function link(dst,iname,src,oname)
    local key="sandbox_mcp_"..S.instance
    if not WireLib.Link_Start(key,dst,Vector(),iname,"cable/cable2",Color(30,220,255),1) then error("Wiremod refused the input",0) end
    local ok,err=pcall(WireLib.Link_End,key,src,Vector(),oname,S.owner)
    WireLib.Link_Cancel(key)
    if not ok or input(dst,iname).Src~=src or input(dst,iname).SrcId~=oname then
        WireLib.Link_Clear(dst,iname) error("Wiremod could not connect: "..tostring(err or "link not established"),0)
    end
end
local function hasDependency(e,target,seen)
    if e==target then return true end
    if seen[e] then return false end seen[e]=true
    for _,p in pairs(e.Inputs or {}) do if IsValid(p.Src) and hasDependency(p.Src,target,seen) then return true end end
    return false
end
-- Validate the complete proposed graph before changing any live inputs.
function S.wireBatch(links,record)
    requireWire()
    if not istable(links) or #links<1 or #links>256 then error("Use 1–256 Wire connections",0) end
    local pending,edges,all={},{},{}
    for _,l in ipairs(links) do
        local src,dst=wireEntity(l.from,true),wireEntity(l.to,true)
        local i,o=input(dst,l.input),src.Outputs and src.Outputs[l.output]
        if not o then error("Unknown output; inspect sandbox_wire_ports",0) end
        if IsValid(i.Src) then error("Input is already wired; disconnect it explicitly first",0) end
        if i.Type~=o.Type then error("Wire port type mismatch: "..o.Type.." -> "..i.Type,0) end
        pending[dst]=pending[dst] or {}
        if pending[dst][l.input] then error("Duplicate destination input in Wire batch",0) end
        pending[dst][l.input]=src
        edges[#edges+1]={src=src,dst=dst,input=l.input,output=l.output,before=revision(dst,l.input)}
        all[src]=true all[dst]=true
    end
    local visiting,done={},{}
    local function visit(e)
        if visiting[e] then error("Feedback cycle refused",0) end
        if done[e] then return end
        visiting[e]=true
        for _,p in pairs(e.Inputs or {}) do if IsValid(p.Src) then visit(p.Src) end end
        for _,src in pairs(pending[e] or {}) do visit(src) end
        visiting[e]=nil done[e]=true
    end
    for e in pairs(all) do visit(e) end
    local applied={}
    local ok,err=pcall(function()
        for _,v in ipairs(edges) do
            link(v.dst,v.input,v.src,v.output)
            setRevision(v.dst,v.input,v.before+1) applied[#applied+1]=v
        end
    end)
    if not ok then
        for i=#applied,1,-1 do local v=applied[i] WireLib.Link_Clear(v.dst,v.input) setRevision(v.dst,v.input,v.before) end
        error("Wire batch rolled back: "..tostring(err),0)
    end
    local result={connections=#edges}
    if record~=false then
        result.operation_id=S.operation("wire circuit",table.GetKeys(all),function()
            for _,v in ipairs(edges) do
                if not IsValid(v.dst) or not IsValid(v.src) or revision(v.dst,v.input)~=v.before+1 or input(v.dst,v.input).Src~=v.src or input(v.dst,v.input).SrcId~=v.output then error("Wire changed or removed since this operation",0) end
                wireEntity(S.entityRef(v.dst),true) wireEntity(S.entityRef(v.src),true)
            end
            for i=#edges,1,-1 do local v=edges[i] WireLib.Link_Clear(v.dst,v.input) setRevision(v.dst,v.input,v.before) end
        end)
    end
    return result
end
H.sandbox_wire_batch=function(a)return S.wireBatch(a.links,true)end
S.wirePorts=ports
H.sandbox_wire_connect=function(a)
    local src,dst=wireEntity(a.from,true),wireEntity(a.to,true)
    local i=input(dst,a.input) local o=src.Outputs and src.Outputs[a.output]
    if not o then error("Unknown output; inspect sandbox_wire_ports",0) end
    if IsValid(i.Src) then error("Input is already wired; disconnect it explicitly first",0) end
    if i.Type~=o.Type then error("Wire port type mismatch: "..o.Type.." -> "..i.Type,0) end
    if hasDependency(src,dst,{}) then error("Feedback cycle refused; use a timed gate for oscillation",0) end
    local previous=revision(dst,a.input)
    link(dst,a.input,src,a.output)
    setRevision(dst,a.input,previous+1)
    local op=S.operation("wire connect",{src,dst},function()
        if not IsValid(dst) or not IsValid(src) or revision(dst,a.input)~=previous+1 or input(dst,a.input).Src~=src or input(dst,a.input).SrcId~=a.output then error("Wire changed or removed since this operation",0) end
        WireLib.Link_Clear(dst,a.input)
        setRevision(dst,a.input,previous)
    end)
    return {operation_id=op,entity=ports(dst)}
end
H.sandbox_wire_disconnect=function(a)
    local dst=wireEntity(a.to,true) local i=input(dst,a.input)
    local src,oname=i.Src,i.SrcId
    if not IsValid(src) then error("Input is not connected",0) end
    -- Do not change links involving manually created components.
    wireEntity(S.entityRef(src),true)
    local previous=revision(dst,a.input)
    WireLib.Link_Clear(dst,a.input)
    setRevision(dst,a.input,previous+1)
    local op=S.operation("wire disconnect",{src,dst},function()
        if not IsValid(dst) or not IsValid(src) or revision(dst,a.input)~=previous+1 or IsValid(input(dst,a.input).Src) then error("Wire changed or removed since this operation",0) end
        if hasDependency(src,dst,{}) then error("Restoring this link would create a feedback cycle",0) end
        link(dst,a.input,src,oname)
        setRevision(dst,a.input,previous)
    end)
    return {operation_id=op,entity=ports(dst)}
end
local function getSource(e)
    if S.tracked[e].wire=="constant" then return tonumber(e.value[1].Value) end
    if S.tracked[e].wire=="button" then
        if IsValid(input(e,"Set").Src) then error("Button is controlled by a wire; change its source instead",0) end
        return e:GetOn() and 1 or 0
    end
    error("wire_set supports constant values and toggle buttons only",0)
end
local function setSource(e,v)
    if S.tracked[e].wire=="constant" then e.value[1].Value=tostring(v) WireLib.TriggerOutput(e,"1",v)
    else e:Switch(v==1) end
end
H.sandbox_wire_set=function(a)
    local e=wireEntity(a.ref,true) local before=getSource(e) local value=S.number(a.value,-1000000,1000000)
    if S.tracked[e].wire=="button" and value~=0 and value~=1 then error("Button state must be 0 or 1",0) end
    local previous=revision(e,"_source")
    setSource(e,value)
    setRevision(e,"_source",previous+1)
    local op=S.operation("wire set",{e},function()
        if not IsValid(e) or revision(e,"_source")~=previous+1 or getSource(e)~=value then error("Source changed or removed since this operation",0) end
        setSource(e,before)
        setRevision(e,"_source",previous)
    end)
    return {operation_id=op,entity=ports(e)}
end
