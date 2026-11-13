# AC-06 B0 Group 3B-2A · Guarded Garden actions

## Baseline and scope

The local branch `ac06/persistence` was clean at `f72ef17086de2b5a1f92d73dc196a74b7624f69c`. That is the verified Group 3B-1 feedback correction above `56da0c1ab18f4f0b103ca0272e0aca6e1405eead`. The baseline check matched 1,243 inputs against the prior disposable project and manifest, then independently rechecked 75 structured verdicts and 105 exits. Those results establish the baseline. Current verification uses new runs.

`main_menu.gd` retains its legacy startup default. `persistence_writer_integration.gd` retains `PRODUCTION_CUTOVER_APPROVED = false` and an empty `VERIFIED_WRITERS` list. The changes below apply to explicitly opted-in worlds. The installed executable, native DLL, and player save data were outside the test and installation paths.

## Caller inventory

**G** is the canonical host Garden, **P** is the selected local host profile, and **J** is the canonical guest-owned profile. Host-side guest actions only write G. The guest's existing profile projection receiver independently writes J under its own lease.

| Action | Actual guarded entry points | Participants and publication |
|---|---|---|
| Experiments and breeding | `game.gd::garden_action/_garden_action/run_seed_experiment`, `progress.gd::experiment/breed` | G, including stock, discovery, failed-breed salvage and attempted pair. Report the outcome after verified commitment. |
| Altar combination and identification | `game.gd::handle_altar_action/run_altar_save`, `altar_service.gd::combine/identify/identify_all` | G. Combination queues the successful-save diagnostic after commitment. Identification uses the Group 3B-1 boundary. A view refresh does not certify a save. |
| Seed and part donations | `game.gd::donate_part/_donate_part/handle_inventory_action`, `inventory_model.gd::transfer` | G. Personal-to-shared seed and part stacks already use the guarded inventory transfer. The legacy Heart part donation now uses the same Garden authority in opted-in sessions. The retired `care_donate` command stays retired. |
| Reclamation and trophy offerings | `game.gd::reclaim_seed/_reclaim_seed/offer_monster/_offer_monster` | G, including the selected ingredient, personal and shared stock, offering record and Knowledge. Success notices follow commitment. |
| Parts and flowering harvest | `game.gd::harvest/harvest_guarded/_harvest/report_harvest`, `garden_crop_service.gd::command/harvest_seeds` | Local actor G+P. Guest actor G, including the Garden's record of guest familiarity and any personal Garden seed reward. Profile projection, reward text, sound and successful harvest diagnostics follow host commitment. Bed-cycle/revision validation and the empty-bed check prevent repeated crop credit. |
| Grafting | `game.gd::attempt_graft/_attempt_graft/graft_feedback` | G for the permanent trophy discovery. The runtime graft, carried part, health adjustment and RNG are in the snapshot. A failed graft still consumes its part after a confirmed transaction. Its feedback and roll diagnostic follow the result. |
| Upgrade purchase and card selection | `game.gd::buy_upgrade/_buy_upgrade/choose_checkpoint_card` | G for first permanent Rift Hook discovery. The live expedition card, rank, essence and stats retain their existing run-only lifetime. Rank feedback and the metric follow commitment. The guarded selection closes its panel without advancing the floor. |
| Courier banking | `game.gd::bank_checkpoint_item/_bank_checkpoint_item`, `garden_return_service.gd::bank` | G, including reserve and return discovery. Checkpoint proximity and per-actor one-deposit limit still apply. |
| Garden ground stacks | `game.gd::drop_inventory_stack/_drop_inventory_stack/pickup_inventory_drop/_pickup_inventory_drop` | G, including the stock and ground-item identity. A repeated pickup cannot credit a removed stack. Wilds ground stacks remain runtime-only. |
| Recollection | `game.gd::consider_recollection`, `heart_progress.gd::serialize/restore` | G for the seen flag, before the overlay and guest notice. The existing retired-finale switch is false. The dormant write route is guarded and the fixture checks it does not reopen the finale. |
| Class selection, learn and respec | `game.gd::select_class/_select_class/handle_loadout_action/_apply_loadout_action` | G+P for host, G then J projection for guest. Class profile and host record commit before success text or profile delivery. |
| Loadout and reservations | `game.gd::cycle_slot/_cycle_slot/persist_loadout/handle_loadout_action/show_gate_preparation/save_action_profile/send_committed_profile/receive_character` | G+P for host, G then J projection for guest. Reconcile changes before opening crafting. Existing shared reservations remain runtime constraints. The packing plan is runtime-only until the deferred departure. |

`game.gd::run_guarded_action` collects the existing feedback calls for a single guarded action and dispatches them once on typed canonical commitment. It distinguishes authorization, business result and persistence outcome. `GameTransaction.run_gameplay` and its existing Group 1 serializers own lease checks, the locked plan and snapshots. A verified abort restores gameplay memory and RNG. Uncertainty retains tentative memory and recovery artifacts and prevents replay. Confirmed cleanup-pending retains new bytes and memory and permits truthful feedback alongside a persistent warning. On the guest, that host Garden warning remains visible alongside later messages without treating the guest's local profile as pending. An ordinary host snapshot or a diagnostic request entry is not a persistence receipt.

## Guest delivery and remaining work

- The existing reliable, ordered `receive_character` RPC carries the projection only after host commitment. Identical current projections are ignored on the opted-in receiver. Host success describes the harvest in the host Garden. It does not establish receipt or a committed guest-profile save.
- `register_character` already reconciles monotonic familiarity from the host's saved character record on reconnect. The co-op fixture independently verified a guest profile-stage refusal followed by reconnect, with no replay or second reward. It also verifies duplicated crop commands and identical profile projection delivery. Arbitrary historical projection replay and durable acknowledgment of non-monotonic guest changes such as respec remain outside this protocol. Stage A still owns the outstanding guest acknowledgment contract and other serializer/publication coverage.
- Group 3B-2B still owns combat settlement, monster reward flushing, revival, expedition departure, checkpoint advance and extraction, abandon/wipe settlement and their effects. Guarded testing places the actor at a checkpoint to exercise purchases and courier without invoking those paths. Group 3C still owns the remaining lifecycle and direct-writer cutover checks. Remote appearance and other Group 3B-1 deferrals outside this inventory retain their earlier behavior.
- The tests use local NTFS and isolated Windows save roots. They do not establish WAN delivery, power-loss durability, or a stable release. There was no full-suite release gate run.

## Verification

Godot `4.7.2.stable.official.ed1daf0bf`. **55 source verdicts, 56 packaged verdicts, and 149 zero-exit process results** independently checked with the existing AC-01 validator. The focused registry preview selected 112 of 157 registered suites because shared dispatcher and transaction inputs changed. The checkpoint ran the directly affected Garden, class/loadout, crafting, graft, card, inventory, startup and network fixtures plus Groups 1, 2A, 2B, 3A and 3B-1 and B1/B2 controls. The four-player fixture passed for host, all three guests and the overflow rejection in both modes. All 53 planner self-tests passed. Group 3B-1 cleanup and late-disconnect/profile controls passed against the current runtime. The preserved Garden-growth co-op fixture again proved offline replacement before world removal.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| Guarded Garden actions | `g32a-source-guarded-garden-actions-final-normalized` | `g32a-pack-guarded-garden-actions-final-normalized` |
| Guarded Garden co-op | `g32a-source-guarded-garden-actions-coop-final-controlled` | `g32a-pack-guarded-garden-actions-coop-final-controlled` |
| Group 3B-1 | `g32a-source-guarded-gameplay-transactions-final-units` | `g32a-pack-guarded-gameplay-transactions-final-units` |
| Four players | `g32a-source-four-players-coop-final-network` | `g32a-pack-four-players-coop-final-network` |
| Package startup and exclusions | — | `g32a-pack-package-startup` |

The solo fixture records actual file digests and journal artifacts for the profile-stage refusal, confirmed harvest, cleanup-pending flowering, a split replacement with failed restoration, and foreign/expired lease and pending-journal refusals. It checks crop, familiarity, rewards, RNG, sound, UI, write refusal and B2 recovery. The co-op fixture starts real guarded host and guest worlds, uses real reliable loopback RPCs, and independently checks both exit verdicts. It also checks host-only and guest-only writes, order of class and weapon projections, reconnect after a guest save refusal and the persistent host cleanup warning.

Development probes remain in the disposable workspace. The first solo run had incorrect fixture assumptions about the staged destination, class node and lease filename. An early co-op run sent the next action before its fixture handshake. Later reconnect runs reproduced an admission race because the guest rejoined before the host processed the previous disconnect. A cleanup-pending host also shuts down via the deferred title path. The final fixture waits for both lifecycle transitions and checks the offline peer before freeing the world. A subsequent packaged probe correctly refused an action when both fixture peers shared one disposable root and a background heartbeat held the native lock. The final guarded fixture uses explicit barriers with unrelated per-frame saves and heartbeats disabled. Those failed probes were excluded from the passing index.

- [Tested-input manifest](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2a/TESTED_INPUTS.sha256>) covers 1,245 paths, including the runtime, assets, fixtures, registry, validator and native inputs. Manifest SHA-256 `bde713f380209d22a889c60801ceb0a1e8f900691dfca6a7e1b66b37673fbac2`.
- [All exact run IDs, verdict hashes and process results](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2a/VERIFIED_RUNS.json>) and [28 action evidence records with canonical digests and feedback](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2a/ACTION_EVIDENCE.json>).
- [Focused preview](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2a/plan-scoped.txt>) and [planner self-tests](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2a/planner-final.log>).
- Disposable Windows EXE SHA-256 `a87ab68fe652fa4d40847becfe08491bbe514353802f66e295ea1118e2b3c52e`.
- Native DLL SHA-256 `ad827586970b7d701af85007185fa2ef31213666add81674d47c3dab96370379`, identical in the baseline, source, package and validation sidecars.

Changed files are `game.gd`, `game_transaction.gd`, `garden_crop_service.gd`, `altar_service.gd`, the two guarded action fixtures, `tools/test_map.json`, the generated `docs/MECHANICS_TEST_MAP.md`, and this report. The checkpoint commit adds this report to the exact tested inputs and records the commit hash in the handoff.
