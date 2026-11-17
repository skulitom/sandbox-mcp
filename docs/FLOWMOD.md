# FlowMod integration

Sandbox MCP 0.4.0 adds four tools and FlowMod support to existing creation,
measurement and blueprint tools. Update both the addon and the
[Windows companion](https://github.com/skulitom/sandbox-mcp/releases/latest),
then install [FlowMod](https://steamcommunity.com/sharedfiles/filedetails/?id=3841216963)
separately. The bridge has 31 tools in total.

The fluid simulation runs in FlowMod. This adapter calls the same server APIs as
the toolgun; it does not emulate pressure, apply extra lifting forces or teleport
the load. Wiremod is optional. The existing host connection and ownership model
applies, including FlowMod's server permissions and part/hose limits.

## Building a circuit

1. Use `sandbox_catalog` with `kind: "flowmod"` to discover the twelve components,
   exact fluid port names, units, ranges and current server limits.
2. Use `sandbox_create` with `kind: "flowmod"` parts and a `flowmod` settings object.
   Position components within 800 Source units of the actual player. The camera
   tool does not move the player or extend reach.
3. Put same-batch labels in `fluid_links`. These are fluid hoses; `links` are
   physical constraints and `wire_links` are electrical control signals.
4. Sources start off, directional valves hold and new fluid state is unpressurised.
   Use `sandbox_flowmod_tune` to start a source and move a valve; release the load
   with `sandbox_edit` (`frozen: false`).
5. Inspect pressures, flows and faults using `sandbox_flowmod_inspect`, or record
   pressure and physical motion together using `sandbox_measure`.

Minimal hydraulic scene (pass this object to `sandbox_create`, adjusting origin
to nearby clear space):

```json
{
  "name": "Hydraulic lift",
  "origin": [400, 500, -125],
  "entities": [
    {"label":"base","model":"models/hunter/plates/plate1x1.mdl"},
    {"label":"load","model":"models/hunter/plates/plate1x1.mdl","pos":[0,0,110],"mass":100},
    {"label":"reservoir","kind":"flowmod","pos":[-130,0,0],"flowmod":{"kind":"reservoir"}},
    {"label":"pump","kind":"flowmod","pos":[-130,80,12],"flowmod":{"kind":"pump","pressure":40,"flow":12}},
    {"label":"valve","kind":"flowmod","pos":[-130,160,12],"flowmod":{"kind":"valve","opening":0.12}},
    {"label":"cylinder","kind":"flowmod","pos":[0,0,12],"flowmod":{"kind":"cylinder","bore":40,"stroke":80,"anchors":{"a":"base","b":"load","minimum":70}}}
  ],
  "links": [{"kind":"nocollide","a":"base","b":"load"}],
  "fluid_links": [
    {"a":"reservoir","port_a":"T","b":"pump","port_b":"T"},
    {"a":"pump","port_a":"P","b":"valve","port_b":"P"},
    {"a":"valve","port_a":"T","b":"reservoir","port_b":"R1"},
    {"a":"valve","port_a":"A","b":"cylinder","port_b":"A"},
    {"a":"valve","port_a":"B","b":"cylinder","port_b":"B"}
  ]
}
```

Use the returned stable pump/valve refs with `sandbox_flowmod_tune`:
`{"ref":"...","control":1}`. A valve accepts -1/retract, 0/hold, 1/extend and
intermediate proportional commands. Sources accept 0/off and 1/on (threshold
0.5). Targeted undo uses the returned `operation_id`.

Cylinder `anchors.a/b` are labels of different, unparented single-body physics
props in that create batch. Optional `point_a/point_b` are local physics-body
coordinates; their defaults are [0,0,0]. `minimum` is retracted length in Source
units. Frozen props serve as ground. This MCP version does not create world
anchors or attach a new cylinder to existing props outside the batch. The
FlowMod toolgun supports broader manual construction.

## Editing and signals

`sandbox_flowmod_connect` creates 1-128 hoses atomically using stable component
refs. Each port accepts one hose; use tees to branch. `sandbox_flowmod_disconnect`
accepts a hose ref from inspection. Undo reconnects only if both ports remain free
and permitted. A failed batch removes every hose it created. Undoing a connection
whose original hose was later removed/replaced is refused; inspect the new hose
and disconnect it explicitly.

Tunable settings depend on kind: pressure/flow for sources, opening for directional
and flow valves, pressure for reliefs, volume for air tanks. Air pressure is limited
to 20 gauge bar, oil to 200. Shrinking a charged tank can be refused until vented.
Tuning and undo are synchronous transactions; a native control error restores the
previous configuration and command without resetting fluid energy. Later manual
or MCP changes prevent stale undo. Resizing undo can also require venting.

When Wiremod is present, normal `wire_ports`, `wire_connect`, `wire_batch` and
`wire_disconnect` work on AI-created FlowMod components. A Wire constant's output
is named `1`; always inspect actual ports. Manual MCP tuning refuses any affected
setting with a connected Wire source. Change that source instead. Existing
feedback-cycle checks remain in force. Player grants currently cover ordinary
prop assemblies, not manually created FlowMod components.

## Saving and observation

Blueprints preserve component settings, fluid hoses, local cylinder anchors and
included Wire signals. Select both cylinder anchor props and every hose endpoint;
incomplete selections fail rather than reconnecting to original entities. Rotated
copies retain local anchors and reference only their own components. New copies
start unpressurised with sources off and valves holding, but copied Wire sources
can immediately activate them. Turn sources off before saving.

Inspection and time-series measurements return gauge bar, signed L/min (standard
litres for air), cylinder newtons, length in Source units and speed in m/s. Positive
flow leaves the component. Failed assemblies report paused state and zero flow/
force; pressure can retain the last valid state. `sandbox_diagnose` includes fluid
faults. Oil hose conductance is L/s/bar; air uses standard L/s per log absolute-
pressure ratio, matching FlowMod's passive gameplay model.

## Native validation

Anode tests through real MCP stdio and GMod:

- 34 hydraulic/Wire checks: real 100 kg load motion, transactions, permissions,
  stale undo, independent rotated copies, signal-driven pumps and a real screen.
- 19 pneumatic/import checks without Wiremod: compressed-air storage and a 20 kg
  lift after the compressor stops, tank capacity protection, bounded imports,
  partial-anchor selection, stale hose undo and server quotas. The earlier
  16-check pneumatic suite also passed with Wiremod installed.
- 12 boundary checks: CanTool/spawn vetoes, injected native failures, failed undo,
  manual changes, and paused assembly diagnostics/recovery.
- Existing Wiremod integration: 21 checks. Three MCP protocol versions expose
  31 unique tools; five Rust unit tests and Clippy pass.
- A separate cold launch without FlowMod or Wiremod passes five checks, including
  a helpful missing-dependency error and ordinary prop construction.

Scripts live in `tests/flowmod_*_evaluation.py`. The boundary fixture only injects
external test conditions and never changes host consent. It remains outside the
addon package. `tools/dogfood_flowmod.py` builds a 12-part, nine-hose twin-cylinder
200 kg lift, saves a blueprint, opens a valve through MCP, records actual motion
and captures the game view. Its initial narrow opening moved too slowly for the
demo threshold; the final example explicitly tunes it wider. Both receipts remain.

These checks do not replace FlowMod's wider multiplayer, performance, UI and
release acceptance work. Development evidence is retained under `artifacts/`.

For the 0.4.0 release, both packaged addons were rechecked together: 34 hydraulic,
19 pneumatic/import, 12 boundary and 21 Wire checks passed. A separate cold launch
without FlowMod or Wiremod passed five checks. See [release validation](VALIDATION.md).
