# Weapon animation and attack warnings

All fifteen class weapon forms use reusable motion profiles in `weapon_motion.gd`.
`combat_effects.gd` draws their trails, projectiles, impacts and enemy warning shapes.

| Class | Weapon motions and effects |
| --- | --- |
| Warden | Rootblade sweep and arc; Briar Spear thrust and streak; Heartwood Maul overhead slam and expanding impact |
| Weaver | Spore Staff casting shot; Thorn Wand quick bolt; Seed Focus lifted orb projectile |
| Ranger | Vine Bow draw and arrow; Bark Arbalest recoil and bolt; Thorn Ring spinning throw |
| Reaper | Alternating Graft Knives slashes; Harvest Scythe wide arc; Root Lash extending curved trail |
| Oracle | Bloom Bell shake and pulse; Spore Censer pendulum and smoke pulse; Petal Fan flick and petal projectile |

Core plant color tints the effects. Motion duration follows the weapon attack interval.
Ranged shots take a short flight time before applying damage. Targets can evade a shot;
terrain blocks it, and shots cannot hit a reused enemy slot or follow into another floor.
The Wilds records ranged tactics using distance at launch.

Enemy warnings now distinguish charge corridors, leap landings, ranged aim, area damage
and supporting chants. The stag charge has repeated directional V markers, parallel lane
edges and a landing circle. Its damage sweeps the marked corridor and landing area;
terrain clips the charge destination. Supporting chants use green warnings.

To add a weapon, add its class catalog entry and motion profile, then choose an existing
trail/projectile shape or extend the effects renderer. Attack state and effect events
travel with existing snapshots. No additional multiplayer transport is introduced.

Validation: all fifteen poses, seven projectile forms, delayed impacts, enemy identity,
charge lanes, terrain clipping and floor cleanup; existing class/skill, enemy roster,
support/death, inventory, altar, checkpoint, weighted upgrade and solo playthrough checks.
Representative screenshots were rendered and inspected. Internet co-op was not tested.

Release policy: replace only the most recent playable EXE. Current target is
`Mystical Garden v0.2.exe`; older versions must remain untouched. Keep pre-update binary
backups outside the project so they are not included as game resources.
