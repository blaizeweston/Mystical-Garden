# AC-06 B0 writer integration — Group 1

Group 1 connects the core transaction and serializers to the opt-in authorization route. Normal gameplay still calls the legacy entry points. Production activation, Groups 2 and 3, and Stage A remain open. The desktop EXE and all live saves were outside the implementation and verification.

## Guarded routes

| Entry point | Behavior |
|---|---|
| `GameTransaction.run_guarded` | Acquires a complete scope through `PersistenceOperations.run_serializers`. The action starts only after locked revalidation. Garden and the local profile normally participate, and the existing guest rule stages only the Garden. A nested action can reuse the owning game's operation. A foreign game or independent outer save cannot reenter. |
| `Progress.save_garden_guarded`, `CharacterProfile.save_profile_guarded` | Run the same serializers as the legacy entry points under the opt-in boundary. Nested calls to the original save methods stage under the same live context. Each serializer is bound by object identity and exact canonical path. Raw legacy writes, commit and recovery cannot operate inside the guarded attempt. |
| `Progress.load_garden_guarded`, `CharacterProfile.load_profile_guarded` | Read under locked preflight and return pending when the planner or process-local uncertainty blocks the participant. They never execute recovery. The caller can invoke the separate B2 recovery operation and reload after verification. Explicit non-recovering reads remain available. |
| `PersistenceOperations.backup_serializer` | Requires the canonical owner, exact migration-backup path and reserved sibling scratch in the same authorization. Copies and verifies bytes before publication using the existing native replacement primitive. Keeps an existing backup. An interrupted scratch can be reused only when its bytes match the original. A contradictory scratch refuses the save. |

[Transaction](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game_transaction.gd>) · [Operations](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd>) · [Garden serializer](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/progress.gd>) · [Profile serializer](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_profile.gd>) · [SaveBatch](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd>)

The guarded transaction keeps authorization, the action value, and the B1 finalization result separate. A verified abort restores snapshots and RNG. An uncertain outcome keeps tentative memory, clears the queued transaction publications, withholds the guarded post-commit callback, and blocks guarded action replay. A confirmed commit, including cleanup pending, keeps committed memory and can call the post-commit callback once. Cleanup pending blocks the next guarded transaction on that model. A fresh model must load verified data after recovery. This checkpoint does not connect arbitrary action-side RPCs, gameplay retry timers or success messages to the new callback. They remain part of caller migration.

The dormant serializer bridge latches the first participating serializer rejection into its own B1 attempt, including an early migration-backup failure. This prevents the opt-in pair from committing one side on a refused serializer. Legacy serializer error handling is unchanged. Migration backups remain outside the canonical atomic pair. Guarded saves preserve migration flags so retries can reconcile with retained backups. A complete Stage A audit of gameplay serializer paths, migration flag lifecycle and guest harvest messaging is still required.

## Exact validation runs

The existing AC-01 runner required current structured PASS, exit 0 and zero unexpected Godot errors. Tests used disposable roots and Godot 4.7.2. Packaged tests used a disposable Windows export with its matching native DLL.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| `persistence_group_one` | `b0g1-source-persistence_group_one-04` | `b0g1-pack-persistence_group_one-04` |
| `persistence_restart_recovery` | `b0g1-source-persistence_restart_recovery-03` | `b0g1-pack-persistence_restart_recovery-03` |
| `persistence_durable_evidence` | `b0g1-source-persistence_durable_evidence-03` | `b0g1-pack-persistence_durable_evidence-03` |
| `persistence_outcomes` | `b0g1-source-persistence_outcomes-03` | `b0g1-pack-persistence_outcomes-03` |
| `persistence_operations` | `b0g1-source-persistence_operations-03` | `b0g1-pack-persistence_operations-03` |
| `persistence_authorization` | `b0g1-source-persistence_authorization-03` | `b0g1-pack-persistence_authorization-03` |
| `persistence_recovery_plan` | `b0g1-source-persistence_recovery_plan-03` | `b0g1-pack-persistence_recovery_plan-03` |
| `persistence_save_access` | `b0g1-source-persistence_save_access-03` | `b0g1-pack-persistence_save_access-03` |
| `foundations` | `b0g1-source-foundations-03` | `b0g1-pack-foundations-03` |
| `combat_balance_saves` | `b0g1-source-combat_balance_saves-03` | `b0g1-pack-combat_balance_saves-03` |
| `character_roster` | `b0g1-source-character_roster-03` | `b0g1-pack-character_roster-03` |
| `content_validation` | `b0g1-source-content_validation-03` | `b0g1-pack-content_validation-03` |

**24 final source and packaged fixture runs and 53 planner self-tests passed.** The new fixture recorded standalone saves and loads, nested pair writes, backup hashes, early backup rejection after Garden staging, foreign lease and serializer refusal, unrelated reentry, legacy Batch bypass refusal, verified abort, uncertain memory and retry suppression, pending load without mutation, B2 recovery, committed cleanup pending, the guest Garden-only path, and the unchanged legacy route. The first probe, `b0g1-source-probe-01`, staged an unchanged profile before the forced Garden replacement failure. The resulting verified abort was correct. The fixture was corrected to change both participants for the uncertain case. [Source case evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-group1/logs/source-cases/persistence_group_one/unit.log>) · [Packaged case evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-group1/logs/pack-cases/persistence_group_one/unit.log>) · [Planner self-tests](<C:/Users/sutte/Documents/Codex/ac06-b0-group1/logs/planner.log>)

Two cross-process scenarios, `b0g1-source-interrupted-01` and `b0g1-pack-interrupted-01`, terminated the Group 1 writer after the character replacement and before the Garden replacement. Both children exited 1 as deliberately terminated. Fresh recovery processes restored the original character, verified both files, and removed the journal and auxiliaries. Fresh writers then committed through the same Group 1 route. The `-writer`, `-recover`, and `-write` child records include exits, engine diagnostics and canonical and artifact bytes/hashes. Both successful children in each scenario exited 0 with no unexpected engine errors. [Cross-process evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-group1/INTERRUPTED_GROUP_ONE.json>)

| Disposable binary | SHA-256 |
|---|---|
| Windows export | `30C2C16D525756CE73A266C4718CC3C63BE954DBD23E48E63921F48C2E7DD1DD` |
| Matching native sidecar | `AD827586970B7D701AF85007185FA2EF31213666ADD81674D47C3DAB96370379` |

Seven exact-match Garden regions were re-anchored to the extracted read and save bodies while keeping their existing systems and normalization layers. The focused preview resolved without unmatched scopes. It reported 107 affected unit suites because the changed files are shared foundations. The selected checkpoint tests do not certify a release or change live cache evidence. [Focused preview](<C:/Users/sutte/Documents/Codex/ac06-b0-group1/logs/plan-final.txt>)

## Inventory and activation blockers

`GROUP_1_GUARDED_ROUTES` records the tested entry points. `VERIFIED_WRITERS` stays empty because normal production callers still use the legacy APIs. A dormant route and fixture coverage do not certify that production cannot bypass it.

- The existing gameplay dispatcher, direct serializer callers, startup and shutdown still need typed pending, retry and publication handling. In particular, action-side feedback and replication are outside this snapshot and callback contract. Guest harvest messaging remains unchanged.
- Groups 2 and 3 still need direct slot and roster writers, imports, replacements, archive and compensation, deletes, catalogs, leases and settings. Unrelated legacy writers continue operating outside the dormant route. The guarded load path reports pending. It leaves selection of recovery and model reconciliation to the eventual production caller.
- Complete Stage A, cover the full writer inventory, and verify the real production entry points before cutover. Legacy committed journals without proof and ambiguous evidence remain blocked under B2. Process interruption on local NTFS was exercised. Sudden power-loss durability remains unverified. [Activation inventory](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>) · [Stage A contract](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/AC06_SAVE_TRANSACTION_CORRECTION_CONTRACT.md>)

## Changed project files

- `save_batch.gd`, `game_transaction.gd`, `progress.gd`, `character_profile.gd`, `persistence_operations.gd`, and `persistence_writer_integration.gd`
- `tests/persistence_group_one.gd`, `tools/test_map.json`, `docs/MECHANICS_TEST_MAP.md`, and this report

The B2 recovery executor, native backend, save and journal formats, gameplay dispatcher, settings, slot and roster writers, and validation executor were unchanged.