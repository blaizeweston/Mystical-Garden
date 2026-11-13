# AC-06 B0 Group 3B-2B · Guarded combat and expedition lifecycle

## Baseline

The starting branch `ac06/persistence` was clean at `cd003875cc9945176a321762fa6f21e86af73342`, the verified Group 3B-2A commit above `f72ef17086de2b5a1f92d73dc196a74b7624f69c`. The prerequisite audit compared 1,245 input hashes across the tested project, working tree and committed blobs, accounting for Git line-ending normalization. It also rechecked all 111 prerequisite verdicts. The evidence below uses the new implementation.

Production cutover remains disabled. `main_menu.gd` still defaults to legacy persistence, and `persistence_writer_integration.gd` retains an empty verified production writer list. The Heart finale stays retired. All execution used disposable saves and exports with Godot `4.7.2.stable.official.ed1daf0bf`.

## Migrated callers and publication

**G** means the host's canonical Garden. **P** is the host's selected local profile. **J** is the guest's own profile. Host settlement uses G+P. The host records guest progress in G and sends the existing reliable profile projection to a connected guest after commitment. Only the guest can write J.

| Operation | Functions | Mutation and effects |
|---|---|---|
| Kill receipts, rewards and progression | `game.gd::record_enemy_death/settle_expedition_rewards`, `monster_rewards.gd::queue/flush/settle/publish_notices` | The host records death and freezes the roll once per existing encounter/enemy receipt. G+P settle XP, monster familiarity, Garden character records, and runtime essence and owned drops. Reward text and profile projections follow commitment. Repeated flushes cannot recredit a consumed queue. Death animation and ordinary hit visuals are transient combat feedback. |
| Encounter completion | `game.gd::finish_combat/_finish_combat/record_settlement_metric` | The transaction settles pending rewards, adaptation observations and encounter progress. It commits the gate cue, loot eligibility, encounter message, and clear/learning metrics together. A floor or its rewards cannot be accepted by the guarded gate before settlement. |
| Damage and revival | `game.gd::apply_enemy_hit/apply_hit_grace/damage_player/_damage_player/revive_player`, `expedition_life.gd::down/revive`, `party_travel.gd::cancel` | Nonlethal hits and blocks are live-only under session ownership. The guarded lethal/downed path snapshots HP, grace, movement, readiness and combat events. Wipe, when triggered, settles inside the same action. Revival defers the notice and readiness effects and charges maximum health once. |
| Expedition departure | `game.gd::enter_wilds/_enter_wilds/start_encounter/reset_encounter`, `party_travel.gd::request/departure_cost`, `progress.gd::pay_shortcut` | G+P consume the existing loadout/cargo and route price and open the return record. One party decision controls every member. The owning Garden serializer stages the route cost. Floor state, entry notices and panel closure follow commitment. |
| Checkpoint and extraction | `game.gd::use_checkpoint/activate_checkpoint/_use_checkpoint/choose_checkpoint_card/buy_upgrade/resume_checkpoint_if_ready`, `party_travel.gd::request` | Card display is presentation. The existing guarded purchase commits before marking selection. Floor travel is a separate consent, using the current travel epoch. Advancement mutates map, healing and live encounter state. Extraction banks carried and safe items and records milestone, guardian and return progress. Both publish transition and closure after commitment. Guarded solo players use the gate again after selecting a card. |
| Safe pouch, wipe and abandonment | `game.gd::recover_pouch/_recover_pouch/return_to_garden/abandon_if_empty/finish_failed_expedition/_finish_failed_expedition/abandon_run`, `inventory_model.gd::bank_safe/bank_extra`, `garden_return_service.gd::bank/outcome` | Settlement preserves the existing distinction between wipe recovery and voluntarily forfeiting the pouch. Recovery and return bookkeeping share the owning transaction. Abandonment closes its panel only after commitment. |
| Disconnect and title/quit | `game.gd::remove_player/leave_game/return_to_main_menu/_notification/_finish_title_return/go_offline/allow_remote/admission_error` | Network membership is removed even if persistence is blocked. A still-owned disconnect preserves the detached actor's pending reward and pouch record until the transaction settles. Re-entry of the same identity waits for settlement. Lost ownership prevents secondary writes. Owned title/quit settles first. Transport goes offline before detachment and late profile callbacks remain subject to the guest lease. |
| Publication and rollback | `game.gd::run_guarded_action/send_expedition_state/publish_combat_event/snapshot_expedition_runtime/restore_expedition_runtime`, `game_transaction.gd::_run_guarded/_restore_guarded` | Only typed canonical commitment releases queued effects. The existing snapshots cover inventory, players and queues. Expedition rollback additionally restores the previous battlefield, map RNG, healing RNG, mouse state and core combat state. Cleanup-pending publishes the committed transition and retains the warning in the Garden or title. Uncertainty keeps tentative state and evidence, withholds success and freezes the last presented floor. |

## Remaining boundaries

- Guest XP and familiarity can reconcile monotonically using the existing saved host record. The host has no durable proof that the guest received or saved the projection. Stage A still owns that acknowledgment contract and remaining serializer/publication coverage. No RPC signatures or save formats changed.
- The existing combat and floor-event channels can deliver at different times. The fixture checks authoritative floor changes, stale and duplicate readiness, one-time rewards and the persistent cleanup warning. It does not prove WAN ordering or durable delivery. Per-run receipts and carried drops still have their existing expedition lifetime. The opt-in path requires an explicit gate interaction for the next floor after card selection.
- Group 3C still owns the production lifecycle/direct-writer audit, including settings and shared save-writer boundaries. The installed executable and native DLL were left untouched. No release or production activation was performed.

## Verification

The 53 planner self-tests passed. The focused preview selected 113 of 159 registered suites because the transaction module and dispatcher contract are shared. The checkpoint used affected combat, travel, inventory, adaptation, co-op and persistence regressions, including the Group 3B-1 and 3B-2A suites, plus packaged startup and exclusions. AC-01 independently checked both peers' structured verdicts, exits, and engine logs. The Garden growth co-op fixture confirmed AC-02 offline-before-removal ordering. The ordinary four-player fixture passed for host, three guests and the overflow rejection in both modes.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| Guarded expedition | `b2b-source-guarded-expedition-checkpoint-unit` | `b2b-pack-guarded-expedition-checkpoint-unit` |
| Guarded host and guest | `b2b-source-guarded-expedition-coop-checkpoint-pair` | `b2b-pack-guarded-expedition-coop-checkpoint-pair` |
| Group 3B-1 | `b2b-source-guarded-gameplay-transactions-checkpoint-unit` | `b2b-pack-guarded-gameplay-transactions-checkpoint-unit` |
| Group 3B-2A guarded co-op | `b2b-source-guarded-garden-actions-coop-checkpoint-pair` | `b2b-pack-guarded-garden-actions-coop-checkpoint-pair` |
| Forced termination at second replacement | `b2b-source-interruption-owner-checkpoint-interrupt` | `b2b-pack-interruption-owner-checkpoint-interrupt` |
| Restart recovery through the linked profile | `b2b-source-interruption-recover-checkpoint-interrupt` | `b2b-pack-interruption-recover-checkpoint-interrupt` |
| Package startup | — | `b2b-pack-package-startup-checkpoint-smoke` |

The final evidence contains 51 source verdicts, 52 packaged verdicts and 145 zero-exit fixture processes. In the separate termination cases, both deliberately killed owners exited 1 without completion results. Both recovery processes exited 0 with current structured PASS, restoring the original pair and removing the transaction artifacts after the normal lease expiry. These are process interruption tests on local NTFS.

The solo fixture verifies disk and runtime restoration after failed departure, encounter settlement and floor advance. It verifies no replay after uncertain extraction and committed cleanup-pending extraction, and records failed disconnect settlement and lost-lease shutdown. The guarded co-op fixture verifies independent host and guest exits, repeated kill-credit refusal, failed party departure before either peer moves, separate card/consent actions, and cleanup-pending extraction with the Garden transition and warning visible on the guest. It drives encounter state and snapshots at explicit barriers using the actual guarded worlds and localhost RPCs.

Earlier probes are preserved outside the passing index. Initial parser errors were corrected. The first restart probe entered recovery while the killed owner's application lease was still current. The final restart harness waited for normal expiry. The first Group 1 rerun exposed an assumption that its lightweight fixture had expedition runtime fields. Expedition-specific snapshots now belong to the gameplay world, and the final Group 1 fixtures passed in both modes.

- [Tested-input manifest](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2b/TESTED_INPUTS.sha256>) covers 1,247 paths. SHA-256 `595fc35ca143d896bf2630b6d6e423257abd8115d81981df2d4339d27f035cf5`.
- [All run IDs, verdicts and controlled interruption evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2b/VERIFIED_RUNS.json>) and [caller-level state, journal hashes and feedback](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2b/ACTION_EVIDENCE.json>).
- [Focused preview](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2b/plan-final.txt>) and [planner self-tests](<C:/Users/sutte/Documents/Codex/ac06-b0-group3b2b/planner-final.log>).
- Disposable EXE SHA-256 `04101b98fc151cf783ab9a3428904a648803fb60e0d85a2bbaa9ec1613a1440e`.
- Native DLL SHA-256 `ad827586970b7d701af85007185fa2ef31213666add81674d47c3dab96370379`, identical across the prerequisite, test source and packaged sidecars.

The checkpoint changes `game.gd`, `game_transaction.gd`, `expedition_life.gd`, `monster_rewards.gd`, `party_travel.gd`, `progress.gd`, the two guarded expedition fixtures, `tools/test_map.json`, the generated mechanics map, and this report. The commit hash is recorded in the handoff.
