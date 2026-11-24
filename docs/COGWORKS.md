# Build a mechanical transmission

Subscribe to [Cogworks](https://steamcommunity.com/sharedfiles/filedetails/?id=3845221917), load a Sandbox map, and connect Sandbox MCP from the Utilities menu. Use version 0.5.0 or later of both the companion and the Workshop addon.

Try asking your assistant, “Build a hand crank with a gear that turns twice as fast. Measure both speeds, then turn it backwards.”

1. Aim at a clear, nearby floor. Call `sandbox_catalog` with `{"kind":"cogworks"}` to discover the installed rotating parts and tooth counts. It returns `available: false` if the addon is missing.
2. Call `sandbox_cogworks_mount` with `{"kind":"crank","teeth":24,"compact":true}`. Keep its returned ref. To start on a prop, pass the owned support's ref as `target` plus a point on the face and its outward normal, both in prop-local coordinates.
3. Call the same tool with `{"kind":"gear","teeth":12,"mode":"mesh","target":"<crank ref>","compact":true}`. The returned ratio is −2. Use `mode:"hub"` for a second part turning on the same shaft.
4. Call `sandbox_cogworks_drive` with the crank ref, `seconds: 4` and `direction: 1`. Immediately call `sandbox_measure` with both refs and `seconds: 1`. Each sample includes signed RPM under `cogworks.rpm`. Reverse the input with `direction: -1`.
5. Use `sandbox_cogworks_inspect` for a part's socket indices, connected bearings, current RPM and the Cogworks inspector's diagnosis. To join independent bearings, call `sandbox_cogworks_connect` with their refs as `from` and `to`, and `kind:"shaft"` or `"belt"`. Specify socket indices for gearbox inputs and differential branches.

Mounts and shaft or belt connections return individual operation IDs for `sandbox_undo`. Building respects the host's grants, tool permissions, reach and sandbox limits. The adapter covers rotating components. Complete vehicle spawning, track laying and mechanical blueprint serialization are outside this version's tool set.
