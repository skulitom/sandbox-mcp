-- Private Anode package test. Never distribute this autorun with the addon.
if SERVER then AddCSLuaFile() end
local ok,files=game.MountGMA("addons/sandbox_mcp_package_test.gma")
print("[Sandbox MCP package mount]",SERVER and "server" or "client",ok,files and #files)
assert(ok,"Sandbox MCP test archive did not mount")
include("autorun/sandbox_mcp.lua")
-- Exercise the same consent message as the panel in this explicitly authorized
-- isolated test desktop. The production addon never grants its own permission.
if CLIENT then timer.Simple(2,function()
    net.Start("sandbox_mcp_consent") net.WriteBool(true) net.WriteBool(true) net.WriteBool(true) net.SendToServer()
end) end
