local connected, captureAllowed, instance, camera, capture = false, false, "", nil, nil
local imageChunks
net.Receive("sandbox_mcp_state",function()
    connected,instance,captureAllowed=net.ReadBool(),net.ReadString(),net.ReadBool()
    if not connected then camera,capture,imageChunks=nil,nil,nil end
    notification.AddLegacy(connected and "Sandbox MCP connected" or "Sandbox MCP disconnected",NOTIFY_GENERIC,4)
end)
local function consent(enable, screens)
    net.Start("sandbox_mcp_consent") net.WriteBool(enable) net.WriteBool(screens==true) net.SendToServer()
end
concommand.Add("sandbox_mcp_disconnect",function()consent(false,false)end)
hook.Add("PopulateToolMenu","SandboxMCPPanel",function()
    spawnmenu.AddToolMenuOption("Utilities","Sandbox MCP","SandboxMCPConnection","Connection","","",function(panel)
        panel:ClearControls()
        local status=panel:Help("Disconnected")
        status.Think=function(self)
            local message=connected and "Connected · AI access is on" or "Disconnected · AI access is off"
            if self:GetText()~=message then self:SetText(message) end
        end
        panel:Help("1. Add the Sandbox MCP companion to your AI app.\n2. Start a Sandbox map.\n3. Connect here and ask your AI to build something.")
        local allow=vgui.Create("DCheckBoxLabel",panel)
        allow:SetText("Allow game screenshots and temporary camera") allow:SetValue(1) allow:SetDark(true) allow:SizeToContents() panel:AddItem(allow)
        local connect=panel:Button("Connect AI") connect.DoClick=function()consent(true,allow:GetChecked())end
        local disconnect=panel:Button("Disconnect") disconnect.DoClick=function()consent(false,false)end
        panel:Help("Only the local host can connect. Your AI can inspect the game and change objects it creates. Screenshots capture only the game view. No API key belongs in this addon.")
        panel:Help("Undo: Z or the Undo tab; your AI can also undo an individual operation by name. Camera views reset after 30 seconds.")
        local copy=panel:Button("Copy setup command") copy.DoClick=function()SetClipboardText("sandbox-mcp setup") notification.AddLegacy("Setup command copied",NOTIFY_GENERIC,3)end
        local badge=panel:Help("Need help? Run sandbox-mcp doctor in the companion folder.")
    end)
end)
net.Receive("sandbox_mcp_view",function()
    if not connected or not captureAllowed then return end
    if not net.ReadBool() then camera=nil return end
    camera={origin=net.ReadVector(),angles=net.ReadAngle(),fov=net.ReadFloat(),untilTime=RealTime()+30,drawviewer=true}
end)
hook.Add("CalcView","SandboxMCPCamera",function()
    if camera then if RealTime()>camera.untilTime then camera=nil else return camera end end
end)
net.Receive("sandbox_mcp_capture",function()
    local id,quality,square=net.ReadString(),net.ReadUInt(7),net.ReadBool()
    if connected and captureAllowed then capture={id=id,quality=quality,square=square,ready=RealTime()+0.15} end
end)
hook.Add("PostRender","SandboxMCPCapture",function()
    if not capture or RealTime()<capture.ready then return end
    local req=capture capture=nil
    local w,h=ScrW(),ScrH()
    if req.square then w=math.min(512,w,h) h=w end
    local data=render.Capture({format="jpeg",quality=req.quality,x=math.floor((ScrW()-w)/2),y=math.floor((ScrH()-h)/2),w=w,h=h})
    if not data or #data>4*1024*1024 then
        net.Start("sandbox_mcp_image") net.WriteString(req.id) net.WriteBool(false) net.WriteString("Close the pause menu and retry; no image was captured.") net.SendToServer() return
    end
    imageChunks={id=req.id,data=data,offset=1,index=0}
end)
hook.Add("Think","SandboxMCPImageSend",function()
    if not imageChunks then return end
    local b=imageChunks
    local chunk=b.data:sub(b.offset,b.offset+47999) b.offset=b.offset+#chunk b.index=b.index+1
    net.Start("sandbox_mcp_image") net.WriteString(b.id) net.WriteBool(true) net.WriteUInt(b.index,10) net.WriteBool(b.offset>#b.data) net.WriteUInt(#chunk,16) net.WriteData(chunk,#chunk) net.SendToServer()
    if b.offset>#b.data then imageChunks=nil end
end)
hook.Add("HUDPaint","SandboxMCPIndicator",function()
    if connected then draw.SimpleText("Sandbox MCP connected · Q → Utilities to disconnect","DermaDefault",16,16,Color(110,230,210)) end
end)
local lightEntities,nextLights={},0
hook.Add("Think","SandboxMCPLights",function()
    if RealTime()>nextLights then nextLights=RealTime()+1 lightEntities={} for _,e in ipairs(ents.FindByClass("prop_physics")) do if e:GetNWBool("SandboxMCPLight") then lightEntities[#lightEntities+1]=e end end end
    for i,e in ipairs(lightEntities) do
        if i>24 then break end
        if IsValid(e) then local light=DynamicLight(e:EntIndex()) if light then local c=e:GetColor() light.pos=e:GetPos()+Vector(0,0,24) light.r=c.r light.g=c.g light.b=c.b light.brightness=1.2 light.Decay=1000 light.Size=300 light.DieTime=CurTime()+0.2 end end
    end
end)
