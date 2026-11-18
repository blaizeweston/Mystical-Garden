# Mystical Garden architecture

## Working baseline

The integrated baseline is `a4eed49680a99f8441312fc3870b54acfe7b2ccc`. Local `main` and the combat branch pointed at that commit before AR01. The terrain branch is in its history. The local `architecture/pre-ar01` tag marks the same verified version. AR02 starts from the tested AR01 graft extraction at `acf8f724a437a0330e349da9704ede2c9290c426`. AR03 starts from the card ledger at `83e67e255830e64bad72d33de2071d1636a3a483`. AR04 starts from the expedition wallet at `6212a30fed1ced6cc4e3adf603fdecbbc4bfd41a`. AR05 starts from the departure settlement extraction at `fddb1fc5cd63bac41361b9caefb513c2e497108a`. AR06 starts from monster reward receipt ownership at `a287458d884f929abd4f6f50fa0b10bf9917d18b`. AR07 starts from native cooldown ownership at `54b1c5b1a6a647139171b4cb9d0c2f2182fc0b85`. AR08 starts from player health ownership at `72389e59066dcc3d63d09da5c4e35058e135cbf5`. AR09 starts from player lifecycle ownership at `956f8302d4dfcaea5210e1c355d8eb986fbe5b0e`. AR10 starts from encounter roster ownership at `92c920cbe97bd623f5baccf6021a578c8c40cf74`. AR11 starts from enemy tactics and behavior ownership at `383251986350fe8e3c809bcc8c94717b49022b97`. AR12 starts from ordinary enemy attack execution at `c0c147471530bd8358f770ecd17da2a2a961df67`. AR13 starts from incoming player hit resolution at `5fb00ae287120518d0b28493e510c9dbfb29b870`, preserved by the local `architecture/pre-ar13` recovery tag. AR14 starts from expedition participation ownership at `c436378fd86ec01674c9abb02284fb8ff8c122fd`, preserved by `architecture/pre-ar14`.

[The title](../main_menu.gd) admits a player and selects solo, host or join networking. [The world scene](../world.tscn) instantiates [Game](../game.gd) and [Stage](../stage.gd). Game accepts inputs and RPCs and coordinates gameplay and saves. Stage presents the world. Several service scripts still use Game as their data store.

The sole gameplay contract is now `modern-gameplay-1`: affinity-based Core/Form/Catalyst combat, free checkpoint cards, cumulative expedition grafts, and five connected class trees. There is no selectable historical gameplay fallback. `architecture/pre-modern-cutover` preserves the verified AR14 parent (`12c13c888621dd57e944088986b76bdbfad7cf41`). Git history and protected tags provide recovery.

## Modern gameplay cutover

| Retired execution | Authoritative replacement / retained data |
|---|---|
| Priced checkpoint ranks, legacy 166-card catalog, power/Technique counters, old cached offers and card event consumers | `affinity_card_catalog.gd` has the unchanged 28 definitions; `affinity_card_ledger.gd` owns offers and per-copy acquisitions. Game coordinates free choices and atomic Essence rerolls. |
| Installed fourth graft slot, replacement/success rolls, old graft panel and Rift Hook run combination | `expedition_grafts.gd` owns four reinforcements and six current adaptations; `native_grafts.gd` executes their scoped effects. All 24 monster material IDs and permanent Garden research/history remain. No additional adaptations are implied. |
| Species-selected Core skills, old Core cards/variants, generic Core Mark, Thorn Line adaptation dispatch | `plant_affinities.gd`, `affinity_build.gd` and nine family handlers resolve all 24 species / 48 materials. `core_skill_rules.gd` retains weapon delivery definitions; `core_combat.gd` executes the family contract. Reusable visuals remain separate. |
| Historical mask skill replacements, generic all-slot stat/tag effects, obsolete class action modes | Five connected-tree modules and their class handlers are the only executable class progression. Historical node order/IDs/prerequisites remain read-only conversion data in `class_catalog.gd`, `warden_tree.gd` and `subclass_catalog.gd`; their old effects are not applied. |
| Combat-mode launch switch and actor mode flag | `combat_ruleset.gd` always publishes the modern version plus definition signature. Terrain/save-root isolation remains independent. Old launcher arguments cannot select historical gameplay. |

Historical invested profiles remain readable without silently changing their selections. The approved explicit **Refund historical class choices** action at the Heart calls `Character.refund_historical_class()` inside the existing authorized profile transaction. It archives that class's original bits in `quarantine.learned_class_masks`, clears only its active mask/path, and records a version-1 `connected_class_migrations` marker. Earned Class XP is retained using `class_experience.gd`'s existing idempotent whole/fractional conversion. The current thresholds determine available connected selections; no extra points, new XP curve, or automatic focus is granted. Unconverted invested classes must refund before departing. Other classes' investments remain untouched. Invalid/unknown conversion versions require review.

The old actor fields `run_upgrades`, `checkpoint_offers`, `offer_floor`, `last_offer`, `power`, `technique`, `graft_part`, `graft_floor`, `graft_choice`, and `rift_hook` no longer own runtime state. Protocol-41 reliable projection keys reserved for retired fields remain inert empty/zero values; the fast snapshot layout is unchanged. The modern gameplay signature deliberately refuses older gameplay builds.

The modern HP scale is unconditional. The old mutable `CombatBalancePreview.enabled` gameplay switch and its old-heart branches are retired; `--combat-balance-preview` remains a **save-root isolation** argument only. Explicit-scale math in `combat_vitals.gd` still supports bounded data/unit conversion. Current damage, mitigation, healing, attack timing and enemy composition retain their former modern values. Seed/material descriptions now use explicit affinity identities rather than claiming old raw-tag passive bonuses.

Known modern enemy-learning gaps remain deliberately unexpanded: `AREA_PRESSURE` had a species-selected Ember Wake producer, but modern Fire has no authored production observation hook; shelter-break observations likewise came from the retired Core displacement path. Five volley/snare/artillery `CAST_DENIAL` responses (enemy kinds 1, 5, 6, 14 and 18) also have no current baseline interruption producer. Native interruption deliberately refuses those committed attacks. Their remaining fixtures distinguish supported native interruptions from recorded-observation consumer checks; they do not prove a live producer for the unsupported cases. Adding those producers requires an explicit AI/gameplay decision, rather than broadening native stagger or restoring Hush.

Inventory presentation also uses the current resolver: `Game.inventory_ui_data()` attaches a detached local view of the already-received `weapon_stats.affinity_build`; `inventory_panel.gd` calls `AffinityBuild.core_skill()` and `slot_preview()` for the Core label and all three slot descriptions. There is no `core_build` shim or species-description caller. The wire inventory and protocol-41 fast state are unchanged.

Historical **persistence** names such as `SaveBatch.Legacy`, `take_legacy_notices`, and contained serializer routes are not selectable old combat. They still protect live save transactions and issued guest-profile digests. Production AC-06 remains disabled. Uncommitted permanent rewards are held in host memory; a host process failure can lose work not yet settled. This cutover adds no durable journal and does not claim production persistence closure.


## Cutover measurements

Compared with the preserved AR14 parent (tracked runtime GDScript, excluding tests and tools):

| Measure | Before | After |
|---|---:|---:|
| Game lines / functions | 4,820 / 268 | 4,479 / 257 |
| Game plain top-level variables | 153 | 153 |
| Runtime GDScript lines | 56,057 | 51,753 |
| Actor combat-mode gates | 42 | 0 |
| Mutable health-mode reads | 78 | 0 |
| Retired runtime scripts | — | 10 |
| Retired gameplay-only fixtures | — | 26 |

Eleven Game purchase/install/support functions and ten mutable legacy actor fields are removed, rather than forwarded through a new service. No new state owner or parallel authority was added. Historical profile tables and inert wire keys are explicitly distinguished from executable gameplay; ordinary current owner operations remain. The card definitions and their effect consumer file are byte-for-byte unchanged from the parent; the five connected-tree definitions and family tuning remain unchanged.

## Cutover verification

Final focused verification passed 73 distinct fixtures: 58 units, one title-based solo smoke, 12 independent host/guest pairs, and two four-player controls including fifth-client refusal (93 fixture process exits). Current fixture hashes and strict per-peer verdicts were checked; original failed runs remain preserved. Coverage includes the five connected trees, all nine affinity families, all 28 real card consumers, current cumulative grafts, explicit historical refunds and XP conversion, TC01, inventory interaction, rewards, guarded rollback, floor travel, extraction, reconnect and guest-profile recovery. The card and four-player controls exercise actual integrated combat and owner projections. Recorded enemy-learning consumer checks remain distinct from the missing producers noted above.

The final inventory test opens the real panel, refreshes it, and inspects Core/Form/Catalyst equipment details. Modernized enemy fixtures respect current attack deadlines, participation reset refusal, and actual native Root Quake damage/displacement. These fixture corrections do not change combat tuning.

At cutover the planner had 214 suites. The later duplicate-mismatch retirement leaves 213 registered suites and preserves the definition-mismatch, matching-build and separate RPC-contract controls. The current structural audit has zero scope/unmapped-input warnings. The native-copy planner unit passed. This is local loopback, not separate-PC or internet verification; no release export or production save activation was performed. The existing approved playtest and six local design references are preserved.

## State ownership

| State | Current owner and writers | Readers | Intended boundary and migration risk |
|---|---|---|---|
| Player registry, position and loadout | Host `Game.players` owns admitted actor records, position and loadout. Actors hold a read-only participation Link; no mutable `wild` field remains on the host. Accepted guest snapshots bind links to the receiving participation projection. | Combat, targeting, inventory, UI and snapshot builders | Actor admission, movement and equipment remain shared orchestration. Keep membership in ExpeditionParticipation and preserve character identity, disconnect settlement and guest prediction. |
| Player health | Each host actor holds an immutable `Health` value from `player_vitals.gd`. Damage, healing, loadout changes, revival and Vital grants use one value. | Combat and life systems, player snapshots, HUD, spectator and diagnostics | Project the effective capacity for guests. Keep damage counters, network revisions and the lost-HP penalty in their existing actor fields. Preserve rollback by replacing the value. |
| Player lifecycle | Each host actor holds an immutable `Life` value from `player_lifecycle.gd`. Game and expedition life replace it on a life transition. | Action admission, delayed combat and defense, movement, HUD and snapshots | Use the host generation for delayed work and keep the projected fallen flag on the existing wire. Preserve rollback through the actor savepoint. |
| Weapon action timeline | `player_weapon_actions.gd::State` owns basic recovery, action sequence, committed direction, ranged wind-up and pose fields. Host actors hold one immutable value; Game, MouseCombat, CoreCombat and lifecycle operations install successors. | Weapon admission/release, Stage, and existing pose/attack_anim snapshots | Keep held cursor input, queued projectiles, class cooldowns and damage resolution separate. Guests receive projections, not the host component. Fall/return clears active presentation without resetting the existing recovery or sequence. |
| Native player protection | `player_protection.gd::State` owns full-hit Guard/Ward duration, charges, directional and counter windows, counter power and accepted Ward claims. Native effects install immutable successors; IncomingPlayerHit consumes one block. | Native Q/R support, class follow-ups, incoming defense, life, status and motion projections | Captured CombatActionEvents retain their response budget and potency. HP, Bark, partial damage reduction, Slow and hit grace remain separate. The owner accepts scalar context, never Game or an actor dictionary. |
| Ordinary hit conditions | `player_hit_conditions.gd::State` owns ordinary Slow and post-hit/revival grace deadlines. IncomingPlayerHit, native cleanses and lifecycle operations install immutable successors. | Damage admission, Slow prevention, five-class support, Water, movement, status and HUD projections | Omens still own Quiet Ground grants/consumption. HP, Guard/Ward, Bark, other affinity statuses and cast queues remain separate. Guests receive existing projections, not this host component. |
| Native action cooldowns | Each host actor holds an immutable `Timers` value from `player_cooldowns.gd`. Game and native class effects replace it when actions start, refund or refresh deadlines. | Action admission, class effects, aim, HUD, player snapshots and diagnostics | Preserve host timing and use existing guest projections. Carry the immutable value through actor rollback. |
| Character and class progression | `CharacterProfile` serializes the profile. Host gameplay edits `player.character` through class/loadout commands and publishes guest progress through the existing projection and acknowledgement path. | `class_catalog.gd`, the five connected trees, `affinity_build.gd`, roster and profile serializers | Separate permanent progression commands and build inputs from in-run actor state. Preserve profile IDs, selected nodes and XP scale. |
| Expedition participation and travel | `ExpeditionParticipation` owns run, route, depth, floor, cycle, seed, epoch, participant bindings, return holds and consent. `ExpeditionTransitions` coordinates admitted entry, advance, return, wipe and reset; `PartyTravel` validates gate consent through the same owner. | Gate, combat identities, rewards, ledgers, HUD, network and transactions | Game retains admission RPCs, encounters, terrain reset, settlement and publication. Deepest cleared floor and world drops remain separate reward/game state. Preserve exactly-once travel and guarded rollback across owners. |
| Expedition wallet | `Wallet` in `expedition_wallet.gd` owns each actor’s earned sparks and spent Essence. Game and monster reward settlement install accepted successors. Game supplies the shared floor milestone. | Card rerolls, player HUD and network snapshots | Keep balances derived from one player wallet and the existing floor progression. The monster reward owner retains the separate XP and loot awards. |
| Monster reward receipts | `MonsterRewards` owns frozen awards, delivery and settlement state by encounter epoch and spawn token. Game supplies eligible recipients, deterministic roll callbacks and verified transaction outcomes. | Enemy death handling, wallet credit, profile settlement, guarded departure and encounter reset | Preserve immediate run payouts and checkpoint profile credit as separate operations on the same receipt. Preserve deduplication through rollback and cleanup. |
| Guarded departure settlement | `DepartureSettlement` in `departure_settlement.gd` owns detached settlement records and reconnect holds. Game registers, stages and finalizes them through the existing guarded save route. | Reconnect admission, kill rewards, safe-pouch recovery, Garden return and host exit | Preserve peer and character identity together. Keep frozen kill receipts and the durable save verdict separate from the detached payload. |
| Cumulative graft acquisitions | `ExpeditionGrafts.Ledger` owns the ordered receipts of one actor's run. Game installs the next ledger and debits the selected trophy. | Altar, affinity build resolution, native graft attack capture, local Tab/HUD and owner-only guest details | Keep the ledger as the sole receipt source. Separate it from temporary proc counters in `native_graft_state`, whose lifetimes include fall and floor changes. |
| Upgrade cards | `Ledger` in `affinity_card_ledger.gd` owns each actor’s current affinity offer, completed checkpoint and acquired copies. Game installs a successor and applies its approved cost. | Checkpoint UI, weapon/ability resolution, graft previews and owner-only snapshots | Keep receipt storage in the ledger and active effects derived from the current build. Game still coordinates wallet debits and owns offer revision allocation and checkpoint readiness. |
| Enemies and encounter state | `EncounterRoster` owns host membership, spawn tokens, HP, death confirmation and clearance. EnemyTactics owns the leader position, engagement, deadlines and active boss phase. The roster keeps scout and elite role records. ExpeditionParticipation supplies the floor epoch; Game retains hazard records. | AI, hit testing, rewards, Stage and replicated state | Use scoped target queries and detached packet projections. Keep the encounter epoch, TC01 movement and ranged clearance, and MonsterRewards settlement boundaries explicit. |
| Combat resolution | Game resolves player strikes and coordinates effect queues and guarded transactions. `incoming_player_hit.gd` resolves incoming defense and health outcomes. `combat_action_events.gd` gives each action source and contact identity. `weapon_contact.gd`, class, graft and affinity handlers resolve effects and still access shared actors or enemies. | Simulation, reward settlement, presentation and snapshots | Provide source/target inputs and return combat outcomes. Keep direct hits separate from secondary effects and keep bounded queue, targeting and contact behavior. |
| Garden progression and experimental scene | `Progress` owns durable Garden data, with Heart, crops and reserves made available to Game commands. `experiment_garden.gd` owns the session layout and its projections. | Garden commands, inventory, Stage, guest details and the Garden serializer | Narrow Garden commands and publish scoped views without copying the full world. Preserve stable plot/item IDs, transaction semantics and the distinction between layout and serialized state. |
| Canonical persistence | `GuardedTitleSession` owns session leases, recovery holds and shutdown. `Progress` and `CharacterProfile` serialize; `game_transaction.gd`, `save_batch.gd` and `persistence_operations.gd` coordinate staging, rollback and publication. | Title, Garden commands, expedition settlement, recovery and guest projection | Prefer explicit participants and outcomes over full mutable-object snapshots. Preserve first-error handling, verified abort, uncertainty and cleanup pending as distinct outcomes. |
| Networking and session lifecycle | `NetworkSession` owns transport/role, pending joins, peer admission, character bindings, party slots, registration deadlines and request budgets. `SessionWorld` coordinates authorized profile/scene operations. Game keeps the 25 RPC entry points and builds actor records. | Host command routes, reliable owner recovery, UI and guest projections | Keep participant, reward and profile owners separate. Revoke connection capabilities before closing transport; compare captured bindings on delayed work. `network_contract.gd` owns the explicit wire/capability contract; `world_snapshot.gd` retains protocol 41. |

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
| `plan_debit()` | Check a requested Essence cost against the balance. Game installs the accepted debit with the card reroll before publishing the result. |
| `balance()`, `projection()` | Resolve the balance from the shared cleared-floor milestone, sparks converted at the authored rate and spent Essence. Return detached values for readers. |

Game passes the deepest cleared floor and the current sparks-per-Essence rate explicitly. The wallet stores no second milestone or balance. Host snapshots keep sending the same derived wallet value to guests. Graft purchases still debit trophies. Monster reward receipts freeze Class XP, kill rolls and run drops. Game applies the detached awards. Guarded departure settlement has its own owner.

The old writable `essence_sparks` and `spent` fields are gone. `ExpeditionWallet.ESSENCE_PER_CLEARED_FLOOR` owns the room award and [the combat balance](../game_balance.gd) resolves the configured kill awards and conversion rate. Card and graft owners do not maintain competing currency balances.

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
| `begin_expedition()`, `forfeit_expedition()`, `finish_expedition()` | Freeze pre-entry Class XP for all five classes and monster familiarity by character/run. Claim a voluntary forfeiture once, dropping only that character's pending permanent awards. Close the boundary on extraction, wipe or settled disconnect. These historical counters are not a second current-progress balance; the existing transaction savepoint restores them on confirmed abort. |
| `stage_pending()` | Mark pending receipts as staged and return detached awards for the current settlement. |
| `pending_receipts()`, `pending_count()`, `pending_profile_ids()`, `status()` | Inspect frozen work, track blocked departure rewards and expose receipt phases without sharing mutable records. |
| `savepoint()`, `restore_savepoint()`, `finish_settlement()` | Register changes with the actual guarded and legacy transaction roots. Verified rollback restores work without rerolling. Committed and cleanup-pending results retain deduplication evidence. Uncertain work stays held and is not replayed. |
| `retire_completed()` | Release completed and excluded receipt IDs at the existing encounter boundary while preserving pending work, cleanup holds and uncertainty. |
| `defer_legacy_notices()`, `take_legacy_notices()` | Retain reward notices until the outer legacy transaction can publish them. |

[Game](../game.gd) applies run currency and physical drops, updates eligible live or detached profiles, and publishes the staged notices at the transaction boundary. Experimental play retains immediate run payouts and banks Class XP and familiarity at the existing checkpoints. The guarded and contained persistence routes use one frozen receipt. A peer ID without the matching character identity cannot inherit another player's credit.

AR05 retires three Game collections and sixteen raw accesses across Game and the previous reward utility. The reward owner has zero direct Game reads/writes. Expedition context and travel now belong to ExpeditionParticipation and ExpeditionTransitions. Player admission, XP limits and save publication remain with Game and the established transaction services. No save-schema, protocol or packet-format changes are required. Multiplayer still checks matching build compatibility signatures. The receipt store lives in host memory. A host crash before a verified checkpoint can lose uncommitted Class XP and monster familiarity. A voluntary host exit instead forfeits the host character's run; involuntarily disconnected teammates retain the existing failed-run settlement. Expedition-only drops and Essence are lost with the run. The existing durable journal still reconciles any commit that was in flight.

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

Core/B recovery, ordinary weapon attack cadence, animation and casting windows, status deadlines and enemy action timers keep their current ownership. Use the five connected-class fixtures for native casts, refunds and dodge refreshes. Use `ability_aim`, `player_hud` and the existing snapshot and loopback checks for readiness presentation.

## AR07 player health

[Player vitals](../player_vitals.gd) owns current HP, resolved native maximum HP and temporary Vital capacity for each host actor. The effective maximum combines the two capacity values. Host actor admission installs one immutable health value. Damage, healing and changes in capacity replace it. The save transaction can restore an older actor dictionary and its prior health value without sharing mutable HP state.

| Operation | Contract |
|---|---|
| `hp()`, `native_max_hp()`, `temporary_hp()`, `max_hp()` | Read current HP or one of the three capacity values. |
| `with_capacity()`, `with_native_max_hp()`, `with_hp()` | Replace the chosen values and clamp current HP to the effective capacity. Capacity increases alone grant no healing. |
| `healed()`, `damaged()`, `refilled()` | Apply HP changes through replacement values. Damage keeps its existing whole-HP accounting. |
| `current_hp()`, `maximum_hp()` | Read the live host value or the guest's projected scalar fields for presentation. |

Game and the existing balance helpers resolve weapon, class, card, graft and expedition capacity inputs. The existing life-loss amount remains a separate actor field for revival eligibility and maximum HP. Damage receipts and network revisions keep their existing owners.

Host snapshots project HP and effective maximum HP into the existing reliable and fast fields. The guest keeps that projected data and reconciles the two channels by the existing revision. HUD, party, spectator, stats and diagnostic readers use the same host value or guest projection. Damage flash still follows the existing damage sequence. The component stays out of packets and character saves.

This removes 37 raw player HP or capacity member accesses in Game, along with its two raw health fields and the separate Vitality bonus cache. Lifecycles still choose explicit refills where gameplay calls for them, including revival and Garden return.

Use `combat_vitals_baseline` and the actual combat and support fixtures for capacity, damage and healing. Use `guarded_expedition` for rollback, `party_hud_gates_coop` and `diagnostics_coop` for host/guest presentation, and `network_presentation` and `world_snapshot_codec` for stale-frame precedence.

## AR08 player lifecycle

[Player lifecycle](../player_lifecycle.gd) owns each host actor's downed state and life generation. Game admits actors; [expedition transitions](../expedition_transitions.gd) coordinates entry and return, and [expedition life](../expedition_life.gd) handles fall and revival through replacement values. Admission, revival, expedition entry and Garden return allocate a new generation. Falling and waiting for the party preserve the existing generation. The savepoint restores the previous actor value on rollback. The allocator never reuses a generation reserved by an aborted transition.

| Operation | Contract |
|---|---|
| `start_life()` | Create an active life with a new host generation. |
| `fall()` | Preserve the generation and mark the life downed. ExpeditionParticipation now owns the separate post-return party hold; `PlayerLifecycle.fallen()` projects that hold for existing gameplay consumers. |
| `clear_inactive()` | Give an inactive actor a fresh life when the party releases the wait. |
| `generation()`, `matches()` | Capture and validate the source or recipient life for delayed host combat work. |
| `fallen()` | Read the host lifecycle value or the existing fallen field on a guest projection. |

Delayed class, Core, affinity, and graft work compare against the captured host generation where their existing source policies require ownership. Falling alone does not invalidate an accepted Ward or Omen whose source policy allows it to finish. A new life or departure invalidates that source. Floor and run ownership still use their existing identities. This replaces 17 direct reads or writes of the fallen field in Game. Game still coordinates expedition participation through `wild`. The `lost_health` field drives the revival HP penalty, and the existing Core and aimed class requests retain it in their wire compatibility fingerprint.

Fast and reliable snapshots retain their public fallen and HP-penalty fields. Movement, HUD, spectator and diagnostics read the host state or the guest projection as appropriate. Movement retains its existing floor/seed/Wilds/fallen epoch. The private generation stays with the host actor.

Use `loot_revival` and its co-op fixture for lifecycle, `guarded_expedition` for rollback, `cr02_combat_contracts` and the connected-class and affinity fixtures for delayed work. Use `world_snapshot_codec`, `network_movement_coop` and the party HUD and diagnostics fixtures to verify the projections.

## AR09 encounter roster

[EncounterRoster](../encounter_roster.gd) owns the active leader and scout membership, current HP, spawn tokens, confirmed defeat, and the floor-clear predicate. Game creates the roster and begins each floor. A scout spawn plan specifies initial HP and consumes its reserved token at registration. Its tactics dictionary supports movement, attack preparation, and status timing. Slot numbers retain the existing packet order. The floor's leader occupies target `-1`. Delayed work also carries the existing encounter epoch.

| Operation | Contract |
|---|---|
| `begin_floor()`, `register_scout()`, `clear_scouts()` | Start the next active roster, fill or replace a seat, or clear scout membership. Fresh occupants use fresh identities. |
| `hp()`, `alive()`, `token()`, `position()`, `cleared()` | Resolve narrow structural queries. Use a captured token for delayed scout work. Since AR10, Game resolves the leader position through EnemyTactics. |
| `apply_damage()`, `set_hp()` | Apply resolved damage against the expected occupant. Set HP explicitly for setup, recovery and other authored overrides. |
| `death_pending()`, `confirm_death()`, `despawn()` | Confirm an eligible death once. Escape retires an occupant without awarding a kill. Game coordinates effects and passes frozen death inputs to MonsterRewards. |
| `scout_view()`, `scout_pack()`, `scout_codes()` | Send detached data to outside callers. Fast host frames retain protocol 41's scalar order and size. Guest presentation uses received projections. |
| `savepoint()`, `restore_savepoint()` | Capture or restore roster health, membership and defeat during guarded rollback. The token allocator retains consumed identities across rollback. |

Specialist movement, telegraphs, roles, boss phases, and status effects use mutable tactical records. Those records carry no authoritative scout HP or spawn token after registration. AR10 moves the leader fields and behavior out of Game. Game retains hit math, effect queues, floor routing, and settlement orchestration.

Use `encounter_roster` for owner invariants, `combat_animation` for slot reuse during a contact batch, `boss_phase_fights` for bounded summons, `monster_rewards` for receipts, `guarded_expedition` for rollback, and `world_snapshot_codec` for protocol shape and stale updates. `boss_coop`, `guarded_expedition_coop`, `experimental_terrain_coop`, and `four_players_coop` exercise the real integration.

## AR10 enemy tactical state and behavior

[EnemyTactics](../enemy_tactics.gd) is the host owner for the leader's position, engagement, attack deadlines, adaptation and plan memory, and active boss kind and phase. The gate-elite role record lives on the leader member in [EncounterRoster](../encounter_roster.gd). Game coordinates encounter reset, damage, rewards, persistence and publication. ExpeditionParticipation owns the encounter epoch. Both transaction paths restore the tactical owner alongside the roster. Guests project accepted protocol-41 leader fields through `EnemyTactics.project()`.

| Path | Responsibility |
|---|---|
| [leader_behavior.gd](../leader_behavior.gd) | Routes a floor leader to the Heart's Briar, a gate elite, or the boss dispatcher. Owns Briar decisions and release. |
| [scout_behavior.gd](../scout_behavior.gd) | Advances regular and summoned scouts and releases prepared scout and gate-elite attacks. |
| [enemy_formation.gd](../enemy_formation.gd) | Finds escorts, arranges formations, and advances support follow behavior. |
| [combat_director.gd](../combat_director.gd) and [enemy_attack.gd](../enemy_attack.gd) | Select targets and navigate. Author aim, collision, telegraphs, and attack geometry. |

The ordinary scout attack path passes a read-only value observation to `choose_attack()`. Game and live actor dictionaries stay on the host side. `apply_attack_intent()` validates the encounter epoch, roster token, target life, current readiness, role, reach and sight before locking the existing telegraph. Specialized movements and boss plans keep their local decision paths. Shared combat and specialist code still access EnemyTactics fields and roster role dictionaries through Game.

Use `regular_enemy_responses` for valid and stale attack intents, `enemy_roster` for role telegraphs, `boss_phase_fights` and `boss_lairs` for phase changes, `guarded_expedition` for tactical rollback, and `boss_coop` with `four_players_coop` for replicated outcomes.


## AR11 enemy attack execution

[ScoutBehavior](../scout_behavior.gd) selects an ordinary attack and submits the read-only observation for host validation. [EnemyAttack](../enemy_attack.gd) locks the existing plan, carries the floor epoch, scout slot and spawn token, and records the intended peer and life generation. It claims a due plan before effect callbacks run. Cancellation and stale floor or source identity invalidate the plan. Volley repeats schedule another beat of the same locked attack. Scout warnings use the same committed geometry, and the roster still provides the gate elite's role record to its warning and release paths.

[EnemyAttackHits](../enemy_attack_hits.gd) resolves area, swept-charge, and sector contacts using the bound field and detached target positions. Its world adapter rechecks source identity and player life before submitting a validated contact to [IncomingPlayerHit](../incoming_player_hit.gd). A replacement life for the intended peer is excluded. Other live players can still enter the locked footprint. Delayed scout hazards retain the commitment in [boss_encounters.gd](../boss_encounters.gd) while using the existing hazard schedule.

Elite movement, boss phase scripts, hazards, class effects, and the lure pull retain their specialized dispatch. The protocol-41 projection keeps the existing wire layout.

Use `regular_enemy_responses` for locked-plan deadline, replay, target changes, stale floor and actor identity, and delayed hazards. Use `combat_vitals_baseline` for defensive ordering, `projectile_terrain` for TC01, `gate_elites_coop` and `boss_coop` for replicated warnings, and `guarded_expedition` with `four_players_coop` for rollback and multiplayer.

## AR12 incoming player hits

[IncomingPlayerHit.resolve_world()](../incoming_player_hit.gd) accepts the peer, captured life generation, hit time, authored damage, Slow duration, and attack origin and classification. It returns an outcome, actual HP loss, and whether a damage record was written. Its recipient adapter revalidates the host and current life and gives the resolver detached combat facts. The recipient adapter still binds one actor record from Game for the existing status, class and affinity hooks. Game supplies the guarded transaction and combat feedback. The resolver owns the order of those steps.

The resolver checks hit grace and consumes eligible Guard or Ward. Unblocked damage uses the existing HP conversion, Water and Warden mitigation, and Bark absorption. [`PlayerHitConditions.State.after_hit()`](../player_hit_conditions.gd) applies ordinary Slow and grace. IncomingPlayerHit asks the Omen owner to consume Quiet Ground only when its prevention is eligible; CombatStatus only projects the resulting status. Surviving hits can trigger the existing Oracle, Frost, Fire, and Bark responses. [PlayerVitals.apply_damage()](../player_vitals.gd) stores HP while [ExpeditionLife](../expedition_life.gd) handles falling with [PlayerLifecycle](../player_lifecycle.gd). A guarded lethal outcome commits before deferred Bark work and returns an uncommitted result on refusal or rollback. The raw `apply_health_loss()` operation shares HP application and settlement. Health and rollback fixtures use it to exercise HP changes independently of defenses.

Use `combat_vitals_baseline` for defenses, simultaneous hit grace and stale lives, `guarded_expedition` for lethal rollback, and `regular_enemy_responses` for scheduled contacts and replay. `ct01_warden`, `ct04_reaper`, `ct05_oracle`, the focused affinity fixtures, and card and graft fixtures cover the existing reactions. `gate_elites_coop`, `boss_coop`, `combat_readability_coop` and `four_players_coop` cover visible outcomes and multiplayer.

## AR13 expedition participation and travel

[ExpeditionParticipation](../expedition_participation.gd) owns the run and floor identity, per-peer actor membership binding, post-return hold, and ready-check kind, membership, signatures and revision. Its actor Link can only query the bound peer, participation and wait state. Replacing or detaching a binding invalidates the old Link. There is no second Game membership array or writable host `wild` field. [PlayerLifecycle](../player_lifecycle.gd) keeps life generation and downed state; the retired `AWAITING_PARTY` phase no longer duplicates participation.

| Interface | Responsibility |
|---|---|
| `attach()`, `enter()`, `leave()`, `detach()` | Bind an admitted actor, enter once, record individual return and invalidate removed actors. NetworkSession separately owns the character association. A returned participant waits until the remaining expedition ends. |
| `contains()`, `active()`, `participants()`, `is_wild()`, `is_waiting()`, `peer_for()` | Query membership through a read-only Link or detached projection. Participant lists are sorted, detached and read-only. |
| `route()`, `depth()`, `floor()`, `cycle()`, `seed()`, `epoch()`, `run_id()`, `world()` | Read one authoritative context. `world()` is a detached read-only projection. Run, floor epoch, player life and enemy spawn identities remain distinct. |
| `select_route()`, `reset_run()`, `begin_floor()`, `advance()` | Govern the existing run/floor changes. A stale or repeated floor advance is refused. Active membership prevents resetting the expedition. |
| `begin_travel()`, `set_vote()`, `withdraw()`, `clear_travel()` and vote queries | Store one ready check; require its revision for withdrawing consent. PartyTravel validates position, loadout, party eligibility and current signatures before accepting a travel result. |
| `savepoint()`, `restore_savepoint()` | Restore membership, floor context and consent with the guarded transaction. Binding, run, floor epoch and consent allocators retain high-water marks so discarded identities are not reused. |
| `project_world()`, `project_participants()` | Rebuild the receiving guest's presentation owner from an accepted protocol-41 frame. The packet layout is unchanged; run IDs remain host-local. Stale-frame rejection stays in the network receiver. |

[ExpeditionTransitions](../expedition_transitions.gd) is the world adapter for `enter/admit`, `checkpoint/commit_checkpoint`, `return_member`, `abandon`, `finish_failed/commit_failed`, `finish_if_empty` and `reset`. These bodies no longer exist in Game. It still receives Game to integrate actor setup, terrain, inventory, ledgers, rewards and save/publication. It is an explicit remaining orchestration dependency, not another authoritative state store. PartyTravel has no vote dictionary of its own.

Accepted entry begins the existing Garden return receipt, binds participation, then records the member join and class life. Advancing checks the current epoch, preserves run cards/grafts/wallets and begins the next encounter. Individual return leaves the other members active. Releasing the final party hold starts a fresh player life, preserving stale-life rejection from the prior implementation. Extraction, wipe and final departure settle through the existing guarded boundary before cleanup. MonsterRewards, DepartureSettlement and the wallet/card/graft owners keep their original records and uncertainty rules. Pending profile settlement still blocks unsafe admission. No production saves or schemas are enabled by this extraction.

Use `expedition_participation` for detached projections, admission and stale consent, peer reuse, guest projection and savepoint restoration. Use `party_ready`/`party_ready_coop` for gate eligibility, votes and rollback; `guarded_expedition`/`guarded_expedition_coop` for aborted, uncertain and cleanup-pending travel; `loot_revival` for partial return and fallen allies; `experimental_terrain_coop` for developed Garden return and rejoin; and card/graft plus four-player fixtures for ledger continuity and overflow. [The fixture helper](../tests/support/expedition_case.gd) seeds synthetic cases through owner savepoints and real membership operations; it is never used by gameplay.

AR13 measurements use the same top-level declaration/function counts and masked literal `game`/`game_node` access scan on both revisions. Data access and owner/service use are separate measures.

| Measure | Pre-AR13 | AR13 |
|---|---:|---:|
| Game lines / top-level functions / variables | 5,557 / 291 / 167 | 5,141 / 280 / 158 |
| External direct Game-owned data accesses | 841 | 600 |
| External Game owner/service references | 1,132 | 1,492 |
| References to the ten retired world/travel fields | 291 | 0 |
| Host actor membership reads / writes (excluding initializer) | 154 / 2 | 0 / 0 |
| Direct actor-registry accesses | 311 | 335 |

The new owner has zero Game dependencies. Its 342 external handle uses are owner operations, not exposed mutable membership. The transition adapter moves 10 lifecycle bodies out of Game while retaining its broad integration context. Total literal Game roots increase from 2,735 to 2,966 because that integration is now external; this is not a claim that whole-project coupling has fallen. The actor registry remains a separate boundary. No current test was deleted. Removed exact Game scopes were mapped to the owning modules and surviving fragments were updated without changing their domain attribution.

Focused verification passed 19 distinct fixtures: 11 units, six independent host/guest pairs and two four-player controls including fifth-client refusal. Three first-pass failures were fixture assumptions (a synthetic Garden wait and two raw guest membership reads); their failure evidence was preserved and the corrected cases passed under separate run IDs. Current coverage includes guarded rollback/uncertainty/cleanup pending, rewards, card and graft transactions, partial return/revival, guest recovery, developed Garden rejoin and the unchanged snapshot codec. The migrated fixtures also passed syntax-only loading. No full export or historical suite was run.

## AR14 session admission and network identity

[NetworkSession](../network_session.gd) owns the live connection registry and transport lifecycle. Actor records hold a read-only Link instead of writable `profile_ready`, `seed_owner`, `party_slot`, `joined_at`, rejection flags or request budgets. Local character identity is distinct from its empty shared-inventory namespace. Peer reuse allocates a new binding; old Links, rejection timers and request identities cannot authorize the replacement. ExpeditionParticipation retains run membership and no longer stores a second character association.

| Interface | Responsibility |
|---|---|
| `admit_peer()`, `bind_character()`, `ready()`, `identity()`, `binding()`, `matches()`, `belongs_to()` | Admit up to four peers, bind an accepted character once and validate the originating owner/connection. Remote characters cannot duplicate an already bound character. |
| `view()`, `peers()` and static Link readers | Return detached read-only peer facts or scalar queries. Frozen departure/reward and guest projections retain their existing value formats. |
| `reject()`, `release_peer()`, `timed_out()`, `allow()` | Claim rejection once, retire bindings, inspect registration timeouts and enforce per-connection request budgets. |
| `start_host()`, `start_join()`, `transport_connected()`, `compatibility_started()`, `accept_guest()`, `finish_recovery()` | Own the existing Solo/Host/Connecting/Guest lifecycle and connection/recovery deadlines. Endpoint configuration stays distinct from the title's saved choices. |
| `close_transport()`, `reset_solo()`, `permits_details()` | Revoke authorization before ENet teardown. Reliable owner details must match the accepted connection and character. |

[SessionWorld](../session_world.gd) is the integration adapter for host/join, registration, disconnect, leave, rejection and timeout handling. It performs existing lease, profile, content and settlement checks before binding a character, and rechecks the captured binding after durable admission. DepartureSettlement still owns pending/uncertain readmission holds; no reward or pending-profile records move into NetworkSession. Session registration and transport budgets stay outside gameplay rollback. Game's RPC signatures and `MysticalGarden` NodePath remain, with sender authorization at the facade and registry. Actor construction, profile publication, snapshots and broader UI still depend on Game.

[NetworkContract](../network_contract.gd) replaces the hash of every Game method with the explicit `session-1` contract: 25 RPC signatures/default counts, sender/delivery/channel declarations, root path, protocol-41 layout constants and named capability versions. Existing terrain, cultivation, Garden, combat ruleset and definition checks remain. Old method-hash clients are refused. A private implementation refactor no longer changes compatibility. Change the relevant capability/contract version when network semantics change; signature equivalence alone does not approve new behavior.

[NetworkActionIdentity](../network_action_identity.gd) supplies `a1` native action stamps from the accepted connection, character, PlayerLifecycle generation and all seven run/floor context fields. Revival capacity loss is no longer an identity token. The host derives the stamp. The reliable acceptance reply binds the character and connection; existing reliable owner details carry the opaque action stamp and connection key. The fast snapshot layout is unchanged. Core and aimed/native Q/R requests refuse missing, foreign-owner and stale stamps before cooldown/resource admission. Native automatic targeting remains explicit through `AbilityAim.request_native()`. Guests expose no action stamp while the reliable owner-details key trails the current fast floor projection.

AR14 measurements use the same masked literal external `game`/`game_node` scan as AR13, separating mutable data access from owner usage.

| Measure | Pre-AR14 | AR14 |
|---|---:|---:|
| Game lines / functions / plain variables | 5,141 / 280 / 158 | 4,820 / 268 / 153 |
| External direct Game-data accesses | 600 | 633 |
| External owner/service references | 1,492 | 1,653 |
| Raw Game session-field accesses | 42 | 0 |
| Live actor session-field reads / writes | 54 / 3 | 0 / 0 |
| Owner operation calls / owner member-data chains | 815 / 588 | 960 / 609 |

The session owner has zero Game dependencies. Its 126 external handle uses are 123 owner-operation chains and three arguments that pass the owner explicitly; none access its private records. Twelve Game session functions and three RPC bodies moved into SessionWorld; four actor initializers and duplicate participation character storage were retired. SessionWorld still adds 62 Game-data accesses for integration; existing external files fall from 600 to 571. Total literal Game roots rise from 2,966 to 3,180. Player-registry references rise from 335 to 363. This establishes one authorization owner without claiming whole-project coupling fell. Named imports remove the adapter's Game-constant lookups except the host ID. The actor registry, snapshot/detail assembly and scene/profile handoff remain substantial boundaries.

Focused verification passed 17 baseline and 21 final distinct fixtures: the final set contains ten units, nine independent host/guest pairs and two four-player controls, each including fifth-client refusal. `network_session` covers ownership, peer reuse, capacity, rejection, budgets and teardown; `network_contract` checks the actual RPC manifest and private-method independence; `network_action_identity` checks life, character, owner and world identity. `network_contract_coop` checks actual obsolete-contract refusal, current admission and stale deferred-attempt rejection. Existing settings, guarded lifecycle/expedition, Core, title, snapshot, terrain and party fixtures cover rollback, settlement holds, rewards, reconnect, owner recovery, travel, card/graft integration and overflow. This is local loopback, not separate-PC or internet verification.

The first final pass exposed a real teardown regression: static multiplayer signal callbacks survived a removed world and rejected the next world's duplicate connection. Game now disconnects those callbacks before teardown. Three other failures were fixture assumptions: exact guest refusal text despite host disconnect ordering, reading a disconnected Link instead of freezing its character identity, and casting after fast floor travel before reliable owner details arrived. Failure evidence remains under the original `ar14-after-*` run IDs; narrowly corrected cases passed under new IDs, including action/aim controls after the guest floor-key guard. No retries hid rejected casts. The 94 migrated/new GDScript fixtures also passed syntax-only loading. No historical full suite, export or production save activation was performed.

[SessionCase](../tests/support/session_case.gd) seeds synthetic fixture facts through public owner operations and never runs in gameplay. The planner maps the new owner/contract/action modules directly, retires obsolete Game-function fragments, and retains current gameplay, historical data conversion, reward and persistence coverage.

## Explicit persistence session

[`guarded_title_session.gd`](../guarded_title_session.gd) is the single owner for a world's persistence-session access and lifecycle. `Game.persistence_session` holds one typed instance. The title and Developer Garden start that exact instance and the world retains it; no metadata attachment or second flag record exists. Startup receives only the three persistence participants, original store instances, confirmed selection/digests and the existing heartbeat-stagger option. It never receives Game, players, network peers or reward records.

| Operation | Meaning and boundary |
|---|---|
| `start(progress, local_profile, guest_profile, garden_store, …)` | Claim and load the confirmed paths under the existing authorization and root lock. Failed claims unwind only acquired leases. Failed confirmation cannot turn a world into a guarded session. |
| `is_guarded()`, `can_write()`, `authorizes(path)` | Distinguish a guarded session from the unchanged ordinary production route, then enforce its shutdown/recovery hold and current leases. Actual IO authorization and serializer scope still apply independently. |
| `record_finalization(boundary)` | Record a recovery hold from the real typed outcome or missing finalization. A later callback cannot clear or reinterpret an existing hold. No reward or save receipt is copied here. |
| `finalization_feedback(boundary)`, `pending_notice()` | Preserve the original recovery reason and return detached publication instructions. Game/transactions publish the existing feedback and diagnostics; they cannot assign pending flags. |
| `can_publish_state()` | Confirmed cleanup may publish its warning to guests while combat remains held. Uncertainty cannot be presented as a committed state. Callers no longer compare local warning text to decide this. |
| `require_departure_recovery()` | Hold an explicitly missing departure verdict. DepartureSettlement still owns the payload and readmission decision. |
| `begin_shutdown()`, `finish_network_detach()` | Claim shutdown once. A permitted network detach can retain the Garden, but cannot clear recovery or reacquire lost leases. |
| `tick()`, `release()` | Renew and release the original store leases. A released guarded instance stays guarded and cannot fall through to ordinary writers or restart itself. Reopening uses a fresh, confirmed session. |
| `status()`, `title_return_view(…)` | Return detached facts. `MainMenu.accept_persistence_return()` copies the passive notice and recovery paths; its returned view cannot alter the old session or authorize writes. Disk review/recovery remains explicit. |

The seven former metadata keys for the session attachment, pending/stopping flags, recovery notice and title-return fields are retired. Two transaction query facades are removed. `guarded_host_cleanup_notice` and `guest_projection_notice` still represent separate received-host/profile presentation concerns; they are not local session authority. Test-only fault hooks and heartbeat clock probes remain distinct from runtime state writers.

| Measurement at this boundary | Before | After |
|---|---:|---:|
| Selected runtime metadata accesses / mutations | 165 / 17 | 0 / 0 |
| All runtime `get_meta` + `set_meta` sites | 266 | 188 |
| Session owner Game/world member accesses / Node parameters | 13 / 1 | 0 / 0 |
| Game lines / functions | 4,479 / 257 | 4,474 / 257 |
| Game plain top-level variables | 153 | 154 |

The extra Game variable is the typed owner reference, not a duplicate pending-state copy. Most consumer changes replace metadata lookups with ordinary owner queries; they are not claimed as eliminated owner/service dependencies. The substantive transfer is finalization/hold/shutdown policy and lease-bound startup without Game. Nine chained title-return normalization fragments, including six full-function rewrites, are retired; their coverage is promoted to the current function's declared systems. Surviving normalization baselines are unchanged.

Focused ownership tests extend `tests/guarded_title_session.gd`: detached views, idempotent shutdown, retained holds, uncertainty, failed release and passive title projection. `guarded_gameplay_transactions` covers real commit/abort/cleanup/uncertainty, nested participants and retry; `guarded_lifecycle` and its co-op fixture cover title, disconnect, reconnect and release ordering. Expedition, guest projection, serializer, card/graft and candidate party fixtures protect the integration, including four-player admission and overflow refusal. Use disposable storage and strict per-peer verdicts. These checks do not replace package, manual or internet acceptance.

Game/SessionWorld still coordinate scenes, actor/profile publication and transactions; GameTransaction still snapshots mutable gameplay for rollback. The owner does not replace physical recovery, permanent reward settlement or the guarded/contained production writer distinction. Production AC-06 remains disabled and uncommitted host-memory progression remains vulnerable to host failure. No durable journal, save-schema migration or production activation is added here.

## Typed player weapon actions

[`player_weapon_actions.gd`](../player_weapon_actions.gd) owns the complete selected weapon timeline as an immutable `State` under `WeaponActions.STATE`. It replaces eleven raw actor keys: `strike_at`, `attack_until`, `attack_duration`, `attack_combo`, `swing_until`, `attack_reach`, `attack_direction`, `attack_clip`, `attack_delivery`, `attack_span`, and `ranged_windup`. Five were initialized on every actor and six were added dynamically. There is one component attachment and no second authoritative timeline or metadata store.

| Operation | Responsibility |
|---|---|
| `ready()`, `try_start()` | Admit a basic attack at its resolved recovery deadline, advance its sequence, and establish the existing pose/swing timing. Game checks readiness before rolls and proc capture. |
| `with_pose()`, `follow_cursor_until()`, `sample_release()` | Capture delivery metadata, identify a live ranged wind-up, and commit its release direction. An older queued shot cannot overwrite the newest pose. Current cursor intent remains in MouseCombat; projectile records capture scalar sequence/life/floor identities. |
| `core_pose()`, `swing_until()` | Preserve Core's existing basic-attack exclusion/pose and native class-hit swing pulse. These operations add no weapon contact, damage or affinity proc. Core/class cooldowns and cast queues keep their owners. |
| `clear_active()`, `with_ready_at()` | Cancel active presentation on fall/return, or explicitly change only ordinary recovery. Floor travel retains the existing timeline. There is no new revival readiness bonus. |
| `animation()`, `swing_ticks()`, `swing_fraction()` | Produce detached presentation from one timing calculation. Game and Stage no longer rebuild that calculation independently. Existing class-cast pose priority stays with Game. |

The execution path remains input → `Game.strike_enemy()` (living actor, resolved build and native/Form/graft capture) → typed action admission → `MouseCombat.queue_attack()` (delivery, geometry and delayed record) → sequence-bound release → existing projectile/contact and damage consumers. WeaponContact, incoming-hit defenses, PlayerVitals and PlayerLifecycle retain their responsibilities. The component accepts scalar values and vectors, never Game, Nodes or mutable actor dictionaries. Its new values preserve the old value for transaction rollback.

The host's existing `pose` and `attack_anim` packet projections are unchanged. The component is never replicated or saved as character progression. Guests retain presentation records; they cannot own or submit the host timeline. Protocol 41, RPC signatures, gameplay-definition values and production persistence configuration are unchanged from the parent. The recovery tag `architecture/pre-player-weapon-actions` protects `2e8a5c5262ab3213e5c647dc3a85a4ff0b94289b`.

| Measurement for this slice | Before | After |
|---|---:|---:|
| Raw selected actor-field access sites across six runtime consumers | 56 | 0 |
| Selected mutable actor keys | 11 | 0 (one typed component) |
| Owner Game/actor-dictionary inputs and metadata accesses | — | 0 |
| Game lines / functions / plain top-level variables | 4,481 / 257 / 154 | 4,484 / 257 / 154 |
| Direct `game.players` references in the affected external modules | 47 | 47 |

This is a state/semantic boundary improvement, not a claim that 56 Game dependencies disappeared. Callers now use component operations; their broader actor lookup and world orchestration remain. Game gains three lines for explicit typed admission/integration. The duplicated pose calculation and the two full-actor MouseCombat aim helpers are removed. Two replaced Game pose-normalization overlays are retired with their coverage promoted to the current function/owner. Other reviewed wiring matches keep their historical baselines.

The focused `player_weapon_actions` fixture covers admission, immutable successors, sequence-bound aim, Core pose/exclusion and detached projections. `mouse_combat`, `weapon_actions`, `combat_animation` and the independent weapon-action pair establish before/after delivery equivalence. `guarded_expedition` now starts a real attack inside a failed save and verifies the original component and queue are restored. Existing class, card/graft, TC01, life, exit and four-player controls protect integrated consumers. Source-only fixture reset operations use the new owner rather than recreating retired actor keys.

Focused verification on 2026-11-18 passed 26 current source suites / 34 fixture-process verdicts, including independent two-/four-player loopback and fifth-client refusal. The four before-change weapon controls also passed, 28 migrated fixtures compiled, and all 106 tooling self-tests passed after the network fixtures exited. One earlier tool self-test competed for the active fixture mutex; it was an execution overlap, not a gameplay failure, and was rerun without changing the test. There were no failing gameplay fixtures. Registry size is 216 → 217. The real shared actor contract change invalidates all 217 source keys; a full release refresh is deferred. No export, production activation, rendered desktop or separate-PC/internet acceptance is claimed.

The later protection slice below completes native Guard/Ward ownership. Position, equipment, live input, class casts, other statuses and combat queues still cross broad integration adapters; this does not convert the entire player registry.

## Typed native player protection

[`player_protection.gd`](../player_protection.gd) is the single owner of native full-hit protection and its counter follow-up. Each actor holds one immutable `State` under `Protection.STATE`. It replaces seven raw native fields (`guard_until`, `guard_charges`, `front_guard_until`, `guard_face`, `counter_guard_until`, `counter_until`, `counter_power`) and the mutable `affinity_ward_claims` array. The transient `affinity_ward_grant` actor key and `ward_grant_order` Node metadata are removed. No parallel raw field or metadata copy remains.

| Public operation | Responsibility |
|---|---|
| `grant(until_ms, charges, now_ms, epoch, event?, adapter?, recipient_id?)` | Preserve the existing max-duration/max-charge merge and 1–4 charge bound. Add an ordinary or captured source claim only when native protection actually changes. A repeated source activation can extend native protection without renewing its once-per-recipient response budget. |
| `allows_block(position, origin, now_ms)`, `with_front_guard()`, `with_counter_guard()`, `movement_scale()` | Own directional eligibility, source-facing capture and independent native movement/counter windows. Unspecified hit origin keeps the prior full-hit policy. |
| `consume_block(now_ms, epoch, recipient_id)` | Return a successor and one detached selected response. Earliest claim expiry wins; ties use accepted host grant order. Order is recipient-local because claims on different recipients never compete. Expired, wrong-floor or already-used response budgets are excluded. |
| `prepare_counter()`, `extend_ready_counter()`, `spend_counter()` | Own the native counter deadline and authored-point power. Warden Deep Roots extends only a live prepared counter; one eligible existing native contact spends it. |
| `expire_claims()`, `clear_guard()`, `clear_expedition()` | Prune inactive claims. Fall/revival cancels Guard and claims while retaining the prior independent native windows; entry/return additionally resets charges and active directional/counter windows. Normal floor travel preserves native deadlines while old-epoch responses cannot fire. |
| Deadline/count queries | Supply status and movement projections without exposing the claims array. Block adapters are detached copies; captured events are references to the existing authoritative CombatActionEvent, never duplicate potency/response stores. |

Incoming defense remains `IncomingPlayerHit.observe()` → grace check → `State.allows_block()` → `State.consume_block()` → [`WardResponses.block()`](../ward_responses.gd) publishing the selected actual-block event → native counter preparation → Warden/Oracle reactions. This preserves response ordering and the distinction between a successful full-hit block and partial Bark absorption. The response publisher owns no mutable protection state. Counter damage remains in the existing native hit augmentation path; no extra weapon contact, Catalyst cast, graft proc or affinity response is introduced.

Native class/growth/Unique-card grants call the component directly. Source-bearing class grants use `CombatActionEvents.grant_ward()` to resolve the recipient ID and pass the captured event explicitly. `CombatActionEvent.accept_grant()` now receives a scalar recipient ID instead of Game and an actor. `Game.grant_guard`, the full-actor `CombatTraits.guard_allows`/`blocked` helpers, the `CombatActionEvents.blocked` forwarding function and `WardResponses.accepted` are retired. Existing owner snapshots restore the earlier immutable component on guarded rollback.

Tune skill-specific durations, charges and support geometry in their existing class/affinity definitions. [`class_skill_balance.gd`](../class_skill_balance.gd) remains authoritative for the Guard charge bound, counter window/potency and the unchanged directional constants (0.4 movement scale, 0.15 facing dot, 0.01 m² near-origin tolerance). The component stores resolved state; it does not author class/card/affinity balance. HP, mitigation, hit grace, Slow, life generation and class-specific Holdfast/Sanctuary effects keep their owners.

| Measurement for this slice (same sixteen affected runtime files) | Before | After |
|---|---:|---:|
| Raw selected protection-field access sites | 57 | 0 |
| Raw native fields / claims / transient grant context | 7 / 1 / 1 | 0 (one typed component) |
| `ward_grant_order` metadata accesses | 2 | 0 |
| Game lines / functions / plain top-level variables | 4,484 / 257 / 154 | 4,477 / 256 / 154 |
| Calls to `game.grant_guard` | 13 | 0 |
| Direct `game.players` references in affected modules | 91 | 91 |
| Explicit `game.participation` API calls in affected modules | 72 | 82 |
| Owner Game/Node/actor-dictionary inputs | — | 0 |

The 57 accesses became owner operations, not 57 eliminated world dependencies. The broad actor lookups remain; direct native grants now pass their floor epoch explicitly. The improvement is one authority for protection transitions, removal of transient actor/metadata state and five superseded paths. This is not a claim that all combat integration is decoupled. Four replaced source-normalization overlays were retired with coverage retained in the current protection/class-balance/incoming-hit owners; surviving historical baseline strings remain unchanged.

The `player_protection` fixture covers immutable successors, bounds, native/captured claim priority, expiry, wrong-floor and spent-budget rejection, detached adapter data, direction, counter use and lifecycle reset distinctions. Existing five-class, Frost/mixed-Ward, card/Unique, graft, incoming-hit, terrain, status, life and independent network fixtures cover actual consumers. `guarded_expedition` changes real protection inside a failed transaction and verifies restoration of the original owner. Fixtures initialize/query the component instead of recreating retired fields. The maintained map has 217 → 218 suites. Shared actor-wiring changes invalidate all 218 source keys; focused evidence does not authorize a release and a broad refresh remains separately scheduled.

Focused verification on 2026-11-18 passed 28 current source suites / 38 fixture-process verdicts: six independent two-player pairs and one mixed-class four-player scenario with fifth-client refusal. Six before-change controls (seven peer verdicts), 30 migrated-fixture compile checks and all 106 validation-tool self-tests also passed. An initial owner check exposed a typed-array assignment error on final-charge consumption; the first Weaver run exposed a fixture variable left behind by migration. Both were corrected and independently rerun; their original failed verdicts are retained. Source inputs stayed stable during each run and all 28 final keys match the live source. No export, production activation, rendered desktop or separate-PC/internet acceptance is claimed.

No packet, RPC, gameplay-definition value, save schema or production saving policy changed. The recovery tag `architecture/pre-player-protection` preserves `a71ad936f49d0bfce0492d5d0207d17a2bd54a60`. Remaining coupling includes the incoming-hit recipient/world adapter, mutable class/affinity response budgets and other status records, class cast/contact queues, actor lookup, and scene/session orchestration. A subsequent cleanup should choose a complete status or effect-scheduling boundary with its real consumers; it must not mix those records into health, profile or network-projection ownership.

## Ordinary hit-condition ownership

[`player_hit_conditions.gd`](../player_hit_conditions.gd) owns ordinary Slow and post-hit/revival grace as one immutable `State` under `Conditions.STATE`. Every live reader/writer of the former `slow_until` and `hurt_until` actor fields uses the component. There is no second host deadline or metadata store. This boundary owns contact aftermath, cleansing and its projections; it does not absorb Omens, HP, Guard/Ward, Bark, affinity statuses or class casting.

| Public operation | Contract |
|---|---|
| `grace_active()`, `grace_until_ms()` | Decide whether an otherwise valid incoming hit is refused by grace; provide the existing host damage-flash deadline. Life/source/epoch validation remains in IncomingPlayerHit and its callers. |
| `slow_needs_prevention(now_ms, duration_ms)` | Only a positive Slow extending the existing deadline may ask OracleOmens to consume Quiet Ground. The state owner never selects or copies Omen grants. |
| `after_hit(now_ms, slow_ms, grace_ms, slow_prevented)` | Return a successor and explicit `slow_applied` feedback. Preserve the current rule: shorter/equal Slow replaces the deadline without consuming Quiet Ground. Grace is set for a valid unblocked contact even when Bark absorbs its HP damage. Blocked, grace-rejected and stale contacts never enter this operation. |
| `cleanse_slow()`, `slow_active()`, `slow_until_ms()`, `movement_scale()` | Cleanse ordinary Slow alone; supply one movement calculation to walking and the existing motion projection. Spiritstride, Guard speed and native Ranger speed retain their separate composition. No attack-speed or cooldown effect is added. |
| `with_grace_until()`, `with_slow_until()`, `clear_grace()`, `clear_all()` | Explicit validated deadline changes and immutable fixture setup. Entry clears grace, revival replaces grace, and Garden return clears both. Fall and ordinary floor travel retain their prior deadlines; revival does not cleanse Slow. |
| `rules_contract()` | Return detached tuning facts for the gameplay-definition handshake. No component is serialized into a permanent profile or the network snapshot. |

The incoming path remains captured life validation → grace rejection → Guard/Ward → mitigation/Bark → accepted contact aftermath → PlayerVitals → life/response handling. IncomingPlayerHit owns coordination and feedback; PlayerHitConditions owns deadlines and the Slow replacement rule; OracleOmens owns the accepted one-use prevention. `CombatStatus.incoming_grace()` and its two unrestricted callbacks are retired. IncomingPlayerHit no longer loads CombatDirector solely to read a tuning value. The status presentation cache and guest `client_hurt_until` flash are detached projections, not competing host authorities.

Tune these values in [`assets/content/balance.json`](../assets/content/balance.json), under `combat`: `hit_grace_ms` remains **220 ms**; the former inline revival value is `revival_grace_ms: 1500`; the two former inline Slow multipliers are one `player_slow_movement_scale: 0.6`. Existing values elsewhere in that JSON are unchanged. Enemy-authored Slow durations and class/affinity cleanse footprints remain in their existing definitions/handlers. No balance or save schema changed.

`combat_ruleset.gd` deliberately includes the three condition rules in its definition signature, so peers with different tuning are refused. This changes the gameplay-definition hash; it does not change the ruleset ID, RPC contract, protocol-41 packet layout or fast-state cadence. Same-build matching and specific definition-mismatch cases are verified separately.

| Measurement across the twelve affected runtime GDScript files | Before | After |
|---|---:|---:|
| Raw selected actor-field access sites | 21 | 0 |
| Authoritative raw actor deadlines | 2 | 0 (one typed component) |
| Owner Game/Node/actor-dictionary inputs or metadata accesses | — | 0 |
| Game lines / functions / plain top-level variables | 4,477 / 256 / 154 | 4,478 / 256 / 154 |
| Direct `game.players` references in those modules | 76 | 76 |

The one added Game line attaches the new owner type. This is a completed state/behavior boundary, not a large Game extraction: the 21 access sites become explicit owner operations, and actor lookup, health/class adapters and world orchestration remain coupled. One replaced normalization overlay is retired; four current fragments are reanchored while their historical baseline strings remain unchanged. No current test is deleted. An older sustain fixture's inert raw Guard reset is also migrated to PlayerProtection while updating its grace setup.

Focused verification on 2026-11-18 passed **31 current source suites / 42 fixture-process verdicts**, including seven independent two-player pairs and mixed-class four-player combat with fifth-client refusal. The matching-build control joined and passed authoritative action readiness; the bad-definition guest received the specific ruleset refusal with zero authenticated guests/admissions. All six before-change controls (seven peer verdicts), 39 migrated-fixture compile checks and 106 validation-tool self-tests passed. There were no failing gameplay verdicts. The final owner unit assertion was refined to follow tunable configuration, then only that unit was repeated. All final source keys match the live source and every fixture used verified disposable storage. Registry size is 218 → 219; the shared actor/content wiring invalidates all 219 source keys. Only these focused checks were refreshed; broad release evidence remains separately scheduled. No export, production activation, rendered desktop or separate-PC/internet acceptance is claimed.

The recovery tag `architecture/pre-player-hit-conditions` preserves `517a82e8d6f4314e3f5dba1beddcf82f80fa0ca6`. Main, protected tags, six design references and real saves remain untouched. Production AC-06 activation stays off. Remaining runtime work includes Core/class cast admission and queues, other source-owned status records, actor lookup and world/session adapters. Those are separate boundaries; this component is not a general player/status manager.

## Persistence modes and compatibility

| Mode | What actually happens |
|---|---|
| Isolated experimental playtesting | The source launcher gives the game disposable `APPDATA` and a matching marker. The existing playtest.8 candidate uses a verified version-specific save root; it is not an approved release tag. These modes have no write access through the game to the normal player save set. They **do write** guarded Garden and character files, preferences and diagnostics inside their own roots. Legacy import and experimental Garden Continue are disabled. The generated Garden layout belongs to the host session. Graft receipts, cards and wallets are run-only. A refused root stops title admission. |
| Temporary persistence fixtures | The validation executor supplies separate throwaway profiles. Fixtures open, write, corrupt or inject faults only against controlled files. Tests of the candidate production route enable it through the headless validation hook. |
| Ordinary production route | The contained production serializer route remains in place, independently of modern gameplay. `persistence_writer_integration.gd` keeps production AC-06 cutover off. The guarded candidate and explicit recovery remain available to controlled fixtures. |

The original AC-06 split-commit bug was dropped serializer return codes. The legacy wrapper now records each required serializer's result before commit. The guarded path latches the first participating failure and protects canonical publication. `serializer_integrity` passed before and after AR01, including early serializer refusals. This verifies that failure path. Production cutover, any new migration and ambiguous historical journal handling still require their own verification. See [serializer integrity](AC06_STAGE_A1_SERIALIZER_INTEGRITY.md).

AR01 through AR14 establish owners for run or host-session state and use the existing save schema. Keep real historical profiles and Gardens intact. Before any future cutover, establish which real schemas must remain readable and preserve their originals. Where needed, convert those fields with a bounded, versioned migration and disposable fixtures. An obsolete experimental save set does not by itself justify retaining the old gameplay runtime.

## AC-06 deployment boundary

Scope clarification from the user, 2026-11-18: host-crash expedition recovery and guest mid-run crash/reconnect recovery are deferred features. Loss of rewards that have not reached a supported save boundary is an accepted current limitation, **not an AC-06 completion blocker**. Existing journal recovery of an interrupted save transaction remains in scope; it does not resume the expedition or recreate host-memory reward receipts. AC-06 must protect the saves attempted at the supported settlement points, report failure truthfully, preserve committed outcomes, and avoid duplicate grants.

The stated gameplay contract banks XP at floor completion, player death, and run end. The approved 2026-11-18 voluntary-forfeiture rule now revokes the entire current run, including prior floor-bank XP; Returning Mycelium courier deliveries are a protected exception. The remaining death-timing distinction is explicit below:

| Boundary | Current implementation and distinction |
|---|---|
| Floor completion | `game.gd::finish_combat()` calls `settle_expedition_rewards(effects, true)` before the guarded clear outcome. Active experimental floors defer permanent kill awards between settlement points through `_defers_kill_profiles()` and `flush_kill_rewards()`. |
| Player death/fall | `expedition_life.gd::down()` records a revivable fall. When no living expedition players remain, it invokes `ExpeditionTransitions.commit_failed()`/`finish_failed()`, which banks pending rewards. A fall while teammates remain alive is not an independent XP-bank call. Clarify whether "player death" means this revivable fall or the final failed-run outcome before changing the timing. |
| Extraction and failed run | `expedition_transitions.gd::commit_checkpoint()` on extraction and `commit_failed()` bank pending rewards. Run currency and acquisitions retain their existing expedition-only lifecycle. |
| Voluntary abandonment | `ExpeditionTransitions.abandon()` restores the character's pre-entry all-class XP and monster familiarity, removes their unbanked receipt rows, and discards carried items, safe pouch, Essence, cards and graft acquisitions. Pre-entry investments and already delivered courier items remain. Teammates' pending rewards still settle normally. |
| Title return, Leave Session and normal window close | The same forfeiture applies to the voluntarily leaving character. A live guest sends a connection-scoped exit nonce and waits for the host's committed profile correction to save locally before closing; a Garden snapshot alone is insufficient. Aborted saves keep the exit pending and permit a safe retry. Uncertain outcomes remain held. A voluntarily exiting host forfeits only the host's progression; other party members keep the existing involuntary failed-run settlement. |
| Guest disconnect/rejoin | `session_world.gd::admission_error()` rejects admission while the expedition is active. Garden rejoin, profile acknowledgment/reconciliation, and pending-settlement holds are supported boundaries, not mid-run reconnection. `server_disconnected()` leaves the session; it does not restore the host's expedition. |

Normal supported co-op acceptance still applies. No active-run reconnect, host migration, durable per-kill journal, or crash-resume requirement is added to AC-06. Run baselines intentionally remain in host memory. A forced process termination can therefore bypass a not-yet-accepted voluntary exit; crash recovery is deferred, not represented as enforced forfeiture.

Forfeiture is part of the existing paired save boundary. A verified abort restores profile counters, receipts, participation and the claim; committed cleanup-pending outcomes are not replayed; uncertainty blocks further writes. Guest correction uses the existing ordered `receive_character` projection and revision/digest checks, so an older higher-XP floor profile cannot restore revoked progress. Only the reliable profile envelope adds a departure receipt. `network_contract.gd` declares `expedition_abandonment_forfeiture: 1`; protocol 41, RPC signatures and compact snapshot layout remain unchanged. Older capability signatures are rejected.

Focused ownership/lifecycle coverage: `expedition_forfeiture` (real guarded entry, earlier-floor and pending XP, all-class preservation, courier, wipe, Title/window-close notifications, abort/retry, cleanup and uncertainty); `expedition_forfeiture_coop` (independent host/guest, canonical downward projection, failed guest save, stale prior profile and retry before exit). These inherit source-only fixture setup; they are not new packaged or manual desktop evidence. Existing `monster_rewards`, `guarded_expedition`, `guest_projection_coop`, `candidate_release_party`, `playable_solo` and `ec01_affinity_cards` retain their respective controls. 2026-11-18 focused source verification passed 19 suites / 26 independent fixture processes, including two- and four-player loopback plus fifth-client refusal, and 106 validation-tool self-tests. The contained writer's actual abandonment/abort/retry is covered by `monster_rewards`; direct inventory, revival, Garden-return, party-vote and graft callers also passed. The registry grew from 214 to 216 suites. The conservative affected plan lists 211 suites because the explicit network capability and shared integration paths changed; that is an evidence-invalidation cost, not a claim that all 211 were run. Broad release evidence refresh remains a separately scheduled task. No Windows export, manual desktop play or separate-PC/internet verification was performed for this patch.


The original first-error serializer defect is fixed. Stage A2 also implements source-attributed guest projection receipts and acknowledgments; it is no longer an unimplemented prerequisite. F6 records historical writer acceptance, while the current focused checks cover the modern title, transactions, recovery, and guest lifecycle. **Production activation remains NO-GO.** `PRODUCTION_CUTOVER_APPROVED` is false and both verification collections remain empty. Local evidence must not be relabeled as desktop or separate-PC acceptance.

| Responsibility | Authoritative location and interface |
|---|---|
| Physical guarded-root identity | [`persistence_root.gd`](../persistence_root.gd): `location_error`, `valid_marker`, `policy_digest`, `prepare`. It has no mutable runtime state and never receives Game. It validates the default account Roaming parent, separate root name, native filesystem gate, and root identity before canonical startup. A fresh root can contain only known engine cache/startup-log data. Existing unmarked save directories and malformed markers are preserved and refused. |
| Root name, schema, and offline limits | [`assets/content/save_cutover.json`](../assets/content/save_cutover.json). Proposed production root: `%USERPROFILE%/AppData/Roaming/Mystical Garden Guarded 1`. The normal project still selects `Mystical Garden Prototype`; this checkpoint neither changes it nor creates the proposed real root. Identity depends on schema/name/marker, independently of JSON formatting and operational file/byte limits. |
| Explicit offline copy | [`tools/save_cutover.py`](../tools/save_cutover.py): `inspect_backup`, `stage`, `verify`. It reads a quiescent backup, checks a reviewed SHA-256 manifest, verifies each copied file, and publishes by a no-replace NTFS directory rename. Complete matching stages resume; incomplete/foreign evidence refuses without deletion. An already published root is never reimported over later progress. No schema conversion, recovery, live-root source selection, automatic migration, or production activation occurs here. |
| Activation sign-off | [`persistence_writer_integration.gd`](../persistence_writer_integration.gd): `evaluate_activation`, `activation_status`, `startup_refusal`. Each writer and named deployment requirement must be accounted for, plus explicit approval. Requirements are now satisfiable by reviewed evidence rather than appended unconditionally. An incompletely approved build refuses startup; it cannot fall back to contained legacy IO. Diagnostics, Title, and Developer entry check this boundary. |

For a **disposable rehearsal**, inspect an operator-selected quiescent backup and retain the plan outside both roots:

```powershell
python -B tools/save_cutover.py inspect 'BACKUP-PATH' --plan 'REVIEWED-PLAN.json'
python -B tools/save_cutover.py stage 'REVIEWED-PLAN.json' --manifest-sha256 'PRINTED-HASH' --destination 'DISPOSABLE-PARENT/Mystical Garden Guarded 1'
python -B tools/save_cutover.py verify 'REVIEWED-PLAN.json' --manifest-sha256 'PRINTED-HASH' --destination 'DISPOSABLE-PARENT/Mystical Garden Guarded 1'
```

Close the source game and use a separate quiescent backup, not a live save folder. The tool rejects known live source roots, recovery/lease artifacts, redirected or hard-linked files, unsupported local filesystems, case-sensitive ancestry, source drift, stale manifests, and conflicting destinations. Ambiguous copies remain available for operator review. The tool does not establish quiescence against an uncooperative old executable. Production rollout must preserve the original root and pre-cutover executable together. Rollback opens only that original pair; it does not copy newer guarded progress back into an older engine.

Focused ownership: `tests/persistence_cutover.gd` covers sign-off and location/identity contracts; explicit disposable modes cover native root initialization/refusal and a copied save entering the real guarded title. `tools/tests/test_save_cutover.py` covers interruption/restart, independent-process termination, concurrency, source/destination drift, links, and exact-copy/idempotence. Existing serializer, import/recovery, title, lifecycle, guest projection, Garden, expedition and candidate solo/party fixtures retain transaction coverage. The registry grows from 213 to 214 suites. The shared startup change predicts 206 related invalidations; this checkpoint runs the bounded 15-suite persistence plan. A broad source/package release evidence refresh remains separate.

Current deployment evidence is indexed outside the repository at `C:/Users/sutte/Documents/Codex/2026-11-05/referenced-chatgpt-conversation-this-is-an/work/ac06-deployment-20261118/verification.json`. It distinguishes accepted results, failed fixture attempts, original inputs, and restoration of the disposable project settings. No installed playtest or real saves were changed.

Targeted packaged-resource probes also pass: the same native root initialization/refusal and copied-save guarded-title admission ran against a temporary PCK with the matching DLL. These are Godot-console package checks, not a distributed EXE or a complete release verdict. The first staging export logged five `get_multiple_md5` errors during reimport and was rejected; one populated-cache export passed the unchanged strict diagnostic checks. Both attempts are retained.

Remaining acceptance: complete current Windows release writer/startup evidence, manual desktop recovery and actual window-close/relaunch, separate-PC co-op, an operator-approved real backup/migration/rollback plan, and explicit production cutover approval. `VERIFIED_REQUIREMENTS` keeps those decisions visible. Loss of host-memory rewards before a supported settlement is accepted for the current design; crash-resume and mid-run reconnection are deferred and do not block AC-06. No durable per-kill reward journal is required for this checkpoint. Process-termination tests do not establish sudden power-loss durability. Keep the broader AC-06 item open until those deployment gates are genuinely satisfied, and do not continue the next architectural extraction automatically.

## Where to change things

| Change | Start here |
|---|---|
| Card number, rarity range or offer balance | [`affinity_card_catalog.gd`](../affinity_card_catalog.gd) owns the affinity catalog. Search for the displayed title, such as `Honed Strikes` or `Light Grip`, and edit `values` in Common, Uncommon, Rare, Epic order. Unique entries use `fixed`. Read `unit`, `limit`, `parameter` and `consumer` in the same entry. `PLAYTEST` holds the acquisition limit, rarity curve and reroll prices. The ledger owns acquisition. `affinity_cards.gd` formats views and connects card effects to combat. There is no separate legacy catalog. |
| Session admission, peer ownership and native request identity | [`network_session.gd`](../network_session.gd) owns peers, roles, four-player capacity and request budgets; [`session_world.gd`](../session_world.gd) implements admission, profile checks, reconnect, disconnect and leave. [`network_contract.gd`](../network_contract.gd) declares RPC/capability compatibility. [`network_action_identity.gd`](../network_action_identity.gd) builds connection/character/life/world stamps; Game keeps the RPC facades. Keep settlement holds in `departure_settlement.gd`. |
| Expedition participants and floor travel | [`expedition_participation.gd`](../expedition_participation.gd) owns membership, floor identity and consent. [`expedition_transitions.gd`](../expedition_transitions.gd) integrates entry, advancement, partial return, extraction and reset. [`party_travel.gd`](../party_travel.gd) validates gate readiness, signature changes and existing checkpoint cadence. Keep rewards and ledger tuning in their owners. |
| Expedition Essence and kill rewards | [`expedition_wallet.gd`](../expedition_wallet.gd) owns the fixed Essence award per cleared floor. [`game_balance.gd`](../game_balance.gd) resolves combat tuning for sparks per kill and sparks per Essence. [`monster_rewards.gd`](../monster_rewards.gd) owns kill receipt identity, frozen awards and settlement phases. `game.gd` applies awards and `game_transaction.gd` connects savepoints to actual save outcomes. Change card reroll prices in `affinity_card_catalog.gd`. |
| Persistence-session holds, cleanup feedback and shutdown | [`guarded_title_session.gd`](../guarded_title_session.gd) owns state transitions and notices. `game_transaction.gd` supplies the actual finalization; `main_menu.gd` owns only a detached return view. Keep physical transaction/recovery rules in `save_batch.gd` and `persistence_operations.gd`. |
| Guarded disconnect settlement and rejoin holds | [`departure_settlement.gd`](../departure_settlement.gd) owns the pending payload and reconnect hold. [`game.gd`](../game.gd) captures the payload in `_capture_pending_departure()` and translates the guarded persistence verdict in `_resolve_departure_settlement()`. |
| Class abilities, weapon stats and tree nodes | [`class_catalog.gd`](../class_catalog.gd) defines class/weapon baselines. [`skill_catalog.gd`](../skill_catalog.gd) and `subclass_catalog.gd` define the native actions and focuses. The `warden_connected_tree.gd`, `weaver_connected_tree.gd`, `ranger_connected_tree.gd`, `reaper_connected_tree.gd` and `oracle_connected_tree.gd` files define selections for each class. Find the named mechanic in the tree, then follow its handler when it has execution-specific tuning. |
| Player HP and capacity | [`player_vitals.gd`](../player_vitals.gd) owns live HP and capacity. [`combat_vitals.gd`](../combat_vitals.gd) and [`combat_balance_preview.gd`](../combat_balance_preview.gd) own HP units and capacity math. `expedition_life.gd` resolves life loss and revival. `vital_combat.gd` controls temporary Vital grants. |
| Player life identity and falling | [`player_lifecycle.gd`](../player_lifecycle.gd) owns the host generation and fallen flag. [`expedition_life.gd`](../expedition_life.gd) applies fall and revival through gameplay. `network_session.gd` authorizes the actor and `game.gd` constructs its record; `expedition_transitions.gd` integrates Garden return and expedition entry, governed by `expedition_participation.gd`. |
| Native ability or dodge cooldown | Start with [`skill_catalog.gd`](../skill_catalog.gd) and [`class_skill_balance.gd`](../class_skill_balance.gd) for authored Q/R durations and the cast floor. Connected-class modules own their node-specific refunds. `game.gd` resolves dodge recovery with weapon, class and card contributions. [`player_cooldowns.gd`](../player_cooldowns.gd) owns timing and projection after those values resolve. |
| Basic attack recovery, aim and animation | [`class_catalog.gd`](../class_catalog.gd) owns each weapon's `strike_ms`; cards and grafts retain their own modifiers. [`assets/characters/weapon_actions.json`](../assets/characters/weapon_actions.json) owns clip duration in seconds, release fraction, delivery and visual clip names. [`weapon_motion.gd::basic_duration_ms()`](../weapon_motion.gd) owns the unchanged pose limits (180 ms minimum, 90% of resolved interval maximum, 240 ms fallback/pulse). [`player_weapon_actions.gd`](../player_weapon_actions.gd) owns the resulting milliseconds, sequence and committed aim. Change authored values in their definition; use owner operations to change live state. |
| Plant families and materials | [`plant_affinities.gd`](../plant_affinities.gd) maps stable plant IDs to affinities. `seed_catalog.gd` and `weapon_parts.gd` own species and material identity. `combat_ruleset.gd` maps family names to their behavior scripts. In those scripts, find timing, geometry and potency constants for Core, Form and Catalyst. |
| Graft price, limit, reinforcement or adaptation | [`expedition_grafts.gd`](../expedition_grafts.gd) holds the definitions, trophy requirements, costs and caps. Reach values are hundredths of a metre and cooldown values are milliseconds. [`native_grafts.gd`](../native_grafts.gd) holds the trigger and timing data for native adaptation effects. It queues their execution through combat handlers. Check the author-facing description with any numerical change. |
| Monster attack range or timing | Start in [assets/enemies/catalog.json](../assets/enemies/catalog.json) with the species ID and its `range`, `windup`, and `recovery`. [combat_director.gd](../combat_director.gd), [enemy_balance.gd](../enemy_balance.gd), and [encounter_config.gd](../encounter_config.gd) apply runtime modifiers. [enemy_attack.gd](../enemy_attack.gd) owns attack shapes and telegraphs. |
| Ordinary attack scheduling and contact | [scout_behavior.gd](../scout_behavior.gd) validates tactical intent, [enemy_attack.gd](../enemy_attack.gd) owns the commitment and due beat, and [enemy_attack_hits.gd](../enemy_attack_hits.gd) resolves hit geometry before passing a life-bound contact to the incoming player hit resolver. |
| Ordinary Slow, contact/revival grace and cleansing | [`assets/content/balance.json`](../assets/content/balance.json), `combat.hit_grace_ms`, `combat.revival_grace_ms`, and `combat.player_slow_movement_scale` are the tuning authority. [`player_hit_conditions.gd`](../player_hit_conditions.gd) owns deadlines and replacement rules; [`incoming_player_hit.gd`](../incoming_player_hit.gd) coordinates a validated contact; [`oracle_omens.gd`](../oracle_omens.gd) owns Quiet Ground. Do not recreate raw actor deadlines or repurpose a botanical status. |
| Native Guard, Ward and counters | [`player_protection.gd`](../player_protection.gd) owns resolved deadlines, charges and claims. [`class_skill_balance.gd`](../class_skill_balance.gd) owns common native limits and directional parameters; starting skill values remain in [`warden_tree.gd`](../warden_tree.gd), [`subclass_catalog.gd`](../subclass_catalog.gd) and their connected-tree handlers. [`ward_responses.gd`](../ward_responses.gd) only publishes the chosen captured response. |
| Incoming defense and health outcomes | [incoming_player_hit.gd](../incoming_player_hit.gd) owns the sequence. Tune hit grace in [assets/content/balance.json](../assets/content/balance.json) under `combat.hit_grace_ms`. [player_protection.gd](../player_protection.gd) owns Guard/Ward and native counters, [combat_action_events.gd](../combat_action_events.gd) captures source events, [ward_responses.gd](../ward_responses.gd) publishes the selected response, and [wood_affinity.gd](../wood_affinity.gd) owns Bark absorption. Class and affinity response values live with their handlers. |
| A specific monster's behavior | Find its catalog `role` and inspect [enemy_behaviors.gd](../enemy_behaviors.gd), [enemy_variants.gd](../enemy_variants.gd) or [enemy_skill_responses.gd](../enemy_skill_responses.gd). Support, corpse use, and brood roles use [enemy_support.gd](../enemy_support.gd). |
| Elite or boss phase | Edit gate-elite overrides and signature moves in [elite_enemy.gd](../elite_enemy.gd). [boss_encounters.gd](../boss_encounters.gd) dispatches phase and lair mechanics to [boss_phase_fights.gd](../boss_phase_fights.gd) and [boss_lair_fights.gd](../boss_lair_fights.gd). |
| Monster model | [stage.gd](../stage.gd) loads `assets/enemies/<id>.glb`. The Rootbound Pilgrim uses [rootbound.glb](../assets/enemies/rootbound.glb). Preserve its rig and authored animation names. |
| New enemy behavior | Add the specialization beside the existing role or variant and dispatch through the relevant behavior owner. For ordinary scout decisions, start at [ScoutBehavior](../scout_behavior.gd)'s observation and intent methods and reuse [EnemyAttack](../enemy_attack.gd) for validation geometry and telegraphs. Extend a focused role fixture and its coverage domain. |
| Player, weapon or plant visuals | `traveller_avatar.gd` selects player rigs under `assets/characters/`. `weapon_visuals.gd` and `plant_weapon_models.gd` map weapon appearances to `assets/weapons/`. Garden crop meshes are currently authored procedurally in `stage.gd` (`build_crop` and `build_lineage_crop`). Crop inspection and icons belong to `garden_crop_view.gd` and the item catalog. |
| Terrain and effect visuals | [`terrain_feature_view.gd`](../assets/terrain_m02/terrain_feature_view.gd) maps vegetation and props to imported assets, including `assets/garden/field/`. `terrain_heart_preview.gd` uses `assets/terrain_m02/garden_heart.glb`. Use `core_skill_visuals.gd`, `status_feedback.gd` and `combat_feedback.gd` for effect presentation. Terrain collision belongs to `wilds_play_surface.gd` and feature geometry. Artistic replacement does not require tuning those rules unless the authored footprint itself changes. |

## Tests and next ownership changes

| Lane | Scope |
|---|---|
| Normal development | Run the focused domain fixture plus one real integration at the boundary being edited. For grafts, `cr05_native_grafts` checks the ledger, authoritative debit, caps, lifecycle and rollback. `ec01_affinity_cards` checks offer transitions, receipt isolation, eligibility, rarity, Essence and live card effects, including graft interactions. `ec01_affinity_cards_party` checks owner-visible offers and receipts, floor travel and cleanup over four-player loopback. Use the graft party fixture when changes affect shared combat or owner publication. |
| Historical data conversion | `modern_gameplay_cutover`, content-ID/profile fixtures and connected-class tests protect archived masks, XP, loadouts and explicit Heart refunds. Retired gameplay suites are removed; their current transaction, HUD, terrain and networking contracts remain in focused modern fixtures. |
| Extended verification | Keep four-player overflow, replay/rejoin, serializer fault matrices, snapshot byte budgets, broad affinity checks and source/package acceptance here. The two-player and party graft harnesses share substantial setup and assertions. Running both by default adds overlapping coverage. |

No suites were deleted in AR01. Existing fixtures use detached receipts and real commands, including the card fixture's graft setup. The baseline's roster, stats and dual-skill fixtures were repaired at `a4eed496` because their expected XP, stat label or spell event had aged out. Their original contracts were still valid. The planner uses explicit systems, literal resource links and exact scoped fragments of Game functions. Scoped wiring must match after earlier regions normalize. The cutover goal is to attach tests to an owner's files and real interfaces instead of maintaining many exact Game fragments.

Next narrow the actor registry and world integration: SessionWorld and ExpeditionTransitions still coordinate live actor dictionaries, profile publication and scene transitions through Game. Accepted snapshot/detail assembly and combat-effect scheduling remain sizable separate boundaries. Do not move reward settlement or persistence ownership into the session registry. Preserve the dedicated production AC-06 cutover and recovery work; do not disguise it as a participation change.

The planner ignores only Godot's recognized native-lock hot-reload copies in `assets/native/persistence_lock/`. The authoritative `b0_native_lock.dll`, extension definition, and other assets remain hashed. A focused Python fixture verifies both that exclusion and authoritative-DLL invalidation. This allows source checks while an editor holds its generated DLL copy; it does not suppress native loading errors in gameplay verdicts.

The gameplay cutover retires 26 fixtures dedicated to obsolete species, mask, priced-card or installed-graft behavior. Mixed fixtures retain current contracts; `playable.gd` is a focused modern smoke instead of the historical all-mechanics matrix. Keep provenance/recording checks distinct from actual integrated combat and independent process loopback. See `modern_gameplay_cutover`, `cr02_combat_contracts`, CT01–CT05, EC01, current graft tests, `projectile_terrain`, and guarded transaction/network fixtures.

## Validation ownership

`tools/test_map.json` is the human-edited authority for suite coverage, systems and isolated fixture profiles. `tools/validation_scope_matches.json` holds only retained exact source anchors and normalization baselines; `validation_registry.py` validates and joins them. Do not copy ownership into that matching file or regenerate its baselines indiscriminately.

`validation_inputs.py` separates source execution keys from package preparation and raw mid-run stability. `validation_execution.py` owns peer processes, isolated profiles, strict structured verdicts and error checks. `packaged_fixture_support.py` owns package-only external helper staging. `test_workflow.py` owns resource/region coverage, planning and cache verification. `playtest_release.py` summarizes all active suites, preserves retired cache history and archives current evidence. See [VALIDATION_WORKFLOW.md](VALIDATION_WORKFLOW.md) for editing locations, scoped previews and the explicit format-2 evidence epoch.

The focused tool tests live under `tools/tests/`. They cover retirement without unrelated rekeys, explicit environments, source/package separation, current-versus-retired cache rows, unchanged log hashes and rejection of mid-run edits. This tooling change does not refresh all gameplay or packaged acceptance evidence. Preserve current failures and schedule any broad release refresh separately.

## Contributing

1. Verify the branch, status and baseline. Follow the displayed name to the authored definition, then the stable ID to its readers and writers. Search existing `res://` references before changing a scene or model. Preserve unrelated work.
2. Keep one text definition for each gameplay value where possible. Prefer readable GDScript constants or JSON records with stable IDs and named units such as HP, milliseconds or metres. Let previews resolve the same numbers as gameplay. Keep visuals with their scene/model consumers and separate from balancing data. Preserve paths while extracting ownership and move assets when a specific owner can verify imports, rig and collision contracts.
3. Change the owner first and pass explicit inputs or detached results across the boundary. Add or update focused tests and `tools/test_map.json`, then regenerate [the coverage map](MECHANICS_TEST_MAP.md) if its source changed. Use `tools/validate_release.ps1 -PlanOnly` to inspect affected consumers. See [the validation workflow](VALIDATION_WORKFLOW.md) for isolated checks and release evidence.
4. Review a focused Git diff. Commit one understandable change with a descriptive message. Keep unrelated formatting, generated artifacts and local design references out of the commit. In the handoff, name the changed files, affected systems, verified cases and any remaining gap so another contributor can review or continue the work from Git.
