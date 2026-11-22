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

Brains do not run every tick. Each mob decides every 6 ticks (100 ms) when fully smart and up to every 30 ticks (500 ms) when dim, staggered across slots; the executors carry the chosen intent on every tick in between. Commitment comes from the rules, not extra inputs: a wind-up locks the mob, each behaviour has a minimum hold (250 to 800 ms), and the observation already carries the current behaviour, target, time since the last change and progress, with a recurrent memory for longer history. A small reward penalty discourages needless switching.

A hit, the mob's own release or an interrupt brings its next decision forward (`MobPool.prompt_decision`), never closer than 6 ticks after its previous one. Dim mobs then react to events within about 100 ms without polling faster, and a burst of hits costs one decision.

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
| 3 | Kits drive every species' attacks, with release geometry, effects and behaviour handlers. The arena resolves them with the real player-hit rules. Done: parts 1 to 3 on 2026-11-21, the legacy comparison on 2026-11-22 | Arena files only |
| 4 | Mana and channeling, dodge, flying layer, darkness in the arena, hazards and player fields. Done 2026-11-22 in four parts | Arena files only |
| 5 | Arena speed, presentation of the new mechanics (replicated to guests), and elite kits with the gate elite run by the framework. Bosses keep scripted plans for now. Done 2026-11-22 in three parts: speed, presentation, elite kits | Arena files only |
| 6 | Schema v2, rewards v2, a stronger stand-in party, a resumable training loop, curriculum with self-play, and evaluation. Parts A (schema v2), B (rewards v2) and C (stand-in party) done 2026-11-22 | None |
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

## Phase 3 record

Phase 3 runs in four parts. Parts 1 and 2 were built 2026-11-21. No existing game files changed.

### Part 1: kits in the simulation

- `mob_species.gd` now compiles each species' four attack slots from its kit instead of from its catalog role: 0 basic, 1 signature, 2 counter, 3 special. Supports keep their rite in slot 0, which needs an escort, and their fallback attack in slot 3, which works only alone. Field names are unchanged, so the native systems and the net's observations read kits without changes.
- Signature and counter slots unlock through two spare mutation bits. A spawn's floor and play-style evidence decide them. Floor zero unlocks everything, which training uses.
- `mob_release.gd` builds each release's areas from its kit row: circles, sectors, charge lanes, bent lanes, pulls, spots and trails. They use the legacy padding and line-of-sight rules.
- With `resolve_hits` on, as in training, the abilities layer hits the stand-in party itself (a `HIT` event with damage, root and pull), runs hazards, and repeats pulses.
- The contract's `ability_3` is now the species' special slot rather than leader-only. The scripted brain tries it last, which is how supports fall back to their lone attack.

### Part 2: the arena uses the kits

- `neural_arena/arena_abilities.gd` locks each wind-up's geometry from the kit. The real enemy also receives a legacy-shaped attack plan, so the game's warnings, poses, audio, Oracle omens, staggers and Bark guards keep working.
- At release, hits go through `incoming_player_hit.gd` with the real battlefield's line of sight, once per player. Hazards go through the game's hazard system. Leaps move the real enemy, pulls move players, haste reaches nearby fighters, and Broodmothers hatch through the game's brood rules.
- The bridge recomputes each enemy's unlocks every tick. Signatures follow the legacy play-style scores, with "late" always met. Counters unlock once the party denies that enemy, using the flags the game already sets.
- An arena check runs a floor-12 round. Five kit abilities fired, including the unlocked Nightbloom signature, 39 hazards reached the real game, and players took damage through the real hit rules.

### Speed

Releases now resolve real geometry and hits in GDScript. The simulation is 390x real time at 20 mobs (was 501x) and 135x at 100 mobs (was 140x), both still above target. The arena stays about 11 to 12x.

### Intended behaviour changes

- The cover vault is no longer an attack slot. It returns in Phase 4 as a movement option beside dodge, so mobile enemies do not vault until then.
- Supports cast their rite whenever a fighting ally is in their perception, rather than when any fighter is alive on the floor.

### Part 3: behaviour handlers

Built 2026-11-21. Rules that data alone cannot express live in `mob_sim/abilities/`, one small class per behaviour. A handler has up to three hooks: `approach` (a short step before the wind-up), `plan` (choose targets and adjust aim at the wind-up, or refuse the attack) and `resolve` (act at release, and optionally skip the kit's generic effects). Handlers reach the world only through a `HandlerPort`. The training simulation implements it in `sim_handler_port.gd` and the arena in `neural_arena/arena_handler_port.gd`, so each handler is written once. `handler_registry.gd` maps the data's handler names to classes, and a check proves the two lists match.

| Handler | Species | Behaviour |
|---|---|---|
| `corpse_tether` | Pallbearer | Tethers the nearest unconsumed corpse within 5 units (7 for the long tether; the spare tether skips the corpse last disrupted) and heals from it. No corpse, no cast |
| `shepherd_command`, `relay_order`, `flank_route` | Root Shepherd | Orders visible escorts onto its target for 2.6 seconds. A flank order sends one escort along a bend route around the target; a relay order sends only that escort |
| `echo_toll`, `antiphon` | Bellcap, Root Choir | Casts through an ally: the toll rings around the farthest visible fighter and hastes the two allies nearest it; the antiphon strikes a sector from an ally near the target. Nothing happens if the ally dies or moves away first |
| `choir_pulse` | Root Choir | Needs a visible fighter. The split chorus strikes a second beat 730 ms later, turned 2.3 radians |
| `brood_hatch`, `scattered_hatch` | Broodmother | Hatches juveniles at safe sites, at most two out at once. The scattered hatch splits them to opposite sides and skips sites a player stands near |
| `side_approach` | Gallhorn, Wicker Wasp | Steps to the side before winding up the angled charge or wide flank |
| `cover_first` | Bellcap | Once per life, steps behind the nearest fighter, away from the target, before the first covered bell |
| `learned_approach` | Gallhorn, Seamroot, Wicker Wasp, Ashen Hart | Bent routes for the antler hook and deep seam, a cut-off landing for the side sting, and a short landing with embers to both sides for the ember fork |
| `cutoff_aim`, `denied_aim`, `side_anchor` | Ashen Hart, Nightbloom, Lantern Lure | Aims beside the target, at where the last volley was stopped, or pulls from a lantern set to the side |
| `canopy_shift` | Hollowback | Leaps to re-cover the ally a player slipped out of its shelter |

Orders change the rules, not a brain: while an order lasts, the commanded player is the only legal enemy target, so the scripted and neural brains both obey it. Approach steps and route points run in the executors, native and reference, ahead of the current behaviour. The parity test injects both so the native and reference executors are compared on them.

In the arena, the game itself provides some behaviour, so those handlers need nothing extra there:

- Shelter and the planted canopy: the game's own player-attack code shelters allies near a Hollowback, and reads the planted canopy from the wind-up's plan.
- The Graft Thief's grabbing and escape, and the Glasscap's feint: the bridge runs the game's `EnemyBehaviors.tick` for those species, and while it owns them the simulation holds them. Their grabs release through the game.
- Corpse healing uses the game's corpse balance, hatching uses the game's brood rules, and per-enemy memory is the enemy's own record, so legacy flags such as a denied volley or a broken shelter are shared.

The training simulation has no dropped items or shelter rules, so the thief only fights there and Hollowbacks do not shelter. Bosses keep their scripted plans until Phase 5.

Checks: `mob_sim/tests/mob_handler_checks.gd` (30 checks) covers every handler in the training simulation. A new arena check runs supports against the real game; it saw Shepherd rallies with orders active, Choir pulses, Bellcap chants, both Pallbearer tethers and a learned counter (the Rootbound's rooted sweep, unlocked when the bots blocked its route). Speed stays above target: 395x real time at 20 mobs and 108x at 100.

### Part 4: comparison with legacy

Done 2026-11-22, after Phases 4 and 5. `neural_arena/tests/arena_compare.gd` plays the same rounds twice, once with the game's own enemy AI and once with framework enemies on the scripted brain: each species in turn (five of it, plus two Rootbound escorts for other species), four map seeds, floor 12, one bot, 45-second rounds. Everything is read from the game's own enemy records and the players' health, so both brains are measured the same way:

```
godot --headless --path . --script res://neural_arena/tests/arena_compare.gd -- --seeds=4 --seconds=45
```

Per species it reports wind-ups started per enemy-minute alive and the mean time to kill; per roster, the party's health lost per minute, round length and rounds cleared or lost. The game does not record which enemy dealt a hit, so damage is compared per roster, not per enemy, and hit rates are not reported.

**Fixes the comparison found:**

| Gap | Cause | Fix |
|---|---|---|
| Ashen Hart rosters dealt no damage | Its charge was ported with only its ember trail. The game's charge hits along its lane and at its landing, then leaves embers | Trails now hit along the lane and landing like a line, and keep their spots for the hazard; the charge and cutoff charge have their damage effect |
| Melee mobs swung about half as often | The scripted brain gave two of every three melee mobs a circling manoeuvre, and attackers aimed at a ring at 85% of their reach, so a retreating target kept slipping out of reach | As in the game's scouts, plain melee mobs close straight in and run at their target (0.7 units off) rather than to the ring; skirmishers still circle and ranged mobs keep their range. Native and reference changed together; parity holds |
| Results differed between brains by bot luck | Each bot's fighting style came from a random stream that carried over between rounds, and advanced differently with each brain | Bots now take their style from the round's seed, so the same round gives the same bots under either brain |

**Results after the fixes** (legacy / scripted):

| Species | Wind-ups per enemy-minute | Time to kill (s) | Roster damage per minute | Round length (s) | Cleared / lost |
|---|---|---|---|---|---|
| rootbound | 12.3 / 9.4 | 7.8 / 10.0 | 46.8 / 43.6 | 12.5 / 17.9 | 4-0 / 4-0 |
| nightbloom | 15.0 / 11.4 | 12.4 / 14.2 | 109.9 / 39.4 | 16.8 / 21.7 | 4-0 / 4-0 |
| gallhorn | 18.1 / 15.1 | 14.9 / 16.9 | 212.1 / 164.6 | 16.8 / 20.8 | 3-1 / 3-1 |
| bellcap | 12.9 / 10.1 | 13.0 / 12.2 | 12.3 / 24.4 | 15.8 / 16.0 | 4-0 / 4-0 |
| thornmaw | 21.5 / 19.5 | 12.7 / 12.3 | 148.5 / 111.1 | 15.1 / 16.2 | 4-0 / 4-0 |
| willow | 11.1 / 6.4 | 13.8 / 15.2 | 182.7 / 39.8 | 21.4 / 27.9 | 3-1 / 3-0 |
| orchid | 14.4 / 12.0 | 12.9 / 12.8 | 17.4 / 15.9 | 17.3 / 18.8 | 4-0 / 4-0 |
| colossus | 10.6 / 10.7 | 13.4 / 12.0 | 307.2 / 244.9 | 16.2 / 15.5 | 2-2 / 2-2 |
| wasp | 22.3 / 18.2 | 7.9 / 9.5 | 92.5 / 54.8 | 13.3 / 14.2 | 4-0 / 4-0 |
| broodmother | 15.9 / 3.9 | 22.3 / 22.4 | 26.4 / 32.5 | 26.7 / 27.7 | 4-0 / 4-0 |
| root_shepherd | 13.3 / 7.0 | 15.1 / 14.1 | 40.6 / 18.3 | 19.2 / 21.4 | 4-0 / 4-0 |
| hollowback | 12.8 / 8.1 | 19.6 / 18.9 | 213.9 / 175.5 | 20.0 / 26.3 | 3-1 / 2-2 |
| lantern_lure | 12.8 / 10.8 | 11.7 / 12.5 | 22.7 / 37.0 | 16.5 / 19.9 | 4-0 / 4-0 |
| seamroot | 15.9 / 13.5 | 15.9 / 15.5 | 10.6 / 8.9 | 18.3 / 21.9 | 4-0 / 4-0 |
| spore_widow | 15.0 / 11.9 | 13.6 / 14.1 | 61.3 / 63.5 | 24.2 / 21.0 | 3-0 / 4-0 |
| pallbearer | 3.2 / 7.2 | 14.3 / 17.4 | 0.0 / 17.0 | 19.6 / 22.9 | 4-0 / 4-0 |
| graft_thief | 13.8 / 8.5 | 12.0 / 12.5 | 56.3 / 15.1 | 23.2 / 23.8 | 3-0 / 3-0 |
| ashen_hart | 11.0 / 14.8 | 13.6 / 12.4 | 106.6 / 249.3 | 31.1 / 16.4 | 1-1 / 2-2 |
| glasscap | 13.3 / 12.7 | 15.3 / 13.5 | 57.8 / 71.1 | 22.3 / 18.4 | 4-0 / 4-0 |
| root_choir | 11.0 / 9.0 | 15.2 / 12.3 | 125.5 / 211.5 | 18.4 / 17.5 | 3-1 / 2-2 |

- Legacy: 80 rounds, 69 cleared, 7 lost, 90.7 party damage per minute, 19.2 s per round
- Scripted: 80 rounds, 69 cleared, 9 lost, 76.9 party damage per minute, 20.3 s per round


**Overall:** the two brains are close. Both cleared 69 of 80 rounds; scripted enemies wiped the party 9 times and the game's AI 7 times. The scripted brain deals 85% of the legacy damage per minute and starts about 15% fewer wind-ups, mostly from its decision cadence and minimum holds. With 4 rounds per species, single-roster damage swings widely between runs, so only consistent gaps are acted on.

**Intended differences:**

- Casters cast less: mana (Phase 4) limits them to four casts before channeling or retreating. This accounts for Willow, Nightbloom, Root Shepherd and the other casters; Willows were seen channeling and waiting for mana.
- The Broodmother stops casting once its two hatchlings are out; the game's version keeps casting with nothing to hatch.
- The Pallbearer tethers more often, and the Graft Thief's grabs stay with the game.

**Kept as baseline differences:** the lower overall wind-up rate. The scripted brain is the baseline and the net learns its own timing in Phase 6, so it is not tuned further here.

## Phase 4 record

### Part 1: mana, channeling and dodging

Built 2026-11-21. `mob_sim/mob_actions.gd` owns both mechanics. MobRules calls it when a committed behaviour changes, so nothing is visited per tick.

| Mechanic | Rules |
|---|---|
| Mana | The 11 caster species have a pool of 100. Each kit's basic cast costs 25 and its signature and counter 35, so four casts empty the pool. A wind-up spends the cost when it starts, and an attack the mob cannot afford is masked |
| Channel | A new behaviour at the end of the contract, so existing ids keep their values. It is legal for a caster below full mana. The mob holds still for at least a second, refills at its species rate (15 to 25 per second) and takes 1.5 times the damage. Changing behaviour ends it. The refill is settled lazily, when the mob decides or changes behaviour |
| Dodge | Now available to Thornmaw, Wicker Wasp and Graft Thief. It sidesteps across the nearest known threat, or straight away if both sides are blocked, then ignores hits for 220 to 260 ms. Cooldowns are 3.5 to 4.5 seconds. Dodging cuts through the current behaviour's hold but not a wind-up, and is illegal while stunned or rooted. The next decision comes when the dodge ends |

The scripted brain, in GDScript and natively, dodges within 12 ticks of being hurt. A caster that runs low (below its dearest cast) channels if no visible player is within 7 units, and flees first if one is. A caster that knows of no player channels until full.

In the arena the game resolves hits before the simulation sees them, so the bridge applies both mechanics afterwards. A dodge restores a hit the mob survived. A channel adds its extra damage but never takes the last point of health, so the game's own death handling always runs. A lethal hit during a dodge still kills; avoiding it needs a hook in the game's hit code, which waits for Phase 7.

The contract now has 15 behaviours, so the observation grows from 555 to 563 values and the policy from 274,032 to 274,537 parameters. The mana and dodge inputs stay masked until schema v2 in Phase 6.

Checks: `mob_sim/tests/mob_action_checks.gd` (31 checks). Native and reference masks and scripted choices still match in the parity test. A new arena check saw casters spend mana and channel (252 channel ticks) and agile mobs dodge real hits (19 dodges). Speed stays above target: 415x real time at 20 mobs and 101x at 100.

### Part 2: flying

Built 2026-11-22. The Orchid and the Wicker Wasp fly.

| Rule | How |
|---|---|
| Where flyers go | Anywhere a walker can, and also over water and low obstacles. Only tall cover (the cover that stops shots), the arena edge and barriers stop them |
| Movement | The native core bakes a second grid, the air layer, from `NavWorld.air_mask`. Each agent has a layer. Flyers route, step and dash on the air grid but stay in the shared crowd, so neighbour queries, ally sensing and alerts still find them. Flyers and walkers do not push each other. The air layer's route fields are only updated while something flies |
| Sight | Every mob's sight now uses the air grid: it crosses water and low obstacles, and only tall cover blocks it, matching the game's combat sight. Before, the walking grid made water block sight. Cover search and ranged-attack sight follow the same rule. A rock walkers can step over but that stops shots no longer blocks sight |
| Roots | Flyers cannot be rooted, in the simulation and in the arena |
| Hits | Stay 2.5D: players hit flyers as before. A flyer over water is out of melee reach |

The air grid is built per piece of cover, so it costs about 14 ms on a real arena map, once per round (the walking grid takes about 60 ms). Ground hazards and player fields are Part 4; they will skip flyers there.

Checks: `mob_sim/tests/mob_layer_checks.gd` (15 checks) and new native tests (a moat that walkers cannot cross and flyers can, with barriers still stopping a flyer's dash). Parity, the neural net's wall-clip audit and every earlier suite pass. A new arena check saw flyers fight real players for 12,810 mob-ticks with 8 attacks, never rooted and never outside the air layer. Speed: 416x real time at 20 mobs and 148x at 100.

### Part 3: darkness in the arena

Built 2026-11-22. The arena setup screen and `--darkness=day|dusk|night` choose a round's light: ambient 1.0, 0.4 or 0.08. Day is the default and changes nothing. Darkness applies only to framework enemies; the current game AI ignores it.

| Piece | How |
|---|---|
| Light sources | Every living player carries a light of radius 5.5. Glowing species give off their own: the Lantern Lure 5, the Nightbloom 2.5 and the Glasscap 2, from a new `glow` trait. `neural_arena/arena_light.gd` republishes them every 6 ticks, snapped to half a unit, so the light grid is rebuilt only when something moved |
| Mobs | `MobSim.set_darkness` turns the senses from Phase 2 on: mobs see players in light, within darkvision, or through hearing and smell. Since players carry lights, mobs still spot players in range; the dark helps mobs more than players |
| Players | One rule, `MobPerception.player_sees`: a player sees a mob within 18 units on a clear sight line, if the mob is lit or within 2.5 units. The arena's bots and the host's view both use it |
| Hiding | `hide` is legal only while darkness is on. Its executor (native and reference) reuses the cover search, and also accepts a dark point farther than 2.5 units from the target. The scripted brain does not hide, so hiding is left to the net to learn |
| Bots | At night a bot targets only enemies it sees, goes to where it last saw one for 4 seconds, then roams between spawn points. In daylight bots are unchanged |
| View | On the host, the sky, sun and ambient light dim (never below 18%), lights follow players and glowing enemies, and in Play mode enemies the local player cannot see are hidden. Watch mode shows every enemy, since the viewer is a spectator |

Limits: guests in a multiplayer arena see every enemy and no darkness until darkness is replicated (Phase 7). The live game's fog of war is adapted in Phase 7 with the live toggle.

Checks: `mob_sim/tests/mob_darkness_checks.gd` (15 checks), including native and reference hiding choosing the same spot and masks agreeing at night. A new arena check runs a night round: senses on, hiding legal, players lose and regain enemies (6,987 unseen and 11,083 seen player-enemy pairs over 1,800 ticks), the Lantern Lure's lantern is published, and the view hides exactly the enemies the local player cannot see. Night rounds with the same roster still clear, taking 14.4 seconds on average against 11.8 in daylight, and the multiplayer check passes. Darkness costs nothing measurable: enemies take 0.36 ms per tick at night against 0.37 in daylight.

### Part 4: hazards and player fields

Built 2026-11-22. `mob_sim/mob_fields.gd` keeps every timed ground area in flat arrays: hazards mobs leave for players, and fields players leave for mobs. Each entry has a centre, radius, start and end tick, owner and a ground flag, so the schema v2 inputs (nearest areas, time to impact, standing inside) can read them cheaply in Phase 6.

| Source | How |
|---|---|
| Training | Mob hazards register themselves when MobAbilities places them. `MobSim.add_player_field` places player fields that burn (damage per second through `damage_mob`), slow and root the mobs inside, four times a second. Ground fields do not touch flyers. Training scenarios will use it for the stand-in party's skills in Phase 6 |
| Neural Arena | `neural_arena/arena_fields.gd` publishes the game's enemy hazards and the players' fields (fire and void fields, gravity wells, thorn lines, read from the game's own warning hints) every 6 ticks. The game keeps applying their effects; the simulation never applies host areas twice |

Limits: the arena's characters carry no affinity cores, so arena bots make no player fields yet, and only enemy hazards appear there. Flyers in the arena still take the game's own ground-field effects (Burning, slows), since those are applied in the game's hit code; immunity there needs the Phase 7 hook, as does a dodge that avoids a lethal hit.

Checks: `mob_sim/tests/mob_field_checks.gd` (15 checks): burning, slows and roots, flyers passing over ground fields, expiry, nearest areas, host publishing, and mob hazards registering in a training run. A new arena check sees enemy hazards reach the registry (9,536 hazard-ticks against the game's 9,651; the gap is the publish interval). Speed stays above target: 400x real time at 20 mobs and 144x at 100; the registry adds about 0.001 ms per tick.

### Phase 4 summary

All four parts are in: mana with channeling, dodging, flying with sight over water, darkness in the arena, and hazards and player fields. New behaviours: `channel` (new) and `dodge` and `hide` (now legal). The net's inputs for these mechanics stay masked until schema v2 in Phase 6.

## Phase 5 record

Decisions (2026-11-22): work in the order speed, presentation, elites. Guests see the new mechanics in Phase 5 through an arena-only packet that leaves the game's packets unchanged. With a framework brain, the gate elite becomes a framework leader mob using its kit with elite bonuses; "Current game AI" keeps the scripted elite for comparison.

### Part A: arena speed

Built 2026-11-22. A profile of the headless arena (4 bots, 20 enemies) found the time per tick:

| Where | Before | After | Change |
|---|---|---|---|
| Enemy movement in the simulation | 0.12 ms | 0.02 to 0.04 ms | Lazy route fields (below) |
| Bridge copying enemy state | 0.13 ms | about 0.07 ms | Unlock bits cached by species, floor and evidence; the game's speed per species computed once per tick |
| Guest snapshot in a run without guests | 0.03 ms | 0 | Skipped in headless runs that have no guests |
| Bots | 0.31 ms | 0.21 ms | Targets chosen every 6 ticks and kept while alive and seen; routes reused while the goal stays within 1.5 units, for up to 30 ticks |

**Lazy route fields** (`mn_set_lazy_fields`, on in MobLocomotion): a route field is solved only while a mob of its layer seeks or flees with it, and the solve stops 6 units past the farthest such mob. It is solved again when one nears that edge. Flyers had doubled movement cost by re-solving every air field each tick; now an air field is solved only for flyers that use it. Off by default in the core, so `mn_path_cost` stays exact for tools and tests. Native tests show agents move identically on lazy and full fields.

Arena speed in the bench: scripted enemies 12.0x to 14.8x real time, neural enemies 11.3x to 13.5x. The rest of the tick is the game's own combat step, most of it player movement against the terrain (0.24 ms), which is real gameplay and stays. The 40x target is not reachable from the arena side alone; the simulation-only environment (400x at 20 mobs, 141x at 100) remains the main training path.

Bot behaviour changed slightly (target switching up to 100 ms later), so arena results are not bit-identical to before. All arena checks, the multiplayer check and the affected game suites pass.

### Part B: presentation of the new mechanics

Built 2026-11-22. `neural_arena/arena_presentation.gd` draws the framework's mechanics over the game's own enemy models, on the host and on guests:

| Mechanic | On screen |
|---|---|
| Flying | The model hovers 1.1 units up with a slight bob. The stage resets the model's height every frame, so the hover never accumulates |
| Channeling | The enemy's core glows a pulsing blue |
| Dodging | A white flash for the dodge window |
| Mana | A thin blue bar above each caster, scaled to its mana |
| Darkness | As in Phase 4 part 3; the darkness view now takes its inputs explicitly, so the same code serves guests |

Darkness is applied first, so effects and mana bars are never drawn for an enemy the viewer cannot see.

**Guests.** The host captures a small state per enemy slot (flags for flying, channeling, dodging, glowing, mana and seen, plus a mana byte) and sends each guest its own copy every 6 ticks through `receive_arena_presentation`, an arena-only unreliable RPC on the arena world. Each guest's copy carries that guest's own seen bits, so guests now see darkness and hidden enemies too. The packet is versioned (4-byte header, 2 bytes per slot) and a guest refuses a packet of another version or size. The game's own packets are unchanged.

Checks: a new arena check covers the packet round trip, refusal of bad packets, and hover, the channel glow and mana bars on the host's models. The multiplayer check now requires the guest to receive presentation packets showing a flyer and a caster's mana (80 packets in a 8-second run). Headed screenshots of day and dusk rounds show hovering wasps, mana bars and the player's light.

### Part C: elite kits and the framework-run gate elite

Built 2026-11-22. An elite is its species' kit with the elite size bonuses the data already defines (wider sweeps, larger radii), plus its signature: always in training, and from floor 3 in the arena, as in the game.

**Gate elite in the arena.** With a framework brain chosen, the simulation's last slot is the gate elite, spawned with the leader and elite flags. The game keeps the elite as encounter member -1, with a scout-shaped body (`elite_enemy.gd` `state`) and its position, wind-up and timers on `game.tactics`. The bridge gains a small set of lookups (`actor`, `actor_alive`, `actor_token`, `game_slot`) that return the elite's body for its slot, kept in step with the tactics once per game tick. So the arena's ability code locks, releases, hits, summons and pulses for the elite through the same path as for scouts. After each lock and release, `after_lock` and `after_release` copy the attack onto the tactics, as the game's own elite code does. The elite locks without a scout observation, and its attack is claimed directly, again as the game does. While the framework runs the elite, the game's leader code rests; bosses and the Heart's Briar still use it.

Also covered: the elite chases 8% faster than its species, as in the game; a Graft Thief or Glasscap elite runs the game's own grab, escape and feint like the scouts of those species; hits on the elite are credited to the right player; dodge and channel defences apply to it; its model hovers, glows, shows mana and hides in darkness through the presentation layer (the stage's `foe` model); and bots at night target it only when they see it. "Current game AI" keeps the scripted elite for comparison.

Checks: a new arena check runs a Gallhorn gate elite with a Rootbound-only roster. The elite is a leader-flagged elite mob with its signature, the simulation moves it, it winds up and releases both its basic charge and its signature angled charge through the game, and the party kills it through the game's own death handling. A simulation check shows an elite Rootbound's sweep is wider (2.49 against 2.25 radians). Every suite, the multiplayer check and the affected game suites pass. The arena bench is unchanged within noise (scripted 14.0x).

### Phase 5 summary

All three parts are in: the arena runs faster (lazy route fields and arena-side savings), the new mechanics are drawn on the host and replicated to guests, and the gate elite runs on the framework with its elite kit. Bosses keep their scripted plans. Phase 3 part 4, the comparison with legacy enemies, was done afterwards (see the Phase 3 record).

## Phase 6 record

Decisions (2026-11-22): build in the order schema v2, rewards v2, stand-in party, training loop, curriculum and evaluation. Godot workers and the Python trainer exchange files. Train in the simulation against stand-in players until the enemies reliably beat them, then self-play: a learned player net against the mob net, with opponents drawn from a pool of past checkpoints and some scripted stand-ins kept in the mix. Training must be easy to start and stop, resume after pauses and reboots, and survive power loss without corrupting data. Long runs are started by the user, not during development; this phase ends with a short proof run and a time estimate.

### Part A: schema v2

Built 2026-11-22. `ai/schema.json` is version 2. Every input that the framework now has data for is live; the observation grows from 563 to 568 values and the policy has 275,177 parameters. A model trained on version 1 cannot be loaded (none exists).

| Inputs | Source |
|---|---|
| Own traits: flight speed, armour, evasion, hearing, smell and darkvision ranges, can dodge, uses mana, glow radius | Species traits and the mob's armour |
| Own state: mana fraction, dodge cooldown, channeling, dodging, light level where it stands, flying, damage over time | The pool and the light grid |
| The two nearest ground areas: position, radius, time until active, whether it harms this mob, whether the mob stands in it | The field registry (`MobFields`); ground areas do not harm flyers |
| Each player: melee and ranged damage and reach, speed, attacks per second, armour, dodge cooldown, winding up, dodging, light level | `MobParty.set_stats` and `set_timers`, published by the host. Wind-ups and dodges show only while the player is in sight |
| Critic only: the objective, the share of supports spawned this episode still alive | The pool's support count |

Still masked, because nothing supplies them yet: the party profile, player resistances, and player buffs and debuffs.

Both builders changed together: `native/mob_obs.c` (which now reads the light grid directly) and `ai/mob_observation_builder.gd`. Nearest areas are chosen by edge distance in single precision on both sides. Cover sight now uses the sight grid, matching perception. The arena publishes each player's weapon damage, reach and attack rate once a second; dodge and wind-up timers are not published there yet.

Checks: the native and GDScript observations agree to within 1e-7 over 6,552 rows by day and 9,687 rows at night with player stats and changing timers. Every suite, the arena checks, the multiplayer check and the bench pass.

### Part B: rewards v2

Built 2026-11-22. `ai/mob_rewards.gd` turns each tick's events into rewards per mob, with the weights in `ai/training/rewards.json`. The trainer calls `tick()` after every simulation tick and `take(slot)` at each of a mob's decisions. Shipped mobs never compute rewards.

| Term | Weight |
|---|---|
| Damage dealt | +1.0 per health bar of the player hit |
| Healing done | +0.6 per health bar of the mob healed (a new `HEALED` event, pushed by corpse tethers) |
| Player downed | +3.0 for every mob that hit the player in the last 5 seconds |
| First sight of the party (added in Part D) | +0.2 once per mob life, the first time it sees any player |
| Sight of the current target | +0.01 per second, at most 0.005 between decisions, so standing in the open pays little |
| A support ally alive and casting | +0.02 per second to the support's allies |
| Own health lost | -0.3 per health bar of its own |
| Support lost | -1.0 times the support's value, to its allies |
| Own death | -0.15 times its value (1, or 3 for elites and leaders) |
| Party wipe | +5.0 to every mob alive |
| Intent change | -0.002 |

Squad mix: a share of every reward goes to the mob's allies; the share starts at 20% and the trainer moves it to 60% as training progresses, so mobs learn to value their squad's success. Checks: `ai/tests/mob_reward_checks.gd` (13 checks) covers every term and the squad mix.

### Part C: the stand-in party

Built 2026-11-22. `ai/stand_in_party.gd` is the party mobs train against in the simulation. It stands in for the game: the simulation resolves its own hits, the party reads the resulting hit events, and it deals damage through `MobSim.damage_mob`.

| Class | Role | Notes |
|---|---|---|
| Warrior | Melee | High armour |
| Rogue | Melee | Fast attacks, short dodge cooldown |
| Ranger | Ranged | Kites |
| Mage | Ranged, splash | Drops a fire field every 8 seconds |
| Warden | Melee tank | Drops a binding (rooting) field every 10 seconds |

Every player publishes its stats and its dodge and wind-up timers to the simulation (the schema v2 inputs). Attacks have a short wind-up and make noise mobs can hear. Dodges give a quarter second of invulnerability on a class cooldown. Armour reduces damage, roots and pulls apply, and players go down at zero health. At night players carry lights and see only lit or nearby mobs, by the arena's rule.

A shared difficulty from 0 to 1 sets the tactics: reaction delay (0.4 to 0.1 seconds) and chance (20% to 90%) for dodging telegraphs aimed at the player, focus fire on wounded mobs and, increasingly, on supports, ranged kiting and backing away from melee mobs, aim (35% to 5% misses) and retreating when badly hurt.

Speed: the game's pathfinder was nearly all the party's cost, so players walk straight when the way is clear and reuse a routed waypoint for up to a second. A fight of eight mobs against four players runs at about 245 times real time (party about 0.05 ms per tick, simulation about 0.02 ms).

Checks: `ai/tests/stand_in_party_checks.gd` (11 checks): stats and timers reach the simulation, armour, dodges, going down, darkness, class skills leaving player fields, and, over three seeds, a harder party dodging more (14 against 4) and taking less damage per kill.

Found for Part D: mobs that spawn far from the party wander until they notice it, so the party picks them off one group at a time. The training environment should start encounters engaged, as arena rounds do. (Part D starts most episodes engaged but keeps exploration starts, by request, so mobs also learn to find the party.)

### Part D: the training loop

Built 2026-11-22. Not started: the user starts and stops training.

**How it runs.** Godot workers play episodes in the simulation and write what every mob decided to rollout files. A Python trainer on the GPU reads them, runs recurrent PPO and publishes each new policy back to the workers. They talk only through files in a run folder (default `Documents\Godot\mob-training\run`, outside the repository).

| File | Purpose |
|---|---|
| `ai/training_brain.gd` | The neural brain for training: samples every head at temperature 1 and records each decision (observation, critic state, recurrent memory, legal options, choices, log-probability) |
| `ai/rollout_recorder.gd` | Groups decisions into mob lives, credits rewards, and writes checksummed shards atomically |
| `ai/training_env.gd` | One episode: a real floor, mobs at the game's health and damage, the stand-in party, the training brain |
| `ai/training_worker.gd` | The worker loop: hot-loads new policies, writes shards, waits when the trainer falls behind, stops on request |
| `ai/training/train.py` | Recurrent PPO with a centralised critic, checkpoints, metrics |
| `ai/training/rollouts.py`, `safe_files.py` | Shard reading, advantages and windows; atomic files and checkpoint fallback |
| `ai/training/training.json` | Worker count, episode mix and trainer settings |
| `ai/training/start_training.ps1`, `stop_training.ps1`, `training_status.ps1` | Control, with double-click `.cmd` launchers beside them |

**Episodes.** A random floor from 1 to 12, reused for 8 episodes. Mob health and hits come from the game's own formulas for that floor and party size (`enemy_balance.gd`), with a 15% chance of an elite leading the group and occasional mutations. The party has 1 to 4 players of random classes at a difficulty from 0.2 to 0.8, now on the game's health scale (75 to 130 health; a mob's hit takes about 10). A quarter of episodes are at night. An episode ends when the party is wiped or every mob is dead (terminal), or at its time limit (truncated, and bootstrapped).

**Learning to find players.** 30% of episodes are explore starts: mobs begin 25 to 45 m away in one to three groups, sensing nobody, while the party patrols a route of points that each have a clear line to the next. Every mob decides through the net even while it senses no one (the game hands those mobs to the scripted idle brain), and the first sight of a player earns +0.2. The other episodes start engaged, 9 to 16 m apart, and half of those also patrol. Search toward an unseen player goes to the remembered spot, so mobs get no hidden knowledge of where players are.

**Training.** Each update takes at least 65,536 decisions, computes advantages per mob life (GAE, gamma 0.995, lambda 0.95), and trains three epochs on 16-decision windows that start from the recorded recurrent memory, with masks applied exactly as the worker sampled. The squad share of rewards moves from 20% to 60% over the first 200 million decisions. Shards more than three policies old are dropped.

**Stopping and safety.** A `STOP` file (written by `stop_training.ps1`), Ctrl+C or closing the trainer's console makes the trainer save a checkpoint and the workers finish their episode. Every file is written to a temporary name, synced and renamed. Shards and checkpoints carry SHA-256 checksums: a damaged shard is rejected, and a damaged checkpoint falls back to the newest good one. Checkpoints are saved every 10 minutes (the last 5 kept), plus a milestone every 2 hours of training that is kept for later opponents. Policy versions only grow, so workers always pick up a resumed policy. Workers and trainer run hidden at below-normal priority, and the trainer keeps the computer from sleeping while it runs.

**Speed.** 12 workers produce about 17,000 decisions a second together (about 60 million an hour); an update of 68,000 decisions takes about 1.4 seconds on the GPU, so the workers set the pace and more workers would help overnight.

**Checks.**
- `ai/training/check_training.py` (19 checks): shard round trip and rejection when damaged or cut short, advantages for terminal and truncated lives, windows, masked log-probabilities, a full update, shard cleanup, metrics, checkpoint pruning and fallback, and version growth on resume.
- `ai/tests/training_checks.gd` (20 checks): explore starts keep mobs at least 20 m away and unseen, engaged starts within 17 m, game-scale health and hits, floor reuse, every life closed once, every recorded choice legal, terminal ends, and the shard checksum.
- `ai/tests/run_training_smoke.ps1`: start, refusal of a second start, shards, stop with a checkpoint, resume and stop again, in a throwaway folder.
- The trainer reports a replay gap: how far its log-probabilities are from those the workers recorded with the same weights. It measures 0.0 (under 5e-7), so Godot and PyTorch sample exactly the same distribution.

Also fixed on the way: the stand-in party stalled where the game's router slides a player a few centimetres at a time, so short steps now count, a player stuck for a second takes a short detour, and each step only refuses walls closer than 0.12 m. A replaced simulation stayed in memory through its handler port; the training environment cuts that link (the arena keeps one simulation per session, so it is unaffected).
