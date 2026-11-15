# 0.2 implementation and release plan

The user authorized implementation and publication on 15 November 2026.

Release priorities, based on using the public tools for the Wiremod rocket:

- Portable blueprints: save, list, export/import, load at a new position/rotation.
- Atomic circuits: create parts and signal wiring together, or batch links onto existing parts.
- Repeatable experiments: named checkpoints, restore, time-series physics/Wire readings and diagnostics.
- Assembly: group transforms, surface snapping/alignment, placement clearance and model-size discovery.
- Explicit player handoff: an in-game selection grants access to a player's existing contraption; revoke remains available.
- Extend optional Wiremod support where native tests establish reliable behavior, including Expression 2 with an explicit host opt-in.

Preserve existing 0.1 tools and ownership protections. Never package private test
or filming autoruns. Validate real MCP calls against native Garry's Mod in Anode,
including failure rollback, save/load after restart and a complete working build.
Update companion, addon, setup documentation, source, GitHub release and the
existing Workshop item after local package validation. Preserve existing gallery.

Implementation and local package validation complete: 25 tools, 11 Wire presets,
portable blueprints, checkpoints, E2, experiments, assembly operations and prop
grants. The exact nine-file GMA passes native testing; save/load survives a full
game restart. Publication receipts are retained under release/.

Deliberately deferred: StrongWeld adapter, arbitrary addon/dupe support, grants
for existing Wire/vehicle assemblies, thumbnails and mirroring. These limits are
stated in the public workflow guide and listing rather than advertised as done.

Status: published and download-verified on Workshop and GitHub as 0.2.0.
