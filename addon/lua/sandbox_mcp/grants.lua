local S=SandboxMCP
util.AddNetworkString("sandbox_mcp_grant") util.AddNetworkString("sandbox_mcp_revoke")
function S.revokeGrants()
    for id,b in pairs(S.builds) do if b.adopted then
        for _,e in ipairs(b.entities) do if S.tracked[e] and S.tracked[e].grant==id then S.tracked[e]=nil end end
        S.builds[id]=nil
    end end
end
function S.grantAssembly(ply,root)
    if not S.connected or S.owner~=ply then error("Connect Sandbox MCP first",0) end
    if not IsValid(root) or root:IsWorld() then error("Aim at a prop you created",0) end
    local connected=constraint.GetAllConstrainedEntities(root) connected[root]=root
    local entities,records={},{}
    for _,e in pairs(connected) do
        if not IsValid(e) or e:IsWorld() or e:IsPlayer() or e:IsNPC() then error("Only player-built prop assemblies can be granted",0) end
        local owner=e.CPPIGetOwner and e:CPPIGetOwner() or e:GetCreator()
        if owner~=ply then error("Every part must belong to you",0) end
        if S.tracked[e] then error("This assembly already contains AI-controlled parts",0) end
        if e:GetClass()~="prop_physics" then error("This release grants prop_physics assemblies only; unsupported part: "..e:GetClass(),0) end
        entities[#entities+1]=e
    end
    if #entities>128 or S.liveCount()+#entities>512 then error("Assembly exceeds the part limit",0) end
    table.sort(entities,function(a,b)return a:EntIndex()<b:EntIndex()end)
    local id=util.SHA256(S.instance..":grant:"..SysTime()):sub(1,16)
    for i,e in ipairs(entities) do
        S.tracked[e]={owner=ply,build=id,label="part-"..i,revision=0,grant=id,spec={kind="prop",model=e:GetModel()}}
        for _,c in ipairs(constraint.GetTable(e) or {}) do
            -- Blueprint restoration only represents unlimited, no-collide welds.
            -- Other manual constraints remain editable but saving refuses to
            -- silently replace their behavior with a different constraint.
            local compatible=c.Type=="NoCollide" or (c.Type=="Weld" and (c.forcelimit or 0)==0 and c.nocollide==true)
            if IsValid(c.Constraint) and compatible and (c.Bone1 or 0)==0 and (c.Bone2 or 0)==0 then
                S.constraintRecords[c.Constraint]={a=c.Ent1,b=c.Ent2,spec={kind=c.Type=="Weld" and "weld" or "nocollide"}}
            end
        end
    end
    S.builds[id]={name="Player-granted prop assembly",entities=entities,connections=records,owner=ply,adopted=true}
    S.event("assembly_granted",{build_id=id,parts=#entities})
    return id,#entities
end
net.Receive("sandbox_mcp_grant",function(_,ply)
    local root=net.ReadEntity()
    local ok,id,count=pcall(S.grantAssembly,ply,root)
    ply:ChatPrint(ok and ("Sandbox MCP: granted "..count.." parts. Ask the AI to inspect your builds.") or ("Sandbox MCP: "..tostring(id)))
end)
net.Receive("sandbox_mcp_revoke",function(_,ply)
    if ply~=S.owner then return end S.revokeGrants() ply:ChatPrint("Sandbox MCP: access to player-built assemblies revoked.")
end)
