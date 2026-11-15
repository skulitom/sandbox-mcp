# Sandbox MCP — Workshop listing

https://steamcommunity.com/sharedfiles/filedetails/?id=3839989108

Title: **Sandbox MCP - Build with AI**

Native in-game preview and gallery; no generated cover.

Showcase: https://www.youtube.com/watch?v=30DsajKY70I

[h1]Build in Garry’s Mod with your AI assistant[/h1]
Find props, create a complete labelled scene, connect its parts, test the physics and inspect the result through in-game screenshots. Ask your AI to refine the build or undo a specific change.

[b]Requires the free Windows companion and an AI app with local MCP support.[/b]
Workshop installs the Lua addon. The companion connects it to your AI app and includes a setup wizard. No Node.js, Python or game DLL is required.

[url=https://github.com/skulitom/sandbox-mcp/releases/latest]Download the companion[/url]
[url=https://github.com/skulitom/sandbox-mcp/blob/main/docs/INSTALL.md]Setup guide and troubleshooting[/url]
[url=https://github.com/skulitom/sandbox-mcp]MIT-licensed source on GitHub[/url]

[h2]Get started[/h2]
[list]
[*]Subscribe to this addon.
[*]Download and extract the companion. Open Setup.vbs or sandbox-mcp.exe.
[*]Choose your AI app, then restart it and enable Sandbox MCP.
[*]Start a Sandbox map. Open Q → Utilities → Sandbox MCP → Connection and click Connect AI.
[/list]
The wizard supports Codex, Claude Desktop, Cursor and GitHub Copilot / VS Code. Other local stdio MCP clients can use the manual configuration command.

Try: “Build me a cargo rover. Keep the driver's view clear, weld the cargo to the chassis, test its physics and show me a screenshot.”

[h2]Useful building tools[/h2]
[list]
[*]Create named parts and physical connections in one call.
[*]Search mounted models, vehicle presets and supported NPCs.
[*]Inspect dimensions, placement, mass, motion and nearby entities.
[*]Native weld, no-collide, axis and rope connections.
[*]Specific-operation undo plus GMod’s familiar Undo menu.
[*]Optional game screenshots and temporary camera views.
[*]Clear connection status and an in-game disconnect control.
[/list]

[h2]Optional Wiremod integration[/h2]
With [url=https://steamcommunity.com/sharedfiles/filedetails/?id=160250458]Wiremod[/url] installed, your AI can create buttons, numeric constants, logic/timed gates, thrusters, indicators, screens, speedometers and GPS sensors. Inspect live ports and values, connect real signals, change controls and undo wiring changes.

Try: “Build a button-controlled Wiremod pulse display with alternating lights and a numeric screen. Inspect the circuit and test the button.”

Wiremod is a separate, optional addon. Restart the map after installing it. Expression 2 scripting, arbitrary Wire entities and editing manually created Wire components are not supported in this first version.

[h2]You stay in control[/h2]
Only the local singleplayer/listen-server host can connect. The AI can inspect the game, but editing tools affect only objects it creates. Screenshot permission is separate. Disconnect revokes the connection. There is no arbitrary Lua, console, shell or filesystem tool.

The companion needs a desktop/CLI AI client that supports local MCP. Browser-only chat apps may not support it. Windows x64 companion; dedicated-server and remote-machine connections are outside version 0.1. Native physics and the AI model’s building choices still matter.

Original code: MIT. Wiremod is not bundled. Game assets belong to their respective authors.
