# Sandbox MCP — Workshop listing

https://steamcommunity.com/sharedfiles/filedetails/?id=3839989108

Title: **Sandbox MCP - Build with AI**

Existing native in-game cover and gallery retained.

[h1]Build in Garry's Mod with your AI assistant[/h1]
Find props, build a complete contraption, connect its parts, test the physics and inspect real game screenshots. Ask your AI to refine it, save it or undo a specific change.

[b]New in 0.4: FlowMod hydraulics and pneumatics, real pressure/flow measurements, hose controls and fluid blueprints.[/b]
Existing users: update the Windows companion too, then restart your AI app and map.

[b]Requires the free Windows companion and an AI app with local MCP support.[/b]
Workshop supplies the Lua addon. The companion supplies the MCP server and setup wizard. No Node.js, Python or game DLL is required.

[url=https://github.com/skulitom/sandbox-mcp/releases/latest]Download the companion[/url]
[url=https://github.com/skulitom/sandbox-mcp/blob/main/docs/INSTALL.md]Setup and troubleshooting[/url]
[url=https://github.com/skulitom/sandbox-mcp/blob/main/docs/WORKFLOWS.md]Blueprints, E2 and workflow guide[/url]
[url=https://github.com/skulitom/sandbox-mcp]MIT-licensed source[/url]
[url=https://www.youtube.com/watch?v=30DsajKY70I]Watch the in-game showcase[/url]
[url=https://www.youtube.com/watch?v=OYWIcwcRxZA]Watch the Wiremod rocket demo[/url]
[url=https://www.youtube.com/watch?v=vvdCXAwM8vg]Watch the Fin 3 flight demo[/url]

[h2]Get started[/h2]
[list]
[*]Subscribe to this addon.
[*]Download and extract the companion. Open Setup.vbs or sandbox-mcp.exe.
[*]Choose your AI app, restart it and enable Sandbox MCP.
[*]Start Sandbox. Open Q > Utilities > Sandbox MCP > Connection and click Connect AI.
[/list]
The wizard supports Codex, Claude Desktop, Cursor and GitHub Copilot / VS Code. Other local stdio MCP clients can use the manual configuration command.

Try: "Build me a cargo rover. Keep the driver's view clear, test its physics, take a screenshot, and save it as my_rover."

[h2]Build, save and improve[/h2]
[list]
[*]31 structured tools, including all the original tools.
[*]Portable JSON blueprints: save, share, import and load supported contraptions at another position or rotation.
[*]Named checkpoints for repeatable experiments in the current map.
[*]Move/rotate an assembly together; align its bounding face with a target and chosen clearance.
[*]Find mounted models using size filters and shape hints.
[*]Record physics and live Wire signals for up to 20 seconds; inspect diagnostics.
[*]Native weld, no-collide, axis and rope links; targeted undo and the familiar Undo menu.
[*]Optional game screenshots and temporary camera views.
[/list]
Blueprints restore frozen by default, with buttons off and E2 stopped. Models and dependencies must be installed. This is a supported-parts format, not a universal duplicator.

[h2]Optional Wiremod and Expression 2[/h2]
With [url=https://steamcommunity.com/sharedfiles/filedetails/?id=160250458]Wiremod[/url], create buttons, constants, logic/timed gates, thrusters, indicators, screens, speedometers, GPS, gyroscopes, rangers and E2 chips.

Build parts, physical constraints and signal wiring in one operation. Batch existing connections with validation, rollback and one undo. Inspect actual port values and record how a circuit behaves over time.

E2 is [b]off by default[/b] and needs separate host permission in the connection panel. Code compiles stopped; run it explicitly. Invalid uploads preserve working code. Stop resets outputs. E2 retains Wiremod's normal player permissions, enabled extensions and server quotas, so permitted code can also affect other props owned by the host. Code undo cannot reverse those world effects.

Try: "Build an E2 hover platform with ground rangers. Save a checkpoint, measure its height and tilt, and tune the controller."

Wiremod is a separate optional addon. Arbitrary Wire components and grants of manually built Wire contraptions are not supported.

[h2]Optional Fin 3 - Superior Flight[/h2]
With [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3113528615]Fin 3[/url], ask your AI to build an aircraft, set wing axes and airfoils, tune camber and propellers, then measure lift, drag, angle of attack, RPM and thrust while it flies.

The forces come from Fin 3's own aerodynamic simulation. Blueprints preserve the settings. Native tool permissions and quotas apply. Writes support unparented single-body physics props. Propellers need real motor rotation; Wiremod E2 can supply a controller with your separate permission.

Try: "Build a Fin 3 glider, measure its flight, improve the tail and save the design."

Fin 3 is a separate optional addon, not bundled. Update the Windows companion to 0.4.0 to expose the new tools.

[h2]Optional FlowMod hydraulics and pneumatics[/h2]
With [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3841216963]FlowMod[/url], ask your AI to build a hydraulic lift or stored-air machine, connect hoses, operate pumps and valves, and measure pressure, flow and actual load movement.

Four new tools inspect circuits, connect and disconnect hoses, and tune settings. Existing creation, measurement and blueprint tools understand FlowMod parts, cylinder anchors and fluid links. Optional Wiremod signals can drive these parts too.

Try: "Build a FlowMod hydraulic lift, measure how it raises a 100 kg load, then save its blueprint."

Uses FlowMod's real simulation, permissions and limits. Controls apply to AI-created circuits; manually built FlowMod machines cannot be granted to MCP in this version. Loaded fluid blueprints start depressurised with sources off and valves holding. Connected Wire controllers can activate them. Parts must be within 800 units of the player.

[url=https://github.com/skulitom/sandbox-mcp/blob/main/docs/FLOWMOD.md]FlowMod tools, examples and limits[/url]. FlowMod is a separate optional addon; update the companion to 0.4.0 as well.

[h2]You stay in control[/h2]
Only the local singleplayer/listen-server host can connect. Ordinary editing tools affect AI-created objects and your prop assemblies that you explicitly grant through the panel. Revoke grants at any time without deleting the props. Screenshot and E2 permissions are separate. Disconnect blocks new commands and revokes grants; existing autonomous circuits keep running unless stopped.

No arbitrary Lua, console, shell or filesystem tool. Windows x64 companion; local stdio MCP client required. Dedicated servers and remote machines are not supported in 0.4. Native physics and the AI model's building choices still matter. StrongWeld integration is not included.

Original code: MIT. Wiremod, Fin 3 and FlowMod are not bundled. Game assets belong to their authors.
