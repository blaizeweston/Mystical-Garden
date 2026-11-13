# AC-06 B0 Group 3A — Guarded title and session lifecycle

Group 3A adds an internal opt-in title route. A normal title scene still opens in legacy mode. The opt-in is carried through the world and back to the title for the same session. The production cutover gate is false and the verified production writer inventory remains incomplete. The installed game, native DLL, and live saves were untouched. [Activation gate](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd:5>)

## Caller integration

| Caller | Guarded behavior |
|---|---|
| Main title and roster browsing | Use passive save inspection for healthy, empty, busy, pending, ambiguous, and invalid states. Reverse-linked evidence and unpublished slot metadata keep an absent save unavailable. A character with an unverified identity cannot be selected for play or customized. |
| Title preparation and character management | Route legacy import, roster preparation, profile creation, profile edit, deletion and selection preference through guarded operations. Profile editing uses a passive preview and rechecks its digest under authorization. |
| Garden creation and deletion | Route creation, occupied replacement, and Garden-only deletion through the guarded slot APIs. Pair deletion remains available through the guarded slot API and has fixture coverage. The title Delete Garden action preserves the separate roster. |
| Confirmations and notices | Capture the target slot and digest when the dialog opens. Developer reset captures both slot-member digests when selected. Only a completed operation closes the destructive confirmation or advances into gameplay. Pending, cleanup pending, partial completion, verified failure and unresolved outcomes produce distinct feedback. Failed destructive confirmations are cleared so a second attempt requires a fresh selection. |
| Title Continue, Host, and Join | Acquire leases and validate the requested profile and Garden bytes before adding the world. A failed launch unwinds only its own claims. Title Join claims the profile and skips Garden recovery, loading, claiming and selection writes. Guest identity loads under the guarded read path without an implicit profile write. |
| Developer Garden | Uses the isolated slot with guarded creation, occupied reset, and ownership transfer. The return path restores the normal Garden and roster selections. |
| Session handoff and teardown | Transfer the store instances that hold the lease digests. Heartbeat runs once per second while the opt-in world is active, including while connecting. It reuses those instances and respects the existing 30-second expiry. Release checks the same owner. A lost lease stops the session and returns to the title without saving through the stale owner. |

## Verification

The final focused runs used isolated save roots and a disposable Godot 4.7.2 Windows export. The 38 unit verdicts and four co-op verdicts passed with exit 0 and no unexpected engine errors. Both peers passed each co-op fixture.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| `guarded_title_session` | `b0g3a-source-guarded_title_session-01` | `b0g3a-pack-guarded_title_session-01` |
| `start_menu` | `b0g3a-source-start_menu-01` | `b0g3a-pack-start_menu-01` |
| `character_roster` | `b0g3a-source-character_roster-01` | `b0g3a-pack-character_roster-01` |
| `delete_saves` | `b0g3a-source-delete_saves-01` | `b0g3a-pack-delete_saves-01` |
| `developer_garden` | `b0g3a-source-developer_garden-01` | `b0g3a-pack-developer_garden-01` |
| `menu_controls` | `b0g3a-source-menu_controls-01` | `b0g3a-pack-menu_controls-01` |
| `network_settings` | `b0g3a-source-network_settings-01` | `b0g3a-pack-network_settings-01` |
| `persistence_destructive_slots` | `b0g3a-source-persistence_destructive_slots-01` | `b0g3a-pack-persistence_destructive_slots-01` |
| `persistence_slot_roster` | `b0g3a-source-persistence_slot_roster-01` | `b0g3a-pack-persistence_slot_roster-01` |
| `persistence_group_one` | `b0g3a-source-persistence_group_one-01` | `b0g3a-pack-persistence_group_one-01` |
| `persistence_restart_recovery` | `b0g3a-source-persistence_restart_recovery-01` | `b0g3a-pack-persistence_restart_recovery-01` |
| `persistence_durable_evidence` | `b0g3a-source-persistence_durable_evidence-01` | `b0g3a-pack-persistence_durable_evidence-01` |
| `persistence_outcomes` | `b0g3a-source-persistence_outcomes-01` | `b0g3a-pack-persistence_outcomes-01` |
| `persistence_operations` | `b0g3a-source-persistence_operations-01` | `b0g3a-pack-persistence_operations-01` |
| `persistence_authorization` | `b0g3a-source-persistence_authorization-01` | `b0g3a-pack-persistence_authorization-01` |
| `persistence_recovery_plan` | `b0g3a-source-persistence_recovery_plan-01` | `b0g3a-pack-persistence_recovery_plan-01` |
| `persistence_save_access` | `b0g3a-source-persistence_save_access-01` | `b0g3a-pack-persistence_save_access-01` |
| `foundations` | `b0g3a-source-foundations-01` | `b0g3a-pack-foundations-01` |
| `content_validation` | `b0g3a-source-content_validation-01` | `b0g3a-pack-content_validation-01` |
| `menu_coop` | `b0g3a-source-menu_coop-02` | `b0g3a-pack-menu_coop-02` |
| `garden_growth_coop` | `b0g3a-source-garden_growth_coop-02` | `b0g3a-pack-garden_growth_coop-02` |

The new fixture exercises the actual opt-in title scene, guarded startup and lease handoff. It covers missing Garden and roster files with evidence, ambiguous records, an invalid profile, metadata scratch, stale replacement and deletion confirmations, foreign and expired leases, competing claims, failed startup, lease takeover, blocked Title Join, legacy import, Developer Garden reset, and outcome handling. Cleanup-pending and unresolved dialog behavior is tested with explicit injected results. The Group 2B fixture covers disk-level deletion failures and verified compensation. The co-op fixtures exercise existing multiplayer paths. [Opt-in source verdict](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/source-01/guarded_title_session/verdict.json>) · [Opt-in packaged verdict](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/pack-01/guarded_title_session/verdict.json>) · [Fixture](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/guarded_title_session.gd>)

The initial co-op attempts `b0g3a-{source,pack}-{menu_coop,garden_growth_coop}-01` timed out in the restricted environment. All four passed on local UDP 32381 with loopback access in the `-02` runs. The AC-01 verdict checker and AC-02 teardown fixture were unchanged. The focused planner preview resolved with no unmatched scopes and all 53 planner self-tests passed. The preview includes shared foundation consumers and is broader than the selected checkpoint runs. [Planner log](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/planner.log>) · [Focused impact preview](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/plan.txt>) · [Successful source co-op verdicts](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/source-network-02>) · [Successful packaged co-op verdicts](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/pack-network-02>)

- Disposable EXE SHA-256 `777565CE4570572641B850CBFC7A23C13EA9C8ABE3AF3424ED8F2A57C2EF8FCA`
- Native DLL SHA-256 `AD827586970B7D701AF85007185FA2EF31213666ADD81674D47C3DAB96370379`

## Changed files

- [main_menu.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/main_menu.gd>)
- [game.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game.gd>)
- [developer_mode.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/developer_mode.gd>)
- [developer_settings.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/developer_settings.gd>)
- [character_creator.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_creator.gd>)
- [network_panel.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/network_panel.gd>)
- [save_slots.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd>)
- [character_slots.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_slots.gd>)
- [persistence_save_inspection.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_save_inspection.gd>)
- [guarded_title_session.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/guarded_title_session.gd>)
- [guarded_title_session.gd.uid](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/guarded_title_session.gd.uid>)
- [tests/guarded_title_session.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/guarded_title_session.gd>)
- [tools/test_map.json](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tools/test_map.json>)
- [docs/MECHANICS_TEST_MAP.md](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/MECHANICS_TEST_MAP.md>)

## Remaining cutover work

Group 3B, Group 3C, and Stage A remain prerequisites. Ordinary title launch still selects the legacy route. Gameplay transactions, runtime saves and settings/network preference writes retain their existing paths. The opt-in launch uses the existing gameplay code after admission. Lost-lease shutdown and guarded title reads reduce risk during opt-in testing, while guarding every gameplay write remains future work. Session marker cleanup can be refused while recovery or contention blocks it. An unreleased marker continues to use the existing expiration policy. Unresolved journals remain available for dedicated B2 recovery, and no archive or recovery evidence is automatically deleted by the title.

The checkpoint is on `ac06/persistence` with the Group 2B documentation commit `8ee17ffa0813477f931dc08415bb934aec7e6ea5` as its parent. This verification covers the focused architecture checkpoint. Stable playable release validation remains outstanding.

## Final checkpoint review

The Group 3A implementation is `7bcfb39975ab3efb7ba40a5e0ea815dd7694e78e` on `ac06/persistence`, directly above the requested parent `8ee17ffa0813477f931dc08415bb934aec7e6ea5`. The review began with a clean working tree and no configured remotes. The complete 15-path diff covers the guarded title, menu, Developer Garden, roster and session lifecycle, plus fixtures, dependency declarations and documentation. Gameplay transaction code, combat mechanics, RPC declarations, network protocol, native binaries and export tooling are outside the diff.

- **Inputs and binaries.** Recomputed SHA-256 for all 1,242 tracked inputs in the recorded manifest and compared each with the retained disposable project and its committed Git blob after repository normalization. This covers the runtime scripts, fixtures, registry, verifier and native sources. The manifest SHA-256 is `997DF3B7C141136B09216C26914FDA955E02DD421A6F44C924CB6A37271194FC`. The disposable EXE matched the original hash above. The tracked native DLL, source test copy, exported sidecar and all 21 packaged test copies matched SHA-256 `AD827586970B7D701AF85007185FA2EF31213666ADD81674D47C3DAB96370379`. The original manifest was recorded during checkpoint preparation. It has no separate per-launch source attestation. [Tested-input manifest](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/GROUP_3A_TESTED_INPUTS.sha256>) · [Final verification log](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/GROUP_3A_FINAL_VERIFICATION.log>)
- **Fixture verdicts.** Rechecked all 42 final run IDs listed above using the existing verdict verifier. Checked fixture hashes, instrumented launcher contents, peer identities, structured completion, process exits and both log streams. The 38 unit runs passed. All eight peer exits across four co-op runs were zero with no unexpected engine errors. Both source and packaged Garden growth runs recorded host and guest offline before world removal. The original four network-restricted failures remain in the source and packaged `-01` directories, with their logs and failed verdicts intact. The final verification log records their hashes. The existing Godot evidence was current, so no Godot fixture reruns were required. [Original source failures](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/source-01>) · [Original packaged failures](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/pack-01>) · [Final source co-op](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/source-network-02>) · [Final packaged co-op](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/pack-network-02>)
- **Planner.** Regenerated the focused impact preview against the matched test project. It matched the stored preview byte-for-byte, with 110 unit suites selected from 154 registered suites and no unmatched scopes. The 53 planner self-tests passed again. This is a focused checkpoint verification. [Regenerated preview](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/plan-final-review.txt>) · [Planner rerun](<C:/Users/sutte/Documents/Codex/ac06-b0-group3a/planner-final-review.log>)

### Title Join and confirmation checks

The guarded title launch supplies a profile lease and no Garden store to `GuardedSession.start()`. It preloads the selected profile with recovery disabled, skips world startup's legacy loads, and bypasses the Garden save in `join_game()` because no Garden slot was claimed. A linked journal can still block the requested profile when the planner finds shared participants. The guarded unit fixture exercises a rejected join with an unclaimed Garden journal and confirms the journal hash and canonical absence are preserved. The successful co-op verdicts cover the existing multiplayer paths. [Guarded title launch](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/main_menu.gd:635>) · [Guarded startup](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/guarded_title_session.gd:106>) · [Join](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game.gd:638>) · [Fixture](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/guarded_title_session.gd>)

Garden replacement and deletion and roster deletion capture the selected slot and its inspected digest before showing confirmation. Developer reset captures a path-keyed Garden/profile digest pair when reset is selected. The guarded operations compare those supplied values under authorization. The fixture exercises stale Garden replacement and roster deletion, and a successful occupied Developer reset. [Garden confirmation](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/main_menu.gd:440>) · [Garden deletion](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/main_menu.gd:531>) · [Roster deletion](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/main_menu.gd:580>) · [Developer reset selection](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/developer_settings.gd:27>) · [Developer digest capture](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/developer_mode.gd:66>)

### Lost-lease shutdown and cutover blockers

The direct lost-lease path disables processing and defers `_finish_title_return()`. It bypasses the ordinary save branch, closes the network peer before release and world removal, and releases only markers still owned by the original store instances. The world's exit callback only releases slots. The window-close path also checks ownership before saving. [Lost-lease shutdown](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game.gd:3311>) · [Lease release](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game.gd:3346>) · [Window close](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game.gd:305>)

Two secondary write paths remain for Group 3C. The host still has its `peer_disconnected` signal connected during peer shutdown. If a disconnect reaches `remove_player()` while the world is still attached, reward flushing, safe-pouch recovery, or the return record can enter the legacy transaction. On the guest, `receive_character()` can reach the legacy profile writer if a profile RPC is dispatched before transport stops. Those callbacks lack a lost-lease check. The source paths are confirmed. Delivery during the lost-lease shutdown interval was not reproduced by the focused fixtures. Group 3C must cover the shutdown window and verify that stale-owner callbacks cannot mutate saves or consume recovery evidence. [Host disconnect](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game.gd:739>) · [Reward flush](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/monster_rewards.gd:15>) · [Pouch recovery](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game.gd:2595>) · [Return record](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/garden_return_service.gd:39>) · [Guest profile callback](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game.gd:1219>) · [Legacy transaction](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game_transaction.gd:24>)

Group 3B and 3C remain open for the remaining production caller migration, standalone and metadata writes, and shutdown and runtime save coverage. Ordinary title startup still defaults to legacy. The opt-in title uses guarded admission and leases, while post-admission gameplay writes and settings and network preference writers still use legacy persistence. Stage A still owns first serializer error propagation and post-commit harvest confirmation. Production cutover remains false and `VERIFIED_WRITERS` remains empty. Live saves, installed binaries, and runtime code were untouched during this final review. [Title default](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/main_menu.gd:6>) · [Settings writer](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/app_settings.gd:64>) · [Network preference writer](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/network_settings.gd:56>) · [Activation gate](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd:5>) · [Stage A contract](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/AC06_SAVE_TRANSACTION_CORRECTION_CONTRACT.md:14>)
