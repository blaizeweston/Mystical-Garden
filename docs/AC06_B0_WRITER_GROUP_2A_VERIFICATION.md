# AC-06 B0 Group 2A — Guarded slot and roster management verification

The project already contained opt-in Group 2A routes. This pass verified those routes and fixed gaps in lease and tombstone preflight, roster identity validation, and partial-completion reporting. Production still uses the legacy routes. The cutover gate is false and the verified production writer list is empty. The installed EXE and live saves were untouched. See the [original implementation report](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/docs/AC06_B0_WRITER_GROUP_2A.md>) and [activation gate](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_writer_integration.gd:5>).

## Verified entry points and changes

| Entry point | Behavior verified |
|---|---|
| `SaveSlots.prepare_guarded` | Imports exact legacy Garden, local profile and guest profile bytes. Rechecks destinations, leases, eligibility and vacancy under the root lock. Pending recovery, including an absent destination with linked evidence, blocks import. An unresolved lease or tombstone scratch blocks the relevant write and stays intact. |
| `SaveSlots.ensure_character_guarded`, `new_game_guarded`, `new_world_guarded` | Creates a profile, a fresh pair, or a Garden only. Uses the existing participant planner and the Group 1 serializer boundary. A pending tombstone blocks creation. Fresh Developer Garden creation works. Occupied replacement or reset returns `replacement_archive_not_guarded` before canonical mutation. |
| `SaveSlots.claim_guarded`, `heartbeat_guarded`, `release_guarded` and roster equivalents | Use the short root lock for marker updates. Refuse foreign and stale leases. Same-process stale instances cannot update or release the owner's lease. The session marker survives release of the short root lock. |
| `SaveSlots.remember_slot_guarded`, `CharacterSlots.remember_guarded`, `set_capacity_guarded` | Read, validate and publish selection and capacity metadata under the lock. Preserve import and deletion records. Retained catalog scratch blocks related edits. |
| `CharacterSlots.create_guarded`, `update_guarded` | Recheck capacity, vacancy and leases. Edits preserve a valid saved identity. An absent or malformed identity refuses the edit without changing canonical bytes. |
| `CharacterSlots.prepare_guarded` | Deduplicates by identity, preserves the source, and refuses changed or pending destinations. If capacity has already grown when the subsequent profile write aborts, reports `partial_completion`, with the profile still absent and no import mapping. A retry uses the new vacant slot. |

Changed files:

- [persistence_operations.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/persistence_operations.gd:93>) includes exact lease markers and scratch paths in the management authorization and refuses unresolved lease publication under the live lock.
- [save_slots.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/save_slots.gd:226>) guards tombstone scratch on import and creation and shares the management lease preflight.
- [character_slots.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/character_slots.gd:181>) verifies saved identity and catalog destination under authorization and reports a separately committed capacity increase after profile abort.
- [tests/persistence_slot_roster.gd](<C:/Users/sutte/Desktop/The Garden Game development/Mystical Garden/tests/persistence_slot_roster.gd:54>) adds fault cases and checks canonical absence or hashes before and after refusal.
- This verification report. The existing test-map registrations and guarded-route inventory still match the entry points.

## Verification

Godot 4.7.2 source and Windows packaged fixtures used disposable save roots and the existing AC-01 result checks. Each fixture below returned a current structured PASS, process exit 0 and zero unexpected engine errors.

| Fixture | Source run ID | Packaged run ID |
|---|---|---|
| `persistence_slot_roster` | `b0g2a-recheck-source-persistence_slot_roster-02` | `b0g2a-recheck-pack-persistence_slot_roster-02` |
| `persistence_group_one` | `b0g2a-recheck-source-persistence_group_one-02` | `b0g2a-recheck-pack-persistence_group_one-02` |
| `persistence_restart_recovery` | `b0g2a-recheck-source-persistence_restart_recovery-02` | `b0g2a-recheck-pack-persistence_restart_recovery-02` |
| `persistence_durable_evidence` | `b0g2a-recheck-source-persistence_durable_evidence-02` | `b0g2a-recheck-pack-persistence_durable_evidence-02` |
| `persistence_outcomes` | `b0g2a-recheck-source-persistence_outcomes-02` | `b0g2a-recheck-pack-persistence_outcomes-02` |
| `persistence_operations` | `b0g2a-recheck-source-persistence_operations-02` | `b0g2a-recheck-pack-persistence_operations-02` |
| `persistence_authorization` | `b0g2a-recheck-source-persistence_authorization-02` | `b0g2a-recheck-pack-persistence_authorization-02` |
| `persistence_recovery_plan` | `b0g2a-recheck-source-persistence_recovery_plan-02` | `b0g2a-recheck-pack-persistence_recovery_plan-02` |
| `persistence_save_access` | `b0g2a-recheck-source-persistence_save_access-02` | `b0g2a-recheck-pack-persistence_save_access-02` |
| `foundations` | `b0g2a-recheck-source-foundations-02` | `b0g2a-recheck-pack-foundations-02` |
| `character_roster` | `b0g2a-recheck-source-character_roster-02` | `b0g2a-recheck-pack-character_roster-02` |
| `delete_saves` | `b0g2a-recheck-source-delete_saves-02` | `b0g2a-recheck-pack-delete_saves-02` |
| `developer_garden` | `b0g2a-recheck-source-developer_garden-02` | `b0g2a-recheck-pack-developer_garden-02` |
| `start_menu` | `b0g2a-recheck-source-start_menu-02` | `b0g2a-recheck-pack-start_menu-02` |
| `content_validation` | `b0g2a-recheck-source-content_validation-02` | `b0g2a-recheck-pack-content_validation-02` |

The pre-change slot/roster baseline also passed as `b0g2a-recheck-baseline-source-01`. The planner command `python -B -m unittest discover -s tools/tests -p test_test_workflow.py` passed all 53 tests. The focused impact preview classified the affected files, including broad foundation consumers of `save_slots.gd`. The executed fixture list is the selected checkpoint coverage. [Source verdict](<C:/Users/sutte/Documents/Codex/ac06-group2a-recheck/source-02/persistence_slot_roster/verdict.json>) · [Packaged verdict](<C:/Users/sutte/Documents/Codex/ac06-group2a-recheck/pack-02/persistence_slot_roster/verdict.json>) · [Source case log](<C:/Users/sutte/Documents/Codex/ac06-group2a-recheck/source-02/persistence_slot_roster/unit.log>) · [Packaged case log](<C:/Users/sutte/Documents/Codex/ac06-group2a-recheck/pack-02/persistence_slot_roster/unit.log>) · [Planner self-tests](<C:/Users/sutte/Documents/Codex/ac06-group2a-recheck/planner.log>) · [Impact preview](<C:/Users/sutte/Documents/Codex/ac06-group2a-recheck/plan.json>)

| Cross-process parent run IDs | Result |
|---|---|
| `b0g2a-recheck-source-lease-02`, `b0g2a-recheck-pack-lease-02` | The competing process reached the planner and received `foreign_session_lease`. Its heartbeat and release attempts were refused and the marker bytes stayed intact until the owner's release. |
| `b0g2a-recheck-source-restart-02`, `b0g2a-recheck-pack-restart-02` | The writer was terminated after the first of two replacements. Inspection reported pending recovery. Guarded creation refused without modifying evidence. Recovery through the character path verified both original files were absent. A subsequent guarded pair creation committed. |

The cross-process supervisor recorded child run IDs, exit codes, engine output, file bytes and hashes. Normal child exits were 0, forced termination exits were 1, and all children had zero unexpected engine errors. The slot fixture separately injected a second-replacement and restoration failure. It observed a typed `UNCERTAIN` outcome, retained the journal, blocked another write, recovered and retried. [Cross-process evidence](<C:/Users/sutte/Documents/Codex/ac06-group2a-recheck/GROUP_2A_CROSS_PROCESS.json>)

- Disposable Windows export SHA-256 `529574687D06615E3519A2D68CCBADDCC8D28D51DACD79223B1DBA2D5FCC5861`
- Native DLL SHA-256 `AD827586970B7D701AF85007185FA2EF31213666ADD81674D47C3DAB96370379`

## Activation blockers and limits

Group 2B must authorize archive destinations and implement occupied Garden/character replacement, occupied Developer Garden reset, deletion and compensation. The existing backup requirement applies to all occupied replacements. The sequential Garden and character replacements have journal-backed restart recovery. A process interruption can leave the first file replaced and the second absent until recovery completes.

Group 3 must migrate the existing menu, browsing, settings and lease callers. Those paths can still use the legacy writers. Stage A and verification of every inventoried production writer remain prerequisites for activation. The root lock coordinates callers using the guarded boundary. Catalog capacity, profile commit and import mapping are separate steps, so a crash can leave a harmless expanded capacity or an imported profile whose mapping was skipped. The deduplication scan uses saved identity to avoid creating a second copy. Unresolved metadata scratch requires reconciliation. The verification covered process termination on local NTFS. Sudden power-loss durability remains unverified.

