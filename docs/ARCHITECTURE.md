# Mystical Garden architecture

## Working baseline

The integrated baseline is `a4eed49680a99f8441312fc3870b54acfe7b2ccc`. Local `main` and the combat branch pointed at that commit before AR01. The terrain branch is in its history. The local `architecture/pre-ar01` tag marks the same verified version. AR02 starts from the tested AR01 graft extraction at `acf8f724a437a0330e349da9704ede2c9290c426`. AR03 starts from the card ledger at `83e67e255830e64bad72d33de2071d1636a3a483`. AR04 starts from the expedition wallet at `6212a30fed1ced6cc4e3adf603fdecbbc4bfd41a`. AR05 starts from the departure settlement extraction at `fddb1fc5cd63bac41361b9caefb513c2e497108a`. AR06 starts from monster reward receipt ownership at `a287458d884f929abd4f6f50fa0b10bf9917d18b`. AR07 starts from native cooldown ownership at `54b1c5b1a6a647139171b4cb9d0c2f2182fc0b85`.

[The title](../main_menu.gd) admits a player and selects the session mode. [The world scene](../world.tscn) instantiates [Game](../game.gd) and [Stage](../stage.gd). Game accepts inputs and RPCs and coordinates gameplay and saves. Stage presents the world. Several service scripts still use Game as their data store.

Once a replacement is verified and accepted, it becomes the sole active implementation. Remove the old switch, dispatch, runtime and tests that exercise only the retired behavior. Use named local Git tags before destructive cutovers. Keep tests for current contracts, including tests that previously drove those contracts through an older fixture. Historical releases remain recoverable from their protected tags. AR01 and AR02 establish separate owners for experimental graft and card purchases. AR03 uses one wallet for both live rulesets. AR04 gives disconnected participants a separate settlement owner on the guarded host. AR05 gives monster reward receipts a shared owner across both active rulesets. AR06 extracts shared native Q, R and dodge cooldowns. AR07 extracts player HP and capacity for both active rulesets. The shipped legacy mode still has live purchase callers and its cutover is a separate decision.

## State ownership

| State | Current owner and writers | Readers | Intended boundary and migration risk |
|---|---|---|---|
| Player registry, position, life flags, loadout | Host `Game.players`. Admission, movement, loadout, combat and departure/return mutate actor dictionaries. On a guest, the registry holds received projections. | Combat, travel, targeting, inventory, UI and snapshot builders | Give the host registry explicit admit, remove and actor update operations. Pass actor IDs or narrow views to other services. Preserve actor identity, disconnect settlement and guest prediction. |
| Player health | Each host actor holds an immutable `Health` value from `player_vitals.gd`. Damage, healing, loadout changes, revival and Vital grants use one value. | Combat and life systems, player snapshots, HUD, spectator and diagnostics | Project the effective capacity for guests. Keep damage revisions, fallen state and life-loss identity in their existing actor fields. Preserve rollback by replacing the value. |
| Native action cooldowns | Each host actor holds an immutable `Timers` value from `player_cooldowns.gd`. Game and native class effects replace it when actions start, refund or refresh deadlines. | Action admission, class effects, aim, HUD, player snapshots and diagnostics | Preserve host timing and use existing guest projections. Carry the immutable value through actor rollback. |
| Character and class progression | `CharacterProfile` serializes the profile. Host gameplay edits `player.character` through class/loadout commands and publishes guest progress through the existing projection and acknowledgement path. | `class_catalog.gd`, the five connected trees, `affinity_build.gd`, roster and profile serializers | Separate permanent progression commands and build inputs from in-run actor state. Preserve profile IDs, selected nodes and XP scale. |
| Expedition lifecycle | Game owns floor identity, deepest cleared floor, readiness and world drops. `party_travel.gd` and `expedition_life.gd` still read and write Game fields. | Gate, reward settlement, upgrades, player HUD and SaveBatch | An expedition owner should expose floor, settle and end operations and scoped inventory. Preserve per-party versus per-player rewards, floor cadence and guarded rollback. |
| Expedition wallet | `Wallet` in `expedition_wallet.gd` owns each actor’s earned sparks and spent Essence. Game and monster reward settlement install accepted successors. Game supplies the shared floor milestone. | Legacy purchase flow, affinity rerolls, player HUD and network snapshots | Keep balances derived from one player wallet and the existing floor progression. The monster reward owner retains the separate XP and loot awards. |
| Monster reward receipts | `MonsterRewards` owns frozen awards, delivery and settlement state by encounter epoch and spawn token. Game supplies eligible recipients, deterministic roll callbacks and verified transaction outcomes. | Enemy death handling, wallet credit, profile settlement, guarded departure and encounter reset | Preserve immediate run payouts and checkpoint profile credit as separate operations on the same receipt. Preserve deduplication through rollback and cleanup. |
| Guarded departure settlement | `DepartureSettlement` in `departure_settlement.gd` owns detached settlement records and reconnect holds. Game registers, stages and finalizes them through the existing guarded save route. | Reconnect admission, kill rewards, safe-pouch recovery, Garden return and host exit | Preserve peer and character identity together. Keep frozen kill receipts and the durable save verdict separate from the detached payload. |
| Cumulative graft acquisitions | `ExpeditionGrafts.Ledger` owns the ordered receipts of one actor's run. Game installs the next ledger and debits the selected trophy. | Altar, affinity build resolution, native graft attack capture, local Tab/HUD and owner-only guest details | Keep the ledger as the sole receipt source. Separate it from temporary proc counters in `native_graft_state`, whose lifetimes include fall and floor changes. |
| Upgrade cards | `Ledger` in `affinity_card_ledger.gd` owns each actor’s current affinity offer, completed checkpoint and acquired copies. Game installs a successor and applies its approved cost. Legacy selection uses `run_upgrade_catalog.gd` and `run_upgrades`. | Checkpoint UI, weapon/ability resolution, graft previews and owner-only snapshots | Keep receipt storage in the ledger and active effects derived from the current build. Game still coordinates wallet debits and owns offer revision allocation and checkpoint readiness. |
| Enemies and encounter state | Game owns leader fields, `scouts`, hazards and combat epoch. Encounter generation, direction, behavior and combat handlers mutate them. `battlefield.gd` and `wilds_play_surface.gd` resolve floor and terrain queries. | AI, hit testing, rewards, Stage and replicated state | Give the encounter a roster with a stable actor/spawn token and explicit query and damage operations. Migrate leader/scout identity carefully. Preserve TC01 movement, projectile and sight distinctions. |
| Combat resolution | Game resolves strikes, enemy damage and effect queues. `combat_action_events.gd` gives each action source and contact identity. `weapon_contact.gd`, class, graft and affinity handlers resolve effects and still access shared actors or enemies. | Simulation, reward settlement, presentation and snapshots | Provide source/target inputs and return combat outcomes. Keep direct hits separate from secondary effects and keep bounded queue, targeting and contact behavior. |
| Garden progression and experimental scene | `Progress` owns durable Garden data, with Heart, crops and reserves made available to Game commands. `experiment_garden.gd` owns the session layout and its projections. | Garden commands, inventory, Stage, guest details and the Garden serializer | Narrow Garden commands and publish scoped views without copying the full world. Preserve stable plot/item IDs, transaction semantics and the distinction between layout and serialized state. |
| Canonical persistence | `Progress` and `CharacterProfile` serialize. `game_transaction.gd`, `save_batch.gd` and `persistence_operations.gd` coordinate staging, rollback and publication. Guarded session admission owns leases. | Title, Garden commands, expedition settlement, recovery and guest projection | Prefer explicit participants and outcomes over full mutable-object snapshots. Preserve first-error handling, verified abort, uncertainty and cleanup pending as distinct outcomes. |
| Networking and session lifecycle | Game owns ENet and RPC entry points. `network_compatibility.gd` checks compatibility, and `world_snapshot.gd` encodes state. | Host command routes and guest views | Keep wire fields and NodePaths stable until a versioned migration. Guests are consumers of host projections. The host validates actor, activity and command revision before publishing a result. |

## AR01 graft ledger

[The ledger](../expedition_grafts.gd) has a run identity and typed receipt array. Each accepted purchase creates a successor, and the prior ledger can still serve as a rollback snapshot. The player dictionary holds one current ledger reference. Its earlier mutable dictionary and the whole-player copy used for previews are gone.

| Interface | Inputs and outputs | Consumers |
|---|---|---|
| `Ledger.new()`, `identity()` | Game assigns the host run serial at departure. Return, extraction and wipe remove the player attachment. Floor travel and revival preserve acquisitions. | Game lifecycle and native graft contact validation |
| `details()`, `resolution()` | Detached receipt details and derived bonuses/adaptations. Changing either result leaves the receipts intact. | `affinity_build.gd`, owner snapshot, local HUD and `run_summary_panel.gd` |
| `altar_view()`, `plan_purchase()` | Current floor, carried trophy counts, parsed request and an evaluator bound to a build and health inputs. A plan contains a successor, receipt and exact cost, or a refusal. The evaluator uses the live class cooldown, weapon and health formulas. | Game builds the altar projection and applies an admitted plan synchronously before sending feedback. |
| `request()`, `decode_request()` | Existing altar request fields and validation. | Altar UI, Game RPC route and co-op fixture |

The graft module went from 19 `game.` accesses and six methods accepting Game to zero of each. One raw dictionary accessor and one speculative whole-player copy path were retired. Previews now derive a bonus projection from the receipts. No second authoritative graft state was added. Guest data remains a projection and the guarded rollback reference is the prior ledger. Native ability and graft callers use the same run identity without accessing receipt storage. Game still owns admission, carried inventory and the synchronous publish boundary. Temporary adaptation counters and other actor fields remain shared.

## AR02 affinity card ledger

[The ledger](../affinity_card_ledger.gd) owns the host’s current offer, rerolls, completed checkpoint and acquired copies for one actor’s expedition. Game holds one current ledger reference. Successful transitions return a successor, so guarded rollback can retain the prior ledger. Floor travel preserves acquired copies. Expedition cleanup removes the attachment.

| Operation | Contract |
|---|---|
| `open_offer()`, `offer()` | Open a checkpoint with host-supplied floor, upgrade seed, revision and resolved stats. Reopening the same floor preserves the offer. Inspect a detached offer with its derived closed status. |
| `plan_choice()` | Validate the floor, revision, choice, eligibility, useful limit and available Essence. Return a successor for an accepted reroll, claim or skip, with an Essence cost for rerolls. Acquired copies preserve their rarity, contribution and acquisition identity. |
| `copies()`, `amount()`, `totals()`, `project_owned()`, `completed_floor()` | Query detached receipts, derived contributions or the last completed floor. Owned contributions come from receipts. The current equipment and effect caps determine active contributions for the Tab and guest views. |

Game keeps network and player admission, gate proximity, the revision sequence and party readiness. It installs the accepted card and wallet successors in the same synchronous command before sending feedback. Rejected choices and rerolls debit no Essence. The ledger’s checkpoint completion replaces the affinity writes to `player.last_offer` and stored offer closure flag. The guest still receives the existing completion projection. Game keeps `checkpoint_ready` for gate and party readiness.

The extracted state and projection code went from 37 `game.` accesses and seven Game parameters to zero. The mutable totals dictionary and writable offer and receipt accessors were removed. [The card adapter](../affinity_cards.gd) formats the picker with `checkpoint_view()` and connects the ledger to combat consumers. The existing Echoing Growth combat adapter still needs enemy, field and world data through three Game parameters and 12 `game.` accesses.

## AR03 expedition wallet

[The wallet](../expedition_wallet.gd) is the sole source for an actor’s earned sparks and spent Essence during an expedition. Each credit or accepted debit returns a successor. Guarded rollback can restore the prior reference with the actor snapshot. Game installs a fresh zero wallet when a run starts or the actor returns. Floor travel and revival preserve the wallet. The public balance is zero outside the Wilds.

| Operation | Contract |
|---|---|
| `credit_sparks()` | Add the sparks from an eligible kill reward. Existing monster reward receipts decide which awards can be applied and when. |
| `plan_debit()` | Check a requested Essence cost against the balance. Game installs the accepted debit with the card reroll or legacy purchase before publishing the result. |
| `balance()`, `projection()` | Resolve the balance from the shared cleared-floor milestone, sparks converted at the authored rate and spent Essence. Return detached values for readers. |

Game passes the deepest cleared floor and the current sparks-per-Essence rate explicitly. The wallet stores no second milestone or balance. Host snapshots keep sending the same derived wallet value to guests. Graft purchases still debit trophies. Monster reward receipts freeze Class XP, kill rolls and run drops. Game applies the detached awards. Guarded departure settlement has its own owner.

The old writable `essence_sparks` and `spent` fields are gone. `ExpeditionWallet.ESSENCE_PER_CLEARED_FLOOR` owns the room award and [the combat balance](../game_balance.gd) resolves the configured kill awards and conversion rate. Neither purchase ruleset has its own accounting.

## AR04 guarded departure settlement

[Departure settlement](../departure_settlement.gd) holds the detached payload for a guarded host’s disconnected participant. Game passes the peer and character identity separately from a snapshot of the character, projection base, Wilds state, safe-pouch and seed data, and Garden return identifiers. The owner's private copy has a different lifetime from the active actor. A disconnected participant loses the run wallet while their eligible profile progress and safe-pouch cargo await settlement.

| Operation | Contract |
|---|---|
| `register(peer_id, identity, snapshot)` | Register the peer and character with a private copy of the payload. The owner holds the character's reconnect admission while that departure is unresolved. |
| `stage(identities_waiting_on_rewards)` | Give the guarded save caller a detached batch. A departure waits while its matching profile rewards are deferred. |
| `finish(result)` | `COMMITTED` retires staged records. `CLEANUP_PENDING` retains an identity hold after commitment. `RESTORED` keeps the original record for retry after verified rollback. `UNCERTAIN` holds admission without replay. |
| `blocks_admission()`, `status()`, `count()`, `is_empty()`, `contains_peer()`, `has_wild_departure()`, `is_settling()` | Give admission and settlement callers narrow queries for identity and pending work. |

Game keeps session authorization, active actor removal, the final save verdict and effect publication. Game matches a frozen reward against the same peer and character identity for detached settlement, then records the updated profile, recovers the safe pouch and applies the disconnected Garden outcome in the same transaction. Normal extraction and a flush outside an active expedition settle remaining frozen kills before completing departures. A departure can be registered while saving is blocked. Stage and retry still require the existing safe guarded route. The owner operates in host memory with no direct access to Game, save files or networking. A restart uses the existing durable recovery path and cannot replay volatile departure records or kill receipts. The ordinary legacy disconnect route still uses its existing settlement.

AR04 replaced nine raw Game and reward-service accesses to the pending departure dictionary, excluding its declaration. It removed the dictionary and the full-actor alias that it kept. The owner holds authoritative records, including retry and reconnect state. Staged batches belong to the guarded save caller until the verdict. A verified rollback leaves the captured payload available for the next safe attempt.

Use `guarded_expedition` for detached ownership, deferred profile rewards, rollback and retry. `candidate_release_party` covers the disconnect publication boundary over real loopback, including recovery holds. `experimental_terrain_coop` exercises successful disconnect settlement and rejoin.

## AR05 monster reward receipts

[MonsterRewards](../monster_rewards.gd) owns one host-session record per encounter epoch and enemy spawn token. A record freezes each eligible player's class, peer ID and character identity with the rolled part, boss seed, Essence and Class XP. Summon exclusion uses the same receipt identity so it cannot generate rewards on a later death callback. Game supplies candidate eligibility facts and the existing roll callbacks. The owner has no access to actors, Game, save files or networking.

| Operation | Contract |
|---|---|
| `admit_kill()`, `take_run_awards()` | Admit a death once before rolling. Return detached run awards once for immediate experimental payout. |
| `stage_pending()` | Mark pending receipts as staged and return detached awards for the current settlement. |
| `pending_receipts()`, `pending_count()`, `pending_profile_ids()`, `status()` | Inspect frozen work, track blocked departure rewards and expose receipt phases without sharing mutable records. |
| `savepoint()`, `restore_savepoint()`, `finish_settlement()` | Register changes with the actual guarded and legacy transaction roots. Verified rollback restores work without rerolling. Committed and cleanup-pending results retain deduplication evidence. Uncertain work stays held and is not replayed. |
| `retire_completed()` | Release completed and excluded receipt IDs at the existing encounter boundary while preserving pending work, cleanup holds and uncertainty. |
| `defer_legacy_notices()`, `take_legacy_notices()` | Retain reward notices until the outer legacy transaction can publish them. |

[Game](../game.gd) applies run currency and physical drops, updates eligible live or detached profiles, and publishes the staged notices at the transaction boundary. Experimental play retains immediate run payouts and banks Class XP and familiarity at the existing checkpoints. Legacy keeps its established reward timing. Both paths use one frozen receipt. A peer ID without the matching character identity cannot inherit another player's credit.

AR05 retires three Game collections and sixteen raw accesses across Game and the previous reward utility. The reward owner has zero direct Game reads/writes. Expedition context, player admission, XP limits, party travel and save publication remain with Game and the established transaction services. No save-schema, protocol or packet-format changes are required. Multiplayer still checks matching build compatibility signatures. The receipt store lives in host memory. A host exit or crash before a verified checkpoint can lose uncommitted Class XP and monster familiarity. Expedition-only drops and Essence are lost with the run. The existing durable journal still reconciles any commit that was in flight.

Guarded transactions distinguish committed, cleanup-pending and uncertain outcomes. The ordinary legacy route still reports its existing Error result and blocks writes through the unresolved-journal gate.

Use `monster_rewards` for receipt identity, frozen awards and nested legacy rollback, `experimental_terrain` for immediate run payout and deferred permanent progress, `guarded_expedition` for checkpoint rollback and retry, and `candidate_release_party` for disconnect and recovery outcomes over loopback. `guarded_expedition_coop` and `four_players_coop` cover host-owned profile settlement and party payout.

## AR06 native action cooldowns

[Player cooldowns](../player_cooldowns.gd) owns a single immutable timer value on each host actor. It keeps three deadlines in milliseconds for native Q, R and dodge. Game initializes it on admission and replaces it with a ready value when the actor enters an expedition. Floor advance, falls, revival and Garden return preserve the deadlines. Leaving the session removes the actor and its timer. A new expedition resets all three deadlines. The existing guarded and legacy actor savepoints can restore the previous timer value because updates replace the value.

| Operation | Contract |
|---|---|
| `deadline()`, `ready()` | Read a native action's deadline or compare it with the caller's time. |
| `start()`, `refund()`, `ready_by()`, `with_deadline()` | Return a replacement value for a successful cast or dodge, a class refund or an explicit refresh. The caller supplies the resolved duration, reduction or deadline. |
| `skill_seconds()`, `skill_projection()` | Project native Q/R cooldowns in seconds with the existing readiness flags. The host uses these values for its HUD and snapshots. |

Game and the class effect modules replace the same actor value. Class definitions, connected nodes, cards and grafts continue to supply their existing resolved durations, reductions and floors. Host aim checks the deadline owner. Guest aim and HUD use host-projected readiness and remaining seconds, with dodge readiness in the existing owner details. The absolute deadlines stay on the host. Diagnostic deadline values are projections for observation. The save schema and packet formats stay the same. AR06 removed 53 old deadline-key references, including 26 in Game. The former keys have no runtime storage or mutation callers. The original Q and R names remain only in diagnostic projections and their sampling filter.

Core/B recovery, ordinary weapon attack cadence, animation and casting windows, status deadlines and enemy action timers keep their current ownership. Use `dual_skills` and the connected-class fixtures for native casts, refunds and dodge refreshes. Use `ability_aim`, `player_hud` and the existing snapshot and loopback checks for readiness presentation.

## AR07 player health

[Player vitals](../player_vitals.gd) owns current HP, resolved native maximum HP and temporary Vital capacity for each host actor. The effective maximum combines the two capacity values. Host actor admission installs one immutable health value. Damage, healing and changes in capacity replace it. The save transaction can restore an older actor dictionary and its prior health value without sharing mutable HP state.

| Operation | Contract |
|---|---|
| `hp()`, `native_max_hp()`, `temporary_hp()`, `max_hp()` | Read current HP or one of the three capacity values. |
| `with_capacity()`, `with_native_max_hp()`, `with_hp()` | Replace the chosen values and clamp current HP to the effective capacity. Capacity increases alone grant no healing. |
| `healed()`, `damaged()`, `refilled()` | Apply HP changes through replacement values. Damage keeps its existing whole-HP accounting. |
| `current_hp()`, `maximum_hp()` | Read the live host value or the guest's projected scalar fields for presentation. |

Game and the existing balance helpers resolve weapon, class, card, graft and expedition capacity inputs. The existing life-loss amount remains a separate actor field because revival eligibility, maximum HP and source-life checks rely on it. Fallen state, damage receipts and network revisions keep their existing owners.

Host snapshots project HP and effective maximum HP into the existing reliable and fast fields. The guest keeps that projected data and reconciles the two channels by the existing revision. HUD, party, spectator, stats and diagnostic readers use the same host value or guest projection. Damage flash still follows the existing damage sequence. The component stays out of packets and character saves.

This removes 37 raw player HP or capacity member accesses in Game, along with its two raw health fields and the separate Vitality bonus cache. Lifecycles still choose explicit refills where gameplay calls for them, including revival and Garden return. Legacy capacity-rank purchases retain their separate heal.

Use `combat_vitals_baseline` and the actual combat and support fixtures for capacity, damage and healing. Use `guarded_expedition` for rollback, `party_hud_gates_coop` and `diagnostics_coop` for host/guest presentation, and `network_presentation` and `world_snapshot_codec` for stale-frame precedence.

## Persistence modes and compatibility

| Mode | What actually happens |
|---|---|
| Isolated experimental playtesting | The source launcher gives the game disposable `APPDATA` and a matching marker. Retail playtest.7 uses a verified version-specific save root. These modes have no write access through the game to the normal player save set. They **do write** guarded Garden and character files, preferences and diagnostics inside their own roots. Legacy import and experimental Garden Continue are disabled. The generated Garden layout belongs to the host session. Graft receipts, cards and wallets are run-only. A refused root stops title admission. |
| Temporary persistence fixtures | The validation executor supplies separate throwaway profiles. Fixtures open, write, corrupt or inject faults only against controlled files. Tests of the candidate production route enable it through the headless validation hook. |
| Ordinary production route | The default remains legacy-contained. `persistence_writer_integration.gd` keeps production AC-06 cutover off. The guarded candidate and explicit recovery remain available to controlled fixtures. |

The original AC-06 split-commit bug was dropped serializer return codes. The legacy wrapper now records each required serializer's result before commit. The guarded path latches the first participating failure and protects canonical publication. `serializer_integrity` passed before and after AR01, including early serializer refusals. This verifies that failure path. Production cutover, any new migration and ambiguous historical journal handling still require their own verification. See [serializer integrity](AC06_STAGE_A1_SERIALIZER_INTEGRITY.md).

AR01 through AR07 need no save migration because the extracted state lives in the run or host session. Keep real historical profiles and Gardens intact. Before any future cutover, establish which real schemas must remain readable and preserve their originals. Where needed, convert those fields with a bounded, versioned migration and disposable fixtures. An obsolete experimental save set does not by itself justify retaining the old gameplay runtime.

## Where to change things

| Change | Start here |
|---|---|
| Card number, rarity range or offer balance | [`affinity_card_catalog.gd`](../affinity_card_catalog.gd) owns the affinity catalog. Search for the displayed title, such as `Honed Strikes` or `Light Grip`, and edit `values` in Common, Uncommon, Rare, Epic order. Unique entries use `fixed`. Read `unit`, `limit`, `parameter` and `consumer` in the same entry. `PLAYTEST` holds the acquisition limit, rarity curve and reroll prices. The ledger owns acquisition. `affinity_cards.gd` formats views and connects card effects to combat. `run_upgrade_catalog.gd` belongs to the existing legacy mode. |
| Expedition Essence and kill rewards | [`expedition_wallet.gd`](../expedition_wallet.gd) owns the fixed Essence award per cleared floor. [`game_balance.gd`](../game_balance.gd) resolves combat tuning for sparks per kill and sparks per Essence. [`monster_rewards.gd`](../monster_rewards.gd) owns kill receipt identity, frozen awards and settlement phases. `game.gd` applies awards and `game_transaction.gd` connects savepoints to actual save outcomes. Change card reroll prices in `affinity_card_catalog.gd`. |
| Guarded disconnect settlement and rejoin holds | [`departure_settlement.gd`](../departure_settlement.gd) owns the pending payload and reconnect hold. [`game.gd`](../game.gd) captures the payload in `_capture_pending_departure()` and translates the guarded persistence verdict in `_resolve_departure_settlement()`. |
| Class abilities, weapon stats and tree nodes | [`class_catalog.gd`](../class_catalog.gd) defines class/weapon baselines. [`skill_catalog.gd`](../skill_catalog.gd) and `subclass_catalog.gd` define the native actions and focuses. The `warden_connected_tree.gd`, `weaver_connected_tree.gd`, `ranger_connected_tree.gd`, `reaper_connected_tree.gd` and `oracle_connected_tree.gd` files define selections for each class. Find the named mechanic in the tree, then follow its handler when it has execution-specific tuning. |
| Player HP and capacity | [`player_vitals.gd`](../player_vitals.gd) owns live HP and capacity. [`combat_vitals.gd`](../combat_vitals.gd) and [`combat_balance_preview.gd`](../combat_balance_preview.gd) own HP units and capacity math. `expedition_life.gd` resolves life loss and revival. `vital_combat.gd` controls temporary Vital grants. |
| Native ability or dodge cooldown | Start with [`skill_catalog.gd`](../skill_catalog.gd) and [`class_skill_balance.gd`](../class_skill_balance.gd) for authored Q/R durations and the cast floor. Connected-class modules own their node-specific refunds. `game.gd` resolves dodge recovery with weapon, class and card contributions. [`player_cooldowns.gd`](../player_cooldowns.gd) owns timing and projection after those values resolve. |
| Plant families and materials | [`plant_affinities.gd`](../plant_affinities.gd) maps stable plant IDs to affinities. `seed_catalog.gd` and `weapon_parts.gd` own species and material identity. `combat_ruleset.gd` maps family names to their behavior scripts. In those scripts, find timing, geometry and potency constants for Core, Form and Catalyst. |
| Graft price, limit, reinforcement or adaptation | [`expedition_grafts.gd`](../expedition_grafts.gd) holds the definitions, trophy requirements, costs and caps. Reach values are hundredths of a metre and cooldown values are milliseconds. [`native_grafts.gd`](../native_grafts.gd) holds the trigger and timing data for native adaptation effects. It queues their execution through combat handlers. Check the author-facing description with any numerical change. |
| Enemy statistics versus enemy models | [`assets/enemies/catalog.json`](../assets/enemies/catalog.json) holds stable IDs, base stats, role and timing. `enemy_balance.gd` and `encounter_config.gd` apply runtime scaling and encounter rules. Stage loads `assets/enemies/<id>.glb` by ID. For example, inspect the `rootbound` row for the Rootbound Pilgrim and replace its visual at `assets/enemies/rootbound.glb`, preserving the rig and authored animation names. |
| Player, weapon or plant visuals | `traveller_avatar.gd` selects player rigs under `assets/characters/`. `weapon_visuals.gd` and `plant_weapon_models.gd` map weapon appearances to `assets/weapons/`. Garden crop meshes are currently authored procedurally in `stage.gd` (`build_crop` and `build_lineage_crop`). Crop inspection and icons belong to `garden_crop_view.gd` and the item catalog. |
| Terrain and effect visuals | [`terrain_feature_view.gd`](../assets/terrain_m02/terrain_feature_view.gd) maps vegetation and props to imported assets, including `assets/garden/field/`. `terrain_heart_preview.gd` uses `assets/terrain_m02/garden_heart.glb`. Use `core_skill_visuals.gd`, `status_feedback.gd` and `combat_feedback.gd` for effect presentation. Terrain collision belongs to `wilds_play_surface.gd` and feature geometry. Artistic replacement does not require tuning those rules unless the authored footprint itself changes. |

## Tests and next ownership changes

| Lane | Scope |
|---|---|
| Normal development | Run the focused domain fixture plus one real integration at the boundary being edited. For grafts, `cr05_native_grafts` checks the ledger, authoritative debit, caps, lifecycle and rollback. `ec01_affinity_cards` checks offer transitions, receipt isolation, eligibility, rarity, Essence and live card effects, including graft interactions. `ec01_affinity_cards_party` checks owner-visible offers and receipts, floor travel and cleanup over four-player loopback. Use the graft party fixture when changes affect shared combat or owner publication. |
| Legacy compatibility | Until retirement is accepted, scope legacy `grafting_menu`, `weighted_upgrades` and old Core roster behavior to the mode that still uses them. The old campaign ending fixture and its network counterpart are already archived under `docs/archives/legacy_endings/`; current tests can still assert the intentional disablement. |
| Extended verification | Keep four-player overflow, replay/rejoin, serializer fault matrices, snapshot byte budgets, broad affinity checks and source/package acceptance here. The two-player and party graft harnesses share substantial setup and assertions. Running both by default adds overlapping coverage. |

No suites were deleted in AR01. Existing fixtures use detached receipts and real commands, including the card fixture's graft setup. The baseline's roster, stats and dual-skill fixtures were repaired at `a4eed496` because their expected XP, stat label or spell event had aged out. Their original contracts were still valid. The planner uses explicit systems, literal resource links and exact scoped fragments of Game functions. Scoped wiring must match after earlier regions normalize. The cutover goal is to attach tests to an owner's files and real interfaces instead of maintaining many exact Game fragments.

Extract encounter actor identity and combat mutation next. Give target lookup, spawn identity and damage application clear interfaces while preserving frozen receipt identity and TC01 terrain rules. Move Garden and save coordination toward explicit participant commands in separate batches.

Once legacy checkpoint behavior has an independently verified replacement, retire the legacy picker and purchase routes (`checkpoint_offer_ids`, `choose_checkpoint_card` and `_buy_upgrade`) with their old rank state and legacy-only fixtures. Verify remaining consumers of `run_upgrade_catalog.gd` before retiring it.

## Contributing

1. Verify the branch, status and baseline. Follow the displayed name to the authored definition, then the stable ID to its readers and writers. Search existing `res://` references before changing a scene or model. Preserve unrelated work.
2. Keep one text definition for each gameplay value where possible. Prefer readable GDScript constants or JSON records with stable IDs and named units such as HP, milliseconds or metres. Let previews resolve the same numbers as gameplay. Keep visuals with their scene/model consumers and separate from balancing data. Preserve paths while extracting ownership and move assets when a specific owner can verify imports, rig and collision contracts.
3. Change the owner first and pass explicit inputs or detached results across the boundary. Add or update focused tests and `tools/test_map.json`, then regenerate [the coverage map](MECHANICS_TEST_MAP.md) if its source changed. Use `tools/validate_release.ps1 -PlanOnly` to inspect affected consumers. See [the validation workflow](VALIDATION_WORKFLOW.md) for isolated checks and release evidence.
4. Review a focused Git diff. Commit one understandable change with a descriptive message. Keep unrelated formatting, generated artifacts and local design references out of the commit. In the handoff, name the changed files, affected systems, verified cases and any remaining gap so another contributor can review or continue the work from Git.
