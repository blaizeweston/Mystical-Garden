# AC-06 B0 Checkpoint 2A-2 — Directory bootstrap and passive save inspection

Implemented as opt-in infrastructure. The title, current slot summaries, serializers, transaction code, and recovery execution retain their existing behavior. The only new callers are tests. No live player save was read or changed, and no milestone EXE was replaced.

## Implementation and changed files

- `PersistenceAuthorization.bootstrap(paths)` validates a batch of exact supported directory paths, expands their supported ancestors, and creates only missing directories under the existing native root lock. It preflights the batch for file collisions, reparse points, case-sensitive or differently cased directories, and unsupported paths. It takes no callback, exposes no token, and releases the handle before returning. It reports directory creation separately from normal file authorization. The caller must then build a new plan and separately acquire ordinary file authorization. [Authorization](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_authorization.gd:36>)
- `persistence_save_layout.gd` and its UID hold the directory and canonical filename rules shared by bootstrap and the recovery planner. The layout covers normal and Preview save trees, Developer Garden, three Garden slots, and up to 128 roster slots. `persistence_recovery_plan.gd` reuses the layout and reports observed lease activity for passive inspection. It still performs discovery only. [Shared layout](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_save_layout.gd>) · [Recovery planner](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_recovery_plan.gd>)
- `persistence_save_inspection.gd` and its UID add `garden(path)` and `character(path)` for paths selected by the caller. They use read-only discovery, never acquire the lock, and never invoke recovery. Both return healthy, empty, busy, pending recovery, ambiguous, or invalid. A missing file named in a journal remains pending. Healthy projections include Garden knowledge, plot count and best clear, or character name, selected class, level and saved identity. Legacy identity is reported as pending with no generated ID. The active session marker also keeps an as-yet-unwritten slot busy. [Passive inspection](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_save_inspection.gd>)
- `tests/persistence_save_access.gd` adds the portable fixture. `tools/test_map.json` and the generated `docs/MECHANICS_TEST_MAP.md` register and document coverage. No changes to the native DLL, package runner, verdict checks, save formats, or journal formats were required. [Fixture](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/persistence_save_access.gd>) · [Registry](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tools/test_map.json>) · [Coverage map](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/MECHANICS_TEST_MAP.md>)

## Verification

All registered fixtures ran against a disposable project copy and separate APPDATA roots. Packaged fixtures used a staged Godot 4.7.2 Windows export under the existing packaged validation runner. Each listed fixture exited zero, produced a current structured PASS result, and recorded zero unexpected engine errors.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| Directory bootstrap and inspection, 30 case rows each | `ac06-b0-2a2-source-04` | `ac06-b0-2a2-pack-access-03` |
| Existing recovery planner | `ac06-b0-2a2-plan-source-01` | `ac06-b0-2a2-pack-plan-01` |
| Existing authorization | `ac06-b0-2a2-auth-source-01` | `ac06-b0-2a2-pack-auth-01` |
| Content validation | `ac06-b0-2a2-content-01` | — |

The bootstrap fixture created eight directories across fresh Garden, roster, and Preview Developer Garden paths. An idempotent retry created zero. The fixture rejected mixed requests containing unsupported paths, canonical files, journals, participant links and archives before creating any directories. It also rejected a regular file and a differently cased directory occupying a requested slot path. Reusing an existing directory preserved archive, journal and link bytes. Ordinary authorization succeeded with a freshly discovered plan after bootstrap returned. Attempting bootstrap inside a normal file operation returned busy.

Passive inspection covered all six states. It matched the persisted character identity, class and level from the existing non-recovering loader and projected Garden summary values. It distinguished a missing character referenced by a Garden journal from an empty roster slot and refused overlapping journals. Every passive case compared the complete disposable tree before and after by directory names and file hashes. Inspection never created a sentinel or changed canonical files, recovery artifacts, leases, or archives. [Source case records](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/source-04/persistence_save_access/unit.log>) · [Packaged case records](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/pack-access-03/persistence_save_access/unit.log>) · [Source verdict](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/source-04/persistence_save_access/verdict.json>) · [Packaged verdict](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/pack-access-03/persistence_save_access/verdict.json>)

### Independent-process and path probes

| Exact run ID pattern | Result |
|---|---|
| `ac06-b0-2a2-{source,pack}-03-interrupted-owner` | The fault-injection process acquired the production sentinel and used the production creation helper for the first directory. The supervisor terminated it after `user://saves` existed. Exit 1 was expected. |
| `ac06-b0-2a2-{source,pack}-03-contention` | A separate process called public bootstrap while the owner was alive. It returned Godot `ERR_BUSY` and Win32 sharing violation 32 with `ran=false` and created no directories. The probe exited 0 after observing the expected refusal. |
| `ac06-b0-2a2-{source,pack}-03-retry-after-kill` | A new process acquired the lock and completed the remaining directories. Exit 0. The sentinel was the only persistence file. The engine and diagnostics autoload also produced their usual logs in the disposable root. |
| `ac06-b0-2a2-source-junction-01` | A junction at `user://saves` was refused with `ERR_INVALID_PARAMETER` and zero created directories. The separate probe exited 4 as expected. Its disposable junction target and original bytes were untouched. |

The first subprocess probe used the console launcher PID. The final supervisor used the paired engine executable so process identity and termination checks applied to the actual lock owner. [Source process evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/process-source-03/summary.json>) · [Packaged process evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/process-pack-03/summary.json>) · [Junction evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/alias-probe/result.json>)

All 53 planner self-tests passed. A focused preview selected content validation and the three persistence suites above. No full release run or installer run was performed. [Planner self-tests](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/logs/planner-tests.log>) · [Focused preview](<C:/Users/sutte/Documents/Codex/ac06-b0-2a2/logs/focused-preview.log>)

## Remaining limits

- Bootstrap can leave empty directories created before an error or termination. Retry validates and reuses them. No directory result authorizes a save mutation.
- The lock retains Checkpoint 1’s Windows x64 local NTFS constraints. It coordinates participating processes. Existing gameplay writers and external filesystem edits are outside that boundary.
- Passive inspection is advisory. It confirms summary bytes still match the planner observation and uses the same namespace and bounds. It grants no ownership and cannot replace a fresh locked plan before a write. A blocked result can leave `exists` unknown. Invalid or legacy identities are left for the existing authorized loader to resolve when integration is approved.
