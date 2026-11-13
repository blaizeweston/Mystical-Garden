# Weapon animation and contact review — 2026-11-10

## Mechanics order and findings

Reviewed in dependency order: crafted weapon stats and tags → delivery/target geometry → release timing and damage → visible effects → character poses and hand attachments → network snapshots → release checks. The mechanics test map now includes the new contact helper, action profiles and regression suites.

The main problems were a generic projectile windup circle, only a few shared character clips, a second layer of procedural arm movement, delayed hand attachments after manual skeleton sampling, and separately specified visual and damage footprints. These have been replaced with a shared action/contact contract.

## Every class and weapon

| Class | Weapon | Authored action | Interaction and visible tell |
|---|---|---|---|
| Warden | Rootblade | One-handed cut | Forward sector lights at contact |
| Warden | Briar Spear | Supported thrust | Narrow forward corridor |
| Warden | Heartwood Maul | Two-handed heavy swing | Broad sector, later contact |
| Weaver | Spore Staff | Supported casting push | Spore projectile from current staff-side muzzle |
| Weaver | Thorn Wand | Short casting flick | Narrow, quick needle projectile |
| Weaver | Seed Focus | Two-handed chest-height focus release | Orb starts at the raised focus; splash on confirmed impact |
| Ranger | Vine Bow | Left-hand hold, right-hand draw/release | Animated string/nocked arrow; no firing circle |
| Ranger | Bark Arbalest | Supported fire/recoil/reload | Bolt from forward muzzle |
| Ranger | Thorn Ring | Backhand throw | Traveling ring; chain links only on confirmed hits |
| Reaper | Graft Knives | Paired close cuts | One knife per hand, short sector |
| Reaper | Harvest Scythe | Two-handed sweep | Wide forward sector |
| Reaper | Root Lash | Vine flick/extension | Segmented vine follows its forward corridor |
| Oracle | Bloom Bell | Bell ring | Caster-centered radial pulse |
| Oracle | Spore Censer | Suspended censer swing | Directional smoke sweep through a forward sector |
| Oracle | Petal Fan | Raised fan flick | Individually swept petal projectiles fan out, with one hit per enemy per attack |

Each form has a ready pose and attack clip. Ten additional crafted line/sweep variants keep the animation consistent when parts change delivery. Each model now contains 46 clips including the original six locomotion/ability clips. Class abilities retain their separate cast action.

## Blender and Godot approach

Preserved the shared 25-bone skeleton, skinning and six customization morphs for both models. Added mesh UVs to eliminate tangent import errors. Authored distinct actions with an analytic two-bone arm solve, then keyed local bone rotations for portable glTF playback. Complete poses and retained immutable animation tracks prevent transforms leaking from a previous weapon. Upper-body poses blend over locomotion, with free-arm counter-swing where appropriate. Hand attachments are refreshed from the sampled skeleton before weapon rendering. Spear, staff and wand forward axes are verified explicitly.

Editable source: `assets/source/travellers.blend`. Rebuild with `tools/make_travellers.py` and `tools/weapon_animation_template.py`. Shared definitions: `assets/characters/weapon_actions.json`. This is an animation and rig integration pass on the existing models, not a new character art/sculpting pass.

Official references consulted:

- [Blender inverse kinematics](https://docs.blender.org/manual/en/5.2/animation/armatures/posing/bone_constraints/inverse_kinematics/introduction.html): chain positioning and pole control informed the baked arm solve.
- [Blender bone deformation](https://docs.blender.org/manual/en/5.2/animation/armatures/bones/properties/deform.html): retain vertex-group skinning and the shared deformation skeleton.
- [Blender action baking](https://docs.blender.org/manual/en/4.5/editors/nla/editing/strip.html): evaluate poses into ordinary keyed bone transforms for export.
- [Blender glTF export](https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html): named, sampled actions, skins and morph targets.
- [Godot animation blending](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html): separate upper-body actions from locomotion.
- [Godot import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html): preserve complete tracks and import sampled clips.

## Contact contract

`weapon_contact.gd` owns resolved shapes and contact timing. Rendering consumes those same dimensions. Melee resolves against current enemy body footprints at the authored contact time. Projectiles use swept flight, current release positions, shared radii and terrain clipping. Secondary splash/chain effects occur after confirmed impacts. Native bell/censer pulses remain radial. Existing target caps still limit the number of enemies damaged. Decorative limbs do not enlarge enemy body footprints.

Protocol is now 18 because attack event/snapshot metadata changed. Everyone in a multiplayer session must use the updated build.

## Verification

Focused checks passed: all 30 model/weapon combinations, distinct action poses, grips, string/nock alignment, forward tips, crafted variants, release timing, geometry, moving muzzles, locomotion, customization, class skills and combat readability. A real local host/guest pair passed dedicated bow action, projectile dimensions, damage and absence of the firing circle. These are local automated network checks, not an internet playtest.

The accompanying contact sheet uses the actual imported character rigs and runtime weapon attachments in a posed QA scene. It is not a gameplay screenshot.
Final release verification: 75 source suites passed with stable inputs; all 42 selected packaged suites and the four-player network smoke passed. Installed only Mystical Garden v0.5.2.0.exe; previous copy retained in .godot/release. Validated source fingerprint: B9AB22EC886810140953BC130FDA938E58532B45D6C8ADB47499526603E8CB7A. Installed EXE SHA256: C65895C13F0CCC6CB0448E88824C416C5A13F26A7BC4926F3D6BBBDD6F9BBB93. Restored learning distance from the player release position to the enemy center independently of muzzle/surface collision. Rotated string/vine segments now scale on their local length axis, with endpoint regression coverage.
