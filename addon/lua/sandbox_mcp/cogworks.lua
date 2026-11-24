-- Optional adapter. Resolve the addon after autorun, including on maps without Cogworks.
local S = SandboxMCP
local H = S.handlers
local workshop = "https://steamcommunity.com/sharedfiles/filedetails/?id=3845221917"

function S.cogworksAvailable()
    local c = Cogworks
    return c ~= nil and istable(c.Parts) and isfunction(c.PlanMount) and isfunction(c.SpawnPart)
        and isfunction(c.ConnectShaft) and isfunction(c.InspectDrivetrain)
end

local function native()
    if not S.cogworksAvailable() then error("Optional Cogworks addon unavailable. Subscribe to Cogworks and reload the map: "..workshop, 0) end
    return Cogworks
end

function S.cogworksCatalog(a)
    local result = {available=S.cogworksAvailable(), workshop=workshop, parts={}}
    if not result.available then return result end
    local c = Cogworks
    local matches = {}
    local query = string.lower(a.query or "")
    for kind, def in pairs(c.Parts) do
        if (kind.." "..def.name):lower():find(query, 1, true) then
            matches[#matches+1] = {kind=kind, name=def.name, compact=c.CompactParts[kind] == true,
                mesh=c.EditableWheel(kind) == true}
        end
    end
    table.SortByMember(matches, "kind", true)
    local start = math.floor(S.number(a.offset or 0, 0, 100000))
    local limit = math.floor(S.number(a.limit or 40, 1, 40))
    for i=start+1, math.min(#matches, start+limit) do result.parts[#result.parts+1] = matches[i] end
    result.total, result.teeth = #matches, c.Sizes
    result.next_offset = start+limit < #matches and start+limit or nil
    return result
end

local function integer(value, low, high)
    S.number(value, low, high)
    if value ~= math.floor(value) then error("Expected an integer", 0) end
    return value
end

local function permission(e, tr)
    if S.owner:EyePos():DistToSqr(tr.HitPos) > 512^2 then error("Move within 512 units of the mount or part", 0) end
    if (IsValid(e) and e.CPPICanTool and e:CPPICanTool(S.owner, "cogworks") == false)
        or hook.Run("CanTool", S.owner, tr, "cogworks") == false then error("Cogworks tool permission denied", 0) end
end

local function bearing(c, ref, write)
    local e = S.resolveEntity(ref, write)
    if not c.Bearing(e) or not e.CogRotor then error("Choose a Cogworks rotating part", 0) end
    if write then permission(e, {Entity=e, Hit=true, HitPos=e:GetPos(), PhysicsBone=0}) end
    return e
end

local function capacity()
    if S.liveCount() >= 512 or not S.owner:CheckLimit("cogworks") then error("Mechanical part limit reached", 0) end
end

function S.cogworksRead(e)
    if not S.cogworksAvailable() or not Cogworks.Bearing(e) or not e.CogRotor then return end
    return {kind=e:GetPartKind(), teeth=e:GetTeeth(), compact=e:GetCompact(),
        rpm=e.CogRotor.omega*60/(2*math.pi), angle_degrees=math.deg(e.CogRotor.angle)}
end

H.sandbox_cogworks_inspect = function(a)
    local c = native()
    local e = bearing(c, a.ref, false)
    local result = S.cogworksRead(e)
    local report = c.InspectDrivetrain(e)
    result.ref, result.sockets, result.neighbors = S.entityRef(e), {}, {}
    for i=0,c.LastShaftSocket(e) do
        result.sockets[#result.sockets+1] = {index=i, name=c.ShaftSocketName(e,i), available=c.BusyShaftSocket(e,i)==nil}
    end
    result.status, result.next_action = report.status, report.action
    if IsValid(report.cause) then result.cause = S.entityRef(report.cause) end
    for _,neighbor in ipairs(report.neighbors) do result.neighbors[#result.neighbors+1] = S.entityRef(neighbor) end
    return result
end

local function mountTrace(c, a, mode)
    if mode ~= "surface" then
        local e = bearing(c, a.target, true)
        local theta = math.rad(S.number(a.bearing_degrees or 0, -360, 360))
        local radius = mode == "mesh" and c.PartRadius(e:GetPartKind(), e:GetTeeth())*c.PartScale(e) or 0
        return {Hit=true, Entity=e, HitPos=e:LocalToWorld(Vector(radius*math.cos(theta), radius*math.sin(theta), 0)),
            HitNormal=e:GetUp(), PhysicsBone=0}
    end
    if not a.target then
        if a.point or a.normal then error("Local point and normal require a support ref", 0) end
        local tr = S.owner:GetEyeTrace()
        if not tr.HitWorld or tr.HitSky then error("Aim at nearby world geometry or provide a support ref with a local point and normal", 0) end
        return tr
    end
    local e = S.resolveEntity(a.target, true)
    local point = e:LocalToWorld(S.vector(a.point))
    local n = S.vector(a.normal)
    if n:IsZero() then error("Choose a nonzero surface normal", 0) end
    n = e:LocalToWorld(n:GetNormalized()) - e:GetPos()
    local tr = util.TraceLine({start=point+n*4, endpos=point-n*4, filter=S.owner})
    if tr.StartSolid or tr.Entity ~= e or tr.HitNormal:Dot(n) < .8 then error("Local point and outward normal must identify an exposed face of the support", 0) end
    return tr
end

local function register(e, label)
    S.tracked[e] = {owner=S.owner, label=label, revision=0, cogworks=true}
end

H.sandbox_cogworks_mount = function(a)
    local c = native()
    capacity()
    if not c.Parts[a.kind] then error("Unknown rotating part; use sandbox_catalog kind=cogworks", 0) end
    local mode = a.mode or "surface"
    if mode ~= "surface" and mode ~= "mesh" and mode ~= "hub" then error("Expected surface, mesh or hub", 0) end
    local teeth = integer(a.teeth or 24, 1, 100)
    if not table.HasValue(c.Sizes, teeth) then error("Unsupported tooth count; see catalog", 0) end
    if a.compact and not c.CompactParts[a.kind] then error("This part has no compact size", 0) end
    local label = a.label or a.kind
    if not isstring(label) or #label < 1 or #label > 64 then error("Use a label of 1-64 characters", 0) end
    local tr = mountTrace(c, a, mode)
    permission(tr.Entity, tr)
    local plan, why = c.PlanMount(tr, a.kind, teeth, a.compact == true, false)
    if not plan or plan.blocked then error(why or (plan and plan.blocked) or "Mount refused", 0) end
    if plan.mode ~= (mode == "surface" and "mount" or mode) then error("These parts cannot use that mount mode", 0) end
    if not util.IsInWorld(plan.pos) then error("Chosen position lies outside the map", 0) end
    if IsValid(plan.support) and plan.support ~= tr.Entity then
        S.resolveEntity(S.entityRef(plan.support), true)
        permission(plan.support, {Entity=plan.support, Hit=true, HitPos=plan.pos, PhysicsBone=0})
    end
    local old = IsValid(plan.target) and plan.target.CogRotor
    local phase = old and (mode == "hub" and old.angle or c.Rotation.meshPhase(old, teeth, plan.bearing)) or nil
    local e, err = c.SpawnPart(S.owner, a.kind, teeth, plan.pos, plan.ang, plan.support, phase, plan.scale,
        integer(a.spokes or 6,3,12), IsValid(plan.support) and c.FrameFor(plan.support)==plan.support, false, integer(a.crank_throw or 2,1,3))
    if not IsValid(e) then error(err or "Cogworks could not create the part", 0) end
    if old then
        if not c.ConnectMountedParts(plan.target, e, plan.ratio) then e:Remove() error("Cogworks could not couple the gears", 0) end
        if IsValid(e.CogSolidWheel) then e.CogSolidWheel:CollisionRulesChanged() end
        if IsValid(plan.target.CogSolidWheel) then plan.target.CogSolidWheel:CollisionRulesChanged() end
    end
    register(e, label)
    local deps = {e}
    if IsValid(tr.Entity) then deps[#deps+1] = tr.Entity end
    if IsValid(plan.support) then deps[#deps+1] = plan.support end
    local op = S.operation("mount "..label, deps, function() if IsValid(e) then e:Remove() end end)
    return {ref=S.entityRef(e), mode=mode, ratio=plan.ratio, pos=S.xyz(e:GetPos()), operation_id=op}
end

H.sandbox_cogworks_connect = function(a)
    local c = native()
    capacity()
    local first, second = bearing(c,a.from,true), bearing(c,a.to,true)
    local sockets = {from=integer(a.from_socket or c.PickShaftSocket(first,true),0,c.LastShaftSocket(first)),
        to=integer(a.to_socket or c.PickShaftSocket(second,false),0,c.LastShaftSocket(second))}
    if a.kind ~= nil and a.kind ~= "shaft" and a.kind ~= "belt" then error("Choose shaft or belt", 0) end
    local link, why = c.ConnectShaft(S.owner,first,second,true,sockets,a.kind=="belt")
    if not IsValid(link) then error(why or "Cogworks refused the connection", 0) end
    register(link, a.kind or "shaft")
    local op = S.operation("connect Cogworks "..(a.kind or "shaft"), {first,second,link}, function() if IsValid(link) then link:Remove() end end)
    return {ref=S.entityRef(link), sockets=sockets, operation_id=op}
end

H.sandbox_cogworks_drive = function(a)
    local c = native()
    local e = bearing(c,a.ref,true)
    local kind = e:GetPartKind()
    if kind ~= "crank" and kind ~= "pedals" then error("Drive a hand crank or pedals; inspect downstream parts to measure transmission", 0) end
    local seconds = S.number(a.seconds or 1, .1, 5)
    local direction = a.direction or 1
    if direction ~= 1 and direction ~= -1 then error("Direction must be 1 or -1", 0) end
    c.Use(S.owner,e)
    -- Extend the native Use input for a bounded pulse. The drivetrain supplies all forces.
    e.CogRotor.crankUntil = CurTime()+seconds
    e.CogRotor.direction = direction
    return {ref=a.ref, seconds=seconds, direction=direction}
end
