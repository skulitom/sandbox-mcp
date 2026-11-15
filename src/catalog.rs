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
        json!({"label":string(),"kind":{"enum":["prop","vehicle","npc","light","wire"]},"model":string(),"preset":string(),"class":string(),"settings":object(json!({"value":{"type":"number","minimum":-1000000,"maximum":1000000},"off":{"type":"number","minimum":-1000000,"maximum":1000000},"on":{"type":"number","minimum":-1000000,"maximum":1000000},"action":string(),"force":{"type":"number","minimum":1,"maximum":10000},"low_color":vector(),"high_color":vector(),"text_a":{"type":"string","maxLength":64},"text_b":{"type":"string","maxLength":64}}), &[]),"pos":vector(),"angles":vector(),"color":{"type":"array","items":{"type":"integer","minimum":0,"maximum":255},"minItems":3,"maxItems":3},"material":string(),"skin":{"type":"integer","minimum":0,"maximum":32},"mass":{"type":"number","minimum":1,"maximum":5000},"frozen":{"type":"boolean"}}),
        &["label"],
    );
    let edit = object(
        json!({"ref":string(),"pos":vector(),"angles":vector(),"color":{"type":"array","items":{"type":"integer","minimum":0,"maximum":255},"minItems":3,"maxItems":3},"material":string(),"mass":{"type":"number","minimum":1,"maximum":5000},"frozen":{"type":"boolean"},"velocity":vector()}),
        &["ref"],
    );
    let definitions = vec![
        (
            "status",
            "Check installation, live game sessions and host consent. Works while disconnected. Start here.",
            object(json!({}), &[]),
            true,
            false,
        ),
        (
            "catalog",
            "Discover installed models with bounds, vehicle presets, NPC classes, or optional Wiremod components and gate actions (kind=wire). The Wire catalog explains settings and reports whether Wiremod is installed. Query uses a case-insensitive substring. Paginated.",
            object(
                json!({"kind":{"enum":["models","vehicles","npcs","wire"]},"query":{"type":"string","maxLength":128},"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1,"maximum":40}}),
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
            "Create a named scene in one batch, with optional physical connections. Entity pos/angles are relative to origin (default: host crosshair). Props default frozen. Vehicle presets: Jeep, Airboat, Seat_Jeep. For Wiremod use kind=wire, preset and settings from catalog kind=wire; signal wiring is separate from physical links. Connections a/b are labels in this batch. Returns build_id, stable refs, bounds and operation_id. Validates and rolls back spawn failures. Limit 128 per batch/512 live parts.",
            object(
                json!({"name":string(),"origin":vector(),"entities":{"type":"array","items":part,"minItems":1,"maxItems":128},"links":{"type":"array","items":link,"maxItems":256}}),
                &["name", "entities"],
            ),
            false,
            false,
        ),
        (
            "edit",
            "Change AI-created entities using absolute world positions. Use frozen=false to release physics. Edits are undoable by operation_id. A velocity launches an object; use observe to measure it.",
            object(
                json!({"items":{"type":"array","items":edit,"minItems":1,"maxItems":128}}),
                &["items"],
            ),
            false,
            true,
        ),
        (
            "connect",
            "Add physical connections between AI-created entities. a/b are stable refs from inspect/create. Anchors are local coordinates. Axis defaults Z. Returns an undoable operation.",
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
            "Remove one AI-created build. Does not touch pre-existing world props or other players' work. This cleanup is permanent; use undo for a recent operation.",
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
            "Sample actual physics of selected entities over 0.2–5 seconds, reporting start/end position, maximum speed and displacement. Useful after releasing or launching a contraption.",
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
    definitions.into_iter().map(|(name,desc,schema,ro,destructive)|serde_json::from_value(json!({"name":format!("sandbox_{name}"),"description":desc,"inputSchema":schema,"annotations":{"readOnlyHint":ro,"destructiveHint":destructive,"idempotentHint":ro,"openWorldHint":false}})).expect("tool schema")).collect()
}
