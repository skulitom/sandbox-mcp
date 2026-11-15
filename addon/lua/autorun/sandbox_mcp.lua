-- Sandbox MCP. Original implementation; MIT license.
if SERVER then
    AddCSLuaFile("sandbox_mcp/client.lua")
    include("sandbox_mcp/server.lua")
else
    include("sandbox_mcp/client.lua")
end
