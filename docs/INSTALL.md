# Sandbox MCP — start here

The addon and Windows companion are MIT licensed. You need Garry's Mod and
an AI application that supports local **stdio MCP** servers.

## Quick setup

1. Subscribe to [Sandbox MCP on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3839989108).
2. Download the [Windows companion ZIP](https://github.com/skulitom/sandbox-mcp/releases/latest),
   extract it and double-click **Setup.vbs**. Alternatively,
   double-click `sandbox-mcp.exe`; both open the local setup page in your browser.
3. Choose **Codex**, **Claude Desktop**, **Cursor**, or **GitHub Copilot / VS Code**, then click
   **Connect this app**. Setup installs the companion in your local application
   data and adds its configuration. Existing settings are preserved, with a
   backup beside the configuration file. Close your AI app before configuring it,
   then reopen it and enable/approve its Sandbox MCP tools.
4. Start a **Sandbox** map in Garry's Mod. Open **Q → Utilities → Sandbox MCP →
   Connection**. Review the screenshot option and click **Connect AI**.
5. Ask your AI to check `sandbox_status`, then build something together.

No Node.js, Python, API key, administrator access, game DLL, or insecure HTTP
setting is required. Workshop supplies the Lua addon; your AI application runs
the small external companion. Subscribing alone cannot configure the AI app.

Example prompts:

> Build a drivable cargo rover near me. Find suitable props, keep the driver's
> view clear, weld the cargo to the vehicle, and take a screenshot to check it.

> Create a colourful sculpture with three concentric rings and floating cubes.
> Use a single labelled build so we can undo it together.

> Inspect the rover's mass and physics. Watch it settle for three seconds and
> tell me whether anything moved unexpectedly.

## Other clients

Run `sandbox-mcp config` from the companion folder and merge the printed entry
into your client's MCP configuration. Keep that executable in a permanent folder.
The command is the absolute executable path; arguments begin with `serve`.

The wizard also offers the older VS Code Local-harness configuration format.
For a custom `COPILOT_HOME`, or a non-default editor profile, use manual setup
in that profile instead of the wizard's standard user directory.

If game detection fails, append `--game-dir` and the full path to the
**garrysmod** directory (the one containing `gameinfo.txt`). If several game
sessions are running, select one with `--instance ID`, using an ID reported by
`sandbox-mcp doctor`. The companion refuses to guess between live sessions.

Browser-only chat applications generally cannot launch a local stdio process.
Use a desktop/CLI MCP client. Setup supports configuration formats; individual
models vary in building ability and may require tool approvals in their app.

## Controls and access

- **Connect AI** enables this map session. **Disconnect** immediately revokes
  access and resets the temporary camera. Restarting/changing maps disconnects.
- Only the local singleplayer/listen-server host can connect. Other players do
  not gain access by subscribing. Dedicated-server and remote-machine control
  are not supported in 0.1.0.
- The AI can inspect the world, but can edit/remove only objects it created for
  this host. It has no arbitrary Lua, console, shell, or filesystem tool.
- Screenshots are optional. They contain the consenting host's game view, never
  the desktop. Temporary camera views reset after 30 seconds.
- Use **Z** / the Undo tab, or ask the AI to undo a specific `operation_id`.
  Targeted undo preserves unrelated later edits. Undo refuses to overwrite later
  AI edits to the same part; undo those later edits first. Cleanup is permanent.
- Builds remain ordinary in-game entities and can affect gameplay through
  normal collisions or NPC behavior. Constraints use GMod's native physics.

## Troubleshooting

Run `sandbox-mcp doctor` for detected game paths and live connection status.

- **No game session:** start Sandbox with the addon installed and unpause.
  Singleplayer pause can stop tool processing. A recently closed game may take
  up to 12 seconds to disappear from diagnostics.
- **Disconnected:** click Connect AI in the Utilities panel. The AI cannot
  grant itself permission or keep access after a map change.
- **Screenshot failed:** close the pause menu, enable screenshots and reconnect.
- **Request timed out:** unpause, then ask the AI to inspect the scene and recent
  events before retrying a build; it may already have completed.
- **Config has comments / invalid JSON:** setup leaves it unchanged. Use the
  manual configuration snippet and your client's configuration editor.
- **Existing Sandbox MCP entry:** review it, then check the replacement checkbox
  if you want setup to update that entry. Other servers are preserved.
- **Windows does not run Setup.vbs:** run `sandbox-mcp.exe setup` instead.

To uninstall: disconnect, remove only the `sandbox-mcp` entry from your AI
client's configuration, unsubscribe/remove the addon, and remove the companion's
`SandboxMCP` folder under local application data after closing the AI app. Your
other MCP servers and game settings are independent of this addon.

## Optional Wiremod

Subscribe to [Wiremod](https://steamcommunity.com/sharedfiles/filedetails/?id=160250458)
and restart the map. No additional companion or configuration is needed.
`sandbox_status` reports `wiremod: true`; `sandbox_catalog` with `kind: wire`
lists the supported components, settings and gate actions. The ordinary building
and inspection tools work without Wiremod.

Try: “Use Wiremod to build a button-controlled pulse display. Connect a timed
gate to alternating coloured indicators and a screen. Inspect its signals and
check that the button stops and starts it.”

Create a component with `kind: wire`, a catalog `preset`, and optional `settings`.
Use `sandbox_wire_ports` for exact port names/types, `sandbox_wire_connect` for
output-to-input connections, and `sandbox_wire_set` for constants and buttons.
Connections are real Wiremod links. Physical attachment is separate: use
`sandbox_connect` to weld sensors or thrusters onto a vehicle. Thrusters push
along local -Z; `[180,0,0]` points their thrust upward.

Only AI-created components can be changed. Inputs already wired must first be
explicitly disconnected. Port types must match. Instant feedback cycles are
rejected; use the timed gates for pulses. Wiring, disconnection and source
changes each return a specific undo operation. Expression 2, arbitrary Wire
entity creation and control of manually created Wire components are outside
this first release.
