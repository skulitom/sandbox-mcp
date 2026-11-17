# Progress

15 November 2026: User approved publication and requested Wiremod support before
release. Added optional Wiremod component discovery/creation, real port values,
typed signal wiring/disconnection and source control with targeted undo. There
are now 17 MCP tools and five packaged Lua files. All eight Wire components and
18 gate actions are discoverable when Wiremod is present.

Final release executable and GMA passed 21 Wiremod, 30 native, nine transport,
24 setup, five Rust and three protocol-version checks. Missing-Wire behavior was
also checked. The Steam-downloaded GMA matches the tested package byte for byte;
all five extracted Lua files match source. No private fixture is bundled.

Recorded a 26-second native 1080p30 showcase and edited it in Cutbolt, with an
original synthesized score. All builds, signal wiring, physics edits and undo
in the footage used the public MCP tools. Private helpers only moved the camera
and recorded frames. Final export decodes cleanly as H.264/AAC stereo.

Published: [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3839989108),
[GitHub/MIT source and companion](https://github.com/skulitom/sandbox-mcp/releases/tag/v0.1.0),
and the [26-second showcase](https://www.youtube.com/watch?v=30DsajKY70I).
Steam API confirms public visibility, the correct owner/app and all four gallery
entries (three screenshots plus video). An anonymous companion download matches
the release checksum. YouTube title and description were saved and verified;
the public watch page and oEmbed endpoint work.

All temporary game addons have been archived outside the game. The seven
original configuration paths were restored and verified. Owned game/browser
processes are closed and the Anode lease released.


## 0.2 — 15 November 2026

Implemented and packaged the next workflow release at the user's request.
25 tools and 11 optional Wire presets; portable blueprints/checkpoints, atomic
circuits, group transforms/alignment, size-filtered assets, time-series signals,
diagnostics, separate E2 opt-in and explicit revocable player prop grants.

Validation: 5 Rust, 24 setup, 3 protocol revisions, 30 base native, 21 Wire,
34 workflow, 9 transport and 7 fresh-restart checks. Nine packaged Lua files
match source exactly and mount in both realms. The E2 hovercraft example was
built through public MCP calls and measured for 20 seconds, then its saved
circuit was restored and run after a full game restart. No private fixture or
Wiremod/game asset is packaged. Public limits are in WORKFLOWS and VALIDATION.


Published 0.2.0 to the existing Workshop item and GitHub release. Steam confirms
public visibility, correct owner/app and all four existing gallery entries. The
fresh Steam download matches the native-tested GMA SHA-256 exactly. An anonymous
GitHub companion ZIP download also matches. The source tag is `v0.2.0`.
Temporary game addons were archived, all seven configuration paths were restored
and hash-verified, owned game processes closed, and the Anode lease released.


## 2026-11-16 — 0.3 Fin 3 release

Added original optional Fin 3 adapter, two new tools (27 total), native force/RPM
telemetry and blueprint persistence. Actual Workshop dependency tested in Anode:
31 integration + 10 boundary + 9 packaged-restart/dependency checks passed.
Native and Wire regressions passed. Dogfooded a five-part glider and bounded E2
propeller motor. New 21-second Fin 3 video and existing 22.5-second Wiremod video
published with Cutbolt projects and native evidence retained locally.

## 2026-11-16 — local FlowMod adapter milestone (unreleased)

Added optional FlowMod support to structured creation, inspection, measurement,
diagnostics and portable blueprints, plus four tools for fluid inspection, hose
connection/disconnection and tuning (31 total). Creation uses the real FlowMod
factories and normal permissions; no helper supplies actuator forces. Wire ports
on AI-created FlowMod parts work with existing signal tools. Tuning refuses
Wire-driven settings, native failures roll back, and stale undo refuses later
changes/replaced hoses. Cylinder anchors and hoses cannot retain old map refs in
blueprints; partial selections fail.

Anode evidence: 34 hydraulic/Wire checks, 19 air/import checks without Wiremod
(the earlier 16 also passed with Wire), 12 permission/failure checks, five cold
checks with FlowMod and Wire absent, and 21 existing Wire regression checks.
Three protocol versions, five Rust unit tests, Clippy and 12 Lua syntax checks
pass. A public-MCP dogfood script built a 12-part twin-cylinder 200 kg lift,
saved its blueprint and measured 8.7 Source units of lift over three seconds.
Real screenshot and transcripts are under artifacts/flowmod-dual-lift. Source
hashes for all 11 installed addon Lua files are retained.

Failed test receipts remain: a test guessed a constant's output name instead of
reading its ports, a rotated copy exceeded normal 800-unit placement reach, and
the first dual-lift opening was too narrow for its demonstration threshold. The
last demonstration explicitly tunes the valve wider through MCP. The no-Wire
cold session's private fixture initially spawned its default rig because boot.json
is consumed on launch; that owned rig was cleared and the player pose restored
before MCP tests (zero tracked parts confirmed).

No package, remote commit, Workshop upload or GitHub release was published.
FlowMod's broader production goal remains active. Owned game sessions exited,
development addons/test blueprints were archived, seven config states restored
and verified, desktop Steam stayed in session 1, and the Anode lease was released.

## 2026-11-17 — 0.4 FlowMod release preparation

FlowMod 0.1.0 is public at Workshop item 3841216963, after Artem approved publication.
Prepared matching Sandbox MCP 0.4.0 addon/Windows companion and updated guides.
The actual release GMAs passed 91 native checks across dependency-present and
dependency-absent Anode sessions. Verified 27 and 11 mounted Lua hashes respectively;
five Rust tests, Clippy, 24 setup checks, three protocol versions and 19 Lua syntax
checks passed. Both game sessions exited normally and the eight configuration
states were restored. User-created blueprints and unrelated addons are preserved.

The first cold absence request arrived before the private fixture's consent timer
and was correctly refused; after consent all five checks passed. The private
server-side quit request was blocked by GMod; normal client-console quit was used
instead and that unused fixture request handler was removed. Fixtures are excluded
from the GMA. Public release receipts and download verification follow below.
