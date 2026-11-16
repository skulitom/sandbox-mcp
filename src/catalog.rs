use rmcp::model::Tool;
use serde_json::{Value, json};

fn object(properties: Value, required: &[&str]) -> Value {
    json!({"type":"object","properties":properties,"required":required,"additionalProperties":false})
}
fn vector() -> Value {
    json!({"type":"array","items":{"type":"number","minimum":-32768,"maximum":32768},"minItems":3,"maxItems":3})
}
fn string() -> Value {
    json!({"type":"string","minLength":1,"maxLength":256})
}
fn refs() -> Value {
    json!({"type":"array","items":string(),"minItems":1,"maxItems":128})
}

pub fn tools() -> Vec<Tool> {
    let link = object(
        json!({"kind":{"enum":["weld","nocollide","axis","rope"]},"a":string(),"b":string(),"anchor_a":vector(),"anchor_b":vector(),"axis":vector(),"length":{"type":"number","minimum":0,"maximum":4096}}),
        &["kind", "a", "b"],
    );
    let part = object(
        json!({"label":string(),"kind":{"enum":["prop","vehicle","npc","light","wire","flowmod"]},"model":string(),"preset":string(),"class":string(),"settings":object(json!({"value":{"type":"number","minimum":-1000000,"maximum":1000000},"off":{"type":"number","minimum":-1000000,"maximum":1000000},"on":{"type":"number","minimum":-1000000,"maximum":1000000},"action":string(),"force":{"type":"number","minimum":1,"maximum":10000},"low_color":vector(),"high_color":vector(),"text_a":{"type":"string","maxLength":64},"text_b":{"type":"string","maxLength":64},"code":{"type":"string","minLength":1,"maxLength":32768},"range":{"type":"number","minimum":1,"maximum":65536},"show_beam":{"type":"boolean"}}), &[]),"pos":vector(),"angles":vector(),"color":{"type":"array","items":{"type":"integer","minimum":0,"maximum":255},"minItems":3,"maxItems":3},"material":string(),"fin3":fin3_settings(),"flowmod":flowmod_part(),"skin":{"type":"integer","minimum":0,"maximum":32},"mass":{"type":"number","minimum":1,"maximum":5000},"frozen":{"type":"boolean"}}),
        &["label"],
    );
    let edit = object(
        json!({"ref":string(),"pos":vector(),"angles":vector(),"color":{"type":"array","items":{"type":"integer","minimum":0,"maximum":255},"minItems":3,"maxItems":3},"material":string(),"mass":{"type":"number","minimum":1,"maximum":5000},"frozen":{"type":"boolean"},"velocity":vector()}),
        &["ref"],
    );
    let mut definitions = vec![
        (
            "status",
            "Check installation, live game sessions and host consent. Works while disconnected. Start here.",
            object(json!({}), &[]),
            true,
            false,
        ),
        (
            "catalog",
            "Discover installed models with bounds, vehicle presets, NPC classes, or optional Wiremod components and gate actions (kind=wire), Fin 3 airfoils (kind=fin3), or FlowMod fluid components, ports, ranges and circuit guidance (kind=flowmod). The Wire catalog explains settings and reports whether Wiremod is installed. Query uses a case-insensitive substring. Optional shape is a filename hint; min_size/max_size filter X/Y/Z model dimensions, and physics_only filters spawnable props. Paginated.",
            object(
                json!({"kind":{"enum":["models","vehicles","npcs","wire","fin3","flowmod"]},"query":{"type":"string","maxLength":128},"shape":{"enum":["box","plate","tube","sphere","cone","wheel"]},"min_size":vector(),"max_size":vector(),"physics_only":{"type":"boolean"},"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1,"maximum":40}}),
                &[],
            ),
            true,
            false,
        ),
        (
            "inspect",
            "Inspect entities, player pose, owned builds and physics. Filter by refs, build_id or a sphere. Returned refs include creation identity to prevent editing reused entity IDs.",
            object(
                json!({"refs":refs(),"build_id":string(),"near":vector(),"radius":{"type":"number","minimum":1,"maximum":10000},"limit":{"type":"integer","minimum":1,"maximum":100},"offset":{"type":"integer","minimum":0},"owned_only":{"type":"boolean"}}),
                &[],
            ),
            true,
            false,
        ),
        (
            "trace",
            "Find ground or a clear placement line. Omit endpoints to trace the host's crosshair. Optional box mins/maxs checks clearance.",
            object(
                json!({"start":vector(),"end":vector(),"mins":vector(),"maxs":vector()}),
                &[],
            ),
            true,
            false,
        ),
        (
            "create",
            "Create a named scene in one batch, with optional physical connections. Entity pos/angles are relative to origin (default: host crosshair). Props default frozen. Vehicle presets: Jeep, Airboat, Seat_Jeep. For Wiremod use kind=wire, preset and settings from catalog kind=wire; wire_links connects signals by part labels in the same atomic batch. Connections a/b are labels in this batch. Optional fin3 settings on kind=prop attach real Fin 3 fins/propellers atomically. For FlowMod use kind=flowmod and flowmod settings from catalog; cylinder anchors use same-batch prop labels and local physics-body points. fluid_links connect fluid ports by labels. Sources start off and valves hold; use flowmod_tune to activate. Returns build_id, stable refs, bounds and operation_id. Validates and rolls back spawn failures. Limit 128 per batch/512 live parts.",
            object(
                json!({"name":string(),"origin":vector(),"entities":{"type":"array","items":part,"minItems":1,"maxItems":128},"links":{"type":"array","items":link,"maxItems":256},"wire_links":{"type":"array","items":wire_link(),"maxItems":256},"fluid_links":{"type":"array","items":fluid_link(),"maxItems":128}}),
                &["name", "entities"],
            ),
            false,
            false,
        ),
        (
            "edit",
            "Change AI-created or explicitly player-granted entities using absolute world positions. Use frozen=false to release physics. Edits are undoable by operation_id. A velocity launches an object; use observe to measure it.",
            object(
                json!({"items":{"type":"array","items":edit,"minItems":1,"maxItems":128}}),
                &["items"],
            ),
            false,
            true,
        ),
        (
            "connect",
            "Add physical connections between AI-created or explicitly player-granted entities. a/b are stable refs from inspect/create. Anchors are local coordinates. Axis defaults Z. Returns an undoable operation.",
            object(
                json!({"links":{"type":"array","items":link,"minItems":1,"maxItems":256}}),
                &["links"],
            ),
            false,
            false,
        ),
        (
            "wire_ports",
            "Read actual Wiremod input/output names, types, current values and connected sources. Requires optional Wiremod addon. Supports read-only inspection of existing Wire entities; writes are restricted to this host's AI-created components.",
            object(
                json!({"refs":{"type":"array","items":string(),"minItems":1,"maxItems":32}}),
                &["refs"],
            ),
            true,
            false,
        ),
        (
            "wire_connect",
            "Connect a Wiremod output to an unwired input on AI-created components. from/to are stable entity refs; output/input are exact port names from wire_ports. Rejects type mismatches and feedback cycles. Returns operation_id for undo. This is signal wiring, not a physical constraint.",
            object(
                json!({"from":string(),"output":string(),"to":string(),"input":string()}),
                &["from", "output", "to", "input"],
            ),
            false,
            false,
        ),
        (
            "wire_disconnect",
            "Disconnect one Wiremod input between AI-created components. Undo restores the link if the port is still free and no cycle would result.",
            object(json!({"to":string(),"input":string()}), &["to", "input"]),
            false,
            true,
        ),
        (
            "wire_set",
            "Change an AI-created Wire constant's numeric value, or set a toggle button to 0/off or 1/on. The real Wire network propagates the signal. Refuses wired buttons; change their source instead. Returns undo operation_id.",
            object(
                json!({"ref":string(),"value":{"type":"number","minimum":-1000000,"maximum":1000000}}),
                &["ref", "value"],
            ),
            false,
            true,
        ),
        (
            "undo",
            "Undo one named operation, independently of later unrelated work. Undoing a create removes its parts; edit undo refuses if those same parts were modified afterwards. Also available through the in-game undo menu.",
            object(json!({"operation_id":string()}), &["operation_id"]),
            false,
            true,
        ),
        (
            "cleanup",
            "Remove one AI-created or explicitly player-granted build. Granted props are deleted too; ungranted props and other players' work remain protected. This cleanup is permanent; use undo for a recent operation.",
            object(json!({"build_id":string()}), &["build_id"]),
            false,
            true,
        ),
        (
            "view",
            "Temporarily position the consenting host's camera to inspect a scene. Camera resets after 30 seconds, on disconnect, or restore=true. Does not move the player or send keyboard input.",
            object(
                json!({"pos":vector(),"look_at":vector(),"fov":{"type":"number","minimum":20,"maximum":110},"restore":{"type":"boolean"}}),
                &[],
            ),
            false,
            false,
        ),
        (
            "screenshot",
            "Return the consenting host's current rendered game view as a JPEG image plus metadata. Close the pause menu first. Only captures Garry's Mod, not the desktop. square_preview captures a central 512x512 region for a Workshop icon; frame the subject accordingly.",
            object(
                json!({"quality":{"type":"integer","minimum":35,"maximum":95},"square_preview":{"type":"boolean"}}),
                &[],
            ),
            true,
            false,
        ),
        (
            "observe",
            "Sample actual physics of selected entities over 0.2â€“5 seconds, reporting start/end position, maximum speed and displacement. Useful after releasing or launching a contraption.",
            object(
                json!({"refs":refs(),"seconds":{"type":"number","minimum":0.2,"maximum":5}}),
                &["refs"],
            ),
            true,
            false,
        ),
        (
            "events",
            "Read recent operation outcomes and errors. Use after a timed-out mutation before deciding whether to retry. No game console or arbitrary Lua access.",
            object(
                json!({"after":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1,"maximum":100}}),
                &[],
            ),
            true,
            false,
        ),
    ];
    definitions.extend(workflow_tools());
    definitions.extend(fin3_tools());
    definitions.extend(flowmod_tools());
    definitions.into_iter().map(|(name,desc,schema,ro,destructive)|serde_json::from_value(json!({"name":format!("sandbox_{name}"),"description":desc,"inputSchema":schema,"annotations":{"readOnlyHint":ro,"destructiveHint":destructive,"idempotentHint":ro,"openWorldHint":name=="e2"}})).expect("tool schema")).collect()
}

fn wire_link() -> Value {
    object(
        json!({"from":string(),"output":string(),"to":string(),"input":string()}),
        &["from", "output", "to", "input"],
    )
}
fn workflow_tools() -> Vec<(&'static str, &'static str, Value, bool, bool)> {
    vec![
        (
            "wire_batch",
            "Connect 1-256 Wire signals as one validated transaction and one undo operation. Uses stable refs; type errors, occupied inputs and cycles change nothing.",
            object(
                json!({"links":{"type":"array","items":wire_link(),"minItems":1,"maxItems":256}}),
                &["links"],
            ),
            false,
            false,
        ),
        (
            "blueprint",
            "Save/list/export/import/load portable contraptions including physics constraints, Wire circuits, Fin 3 settings and FlowMod fluid circuits. FlowMod saves settings and prop anchors, not pressure or active commands. Include every hose endpoint and both anchor props. Wire sources can activate copies. Names use letters, digits, hyphens or underscores. Save selects build_id or refs; export can select a build or saved name. Load creates a new build, frozen by default, with buttons off and E2 stopped. Imported data is untrusted; load validates supported parts. Saves persist across restarts in game DATA, per host.",
            object(
                json!({"action":{"enum":["save","list","export","import","load"]},"name":string(),"title":string(),"build_id":string(),"refs":refs(),"blueprint":{"type":"object"},"origin":vector(),"angles":vector(),"frozen":{"type":"boolean"},"overwrite":{"type":"boolean"},"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1,"maximum":40}}),
                &["action"],
            ),
            false,
            false,
        ),
        (
            "checkpoint",
            "Save or restore a named checkpoint of an AI-created build in this map session. Restore validates and spawns the replacement BEFORE removing the old build; returns NEW build_id and refs. Restores frozen by default, buttons off and E2 stopped. Use blueprint for durable saves or adopted builds.",
            object(
                json!({"action":{"enum":["save","restore"]},"name":string(),"build_id":string(),"origin":vector(),"frozen":{"type":"boolean"}}),
                &["action", "name"],
            ),
            false,
            true,
        ),
        (
            "transform",
            "Translate/rotate an entire selected assembly around a pivot, preserving relative poses. Select build_id or refs. rotation is [pitch,yaw,roll] degrees; default pivot is first part. Clears linear velocity. One targeted undo.",
            object(
                json!({"build_id":string(),"refs":refs(),"pivot":vector(),"translation":vector(),"rotation":vector(),"frozen":{"type":"boolean"}}),
                &[],
            ),
            false,
            true,
        ),
        (
            "align",
            "Snap selected parts as a group against a target's world-aligned bounding-box face. axis x/y/z, face min/max. Centers the other axes unless center=false. gap adds clearance. Does not rotate parts; use transform first. Returns undo operation.",
            object(
                json!({"build_id":string(),"refs":refs(),"target":string(),"axis":{"enum":["x","y","z"]},"face":{"enum":["min","max"]},"gap":{"type":"number","minimum":0,"maximum":512},"center":{"type":"boolean"},"frozen":{"type":"boolean"}}),
                &["target"],
            ),
            false,
            true,
        ),
        (
            "measure",
            "Record real physics, Fin 3 forces/RPM and Wire values over 0.2-20 seconds. Select up to 8 refs or a small build. Returns timestamped poses, velocities, signals, max speed/tilt and displacement; interval 0.1-2 seconds. Read-only: start controls separately, then measure. Keeps native server quotas.",
            object(
                json!({"build_id":string(),"refs":{"type":"array","items":string(),"minItems":1,"maxItems":8},"seconds":{"type":"number","minimum":0.2,"maximum":20},"interval":{"type":"number","minimum":0.1,"maximum":2}}),
                &[],
            ),
            true,
            false,
        ),
        (
            "diagnose",
            "Inspect a selected build or refs for unconnected Wire inputs, external sources, component errors, world overlaps, frozen parts and total mass. Unconnected inputs may intentionally use defaults. Does not change the scene.",
            object(json!({"build_id":string(),"refs":refs()}), &[]),
            true,
            false,
        ),
        (
            "e2",
            "Validate, upload, run, stop or inspect Expression 2 code. Host must separately enable E2 code access to create/program/run chips; E2 uses normal Wiremod player permissions and quotas. Code uploads compile STOPPED; run explicitly. Stop clears outputs to their Wiremod neutral values. Self-contained code only, max 32 KiB; no includes. Compilation errors are returned without replacing working code. Upload undo restores prior code stopped; it does not reverse effects of executing a program. Interface changes require disconnected ports.",
            object(
                json!({"action":{"enum":["validate","upload","run","stop","status"]},"ref":string(),"code":{"type":"string","minLength":1,"maxLength":32768}}),
                &["action"],
            ),
            false,
            true,
        ),
    ]
}

fn fin3_settings() -> Value {
    object(
        json!({"kind":{"enum":["fin","propeller"]},"forward":vector(),"up":vector(),"airfoil":string(),"camber":{"type":"number","minimum":0,"maximum":100},"efficiency":{"type":"number","minimum":0.1,"maximum":1.5},"induced_drag":{"type":"number","minimum":0,"maximum":1},"disable_lowpass":{"type":"boolean"},"blades":{"type":"integer","minimum":2,"maximum":6},"diameter":{"type":"number","minimum":0.1,"maximum":6},"pitch":{"type":"number","minimum":-90,"maximum":90},"invert":{"type":"boolean"}}),
        &["kind"],
    )
}
fn fin3_tools() -> Vec<(&'static str, &'static str, Value, bool, bool)> {
    vec![
        (
            "fin3_inspect",
            "Read live Fin 3 wing/propeller settings and forces. Select refs or build_id. Reports lift/drag in newtons, surface area in m2, angle of attack in degrees, airspeed in m/s, propeller RPM/thrust/torque. Read-only inspection of existing props is allowed. Optional Fin 3 Workshop 3113528615 required.",
            object(json!({"refs":refs(),"build_id":string()}), &[]),
            true,
            false,
        ),
        (
            "fin3_apply",
            "Attach, replace, tune or remove Fin 3 modifiers as one validated batch with targeted undo. Only owned/granted single-body unparented props; respects CanTool and Fin 3 server limits. Each item has ref plus full fin3 settings, or remove=true. Defaults: standard fin, local forward +X, up +Z, camber 0, efficiency/induced_drag 1; propeller 2 blades, diameter 2 meters, pitch 15 degrees. Axes must be cardinal unit vectors; fin axes perpendicular. Propellers need actual physical rotation from a motor/E2, not just pitch. Inspect before tuning; later or manual edits prevent stale undo. Does not change Fin 3 global settings. Blueprints retain these modifiers.",
            object(
                json!({"items":{"type":"array","items":object(json!({"ref":string(),"fin3":fin3_settings(),"remove":{"type":"boolean"}}), &["ref"]),"minItems":1,"maxItems":128}}),
                &["items"],
            ),
            false,
            true,
        ),
    ]
}

fn fluid_link() -> Value {
    object(
        json!({"a":string(),"b":string(),"port_a":string(),"port_b":string(),"conductance":{"type":"number","minimum":0.001,"maximum":10}}),
        &["a", "b", "port_a", "port_b"],
    )
}
fn flowmod_part() -> Value {
    object(
        json!({
            "kind":{"enum":["reservoir","pump","compressor","airtank","exhaust","valve","restrictor","gauge","tee","check","relief","cylinder"]},
            "medium":{"enum":["oil","air"]},"pressure":{"type":"number","minimum":1,"maximum":200},
            "flow":{"type":"number","minimum":0.1,"maximum":120},"opening":{"type":"number","minimum":0,"maximum":1},
            "volume":{"type":"number","minimum":0.1,"maximum":100},"bore":{"type":"number","minimum":10,"maximum":100},"stroke":{"type":"number","minimum":8,"maximum":300},
            "anchors":object(json!({"a":string(),"b":string(),"point_a":vector(),"point_b":vector(),"minimum":{"type":"number","minimum":8,"maximum":400}}), &["a","b"])
        }),
        &["kind"],
    )
}
fn flowmod_tools() -> Vec<(&'static str, &'static str, Value, bool, bool)> {
    vec![
        (
            "flowmod_inspect",
            "Read native FlowMod component settings, gauge pressures, signed hose flow, faults, cylinder anchors and load forces. Select build_id or refs. Also included in inspect/measure. Requires separately installed FlowMod.",
            object(json!({"build_id":string(),"refs":refs()}), &[]),
            true,
            false,
        ),
        (
            "flowmod_connect",
            "Connect 1-128 fluid hoses atomically between owned FlowMod components. a/b are stable refs; exact port names come from flowmod_inspect. One hose per port; use tees to branch. Oil and air cannot mix. Returns hose refs and targeted undo. conductance defaults to 0.5 for oil (L/s/bar) or 5 for air (standard L/s per log absolute-pressure ratio).",
            object(
                json!({"links":{"type":"array","items":fluid_link(),"minItems":1,"maxItems":128}}),
                &["links"],
            ),
            false,
            false,
        ),
        (
            "flowmod_disconnect",
            "Remove one owned fluid hose by its ref from flowmod_inspect. Targeted undo reconnects only if both ports remain free and permitted.",
            object(json!({"ref":string()}), &["ref"]),
            false,
            true,
        ),
        (
            "flowmod_tune",
            "Tune one owned FlowMod component. control: sources 0/off or 1/on, directional valve -1/retract, 0/hold, 1/extend (proportional). pressure gauge bar (air max20), flow L/min, opening0..1, volume litres. Supported settings by kind in catalog. Rejects settings currently driven by Wire; edit their source instead. Targeted undo preserves later edits; volume undo may require venting. No pressure reset or physics teleport.",
            object(
                json!({"ref":string(),"control":{"type":"number","minimum":-1,"maximum":1},"settings":object(json!({"pressure":{"type":"number","minimum":1,"maximum":200},"flow":{"type":"number","minimum":0.1,"maximum":120},"opening":{"type":"number","minimum":0,"maximum":1},"volume":{"type":"number","minimum":0.1,"maximum":100}}),&[])}),
                &["ref"],
            ),
            false,
            true,
        ),
    ]
}
