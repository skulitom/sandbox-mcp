-- Optional integration with separately installed Fin 3. Original MIT adapter.
-- Aerodynamic forces remain entirely in Fin 3's native simulation.
local S,H=SandboxMCP,SandboxMCP.handlers
local URL="https://steamcommunity.com/sharedfiles/filedetails/?id=3113528615"
function S.fin3Available()
    return istable(Fin3) and istable(Fin3.fins) and istable(Fin3.propellers)
        and istable(Fin3.fin) and isfunction(Fin3.fin.new)
        and istable(Fin3.propeller) and isfunction(Fin3.propeller.new)
end
local function requireFin()
    if not S.fin3Available() then error("Fin 3 is not installed or loaded. Subscribe to Fin 3 - Superior Flight (3113528615), then restart the map. Other MCP tools work without it.",0) end
end
local function axis(value,default)
    local v=S.vector(value or default)
    -- Match the toolgun's cardinal local axes; diagonal OBB projections can
    -- misrepresent surface area in Fin 3.
    local count=0
    for i=1,3 do if v[i]~=0 then if math.abs(v[i])~=1 then error("Fin 3 axes must be local cardinal unit vectors",0) end count=count+1 end end
    if count~=1 then error("Fin 3 axes must be local cardinal unit vectors",0) end
    return v
end
function S.validateFin3(a)
    requireFin()
    if not istable(a) or (a.kind~="fin" and a.kind~="propeller") then error("fin3.kind must be fin or propeller",0) end
    local keys=a.kind=="fin" and {kind=true,forward=true,up=true,airfoil=true,camber=true,efficiency=true,induced_drag=true,disable_lowpass=true}
        or {kind=true,forward=true,blades=true,diameter=true,pitch=true,invert=true}
    for k in pairs(a) do if not keys[k] then error("Unknown Fin 3 setting: "..tostring(k),0) end end
    local out={kind=a.kind,forward=S.xyz(axis(a.forward,{1,0,0}))}
    if a.kind=="fin" then
        local up=axis(a.up,{0,0,1})
        if up:Dot(Vector(unpack(out.forward)))~=0 then error("Fin forward and up axes must be perpendicular",0) end
        out.up=S.xyz(up) out.airfoil=a.airfoil or "standard"
        local model=Fin3.models and Fin3.models[out.airfoil]
        if not model or model.hidden then error("Unknown airfoil; use sandbox_catalog kind=fin3",0) end
        out.camber=S.number(a.camber or 0,0,100)
        if out.camber>0 and not model.canCamber then error("This airfoil does not support camber",0) end
        out.efficiency=S.number(a.efficiency or 1,0.1,1.5)
        out.induced_drag=S.number(a.induced_drag==nil and 1 or a.induced_drag,0,1)
        if a.disable_lowpass~=nil and not isbool(a.disable_lowpass) then error("disable_lowpass must be boolean",0) end
        out.disable_lowpass=a.disable_lowpass==true
    else
        out.blades=S.number(a.blades or 2,2,6)
        if out.blades~=math.floor(out.blades) then error("Blade count must be an integer",0) end
        out.diameter=S.number(a.diameter or 2,0.1,6)
        out.pitch=S.number(a.pitch==nil and 15 or a.pitch,-90,90)
        if a.invert~=nil and not isbool(a.invert) then error("invert must be boolean",0) end
        out.invert=a.invert==true
    end
    return out
end
function S.fin3Spec(e)
    if not S.fin3Available() then return nil end
    local f,p=Fin3.fins[e],Fin3.propellers[e]
    if f and p then error("Both Fin 3 modes are attached; remove one with the toolgun before editing or saving",0) end
    if f then return {kind="fin",forward=S.xyz(f.forwardAxis),up=S.xyz(f.upAxis),airfoil=f.finType,camber=f.camber,
        efficiency=f.efficiency,induced_drag=f.inducedDrag,disable_lowpass=f.disableLowPass==true} end
    if p then return {kind="propeller",forward=S.xyz(p.forwardAxis),blades=p.bladeCount,diameter=p.diameter,
        pitch=p.invertRotation and -p.bladePitch or p.bladePitch,invert=p.invertRotation==true} end
end
local function active(e) return Fin3.fins[e] or Fin3.propellers[e] end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if not istable(a) then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function physics(e)
    local p=e:GetPhysicsObject() local linear,angular=p:GetDamping()
    return {drag=p:IsDragEnabled(),linear=linear,angular=angular}
end
local function restorePhysics(e,a)
    local p=e:GetPhysicsObject()
    if IsValid(p) and a then p:EnableDrag(a.drag) p:SetDamping(a.linear,a.angular) p:Wake() end
end
local function target(e,spec)
    if e:GetClass()~="prop_physics" or not IsValid(e:GetPhysicsObject()) or e:GetPhysicsObjectCount()~=1 then error("Fin 3 edits support single-body physics props",0) end
    if IsValid(e:GetParent()) then error("Unparent this prop before editing Fin 3; parent physics is outside this adapter's edit scope",0) end
    if IsValid(e.Fin2_Ent) then error("Remove the existing Fin 2 modifier first",0) end
    local old=active(e)
    if old and old.owner~=S.owner then error("This Fin 3 modifier belongs to another player",0) end
    local before=S.fin3Spec(e)
    local modes={}
    for _,kind in ipairs({spec and spec.kind or "",before and before.kind or ""}) do
        if kind~="" then modes[kind=="propeller" and "fin3_propeller" or "fin3"]=true end
    end
    for mode in pairs(modes) do
        if hook.Run("CanTool",S.owner,{Entity=e,HitPos=e:WorldSpaceCenter(),HitNormal=e:GetUp(),Hit=true},mode)==false then error("Server denied the Fin 3 tool",0) end
    end
    if spec and spec.kind=="fin" then
        local size=e:OBBMaxs()-e:OBBMins()
        local f,u=Vector(unpack(spec.forward)),Vector(unpack(spec.up))
        if math.abs(size:Dot(f))<0.1 or math.abs(size:Dot(f:Cross(u)))<0.1 then error("Fin has no usable chord or span",0) end
    end
end
local function limits(changes)
    local counts={fin=Fin3.playerFinCount[S.owner] or 0,propeller=Fin3.playerPropellerCount[S.owner] or 0}
    for _,c in ipairs(changes) do
        local before=S.fin3Spec(c.e)
        if before then counts[before.kind]=counts[before.kind]-1 end
        if c.spec then counts[c.spec.kind]=counts[c.spec.kind]+1 end
    end
    for kind,n in pairs(counts) do
        local cv=GetConVar(kind=="fin" and "sbox_max_fin3" or "sbox_max_fin3_propellers")
        if not cv or n>cv:GetInt() then error("Fin 3 server limit reached for "..kind,0) end
    end
end
local function detach(e)
    local old=active(e) if old then old:remove() end
end
local function attach(e,a)
    if not a then return end
    if a.kind=="fin" then
        Fin3.fin:new(S.owner,e,{forwardAxis=Vector(unpack(a.forward)),upAxis=Vector(unpack(a.up)),finType=a.airfoil,
            camber=a.camber,efficiency=a.efficiency,inducedDrag=a.induced_drag,disableLowPass=a.disable_lowpass,version=Fin3.version})
    else
        Fin3.propeller:new(S.owner,e,{forwardAxis=Vector(unpack(a.forward)),bladeCount=a.blades,diameter=a.diameter,
            bladePitch=a.pitch,invertRotation=a.invert})
    end
    if not active(e) then error("Fin 3 rejected the modifier",0) end
end
function S.fin3Read(e)
    if not S.fin3Available() then return nil end
    local f,p=Fin3.fins[e],Fin3.propellers[e]
    local out={ref=S.entityRef(e),settings=S.fin3Spec(e),active=f~=nil or p~=nil}
    if f then out.telemetry={surface_area_m2=f.surfaceArea,aspect_ratio=f.aspectRatio,angle_of_attack_degrees=f.angleOfAttack,
        lift_newtons=f.liftForceNewtons,drag_newtons=f.dragForceNewtons,airspeed_mps=math.sqrt(math.max(0,f.velMsSqr or 0))} end
    if p then out.telemetry={rpm=p.invertRotation and -p.rpm or p.rpm,thrust_newtons=p.lastForce,torque_nm=p.lastTorque} end
    return out
end
function S.fin3Catalog(a)
    local installed=S.fin3Available() local items={}
    if installed then
        for id,m in pairs(Fin3.models) do
            if not m.hidden and id:find(string.lower(a.query or ""),1,true) then items[#items+1]={id=id,kind="airfoil",camber=m.canCamber==true,base_stall_degrees=m.stallAngle} end
        end
        table.sort(items,function(x,y)return x.id<y.id end)
    end
    return {installed=installed,workshop_url=URL,items=items,total=#items,
        limits=installed and {fins=GetConVar("sbox_max_fin3"):GetInt(),propellers=GetConVar("sbox_max_fin3_propellers"):GetInt()} or nil,
        help="Create props with fin3 settings or use sandbox_fin3_apply. Local forward/up must be perpendicular cardinal unit vectors. Surface area comes from actual prop dimensions, not mass. Propellers need physical rotation from a motor/E2; pitch alone does not spin them. Fin 3 and Wiremod are separate optional addons. Read live forces with fin3_inspect/measure; blueprints preserve settings."}
end
H.sandbox_fin3_inspect=function(a)
    requireFin() local entities=S.buildEntities(a,false) local out={}
    for _,e in ipairs(entities) do out[#out+1]=S.fin3Read(e) end
    return {entities=out,installed=true,air_density_kg_m3=Fin3.airDensity}
end
-- Shared path for standalone edits and atomic creation/blueprint loading.
function S.fin3Apply(items,withUndo)
    requireFin()
    if not istable(items) or #items<1 or #items>128 then error("Use 1-128 Fin 3 edits",0) end
    local changes,seen,entities={},{},{}
    for _,item in ipairs(items) do
        local e=S.resolveEntity(item.ref,true) if seen[e] then error("Duplicate Fin 3 ref",0) end seen[e]=true
        if item.remove~=nil and not isbool(item.remove) then error("remove must be boolean",0) end
        if item.remove and item.fin3 then error("Choose fin3 settings or remove, not both",0) end
        local spec=not item.remove and S.validateFin3(item.fin3) or nil
        target(e,spec)
        local m=S.tracked[e]
        changes[#changes+1]={e=e,spec=spec,before=S.fin3Spec(e),physical=physics(e),base=m.fin3_base,revision=m.revision,
            token=active(e) and active(e).SandboxMCPToken}
        entities[#entities+1]=e
    end
    limits(changes)
    local function rollback()
        for _,c in ipairs(changes) do detach(c.e) end
        for _,c in ipairs(changes) do
            attach(c.e,c.before) restorePhysics(c.e,c.physical)
            if active(c.e) then active(c.e).SandboxMCPToken=c.token end
            local m=S.tracked[c.e] m.fin3_base=c.base m.revision=c.revision
        end
    end
    local ok,err=pcall(function()
        for _,c in ipairs(changes) do detach(c.e) end
        for _,c in ipairs(changes) do
            local m=S.tracked[c.e]
            if c.spec then m.fin3_base=m.fin3_base or c.physical attach(c.e,c.spec)
            else restorePhysics(c.e,m.fin3_base or c.physical) m.fin3_base=nil end
            m.revision=m.revision+1
            c.appliedToken=S.instance..":"..tostring(SysTime())..":"..c.e:EntIndex()
            if active(c.e) then active(c.e).SandboxMCPToken=c.appliedToken end
        end
    end)
    if not ok then local restored,why=pcall(rollback) error("Fin 3 batch failed: "..tostring(err)..(restored and "; rolled back" or "; rollback failed: "..tostring(why)),0) end
    local op
    if withUndo then op=S.operation("Fin 3",entities,function()
        local reverse={}
        for _,c in ipairs(changes) do
            local e=S.resolveEntity(S.entityRef(c.e),true)
            if S.tracked[e].revision~=c.revision+1 or (active(e) and active(e).SandboxMCPToken~=c.appliedToken) or not same(S.fin3Spec(e),c.spec) then error("Fin 3 part changed later; undo its later edits first",0) end
            target(e,c.before) reverse[#reverse+1]={e=e,spec=c.before}
        end
        limits(reverse) rollback()
    end) end
    local result={} for _,e in ipairs(entities) do result[#result+1]=S.fin3Read(e) end
    return {operation_id=op,entities=result}
end
H.sandbox_fin3_apply=function(a)return S.fin3Apply(a.items,true)end
function S.fin3RemoveForCleanup(e)
    if S.fin3Available() then
        if Fin3.fins[e] then Fin3.fins[e]:remove() end
        if Fin3.propellers[e] then Fin3.propellers[e]:remove() end
    end
end
