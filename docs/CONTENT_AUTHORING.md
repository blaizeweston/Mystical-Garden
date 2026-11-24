# Adding content without breaking synchronized systems

## Required order
1. Give each seed, component, enemy, class, weapon, node and upgrade a unique permanent string ID. Names and positions may change; published IDs must not be reused.
2. Add or edit the authoritative catalog. Keep the frozen v1 manifest and v2 component order unchanged. New components append after existing IDs. Save migration remaps indices by the stored manifest.
3. Connect inventory, crafting, rewards, progression and visuals before calling the content playable. Run content validation and a meaningful end-to-end acquisition-to-use test.
4. Run the regression and release checks, then update only the highest numbered EXE. Keep authoring sources and archives out of the runtime pack.

## Authoritative entry points
| Content | Source and contract |
| --- | --- |
| Seed | `seed_catalog.gd` DEFINITIONS: stable id, tier, numeric runtime part reference, parents, effects, tags, discovery conditions; matching portrait in assets/ui/seeds |
| Component | `weapon_parts.gd` registry; extra plant components in assets/items/custom_components.json with id, plant species ID, effects, tags, rarity and name |
| General inventory material | Item catalog custom registry; a plant_part category must resolve to a real component. A tagged miscellaneous item alone cannot enter weapon slots. |
| Enemy | assets/enemies/catalog.json plus matching GLB and authored role; template tools/enemy_model_template.py and tools/make_enemies.py |
| Class / weapon / learned choice | class_catalog.gd; unique weapon/node IDs, supported weapon_motion.gd profile, valid node parents and effects |
| Checkpoint upgrade | assets/upgrades catalog; class/weapon/tag eligibility and supported effects; weights remain in the shared upgrade resolver |
| Garden observation | `garden_interaction_catalog.gd`: stable parent/point/observation IDs, supported observe/cue handler, anchor and inherited tech requirements; see docs/GARDEN_INTERACTIONS.md |
| Heart technology | Heart catalog and heart_progress.gd; Knowledge start costs, saved timers and exact optional offering plans |
| Pace / schedule | assets/content/balance.json and encounter_config.gd; checkpoint, biome and graft intervals are independent |

Effect names are a contract, not arbitrary executable tags. `content_validator.gd` lists supported numeric effects. Tags select authored slot interactions and upgrade eligibility; merely inventing a tag does not create a new combat behavior. Add resolver support and a behavioral test for new semantics. Keep changes to reach, damage, targets, cooldowns and graft chance within their existing bounds.

Components use one identity across inventory, equipment, altar refinement and checkpoint eligibility. Original numeric entries remain frozen for compatibility. Every seed automatically receives a refined harvest entry; set its ordinary part reference to the registry index and validate it. Do not hand-edit frozen manifests to make a failing mapping pass.

## Persistence and action boundaries
Validate the full request, identify its owner, compute the exact cost, then mutate through `game_transaction.gd`. `save_batch.gd` journals multi-file changes and restores interrupted commits before loading. Publish guest profile updates and success messages only after persistence succeeds. Avoid saving a character independently halfway through a Garden operation. Quarantined retired content remains available for a later explicit migration.

The host owns world changes and combat. Movement/public combat state uses the frequent channel; owner inventory and Garden details use a separate reliable channel. Short combat effects also have reliable event delivery. Do not send another full backpack in every movement packet. Reject mismatched content manifests when registering a guest. Direct-IP transport now supports up to three guests across reachable interfaces. network_settings.gd owns protocol, ports and validation. Require admission before snapshots/actions, keep profile identity unique, and increment the protocol when its wire contract changes. This remains trusted-friend hosting with client-supplied progression; it is not an account-authenticated public service.

## Explicit authoring budgets
Class learned choices use a 63-bit mask. The Garden supports up to nine cultivation beds. Their positions come from the Garden layout. Enemy snapshots support twelve scouts plus the leader; IDs have a separate 16-bit field. These are validated capacities, not roster sizes. Increasing a budget requires its placement/rendering/network check, not an unrelated class or enemy count clamp.

## Art source ownership
`tools/make_natural_world.py` and `assets/source/natural_world.blend` own shared wilderness exports. `tools/build_field_travellers.py` owns the current rigged travellers; `tools/make_enemies.py` uses the enemy/boss templates and catalog for every current enemy, including Nightbloom. The Altar retains its matching generator and Blender source. Superseded generators, their old outputs and sources were removed during the 2026-11-10 cleanup; see `STALE_CODE_CLEANUP.md`. Hand-edited assets must record their ownership here before regeneration.

Use flowing asymmetrical roots, bark variation and restrained organic detail. Garden materials stay green, warm and readable around water. Wilds soil and corruption deepen by biome and depth through the active shader parameters. Reserve saturated corruption accents for threats; do not turn every tree into a purple monster. Combat warnings must remain readable over the terrain. The HUD root illustrations establish surface treatment; current character/crop silhouettes still need a future art pass.

## Verification and release
Run tools/validate_release.ps1 for isolated source suites and co-op pairs. Use tools/release_latest.ps1 to validate catalogs, fingerprint runtime sources, export a staging EXE, reject archived/test resources, preserve a backup, and replace only the highest numeric revision. The package must then pass the documented external-script smoke check. Local JSONL metrics record timing/rewards without player identities or transmission; they support balancing but do not prove weeks of content.

## Character roster expansion
character_slots.gd owns independent profiles, migration and profile leases. INITIAL_COUNT is 3; set_capacity increases the persisted roster capacity up to MAX_COUNT (128), and the main menu builds scrollable character cards from count(). World capacity stays independent. Always pass the selected roster profile to both host and guest character paths. Never restore the old per-world character coupling or delete roster profiles as part of world replacement. Shared character_appearance.gd drives both the creator preview and in-game model. tests/character_roster.gd covers expanded slots, identity preservation, multiple characters in one world and safe failed joins.

## Shared travel
party_travel.gd owns party membership, readiness epochs, loadout signatures, aggregate resource reservations and consent. Never call _enter_wilds or _use_checkpoint from a player action; those are transaction-internal operations. Route requests through enter_wilds/use_checkpoint so they cannot bypass readiness. Keep upgrade-card decisions separate from travel votes. Store ready state only in session snapshots, never in character or world progress. tests/party_ready.gd and party_ready_coop.gd cover this contract, including rollback, shared paid-route reservations and the finale.

## Combat balance and adaptation
Tune the combat section of assets/content/balance.json instead of scattering spawn/health/drop constants. combat_director.gd resolves population, locked encounter health, movement pacing, threat selection and drop probabilities. Keep the twelve-scout protocol budget and minimum telegraph validation intact. Player targeting shares the same visible/reachable candidate selection between basic attacks and skills. New direct damage/skill paths should retain actual source-species kill records, authored warnings and the hit-grace boundary.

wilds_learning.gd owns versioned memory normalization, bounded evidence, quiet decay, retained peaks and depth-limited trait selection. Store it in the host Garden only, within the same transaction as encounter settlement. Summoned creatures do not become natural loot sources. Keep item eligibility/weights separate from the encounter drop-chance gate. tests/combat_balance.gd validates distributions, collision equivalence, co-op scaling, targeting and save/recovery. The performance fixture now engages all twelve scouts; older idle-actor CPU samples are not comparable.

Monster rewards are handled by monster_rewards.gd. Append species and their component definitions without reordering published IDs. Kill events freeze personal loot rolls before transactional settlement; never add rewards to floor-clear collection. Use the pending-kill service for new combat sources so deduplication, XP, rollback, private drops and co-op delivery stay synchronized. Regeneration of a new model should preserve EnemyCore, Root pivots, Growth1/2 and Adapt sockets.


## Current botanical/class expansion
The current roster is 24 plants, 62 components, 104 checkpoint cards and five classes with twelve nodes each. The active component order is assets/content/part_order.json; append here without editing frozen migration manifests. The first 44 component identities and first eight nodes of every class remain stable. Use the new specialization and checkpoint behavior templates. combat_traits.gd handles status setup, limited secondary contacts, fields and authored class interactions; new keys require a handler and an effect test. The class tree now renders explicit parent IDs rather than inventing previous-row connections. New class levels six/seven use 140/260 XP. See CONTENT_DEPTH_2026-11-08.md for the sequential acceptance gates and scope.

## Garden zones relationships and background life

GARDEN_SPRING_LIFE.md documents the implemented zone/water/bed, mature-species clue and ambient-family templates. Add content to the existing catalog; use stable bed/species/technology IDs and an existing refinement recipe. Garden water/paths/decoration read garden_layout.gd. Cosmetic life uses bounded local instances and shaders with an optional motion preference; it has no loot, collision or progression authority. Specific Garden shader ownership rules must come before the generic shader rule in test_map.json. New interactive fauna or physical shorelines need explicit authoritative behavior and co-op/prediction coverage.
