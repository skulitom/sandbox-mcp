# Build, save, test and refine — 0.2

Start with `sandbox_status` and `sandbox_catalog`. The model catalog accepts
`shape` filename hints, `physics_only`, and local model `min_size`/`max_size`
triples. Bounds are model-header bounds, not a guarantee of collision clearance.
Use placement traces and inspect the actual spawned part too.

## One complete circuit

`sandbox_create` accepts labelled `entities`, physical `links`, and `wire_links`.
Wire links use part labels: `{"from":"button","output":"Out","to":"lamp","input":"A"}`.
A failed part, constraint or signal connection removes the entire new batch.
On existing parts, `sandbox_wire_batch` accepts stable entity refs and returns one
undo for the batch. It rejects occupied inputs, mismatched types and feedback
cycles before modifying the graph. Runtime failures remove the links it added.
This is graph rollback, not reversal of side effects a running circuit produced.
Build frozen and start controls only after assembling the circuit.

## Keep a contraption between sessions

Ask: “Save this build as my_rover. Load another copy over there facing east.”

- `sandbox_blueprint` supports save, list, export, import and load.
- Save stores the supported parts, poses, mass, appearance, physical constraints,
  Wire connections, live constants and E2 source. Names use letters, digits,
  underscores or hyphens. Replacing a saved name requires `overwrite: true`.
- Export returns a portable JSON object. Share that JSON; import stores it in the
  current host’s blueprint library. Referenced models/addons must be installed.
- Load can change origin/rotation. It returns new build IDs and entity refs.
  Parts load frozen by default, buttons off and E2 stopped. Activate explicitly.
  `frozen: false` preserves the individual saved frozen flags; it does not force
  every part to move. Only self-contained E2 source is supported, no includes.
- Files live in `garrysmod/data/sandbox_mcp/blueprints/<SteamID64>/`. Blueprints
  are up to 128 parts, 256 physical and 256 Wire connections, and 200 KB.
- Selections with NPCs, unsupported constraints or links leaving the selection
  are refused. This is an allowlisted format, not a universal GMod duplicator.

`examples/hovercraft.json` is a real MCP-built 15-part example with 12 signal
links, ground/front rangers, a gyroscope and E2 feedback. Import it, load above a
clear flat floor, inspect, then run its controller and unfreeze its parts. The
controller is a demonstration for `gm_construct`, not a terrain navigation system.
`tools/dogfood_hovercraft.py` reproduces construction, a 20-second measurement and
saving. It requires Wiremod and E2 opt-in.

## Repeat experiments

Before changing a build, save a named `sandbox_checkpoint`. Restore creates and
validates a replacement before removing the old build. **Use the returned new
build ID and refs**. Checkpoints last only for the map session (32 names maximum).
Restoring is replacement, not an undo of arbitrary world interactions. It needs
room for both copies within the part quota. Use durable blueprints for player-
granted assemblies; checkpoints replace AI-created builds only.

Use `sandbox_transform` for group translation/rotation. `sandbox_align` places
the group against a target’s world-axis bounding face with a chosen gap; it does
not infer a mesh face or rotate the group. Both return targeted undo operations.

`sandbox_measure` samples up to eight parts for 0.2–20 seconds, returning physics
poses/velocities and Wire inputs/outputs, plus peak speed, tilt and displacement.
Sampling interval is 0.1–2 seconds; real scheduling varies with the game tick.
The response stops at 700 KB and reports truncation. `sandbox_diagnose` reports
frozen parts, total mass, unconnected/external inputs, component errors and world
intersection. An unused input can be intentional; diagnostics are observations.

## Let AI help with your existing props

Aim at your assembly, open the connection panel and choose **Grant aimed prop
assembly**. Every constrained part must be a `prop_physics` belonging to you.
The AI can discover its build ID through inspection, then move, edit or remove
it. **Revoke access to my assemblies** removes access and blocks old undo actions;
it leaves the props in place. Disconnect also revokes grants. Wire components,
vehicles and other players’ props cannot be granted in this release. Blueprints
only preserve supported constraint settings; incompatible manual constraints
cause a save error instead of silently changing their physics.

## Remaining limits

StrongWeld integration, arbitrary addon adapters, native GMod dupe export,
mirroring, model thumbnails and remote/dedicated-server control are not included.
The existing 0.1 tools remain available. Native physics costs and solver limits
still apply; the MCP is a building interface, not a replacement physics engine.
