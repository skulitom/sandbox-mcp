# Scope and acceptance

Build from scratch, not a fork of another GMod MCP project. Standard protocol
libraries and documented game APIs are dependencies, not copied competing code.

Workshop ships Lua, UI and in-game help. Its whitelist excludes executables and
DLLs, so the portable companion is a separate download. Users subscribe, run the
companion setup once, select their AI client, start Sandbox, then click Connect.
Never claim that subscribing alone configures an external AI application.

## Transport

Official rmcp SDK, stdio. Companion discovers Steam libraries or accepts an
explicit game directory. Pure Lua reads an atomic file mailbox in DATA, with
per-request UUIDs, game-instance identity, expiring authorization and explicit
host opt-in. No network listener, binary module or arbitrary filesystem API in
the addon. Native screenshots are chunked from the consenting player to the
server, then returned as MCP image content.

Each game instance uses its own mailbox beneath data/sandbox_mcp/instances.
Startup publishes a fresh instance identifier; a companion must select exactly
one recent instance rather than accidentally acting on a different running game.
Expired or disconnected requests cannot be silently replayed on a later map.

## Tools and feedback

Status and errors explain the exact next step. Filtered/paginated model discovery
includes bounds. Entity references include creation identity, not reusable entity
indices alone. Scene creation validates the complete batch and rolls back on
failure. Builds have stable IDs, named parts and an explicit undo operation.
Edits and constraints are bounded and limited to the connected user's creations
or explicitly granted own prop assemblies.
The initial tools cover status, catalog, inspect, trace, create, edit, constraints,
undo, build cleanup, camera, screenshot, physics observation and event history.
The preview exposes no arbitrary Lua execution. The host controls connection
consent and optional screenshot/camera access separately.

## Evidence needed

- Real MCP initialization, tool discovery, calls, images, errors and reconnects.
- Valid GMA with no forbidden files or native game module.
- First-use setup tested with isolated client configuration, preserving existing
  settings. Standard configuration export for other MCP clients.
- Native permission, stale-reference, validation, rollback and undo checks.
- Build a drivable contraption and a visually interesting scene through MCP;
  record calls, elapsed time, screenshots and actual gameplay observations.
- Iterate on failures and awkward steps found while using the tools ourselves.
- Package, installation guide and accurate Workshop listing draft. Publication
  awaits the user's request or approval.

## 0.2 extension

The existing file-mailbox transport and 0.1 tools remain compatible. Four Lua
modules add portable allowlisted builds, experiments, E2 and player grants.
Blueprints contain declarative part specs, never arbitrary serialized Lua tables.
Loading reuses the same bounded create/rollback path. Signal batches prevalidate
the complete graph. Measurements are asynchronous and capped at 700 KB.

Expression 2 has a separate host consent flag, retains Wiremod permission/quota
checks, and compiles uploads stopped. It is deliberately documented as broader
than the ordinary per-entity MCP editing scope. Stop resets all typed outputs.
Granting existing props happens only via an authenticated in-game host action;
MCP cannot grant itself access. Revocation also guards historical undo closures.
