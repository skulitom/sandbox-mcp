# Validation — 0.2.0, 15 November 2026

Windows x64; Garry’s Mod build 10175; Sandbox on `gm_construct` in Anode’s
separate desktop. Native tests used real stdio MCP calls with the portable
release executable and packed Workshop GMA. The main desktop was not used.

## Automated checks

- 5 Rust checks: configuration preservation, malformed config refusal, client
  schemas and identifier/path handling. Clippy passes with warnings denied.
- 24 setup checks in isolated profiles: five clients, backups, idempotent setup,
  stable executable installation, origin/token rejection and shutdown.
- 3 MCP protocol revisions: 2025-03-26, 2025-11-25 and 2026-07-28. All 25 tools
  discoverable, structured results work.
- 30 base native checks: models/bounds, all four constraint types, scene rollback,
  ownership, stale refs, targeted undo, real gravity, NPCs, cleanup and screenshots.
- 9 transport checks: authorization/instance/expiry, duplicate requests and six
  simultaneous MCP clients receiving the correct responses.
- 21 Wire checks: original eight presets, real signal propagation, port types,
  wiring/source undo, feedback refusal, physical thrust, speed and GPS readings.
  The catalog advertises 11 presets; new sensors/E2 are tested below.
- 34 new workflow checks: asset filters; whole-circuit creation rollback; live
  state/constraint/wire save/import/load; rotation; overwrite/path guards;
  checkpoint replacement; graph cycle rejection; injected second-link failure
  rollback; whole-batch undo; group transforms/alignment; time-series values;
  diagnostics; E2 opt-in, compiler errors, stopped uploads, execution, code undo,
  interface-change rejection and zeroed outputs on stop; grants and revocation
  including refusal of historical undo after access is revoked.
- 7 restart checks: a fresh game instance loads persisted blueprints, restores
  the saved constant and all 12 hovercraft signal links, restores 15 frozen parts
  and 105 physical connections, keeps E2 stopped, and runs the restored controller
  with actual ranger/gyroscope data when explicitly started.

The private fixture only supplies consent, controlled faults and player-created
props for permission tests. It is outside `addon/` and is never packaged. The
new GMA has exactly nine Lua files, all byte-identical to source, and mounts in
both server/client realms. Raw JSON transcripts stay in local `artifacts/`;
reproducible scripts/fixtures are in `tests/` and `tools/`.

## Dogfooding

The new hovercraft was built through public tools: 15 parts, 105 physical links,
12 signal links and an E2 feedback controller. A 20-second native measurement
recorded 409 Source units of displacement, peak speed 49.5 units/s and maximum
body tilt 11.4 degrees. It slowed near the front obstacle; the final front ranger
read about 230 units. Lateral drift remained, so this is a working controller
example, not a robust autonomous navigation system. Its portable blueprint is
included in `examples/hovercraft.json`.

The previous native examples remain reproducible: a 26-part sculpture and an
8-part drivable rover. Version 0.1 also validated the actual connection panel,
screenshot opt-out, missing Wiremod behavior and setup browser UI. Those earlier
manual UI checks were not represented as newly repeated 0.2 checks.

## Limits

- Windows companion; local singleplayer/listen-server host. Dedicated/remote
  servers, macOS/Linux binaries and a second multiplayer player are unvalidated.
- Client configuration formats are tested; every vendor’s conversational UI and
  AI model has not been separately exercised.
- 128 parts / 256 physical and 256 signal connections per create; 512 live parts.
  Model index cap 50,000. Native physics/rendering costs still apply.
- Blueprints support allowlisted parts and constraint settings, not every addon
  or arbitrary GMod dupe. NPCs and links leaving the selection are refused.
- E2 is separately opt-in and retains Wiremod permissions/extensions/quotas.
  Ordinary grants support the host’s prop_physics assemblies only. StrongWeld,
  manually built Wire/vehicle grants, mirroring and model thumbnails are deferred.
- Undo/checkpoints are session-local. Cleanup is permanent. Checkpoint restore
  replaces the build and returns new IDs; effects on the surrounding world are
  not reversed. Disconnect blocks commands, not autonomous in-game circuits.
- Measurement results are capped at 700 KB and report truncation. Values are
  sampled at game-tick cadence, not a hard real-time instrumentation guarantee.
- Setup temporarily uses loopback HTTP with Host/Origin/token checks. Normal game
  control is stdio plus local files, with no control HTTP listener or arbitrary
  Lua/console/shell/filesystem tool.

Wiremod tests use upstream commit `0464cecb3bdacc9ea886c0a4ae244e8f040269f4`.
No Wiremod source or game assets are bundled.

## Primary references

- [Workshop packaging](https://wiki.facepunch.com/gmod/Workshop_Addon_Creation)
- [Official Rust MCP SDK](https://github.com/modelcontextprotocol/rust-sdk)
- [Wiremod source](https://github.com/wiremod/wire)
- [Constraint API](https://wiki.facepunch.com/gmod/constraint.GetTable)
- [Native screenshots](https://wiki.facepunch.com/gmod/render.Capture)
- [Entity identity](https://wiki.facepunch.com/gmod/Entity:GetCreationID)
- [Valve model headers](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/public/studio.h)


Publication verification: the freshly downloaded 0.2.0 Steam GMA matches the
native-tested archive byte for byte (SHA-256
`abcfb255f3fb60c59109fbb0ad31f97fa59344b0ef00523715c1a99dd93e3da2`). The anonymous
GitHub Windows ZIP download matches its published checksum. Workshop visibility,
owner/app and the four existing gallery items were verified after updating.
