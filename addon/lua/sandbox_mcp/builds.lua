-- Portable, allowlisted blueprints. No engine tables or executable Lua are imported.
local S,H=SandboxMCP,SandboxMCP.handlers
local function slug(s)
    if not isstring(s) or #s<1 or #s>64 or not s:match("^[a-zA-Z0-9_-]+$") then error("Name must be 1–64 letters, digits, underscores or hyphens",0) end
    return s:lower()
end
local function folder()
    local p="sandbox_mcp/blueprints/"..S.owner:SteamID64() file.CreateDir(p) return p
end
function S.buildEntities(a,owned)
    local out,seen={},{}
    if a.build_id then
        local b=S.builds[a.build_id] if not b or b.owner~=S.owner then error("Unknown owned build_id",0) end
        for _,e in ipairs(b.entities) do if IsValid(e) then out[#out+1]=e end end
    elseif istable(a.refs) then
        for _,id in ipairs(a.refs) do local e=S.resolveEntity(id,owned) if seen[e] then error("Duplicate entity reference",0) end seen[e]=true out[#out+1]=e end
    else error("Provide build_id or refs",0) end
    if #out<1 or #out>128 then error("Select 1–128 entities",0) end
    if owned then for _,e in ipairs(out) do S.resolveEntity(S.entityRef(e),true) end end
    return out
end
local function validate(data)
    if not istable(data) or data.format~="sandbox-mcp-blueprint" or data.version~=1 or not istable(data.entities) or #data.entities<1 or #data.entities>128 then error("Unsupported blueprint format or part count",0) end
    if not isstring(data.name) or #data.name>80 then error("Invalid blueprint title",0) end
    if not istable(data.links) or #data.links>256 or not istable(data.wire_links) or #data.wire_links>256 then error("Blueprint connection limits exceeded",0) end
    if data.fluid_links and (not istable(data.fluid_links) or #data.fluid_links>128) then error("Blueprint fluid connection limits exceeded",0) end
    local raw=util.TableToJSON(data)
    if not raw or #raw>200000 then error("Blueprint exceeds 200 KB",0) end
    return data,raw
end
function S.captureBlueprint(a)
    local entities=S.buildEntities(a,true)
    local origin=a.origin and S.vector(a.origin) or entities[1]:GetPos()
    local data={format="sandbox-mcp-blueprint",version=1,name=a.title or (a.build_id and S.builds[a.build_id].name) or "Saved contraption",entities={},links={},wire_links={}}
    local labels,selected={},{}
    for i,e in ipairs(entities) do
        local m=S.tracked[e] local p=table.Copy(m.spec or {}) local info=S.entityInfo(e)
        if m.cogworks then error("Save the Cogworks mount and socket recipe to rebuild this mechanism",0) end
        if p.kind=="npc" then error("NPC behavior cannot be saved as a contraption blueprint",0) end
        local label=m.label local suffix=0
        while labels[label] do suffix=suffix+1 label="part-"..i.."-"..suffix end
        labels[label]=e selected[e]=label
        p.label=label p.pos=S.xyz(e:GetPos()-origin) p.angles=info.angles
        p.model=info.model p.color=info.color p.skin=info.skin p.material=info.material~="" and info.material or nil
        p.mass=info.physics and info.physics.mass p.frozen=info.physics and info.physics.frozen p.velocity=nil
        if m.wire then
            p.kind="wire" p.preset=m.wire p.settings=p.settings or {}
            if m.wire=="constant" then p.settings.value=tonumber(e.value[1].Value)
            elseif m.wire=="button" then p.source_state=e:GetOn() and 1 or 0
            elseif m.wire=="expression2" then p.settings.code=e.original end
        end
        p.fin3=S.fin3Spec and S.fin3Spec(e) or nil
        data.entities[#data.entities+1]=p
    end
    if S.flowmodBlueprint then S.flowmodBlueprint(entities,selected,data) end
    local seen={}
    for _,e in ipairs(entities) do
        for _,constraintInfo in ipairs(constraint.GetTable(e) or {}) do
            local c=constraintInfo.Constraint
            if IsValid(c) and not seen[c] then
                seen[c]=true
                local record=S.constraintRecords[c]
                if not record and S.flowmodAvailable and S.flowmodAvailable() and (c:GetClass()=="flowmod_hose" or c:GetClass()=="flowmod_attachment") then
                    -- Captured as fluid links and cylinder local anchors above.
                    for _,endpoint in ipairs({c.Ent1,c.Ent2,c.Ent3}) do
                        if IsValid(endpoint) and not selected[endpoint] then error("A FlowMod connection leaves this selection; include its controller and anchor props",0) end
                    end
                else
                if not record then error("Unsupported or manually changed constraint; remove it or use supported MCP links before saving",0) end
                if not selected[record.a] or not selected[record.b] then error("A constraint leaves the selected build; include both endpoints using refs",0) end
                local l=table.Copy(record.spec) l.a=selected[record.a] l.b=selected[record.b] data.links[#data.links+1]=l
                end
            end
        end
        for name,p in pairs(e.Inputs or {}) do
            if IsValid(p.Src) then
                if not selected[p.Src] then error("A Wire input comes from outside this selection; include its source using refs",0) end
                data.wire_links[#data.wire_links+1]={from=selected[p.Src],output=p.SrcId,to=selected[e],input=name}
            end
        end
    end
    validate(data)
    return data
end
function S.loadBlueprint(data,a)
    validate(data)
    local rotation=Angle(unpack(a.angles or {0,0,0})) S.vector(a.angles or {0,0,0})
    local parts=table.Copy(data.entities)
    for _,p in ipairs(parts) do
        local pos,ang=LocalToWorld(S.vector(p.pos),Angle(unpack(p.angles or {0,0,0})),Vector(),rotation)
        p.pos=S.xyz(pos) p.angles={ang.p,ang.y,ang.r}
        if a.frozen~=false then p.frozen=true end
        -- The activation of buttons is separate from restoring the graph.
        p.source_state=nil
    end
    local result=H.sandbox_create({name=a.title or data.name,origin=a.origin,entities=parts,links=table.Copy(data.links),wire_links=table.Copy(data.wire_links),fluid_links=table.Copy(data.fluid_links or {})})
    return result
end
H.sandbox_blueprint=function(a)
    local path=folder()
    if a.action=="list" then
        local names=file.Find(path.."/*.json","DATA") table.sort(names)
        local offset,limit=math.floor(S.number(a.offset or 0,0,100000)),math.floor(S.number(a.limit or 20,1,40))
        local items={} for i=offset+1,math.min(#names,offset+limit) do items[#items+1]={name=names[i]:sub(1,-6),bytes=file.Size(path.."/"..names[i],"DATA")} end
        return {items=items,total=#names,next_offset=offset+#items<#names and offset+#items or nil}
    end
    if a.action=="export" and (a.build_id or a.refs) then return {blueprint=S.captureBlueprint(a)} end
    local name=slug(a.name) local target=path.."/"..name..".json"
    if a.action=="save" or a.action=="import" then
        if file.Exists(target,"DATA") and not a.overwrite then error("Blueprint already exists; choose another name or set overwrite=true",0) end
        local data=a.action=="save" and S.captureBlueprint(a) or a.blueprint
        local _,raw=validate(data)
        local tmp=path.."/"..name..".pending.json" file.Write(tmp,raw)
        if file.Read(tmp,"DATA")~=raw then error("Blueprint could not be written",0) end
        local previous=file.Read(target,"DATA")
        if file.Exists(target,"DATA") then file.Delete(target) end
        file.Rename(tmp,target)
        if file.Read(target,"DATA")~=raw then
            if previous then file.Write(target,previous) end
            error("Blueprint replacement failed; previous contents restored where possible",0)
        end
        return {saved=name,parts=#data.entities,connections=#data.links,wire_connections=#data.wire_links}
    end
    local bytes=file.Size(target,"DATA") if bytes<1 or bytes>200000 then error("Blueprint not found or too large",0) end
    local data=validate(util.JSONToTable(file.Read(target,"DATA") or ""))
    if a.action=="export" then return {blueprint=data,name=name} end
    if a.action=="load" then return S.loadBlueprint(data,a) end
    error("action must be list, save, import, export or load",0)
end
S.checkpoints=S.checkpoints or {}
H.sandbox_checkpoint=function(a)
    local name=slug(a.name)
    if a.action=="save" then
        if not S.checkpoints[name] and table.Count(S.checkpoints)>=32 then error("32 checkpoints reached; reuse an existing checkpoint name",0) end
        local b=S.builds[a.build_id] if not b or b.owner~=S.owner then error("Unknown owned build_id",0) end
        if b.adopted then error("Save an adopted build as a blueprint; checkpoint replacement is only for AI-created builds",0) end
        local entities=S.buildEntities(a,true)
        local data=S.captureBlueprint(a)
        S.checkpoints[name]={owner=S.owner,build_id=a.build_id,origin=S.xyz(entities[1]:GetPos()),data=data}
        return {checkpoint=name,build_id=a.build_id,parts=#data.entities}
    end
    local checkpoint=S.checkpoints[name]
    if not checkpoint or checkpoint.owner~=S.owner then error("Unknown checkpoint in this map session",0) end
    if a.action~="restore" then error("action must be save or restore",0) end
    local old=S.builds[checkpoint.build_id]
    if old and (old.owner~=S.owner or old.adopted) then error("Build is no longer replaceable",0) end
    local result=S.loadBlueprint(checkpoint.data,{origin=a.origin or checkpoint.origin,frozen=a.frozen})
    if old then H.sandbox_cleanup({build_id=checkpoint.build_id}) end
    checkpoint.build_id=result.build_id
    result.checkpoint=name result.replaced=true
    return result
end
