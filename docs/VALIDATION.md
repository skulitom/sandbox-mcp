# Validation — 15 November 2026

Windows x64; Garry's Mod build 10175; Sandbox on `gm_construct` in Anode's separate
desktop. The user's main desktop was not used for game tests. Building tools were
called through real stdio MCP, not substituted direct game-file commands.

## Checks

- **5 Rust checks:** preserving JSON/TOML settings and comments, malformed config
  refusal, VS Code schema, and identifier/path handling.
- **24 setup checks:** five client targets, preserved settings, backups,
  idempotent setup, stable executable installation, wrong-origin/token refusal,
  unknown-client refusal and clean shutdown. All use isolated profiles.
- **30 native checks:** model bounds/pagination, scene creation, all four
  constraint kinds and undo, protected player, invalid paths/positions/labels,
  failed prevalidation, targeted/out-of-order undo, stale references, gravity
  observation, NPC creation, cleanup isolation, camera placement and JPEG.
- **9 transport checks:** token/instance/expiry rejection without side effects,
  duplicate UUID executes once, cross-session entity references, six concurrent
  MCP clients receiving the right result.
- **3 protocol revisions:** 2025-03-26 and 2025-11-25 initialization; 2026-07-28
  discovery and request metadata. Tool discovery and structured results work.
- **10 read-only evaluation questions:** answers in `tests/evaluation.xml` were
  independently derived from the two fixed example builds through MCP.
- `cargo clippy --all-targets -- -D warnings` passes.

Manual/native evidence:

- Connected using the actual Utilities panel. Disconnect caused MCP inspection
  to fail. Reconnected with screenshots unchecked: inspection worked and capture
  was refused. Raw logs: `artifacts/consent-*.json`.
- Injected a one-shot weld failure after part creation in the isolated Anode
  session. The batch rolled back, entity count remained 34 and both earlier builds
  stayed intact. The injected wrapper restored the original weld function. This
  fault injection is not distributed. Logs: `artifacts/injected-rollback.json` and
  `artifacts/after-injected-rollback.json`.
- The real browser wizard's Connect button created the isolated Codex
  configuration and displayed live game status.
- GMod's `gmad.exe` accepted the original four Lua files. The actual GMA mounted in server
  and client realms, both reporting success and four files. Native and transport
  evaluations passed against the packed addon as well as development files.

Raw evidence stays locally under `artifacts/`, excluded from source control.
Test scripts and fixtures are included in source.

## Workflow measurements

The **Chromatic gate laboratory** uses 26 parts in one create call. On the packed
addon, creation took 134 ms. Ground tracing, creation, camera selection and capture
took 1.12 seconds of scripted execution, excluding design and earlier iteration.

The **Field survey rover** uses eight parts and seven native welds. Creation took
135 ms; the script including a three-second physics observation took 4.30 seconds.
It adds cargo, side panels, a deck and lamps to the stock drivable chassis.

Entered and drove the rover with normal game input. Three seconds of acceleration
moved it approximately 1,568 Source units; all eight parts remained present. The
first run continued into the map's pond: this verifies driving and attachments,
not a vehicle handling benchmark. Side panels were then lowered/reoriented to
clear the driver's view.

Dogfooding found and fixed temporary-file extensions, model bounds lookup,
camera placement/occlusion/visibility, hot-reload handler references, stale
session/entity IDs, and a clipped connection-status label.

## Preview limits

- Windows companion, local singleplayer/listen-server host. Dedicated servers,
  remote machines, macOS/Linux binaries and a second multiplayer client were not
  validated.
- Client configuration formats were tested. Full conversational testing inside
  every vendor's UI/model was not performed. The assistant used the real MCP tools
  to inspect, build, view, revise and evaluate scenes.
- 128 parts / 256 connections per batch; 512 live owned parts; model index capped
  at 50,000. Large builds still incur normal rendering/physics costs.
- Stock GMod constraints retain normal solver limits. StrongWeld is not required
  or bundled. NPC spawning supports the explicitly listed base classes.
- No arbitrary Lua or arbitrary scripted-entity spawning, or edits to pre-existing props.
  Undo is session-local; cleanup is permanent. General blueprint save/load is
  not included; example scripts reproduce the demonstrations.
- Setup alone runs a temporary loopback web server with an unpredictable URL and
  Host/Origin checks. It closes after Finish or 15 minutes. Game control uses
  stdio and local files, with no control HTTP listener.

## Primary references

- [Workshop packaging](https://wiki.facepunch.com/gmod/Workshop_Addon_Creation)
- [Official Rust MCP SDK](https://github.com/modelcontextprotocol/rust-sdk)
- [Native screenshot API](https://wiki.facepunch.com/gmod/render.Capture)
- [Entity identity](https://wiki.facepunch.com/gmod/Entity:GetCreationID)
- [Valve model headers](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/public/studio.h)
- [Codex configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
- [Cursor configuration](https://cursor.com/docs/mcp)
- [Copilot / VS Code configuration](https://code.visualstudio.com/docs/agents/reference/mcp-configuration)
- [Claude Desktop local setup](https://modelcontextprotocol.io/docs/2026-07-28/develop/connect-local-servers)

## Wiremod release integration

Optional Wiremod adapter tested against upstream commit
`0464cecb3bdacc9ea886c0a4ae244e8f040269f4` on the same native GMod build.
**21 real-MCP checks pass:** all eight component presets, port discovery,
button/constant propagation through gates and displays, actual indicator colours,
source undo, rewiring undo, occupied/type-mismatched ports, feedback rejection,
ownership, bounded settings, physical thruster movement, velocity and GPS values.
Missing Wiremod reports an actionable installation message and does not disable
base tools. Wiremod code/assets are neither vendored nor included in the GMA.
The pulse laboratory example also exercises a running timed gate.

Reference: [Wiremod source](https://github.com/wiremod/wire).

Final release GMA: five Lua files; extracted files match source exactly.
Steam-downloaded archive SHA-256 equals the tested GMA. All native, transport
and Wiremod checks above were repeated with the final portable release executable
and GMA mounted in both realms.
