# AC-06 B0 writer integration — Group 2A

Group 2A adds opt-in slot and roster management. Production activation remains disabled. The guarded routes are separate from the existing menu, game, and Developer Garden callers. No live saves, installed EXE, native DLL, journal format, gameplay, deletion or archive code changed.

## Verified guarded entry points

| Route | Verified behavior |
|---|---|
| `SaveSlots.prepare_guarded` | Authorized directory bootstrap, then a single locked legacy import. Includes original Garden, character and guest profile, both destination slots and tombstones. Rechecks paths, vacancy, eligibility and leases. Copies exact source bytes into a B1/B2 transaction without changing originals. A pending source or destination blocks import even when its canonical file is absent. |
| `SaveSlots.ensure_character_guarded`, `new_game_guarded`, `new_world_guarded` | Locked vacancy and lease checks, followed by the Group 1 serializer and migration-backup scope. Supports fresh character, pair and Garden-only creation, including vacant Developer Garden slots. The B1 journal tracks sequential replacements and permits verified recovery. The replacements are not crash-atomic. |
| `SaveSlots.claim_guarded`, `heartbeat_guarded`, `release_guarded`; roster equivalents | The short root lock covers each marker operation and is released between calls. Claim checks freshness, and heartbeat and release require the instance's recorded marker digest, process ID and a fresh lease. A stale same-process instance cannot update or release another instance's marker. Foreign active leases are refused before mutation. |
| `SaveSlots.remember_slot_guarded`; `CharacterSlots.set_capacity_guarded`, `remember_guarded` | Validates scope and reads the current metadata under the lock before applying the requested change. Uses checked publication with the existing native replacement. Keeps unrelated catalog fields, import records and deletion records. Refuses a retained metadata scratch. |
| `CharacterSlots.create_guarded`, `update_guarded` | Rechecks catalog capacity, target identity and vacancy, and active leases. Uses one lock and the existing Group 1 serializer and backup scope. Editing preserves the profile identity. |
| `CharacterSlots.prepare_guarded` | Preselects the exact source and destination. Recomputes capacity, identity, import/deletion records, roster vacancy and deduplication under the root lock. The planner observes the bounded roster before the destination can be chosen. Other roster candidates are read-only under that lock. Only the chosen source and destination enter the canonical mutation scope. A changed destination refuses the operation. Pending evidence cannot make a slot look vacant. Missing or invalid permanent identity is explicitly refused. |

[World routes](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd:223>) · [Roster routes](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_slots.gd:155>) · [Shared management authorization](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd:91>)

The boundary returns authorization separately from the operation result. Operations distinguish `busy`, `pending_recovery`, `verified_failure`, `unresolved`, `committed_cleanup_pending` and known `partial_completion`. An unresolved canonical replacement retains the B2 journal and blocks another guarded operation on its participants. Metadata publication verifies the result or the old bytes. Unverified publication preserves available scratch and reports unresolved. The roster import's catalog growth, profile commit and mapping update are separate steps within the same lock. A later failure reports any known partial completion. Identity deduplication prevents a second copy if the profile committed before its mapping was recorded. A retained catalog scratch blocks related guarded edits and imports.

## Deliberately inactive operations

Confirmed occupied `new_game` and `new_world` replacements, including a Developer Garden reset, require the existing timestamped backup. The current authorized layout has no scoped dynamic archive destination. Guarded occupied replacements return `replacement_archive_not_guarded` before any canonical write. Group 2B must preserve and verify the original archive behavior before those routes can replace occupied slots. The Developer Garden scene/menu caller remains on the legacy path.

The inventory records tested routes in `GROUP_2A_GUARDED_ROUTES`. `VERIFIED_WRITERS` remains empty because normal callers have not been migrated. Legacy prepare, lease, summary, catalog and deletion paths remain reachable in production. The native lock coordinates cooperating guarded builds only. A legacy game window or external writer does not honor it. [Inventory and cutover gate](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>)

## Exact verification runs

The existing AC-01 fixture runner checked current structured PASS, exit 0 and zero unexpected Godot errors. Source and packaged tests used disposable roots. Packaged tests ran the Windows export with its matching native DLL.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| `persistence_slot_roster` | `b0g2a-source-persistence_slot_roster-04` | `b0g2a-pack-persistence_slot_roster-04` |
| `persistence_group_one` | `b0g2a-source-persistence_group_one-03` | `b0g2a-pack-persistence_group_one-03` |
| `persistence_restart_recovery` | `b0g2a-source-persistence_restart_recovery-03` | `b0g2a-pack-persistence_restart_recovery-03` |
| `persistence_durable_evidence` | `b0g2a-source-persistence_durable_evidence-03` | `b0g2a-pack-persistence_durable_evidence-03` |
| `persistence_outcomes` | `b0g2a-source-persistence_outcomes-03` | `b0g2a-pack-persistence_outcomes-03` |
| `persistence_operations` | `b0g2a-source-persistence_operations-03` | `b0g2a-pack-persistence_operations-03` |
| `persistence_authorization` | `b0g2a-source-persistence_authorization-03` | `b0g2a-pack-persistence_authorization-03` |
| `persistence_recovery_plan` | `b0g2a-source-persistence_recovery_plan-03` | `b0g2a-pack-persistence_recovery_plan-03` |
| `persistence_save_access` | `b0g2a-source-persistence_save_access-03` | `b0g2a-pack-persistence_save_access-03` |
| `foundations` | `b0g2a-source-foundations-03` | `b0g2a-pack-foundations-03` |
| `character_roster` | `b0g2a-source-character_roster-03` | `b0g2a-pack-character_roster-03` |
| `delete_saves` | `b0g2a-source-delete_saves-03` | `b0g2a-pack-delete_saves-03` |
| `developer_garden` | `b0g2a-source-developer_garden-03` | `b0g2a-pack-developer_garden-03` |
| `start_menu` | `b0g2a-source-start_menu-03` | `b0g2a-pack-start_menu-03` |
| `content_validation` | `b0g2a-source-content_validation-03` | `b0g2a-pack-content_validation-03` |

**30 final source and packaged fixture runs and 53 planner self-tests passed.** The new fixture covered legacy world and guest import, roster deduplication and expansion, fresh and edited slots, preserved catalog records, stale lease operations, foreign leases, changed destination, a missing destination with recovery evidence, retained catalog scratch, occupied replacement refusal, and an injected second-replacement plus restore failure. The latter returned `UNCERTAIN`, retained its journal, refused a conflicting follow-up and allowed a fresh guarded create after verified B2 recovery. The first source probe seeded a third distinct legacy profile before checking the duplicate-only roster. The fixture was corrected to introduce that profile after the deduplication check. [Source case log](<C:/Users/sutte/Documents/Codex/ac06-b0-group2a/logs/source-cases/persistence_slot_roster/unit.log>) · [Packaged case log](<C:/Users/sutte/Documents/Codex/ac06-b0-group2a/logs/pack-cases/persistence_slot_roster/unit.log>) · [Planner self-tests](<C:/Users/sutte/Documents/Codex/ac06-b0-group2a/logs/planner.log>)

| Cross-process scenario | Exact parent run IDs | Result |
|---|---|---|
| Session ownership | `b0g2a-source-lease-01`, `b0g2a-pack-lease-01` | The claim holder retained the session marker while a second process acquired the short root lock to inspect it. The contender received `foreign_session_lease`. Foreign heartbeat and release were refused. The owner's release then succeeded. |
| Interrupted fresh pair | `b0g2a-source-restart-01`, `b0g2a-pack-restart-01` | Writer terminated after the character replacement. Passive Garden inspection reported pending, and guarded create refused with unchanged evidence. Recovery through the character verified original absence of both files. A subsequent guarded pair creation committed. |

The supervisor records each child ID and process exit, native/EXE hashes, and before/after file hex bytes and hashes. Ordinary children exited 0 with no unexpected engine errors. The terminated writers exited 1 as expected. [Cross-process evidence](<C:/Users/sutte/Documents/Codex/ac06-b0-group2a/GROUP_2A_CROSS_PROCESS.json>) · [Supervisor](<C:/Users/sutte/Documents/Codex/ac06-b0-group2a/cross.py>)

| Binary | SHA-256 |
|---|---|
| Disposable Windows export | `AC7507E4041F7D81A3D8055DA58A4CC14F84259C705A144954FAEA88A07DF0B0` |
| Existing matching native sidecar | `AD827586970B7D701AF85007185FA2EF31213666ADD81674D47C3DAB96370379` |

The focused plan resolved without unmatched scopes. It showed 108 affected unit suites because the slot source is a shared foundation. This checkpoint ran selected relevant regressions and did not certify a full release or alter live validation cache evidence. [Planner preview](<C:/Users/sutte/Documents/Codex/ac06-b0-group2a/logs/plan.txt>)

## Changed project files and remaining blockers

- [SaveSlots](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd>), [CharacterSlots](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_slots.gd>), [PersistenceOperations](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd>), and [integration inventory](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd>)
- [Regression fixture](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/persistence_slot_roster.gd>), [test registry](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tools/test_map.json>), [generated mechanics map](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/MECHANICS_TEST_MAP.md>), and this report

Group 2B still owns archive, replacement backup, deletion, and compensation. Group 3 must migrate production callers, settings, passive browsing and lease lifecycle. Stage A and complete verified writer coverage remain prerequisites for cutover. Operator reconciliation is still needed for ambiguous records or metadata scratch that cannot be classified. The tests cover process interruption on local Windows NTFS. Sudden power-loss durability remains unverified.