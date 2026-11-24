# Traveller anatomy, skinning and weapon animation overhaul

Historical implementation notes. The current models, animation assets and editing paths are listed in [Character models](CHARACTER_MODELS.md).

The character pass rebuilds both clothed models in Blender 5.2.3 LTS and keeps the existing character identities, class progression, appearance array, 25 deformation-bone names, six morph names and weapon action IDs. It replaces the disconnected, slender garment construction and spread-elbow poses that contributed to the scarecrow appearance. This is a detailed game-mesh iteration within the current fantasy art style, not a photoreal character asset.

## Research applied

- Blender's [Armature Deform Parent](https://docs.blender.org/manual/en/5.0/animation/armatures/skinning/parenting.html) notes that automatic weights can require manual correction. The generated cloth uses anatomical, normalized transitions across shoulders, elbows, hips and knees rather than inverse-distance competition between unrelated bones.
- [Armature Modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/deform/armature.html) documents deformation through bone-named vertex groups. The build preserves the shared skeleton and verifies normalized skin weights on the imported meshes.
- Blender's [shape-key guidance](https://docs.blender.org/manual/en/5.3/animation/shape_keys/introduction.html) describes independent offsets from a Basis shape. Mesh union/polish happens before skin/morph authoring; every slider target starts from Basis, preventing cumulative deformation or topology changes after morph creation.
- [F-curve properties](https://docs.blender.org/manual/en/5.3/editors/graph_editor/fcurves/properties.html) explains interpolation and handle behavior. Dense sampled actions, compatible Euler keys, smooth knee recovery and continuous elbow-plane orientation avoid abrupt pose changes; runtime layering does not delay the upper-body contact pose behind its authored phase.
- Godot's [3D formats guidance](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html) and [retargeting rules](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html) inform the GLB interchange: identity transforms, shared rest rig, named skins/morphs and fully sampled portable actions. No Blender control rig or runtime IK plugin is required by players.

## Model and pose changes

- Fuller torso/hip/limb proportions, rounded facial features, retained female chest volume, updated hair fit and a curved, tapered travelling cloak/cowl.
- A continuous remeshed and polished tunic/sleeve shell replaces overlapping shoulder pieces. Parallel-transport tube frames remove ring twists at limb bends. Accessories, face and hands retain their separate surface detail inside the skinned body mesh.
- Relaxed hands hang closer to the hips during idle and counter-swing during travel. Ready poses reflect the held weapon rather than uniformly raised arms. Walking/running continue while the upper body attacks.
- Elbow-plane IK is baked into actions. Rest-to-direction twist singularities found in hammer/scythe animation were removed; the scythe support wrist stays away from the shoulder singularity. Crossbow reload movement blends instead of switching hand targets instantly.
- Every weapon has its existing complete ready/attack channels, including crafted delivery variants. Named palm sockets put handles inside the hands; bow draw and shaft-support targets follow the same grip-space orientation used by the weapon visuals.
- Per-frame smoothing remains for locomotion/state transitions. Active upper-body poses follow the authored attack phase directly, preserving contact timing at different render rates. Host hit geometry, attack costs, speeds, ranges and projectile timing are unchanged.

The male/female body meshes contain roughly 28k vertices each before engine LOD processing, plus the selected hair. Generated GLBs are about 4.5 MB each. Existing engine LOD/import settings remain in use. Only visible hair is drawn; customization updates when appearance changes rather than deforming vertices on the CPU each frame.

## Sliders and compatibility

The saved appearance array still has 13 entries. Height changes vertical scale only (0.92–1.08). Build changes thickness around each limb's own axis instead of shifting the whole hand away from its socket. Shoulders changes upper-body contour; face width, jaw, nose depth and eye size remain separate localized signed morphs. Hair and clothing color/style options retain their existing IDs. The creation preview is framed more closely and retains its rotation control.

Body proportions remain cosmetic. They do not change movement collision, reach, damage or a character's progression. Existing character records need no migration. Both model variants use the same bone/action contract so weapon switching, local preview, host and guest presentation share one pipeline.

## Files and reusable authoring

`tools/make_travellers.py` authors the anatomy, normalized weights, continuous garment, independent morphs and locomotion. `tools/weapon_animation_template.py` bakes weapon-specific ready/action targets and support-hand poses. `assets/source/travellers.blend` is the editable Blender source; the two runtime GLBs and `rig_manifest.json` live in `assets/characters/`. Regenerate with the installed Blender in background mode, then import with the project Godot engine. Use `--python-exit-code 1` when invoking the generator so a Python error cannot silently leave old assets in place.

Run Blender again with the saved `.blend` and `--python-exit-code 1 --python tools/audit_travellers.py`. This read-only audit confirms that both rigs, normalized source skins, six morphs and the full action library survive reopening. Base actions now retain explicit fake users; without those, idle/walk/run and generic actions existed in the export process but could be discarded from the saved source.

`traveller_avatar.gd` handles manual sampling, layered animation, floor contact and wrist/palm sockets. `weapon_visuals.gd` positions existing weapon meshes at the palm anchors. `character_creator.gd` changes only preview framing. New weapons should add profiles/actions to the established template, not a second arm animation in the weapon renderer. Keep the contact/release marker shared with the existing weapon interaction model.

## Validation and selective scope

`character_overhaul` checks 90 body/combined-slider/weapon combinations, individual slider channels, normalized skin weights, actual palm-handle positions, bow nock alignment, complete primary/crafted action continuity and identical upper-body contact poses at 30/240 render FPS. It also bounds triangle-edge stretch/collapse at combined morph extremes. Visual inspection caught discontinuous negative shoulder/build deformation that simple morph-channel checks missed; smooth skin-weighted fields, smooth region transitions and bounded anatomical ranges replaced those discontinuities. Existing rig, locomotion, weapon actions/contact, character save/customization and real network suites cover consumers. The weapon co-op fixture now uses a customized female character with extreme height/build/shoulder values and verifies host receipt and guest rendering.

Crafted line-blade/heavy and spear-sweep visuals now begin and end in their own ready orientation, avoiding a weapon-only snap even when the arm pose was continuous. This final adapter is scoped separately in `avatar_motion_view` so an orientation refinement does not discard verified unrelated model/economy evidence.

The first plan would have rerun 94 of 96 suites because every world import recursively includes the avatar meshes. Explicit presentation boundaries retain verified pre-overhaul dependency identities for unrelated mechanics while hashing actual visual bytes into character/presentation tokens, broad source smoke and release identity. The stable contract is the same bones, morph/action IDs and absence of gameplay collision. Contract changes must broaden ownership. Planner self-tests cover visual invalidation, unrelated reuse, malformed boundaries and refusal of stale packaged evidence. No passing log/result was copied or fabricated.

The reviewed plan selects 42 affected suites and reuses 54 unchanged results. Full game-suite validation is reserved for a major release or explicit request. Exact source/package release results are recorded below after verification.

## Recovery

The pre-overhaul character files are retained in `.godot/character-overhaul-before-20261110-161052`, with stage notes. This is separate from the protected pre-cleanup backup, which was not opened or modified. Only the highest numbered EXE may be replaced, with its existing release-tool backup.

## Released evidence — 2026-11-10

Final connected run `20261110-165209-9da282c7` passed 41 affected suites with 55 verified results reused (96 registered). All 39 planner self-tests passed. Earlier targeted passes caught and resolved joint singularities, crafted-ready snaps, and combined-slider garment creasing; only evidence for current inputs authorizes this release. Full game-suite validation was not run.

Packaged validation passed 26 selected suites with 37 reusable results, startup/catalog/exclusion validation, real four-player admission/full-session rejection, and a host/three-guest movement/animation/private-detail smoke at differing render rates. The dedicated customized guest fixture and all body/slider/weapon, crafted variant, topology and continuity checks passed in the package. Reopening the actual saved Blender source also passed the read-only authoring audit.

Only `Mystical Garden v0.5.2.0.exe` was replaced. Installed SHA256 `350704604482770610f98ca9aeac90dc45e6a417fc1bca4898cc159616cfba03` matches the verified staged package. Prior EXE: `.godot/release/backup-20261110-165718-Mystical Garden v0.5.2.0.exe`. The pre-overhaul character backup and protected pre-cleanup checkpoint remain retained; the protected checkpoint was not accessed.

Evidence: `.godot/character-build.log`, `.godot/character-source-audit.log`, `.godot/character-import.log`, `.godot/character-overhaul-connected-release.log`, `.godot/character-overhaul-package.log`, `.godot/validation/last-package.json`, and `.godot/network-tests/20261110-165710-5edf4929`. Renderer/creator error logs are empty. Previews were reviewed for neutral/ready/contact poses, all weapon families, both bodies at combined minimum/default/maximum slider settings, and actual creator framing.

Previews: [body and ready poses](character-overhaul-ready.png), [combined slider extremes](character-overhaul-sliders.png), [weapon poses](character-overhaul-weapons.png). Personal identities, class XP, plant familiarity and the existing appearance-array format are preserved. Garden G-08 remains the next Garden milestone; this character overhaul does not claim its playtest-backed pacing targets are complete.
