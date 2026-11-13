# AC-06 P1 · Inactive production persistence route

## Baseline

The clean starting branch was `ac06/persistence` at `bc42453892e48679b49de06f16e649807e554ddd`, above Stage A1 `be3ac4d3297e8ad42a5950923a38e7600798f533`. The audit compared all 1,255 committed blobs and worktree inputs with the Stage A2 tested manifest, allowing Git line-ending normalization. It rechecked all 127 source and packaged verdicts, 177 process exits, the separate four-player smoke and four interruption and recovery pairs.

## Route and writer inventory

`PersistenceWriterIntegration.default_route` is evaluated by the actual title scene and by world startup. Normal launch continues to use the legacy route while the production gate is closed. The source and packaged fixtures use the title's normal route-selection function with a headless, disposable-root SceneTree marker. No user setting, launch argument or network message opens the gate. The tests exercise the same guarded menu handlers that the approved route selects. The windowed title has no cutover switch.

| Entry point | Candidate default path and evidence |
|---|---|
| `main_menu.gd::_ready/garden_summary/character_summary` | Guarded directory bootstrap, then passive inspection. Slots with pending or ambiguous evidence are unavailable. Older-save import requires a separate confirmation. Browsing and startup do not import canonical saves. |
| `main_menu.gd::request_create_character/create_character/_create_character_guarded/confirm_delete_character` | Guarded roster creation, edits, catalog updates and deletion. The original confirmation digest is rechecked. Roster deletion verifies both the profile disposition and catalog before reporting completion. |
| `main_menu.gd::create_and_launch/confirm_delete_save` | Guarded Garden-only creation, replacement and deletion with the selected digest, archive copy and deletion metadata. The roster remains independent. Cleanup pending and unresolved results do not display ordinary completion. |
| `developer_settings.gd` and `developer_mode.gd::_open_guarded/open_garden` | The isolated Developer Garden uses the same guarded pair creation/reset and lease handoff. Its settings entry exposes explicit recovery for that Garden. Missing backend refuses entry. |
| `SaveSlots.prepare_guarded/remember_slot_guarded` and `CharacterSlots.prepare_guarded/remember_guarded/set_capacity_guarded` | Locked slot and catalog updates. Explicit import copies eligible original bytes and then prepares the roster. Existing sources stay intact. A blocked import does not fall back to direct copy. |
| `main_menu.gd::_launch_guarded` and `GuardedTitleSession.start/tick/release` | Lease ownership and digest validation precede loading. Continue claims the Garden and selected profile. Join claims the profile only. Heartbeat and release remain scoped to exact owned markers. |
| `game.gd::_ready/_refuse_unowned_world` | Candidate world startup without the session handoff returns to title before legacy loads. Guarded serializers require their bound transaction and authorized stage. |
| `GameTransaction.run_gameplay`, `Progress.save_garden`, `CharacterProfile.save_profile`, and `PersistenceOperations.commit_serializers` | Garden, class, inventory, combat, expedition, explicit saves, migration backups and settlement use the previously migrated guarded scopes. First errors, B1 outcomes, B2 evidence and recovery warnings remain intact. |
| `game.gd::register_character/connection_accepted/receive_character` | Protocol 40 requires the same save mode. The host commits Garden projections. The guest writes and acknowledges its own profile. Reconnect and lease-loss behavior are exercised through the candidate title. |
| `game.gd::_notification/return_to_main_menu/_finish_title_return/release_slot/remove_player` | Guarded settlement uses owned participants. Delayed callbacks cannot fall through to legacy writes. The offline peer is installed before detachment. The next title keeps the recovery notice until verified recovery of the affected save set. |
| `AppSettings`, `NetworkSettings`, diagnostics and metrics | Separate noncanonical writers. Their failures do not decide canonical outcomes. |

## Explicit recovery

Open **Review Garden Recovery**, **Review Character Recovery**, or **Review Older Save Recovery**. The Developer Garden has its own review under Developer Mode. Review calls the read-only planner and lists the complete discovered participant set. Active leases and evidence with no safe authorization disable confirmation. The reviewed plan is compared with a fresh plan, then B2 revalidates that plan under the native root lock. Title recovery requires idle participants and refuses unresolved lease scratch. It does not acquire a session lease or open a world.

Successful committed recovery verifies the committed bytes and finishes cleanup. A verified abort restores the original bytes or recorded absence. An unresolved recovery keeps the evidence and reports that it could not be verified. A missing Garden does not prove deletion. Archives, unowned scratch and contradictory records are preserved. The guest Join path does not invoke recovery on a selected or host Garden.

`SaveBatch.recover` refuses a guarded primary attempt marker or B2 sidecars at the requested path or linked anchor. The legacy serializer entry point also refuses known guarded evidence. This is protection for the current binary. It does not establish older-build exclusion or turn the legacy route into the guarded implementation.

## Remaining boundaries

- `PRODUCTION_CUTOVER_APPROVED` is false and `VERIFIED_WRITERS` remains empty. The legacy title, slot and roster writers, direct legacy recovery and legacy gameplay remain reachable through the current inactive release mode. Full independent production-writer acceptance and activation approval remain outstanding.
- Older protocol peers are refused at admission. The native lock cannot stop old binaries from independently opening the same root. Older-build exclusion or root separation must be established before cutover.
- Legacy committed journals without independent proof, conflicting evidence, uncertain archives and unsupported native or filesystem environments need operator review. The title does not attempt archive reconciliation or delete ambiguous artifacts. The current implementation is verified on local Windows x64 NTFS with the matching engine and DLL.
- The automated tests exercise title controls headlessly. Visual layout, WAN behavior and full release acceptance are separate. No live saves or installed executable or DLL were used.

## Verification

- `p1-{source,pack}-production-persistence-verified-unit` covers the default title, explicit import, roster creation/edit/delete, Garden create/replace/delete, standalone write refusal, recovery review and confirmation, competing evidence and lease drift, Developer Garden reset, and window-close save and lease release.
- `p1-{source,pack}-guest-projection-coop-projection-recheck` runs default-title host and Join, actual loopback projection acknowledgments, reconnect, missing acknowledgment, uncertainty and lost-lease callbacks. Its first final probe exposed a fixture attempting to leave a world that had already auto-detached during pending-state heartbeat. The recheck accepts that real teardown ordering and still verifies offline transition and disk outcomes.
- `p1-{source,pack}-direct-ip-coop-verified-pair` exercises protocol 39 rejection over loopback with unchanged guest progress, then compatible Join and reconnect. The legacy two-window title regression verifies the original selection behavior.
- `p1-final-{source,pack}-backend-{missing,incompatible}` verifies failed title admission, disabled writes and absent save directories and sentinel. Each missing-library process emits exactly three expected Godot loader diagnostics. The older prototype DLL loads and is refused for its missing replacement interface. The regular AC-01 validator is unchanged.
- `p1-final-{source,pack}-migration-{before,partial}-{owner,recover}` verifies forced interruption and restart. Each owner was deliberately terminated. Each recovery exited successfully with a current structured result, restored the original bytes and retained the backups.
- [Exact structured verdicts, peer exits, interruption and smoke evidence](<C:/Users/sutte/Documents/Codex/ac06-p1/VERIFIED_RUNS.json>), [title and projection case data](<C:/Users/sutte/Documents/Codex/ac06-p1/ACTION_EVIDENCE.json>), and [native refusal runs](<C:/Users/sutte/Documents/Codex/ac06-p1/BACKEND_REFUSAL.json>).
- [Focused plan](<C:/Users/sutte/Documents/Codex/ac06-p1/plan-final.log>) identified 116 of 164 registered suites with no unmatched scope declarations. All 53 planner self-tests passed. The focused checkpoint rechecked 129 passing verdicts, 64 source and 65 packaged, with 179 successful process exits. The separate four-player smoke passed with four exits. The four restart recovery and four backend refusal cases are recorded separately.
- [Tested-input manifest](<C:/Users/sutte/Documents/Codex/ac06-p1/TESTED_INPUTS.sha256>) covers 1,257 inputs. SHA-256 `88f55290628c8449af67788fdcb4b2d7ddea8f725b272562f5eeff1d01ade529`. Disposable Windows EXE SHA-256 `070922aac982afcb88bfafdb4da8b213c26b59f7800165e3c88daec2bacfebab`. Native DLL SHA-256 `ad827586970b7d701af85007185fa2ef31213666add81674d47c3dab96370379`.
