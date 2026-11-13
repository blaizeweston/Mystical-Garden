# AC-06 B1 — Explicit SaveBatch finalization outcomes

The typed finalization interface is implemented and remains opt-in. Normal gameplay still uses the legacy SaveBatch API. The production activation gate remains closed. No gameplay caller, serializer, harvest message, settings caller, or validation executor changed. All runs used disposable project copies, save roots, and an isolated Windows export. No player save or installed EXE was used or replaced.

## Implementation

- `SaveBatch.Finalization` is a typed result with four outcomes: `COMMITTED`, `ABORTED_RESTORED`, `COMMITTED_CLEANUP_PENDING`, and `UNCERTAIN`. It records the first error, separate recovery and cleanup errors, phase, affected paths, journal anchor, attempt ID, evidence and write-block status. The attempt ID is process-local and does not change the save or journal format. The legacy methods remain byte-identical. [Result and legacy API](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd:69>)
- `PersistenceOperations.run_batch` runs the opt-in batch inside the existing root lock and fresh locked preflight. The authorization result, batch execution result, typed disposition and callback value are distinct. The callback receives a scoped stage callable and operation context. A nested helper may stage a declared participant. Only the outer owning operation finalizes. An unrelated or foreign call cannot finalize or acquire a second batch, and the stage callable expires before finalization. An explicit no-op verifies the original state. An ordinary batch must stage every declared participant. [Operation entry point](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd:78>) · [SaveBatch ownership](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd:93>)
- SaveBatch reads originals or establishes their absence, verifies staged bytes, publishes and verifies the current uncommitted record and links, replaces participants, and verifies the committed marker and all new bytes before certifying commit. For this live attempt, exact uncommitted journal bytes and compatible participant states allow checked restoration. All original bytes or recorded absences must match before abort is confirmed. Contradictory or insufficient evidence stays uncertain. The journal is removed last, and a failed cleanup after confirmed commit preserves the committed disposition. [Finalization](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd:179>) · [Restoration and cleanup](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd:262>)

## Disposable fixture results

Source and packaged `persistence_outcomes` returned the same outcomes and disk effects. The existing AC-01 runner required current structured results, process exit 0 and zero unexpected engine errors. Fixture case records contain the exact text bytes or absence of each participant and artifact, the raw journal, marker, first/recovery/cleanup errors, attempt identity, and the subsequent guard decision.

| Case | Outcome and errors | Canonical Garden / character | Journal and subsequent guarded write |
|---|---|---|---|
| Pair, action returned `false` | `COMMITTED` | `new` / `new` | Removed. Allowed. |
| Standalone, action returned `null` | `COMMITTED` | Character `new` | Removed. Allowed. |
| Explicit no-op | `COMMITTED`, explicit no-op evidence | Character `new` unchanged | Absent. Allowed. |
| Undeclared no-op | `ABORTED_RESTORED`, `ERR_INVALID_DATA` | Character `new` unchanged | Absent. Allowed. |
| Stage failure before replacement | `ABORTED_RESTORED`, `ERR_CANT_CREATE` | `garden-old` / `character-old` | Absent, staged residue removed. Allowed. |
| Second replacement refused | `ABORTED_RESTORED`, `ERR_CANT_CREATE` | `garden-old` / verified absence | Removed. Allowed. |
| Second replacement refused, restore failed | `UNCERTAIN`, `ERR_CANT_CREATE` and recovery `ERR_FILE_CANT_WRITE` | `garden-old` / `new` | Uncommitted, links and stage retained. Both participant writes blocked. |
| Commit marker publication refused | `ABORTED_RESTORED`, `ERR_CANT_CREATE` | `garden-old` / `character-old` | Verified uncommitted before restore, then removed. Allowed. |
| Confirmed marker, journal removal failed | `COMMITTED_CLEANUP_PENDING`, cleanup `ERR_CANT_CREATE` | `new` / `new` | Committed marker retained. Both participant writes blocked. |
| Confirmed marker conflicts with a participant's bytes | `UNCERTAIN`, `ERR_INVALID_DATA` | `new` / `contradictory` | Committed marker and evidence retained. Blocked. |
| Foreign or expired authority, nested reentry | `ERR_UNAUTHORIZED` for foreign or expired authority, `ERR_BUSY` for a second batch | Original successful pair stays `new` / `new` | Absent. Valid outer ownership was still able to commit. |

The blocked cases probed subsequent guarded entry and checked for canonical or journal changes. Reverse lookup from the roster profile also discovered the pending pair after cleanup had removed its links. This is a planner check, not an actual restart recovery run. [Source case records](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/source-02/persistence_outcomes/unit.log>) · [Packaged case records](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/pack-02/persistence_outcomes/unit.log>) · [Source verdict](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/source-02/persistence_outcomes/verdict.json>) · [Packaged verdict](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/pack-02/persistence_outcomes/verdict.json>)

## Exact regression runs

| Fixture | Source run | Packaged run | Result |
|---|---|---|---|
| `persistence_outcomes` | `b1-source-persistence_outcomes-02` | `b1-pack-persistence_outcomes-02` | PASS |
| `persistence_operations` | `b1-source-persistence_operations-02` | `b1-pack-persistence_operations-02` | PASS |
| `persistence_authorization` | `b1-source-persistence_authorization-02` | `b1-pack-persistence_authorization-02` | PASS |
| `persistence_recovery_plan` | `b1-source-persistence_recovery_plan-02` | `b1-pack-persistence_recovery_plan-02` | PASS |
| `persistence_save_access` | `b1-source-persistence_save_access-02` | `b1-pack-persistence_save_access-02` | PASS |
| `foundations` | `b1-source-foundations-02` | `b1-pack-foundations-02` | PASS |
| `combat_readability` | `b1-source-combat_readability-02` | `b1-pack-combat_readability-02` | PASS |
| `combat_balance_saves` | `b1-source-combat_balance_saves-02` | `b1-pack-combat_balance_saves-02` | PASS |
| `content_validation` | `b1-source-content_validation-02` | `b1-pack-content_validation-02` | PASS |
| `garden_growth_coop` | `b1-source-garden_growth_coop-03` | `b1-pack-garden_growth_coop-03` | PASS |

- All 20 final runs passed. The co-op runs returned current PASS results from host and guest and showed offline peers before world removal. The initial `b1-{source,pack}-garden_growth_coop-{01,02}` runs and `b1-prechange-garden_growth_coop-01` timed out in the restricted environment. A plain localhost UDP probe also timed out. Loopback worked after network permission and both unchanged fixtures passed on retry. [Co-op source verdict](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/source-03/garden_growth_coop/verdict.json>) · [Co-op packaged verdict](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/pack-03/garden_growth_coop/verdict.json>)
- Early probes `b1-source-probe-01` and `b1-source-probe-02` caught a fixture type inference error and an expired callable that raised an engine error. The latter exited 0 and AC-01 still rejected it. The final callable returns `ERR_UNAUTHORIZED` after the scope expires. `b1-source-probe-03` and `b1-source-probe-04` passed. [Early failed verdict](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/probe-02/persistence_outcomes/verdict.json>)
- Planner self-tests passed **53/53**. The planner classified `save_batch.gd` as a shared foundation input and showed 104 impacted focused suites. This checkpoint ran the affected persistence and selected legacy regression fixtures. It did not certify a full release or refresh live cache evidence. [Planner results](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/planner-self-tests.log>) · [Focused impact preview](<C:/Users/sutte/Documents/Codex/ac06-b1/logs/planner-preview.txt>)

## Activation blockers

- **B2 recovery execution and interruption evidence.** This checkpoint verifies and can restore only a live attempt with the current uncommitted record and known original or staged participant bytes. It does not change legacy restart recovery, resolve contradictory committed journals, or certify power-loss durability. Some ambiguous failures without durable artifacts are only latched in the current process. B2 must define restart discovery and safe disposition for those cases, including interrupted publication and scratch artifacts.
- **Writer coverage and caller migration.** Legacy production serializers, direct imports, replacement, deletion, archive/restore and settings still have their existing behavior and can bypass the opt-in boundary. Bind all affected writer and recovery paths before activation. Migrate callers to gate rollback, publication, and retry on the typed outcome. The new write-block status describes the guarded path only.
- **Stage A and settings isolation.** First-error propagation from participating gameplay serializers, harvest success deferral, and independent settings writes remain open. No gameplay rollback or publication code changed at B1. [Activation inventory](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>) · [Correction contract](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/AC06_SAVE_TRANSACTION_CORRECTION_CONTRACT.md>)

## Changed project files

- [SaveBatch](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd>) and [PersistenceOperations](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd>)
- [Disposable outcome fixture](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/persistence_outcomes.gd>)
- [Test registry](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tools/test_map.json>), [generated mechanics map](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/MECHANICS_TEST_MAP.md>), and this report