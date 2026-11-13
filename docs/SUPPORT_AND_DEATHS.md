# Support groups and enemy deaths

Support enemies such as the **Bellcap Cantor** now spawn in a local fighting group rather than at an isolated spawn point. Each support requires at least two nearby, reachable combat allies. Formations reuse existing encounter slots, remain on walkable terrain and avoid the player entrance. If a legal escort formation cannot be placed, that support slot becomes a combat enemy instead of spawning an unsupported caster.

Support units follow living combat allies and cast near them instead of independently chasing the player. A Cantor's haste affects nearby combatants (including the lead monster) with line of sight; it no longer buffs itself. Haste improves movement and recovery between attacks. If all combat allies are killed, a surviving support uses a short-range defensive attack so the encounter can still be finished.

The enemy template supports `support`, `escort_min` and `escort_radius` fields. The Cantor uses two escorts within 3.8 units. Future support types can reuse the formation rules; their specific abilities still need their appropriate behavior handler.

## Death animation

Lethal weapon and class-skill hits create an authoritative death event. The enemy's combat health reaches zero immediately, removing it from targeting and combat; an independent visual body remains to animate.

- Walkers and bounding creatures recoil and topple.
- Swaying plant creatures fold and wilt.
- Flying creatures drop and fold their limbs.
- Crawling bodies squash and settle.
- Bodies darken, shed small spores and fade out over approximately 2.1 seconds.

The system uses each enemy's actual model, growth stage and adaptations. Visual bodies have no collision or damage. They respect exploration visibility, are capped at 24 active bodies, deduplicate repeated state events and clear on floor changes. Fade materials are private to each death body, preserving living enemy colors and opacity. Guardian crowns and attack warnings disappear when their living owner dies.

Ordinary loot and checkpoint progression remain available immediately after a clear. The Heart finale waits about 1.5 seconds to show its collapse before resolving the existing ending and returning the party to the Garden.

## Verification

Across 300 generated floors, 139 support units remained in the pool and every one had two reachable combat escorts. Checks also covered forced support-heavy pools, walkable placement, following allies rather than players, buff targets, orphaned support defense, lethal-hit events, visible collapse, fade and cleanup, collision-free bodies, snapshot deduplication, material isolation and all ten model variants. Collapse/fade poses and an escort group were rendered and inspected. Existing enemy roles, hit reactions, weapon/class skills, grafting, weighted upgrades, checkpoints and run-flow tests passed. The full solo test checks both finale endings after the new animation window.

The full solo gameplay test passed both ending paths after the animation window. The exported build passed the 300-floor support and all-model death checks. Both playable executables were refreshed with prior builds backed up; v0.2 launched successfully.
