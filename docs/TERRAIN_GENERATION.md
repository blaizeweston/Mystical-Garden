# Finished terrain and varied expedition routes — 2026-11-10

## Findings

Regular maps previously varied clearing positions around a fixed north-to-south spine. Entry came from the first clearing and the onward gate from the last, creating a repeated overall journey. Per-path collision walls were not present: physics used a smoothed combination of corridor/clearing distance fields. However, visible zero-distance dirt and a player's required clearance could disagree at a narrow merged shoulder. The earlier larger blend reduced that symptom without introducing a final, independently compiled terrain boundary.

## Current ownership

- `wilds_layout.gd` supplies winding, crescent and branching-circuit route families, then varies whole-map orientation, handedness and travel direction using the map's private seeded RNG. Landmarks and spawn anchors move with that layout. Clearings fit within the supported region, with space reserved for their banks.
- `battlefield.gd` still owns generation orchestration, optional visible cover, pathfinding and movement. It retains the authored nonprocedural fixtures and boss layout definitions.
- `walkable_surface.gd` bakes the complete combined source field once, after every corridor/clearing is present. A half-unit boolean mask closes near-touching shoulders with a small morphological closing operation. Original floor cells are retained. Genuine larger forest gaps remain gaps. Only the final mask's boundary contributes to its signed clearance field; internal route-stroke edges cannot become independent walls.
- Boundary segments are spatially indexed, with distance clamped outside the nearby boundary band. The existing cached conservative clearance checks remain valid for player/navigation clearance. No per-frame baking or gameplay RNG consumption is introduced.
- Movement, dashing, enemy navigation, dirt clipping, decorative boundary roots and explored-floor classification query this finished field. Visible cover remains a separate explicit obstacle. Scenery does not add per-corridor collision bodies.
- Fog/minimap bounds and projection derive from `Battlefield.REGION`, including their shader uniforms. Forest-edge decoration covers that region too. The prior fixed 53×49 map projection cannot clip a rotated floor.

Regular procedural geometry is rebuilt from the shared site/depth/seed on host and guests. Pre-auth now includes `wilds_layout.gd::SIGNATURE` and rejects missing/different terrain versions before gameplay. **Bump that signature whenever generation or compiled-collision semantics change.** Existing saved Garden/character progression needs no migration. Changes become visible when a new procedural floor is generated; checkpoint intervals, floor numbering, combat budgets and reward rules retain their existing authorities.

The existing `floor_generation` diagnostic event now includes entry/exit coordinates, clearing count, finished-mask cell count and terrain version alongside seed/biome/depth/timing. Logs can identify the exact layout if a future path report needs reproduction.

## Validation and authoring

`tests/terrain_generation.gd` checks 24 seeds across biomes/depths, connected landmarks, safe region bounds, varied endpoints/directions, deterministic independently reconstructed masks, crossing/shallow-angle/parallel junctions, both walking and dashing, separate forest gaps and solid cover. `tests/terrain_generation_coop.gd` rejects deliberately incompatible terrain, reconnects using the correct signature and compares actual host/guest gate coordinates and mask hashes across three seeds. It also checks client-predicted movement against that floor.

`tests/natural_world.gd` preserves the old arena-limit regression on all four cardinal edges instead of relying on north-facing generated seeds. It checks rendered root continuity. `tests/exploration_ui.gd` checks fog memory and marker projection at all four region edges. Existing linked combat, enemy, loot, expedition, presentation and multiplayer suites cover their consumers; unrelated Garden/menu/character evidence remains reusable.

The mechanics map explicitly scopes this geometry change and its small map/scenery/auth adapters. A bare `world.tscn` import does not make a character-deletion test a terrain integration test. Actual geometry/combat/travel/life/loot consumers retain coverage; broad startup/playable smoke still uses current bytes.

Three in-engine full-floor previews were reviewed: `.godot/terrain-layout-91247.png`, `.godot/terrain-layout-91249.png`, `.godot/terrain-layout-91255.png` (blue entry, gold exit). These previews deliberately hide fog for inspection. They do not change normal player sight or camera zoom. Automated cases cannot prove that every possible screenshot or player-reported location is resolved; seed-based diagnostics and continued playtesting remain useful.

Historical context: [previous junction blend](PATH_JUNCTION_FIX.md), [natural Wilds presentation](NATURAL_WILDS.md). This final terrain bake supersedes the earlier blend-only approach for configured procedural floors.

## Verified release

Final connected run `20261110-190548-b6747d7b`: 22 affected suites passed, 80 unchanged results reused, 102 registered suites covered. Earlier passing geometry/consumer evidence was preserved; 39 planner self-tests passed. Packaged validation passed 51 selected checks and reused 18 unchanged packaged results, plus startup/catalog/exclusion checks and a real host/three-guest connect-and-play smoke. Both source and packaged terrain host/guest compatibility and reconstruction tests passed. Full-suite mode was not used.

Updated only `C:/Users/sutte/Desktop/Mystical Garden v0.5.2.2.exe`; installed SHA256 `563ae60d8918bbbb56697a46668fcfaece1c8e3afe2e091806746c8991cfb65d` matches the tested staged artifact. Previous EXE retained at `.godot/release/backup-20261110-191030-Mystical Garden v0.5.2.2.exe`. Co-op participants must all update because the terrain signature now guards map/collision compatibility. Protected pre-cleanup backup untouched.

## VFX07 · Wilds surface materials

The live floor draws a single opaque ground plane. Its fragment shader reads a nearest-filtered axial substrate map and the existing signed-distance atlas for water, paths and clearings. The terrain laboratory can also use the welded preview mesh, where UV and UV2 carry terrain weights. Both views use world-space texture coordinates and the same Wilds surface settings. Garden frontier materials retain their own treatment.

The new 512 × 512 mipmapped RGB texture encodes moss cushions and leaflets, silt with pebbles, and warped shale bedding. It is project-authored. The editable generator is `tools/art/wilds_surface_texture.py`. The channels blend with the existing leaf and soil textures at two rotations and scales. Small changes in surface normals affect lighting without displacing vertices. The signed shoreline separates opaque dry ground and shaded water. Simulated opacity changes how much of the submerged bed shows through the water tint. Moving highlights and short shore ripples require no reflection pass.

Open Settings → Developer Garden → Enter Testing Arena. Select a nonzero terrain seed under Scenarios. In F4 → Tuning → World, adjust texture scale, surface variation, trail fringe, relief, water speed or opacity. Changes apply to the current floor and subsequent floors immediately. Presets retain the ordinary source-fingerprint checks.
