# Enemy framework plan

Status: proposed 2026-11-21. Supersedes the live-game stages in `mob_sim/MIGRATION.md`.

## Goals

1. Live combat keeps working exactly as it does now. The current ("legacy") enemy code stays the live default and is not restructured.
2. A new enemy framework is built as a clean replacement. Only the Neural Arena runs it until the neural net is trained and accepted.
3. The framework adds the mechanics the net was designed around: per-slot abilities, mana with channeling, dodge, flying, hearing, smell and darkness.
4. Performance is a first-class requirement, because training speed is limited by simulation speed.
5. When it is ready, a host setting chooses **Legacy enemies** (default) or **New enemies**. Legacy is retired only after the new system is accepted.

## Decisions on record

| Topic | Decision |
|---|---|
| New mechanics | Mob dodge, hearing and smell, real flying, enemy mana pool |
| Mana | Several casts drain the pool. The mob must then channel to refill, which roots it and leaves it vulnerable |
| Darkness | Turn the fog of war into a real visibility mechanic for enemies and players. It gets its own toggle, separate from the enemy toggle |
| Objective | Protect their supports (support casters and broodmothers) |
| Rewards | Small reward for line of sight on a player, reward for damage dealt, smaller reward for healing, large reward for killing a player, small penalty for own HP lost |
| Existing files | Changed only in small, approved steps. Each step lists its files first |

## Why a replacement instead of a refactor

The legacy enemy code works, but its structure makes additions hard:

- A regular enemy is an untyped Dictionary with about 40 combat fields. A leader is split across `EnemyTactics`, the roster's leader member and a `memory` Dictionary. Bosses keep separate plans.
- Decisions and actions are interleaved in `scout_behavior.gd`. Only the "attack now or wait" choice crosses a clean decision boundary.
- Species specials are selected by numeric kind checks spread across `enemy_behaviors.gd`, `scout_behavior.gd`, `enemy_support.gd`, `enemy_skill_responses.gd` and others.
- Each species has one attack. Extra moves come from a spawn-time variant, learned counter-moves, mutation bits and support rites.
- Target selection (`combat_director.gd::target`), crowd separation (`navigate`) and escort lookups (`enemy_formation.gd::allies`) loop over all enemies for every enemy, every tick.

Restructuring that code in place would risk live combat while another refactor is in progress. A replacement avoids both risks. Legacy cleanup then becomes a deletion instead of a rewrite.

## Performance design

### Principles

| Rule | Why |
|---|---|
| GDScript orchestrates. C does per-mob and per-pair loops | A GDScript loop costs roughly 50–100 ns per operation. Native loops are about 100x cheaper |
| Struct-of-arrays state in typed packed arrays | Cache-friendly. Can be passed to C without copying |
| No allocations in the tick | No Dictionary, Array or String creation in hot paths. Buffers are preallocated per encounter |
| Data compiled to flat tables at load | Species and ability ids become integers. No string lookups in the tick |
| Work at the rate it changes | Perception every 6 ticks, decisions every 6 to 30 ticks, flow fields only when a target moves a cell, light only when a source changes |
| Batch everything | One native call per system per tick, not one per mob |
| Fixed-step integer time | No real clock reads. Identical seeds give identical runs |
| Measured budgets | Every system reports its microseconds. Benchmarks fail when a budget regresses |

### Native core additions

The existing core (`mob_sim/native`) already has the clearance grid, flow fields, sphere-traced sight, crowd separation, the observation builder and the policy runner. The framework adds:

| Native feature | Replaces | Cost shape |
|---|---|---|
| Uniform spatial grid, rebuilt each tick by counting sort | All-pairs enemy loops | O(n) build, O(k) neighbour query |
| Batched sense queries: sight with light, hearing events, scent sampling | Per-mob GDScript perception | One call per perception refresh |
| Ability shape kernels: circle, sector, line, ring, multi-spot, chain | Per-attack GDScript geometry | One call tests every release against every player |
| Light grid, updated per changed source | Nothing yet | Cost only on change |
| Scent grid with decay | Nothing yet | O(players) writes, O(cells) decay every few ticks |
| Second movement layer for flying | Nothing yet | One extra clearance grid and flow fields on demand |

### Budgets

These are the goals. `mob_sim/perf/budgets.json` holds them with the recorded baseline and a regression floor, and `mob_sim/tests/run_bench.ps1` measures against it.

| Scenario | Target |
|---|---|
| Simulation only, 100 mobs, 4 stand-in players | 100x real time or better per process |
| Simulation only, 20 mobs | 300x real time or better per process |
| Neural Arena with real combat, 20 mobs, 4 bots, headless | 40x real time or better |
| Live game with New enemies, 20 mobs, 4 players | Enemy work under 0.5 ms per tick |

Training runs several headless processes in parallel, so per-process speed multiplies.

## Framework structure

The framework grows from `mob_sim/`, which already holds the simulation, its native core and its tests. New code goes into these folders. Existing `mob_*.gd` files move into them when a later phase rewrites them, so no phase moves a file without changing it.

| Folder | Contents |
|---|---|
| `mob_sim/definitions/` | Typed definition classes, the loader, the validator and the table compiler |
| `mob_sim/state/` | The mob pool and per-slot ability state |
| `mob_sim/systems/` | Perception, decision, rules, abilities, movement, status, resolution |
| `mob_sim/abilities/` | Ability behaviour classes |
| `mob_sim/brains/` | The brain interface, the scripted brain and the neural brain adapter |
| `mob_sim/ports/` | The world port interface the host implements |
| `mob_sim/native/` | The C core |
| `mob_sim/data/` | Ability, kit, trait and mutation data, keyed by the catalog's species ids. It sits inside `mob_sim/` so the `.gdignore` keeps it out of exports and validation inputs until the live toggle |
| `mob_sim/perf/` | Per-system timers and speed budgets |

`assets/enemies/catalog.json` stays the single source for species identity, base stats, models and loot. The framework reads it and does not change it.

### Definitions

| File | Holds |
|---|---|
| `species_def.gd` | Catalog id, a kit of four ability slots, movement options and traits |
| `ability_def.gd` | Slot, delivery, target, sight need, aim lead, range band, wind-up, recovery, cooldown, mana cost, interruptible flag, shape, effects, unlock rule, elite bonuses, behaviour handler and the legacy move it reproduces |
| `shape_def.gd` | Circle, sector, line, bent line, spots or trail, with its radius, width, span, anchor and offsets |
| `effect_def.gd` | Damage, root, hazard, ally haste, summon, pull, repeat pulse, heal, command, steal, decoy or guard |
| `trait_set.gd` | Flight layer, sight, darkvision, hearing, smell, armour, evasion, dodge and mana |
| `modifier_def.gd` | Spawn-time mutations such as Reach and Bark |
| `definition_loader.gd` | Parses the data, checks every cross-reference against the catalog and caches the result |
| `definition_tables.gd` | Compiles everything into flat packed arrays indexed by species and slot |

Kit slots are 0 basic, 1 signature, 2 counter and 3 special. Slot 3 holds elite or leader abilities and species-specific actions such as the Graft Thief's loot grab. Vault and dodge are movement options, not ability slots, because the net already has separate behaviours for them.

Any value written as `"catalog"` is copied from the enemy catalog when the tables are compiled. Basic attacks inherit range, wind-up, recovery and radius this way, so the two systems cannot drift apart on those numbers. The loader refuses unknown fields, ids, slots and handlers, mismatched mutation bits, and species whose flight disagrees with the catalog.

Legacy features map onto kits like this:

| Legacy feature | Framework equivalent |
|---|---|
| Role attack | Slot 0 basic ability |
| Spawn-time variant | Signature ability unlocked by floor and party play style, used when the brain chooses |
| Learned counter-move | Counter ability unlocked by the same evidence the legacy code records |
| Mutation bits | Mutation modifiers |
| Cover vault | Movement option enabled by the Mobility mutation |
| Support rite | Basic ability with a rite delivery, plus a shared fallback attack when no escort is near |
| Elite signature | The species' signature ability, with elite size bonuses |

### Runtime state

`MobPool` keeps one row per mob in packed arrays, as it does now. The framework adds per-slot cooldowns, mana, channel state, dodge state, flight state, armour, damage-over-time stacks and sense memory. Rare, species-specific state such as the Graft Thief's stolen items lives in small typed side tables indexed by mob, not in the hot arrays.

### Systems and tick order

| Order | System | Responsibility |
|---|---|---|
| 1 | Clock | Advances one fixed tick |
| 2 | World intake | Reads party positions, player states, hazards and light sources from the world port |
| 3 | Spatial grid | Rebuilds the neighbour grid |
| 4 | Perception | Sight with light, hearing, scent and memory, at the perception rate |
| 5 | Decision | Builds masks, batches due mobs, asks the brain, validates intents |
| 6 | Abilities | Starts wind-ups, spends mana, releases through shape kernels, applies effects |
| 7 | Status | Damage over time, roots, slows, haste, channeling, dodge windows |
| 8 | Movement | Flow fields per layer, manoeuvres, separation. Nothing else writes positions |
| 9 | Resolution | Sends hits, hazards and summons to the world port, emits events |

### World port

Every system reaches the game only through one interface. The Neural Arena implements it now. The live game implements it when the toggle is added.

The port supplies party state, map data, light sources and hazards. It also accepts hit requests, which go through the game's existing `incoming_player_hit.gd`, wards and statuses, so player-side combat rules are shared rather than copied.

### Brains

One interface takes the observation batch and returns intents (behaviour, target, manoeuvre, ability slot):

- The scripted brain is a port of today's legacy decision rules. It is the baseline and the fallback.
- The neural brain is the existing net, retrained on schema v2.

### Events

Typed events (wind-up locked, released, hit, dodge, channel started, death and others) go to a ring buffer. Presentation, audio, the diagnostics journal and training rewards read them, so none of them depend on framework internals.

### Presentation and multiplayer

At first, the arena mirrors framework mobs into the roster fields the existing enemy visuals read, so models and animations work unchanged. A dedicated framework view replaces the mirror in Phase 5. New mechanics (channeling, dodge, flight) send their presentation data through a versioned extension, so legacy packets never change.

## New mechanics

| Mechanic | Design |
|---|---|
| Mana | Per-species pool and per-ability cost. Channeling refills it, roots the mob and makes it take extra damage. The net sees its mana fraction and channel state |
| Dodge | Short sidestep with brief invulnerability and a cooldown, for agile species. The net sees player wind-ups so it can learn to dodge them |
| Flying | Hover species use a second movement layer that ignores low walls and ground hazards and is immune to roots. Hit rules stay 2.5D |
| Hearing | Attacks, casts, dodges and sprinting emit noise events. Mobs inside the radius learn the source position without sight |
| Smell | Players leave a decaying scent trail. Mobs with smell follow it to the last known position |
| Darkness | The host keeps a light grid from ambient biome light plus light sources: player light, fire, glowing species and the Heart. Enemies see players in light at full range, and darkvision extends sight past the edge of light and around the enemy itself. Players see enemies only when they are lit or close. The fog of war is drawn from the same grid. Guests rebuild the grid from the replicated light sources |

## Training

| Part | Plan |
|---|---|
| Environments | Simulation-only with stand-in players for early, fast training. Neural Arena with real combat for fine-tuning and evaluation |
| Parallelism | Several headless processes. Godot runs batched inference in C. PyTorch trains on the GPU |
| Algorithm | PPO with the existing recurrent policy and the shared critic state |
| Curriculum | Single mob, then squads, then mixed species with supports, then elites. Opponent bots get stronger over time |
| Evaluation | Fixed seeds against the scripted brain: damage, kills, survival, support uptime and fairness checks |
| Checkpoints | Saved to `ai/checkpoints/`, where the arena's brain picker finds them |

### Rewards v2

Weights start here and are tuned during training. One player health bar is 1.0.

| Reward | Start |
|---|---|
| Damage dealt | +1.0 per health bar |
| Healing done | +0.6 per health bar |
| Player downed | +3.0 |
| Line of sight on the current target | +0.01 per second, capped per decision window |
| Own HP lost | -0.3 per own health bar |
| Supported ally alive and casting | Small positive per second |
| Support lost | -1.0 times the support's value |
| Own death, party wipe, intent-change smoothing | Kept from `ai/training/rewards.json` |

The line-of-sight reward must stay small, or mobs learn to stand in the open.

### Net inputs

Schema v2 unmasks every input that has real data. Changing the schema means training starts fresh.

| Input | Source |
|---|---|
| Hazards | Enemy hazards and player-made fields |
| Damage over time | Burning, Bleed and Frost on mobs |
| Armour, evasion | Traits, including the legacy Bark mutation |
| Player stats | Class and weapon stats, cooldowns, wards and statuses |
| Party profile | The ranged, burst and choke pressure scores |
| Resource, dodge, flying, senses, light | The new mechanics |
| Objective | Protect supports |

## Phases

Each phase ends with evidence and a review before the next starts.

| Phase | Work | Existing files |
|---|---|---|
| 0 | Fix ward grants mixing clocks. Make the simulation test drive combat time | 10 ward files and one validation anchor file. Done 2026-11-21 |
| 1 | Folder structure, definitions, loader, validator, table compiler, per-system timers, benchmark budgets and the baseline | None |
| 2 | Native executors, decisions, perception and movement speeds, with parity tests; senses with a light grid; status system. Done 2026-11-21 | None |
| 3 | Ability shape kernels and effects. Port every regular species' kit. The arena's world port uses the real player-hit rules | Arena files only |
| 4 | Mana and channeling, dodge, flying layer, darkness in the arena, hazards and player fields | Arena files only |
| 5 | Dedicated framework presentation. Elite kits. Bosses keep scripted plans for now | Arena files only |
| 6 | Schema v2, rewards v2, training loop, curriculum and evaluation | None |
| 7 | Live toggles, with Legacy enemies and darkness off by default | Small hooks: settings, `tick_enemies`, spawning, guest snapshots, fog of war. Approved step by step |
| 8 | After acceptance: New enemies become the default, then legacy enemy code is removed | Approved separately |

Phases 2–5 and Phase 6 overlap. Training can start on the simulation-only environment as soon as Phase 3 lands.

### Comparing with legacy

Exact trace parity with legacy enemies is not realistic, because movement uses a different pathfinder. Instead, the arena runs legacy enemies and New enemies with the scripted brain on the same seeds and compares damage per minute, time to kill, hit rate and ability use per species. Large gaps are fixed or recorded as intended changes. The arena's "Current game AI" option stays available for this comparison.

## Phase 0 record

- Ward grants in `combat_action_events.gd`, `native_effects_world.gd`, `oracle_combat.gd`, `ranger_combat.gd`, `reaper_combat.gd`, `subclass_combat.gd`, `warden_combat.gd`, `water_combat.gd`, `water_tidal_return.gd` and `weaver_combat.gd` passed the real clock as the grant time while expiry used combat time. In the arena, wards could expire at once or lose their card effects. They now pass the combat time already in scope. Normal play is unchanged, because both clocks are equal there. Two exact anchors in `tools/validation_scope_matches.json` were updated to match.
- `Battlefield.navigate` throttles route searches with combat time. The simulation test did not drive that clock, so identical encounters diverged. `mob_sim/tests/mob_sim_arena.gd` now sets combat time from its own tick while it moves the stand-in players.

Checks on 2026-11-21:

| Check | Result |
|---|---|
| Simulation contracts | 154 passed, 0 failed |
| Neural net runtime | 54 passed, 0 failed |
| Arena checks | 49 passed, 0 failed |
| Two-process multiplayer | Passed |
| Focused game validation | 185 of 187 suites passed |

`ct04_reaper` ("water stops Veil Dance but the legal Siphon Cut still recovers dodge") and `garden_knowledge_preview` ("protects landmarks and the Wilds entrance") fail with the same messages on the unmodified `Enemies-and-Neural-Net-Framework` branch, so they predate this change. A control suite passed on that unmodified copy.

## Phase 1 record

Built 2026-11-21. No existing game files changed.

- Definitions for all 24 catalog species and 65 abilities in `mob_sim/data/`, with typed classes, a loader and a table compiler in `mob_sim/definitions/`. Loading and compiling takes about 6 ms.
- `mob_sim/tests/mob_definition_checks.gd` (43 checks) reads the legacy code's own tables and proves every variant, learned response, elite signature, role and boss plan has a framework ability with the same unlock floor and evidence. It also checks catalog inheritance, mutation values, vault rules, deterministic compilation, and that 12 kinds of broken data are refused for the right reason.
- `MobSim.timers` measures each system when enabled and costs nothing when off. The arena's headless runner takes `--profile` to split each tick into bots, enemies and the rest of the game.
- `mob_sim/perf/budgets.json` and `mob_sim/tests/run_bench.ps1` record the baseline and fail on regressions.

### Baseline

| Scenario | Times real time | Target | Time per tick |
|---|---|---|---|
| Simulation, 20 mobs | 182 | 300 | 0.10 ms |
| Simulation, 100 mobs | 34 | 100 | 0.53 ms: decision 0.19, executors 0.20, movement 0.08, perception 0.05 |
| Arena, neural enemies | 12 | 40 | Enemies 0.36 ms, bots 0.29 ms, rest of the game 0.62 ms |
| Arena, scripted framework enemies | 12 | 40 | Enemies 0.32 ms, bots 0.31 ms, rest of the game 0.58 ms |
| Arena, legacy enemies | 7 | None | Enemies 1.16 ms, bots 0.24 ms, rest of the game 0.82 ms |

### What the baseline shows

- At 100 mobs, the decision and executor systems are 75% of the simulation tick. Both are GDScript loops over every due mob, so moving their inner loops into the native core is the first Phase 2 speed task.
- Legacy enemies cost about 1.2 ms per tick with 20 enemies, roughly three times the framework path. The live toggle should therefore make normal play faster, not slower.
- In the arena, the rest of the game's combat step (0.6 ms) now costs more than the enemies. The 40x arena target cannot be reached by enemy work alone. Phase 5 should skip work a headless arena never needs, such as presentation, guest snapshots and audio, through arena-only overrides.

### Intended behaviour changes

- Legacy variants replace a species' attack for the whole spawn. In the framework they are signature abilities that unlock under the same rules, and the brain chooses when to use them.
- Values marked provisional in `species.json` (senses, dodge, flight and mana) only take effect in Phase 4.

## Phase 2 record

Built 2026-11-21. No existing game files changed. The arena bridge, which is framework code, now passes already-resolved damage unscaled.

### Native hot paths

Each moved system keeps its GDScript version as a reference. `mob_sim/tests/mob_native_parity.gd` runs both on identical state every tick across three encounters (20, 60 and 100 mobs, 7,200 ticks).

| System | Native file | Reference | Parity result |
|---|---|---|---|
| Executors | `native/mob_exec.c` | `mob_executors_reference.gd` | Modes, targets and 906 attack starts identical. 63 movement offsets differ by at most 5e-7, because Godot's and the native library's sine and cosine round differently |
| Legal-action masks | `native/mob_decide.c` | `MobRules.build_masks_reference` | Identical |
| Scripted brain | `native/mob_decide.c` | `mob_scripted_brain_reference.gd` | 32,896 decisions identical |
| Perception and ally slots | `native/mob_sense.c` | `MobPerception.update_reference`, `refresh_allies_reference` | Identical with senses off |
| Movement speeds | `native/mob_exec.c` | `MobLocomotion.speeds_reference` | Identical |

Attack starts still go through `MobAbilities.begin`. The native executors only propose attacks that pass the rules depending on simulation state, with a fallback movement row, so host checks such as the arena's real-game sight test still apply in mob order.

The native core already had a spatial hash, rebuilt only when mobs move, for neighbour searches and crowd separation. Native perception uses it directly, so no separate grid was needed.

### Speed

| Scenario | Phase 1 | Phase 2 | Target |
|---|---|---|---|
| Simulation, 20 mobs | 182x | 501x | 300x |
| Simulation, 100 mobs | 34x | 140x | 100x |
| Simulation tick, 100 mobs | 0.53 ms | 0.14 ms | |

At 100 mobs the remaining time is decisions (0.05 ms, mostly the GDScript decision upkeep and commit), movement (0.05 ms, mostly the native navigation step) and executors (0.03 ms). Arena speed is unchanged at about 12x, because the arena's cost is in the real game's combat step, which Phase 5 addresses.

### Senses

`native/mob_sense.c` adds light, darkvision, hearing and smell, switched on with `MobPerception.set_senses(true)`. They stay off until Phase 4. `mob_sim/tests/mob_sense_checks.gd` (18 checks) covers them.

- **Light:** the host supplies light sources and an ambient level. The light grid, and each cell's distance to the nearest lit cell, are rebuilt only when they change. A cell is lit at a quarter light or more. Within normal sight range and a clear line, a mob sees a player who stands in light, within its darkvision of the mob, or within its darkvision of the edge of any lit area. So darkvision extends sight past the light a mob stands in, and lights a radius around it in full darkness.
- **Hearing:** the host reports noises with a loudness. Every mob whose hearing reaches a noise learns its position, even through walls, and engages.
- **Smell:** players leave a scent trail that halves every six seconds. Engaged mobs with smell follow the freshest trail within range when they cannot see the player.
- **Design change with senses on:** engaged mobs no longer track unseen players within their awareness radius for free. They must see, hear or smell them. With senses off, that legacy tracking stays, so parity holds.

### Status system

`mob_status.gd` adds damage over time and damage modifiers. `mob_sim/tests/mob_status_checks.gd` (18 checks) covers it.

- Damage over time stacks its damage per second, keeps the longest duration, lands four times a second, credits kills to the player who applied it, and costs nothing when no mob is burning.
- Armour uses the shared balance's armour ratio and comes from the Bark mutation or a species trait. Dodge windows ignore hits and record a `DODGED` event. Channeling multiplies damage taken by the species' channel value.
- `damage_mob` takes `scaled = false` for damage a host has already resolved. The arena bridge uses it so real-game armour is not applied twice.

Per-slot cooldowns already exist in `MobPool.cooldown_until`, one per mob and attack slot. The definition tables carry each ability's cooldown, and Phase 3 applies them when kits replace the role-based attacks.
