# Stale code and file cleanup

Completed 2026-11-10. The active project no longer contains the superseded inventory renderer, twelve unused functions, six replaced model exports, obsolete authoring sources/generators, historical source copies, or accumulated generated test/build artifacts. Current gameplay, saved content identities and multiplayer contracts remain intact.

## Backup and exact removal record

Retention checkpoint recorded **2026-11-10T11:22:21-05:00 (EST, America/New_York)**. Capture began **2026-11-10 10:50:18 EST**; the verified backup completed **2026-11-10T11:00:31.543711 EST**. It preserves the **pre-cleanup v0.5.2.0 project and EXE**, before Garden G-01 implementation. G-00 planning was complete; the next Garden objective remained G-01, followed by the sheltered spring in G-02. The post-cleanup package was verified at **2026-11-10T16:16:50.301652+00:00 UTC**.

**Retain this backup untouched.** Routine builds, exports, validation, audits and cleanup must not scan, hash, import, execute, modify, prune, move or delete it. Replace/retire it only after a separate verified stable backup of a **newer version** exists with its version, date/time, source/EXE identity and passing release evidence recorded, and the active checkpoint reference is updated. A newer timestamp or renamed EXE does not qualify. The backup's `RETAINED_CHECKPOINT.txt` records the stage and retention policy; the active `AGENTS.md` enforces this rule for future development. A separately requested recovery is outside routine builds.


Full pre-cleanup backup: `C:\Users\sutte\Desktop\The Garden Game development\Backups\Mystical-Garden-before-cleanup-20261110-105018`.

The backup contains all 29,256 original project files (11,544,939,072 bytes), including generated data, plus the latest desktop EXE. Every original/copy pair passed SHA256 verification before removal. `manifest.json` contains original file hashes and sizes. `cleanup-removals.json` lists every removed path, original hash, size and reason, plus the changed code files. `RESTORE.txt` explains the backup layout. The backup lives outside the active project and is excluded from exports.

Removed 25,798 files totaling 11,440,899,590 bytes (11.44 GB). This measures removed project artifacts; fresh validation/build output is generated again, and the external backup still occupies disk space.

| Category | Removed files | Bytes |
|---|---:|---:|
| Generated Godot artifacts | 25,616 | 11,430,023,611 |
| Superseded assets and authoring tools | 21 | 1,102,251 |
| Historical source snapshots | 153 | 9,512,901 |
| Python bytecode caches | 8 | 260,827 |

## Removed runtime code

The cleanup removed 196 net runtime lines, including the old HUD inventory state construction. The active `inventory_panel.gd` and `inventory_model.gd` now own the inventory display without a second renderer/redraw bridge in `root_ui.gd`. `tests/player_hud.gd` verifies the live panel and its carried, personal and shared component data.

| File | Removed unused functions |
|---|---|
| `root_ui.gd` | `style_button`, `make_inventory`, `inventory_cell`, `draw_inventory` |
| `attack_geometry.gd` | `accepts_body` |
| `campaign.gd` | `tend_offshoot` |
| `heart_progress.gd` | `material_text` |
| `progress.gd` | `plot_cost`, `plot_knowledge` |
| `save_slots.gd` | `start_garden` |
| `stage.gd` | `build_ground` |
| `weapon_parts.gd` | `technique_name` |

The unused `InventoryCanvas` class, its fields/catalog imports, `PANEL_BG`, and the HUD-only copies of inventory/equipment dictionaries were also removed. Public/private multiplayer inventory snapshots remain owned by their existing authorities.

The first full run passed 81 suites and failed the class co-op single-strike assertion; that test passed unchanged on retry. Its random live elite target was replaced with a deterministic stationary ordinary enemy and an explicit clear-line precondition. The existing host damage, guest damage, graft and class-state assertions remain. Separate enemy/elite behavior suites still exercise the AI. The corrected fixture and the entire full suite were rerun before release.

## Replaced files and their current authorities

| Removed family | Current authority retained |
|---|---|
| Root-level adventurer and briar GLBs and combat_models source/generator | Rigged traveller models, `make_travellers.py`, current enemy catalog/template |
| Root-level Nightbloom GLB, its old source/generator | `assets/enemies/nightbloom.glb`, catalog and `make_enemies.py` |
| wild_boulder, wild_pine and wild_snag GLBs; old wilderness/rootwood sources and wrappers | `make_natural_world.py`, natural_world.blend and current root_stone/root_tree/root_snag/path/ruin exports |
| altar.blend1 | Editable altar.blend |
| docs/change-backups source copies | Exact originals in the external verified backup |
| Old staged EXEs, debug scripts/images/logs and isolated test save directories under .godot | Recreated test/build output; current validation evidence and editor/import/shader caches retained |

Removed model import settings and their orphaned imported scene caches were included. Obsolete asset ownership rules were removed from `tools/test_map.json`, the readable map was regenerated, and `CONTENT_AUTHORING.md` now identifies the canonical generators.

Historical notes retain their original paths for traceability. References to old `docs/change-backups` or `.godot` outputs now refer to those paths inside the backup's `project` directory.

## Compatibility and content retained deliberately

- Frozen content manifests, retired component entries and migration functions preserve published seed, part, character and save identities. Sparse direct calls are not proof that a migration is unused.
- The deferred Heart ending/offshoot save fields, inert guards and snapshot layout remain compatible. The unused offshoot mutation entrypoint was removed; this cleanup does not enable or redesign the ending. Removing serialized fields or protocol slots requires an explicit versioned migration.
- Current Blender sources, supplied references, all current enemy/boss models, procedural shaders, UI icons, documentation, Garden roadmap and supplied Gameplay logs remain. Catalog-generated paths, icon naming conventions and shared templates were checked separately from literal path searches.
- Current source/package validation evidence remains in `.godot/validation` and `.godot/stabilization`. No real AppData saves were used or modified. Earlier milestone EXEs outside the active project remain untouched.

## Verification

Godot import completed without errors. The updated HUD/inventory regression passed before release validation. A separate SHA256 audit verified 756 retained authored files against the original backup, outside the planned edits, generated output and removed archives.

Full source run: `20261110-111029-f650c827`. All 82 registered suites executed, 0 reused; the run passed with stable inputs and release readiness. This includes content validation, migration/persistence, cultivation/research, crafting/inventory, combat/pathing, classes/upgrades, diagnostics and co-op. Planner self-tests also passed.

Full packaged plan: 49 selected suites, plus startup/catalog/exclusion and network smoke checks. Packaged validation passed before installation. The installed `Mystical Garden v0.5.2.0.exe` SHA256 matches the verified staged package: `23bff5d528359d8a1e6ef5da092590062162fd4b0cb15b26fb5b33335e9d3c1a`.

Evidence: `.godot/cleanup-import.log`, `.godot/cleanup-hud.log`, `.godot/cleanup-full.log`, `.godot/validation/latest-report.json`, `.godot/validation/runs/20261110-111029-f650c827/`, `.godot/cleanup-package.log`, `.godot/validation/last-package.json` and `.godot/release/`.

Automated local co-op checks verify synchronization contracts and connections; gameplay feel and internet latency still benefit from normal playtesting.

## Restore or inspect archived content

Close Godot. For a safe inspection or rollback, copy the backup's `project` directory into a separate working folder and open its `project.godot`. The previous desktop EXE is beside that directory. To restore in place, preserve any work made after this backup first, then restore the backed-up files. Real player saves are outside this backup and were not changed by cleanup. Use `cleanup-removals.json` to restore one specific removed file instead of rolling back the whole project.

## Continued development

The next Garden objective remains G-01 in `GARDEN_MILESTONES.md`. Keep canonical generators and migration owners explicit. Generated fixtures/builds belong under `.godot`; historical source snapshots belong in external backups. Routine changes return to the affected checks selected by the mechanics map. This full run was explicitly requested for the cleanup.
