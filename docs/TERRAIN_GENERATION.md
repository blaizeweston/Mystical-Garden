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

### Habitat, visibility and field review

Outer Grove uses olive crowns, pools of warm light and scattered drifting motes. Sable Mire has cooler crowns, wet peat, teal water and a moving bank mist shaded directly onto the ground. Hollow Below uses exposed shale, pale elevated roots and sparse silver-violet fungal light. Raised deadfalls, root arches and selected trunks show darker cambium veins with a slow pulse. Corruption has no ground warning or gameplay effect.

The feature renderer groups existing vegetation by material on each generated floor. Wind phase comes from the placement of each plant. Only upper crowns in the narrow camera corridor ahead of the local observer are thinned, using an opaque cutout. Trunks retain depth. The ordinary sight radius still controls actors, resources, warnings and the new airborne motes. The laboratory overview continues to show the full floor. One batch of soft, unshadowed motes uses existing habitat positions. The ground carries the water motion, filtered light and mist, with no extra mist planes, reflection render, shadow light or physics objects. A floor owns its material instances.

Open **F4 > Tuning > World** during authorized Developer Wilds or on a nonzero Testing Arena scenario floor. Sway, foreground crown thinning, cambium contrast, mote density, Mire mist and habitat light join the six surface controls above. Select **Compare Wilds scenery at production settings** to compare on the current floor without losing experimental values. Named presets use the existing save, reset, source comparison and export controls. Exploration, enemy and resource placement use their usual independent random streams.

[Three biome comparisons](vfx07-biomes.jpg) / [Ordinary expedition resources and a real enemy warning](vfx07-exploration.jpg) / [Ambient motion and mixed combat](vfx07-motion.webp)

The solo comparisons use the normal 1100 x 720 camera. The Grove, Mire and Hollow practice scenes use depth/seed pairs 2/136, 10/137 and 16/129. The old and new builds returned identical layout and cell hashes, entries, gates and generated specimen and Returning Root positions for these floors. Real expedition seed 927227169 yielded both projected objects, an accepted harvest and the deposit prompt. The combat sequence includes ordinary weapon contacts, Thorn Line, both Rime Bloom phases and Brittle rupture. A separate Rootbound wind-up produced the same sweep radius, width, arc and origin in each version. Ambient shader clocks and individual combat frames can differ between runs.

The close foreground crown in the Grove previously masked the avatar and part of a sweep. Both are easier to follow in the new view. The player, natural specimen and Returning Root retain their prompts. The low root can still blend into dark wood beside trees. Angular crown clusters and flat bridge planks are the clearest candidates for a later model and texture pass. Review Hollow shale contrast and the amount of thinning in motion before setting final values.

### Rendered measurements

Godot 4.7.2 Compatibility, RTX 5080, 1100 x 720, VSync off. Each entry compares VFX06B with VFX07 in milliseconds. Each sample window lasted 2.6 seconds. Capture and image encoding ran separately. The first combat window includes the first use of the mixed build on that floor. The warm tests repeated the same actions. CPU and GPU time were not measured independently.

| Floor | First combat p95 at 120 FPS | First combat worst | Warm combat p95 at 120 FPS | Warm combat p95 uncapped | Warm exploration p95 uncapped |
| --- | ---: | ---: | ---: | ---: | ---: |
| Outer Grove | 8.85 / 8.96 | 38.38 / 42.94 | 8.88 / 9.05 | 4.45 / 4.88 | 4.43 / 4.90 |
| Sable Mire | 8.90 / 8.94 | 27.61 / 31.83 | 8.80 / 8.84 | 4.96 / 4.97 | 4.89 / 4.68 |
| Hollow Below | 8.85 / 8.81 | 33.27 / 35.61 | 8.79 / 8.86 | 4.93 / 5.13 | 4.92 / 5.07 |

The new scenery added one draw call and about 1 MiB of reported texture memory in like-for-like samples. At the three depths the mote batches contained 179, 110 and 47 quads respectively, sharing three or four habitat materials in total per floor. Ground and water remain opaque. Sparse mote quads are the additional transparency cost. The main directional shadow map still uses the established scene settings. The measurements include its cost. They do not isolate shadow rendering or overdraw.

Recreating the whole practice world took 1.71 / 1.77 s in the Grove, 2.05 / 2.12 s in the Mire and 1.18 / 1.16 s in the Hollow. Each discarded practice world was released. A separate fresh-process probe drew the Grove, Mire, Hollow and Grove again in the same scene. The baseline first Grove draw plus synchronization took 166.12 ms. VFX07 took 600.46 ms in one process and 198.15 ms in another. Repeating the Grove within each process took 1.51 ms on the baseline and 1.79 / 1.60 ms on VFX07. These forced full-scene draws include driver waits and do not establish that shader compilation caused the spike. All previous floor atmosphere nodes and their material instances were released across transitions.

The earlier 263.17 ms Monsoon frame, 310.41 ms Storm frame and 495.22 ms Spirit frame during recording remain unexplained. Lower-end and four-player graphical performance are unmeasured.

The focused generation, biome, continuity, collision, floor play, fog, botanical art, specimen harvest, combat preview, effects, readability and developer lifecycle checks passed using disposable storage. The developer check applied surface and habitat settings to the live material, compared production and experimental appearance on the same floor, and saved, loaded, reset and exported a preset.

Ordinary two-player loopback passed. In two standard four-player launches, the overflow client's 32-second wait expired. The host wrote its full-party marker 34.3 and 33.5 seconds after its own ready signal. Both failed runs are preserved. In a third run, the four players started normally and the fifth process launched when the host signalled a full party. All five unmodified fixture scripts passed, including floor replacement, private flora claims, resource banking and fifth-client refusal. The committed fixture waits for the existing altar setup marker before starting its ordinary full-party wait. The standard runner then passed with all five processes (vfx071795658523647), including refusal and next-floor assertions. Each wait uses the original 32-second deadline.

On both VFX06B and VFX07 the synthetic terrain network fixture also reached its matching geometry assertions, then raised an error when settling a disconnected synthetic participant. Its manual setup had skipped Garden return registration. The fixture now uses the normal return owner for both participants. Repeating the whole two-player test passed, including teardown. The existing guest checkpoint-offer and expedition-summary timeouts, long-path renderer startup issue and the two saved Garden layout validation mismatches remain open.
