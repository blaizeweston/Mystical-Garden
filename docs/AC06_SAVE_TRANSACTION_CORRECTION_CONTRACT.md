# AC-06 Save Transaction Correction Contract

**Status:** Proposed. The existing `SaveBatch` journal and rollback snapshots remain the basis of the correction. The atomic save set is the Garden and participating local character. A guest’s own profile is saved separately on the guest machine.

## Transaction outcomes

| Outcome | Persistent files | In-memory state and rollback | Next write | Guest success | Recovery |
|---|---|---|---|---|---|
| Failure before commit | Both originals are untouched or verified restored. | Restore the snapshot. | Allowed after staging artifacts are cleared or verified safe to reuse. | Discard queued success and report failure. | Cancel staging. Retain any journal until restoration is verified. |
| Successful commit | Both replacements and the commit marker are confirmed. | Keep the new state. Rollback is prohibited. | Allowed after cleanup. | Send queued success once. | None. |
| Committed, cleanup pending | Both new files remain authoritative. | Keep the new state. Rollback is prohibited. | Block writes to the affected save set until cleanup succeeds. | Send queued success once. Report cleanup separately. | Retry cleanup only. Keep the journal until participant cleanup succeeds. |
| Uncertain commit or incomplete recovery | The pair may be old, new, or mixed. | Pause affected gameplay and publication. Reconcile from the verified files. Rollback requires confirmation of the old pair. | Block all affected writes, including standalone saves. | Withhold success and report recovery pending. | Preserve the journal and verify both files before resuming. |

## Stage A — Serializer errors and success messages

- Use one first-error latch for the outer batch. Both serializers, `SaveBatch.write()`, and existing direct failure assignments use it. Nested operations share it. A later save or error cannot replace the first error. The outer wrapper checks every required serializer before commit.
- On failure, stop staging and discard all stage artifacts created by the batch, including incomplete stages. Restore the captured state and discard queued success. A failed stage cleanup prevents unsafe reuse of that path.
- Keep migration backups outside the atomic pair. Preserve valid backups on abort, and publish new backups only after a verified copy. Restore migration flags or reconcile them against verified backups before retry.
- Queue the existing guest harvest confirmation after staging succeeds. Send it once after confirmed commit, preserving its recipient, wording, yield, familiarity, and RNG behavior. Send validation and readiness messages immediately.

**Acceptance:** On disposable Garden and character pairs, inject early Garden rejection, character rejection after Garden staging, migration-copy failure on either side, stage-write failure on either side, and nested errors followed by a successful save attempt. Verify byte-identical originals, restored memory, the first error retained, and zero guest success messages. A clean retry must commit both files and send exactly one harvest confirmation.

## Stage B — Commit, recovery, and cleanup

- Before replacement, fully read each original or positively establish absence. Verify stage writes and flush results. Read back and validate the uncommitted journal and participant links.
- Publish `committed=true` after every replacement succeeds. Use a checked temporary write and rename to preserve the readable uncommitted record if publication fails. Confirm the marker belongs to the current attempt. This defines restart recovery. Power-loss durability still depends on filesystem guarantees.
- Separate cleanup errors from commit failure. Keep an unresolved journal and block affected writes until the pair is verified. Give callers an explicit pending outcome so they withhold success and ordinary retry messages.

**Acceptance:** On disposable files, inject an unreadable original, an invalid link, failure after the first replacement, a failed marker update, blocked recovery, and cleanup failure after a confirmed commit. Verify preflight failures prevent replacement, recovery restores the old pair or retains the verified new pair, and pending recovery blocks writes and success. After a committed cleanup failure, verify that both new files and memory remain intact, success is sent once, and cleanup retries without replaying the action. Verify restart recovery through either participant and compatibility with existing readable journals.

[AC-06 audit summary](AC06_SAVE_TRANSACTION_AUDIT_SUMMARY.md) · [Transaction wrapper](../game_transaction.gd#L24) · [SaveBatch](../save_batch.gd#L20)
