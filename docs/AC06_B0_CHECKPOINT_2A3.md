# AC-06 B0 Checkpoint 2A-3 — Guarded writer integration boundary

The opt-in boundary is implemented. Normal gameplay still uses the existing persistence paths. Production activation is blocked, and B0 writer coverage remains open. All execution used a disposable project and isolated save roots. The desktop game build and live player data were outside the run.

## Guarded entry points

| Entry point | Contract |
|---|---|
| `PersistenceOperations.inspect` | Delegates to passive Garden or character inspection. Browsing has no write authority. |
| `PersistenceOperations.prepare` | Builds a read-only snapshot of the actual canonical paths, recovery participants and anchors, and declared metadata. Directory bootstrap remains the separate existing operation and must finish before this preview is built. |
| `PersistenceOperations.run` | Acquires the existing root lock for the complete plan and declared auxiliaries. Revalidates discovery and metadata under that lock before issuing a context. Refuses changed destinations, additional participants, changed recovery evidence, foreign leases, and an already-active SaveBatch. A valid pending journal blocks the writer and remains available for recovery. |
| `PersistenceOperations.run_nested` | A synchronous helper uses the same live context and an exact subset of already-authorized paths. Foreign, expired, expanded, and independently reentrant operations are refused. This is the reuse interface for serializers and future recovery helpers. |
| `PersistenceOperations.run_production` | Checks the integration inventory before discovery or acquisition. Reports every unverified writer group and the disabled cutover. No normal gameplay caller uses this entry point. |

Declared auxiliary paths are restricted to known siblings of canonical participants and scoped slot or roster metadata. Supported declarations include standalone temp files, migration backups, session markers, tombstones, pair replacement staging, world selection settings, and the roster catalog. The callback value and boundary error stay separate, including release errors after a callback ran. The boundary makes no commit or rollback determination. [Guarded operation interface](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd>) · [Activation check and inventory](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>)

## Remaining bypasses and activation blockers

| Production surface | Remaining work |
|---|---|
| `SaveBatch.write_bytes/write/begin/commit/cancel/recover`, `GameTransaction.run` | Bind actual staging, replacement, cleanup, and internal recovery to the scoped context. The legacy commit result conflates failed replacement, failed recovery and cleanup after commit. `GameTransaction.run` can restore in-memory state on any returned error. Correct outcome handling and safe execution of validated recovery plans are B1/B2 dependencies. [Batch](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_batch.gd>) · [Transaction](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/game_transaction.gd:24>) |
| `Progress.save_garden/load_garden`, `CharacterProfile.save_profile/load_profile` | Bind serializers, migration backups and recovery-capable loads. Fixture coverage demonstrates reuse by synchronous writers, while the existing production entry points still bypass the boundary. Serializer first-error propagation and harvest feedback are Stage A. [Garden](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/progress.gd:217>) · [Profile](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_profile.gd:90>) |
| `SaveSlots.prepare/ensure_character/new_game/new_world` | Guard legacy imports, creation, replacement and Developer Garden resets. Resolve source and destination before mutation. Legacy pair replacement uses two sequential renames, so a lock alone does not guarantee crash atomicity. [Slots](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd>) |
| `SaveSlots.delete_save/archive_deleted_save/restore_deleted_save/delete_world`, `CharacterSlots.delete_character/remove_character` | Bind deletion and restoration to the canonical participants. Timestamped archive creation, movement, and compensation require a scoped adapter for destinations that do not exist at preview time. This checkpoint rejects archive targets. Legacy compensation errors need explicit treatment before calling these paths safe. [Garden deletion](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd:146>) · [Roster deletion](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_slots.gd:122>) |
| `SaveSlots.claim/heartbeat/release/remember_slot`, `CharacterSlots.prepare/summary/create/update/set_capacity/remember` | Bind lease and catalog helpers, make browsing passive, and handle refusals in menu and lifecycle callers. Imports currently discover their roster destination while running. A future adapter must determine that destination before mutation and revalidate it under the same lock. Session markers continue to represent session ownership. The native handle only covers the synchronous operation. [Slot metadata](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd:107>) · [Roster](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_slots.gd>) |
| `AppSettings.save_settings` | The general settings file is outside the canonical save set, but its shared `SaveBatch.write` can stage into an active gameplay batch. Exclude it from that batch or explicitly bind its use before marking the shared writer covered. [Settings](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/app_settings.gd:64>) |

The inventory has 17 pending writer groups plus the cutover flag. Fixture wrappers do not count as production coverage. The capability scopes cooperating calls and cannot intercept arbitrary filesystem access inside a callback or in older builds. Future activation needs verified guards at each real writer, including recovery-capable loads, archive and compensation operations, and menu/shutdown callers that handle refusal or pending status. [Integration inventory](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>)

## Verification

Godot 4.7.2 source runs and packaged Windows runs used the existing AC-01 verdict runner. Packaged fixtures ran the exported game pack under the installed engine with the exported native DLL. All final runs exited 0 with current structured PASS results and zero unexpected engine errors. The export DLL matched the source DLL. The desktop EXE was outside the test and install workflow.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| `persistence_operations` | `b0-2a3-source-persistence_operations-04` | `b0-2a3-pack-persistence_operations-04` |
| `persistence_authorization` | `b0-2a3-source-persistence_authorization-04` | `b0-2a3-pack-persistence_authorization-04` |
| `persistence_recovery_plan` | `b0-2a3-source-persistence_recovery_plan-04` | `b0-2a3-pack-persistence_recovery_plan-04` |
| `persistence_save_access` | `b0-2a3-source-persistence_save_access-04` | `b0-2a3-pack-persistence_save_access-04` |
| `foundations` | `b0-2a3-source-foundations-04` | `b0-2a3-pack-foundations-04` |
| `delete_saves` | `b0-2a3-source-delete_saves-04` | `b0-2a3-pack-delete_saves-04` |
| `character_roster` | `b0-2a3-source-character_roster-04` | `b0-2a3-pack-character_roster-04` |
| `content_validation` | `b0-2a3-source-content_validation-04` | `b0-2a3-pack-content_validation-04` |

The new fixture exercised actual Garden and roster creation, catalog growth, lease claim/heartbeat/release, and Garden/profile serialization inside one guarded operation. It rejected foreign and expired contexts, scope expansion, an incomplete native scope, a competing outer operation, a foreign active lease, changed destination, and changed metadata. Each refusal ran zero mutation callbacks. Save and recovery bytes and directory listings were unchanged. A callback error stayed distinct from the boundary result and the next operation acquired the lock successfully.

The recovery probe placed a journal at `user://saves/slot_1/garden.cfg.transaction` with only `user://saves/characters/slot_1/character.cfg` in its entries and no participant links. Reverse discovery reported both canonical paths and the Garden anchor. A fresh pending plan refused with `journal_found`. An old plan refused under lock with `observations_changed` or `participant_set_changed`, depending on whether it already included the profile. The journal and canonical bytes remained intact. [Source verdict](<C:/Users/sutte/Documents/Codex/ac06-b0-2a3/logs/source-04/persistence_operations/verdict.json>) · [Packaged verdict](<C:/Users/sutte/Documents/Codex/ac06-b0-2a3/logs/pack-04/persistence_operations/verdict.json>) · [Packaged case results](<C:/Users/sutte/Documents/Codex/ac06-b0-2a3/logs/pack-04/persistence_operations/unit.log>)

`python -B -m unittest discover -s tools/tests -p 'test_*.py'` passed all **53** tests. Focused planning selected `persistence_operations` and `content_validation`. The first source probe, `b0-2a3-source-operations-01`, failed because the fixture included Godot logs and diagnostics in the save manifest. Restricting that assertion to the persistence tree fixed the false failure. No AC-01 checks were altered. [Planner self-tests](<C:/Users/sutte/Documents/Codex/ac06-b0-2a3/logs/planner-self-tests.log>) · [Focused plan](<C:/Users/sutte/Documents/Codex/ac06-b0-2a3/logs/planner-preview.txt>) · [Initial probe verdict](<C:/Users/sutte/Documents/Codex/ac06-b0-2a3/logs/source-01/persistence_operations/verdict.json>)

## Changed files

- Guarded operations and activation inventory, with their Godot UID files. [Operations](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd>) · [Inventory](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>)
- Disposable regression fixture. [Fixture](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/persistence_operations.gd>)
- Test registry, regenerated mechanics map, and this report. [Registry](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tools/test_map.json>) · [Map](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/MECHANICS_TEST_MAP.md>)

Fourteen existing files, including production writers, gameplay entry points, project settings, the existing authorization and planning components, and the SaveBatch and transaction code, matched the source bytes. No save or journal format changed.