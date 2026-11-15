# Workshop listing draft — not published

Title: **Sandbox MCP — Build with AI**

Type: Tool. Tags: Build, Fun. First-upload visibility: private for owner review.
Preview: `release/workshop-preview.jpg`, a native 512×512 game capture.
Gallery: current gate and rover captures in `docs/images`.

## Description

Turn an idea into a playable Garry's Mod scene with your AI assistant.

Sandbox MCP gives an MCP-compatible AI app useful building tools: find props,
inspect the map, create a complete labelled scene, connect its parts, test the
physics, and look at the result through an in-game screenshot. Ask it to refine
the build or undo a specific change.

**Requires the free Sandbox MCP companion and an AI app with local MCP support.**
Workshop installs the game addon. The companion connects it to your AI app and
includes a setup wizard. No Node.js, Python or game DLL is required.

Companion download: **[Insert approved public release URL before publishing.]**
Source and guide: **[Insert approved public source URL.]**

### Getting started

1. Subscribe to this addon.
2. Download the companion, extract it, and open Setup.
3. Choose your AI app, then restart it and enable Sandbox MCP.
4. Start a Sandbox map. Open **Q → Utilities → Sandbox MCP → Connection** and
   click **Connect AI**.

Try: “Build me a small cargo rover. Keep the driver's view clear, weld the cargo
to the chassis, test its physics, and show me a screenshot.”

### Features

- Create named parts and physical connections in one tool call.
- Search mounted models, vehicle presets and supported NPCs.
- Inspect dimensions, placement, mass, motion and nearby entities.
- Native weld, no-collide, axis and rope connections.
- Specific-operation undo, plus GMod's familiar Undo menu.
- Optional game screenshots and temporary camera views.
- Clear connection status and an in-game disconnect control.

Only the local singleplayer/listen-server host can connect. The AI can inspect
the game, but editing tools affect only objects it creates. Screenshot permission
is separate; there is no arbitrary Lua or console execution tool.

The companion needs a desktop/CLI MCP client. Browser-only chat apps may not
support local servers. Dedicated-server and remote-machine connections are
outside this preview. Native physics and the AI model's building choices still
matter; this is not a replacement physics engine.

MIT-licensed original code. Game assets belong to their respective authors.

## Before publication

User approval is required. Publish the approved source/companion release, replace
both placeholders, confirm the title/account, and upload the validated GMA with
the native icon and gallery. Verify a fresh subscriber's setup using those links.

No Workshop item, public repository or public release has been created by this
task. This is the reviewable listing copy for that next step.
