# AC-06 Save Transaction Audit Summary

## Confirmed findings

`Transactions.run()` ignores the return values from `Progress.save_garden()` and `CharacterProfile.save_profile()`. If either serializer returns before `SaveBatch.write()`, the batch can commit the other file and report success. Four disposable probes reproduced this split: an early Garden or character rejection and a migration-backup copy failure on either side. Both staging-write failures preserved the original files, restored memory, and returned failure. [Transaction wrapper](../game_transaction.gd#L24) · [Probe results](C:/Users/sutte/Documents/Codex/ac06-9608be/AC06_PROBE_RESULTS.json)

A guest harvest message can be sent after staging but before commit. Combat events and character replication already wait for commit. The message ordering was verified in code. [Harvest and save path](../game.gd#L2182) · [Message dispatch](../game.gd#L2877)

## Safeguards and gaps

- The wrapper snapshots gameplay data and rolls it back on a reported batch failure. Nested operations share the batch. Migration backups are copied outside the batch, and the serializers check copy errors before staging. [Garden serializer](../progress.gd#L217) · [Character serializer](../character_profile.gd#L109)
- The batch checks journal writes, link writes, file replacements, and recovery writes. It does not independently verify the original-byte or link reads, check the `store_buffer()` result, or check each stage and link cleanup result. A blocked recovery write left a disposable pair mixed with its journal intact. After the obstruction was removed, recovery restored both originals. Journal deletion can also report failure after the commit marker is written, which can trigger an in-memory rollback of an already committed save. [Batch implementation](../save_batch.gd#L7) · [Recovery probe](C:/Users/sutte/Documents/Codex/ac06-9608be/recovery.log)
- Existing fixtures cover staging failures, in-memory rollback, a readable uncommitted journal, and successful migration backups. Early serializer rejection, failed backups, and failed recovery or cleanup after file replacement need dedicated regression coverage. [Foundations](../tests/foundations.gd#L26) · [Garden growth](../tests/garden_growth.gd#L52) · [Migration coverage](../tests/combat_balance_saves.gd#L79)

## Proposed correction and acceptance

Keep the existing batch. Latch the first non-OK result from every participating save, including pre-write and nested saves. Discard staged writes and use the existing rollback path. Send success only after commit. Preserve unresolved journals and block further writes until recovery completes. Treat cleanup failures after confirmed commit separately.

Test early Garden rejection, character rejection after Garden staging, migration-copy failures on either side, and failed stage writes on either side. Each case should leave both original files byte-identical, restore memory, and report failure without success feedback. Verify that retry commits both files. Preserve valid migration backups already written.
