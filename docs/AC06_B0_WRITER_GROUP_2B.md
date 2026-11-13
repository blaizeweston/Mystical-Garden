# AC-06 B0 Group 2B — Guarded destructive save management

Group 2B adds opt-in occupied replacement and deletion. Production cutover remains disabled and the production writer inventory remains unverified. Normal gameplay, the installed executable and DLL, and live saves were untouched. [Activation gate](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>)

| Guarded entry point | Behavior |
|---|---|
| `SaveSlots.new_game_guarded`, `new_world_guarded` | Verify timestamped archive copies before B1/B2 replacement. Recheck occupancy, confirmation digests, leases, and participant scope under authorization. Garden-only replacement keeps the associated character file. Developer Garden uses the same pair route. |
| `SaveSlots.delete_world_guarded`, `delete_save_guarded` | Archive the affected originals, then commit the slot tombstone and canonical absence through the same B1/B2 attempt. The tombstone prevents legacy reimport. The Garden-only route leaves the character file intact. |
| `CharacterSlots.delete_character_guarded` | Verify the saved identity, archive the selected profile, then commit its absence and the roster catalog changes in the same attempt. Retains existing catalog settings and other characters. The guarded remove helper requires the live nested context. |

Each route uses one mutation authorization for the archive writes and canonical transaction. Directory-only bootstrap takes a separate short lock and grants no write token. The mutation authorization includes exact archive and scratch paths, canonical participants, journal artifacts, and the relevant tombstone, catalog and leases. Archive names are bounded to the existing backup directory and name families. An occupied destination refuses the copy. Locked confirmation compares caller-supplied digests when available, otherwise it compares digests captured at entry. Group 3 still needs to pass confirmation digests captured when the user selects a save.

## Commit and recovery behavior

Archive preparation and the canonical transaction are separate phases. A failed or interrupted archive copy leaves the original canonical state intact and can leave an empty folder, scratch file, or completed copy. A retry uses a fresh archive location. Published archives remain available after a later transaction abort. The existing journal format and manifest version are retained. Group 2B extends the existing participant allowlist only to the anchor slot's tombstone or roster catalog and uses the manifest's existing absence representation for deletion.

B1 verifies original bytes or absence before reporting restoration. B2 restores uncommitted deletions, including the catalog or tombstone, and preserves committed deletions during cleanup. A failed compensation returns `UNCERTAIN`, keeps the journal and archive, and blocks conflicting guarded operations until authorized recovery verifies the result. The former direct archive-move compensation has no guarded equivalent that can independently mutate saves. The guarded route delegates compensation to B1/B2. Passive inspection observes pending shared roster catalog evidence, including when the canonical profile is absent. The process tests exercise Windows process termination on disposable local roots. Sudden power-loss durability remains unverified.

## Verification

Godot 4.7.2 source and disposable Windows export. Every fixture below returned exit 0, a current structured PASS, and zero unexpected engine errors.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| `persistence_destructive_slots` | `b0g2b-source-persistence_destructive_slots-01` | `b0g2b-pack-persistence_destructive_slots-01` |
| `persistence_slot_roster` | `b0g2b-source-persistence_slot_roster-01` | `b0g2b-pack-persistence_slot_roster-01` |
| `persistence_group_one` | `b0g2b-source-persistence_group_one-01` | `b0g2b-pack-persistence_group_one-01` |
| `persistence_restart_recovery` | `b0g2b-source-persistence_restart_recovery-01` | `b0g2b-pack-persistence_restart_recovery-01` |
| `persistence_durable_evidence` | `b0g2b-source-persistence_durable_evidence-01` | `b0g2b-pack-persistence_durable_evidence-01` |
| `persistence_outcomes` | `b0g2b-source-persistence_outcomes-01` | `b0g2b-pack-persistence_outcomes-01` |
| `persistence_operations` | `b0g2b-source-persistence_operations-01` | `b0g2b-pack-persistence_operations-01` |
| `persistence_authorization` | `b0g2b-source-persistence_authorization-01` | `b0g2b-pack-persistence_authorization-01` |
| `persistence_recovery_plan` | `b0g2b-source-persistence_recovery_plan-01` | `b0g2b-pack-persistence_recovery_plan-01` |
| `persistence_save_access` | `b0g2b-source-persistence_save_access-01` | `b0g2b-pack-persistence_save_access-01` |
| `foundations` | `b0g2b-source-foundations-01` | `b0g2b-pack-foundations-01` |
| `character_roster` | `b0g2b-source-character_roster-01` | `b0g2b-pack-character_roster-01` |
| `delete_saves` | `b0g2b-source-delete_saves-01` | `b0g2b-pack-delete_saves-01` |
| `developer_garden` | `b0g2b-source-developer_garden-01` | `b0g2b-pack-developer_garden-01` |
| `start_menu` | `b0g2b-source-start_menu-01` | `b0g2b-pack-start_menu-01` |
| `content_validation` | `b0g2b-source-content_validation-01` | `b0g2b-pack-content_validation-01` |

The destructive fixture logs each result, B1 errors and verification details, and path hashes or absence for canonical files, catalog, tombstone, archives, leases, and journal artifacts. It covers first and second archive failure, occupied and unsafe archive paths, failed replacement after archive, tombstone and catalog publication failures, removal and compensation failures, pending linked journals, stale confirmation, foreign lease, unrelated profile preservation, and legacy import refusal. [Source case log](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/source-01/persistence_destructive_slots/unit.log>) · [Packaged case log](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/pack-01/persistence_destructive_slots/unit.log>)

| Process scenario | Exact run IDs | Result |
|---|---|---|
| Archive scratch written | `b0g2b-source-archive_staged-01`, `b0g2b-pack-archive_staged-01` | Originals intact, scratch retained, fresh guarded replacement succeeded. |
| Both archives verified before replacement | `b0g2b-source-after_archive-01`, `b0g2b-pack-after_archive-01` | Originals and both copies intact, no pending journal, fresh guarded replacement succeeded. |
| Pair deletion interrupted after first removal | `b0g2b-source-delete_interrupted-01`, `b0g2b-pack-delete_interrupted-01` | Passive inspection and another guarded delete reported pending. Recovery through the character restored both originals and removed the new tombstone. A retry committed. |
| Pair deletion committed before cleanup | `b0g2b-source-committed_interrupted-01`, `b0g2b-pack-committed_interrupted-01` | Recovery preserved the tombstone and both recorded absences while cleaning artifacts. |
| Roster deletion interrupted after catalog publication | `b0g2b-source-roster_interrupted-01`, `b0g2b-pack-roster_interrupted-01` | Catalog entry point found the journal. Verified recovery restored the prior catalog absence and original profile. A retry committed. |

The process supervisor records child IDs, exits, engine errors and actual save bytes and SHA-256 hashes after each step. Terminated writers exited 1 as expected. Ordinary children exited 0 without unexpected engine errors. [Process evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/GROUP_2B_CROSS_PROCESS.json>) · [Process supervisor](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/cross.py>)

Missing and incompatible backend checks passed as `b0g2b-source-backend-missing-01`, `b0g2b-source-backend-incompatible-01`, `b0g2b-pack-backend-missing-01`, and `b0g2b-pack-backend-incompatible-01`. The guarded public delete refused with `ERR_UNAVAILABLE` and preserved the original bytes. Only the missing-library scenarios emitted the three separately asserted Godot loader errors. [Backend evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/GROUP_2B_BACKENDS.json>)

- Disposable Windows EXE SHA-256 `0F2372C9FB5F227FF10555CCAC0F12BA932AF6AADD1F61E83089D69284CB450D`
- Existing native DLL SHA-256 `AD827586970B7D701AF85007185FA2EF31213666ADD81674D47C3DAB96370379`
- All 53 planner self-tests passed. The focused preview classified the changed sources and selected 109 unit suites because several persistence scripts are foundation inputs. The selected checkpoint fixtures above cover persistence, its callers, and content startup. Full release validation was outside this checkpoint. [Planner result](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/planner.log>) · [Impact preview](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/plan.txt>)

## Changed files and activation blockers

- [save_batch.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd>)
- [save_slots.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd>)
- [character_slots.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_slots.gd>)
- [persistence_authorization.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_authorization.gd>)
- [persistence_operations.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd>)
- [persistence_save_layout.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_save_layout.gd>)
- [persistence_save_inspection.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_save_inspection.gd>)
- [persistence_evidence.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_evidence.gd>)
- [persistence_recovery_plan.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_recovery_plan.gd>)
- [persistence_writer_integration.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>)
- [tests/persistence_slot_roster.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/persistence_slot_roster.gd>)
- [tests/persistence_destructive_slots.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/persistence_destructive_slots.gd>)
- [tools/test_map.json](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tools/test_map.json>)
- [docs/MECHANICS_TEST_MAP.md](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/MECHANICS_TEST_MAP.md>)

Group 3 still owns production callers, confirmation snapshots, passive browsing and lease lifecycle. Stage A remains a cutover prerequisite. The guarded boundary coordinates cooperating processes. Keep it opt-in until all production paths are migrated and verified. The opt-in process tests and selected regressions do not certify a stable playable release.

## Final checkpoint review

The implementation is recorded in `a1d503f6073e1893f90322880110d3e92dcef7d3` on `ac06/persistence`. Its parent is the Group 2A baseline `9fd6fd4047e85fa446a3ae9fa448f92fd8326b60`. Review of the complete 15-path diff found only guarded persistence code, fixture and registry updates, and checkpoint documentation. The legacy gameplay entry points, multiplayer code, release scripts, and native DLL were outside the diff. The verification addendum changes documentation only.

- Compared 1,239 tracked non-documentation inputs byte-for-byte with the retained test project, including runtime scripts, assets, fixtures, validation runner and test registry. Compared the same inputs with the implementation commit after Git's text normalization. Input manifest SHA-256 is `0C1D8F0AD217396C8EC3131ADE56168596FC328F4E2561332F58F9FE6799866C`.
- Rechecked all 32 run IDs in the table above with the existing verdict verifier. Verified script hashes, instrumented launcher contents, structured results, successful exits, and both engine log streams. The DLL matched the source sidecar, exported sidecar, and every packaged fixture's staged copy.
- Rechecked all 10 interruption run IDs above against the 50 child records, result files, process exits, and engine logs. Recomputed every recorded file hash from captured bytes and compared final snapshots with the disposable files still on disk. Four native-backend refusal probes also matched the stored results and canonical hashes. The saved planner log recorded 53 passing tests.
- The stored executable and native library hashes match the values above. The paired Godot engine SHA-256 is `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`. The interruption evidence JSON SHA-256 is `B0EF95A474853DB216DAF07ECDEFA090BC1BB63E59360AD492DAC6D7BCF6981E`. The retained snapshot, launched fixtures, exported binaries and recorded results provide the evidence for this checkpoint. The original runs did not emit a separately timestamped digest for every source input. The digest above was computed during the review. The review required no Godot reruns. [Verification log](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/GROUP_2B_FINAL_VERIFICATION.log>) · [Fixture verifier](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tools/validation_execution.py:233>)

The positive fixtures exercise the public guarded Garden-only and paired replacements, Developer Garden reset through `new_game_guarded`, Garden-only and pair deletions, and roster deletion. The fault fixtures confirmed that pending recovery, archive preparation failure, and failed compensation return distinct states. In particular, guarded deletion reaches `completed` only after the typed transaction reports `COMMITTED`. A committed deletion with cleanup pending stays distinct. Consumers must check the outer authorization result and the inner operation state and outcome. An outer result indicating that the callback ran is insufficient to report success. Passive inspection checks pending journal evidence before reporting an absent save as empty. [Garden and pair routes](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd:270>) · [Roster deletion](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_slots.gd:167>) · [Typed result mapping](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd:294>) · [Passive inspection](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_save_inspection.gd:47>)

The primary journal keeps its ConfigFile encoding, and the version 1 manifest retains the same fields and recorded absence format. The guarded reader accepts earlier canonical-only journals and binds the new metadata participant to the owning slot or roster catalog. Existing B1/B2 fixtures passed alongside interrupted Group 2B deletions. Compatibility applies to the current guarded reader and existing journals. Use the Group 2B guarded recovery path for Group 2B deletion journals. Downgrading a build with outstanding guarded journals or using legacy recovery against those files is outside the verified contract. [Journal scope](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_save_layout.gd:67>) · [Manifest validation](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_evidence.gd:29>) · [Guarded recovery](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd:390>)

### Read-only archive reconciliation

Archive classification is a review procedure. It uses path ownership, bounded byte reads, SHA-256 and recorded transaction or fixture evidence. Record canonical recovery status separately. A tombstone or catalog reference helps identify the intended archive folder, but only verified transaction evidence establishes the deletion outcome. Use a quiescent snapshot or repeat observations if the files can change during inspection.

| Classification | Evidence required | Disposition |
|---|---|---|
| Valid archive | Expected final filenames in the correct slot's backup folder. Ordinary files and ancestry. File lengths and hashes match trustworthy original-byte evidence for every expected member. | Keep as a backup. Derive deletion or replacement status from separate canonical transaction evidence. |
| Incomplete scratch | A recognized `.cfg.tmp` for the expected source exists before final publication. It may be truncated or may already contain all original bytes. | Preserve it as unpublished evidence. Record size, hash and any verified match. |
| Abandoned but owned artifact | A known interrupted or aborted operation ties the exact folder or files to the slot, with matching recorded originals where bytes were written. A complete set can exist before the canonical transaction starts. | Preserve the folder and record whether canonical files stayed intact or were restored. A new authorized attempt can use a fresh folder after canonical recovery is clear. |
| Ambiguous artifact | Path ancestry or ownership cannot be verified, hashes or references disagree, members are unexpected, or there is insufficient evidence to determine provenance. | Preserve as-is and report for manual reconciliation. Filename, age and slot location alone do not prove ownership or authorize cleanup. |

In both `archive_staged` runs, the retained `character.cfg.tmp` was 4,368 bytes and exactly matched the original character. Both original saves remained intact. In both `after_archive` runs, the two final copies matched the originals at 4,368 and 8,084 bytes. There was no canonical transaction journal in either archive-only scenario. Fresh authorized retries used new folders and preserved all six original interruption artifacts byte-for-byte. The verification log records their exact relative paths and hashes. [Archive evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-group2b/GROUP_2B_FINAL_VERIFICATION.log>) · [Archive publication](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd:195>)

The planner tracks canonical journal artifacts and the selected operation's exact archive destinations. Passive save inspection does not scan every historical backup directory, and the current protocol does not store an independent archive receipt. A slot can therefore appear healthy while an earlier archive attempt has retained scratch. A new attempt can proceed with a fresh destination if canonical recovery is clear. Unknown copies may accumulate, and a pair of final archive files alone cannot distinguish an interrupted attempt from a successful replacement. The review made no archive changes and adds no automatic reconciliation or deletion. An absent slot without journal evidence is likewise only a current availability observation. It cannot prove a deletion succeeded. Before cutover, Group 3 must keep pending and unresolved results out of success UI, supply confirmation snapshots, and migrate production save callers and lease handling. Stage A remains required. `PRODUCTION_CUTOVER_APPROVED` is false and `VERIFIED_WRITERS` is empty. This remains a focused architecture checkpoint. [Activation gate](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd:5>)
