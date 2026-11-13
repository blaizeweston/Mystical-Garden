# Dependency Map and Regression Testing Summary

The Mystical Garden dependency map combines a **manually maintained registry**, a **generated diagram**, and an **automated test planner**. The inspected registry contains 67 systems, 182 relationships, and 143 test suites.

## How it works

- Developers maintain system relationships, file and function ownership, and test coverage in [tools/test_map.json](../tools/test_map.json). [AGENTS.md](../AGENTS.md) directs developers to classify changes and regenerate the [Mechanics and Test Map](MECHANICS_TEST_MAP.md).
- The diagram shows authored gameplay and data relationships. The planner selects tests using declared ownership, literal `res://` dependencies, and fingerprints of the relevant inputs. It uses declared function and fragment ownership for the shared `game.gd` dispatcher. [Planner](../tools/test_workflow.py)
- Validation starts when someone runs the [source runner](../tools/validate_release.ps1). Focused mode covers eligible unit suites. Connected mode includes relevant integration and co-op suites. Full mode explicitly runs every suite. Valid cached results can be reused. The inspected project had no watcher, hook, or CI configuration that triggered tests after an edit. [Validation workflow](VALIDATION_WORKFLOW.md)
- The [release runner](../tools/release_latest.ps1) requires current source evidence before running selected packaged tests and startup and network smoke checks. The inspected source report records one suite executed and 142 reused. The package report records 110 checks. All registered fixtures existed, and the saved log and package hashes checked out. [Source report](../.godot/validation/latest-report.json) · [Package report](../.godot/validation/last-package.json)

## Limits and priorities

The planner detects missing registered files, unmapped inputs, some broken scope anchors, and stale test evidence. It does not automatically verify that gameplay relationships are still accurate or that the Markdown matches the registry. The shrine, checkpoint, and rolled-strike cases show how a body edit can leave a relevant test eligible for reuse. The Garden growth co-op fixture also recorded node and packet errors alongside a passing verdict. [Planner](../tools/test_workflow.py) · [Guest log](../.godot/validation/runs/20261112-124734-c9cfe486/garden_growth_coop-guest.log)

1. Require per-peer exit codes and results, and fail on unexpected engine errors.
2. Fix the confirmed coverage gaps and make plan previews agree with actual invalidation.
3. Add a generated-map comparison and report unmatched scope rules.

See the [Architecture Correction Checklist](ARCHITECTURE_CORRECTION_CHECKLIST.md) for acceptance checks.
