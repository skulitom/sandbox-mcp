# Sandbox MCP

An original Workshop-compatible Garry's Mod addon and portable MCP companion.
Build scenes and contraptions, inspect the real game, test physics, capture the
result and undo changes through useful structured tools.

**0.4.0 beta.** [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3839989108) · [Download the Windows companion](https://github.com/skulitom/sandbox-mcp/releases/latest) and follow the [setup guide](docs/INSTALL.md).

[Launch showcase](https://www.youtube.com/watch?v=30DsajKY70I) ·
[Wiremod rocket](https://www.youtube.com/watch?v=OYWIcwcRxZA) ·
[Fin 3 flight](https://www.youtube.com/watch?v=vvdCXAwM8vg) ·
[Installation](docs/INSTALL.md) · [Validation and limits](docs/VALIDATION.md) ·
[Workshop listing](docs/WORKSHOP.md) · [Design](docs/DESIGN.md)

The game addon is pure Lua. The companion runs outside the game and exposes
standard MCP over stdio using the official Rust SDK. No game DLL, localhost
network bypass, API key, or model-specific code is required by the bridge.
An MCP-capable AI client supplies the model.

**New in 0.4:** [FlowMod integration](docs/FLOWMOD.md) adds hydraulic and
pneumatic construction, inspection, tuning and fluid blueprints. Install
[FlowMod](https://steamcommunity.com/sharedfiles/filedetails/?id=3841216963)
separately and update both the Sandbox MCP addon and Windows companion to 0.4.0.

The addon is disabled until the host connects through Q > Utilities >
Sandbox MCP > Connection. Disconnect revokes the current connection. Building tools own their
creations; inspecting an existing prop does not authorize modifying it. The host
can explicitly grant and revoke access to an aimed assembly of their own props.
Opting into E2 separately permits code with the host’s normal Wiremod permissions.

Original code: MIT. Game assets remain owned by their authors; no game assets
are redistributed by this project.

The companion exposes 31 tools: connection diagnostics, model/vehicle/NPC
catalogs, world inspection, placement traces, batched scene creation, edits,
physical connections, targeted undo, build cleanup, temporary camera views,
game screenshots, physics observation, recent operation events, and optional
Wiremod port inspection, signal wiring/disconnection and source control. Version
0.2 adds portable contraption blueprints, checkpoints, atomic Wire batches, group
transforms, face alignment, time-series measurements, diagnostics and Expression 2.

With [Wiremod](https://steamcommunity.com/sharedfiles/filedetails/?id=160250458)
installed, create buttons, constants, gates, thrusters, indicators, screens,
speedometers and GPS sensors. The AI can inspect live signals, wire a circuit,
change its controls and undo individual changes. Wiremod remains optional; it
is not bundled. Ranger and gyroscope sensors support feedback controllers.
Expression 2 requires a separate host opt-in and keeps Wiremod permissions and
quotas; code compiles stopped until explicitly run. Arbitrary Wire entities are
not supported.

With [Fin 3 - Superior Flight](https://steamcommunity.com/sharedfiles/filedetails/?id=3113528615)
installed, configure wings and propellers, inspect lift, drag, angle of attack,
RPM and thrust, and record those values during physics tests. Blueprints preserve
the aerodynamic settings. The optional integration uses Fin 3's own simulation;
Fin 3 is installed separately and is not bundled. Propellers need a physical
motor, such as an opt-in Wiremod E2 controller. Existing users must update the
Windows companion to 0.4.0 too.

The setup wizard supports Codex, Claude Desktop, Cursor, GitHub Copilot/VS Code,
and the older VS Code Local harness. It preserves other settings and backs up
existing configuration files. Other stdio MCP clients can use `sandbox-mcp config`.

![A gate sculpture created through real MCP calls](docs/images/chromatic-gate.jpg)

![An optional Wiremod pulse circuit](docs/images/wire-pulse.jpg)

![A drivable rover created through real MCP calls](docs/images/field-rover.jpg)

These are native captures. Both examples were built through the public MCP tools,
with transcripts and timings retained. Reproduce them with `tools/dogfood_scene.py`
and `tools/dogfood_rover.py` against a connected `gm_construct` session.
`tools/dogfood_hovercraft.py` builds, measures and saves a 15-part E2 hovercraft.
`tools/dogfood_fin3.py` builds and tunes a real Fin 3 glider.
See [the workflow guide](docs/WORKFLOWS.md) for persistence and controller examples. Python is
a development/test dependency only; users run the portable Rust executable.

## Build and test

```powershell
cargo build --release --locked
cargo test --locked
cargo clippy --all-targets -- -D warnings
python tests/setup_evaluation.py
python tests/protocol_evaluation.py
# Requires a connected Sandbox session:
python tests/native_evaluation.py
python tests/transport_evaluation.py
# With optional Wiremod installed:
python tests/wire_evaluation.py
# With optional Fin 3 installed:
python tests/fin3_evaluation.py
# With the private test fixture in tests/ (never install on a public server):
python tests/workflow_evaluation.py
```

`tools/package.ps1` validates the addon with GMod's own `gmad.exe` and prepares the
local GMA and Windows ZIP. `tools/third_party_notices.py` collects dependency
license notices for the companion. The private Anode package fixture in `tests/`
is never included in the Workshop package. Dependency licenses are included with
the portable download.
