# AC-06 B2 Phase 2 — Authorized restart recovery

The opt-in restart executor is implemented. Normal gameplay still uses the legacy save path. No player saves, installed EXE, native DLL, gameplay or multiplayer code, canonical save format, or primary journal format changed.

## Recovery behavior

- `PersistenceOperations.recover(paths)` is a recovery-only call with no gameplay callback. It discovers linked paths, acquires the existing root lock once, and passes the exact authorized scope to SaveBatch. SaveBatch revalidates under that token, prevalidates all selected records and destinations, and checks intermediate restore footprint before writing. Nested recovery and native replacements reuse the live authorization. The return separates authorization acquisition/release from filesystem, restoration and cleanup errors. [Entry point](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd:88>) · [Locked executor](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd:543>)
- Uncommitted recovery restores only entries, verifies original bytes or recorded absence, and leaves an anchor-only canonical file untouched. For B2 records, existing files must match old or independently recorded new bytes before recovery will mutate the set. A durable primary without a prepared manifest can still be cleaned when every old entry already matches. Legacy uncommitted records use the strictly parsed original entries and validated paths. The legacy format cannot identify the intended new bytes. [Restoration](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd:628>) · [Planner](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_recovery_plan.gd>)
- Committed recovery verifies expected existence, length and hash. It promotes prepared evidence to a terminal receipt when needed and performs cleanup only. A verified receipt can finish cleanup after the primary disappears. Before removing terminal authority, recovery rechecks participant bytes and confirms other owned artifacts are gone. A fresh locked scan and final byte verification complete the operation. A later guarded writer still runs its own preflight. [Executor](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd:543>) · [Attempt binding](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_evidence.gd:91>)
- Corrupt, contradictory, overlapping, unsafe or unowned evidence is preserved. A committed legacy journal with no new-byte proof remains blocked. A missing primary with fallback and prepared evidence remains uncertain, since that evidence cannot distinguish a lost uncommitted marker from a lost committed one. A receipt-only record with unexpected residue stays blocked. Same-process uncertainty clears only on verified recovery of the matching attempt. [Evidence validation](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_recovery_plan.gd>) · [Uncertainty tracking](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd:143>)

## Source and packaged verification

The normal fixture runner required current structured PASS, exit 0, and zero unexpected Godot errors. Windows packaged tests used the disposable game export under `--main-pack` with its hash-matched sidecar. **20 final fixture runs and 53 planner self-tests passed.**

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| `persistence_restart_recovery` | `b2p2-source-persistence_restart_recovery-04` | `b2p2-pack-persistence_restart_recovery-04` |
| `persistence_durable_evidence` | `b2p2-source-persistence_durable_evidence-03` | `b2p2-pack-persistence_durable_evidence-03` |
| `persistence_outcomes` | `b2p2-source-persistence_outcomes-03` | `b2p2-pack-persistence_outcomes-03` |
| `persistence_operations` | `b2p2-source-persistence_operations-03` | `b2p2-pack-persistence_operations-03` |
| `persistence_authorization` | `b2p2-source-persistence_authorization-03` | `b2p2-pack-persistence_authorization-03` |
| `persistence_recovery_plan` | `b2p2-source-persistence_recovery_plan-03` | `b2p2-pack-persistence_recovery_plan-03` |
| `persistence_save_access` | `b2p2-source-persistence_save_access-03` | `b2p2-pack-persistence_save_access-03` |
| `foundations` | `b2p2-source-foundations-03` | `b2p2-pack-foundations-03` |
| `combat_balance_saves` | `b2p2-source-combat_balance_saves-03` | `b2p2-pack-combat_balance_saves-03` |
| `content_validation` | `b2p2-source-content_validation-03` | `b2p2-pack-content_validation-03` |

The new fixture exercised a readable legacy uncommitted journal with no links, an anchor outside the entry list, an initially absent character, foreign lease, incomplete or drifted authorization, an injected restoration write failure, cleanup failure followed by retry, contradictory committed bytes, legacy committed refusal, corrupt and unsafe records, overlapping journals, invalid links and unowned stage/restore scratch. The fixture checked refusal bytes, independent errors, idempotent retry, and a real subsequent guarded commit. [Source case records](<C:/Users/sutte/Documents/Codex/ac06-b2p2/logs/source-cases/persistence_restart_recovery/unit.log>) · [Packaged case records](<C:/Users/sutte/Documents/Codex/ac06-b2p2/logs/pack-cases/persistence_restart_recovery/unit.log>) · [Planner self-tests](<C:/Users/sutte/Documents/Codex/ac06-b2p2/logs/planner.log>)

### Cross-process interruption matrix

Each exact parent ID is `b2p2-source-<case>-03` or `b2p2-pack-<case>-03`, using the case names below. The evidence records all child IDs, with `-writer`, `-recovery`, `-repeat`, and `-followup`, plus `-interrupted-recovery`, `-holder` or `-contender` where applicable. All **22 scenarios** passed. The supervisor verified deliberate exit 1 on termination, exit 0 and current structured results for ordinary children, and zero unexpected engine errors. After each successful recovery, a repeat reported clean with identical bytes and a real follow-up transaction committed.

| Case | Verified disk outcome |
|---|---|
| `before_first` | Old pair already present. Verified it and cleared owned artifacts. |
| `after_first` | Restored the replaced character. Garden already matched the old bytes. |
| `before_marker` | Both replacements had landed. Restored and verified both originals. |
| `after_marker` | Verified the new pair. Published the receipt and cleaned artifacts only. |
| `after_receipt` | Verified the new pair and used the existing receipt to finish cleanup. |
| `after_primary` | Primary absent. Discovered the pair through the receipt and verified it before removing the receipt. |
| `partial_cleanup` | Resumed cleanup after a link had already been removed. |
| `restore_kill` | First recovery restored the character and was terminated. Next process restored the Garden and verified both. |
| `cleanup_kill` | First recovery published the receipt and removed one link before termination. Next process kept the new pair and finished cleanup. |
| `absent` | Removed the newly created character and verified its recorded absence. |
| `contention` | Second process received ERR_BUSY while a holder owned the sentinel. Recovery succeeded after that holder was terminated. |

[All interruption run IDs, exact hex bytes and SHA-256, artifacts, recovery results, exits, and follow-up permission](<C:/Users/sutte/Documents/Codex/ac06-b2p2/RESTART_RESULTS.json>) · [Supervisor](<C:/Users/sutte/Documents/Codex/ac06-b2p2/restart_supervisor.py>) · [Godot phase driver](<C:/Users/sutte/Documents/Codex/ac06-b2p2/restart_driver.gd>)

### Native backend refusal

`b2p2-source-backend-missing-01`, `b2p2-pack-backend-missing-01`, `b2p2-source-backend-old-01`, and `b2p2-pack-backend-old-01` exited 0 after proving `ERR_UNAVAILABLE` and unchanged Garden and journal bytes. The old lock-only DLL loaded but lacked the authorized replacement method. The missing DLL produced expected, narrowly checked loader messages in the external negative probe. The ordinary verdict runner was unchanged. [Backend evidence](<C:/Users/sutte/Documents/Codex/ac06-b2p2/BACKEND_RESULTS.json>)

| Binary | SHA-256 |
|---|---|
| Godot 4.7.2.stable.official.ed1daf0bf Windows engine | `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424` |
| Disposable `B2Phase2.exe` | `BD016B82211D40C7FE0C31EAB232E2309ED79F192E40880E02870D9DD780E02E` |
| Phase 1 native DLL, unchanged and matched in source and export | `AD827586970B7D701AF85007185FA2EF31213666ADD81674D47C3DAB96370379` |

Two development probes failed before final verification. `b2p2-source-probe-01` caught an unsupported array method during the final scan. `b2p2-source-probe-03` caught a test that left a valid journal in place while attempting to construct an orphan stage. Both were corrected and the final source and packaged runs passed. The foundation change affected the focused planner preview, so these selected checks do not certify the full release suite or refresh live cache evidence. [Focused preview](<C:/Users/sutte/Documents/Codex/ac06-b2p2/logs/plan.txt>)

## Changed project files

- [SaveBatch](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd>), [PersistenceOperations](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd>), [PersistenceRecoveryPlan](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_recovery_plan.gd>), and [PersistenceEvidence](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_evidence.gd>).
- [Restart recovery fixture](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/persistence_restart_recovery.gd>), [test registry](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tools/test_map.json>), [generated mechanics map](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/MECHANICS_TEST_MAP.md>) and this report.

## Remaining activation blockers

Complete B0 writer coverage, migrate callers to the guarded outcomes and pending state, isolate settings and metadata writes, and finish Stage A before enabling production. Establish an operator path for unverifiable records, including committed legacy data, missing authoritative primaries, and unbound or torn publication evidence the executor cannot prove safe. The executor never reconstructs or rolls back mismatched committed bytes. The tested guarantee covers cooperating processes and the observed termination barriers on local Windows NTFS. Sudden power loss and outside filesystem tampering remain outside that guarantee. [Activation gate](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>) · [Transaction contract](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/AC06_SAVE_TRANSACTION_CORRECTION_CONTRACT.md>)