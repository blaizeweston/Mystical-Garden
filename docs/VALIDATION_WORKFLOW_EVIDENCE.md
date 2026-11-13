# Selective validation verification — 2026-11-09

The new workflow was verified against the existing game without installing a new player executable. No gameplay behavior was changed.

## Measured source runs

| Case | Game suites executed | Results reused | Time |
|---|---:|---:|---:|
| Trusted full baseline | 68 | 0 | 205.25s |
| Identical source/test inputs | 0 | 68 | 6.12s |
| Temporary comment added to menu_controls test | 1 | 67 | 6.77s |
| Original test restored and revalidated | 1 | 67 | 6.73s |

The full baseline timing is the game-suite run; the three selective timings include the wrapper and planner self-tests. The edited-test experiment confirms test-code invalidation, not a claim that a gameplay change needs only one suite. The original test bytes were restored exactly. All runs ended with complete current release coverage.

The planner has 26 passing self-tests for scoped function bodies, global signatures/RPCs, real-engine fingerprinting, direct resource dependencies, unknown files/tests, changed or missing evidence, weekly expiry, focused/co-op boundaries, interrupted inputs, nonzero process exits, missing success markers, shell selection, and packaged template changes.

## Packaged verification

- First staged build: all 35 portable suites plus packaged startup/catalog/exclusion smoke passed.
- Second staged build with unchanged inputs: 34 portable results reused; the real host/three-guest connection suite and packaged startup/catalog/exclusion smoke passed again.
- Both builds used VerifyOnly. The desktop EXE was not replaced.
- Desktop EXE checked: `C:\Users\sutte\Desktop\Mystical Garden v0.5.1.3.exe`.
- Unchanged SHA-256: `EC16E5D88596701F0BF8F0DC3E432313FDFB73126D4FB74128DB60B60D8DCD07`.

## Declared coverage previews

These show the system map only. Actual runs can expand coverage through literal resource dependencies, missing evidence, or full-validation safeguards.

| Example change | Plan | Suites in declared coverage |
|---|---|---:|
| `settings_panel.gd` | connected | 11 |
| `seed_catalog.gd` | connected | 22 |
| `heart_catalog.gd` | connected | 15 |
| `game.gd::harvest` | connected | 32 |
| `save_batch.gd` | full | 68 |

Per-run plans, logs, fingerprints and timings are stored under `.godot/validation`. The operational instructions are in [VALIDATION_WORKFLOW.md](VALIDATION_WORKFLOW.md); the mechanics and coverage map is [MECHANICS_TEST_MAP.md](MECHANICS_TEST_MAP.md).
