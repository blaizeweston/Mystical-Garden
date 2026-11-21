# Mob architecture and migration plan

> Superseded on 2026-11-21 by [docs/ENEMY_FRAMEWORK_PLAN.md](../docs/ENEMY_FRAMEWORK_PLAN.md). Live enemies now stay on their current code, and this folder grows into the replacement framework, which only the Neural Arena runs until a live toggle is added. The measurements and tick order below remain accurate background.

This folder holds the target mob architecture. The normal game does not use it yet, but the Neural Arena does. Every stage below that edits an existing file needs approval first.

Stage 1 (the shared combat clock) is done. Stage 2 and the bridge in Stage 3 are covered by the Neural Arena, which works alongside the current enemy code rather than through the decision hook in Stage 4. See [docs/NEURAL_ARENA.md](../docs/NEURAL_ARENA.md) for the existing-file changes and the references to update after refactors.

## Approach

Migrate through a bridge. The current enemy code stays authoritative for damage, status effects, variants and bosses, while the neural brain takes over decisions one layer at a time. Scripted enemies stay the default until the neural path is proven.

Replacing the enemy data model first was rejected for now. Mob state is used across 40 gameplay scripts and 96 test scripts, and that rewrite would delay training on real combat without improving what the net learns.

## Baseline measurements

Measured on the current game, headless, with players standing still while enemies attack them.

| Encounter | Whole combat tick | Enemy AI share | Fastest possible training speed |
|---|---|---|---|
| 1 player, 8 scouts | 1.29 ms average | 0.42 ms | About 13x real time |
| 4 players, 20 scouts | 3.64 ms average | 0.70 ms | About 4.6x real time |

Enemy AI is only about a fifth of the four-player tick. The rest of the combat loop must be profiled in Stage 2 to reach the brief's 10x target.

## Stages

| Stage | Result | Existing files changed |
|---|---|---|
| 1. Shared combat clock | Combat can run at a fixed step. The live game behaves the same | See the list below |
| 2. Real-combat training arena | Headless encounters with scripted player bots, repeatable runs and a measured training speed | None planned. Speed fixes are proposed separately |
| 3. Shadow bridge | The net observes real combat and decides without acting, so its choices can be compared with current enemies | None |
| 4. Decision hook | The net controls regular scouts and gate elites in the arena | `scout_behavior.gd`, `elite_enemy.gd`, `enemy_formation.gd` |
| 5. Training | The training loop runs against real combat rules | None |
| 6. Native movement | Neural-controlled scouts use the new pathfinding | None planned. The bridge detects knockback and other outside position changes |
| 7. Ship behind a setting | Players can run the neural brain, with scripted as the default | `project.godot`, `tools/test_map.json`, `docs/MECHANICS_TEST_MAP.md`, `tools/release_latest.ps1`, `tools/test_workflow.py`, `tools/validation_execution.py`, `tools/playtest_release.py`, `docs/DIAGNOSTICS.md` |
| 8. Higher mob counts (optional) | More than 20 scouts in play | `encounter_config.gd`, `world_snapshot.gd`, `network_settings.gd`, `network_contract.gd`, `stage.gd`, `game.gd` |
| 9. Retire old code (optional) | The pool replaces the current enemy data model | Decided after Stage 7 |

Each stage ends with evidence and a stop for approval.

## Stage 1 file changes

A new `combat_clock.gd` returns the real clock in the live game and a fixed-step clock in the training arena. These combat rule reads move to it:

| File | Reads to change |
|---|---|
| `game.gd` | `use_class_skill`, `grant_guard`, `_physics_process`, `move_player`, `dodge_player`, `strike_enemy`, `finish_combat`, `_finish_combat`, `reset_encounter`, `record_enemy_death` |
| `enemy_attack.gd` | `lock` (2) |
| `core_combat.gd` | 2 |
| `weapon_contact.gd` | 2 |
| `class_ability_targeting.gd` | 2 |
| `mouse_combat.gd`, `boss_encounters.gd`, `combat_traits.gd`, `combat_status.gd`, `expedition_life.gd`, `expedition_pressure.gd`, `expedition_transitions.gd`, `enemy_skill_responses.gd`, `elite_enemy.gd` | 1 each |
| `tools/test_map.json`, `docs/MECHANICS_TEST_MAP.md` | Classify the new clock file |

Presentation, networking, diagnostics and save timing keep the real clock. Validation uses the focused and connected suites selected by `tools/validate_release.ps1`.

## Tick order

`MobSim.tick()` runs these layers in a fixed order on the host:

| Order | Layer | File | Responsibility |
|---|---|---|---|
| 1 | Clock | `mob_clock.gd` | Advances whole simulation ticks |
| 2 | Perception | `mob_perception.gd` | Updates what each mob senses and remembers |
| 3 | Rules and brain | `mob_rules.gd`, `mob_brain.gd` | Builds action masks, asks a brain for intents, refuses illegal ones |
| 4 | Executors | `mob_executors.gd` | Turns each intent into movement goals and attack requests |
| 5 | Abilities | `mob_abilities.gd` | Runs telegraphed wind-ups, releases and recovery |
| 6 | Locomotion | `mob_locomotion.gd` | Moves mobs through the native core. Nothing else writes position |

Shared data lives in `mob_pool.gd` (mob state), `mob_species.gd` (species tables), `mob_party.gd` (player slots), `mob_events.gd` (event log) and `mob_contract.json` (behaviours, action heads and rule values).

## Host boundary

| Direction | Call | Purpose |
|---|---|---|
| Game to sim | `configure(field)` | Bakes the current `Battlefield` |
| Game to sim | `party.set_player(...)` | Publishes each player before the tick |
| Game to sim | `spawn(request)` | Adds a mob with its scaled stats |
| Game to sim | `damage_mob(slot, amount, player)` | Applies resolved player damage |
| Game to sim | `record_hit(slot, generation, player, amount)` | Credits resolved damage to the attacking mob |
| Game to sim | `apply_status(slot, status, ticks, scale)` | Applies stun, root, slow or haste |
| Game to sim | `abilities.interrupt(slot, delay, tick)` | Cancels a wind-up |
| Sim to game | `events.read_since(cursor)` | Wind-ups, releases, deaths and intent changes |

## Bridge coverage

The bridge keeps these current behaviours in their existing code, so the net acts through them instead of replacing them:

- Species variants in `enemy_variants.gd` and learned responses in `enemy_skill_responses.gd`.
- Special actors in `thief_escape.gd` and `glasscap_feint.gd`.
- Support rites, shelter and corpse effects in `enemy_support.gd`.
- Player effects that redirect or slow enemies in `spirit_affinity.gd`, `frost_combat.gd` and `void_affinity.gd`.
- Exact hit shapes in `enemy_attack_hits.gd`.

Bosses stay scripted.

## Rule choices made in this design

- A species' single attack fills the basic attack slot when it is a plain melee or ranged attack, and fills ability 1 otherwise.
- Support casters get a basic melee attack only when no fighter ally remains, matching the current desperate attack.
- The mobility mutation's vault is ability 2.
- At most 6 mobs can wind up on one player at once. The value is in `mob_contract.json`.
- A mob that has sensed nobody for 5 seconds uses the scripted brain instead of the neural net.
