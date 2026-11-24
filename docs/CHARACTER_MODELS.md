# Playable character models

Each traveller has one visible 65-joint skeleton and one animation player. Both the character creator and the live game build it through `traveller_avatar.gd` and `field_traveller.gd`.

| Change | Edit |
|---|---|
| Character shape, clothing or accessories | `assets/characters/field_traveller_male.glb` and `field_traveller_female.glb`. `tools/build_field_travellers.py` assembles the Quaternius source models. Preserve bone names, skin weights, mesh names used by the accessory controls, and the six named morph channels. |
| Appearance | `character_appearance.gd`. Height ranges from 92% to 108%. Build, shoulders, face width, jaw, nose and eye size drive visible mesh blend shapes. The hood covers the selected hairstyle. Shoulder armor, bracers and belts toggle independently. |
| Idle, walking and running | `traveller_locomotion.gd` samples `field_locomotion.glb`. Distance traveled drives the gait, and the visible soles provide the grounding correction. |
| Weapon carry, attack and release | `field_traveller.gd` composes the pose. `weapon_pose_catalog.gd` and the per-weapon animation scripts map the reviewed clips, grips and recovery. `assets/characters/weapon_actions.json` defines timing and contact. |
| Class and Core casts | `assets/characters/field_skill_poses_male.res` and `field_skill_poses_female.res` contain the default cast and twelve class poses. Rotation tracks are in model space, indexed by visible joint name and normalized cast phase. `field_traveller.gd::pose_equipped` layers them over the moving hips and legs. |

`character_creator.gd` and the Garden character panel use the same appearance definition. Existing characters keep their identity, progression and appearance fields. Protocol 41 packs the cosmetic choices into the existing 64 bits.

Focused checks are `tests/character_rig.gd`, `tests/character_overhaul.gd`, `tests/character_customization.gd`, `tests/character_locomotion.gd`, `tests/weapon_actions.gd` and the two-player presentation fixtures.
