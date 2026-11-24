SandboxMCP = SandboxMCP or {}
local S = SandboxMCP
if S.disconnect then S.disconnect() end
if S.root then file.Delete(S.root .. "/status.json") end
S.version = "0.5.0"
S.instance = util.SHA256(tostring(os.time()) .. ":" .. tostring(SysTime()) .. ":" .. tostring(math.random())):sub(1, 24)
S.root = "sandbox_mcp/instances/" .. S.instance
S.connected, S.owner, S.token = false, nil, nil
S.builds, S.operations, S.events, S.pending = S.builds or {}, S.operations or {}, S.events or {}, {}
S.sequence, S.eventSequence = S.sequence or 0, S.eventSequence or 0
S.completed, S.completedOrder = {}, {}
for _, path in ipairs({"sandbox_mcp", "sandbox_mcp/instances", S.root, S.root .. "/requests", S.root .. "/responses"}) do file.CreateDir(path) end
for _, name in ipairs({"sandbox_mcp_consent", "sandbox_mcp_state", "sandbox_mcp_view", "sandbox_mcp_capture", "sandbox_mcp_image"}) do util.AddNetworkString(name) end

function S.write(path, value)
    local tmp = path .. ".tmp.json"
    file.Write(tmp, util.TableToJSON(value, false))
    if file.Exists(path, "DATA") then file.Delete(path) end
    file.Rename(tmp, path)
end
function S.event(kind, details, request)
    S.eventSequence = S.eventSequence + 1
    table.insert(S.events, {sequence=S.eventSequence, time=os.time(), kind=kind, details=details, request_id=request})
    if #S.events > 200 then table.remove(S.events, 1) end
end
function S.reply(request, ok, value)
    if request.replied then return end
    request.replied = true
    S.pending[request.id] = nil
    local response=ok and {ok=true, data=value} or {ok=false, error=tostring(value)}
    S.write(S.root .. "/responses/" .. request.id .. ".json", response)
    S.completed[request.id]=response S.completedOrder[#S.completedOrder+1]=request.id
    if #S.completedOrder>512 then S.completed[table.remove(S.completedOrder,1)]=nil end
    S.event(ok and "completed" or "error", {tool=request.tool, operation_id=istable(value) and value.operation_id or nil, error=not ok and tostring(value) or nil}, request.id)
end
function S.notify()
    S.write(S.root .. "/status.json", {version=S.version, instance=S.instance, heartbeat=os.time(), map=game.GetMap(),
        connected=S.connected, screenshots=S.captureAllowed == true and S.connected, player=IsValid(S.owner) and S.owner:Nick() or nil,
        gamemode=engine.ActiveGamemode(), part_count=S.liveCount and S.liveCount() or 0, wiremod=S.wireAvailable and S.wireAvailable() or false, fin3=S.fin3Available and S.fin3Available() or false, cogworks=S.cogworksAvailable and S.cogworksAvailable() or false, flowmod=S.flowmodAvailable and S.flowmodAvailable() or false, e2_allowed=S.connected and S.e2Allowed==true, capabilities={"inspect", "build", "undo", "physics", "camera", "optional_wiremod", "blueprints", "checkpoints", "wire_batch", "assembly_transform", "measure", "diagnose", "optional_e2", "player_prop_grants", "optional_fin3", "optional_flowmod", "optional_cogworks"}})
    if not IsValid(S.owner) then return end
    net.Start("sandbox_mcp_state")
    net.WriteBool(S.connected)
    net.WriteString(S.instance)
    net.WriteBool(S.captureAllowed == true)
    net.Send(S.owner)
end
function S.disconnect()
    if S.revokeGrants then S.revokeGrants() end
    S.e2Allowed=false
    S.connected, S.token = false, nil
    S.cameraPos, S.cameraUntil = nil, nil
    file.Delete(S.root .. "/auth.json")
    for _, request in pairs(table.Copy(S.pending)) do S.reply(request, false, "Host disconnected; operation cancelled.") end
    S.notify()
    S.event("disconnected", {})
end
net.Receive("sandbox_mcp_consent", function(_, ply)
    if not (game.SinglePlayer() or ply:IsListenServerHost()) then return end
    local enable, capture, e2 = net.ReadBool(), net.ReadBool(), net.ReadBool()
    if not enable then S.disconnect() return end
    if S.connected then S.disconnect() end
    S.owner, S.connected, S.captureAllowed = ply, true, capture
    S.e2Allowed=e2
    S.token = util.SHA256(S.instance .. tostring(SysTime()) .. tostring(math.random()))
    S.write(S.root .. "/auth.json", {token=S.token})
    S.notify()
    S.event("connected", {capture=capture})
end)
hook.Add("PlayerDisconnected", "SandboxMCPConsent", function(ply) if ply == S.owner then S.disconnect() end end)
hook.Add("ShutDown", "SandboxMCPShutdown", function() S.disconnect() file.Delete(S.root .. "/status.json") end)

include("sandbox_mcp/world.lua")
include("sandbox_mcp/wire.lua")
include("sandbox_mcp/expression2.lua")
include("sandbox_mcp/fin3.lua")
include("sandbox_mcp/flowmod.lua")
include("sandbox_mcp/cogworks.lua")
include("sandbox_mcp/builds.lua")
include("sandbox_mcp/experiments.lua")
include("sandbox_mcp/grants.lua")

local handlers = S.handlers
handlers.sandbox_events = function(a)
    local items = {}
    for _, event in ipairs(S.events) do if event.sequence > (tonumber(a.after) or 0) then items[#items+1] = event end end
    local result = {}
    for i=1, math.min(#items, math.Clamp(tonumber(a.limit) or 40, 1, 100)) do result[i] = items[i] end
    return {events=result, latest=S.eventSequence, next_after=result[#result] and result[#result].sequence or a.after or 0}
end
handlers.sandbox_view = function(a)
    if not S.captureAllowed then error("Host has not allowed camera/screenshots. Enable the checkbox and reconnect.", 0) end
    if a.restore then
        S.cameraPos, S.cameraUntil = nil, nil
        net.Start("sandbox_mcp_view") net.WriteBool(false) net.Send(S.owner)
        return {restored=true}
    end
    local pos, target = S.vector(a.pos), S.vector(a.look_at)
    local check=util.TraceHull({start=pos,endpos=pos,mins=Vector(-3,-3,-3),maxs=Vector(3,3,3),filter=S.owner})
    if check.StartSolid or check.AllSolid then error("Camera position is inside solid geometry. Trace a clear position or use the player's eye_pos from inspect.",0) end
    local sight=util.TraceLine({start=pos,endpos=target,filter=S.owner,mask=MASK_SOLID_BRUSHONLY})
    if sight.HitWorld and sight.Fraction<0.97 then error("The camera's view of the target is blocked by world geometry. Use sandbox_trace to choose a clear angle.",0) end
    local fov = S.number(a.fov or 75, 20, 110)
    S.cameraPos, S.cameraUntil = pos, SysTime()+30
    net.Start("sandbox_mcp_view") net.WriteBool(true) net.WriteVector(pos) net.WriteAngle((target-pos):Angle()) net.WriteFloat(fov) net.Send(S.owner)
    return {position=S.xyz(pos), look_at=S.xyz(target), expires_in=30}
end
hook.Add("SetupPlayerVisibility","SandboxMCPCameraVisibility",function(ply)
    if S.connected and ply==S.owner and S.cameraPos and SysTime()<(S.cameraUntil or 0) then AddOriginToPVS(S.cameraPos) end
end)
handlers.sandbox_screenshot = function(a, request)
    if not S.captureAllowed then error("Host has not allowed screenshots. Enable the camera/screenshots checkbox and reconnect.", 0) end
    for _, p in pairs(S.pending) do if p.tool == "sandbox_screenshot" then error("Another screenshot is in progress; wait for it to finish.", 0) end end
    S.pending[request.id] = request
    request.image, request.imageSize, request.chunk = {}, 0, 0
    net.Start("sandbox_mcp_capture") net.WriteString(request.id) net.WriteUInt(math.floor(S.number(a.quality or 80, 35, 95)), 7) net.WriteBool(a.square_preview==true) net.Send(S.owner)
    return nil
end
net.Receive("sandbox_mcp_image", function(_, ply)
    if not S.connected or ply ~= S.owner or not S.captureAllowed then return end
    local id = net.ReadString()
    local request = S.pending[id]
    if not request or request.tool ~= "sandbox_screenshot" then return end
    local success = net.ReadBool()
    if not success then S.reply(request, false, net.ReadString():sub(1, 200)) return end
    local index, last, length = net.ReadUInt(10), net.ReadBool(), net.ReadUInt(16)
    if index ~= request.chunk + 1 or length > 48000 or request.imageSize + length > 4*1024*1024 then
        S.reply(request, false, "Screenshot exceeded its size limit or arrived out of order.") return
    end
    request.chunk, request.imageSize = index, request.imageSize + length
    request.image[index] = net.ReadData(length)
    if last then
        local name = id .. ".jpg"
        file.Write(S.root .. "/responses/" .. name, table.concat(request.image))
        S.reply(request, true, {image_file=name, bytes=request.imageSize, map=game.GetMap(), source="consenting_host_game_view"})
    end
end)

local nextPoll, nextHeartbeat = 0, 0
hook.Add("Think", "SandboxMCPBridge", function()
    local clock = SysTime()
    if clock >= nextHeartbeat then
        nextHeartbeat = clock + 1
        if S.connected and not IsValid(S.owner) then S.disconnect() end
        S.write(S.root .. "/status.json", {version=S.version, instance=S.instance, heartbeat=os.time(), map=game.GetMap(),
            connected=S.connected, screenshots=S.captureAllowed == true and S.connected, player=IsValid(S.owner) and S.owner:Nick() or nil,
            gamemode=engine.ActiveGamemode(), part_count=S.liveCount(), wiremod=S.wireAvailable and S.wireAvailable() or false, fin3=S.fin3Available and S.fin3Available() or false, cogworks=S.cogworksAvailable and S.cogworksAvailable() or false, flowmod=S.flowmodAvailable and S.flowmodAvailable() or false, e2_allowed=S.connected and S.e2Allowed==true, capabilities={"inspect", "build", "undo", "physics", "camera", "optional_wiremod", "blueprints", "checkpoints", "wire_batch", "assembly_transform", "measure", "diagnose", "optional_e2", "player_prop_grants", "optional_fin3", "optional_flowmod", "optional_cogworks"}})
    end
    if clock < nextPoll then return end
    nextPoll = clock + 0.06
    for _, request in pairs(table.Copy(S.pending)) do if request.expires < os.time() then S.reply(request, false, "Operation expired. Unpause the game, then retry read-only operations.") end end
    local files = file.Find(S.root .. "/requests/*.json", "DATA")
    for index, filename in ipairs(files) do
        if index > 4 then break end
        local id = filename:match("^([%x%-]+)%.json$")
        local path = S.root .. "/requests/" .. filename
        local size = file.Size(path, "DATA")
        if id and #id <= 64 and size >= 0 and size <= 262144 then
            local raw = file.Read(path, "DATA")
            file.Delete(path)
            local decoded = raw and util.JSONToTable(raw)
            if istable(decoded) and decoded.id == id then
                local request={id=id,instance=decoded.instance,token=decoded.token,expires=decoded.expires,tool=decoded.tool,args=decoded.args}
                if not S.connected or request.token ~= S.token or request.instance ~= S.instance then
                    S.reply(request, false, "Connection is no longer authorized. Reconnect in-game.")
                elseif not isnumber(request.expires) or request.expires < os.time() or request.expires > os.time()+30 then
                    S.reply(request, false, "Expired request; nothing was changed.")
                elseif S.completed[id] then
                    S.write(S.root .. "/responses/" .. id .. ".json",S.completed[id])
                elseif S.pending[id] then
                    -- Same request is still running. Do not execute it twice.
                elseif not handlers[request.tool] or not istable(request.args) then
                    S.reply(request, false, "Unknown tool or invalid arguments.")
                else
                    local ok, result = pcall(handlers[request.tool], request.args, request)
                    if not ok then S.reply(request, false, result)
                    elseif result ~= nil then S.reply(request, true, result) end
                end
            end
        else file.Delete(path) end
    end
end)
