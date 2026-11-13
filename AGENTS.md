# Mystical Garden development

## Validation workflow

Read `docs/VALIDATION_WORKFLOW.md` and consult `docs/MECHANICS_TEST_MAP.md` when changing mechanics or planning checks.

- Use `tools/validate_release.ps1 -Mode Focused` during implementation, then `-Mode Connected` before ordinary exports. Inspect `-PlanOnly` when scope is unclear.
- User testing policy (2026-11-10): run the full game suite only for major releases or an explicit user request. Routine fixes and content additions use the interaction tree and affected unit/integration/network suites, even when the tree itself needs updating.
- Review the plan before executing checks. The planner keeps Full explicit and reuses verified unaffected inputs. If a routine plan unexpectedly expands, correct ownership/selection/cache boundaries first; do not run the full suite merely to satisfy broad defaults. Never invent or copy passing evidence. Preserve checks for every affected interaction and report unresolved coverage honestly.
- Preserve reusable results for unchanged inputs. Do not run the entire suite merely because an EXE is being updated. Fix focused failures before starting expensive release validation, and do not change validation inputs during a run.
- Keep new files/functions/tests classified in `tools/test_map.json`, with integration suites covering their consumers. Regenerate `docs/MECHANICS_TEST_MAP.md` after map changes.
- Use the release tool's dependency-based packaged plan. It verifies every suite's current source evidence and always checks packaged startup/catalogs and real network connection. Full packaged checks remain available with `-Full`.
- Tests must use isolated fixtures. Never load, delete or overwrite the player's real save files for validation.
- Discover and update only the highest numbered EXE milestone. Earlier revisions are preserved. Tooling/documentation-only changes normally need no player EXE replacement; use `-VerifyOnly` to verify the export workflow without installing a build.

The project still contains shared dispatcher logic in `game.gd`. Body ownership is explicitly mapped; signatures, RPC annotations and global declarations remain broad contracts. When a task permits, extract a small cohesive service rather than expanding the dispatcher, and update its coverage map.

## Garden development objectives

For Garden interactions, read `docs/GARDEN_MILESTONES.md` first for the current handoff and next objective, then `docs/GARDEN_DEVELOPMENT_MAP.md` for boundaries and overlap decisions. Keep milestone IDs/statuses/evidence and the next-objective handoff current. Planned modules/tests are not implemented features; add them to the runtime/test map only when they exist. Do not resume the deferred Heart ending or replace existing research, inventory, Altar or cultivation authorities as part of routine Garden additions.

## Diagnostic events

Use the shared diagnostic_journal.gd event API for new mechanics. Read docs/DIAGNOSTICS.md for field meanings and report collection. Record useful stable content/actor IDs, inputs, outcomes and save failures; keep gameplay actions independent of logging success. Do not add a separate ad-hoc log file or log motion/packets every frame. Diagnostic observation must not consume RNG, alter simulation state or join gameplay save transactions. Guest logs must distinguish received host state from local character/Garden data. Use optional detailed tracing for high-frequency investigation. Update relevant diagnostics tests when changing its hooks, and preserve the crash/error and multiplayer correlation checks.

## Retained cleanup backup

Retention recorded 2026-11-10T11:22:21-05:00. Protected checkpoint: `C:\Users\sutte\Desktop\The Garden Game development\Backups\Mystical-Garden-before-cleanup-20261110-105018`. Read its retention summary in `docs/STALE_CODE_CLEANUP.md`; do not open or scan the backup during routine development. It captures the pre-cleanup v0.5.2.0 project, before Garden G-01 implementation. Exclude this backup from builds, exports, validation, hashing, source audits, cleanup and pruning. Do not modify, execute, overwrite, move or delete it. Only replace/retire it after a separate verified stable backup of a newer version exists, its version/date/time/source and EXE identity and passing release evidence are recorded, and the active checkpoint reference is updated. A newer timestamp or renamed EXE is insufficient. Do not mutate the original backup payload or manifests. A separately requested recovery is outside routine builds.
