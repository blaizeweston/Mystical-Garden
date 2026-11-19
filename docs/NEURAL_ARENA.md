# Neural Arena

The Neural Arena is a separate session for testing, watching and fighting the mob neural net. It uses the real game's combat, classes, abilities, enemy models and stats. The normal game keeps its current enemy AI.

This page records what the arena changed in existing files, why, and which references must be updated when those files are refactored.

## Opening the arena

| Route | How |
|---|---|
| In the game | Press Esc, then choose **Neural Arena**. The button only appears when running from the project, because exported builds leave the `neural_arena` folder out |
| Headless | `neural_arena/tests/run_arena.ps1 -Arguments '--rounds=5','--bots=4','--enemies=rootbound:6,nightbloom:3','--brain=scripted'` |

Headless options are `--rounds`, `--bots`, `--enemies=id:count,id:count`, `--brain`, `--seed`, `--floor`, `--map=open`, `--round-seconds`, `--elite` and `--intelligence`.

`--brain` accepts `scripted`, or the path of a model file. Leaving it out uses the current game AI.

### Modes

| Choice | Options |
|---|---|
| Mode | **Watch** has AI players fight the mobs. **Play** puts you in the fight, with optional AI allies |
| Session | Solo, Host or Join. Multiplayer uses the normal co-op connection |
| Enemies | Any enemy types, up to 20 in total, plus an optional leader |
| Brain | Current game AI, scripted baseline, the untrained net, or any `.bin` checkpoint in `ai/checkpoints` |
| Speed | Watch: 0.25x to 16x. Solo Play: 0.25x to 1x. Multiplayer: 1x only |

Pause and single-step are on the arena's time bar. F2 opens the setup screen and the period key advances one step.

## What changed in existing files

Everything else lives in new folders: `neural_arena/`, `mob_sim/` and `ai/`, plus the new root file `combat_clock.gd`.

| File | Change | Why |
|---|---|---|
| `game.gd` | Added the `CombatClock` constant | Gives combat rules one replaceable time source |
| `game.gd` | 52 combat time reads now call `CombatClock.now()` | Pause, slow motion, fast-forward and repeatable fights all need combat time the arena can control |
| `game.gd` | Moved the three enemy update lines from `_physics_process` into a new `tick_enemies(delta, now)` | Gives the arena one function to replace, so it can run the bridge instead of the scripted scouts |
| `game.gd` | The original commit added the **Neural Arena** button in `build_hud`; the integration now mounts it through `GameplayUI.configure_arena_menu` | Requested entry point. It is hidden when the arena files are absent |
| 16 other scripts | 25 combat time reads now call `preload("res://combat_clock.gd").now()` | Same reason as above. The full list is below |
| `tools/test_map.json` | Registered the clock, `tick_enemies`, the button and the converted reads | Keeps the validation planner's code fingerprints accurate |
| `docs/MECHANICS_TEST_MAP.md` | Regenerated from the map | Generated file |
| `docs/ARCHITECTURE.md` | Added a short Neural Arena section | Points people refactoring combat code to this page |

### Effect on the normal game

`CombatClock.now()` returns `Time.get_ticks_msec()` unless the arena has switched it to fixed steps, so normal play reads the same clock as before. `tick_enemies` runs the same three lines in the same order.

### Reads that stay on the real clock

These five reads in `game.gd` are not combat rules, so they were left alone:

| Function | Purpose |
|---|---|
| `status` setter | Toast timing |
| `_ready` | Toast timing |
| `add_player` | `admit_peer` connection timing |
| `refresh_feedback` | Toast timing |
| `_process` | `EventAudio.sync` audio timing |

## References to update after refactors

### 1. Hooks in existing code

| If this changes | Update |
|---|---|
| `tick_enemies` is renamed, moved or split | The override in `arena_world.gd` |
| `LeaderBehavior.tick` or `ScoutBehavior.tick` signatures change | `tick_enemies` in `game.gd` and `arena_world.gd` |
| Gameplay menu presentation changes | `GameplayUI.configure_arena_menu`, its `arena_open`/`arena_setup` intentions, `Game._handle_ui_request`, and `ArenaWorld._handle_ui_request` |
| Arena menu options change | `_trim_session_menu` requests `ui.configure_arena_menu(false, true)`; do not restore removed Game control fields or inspect private UI children |
| `world.tscn` changes its root script or is renamed | `arena_entry.gd`, which applies `arena_world.gd` to that scene |

### 2. Combat clock reads

New combat rule code should call the clock rather than `Time.get_ticks_msec()`. If a function below moves, the read must move with it. If one is missed, that rule runs on real time and breaks pause and fast-forward in the arena.

| File | Functions (reads) |
|---|---|
| `game.gd` | `campaign_snapshot`, `use_class_skill`, `grant_guard`, `submit_motion`, `submit_movement`, `_physics_process`, `send_expedition_state`, `move_player` (3), `dodge_player`, `strike_enemy`, `finish_combat` (2), `_finish_combat` (3), `reset_encounter`, `combat_pose`, `player_snapshot` (7), `apply_world_snapshot`, `_process` (7), `record_enemy_death`, `death_events_snapshot`, `attack_animation_snapshot` (5), `emit_combat_event`, `publish_combat_event`, `combat_events_snapshot`, `attack_hints_snapshot` (4), `receive_details`, `receive_combat_event`, `guest_combat_events`, `submit_combat` |
| `ability_aim.gd` | `footprint` |
| `boss_encounters.gd` | `hints` |
| `class_ability_targeting.gd` | `growth_centers`, `plan` |
| `combat_status.gd` | `root` |
| `combat_traits.gd` | `decoy_point` |
| `core_combat.gd` | `command`, `hud_state` |
| `elite_enemy.gd` | `hints` |
| `enemy_attack.gd` | `lock` (2) |
| `enemy_skill_responses.gd` | `plan_canopy` |
| `expedition_life.gd` | `revive` |
| `expedition_pressure.gd` | `hints` |
| `expedition_transitions.gd` | `admit` |
| `game_transaction.gd` | `_run_legacy` |
| `mouse_combat.gd` | `frame` |
| `stage.gd` | `draw_state`, `animate_enemy` (5) |
| `weapon_contact.gd` | `secondary` (2) |

### 3. `game.gd` functions the arena overrides

`arena_world.gd` extends `game.gd`. A renamed function stops being overridden without any error, so check this list whenever one of these moves.

| Function | What the arena does |
|---|---|
| `_ready`, `_physics_process`, `_unhandled_key_input` | Runs the arena's session, fixed steps and input rules |
| `tick_enemies` | Runs the mob bridge |
| `apply_weapon_hit` | Credits hits to the attacking player, then runs the real hit |
| `move_player` | Lets a bot steer the host's body |
| `finish_combat` | Ends the round |
| `flush_kill_rewards`, `save_local_character`, `_queue_monster_reward` | Turns off rewards and saving |
| `tell`, `_act` | Hides bot messages and handles revives |
| `register_character` | Admits guests mid-round. Its `@rpc` annotation must match the parent |
| `request_main_menu`, `return_to_main_menu` | Leaves the arena safely |

### 4. Game state the arena reads or calls

| Owner | Members used |
|---|---|
| `game.gd` | `players`, `motions`, `combat_velocity`, `mouse_controls`, `HOST`, `status`, `spectator_view`, `closest_enemy`, `enemy_position`, `dodge_player`, `use_class_skill`, `revive_player`, `weapon_stats` |
| Encounter roster | `encounter.scout`, `scout_count`, `living_scout_count`, `alive`, `hp`, `set_hp`, `token`, `register_scout`, `clear_scouts` |
| `expedition_participation.gd` | `active`, `epoch`, `contains`, `seed`, `reset_run`, `enter`, `detach`, `detach_all`, `savepoint`, `restore_savepoint` |
| `network_session.gd` | `role`, `transport`, `binding`, `bind_character`, `start_join`, `release_peer`, `peer_for`, `ready_for`, `slot_for` |
| Life rules | `Life.alive`, `Life.nearest`, `Life.revive`, `Life.living_ids`, `Life.native_maximum`, `Life.Preview.strike_rng`, `Life.Preview.heal_rng` |
| `battlefield` | `spawn_points`, `leader`, plus the terrain data baked for the native pathfinder |
| Enemy rules | `Enemies.get_kind`, `Enemies.all`, `Director.spawn`, `Director.speed`, `Director.windup`, `Director.Balance`, `EncounterConfig.MAX_SCOUTS` |
| Save rules | `SaveBatch.active`, which makes game saves refuse to write while the arena runs. `game_transaction.gd` must keep running actions directly while it is set |

### 5. Files the arena loads directly

| Arena file | Existing files |
|---|---|
| `arena_world.gd` | `game.gd`, `expedition_grafts.gd`, `garden_return_service.gd` |
| `arena_entry.gd` | `world.tscn` |
| `arena_mob_bridge.gd` | `combat_clock.gd`, `enemy_catalog.gd`, `expedition_participation.gd`, `frost_combat.gd`, `network_session.gd`, `player_vitals.gd` |
| `arena_abilities.gd` | `combat_clock.gd`, `enemy_attack.gd` (`Attacks.lock`), `enemy_behaviors.gd`, `frost_combat.gd`, `player_lifecycle.gd`, `scout_behavior.gd` (`ScoutBehavior.release`) |
| `arena_characters.gd` | `character_profile.gd`, `class_catalog.gd` |
| `arena_mouse.gd` | `mouse_combat.gd` (extended) |
| `arena_hud.gd` | `root_ui.gd` |

### 6. Validation map entries

`tools/test_map.json` owns coverage; retained exact anchors live in `tools/validation_scope_matches.json`. Keep ownership and matching records aligned without rewriting historical baselines:

| Entry | Covers |
|---|---|
| `systems.combat.files` | `combat_clock.gd` and its `.uid` |
| `game_functions.tick_enemies` | Ownership of the new function |
| `systems.gameplay_ui` and `game_functions.configure_gameplay_ui` / `_handle_ui_request` | UI-owned Arena controls and authorized requests |
| `file_regions.<file>.regions.shared_combat_clock` | The converted reads in each of the 16 scripts |
| `game_regions`, text containing `CombatClock.now()` | The converted reads in `game.gd` |

Run `python tools/test_workflow.py document --project . --engine <godot>` after any map change.

## Removing the arena

1. Delete `neural_arena/`.
2. Remove its UI menu options and the authorized `arena_open` request. Keep other gameplay-menu coverage intact.
3. Keep `combat_clock.gd` and `tick_enemies` if the neural net is still planned, because the training loop needs both.

## Current limits

- The net is untrained, so its fights show the system working rather than good tactics. The training loop is not built yet.
- The gate elite stays on its scripted behaviour.
- Some species specials are not driven by the net yet.
- A round holds at most 20 enemies plus a leader.
- The arena button does not appear in exported builds.

## Checks

| Check | Command |
|---|---|
| Arena rules, time controls and menu button | `neural_arena/tests/run_arena.ps1 -Script res://neural_arena/tests/arena_checks.gd` |
| Two-process multiplayer | `neural_arena/tests/run_net_check.ps1` |
| Neural net runtime | `ai/tests/run_checks.ps1` |

All arena tests use their own temporary user data folder and never touch real saves.

### Original Neural Arena branch results on 2026-11-18

| Check | Result |
|---|---|
| Arena checks | 49 passed, 0 failed |
| Two-process multiplayer | Passed |
| Neural net runtime | 54 passed, 0 failed, plus the Godot and Python schema checks |
| Focused game validation | 133 of 145 suites passed, 12 failed |
| Connected game validation | Not run, because focused validation did not pass |

The same 12 suites fail on the unmodified commit `b1d1291` with the same failure messages, so the arena changes did not cause them:

`developer_garden`, `experimental_terrain`, `garden_growth`, `garden_returns`, `garden_spring`, `heart_growth_visual`, `heart_progression`, `inventory_party`, `production_persistence`, `regular_enemy_responses`, `serializer_integrity`, `tree_portraits`.

## Integrated owner/UI checkpoint

The 2026-11-18 integration retains the newer typed weapon, protection and hit-condition owners, whole-run forfeiture, explicit persistence-session state and complete UI feature ports. Moved combat reads use `CombatClock.now()`; toast, connection and audio timing stay on real time. The Arena prepares immutable owner values instead of retired raw actor timers. The world replacement waits for queued departure to finish, preserving the `MysticalGarden` RPC root. Arena entry describes the current whole-run forfeiture, including safe-pouch contents; courier deliveries remain protected.

Native compilation no longer assumes another contributor's absolute toolchain path. Run `mob_sim/native/build.ps1 -Zig <zig.exe> -Interface <header-directory>`, or pass the existing llvm-mingw `-Toolchain` option. Generate the header with Godot 4.7.2's `--dump-gdextension-interface` in an isolated SDK directory. CPU/OS AVX2 detection is explicit and no longer relies on a hidden libgcc runtime symbol; numerical kernels and FP flags are unchanged. Missing optional native binaries return an unavailable result rather than engine load errors.

Focused integration checks passed six owner/UI/forfeiture suites and a real matching host/guest pair. The source-built native core passed its checks, and the Arena passed all 49 checks, including all five classes, twenty regular species, real neural movement/damage, attacker limits, repeatability, time controls and save canaries. The disposable checkout needed its ignored native DLL and model artifacts generated first. The Arena check used an explicitly recorded deterministic NumPy-initialized untrained fixture; this is not training, PyTorch parity, separate-PC or internet evidence. The original failed runs remain archived. Production save activation remains off.

### Modern terrain integration

Normal play retains its real-time clock and scripted enemy path. `Battlefield` now supplies modern surfaces for generated, authored boss/Heart and practice floors. The native bake reads conservative occupancy from those footprints; the Arena player bot queries the same certified navigation graph. There is no separate old-floor generator to select for the Arena.

The integrated Arena passes all 49 functional checks. The independent host/guest check confirms guest class selection, movement, replicated enemies and enemy motion. An untrained agent may hold position, so that check observes all living slots within one floor identity rather than requiring the first agent to move. No policy or enemy behavior is changed to satisfy it. An earlier failing observation run remains in the evidence archive.

These checks use the source-built optional native DLL and the explicitly recorded temporary deterministic untrained model described above. They do not install those ignored fixture artifacts into the user's project, establish PyTorch parity, train a policy or verify internet play. A source checkout still needs its normal native/model build artifacts before using neural mode.
