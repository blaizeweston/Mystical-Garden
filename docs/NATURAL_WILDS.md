# Natural Wilds environment pass

This pass begins the shift from rounded, bright placeholders toward a darker organic
forest inspired by the HUD's worn, intertwined wood. Character and monster models
remain a separate future art pass.

## Movement and readable boundaries

Generated clearings can extend beyond the legacy arena's z=23 movement clamp. Normal
movement now uses the generated field's region, preserving the original authored arena
bounds for nonprocedural fixtures. The navigation region was expanded to contain those
outer clearings. Floor rendering and movement still use the same signed floor field.

The underlying forest bed now uses dark leaf-litter soil, distinct from open dirt paths.
Blocked gaps should read as forest rather than a continuation of the playable ground.

## Roots and scenery

Old per-corridor root trimming discarded pieces at merged junctions. Roots now trace
continuous contours of the combined floor. Quantized shared endpoints keep the trace
connected. Smaller woven roots and tapered outward branches add an organic silhouette;
roots are decorative and do not introduce separate collision barriers.

New Blender source: assets/source/natural_world.blend.
Rebuild script: tools/make_natural_world.py.
Updated assets: root_tree, root_snag, root_stone, wild_ruin, wild_path.
Trees have curved tapered boughs, fine twigs, pointed individual leaves and trunk ridges.
Stone and paving have eroded irregular surfaces. Shared materials supply muted bark,
foliage and stone colours with fine normal detail. Soil and root bark use reusable
procedural shaders under assets/shaders. Fallen leaf litter replaces angular grass V's.

## Validation

- tests/natural_world.gd checks real player movement beyond the former arena boundary,
  connected destinations, and continuous root geometry across multiple generated maps.
- Existing path_junctions and exploration_maps checks cover bidirectional junction
  crossing, 48 deterministic connected maps, solid cover and route following.
- Combat, fog/map, Garden presentation, support/death and full solo regression checks.
- Rendered close views of a flank clearing and outer clearing for visual inspection.

The exact map seed in the user's screenshot was unavailable; the tests reproduce the
legacy clamp and exercise shared junction cases rather than claiming that exact floor
was reproduced. Only the latest playable EXE (v0.2) is replaced.
