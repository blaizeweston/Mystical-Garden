# AC-06 Persistence Write Boundary Inventory

**Status:** Read-only audit. Path-level protection can use the existing batch, journal, and slot infrastructure. The current lease check and file mutation are separate, so a preflight alone leaves a race.

## Canonical writers

Garden and character paths include the legacy `user://` defaults, Garden slots under `user://saves/slot_N/`, and independent profiles under `user://saves/characters/slot_N/`. Preview and Developer Garden use the same writers under alternate roots.

| Writer | Canonical mutation | Recovery and coordination today |
|---|---|---|
| `Transactions.run()` → `SaveBatch.begin()/commit()` | Replaces the Garden and participating local profile. | Nested calls share a process-local batch. Begin has no recovery preflight or interprocess exclusion. |
| `Progress.save_garden()`, `CharacterProfile.save_profile()` | Create or replace the configured save. Migration copies write backup siblings. | Stage inside a batch or write a temporary file and rename it. No recovery preflight before saving. |
| `SaveBatch.recover()` | Restores or removes canonical files for both participants. | Used by loaders and commit. No common lock. A link to a missing journal can return success. |
| `SaveSlots.prepare(true)` | Imports legacy Garden, character, or guest files directly into slots. | No recovery check or claim around the copy. |
| `SaveSlots.ensure_character()`, `new_game()`, `new_world()` | Creates a profile, replaces a pair, or replaces a Garden. Pair replacement renames staged `.new` files onto canonical targets. | Checks slot activity without holding a claim. Existing-profile loading invokes recovery. Final pair renames bypass the batch. |
| `SaveSlots.delete_save()`, `archive_deleted_save()`, `restore_deleted_save()` | Moves a Garden and profile to an archive, or moves them back on failure. | The entry point claims the slot. Direct moves have no recovery check. |
| `SaveSlots.delete_world()` | Archives and removes the Garden. | Claims the slot. Only the tombstone write uses the batch. No recovery check on the Garden. |
| `CharacterSlots.create()`, `update()`, `prepare()` | Creates, updates, or imports a roster profile. Import can also recover the source. | Claims the destination. Update checks recovery on load. Import checks the source load without claiming it, and destination saves lack preflight. |
| `CharacterSlots.delete_character()`, `remove_character()` | Archives and removes a roster profile and updates the catalog. | Claims the roster slot and invokes recovery. Final removal is direct, and the claim does not serialize recovery across the linked Garden and profile. |

[SaveBatch](../save_batch.gd) · [Transaction wrapper](../game_transaction.gd) · [Garden serializer](../progress.gd#L217) · [Character serializer](../character_profile.gd#L109) · [Garden slots](../save_slots.gd) · [Character slots](../character_slots.gd)

## Risks and callers

The current lease reads a heartbeat and then writes a marker. Another process can pass the same check before that write. Character browsing can run recovery without a claim, and joining from the title can load a local Garden without claiming it. Disposable probes confirmed that Garden deletion and legacy import still changed canonical files after recovery returned an error. [Lease](../save_slots.gd#L100) · [Character browsing](../character_slots.gd#L38) · [Join setup](../main_menu.gd#L398) · [Probe log](C:/Users/sutte/Documents/Codex/ac06-9608be/AC06_BARRIER_PROBE.log)

Title startup, slot browsing and launch, the character editor, and Developer Garden need an explicit recovery-pending state. Standalone save feedback and dirty-profile shutdown paths must surface blocked writes. Transaction callers must distinguish pending from confirmed abort before retrying, rewinding RNG, restoring a scene, or publishing rewards. [Save feedback](../game.gd#L2877) · [Travel result](../party_travel.gd#L69) · [Harvest result](../game.gd#L2171) · [Reward publication](../monster_rewards.gd#L15)

## Minimal correction

1. Put one recovery preflight in `SaveBatch` and apply it to the actual canonical paths before standalone saves, outer transactions, and direct slot operations. Check import sources too. Resolve linked journals across known save roots when legacy links are incomplete. Block when recovery or participant identity cannot be established.
2. Hold a short atomic interprocess gate across preflight and mutation. Recheck existing slot ownership under that gate. Nested writers and internal recovery reuse the current operation’s authorization, so public save and recovery paths never reacquire each other’s lock. Reclaim an abandoned gate only when its owner is known to be gone.
3. Preserve unresolved journals and recovery inputs. Keep confirmed commit, confirmed abort, and pending recovery distinct, and permit affected writes only after verified resolution. Serializer first-error propagation and harvest-message deferral remain separate Stage A work.

## Disposable acceptance tests

- Block recovery, then attempt Garden deletion and legacy Garden and guest-profile imports. Require an explicit failure, unchanged canonical and journal bytes, and no archive or tombstone.
- Test pair and world replacement, legacy pair archiving, and roster removal with a cross-directory journal or dangling link. Verify no canonical, catalog, archive, or staged-file changes. Separately verify that authorized archive compensation restores the first file after a later move fails.
- Attempt standalone saves, migration backups, and roster imports with unresolved sources or destinations. Verify browsing and joining cannot recover an unclaimed Garden. Resolve the fault and retry through either participant.
- Pause one process between preflight and replacement. Verify a second process cannot write or recover the pair. Terminate the first process after one replacement and verify restart recovery, subsequent writes, and unrelated-slot access once the gate is free.
