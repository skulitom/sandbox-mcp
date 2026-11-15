local S = SandboxMCP
S.handlers = S.handlers or {}
S.tracked = S.tracked or setmetatable({}, {__mode="k"})
local H, tracked = S.handlers, S.tracked
local npcClasses = {"npc_citizen", "npc_alyx", "npc_barney", "npc_kleiner", "npc_monk", "npc_dog", "npc_combine_s", "npc_metropolice", "npc_zombie", "npc_headcrab", "npc_antlion", "npc_turret_floor"}

function S.number(n, low, high)
    if not isnumber(n) or n ~= n or n < low or n > high then error("Number outside allowed range " .. low .. ".." .. high, 0) end
    return n
end
function S.vector(a)
    if not istable(a) or #a ~= 3 then error("Expected [x,y,z] vector", 0) end
    return Vector(S.number(a[1],-32768,32768), S.number(a[2],-32768,32768), S.number(a[3],-32768,32768))
end
function S.xyz(v) return {v.x, v.y, v.z} end
local function angles(a) local v=S.vector(a or {0,0,0}) return Angle(v.x,v.y,v.z) end
local function angleArray(a) return {a.p,a.y,a.r} end
local function text(s, max) if not isstring(s) or #s == 0 or #s > (max or 256) then error("Expected a non-empty bounded string",0) end return s end
local function asset(s) text(s) if s:find("..",1,true) or s:find(":",1,true) or s:find("\\",1,true) then error("Asset paths must be relative to the game",0) end return s end
local function ref(e) return S.instance .. ":" .. e:EntIndex() .. ":" .. e:GetCreationID() end
local function resolve(id, owned)
    if not isstring(id) then error("Expected stable entity ref from inspect/create",0) end
    local instance, index, creation = id:match("^(%x+):(%d+):(%d+)$")
    if instance~=S.instance then error("Entity ref is from a previous game session; inspect again",0) end
    local e = index and Entity(tonumber(index))
    if not IsValid(e) or e:GetCreationID() ~= tonumber(creation) then error("Stale entity ref " .. id .. "; inspect again",0) end
    if owned and (not tracked[e] or tracked[e].owner ~= S.owner) then error("Only this host's AI-created objects can be changed",0) end
    return e
end
local function info(e)
    local lo, hi = e:WorldSpaceAABB()
    local p, meta = e:GetPhysicsObject(), tracked[e]
    local out = {ref=ref(e), class=e:GetClass(), model=e:GetModel(), pos=S.xyz(e:GetPos()), angles=angleArray(e:GetAngles()),
        bounds={min=S.xyz(lo), max=S.xyz(hi)}, owned=meta ~= nil, label=meta and meta.label, build_id=meta and meta.build,
        material=e:GetMaterial(), color={e:GetColor().r,e:GetColor().g,e:GetColor().b}, skin=e:GetSkin()}
    if IsValid(p) then out.physics={mass=p:GetMass(), frozen=not p:IsMotionEnabled(), asleep=p:IsAsleep(), velocity=S.xyz(p:GetVelocity())} end
    if e:IsNPC() then out.health=e:Health() end
    return out
end
function S.liveCount() local n=0 for e in pairs(tracked) do if IsValid(e) then n=n+1 end end return n end
local function operation(kind, entities, undoFn)
    S.sequence = S.sequence + 1
    local id = S.instance .. "-" .. S.sequence
    S.operations[id] = {kind=kind, undo=undoFn, entities=entities, owner=S.owner}
    undo.Create("Sandbox MCP " .. kind)
    undo.SetPlayer(S.owner)
    undo.AddFunction(function() local ok, err=pcall(H.sandbox_undo,{operation_id=id}) if not ok and IsValid(S.owner) then S.owner:ChatPrint(tostring(err)) end end)
    undo.Finish()
    return id
end
H.sandbox_undo = function(a)
    local op = S.operations[a.operation_id]
    if not op then error("Unknown operation; use sandbox_events to find operation_id",0) end
    if op.owner ~= S.owner then error("Operation belongs to another host",0) end
    if op.undone then return {undone=true, already_undone=true, operation_id=a.operation_id} end
    op.undo()
    op.undone = true
    return {undone=true, operation_id=a.operation_id, kind=op.kind}
end

local known, modelSet = {}, {}
local boundsCache = {}
local function modelBounds(path)
    if boundsCache[path] then return boundsCache[path] end
    -- Source studiohdr_t hull_min/hull_max: six little-endian floats at byte 104.
    -- Read the model header rather than spawning invisible physics probes.
    local f=file.Open(path,"rb","GAME")
    if not f then return nil end
    if f:Read(4)~="IDST" or f:Size()<152 then f:Close() return nil end
    f:Seek(104)
    local low={f:ReadFloat(),f:ReadFloat(),f:ReadFloat()}
    local high={f:ReadFloat(),f:ReadFloat(),f:ReadFloat()}
    f:Close()
    boundsCache[path]={min=low,max=high}
    return boundsCache[path]
end
local folders, folderIndex = {"models"}, 1
local function addModel(path) if not modelSet[path] and #known < 50000 then modelSet[path]=true known[#known+1]=path end end
for _, m in ipairs({"models/props_c17/oildrum001.mdl", "models/props_c17/furnituretable001a.mdl", "models/props_c17/furniturechair001a.mdl", "models/props_c17/lampshade001a.mdl", "models/props_c17/statue_horse.mdl", "models/props_junk/wood_crate001a.mdl", "models/props_phx/construct/metal_plate1.mdl", "models/props_phx/construct/metal_plate2x2.mdl", "models/props_phx/wheels/wooden_wheel1.mdl", "models/hunter/plates/plate1x1.mdl", "models/buggy.mdl"}) do addModel(m) end
timer.Create("SandboxMCPModelIndex", 0.1, 0, function()
    local start = SysTime()
    while folderIndex <= #folders and SysTime()-start < 0.002 do
        local folder=folders[folderIndex] folderIndex=folderIndex+1
        local files, dirs = file.Find(folder .. "/*", "GAME")
        for _, f in ipairs(files) do if f:sub(-4)==".mdl" then addModel(folder .. "/" .. f) end end
        for _, d in ipairs(dirs) do if #folders < 10000 then folders[#folders+1]=folder .. "/" .. d end end
    end
    if folderIndex > #folders then timer.Remove("SandboxMCPModelIndex") end
end)
H.sandbox_catalog = function(a)
    local kind, query = a.kind or "models", string.lower(a.query or "")
    local matches = {}
    if kind=="models" then
        for _, model in ipairs(known) do if model:lower():find(query,1,true) then matches[#matches+1]=model end end
    elseif kind=="vehicles" then
        for id, v in pairs(list.Get("Vehicles")) do if (id .. " " .. (v.Name or "")):lower():find(query,1,true) then matches[#matches+1]={id=id,name=v.Name,model=v.Model,class=v.Class} end end
    elseif kind=="npcs" then
        for _, class in ipairs(npcClasses) do if class:find(query,1,true) then matches[#matches+1]=class end end
    else error("kind must be models, vehicles, or npcs",0) end
    table.sort(matches,function(a,b) return (istable(a) and a.id or a)<(istable(b) and b.id or b) end)
    local offset, limit = math.floor(S.number(a.offset or 0,0,1000000)), math.floor(S.number(a.limit or 20,1,40))
    local items = {}
    for i=offset+1, math.min(#matches,offset+limit) do
        local item=matches[i]
        if kind=="models" then
            item={model=item, bounds=modelBounds(item), valid=util.IsValidModel(item)}
        end
        items[#items+1]=item
    end
    return {items=items, total=#matches, next_offset=offset+#items < #matches and offset+#items or nil, indexing=folderIndex<=#folders}
end
H.sandbox_inspect = function(a)
    local selected={}
    if a.refs then for _, id in ipairs(a.refs) do selected[#selected+1]=resolve(id) end
    elseif a.build_id then local b=S.builds[a.build_id] if not b then error("Unknown build_id",0) end for _,e in ipairs(b.entities) do if IsValid(e) then selected[#selected+1]=e end end
    elseif a.near then selected=ents.FindInSphere(S.vector(a.near),S.number(a.radius or 512,1,10000))
    else selected=ents.GetAll() end
    local filtered={}
    for _,e in ipairs(selected) do if IsValid(e) and (not a.owned_only or tracked[e]) and (tracked[e] or e:GetModel() or e:IsPlayer()) then filtered[#filtered+1]=e end end
    table.sort(filtered,function(a,b)return a:EntIndex()<b:EntIndex() end)
    local offset, limit=math.floor(S.number(a.offset or 0,0,100000)),math.floor(S.number(a.limit or 40,1,100))
    local items={}
    for i=offset+1, math.min(#filtered,offset+limit) do items[#items+1]=info(filtered[i]) end
    local builds={}
    for id,b in pairs(S.builds) do local n=0 for _,e in ipairs(b.entities) do if IsValid(e) then n=n+1 end end if n>0 then builds[#builds+1]={id=id,name=b.name,count=n} end end
    return {entities=items,total=#filtered,next_offset=offset+#items<#filtered and offset+#items or nil,builds=builds,
        player={pos=S.xyz(S.owner:GetPos()),eye_pos=S.xyz(S.owner:EyePos()),angles=angleArray(S.owner:EyeAngles())},map=game.GetMap()}
end
H.sandbox_trace = function(a)
    local tr
    if a.start or a["end"] then
        local data={start=S.vector(a.start),endpos=S.vector(a["end"]),filter=S.owner}
        if a.mins or a.maxs then data.mins=S.vector(a.mins) data.maxs=S.vector(a.maxs) tr=util.TraceHull(data) else tr=util.TraceLine(data) end
    else tr=S.owner:GetEyeTrace() end
    return {hit=tr.Hit,hit_world=tr.HitWorld,position=S.xyz(tr.HitPos),normal=S.xyz(tr.HitNormal),fraction=tr.Fraction,start_solid=tr.StartSolid,entity=IsValid(tr.Entity) and ref(tr.Entity) or nil}
end

local function validateChanges(a)
    if a.pos then S.vector(a.pos) end
    if a.angles then angles(a.angles) end
    if a.velocity then for _,n in ipairs(a.velocity) do S.number(n,-2000,2000) end S.vector(a.velocity) end
    if a.mass then S.number(a.mass,1,5000) end
    if a.frozen~=nil and not isbool(a.frozen) then error("frozen must be a boolean",0) end
    if a.skin then S.number(a.skin,0,32) end
    if a.material then asset(a.material) end
    if a.color then if #a.color~=3 then error("color must be [r,g,b]",0) end for _,n in ipairs(a.color) do S.number(n,0,255) end end
end
local function apply(e,a)
    if a.pos then e:SetPos(S.vector(a.pos)) end
    if a.angles then e:SetAngles(angles(a.angles)) end
    if a.color then e:SetColor(Color(unpack(a.color))) end
    if a.material then e:SetMaterial(a.material) end
    if a.skin then e:SetSkin(a.skin) end
    local p=e:GetPhysicsObject()
    if IsValid(p) then
        if a.mass then p:SetMass(a.mass) end
        if a.frozen~=nil then p:EnableMotion(not a.frozen) end
        if a.velocity then p:SetVelocity(S.vector(a.velocity)) end
        p:Wake()
    end
end
local function validateLink(l, lookup)
    if not table.HasValue({"weld","nocollide","axis","rope"},l.kind) then error("Unsupported connection kind",0) end
    local a,b=lookup(l.a),lookup(l.b)
    if a==b then error("Cannot constrain an object to itself",0) end
    if l.anchor_a then S.vector(l.anchor_a) end if l.anchor_b then S.vector(l.anchor_b) end
    if l.axis and S.vector(l.axis):LengthSqr()<0.001 then error("Axis cannot be zero",0) end
    if l.length then S.number(l.length,0,4096) end
end
local function makeLink(l,lookup,created)
    local a,b=lookup(l.a),lookup(l.b)
    if not IsValid(a:GetPhysicsObject()) or not IsValid(b:GetPhysicsObject()) then error("Both linked parts must have physics",0) end
    local c,rope
    if l.kind=="weld" then c=constraint.Weld(a,b,0,0,0,true,false)
    elseif l.kind=="nocollide" then c=constraint.NoCollide(a,b,0,0)
    elseif l.kind=="axis" then c=constraint.Axis(a,b,0,0,S.vector(l.anchor_a or {0,0,0}),S.vector(l.anchor_b or {0,0,0}),0,0,0,1,S.vector(l.axis or {0,0,1}))
    else c,rope=constraint.Rope(a,b,0,0,S.vector(l.anchor_a or {0,0,0}),S.vector(l.anchor_b or {0,0,0}),l.length or a:GetPos():Distance(b:GetPos()),0,0,2,"cable/rope",false) end
    if not IsValid(c) then error("The engine could not create the connection",0) end
    created[#created+1]=c if IsValid(rope) then created[#created+1]=rope end
end
local function removeAll(entities) for i=#entities,1,-1 do if IsValid(entities[i]) then entities[i]:Remove() end end end
H.sandbox_create = function(a)
    text(a.name,80)
    if not istable(a.entities) or #a.entities<1 or #a.entities>128 then error("Use 1–128 entities per batch",0) end
    if S.liveCount()+#a.entities>512 then error("512 live parts reached; clean up an old build first",0) end
    if a.links and #a.links>256 then error("Maximum 256 connections per batch",0) end
    local origin=a.origin and S.vector(a.origin) or S.owner:GetEyeTrace().HitPos
    local labels={}
    for _,p in ipairs(a.entities) do
        text(p.label,80) if labels[p.label] then error("Duplicate part label "..p.label,0) end labels[p.label]=p
        validateChanges(p)
        S.vector(S.xyz(origin+S.vector(p.pos or {0,0,0})))
        p.kind=p.kind or "prop"
        if p.kind=="prop" or p.kind=="light" then
            p.model=asset(p.model or (p.kind=="light" and "models/props_c17/lampShade001a.mdl" or "")):lower()
            if not util.IsValidModel(p.model) or not util.IsValidProp(p.model) then error("Not a valid physics prop: "..p.model,0) end
            if hook.Run("PlayerSpawnProp",S.owner,p.model)==false then error("Server denied prop "..p.model,0) end
        elseif p.kind=="vehicle" then
            if not list.Get("Vehicles")[p.preset] then error("Unknown vehicle preset; use sandbox_catalog kind=vehicles",0) end
        elseif p.kind=="npc" then
            if not table.HasValue(npcClasses,p.class) then error("Unsupported NPC class; use sandbox_catalog kind=npcs",0) end
        else error("Unknown entity kind",0) end
    end
    local function definition(label) if not labels[label] then error("Connection references unknown label "..tostring(label),0) end return labels[label] end
    for _,l in ipairs(a.links or {}) do validateLink(l,definition) end
    local made, parts, byLabel, connections={},{},{},{}
    local buildID = util.SHA256(S.instance..tostring(SysTime())..a.name):sub(1,16)
    local ok, err=pcall(function()
        for _,p in ipairs(a.entities) do
            local v=p.kind=="vehicle" and list.Get("Vehicles")[p.preset] or nil
            local e=ents.Create(v and v.Class or p.kind=="npc" and p.class or "prop_physics")
            if not IsValid(e) then error("Engine could not create "..p.label,0) end
            made[#made+1]=e parts[#parts+1]=e byLabel[p.label]=e
            if v then
                e:SetModel(v.Model)
                for k,value in pairs(v.KeyValues or {}) do e:SetKeyValue(k,value) end
                e.VehicleName=p.preset e.VehicleTable=v
            elseif p.model then e:SetModel(p.model) end
            e:SetPos(origin + S.vector(p.pos or {0,0,0})) e:SetAngles(angles(p.angles))
            e:SetCreator(S.owner) e:Spawn() e:Activate()
            if v and v.Members then table.Merge(e:GetTable(),v.Members) end
            if p.kind=="npc" and p.class=="npc_citizen" then e:SetModel("models/humans/group01/male_07.mdl") end
            if p.kind~="npc" and not IsValid(e:GetPhysicsObject()) then error("No physics for "..p.label,0) end
            if p.frozen==nil and p.kind~="npc" then p.frozen=true end
            local properties=table.Copy(p) properties.pos=nil properties.angles=nil apply(e,properties)
            tracked[e]={owner=S.owner,build=buildID,label=p.label,revision=0}
            if p.kind=="light" then e:SetNWBool("SandboxMCPLight",true) end
        end
        for _,l in ipairs(a.links or {}) do makeLink(l,function(label)return byLabel[label]end,connections) end
    end)
    if not ok then removeAll(connections) removeAll(made) error("Batch rolled back: "..tostring(err),0) end
    S.builds[buildID]={name=a.name,entities=parts,connections=connections,owner=S.owner}
    local op=operation("create "..a.name,parts,function() removeAll(connections) removeAll(parts) S.builds[buildID]=nil end)
    local result={} for _,e in ipairs(parts) do result[#result+1]=info(e) end
    return {build_id=buildID,operation_id=op,entities=result,connections=#connections}
end
H.sandbox_edit = function(a)
    if not istable(a.items) or #a.items<1 or #a.items>128 then error("Use 1–128 edits",0) end
    local entities,snapshots,seen={},{},{}
    for _,item in ipairs(a.items) do
        validateChanges(item)
        local e=resolve(item.ref,true) if seen[e] then error("Duplicate ref in edit batch",0) end seen[e]=true
        entities[#entities+1]=e
        local i=info(e)
        snapshots[#snapshots+1]={pos=i.pos,angles=i.angles,color=i.color,material=i.material,skin=i.skin,mass=i.physics and i.physics.mass,frozen=i.physics and i.physics.frozen,velocity=i.physics and i.physics.velocity}
    end
    local revisions,originalRevisions={},{}
    for i,e in ipairs(entities) do originalRevisions[i]=tracked[e].revision end
    local ok,err=pcall(function() for index,e in ipairs(entities) do apply(e,a.items[index]) tracked[e].revision=tracked[e].revision+1 revisions[index]=tracked[e].revision end end)
    if not ok then for i,e in ipairs(entities) do if IsValid(e) then apply(e,snapshots[i]) tracked[e].revision=originalRevisions[i] end end error("Edit rolled back: "..tostring(err),0) end
    local op=operation("edit",entities,function()
        for i,e in ipairs(entities) do if not IsValid(e) or tracked[e].revision~=revisions[i] then error("Cannot undo: a part was removed or edited later. Undo its later edit first.",0) end end
        for i,e in ipairs(entities) do apply(e,snapshots[i]) tracked[e].revision=tracked[e].revision-1 end
    end)
    local items={} for _,e in ipairs(entities) do items[#items+1]=info(e) end
    return {operation_id=op,entities=items}
end
H.sandbox_connect = function(a)
    if not istable(a.links) or #a.links<1 or #a.links>256 then error("Use 1–256 connections",0) end
    local function lookup(id)return resolve(id,true)end
    for _,l in ipairs(a.links) do validateLink(l,lookup) end
    local made={}
    local ok,err=pcall(function() for _,l in ipairs(a.links) do makeLink(l,lookup,made) end end)
    if not ok then removeAll(made) error("Connections rolled back: "..tostring(err),0) end
    return {operation_id=operation("connect",made,function() removeAll(made) end),connections=#made}
end
H.sandbox_cleanup = function(a)
    local b=S.builds[a.build_id] if not b then error("Unknown build_id",0) end
    if b.owner~=S.owner then error("Build belongs to another host",0) end
    removeAll(b.connections) removeAll(b.entities)
    S.builds[a.build_id]=nil
    return {removed=true,build_id=a.build_id}
end
H.sandbox_observe = function(a,request)
    if not istable(a.refs) or #a.refs<1 or #a.refs>128 then error("Use 1–128 refs",0) end
    local duration=S.number(a.seconds or 1,0.2,5)
    local entries={}
    for _,id in ipairs(a.refs) do local e=resolve(id) entries[#entries+1]={e=e,ref=id,start=e:GetPos(),max_speed=0} end
    S.pending[request.id]=request
    local began=SysTime()
    timer.Create("SandboxMCPObserve"..request.id,0.05,0,function()
        if not S.connected or request.replied then timer.Remove("SandboxMCPObserve"..request.id) return end
        for _,v in ipairs(entries) do if IsValid(v.e) then v.max_speed=math.max(v.max_speed,v.e:GetVelocity():Length()) end end
        if SysTime()-began>=duration then
            local result={}
            for _,v in ipairs(entries) do result[#result+1]={ref=v.ref,start=S.xyz(v.start),finish=IsValid(v.e) and S.xyz(v.e:GetPos()) or nil,removed=not IsValid(v.e),max_speed=v.max_speed,displacement=IsValid(v.e) and v.e:GetPos():Distance(v.start) or nil} end
            timer.Remove("SandboxMCPObserve"..request.id)
            S.reply(request,true,{seconds=SysTime()-began,entities=result})
        end
    end)
end
