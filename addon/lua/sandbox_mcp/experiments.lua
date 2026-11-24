local S,H=SandboxMCP,SandboxMCP.handlers
local function sample(e)
    local i=S.entityInfo(e)
    local result={ref=i.ref,pos=i.pos,angles=i.angles,velocity=i.physics and i.physics.velocity,frozen=i.physics and i.physics.frozen}
    if S.tracked[e] and S.tracked[e].wire and S.wirePorts then
        local ports=S.wirePorts(e) result.inputs={} result.outputs={}
        for _,kind in ipairs({"inputs","outputs"}) do
            for index,p in ipairs(ports[kind]) do if index<=32 then result[kind][p.name]=p.value end end
        end
    end
    if S.fin3Read then result.fin3=S.fin3Read(e) end
    if i.cogworks then result.cogworks=i.cogworks end
    if S.flowmodRead then result.flowmod=S.flowmodRead(e) end
    return result
end
H.sandbox_measure=function(a,request)
    local entities=S.buildEntities(a,false)
    if #entities>8 then error("Measure at most eight entities; select the sensors or main body",0) end
    local duration=S.number(a.seconds or 3,0.2,20)
    local interval=S.number(a.interval or 0.2,0.1,2)
    local started,nextSample=SysTime(),0
    local samples,summary={},{}
    local bytes,truncated=0,false
    for _,e in ipairs(entities) do summary[e]={ref=S.entityRef(e),start=S.xyz(e:GetPos()),max_speed=0,max_tilt_degrees=0} end
    S.pending[request.id]=request
    timer.Create("SandboxMCPMeasure"..request.id,0.05,0,function()
        if request.replied or not S.connected then timer.Remove("SandboxMCPMeasure"..request.id) return end
        local elapsed=SysTime()-started
        if elapsed>=nextSample then
            nextSample=elapsed+interval local row={t=elapsed,entities={}}
            for _,e in ipairs(entities) do
                local stat=summary[e]
                if IsValid(e) then
                    row.entities[#row.entities+1]=sample(e)
                    stat.max_speed=math.max(stat.max_speed,e:GetVelocity():Length())
                    stat.max_tilt_degrees=math.max(stat.max_tilt_degrees,math.deg(math.acos(math.Clamp(e:GetUp().z,-1,1))))
                    stat.finish=S.xyz(e:GetPos()) stat.displacement=e:GetPos():Distance(Vector(unpack(stat.start)))
                else stat.removed=true end
            end
            local size=#util.TableToJSON(row)
            if bytes+size>700000 then truncated=true else samples[#samples+1]=row bytes=bytes+size end
        end
        if elapsed>=duration or truncated then
            timer.Remove("SandboxMCPMeasure"..request.id)
            local stats={} for _,e in ipairs(entities) do stats[#stats+1]=summary[e] end
            S.reply(request,true,{seconds=elapsed,interval=interval,samples=samples,summary=stats,truncated=truncated,limit_reason=truncated and "700 KB sample limit; measure fewer signals or a longer interval" or nil,tick_interval=engine.TickInterval(),units={position="Source units",speed="Source units/second",tilt="degrees from world up"}})
        end
    end)
end
H.sandbox_diagnose=function(a)
    local entities=S.buildEntities(a,false) local selected,issues,parts={},{},{}
    for _,e in ipairs(entities) do selected[e]=true end
    local function issue(kind,e,details) issues[#issues+1]={kind=kind,ref=S.entityRef(e),details=details} end
    local mass,frozen=0,0
    for _,e in ipairs(entities) do
        local info=S.entityInfo(e) parts[#parts+1]=info
        if info.flowmod and info.flowmod.fault~="" then issue("flowmod_fault",e,info.flowmod.fault) end
        if info.physics then mass=mass+info.physics.mass if info.physics.frozen then frozen=frozen+1 end end
        for name,p in pairs(e.Inputs or {}) do
            if not IsValid(p.Src) then issue("unconnected_input",e,name)
            elseif not selected[p.Src] then issue("external_wire_source",e,name) end
        end
        if e.error and not e.SandboxMCPPaused then issue("component_error",e,tostring(e.SandboxMCPError or e.error_message or e.error)) end
        local overlap=util.TraceEntity({start=e:GetPos(),endpos=e:GetPos(),filter=function(other)return other==game.GetWorld() end},e)
        if overlap.StartSolid then issue("world_overlap",e,"Physics hull intersects world geometry") end
    end
    return {parts=parts,total_mass=mass,frozen_parts=frozen,issues=issues,help="Unconnected inputs may intentionally use defaults. Diagnostics describe observations, not proof of a broken circuit."}
end
H.sandbox_transform=function(a)
    local entities=S.buildEntities(a,true)
    local pivot=a.pivot and S.vector(a.pivot) or entities[1]:GetPos()
    local translation=S.vector(a.translation or {0,0,0})
    local rotation=Angle(unpack(a.rotation or {0,0,0})) S.vector(a.rotation or {0,0,0})
    local edits={}
    for _,e in ipairs(entities) do
        local pos,ang=LocalToWorld(e:GetPos()-pivot,e:GetAngles(),pivot+translation,rotation)
        edits[#edits+1]={ref=S.entityRef(e),pos=S.xyz(pos),angles={ang.p,ang.y,ang.r},frozen=a.frozen,velocity={0,0,0}}
    end
    return H.sandbox_edit({items=edits})
end
H.sandbox_align=function(a)
    local moving=S.buildEntities(a,true)
    local target=S.resolveEntity(a.target,false)
    local selected={} for _,e in ipairs(moving) do selected[e]=true end
    if selected[target] then error("Alignment target cannot be part of the moving selection",0) end
    local axis=({x=1,y=2,z=3})[a.axis or "z"] if not axis then error("axis must be x, y or z",0) end
    local face=a.face or "max" if face~="max" and face~="min" then error("face must be min or max",0) end
    local clearance=S.number(a.gap or 0,0,512)
    local lo,hi=target:WorldSpaceAABB() local low,high={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
    for _,e in ipairs(moving) do local l,h=e:WorldSpaceAABB() for n=1,3 do low[n]=math.min(low[n],l[n]) high[n]=math.max(high[n],h[n]) end end
    local delta=Vector()
    for n=1,3 do
        if n==axis then delta[n]=face=="max" and hi[n]+clearance-low[n] or lo[n]-clearance-high[n]
        elseif a.center~=false then delta[n]=(lo[n]+hi[n]-low[n]-high[n])*0.5 end
    end
    return H.sandbox_transform({refs=a.refs,build_id=a.build_id,translation=S.xyz(delta),frozen=a.frozen})
end
