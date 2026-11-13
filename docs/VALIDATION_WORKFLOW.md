# Development validation workflow

User testing policy, reaffirmed 2026-11-10: full game-suite runs are reserved for major releases or an explicit user request. Routine changes use focused and connected checks selected from [MECHANICS_TEST_MAP.md](MECHANICS_TEST_MAP.md), maintained in `tools/test_map.json`.

Inspect the plan before running it. Update ownership and interaction coverage alongside implementation, then run the affected unit suites and relevant integration/network scenarios. Reuse trustworthy results for unaffected inputs. A tree update, new test, elapsed week, or broad file dependency is not by itself a reason to rerun the full game suite.

The planner now keeps Full explicit. Map-only edits and planner self-tests do not discard verified evidence for unchanged runtime inputs. A verified cache lineage preserves the original keys when executor semantics are unchanged; actual executor/engine changes invalidate the appropriate evidence. Existing result rows and log hashes are never rewritten to manufacture a pass.

Narrow, explicitly mapped wiring regions allow a gate-distance call or a HUD hook in a large dispatcher to own its specific coverage. The untouched remainder retains its previous identity, while the extracted fragment, its location and its service are fingerprinted for their declared consumers. Changes elsewhere in that dispatcher remain conservatively covered. Resource traversal respects these region boundaries. Unknown inputs block execution until classified; they do not silently trigger Full.

Documentation-only updates need no game tests or EXE replacement.

## Ordinary changes

From the project folder in PowerShell:

```powershell
# Explain the current plan without running game tests.
./tools/validate_release.ps1 -PlanOnly

# Fast feedback while the feature is under development.
./tools/validate_release.ps1 -Mode Focused

# Finish relevant integration/co-op checks and verify reusable evidence.
./tools/validate_release.ps1 -Mode Connected

# Export using the affected packaged checks and essential smoke tests.
./tools/release_latest.ps1 -TargetPath 'C:/Users/sutte/Desktop/Mystical Garden v0.5.1.3.exe'
```

The EXE path is an example: always discover the highest numbered revision before exporting. Earlier milestones must remain untouched. Settings/audio or documentation changes do not automatically justify rebuilding the game.

Connected is the default. Focused runs eligible unit suites; it cannot certify missing co-op coverage. The export gate checks current evidence for **every registered suite**, including successful results reused from unchanged inputs. It no longer requires rerunning a fixed number of suites. A partial pass cannot authorize a release.

Do not edit runtime files, tests, the map or validation tools while a run is in progress. Complete focused fixes first, then start connected/release verification. New results are discarded if inputs change mid-run. Tests use isolated data under `.godot`, not the player's saves.

## Major milestones and conservative fallback

```powershell
./tools/validate_release.ps1 -Mode Full
./tools/release_latest.ps1 -Full -TargetPath 'C:/Users/sutte/Desktop/Mystical Garden v0.5.1.3.exe'
```

Use Full only for a major release or explicit user request. Shared changes can require broader related checks, but a new tree node, stale baseline date, or unchanged test executor does not automatically schedule every suite. Inspect `-PlanOnly`, maintain ownership, and resolve stale evidence for the affected consumers.

`-NoCache` reruns checks eligible for the selected mode; it does not promote the mode to Full. `-VerifyOnly` tests a staged package without replacing the player's EXE. Packaged validation reuses matching suite evidence and always checks startup/catalogs and a real peer connection.

## What selects tests

Each suite declares the mechanics and interactions it covers. The planner combines those declarations with literal `res://` resource dependencies found in the test and its referenced files. Inputs include runtime code, assets and import settings, test code, Godot and validation tooling. A change invalidates only results whose relevant input fingerprint changed; absent or modified evidence logs invalidate reuse too.

Two small broad source checks—content validation and the playable solo smoke—cover all runtime inputs. Other suites cover their declared systems. The four-player and network scenarios are selected when their inputs are affected; they are not automatically rerun for every unrelated edit.

The graph is an explanation of relationships, not an instruction to recursively select every connected mechanic. That would eventually select the entire game. Instead, each integration suite declares the complete interaction it verifies, such as seeds + weapon parts + class effects + checkpoint cards.

`game.gd` remains a large dispatcher. Existing function bodies have explicit ownership in the map. Changing a seed-harvest body invalidates its declared seed/Garden/item consumers without invalidating unrelated character deletion. Global declarations and signatures stay conservative. Unknown functions must be classified before validation. The regular broad smoke checks still instantiate the game to catch compilation and startup failures. Gradually extracting services will improve this boundary; no large gameplay rewrite was needed for this workflow.

For suites whose literal resource dependencies reach `game.gd`, the planner also scans the fixture and reachable GDScript helpers under `test/` and `tests/`. It recognizes the fixture's `game` receiver and receivers assigned directly from the world scene or dispatcher script. Named method references and literal reflective calls add the matching body and scoped region fingerprints to that suite. The planner lists the matching dispatcher token and fixture path for changes found against the baseline or requested in a dispatcher preview. Already-included tokens keep their existing identity.

If a recognized receiver uses a computed method name, that fixture depends on all dispatcher bodies and regions. Receiver aliases passed through arbitrary helpers, scene signals, runtime dispatch and transitive method calls still rely on declared ownership. Include those consumers in the function or region's system ownership. If the affected systems cannot be bounded confidently, use foundation ownership for that function or region so connected validation rechecks all suites. A new dependency can make older evidence stale even if the gameplay files are identical.

Dependency declarations require judgment, especially for dynamic loading or shared state. If impact is uncertain, run Full and update the map before relying on selective results. Automated test selection reduces repeated work; it does not replace playtesting combat feel, visuals or real internet conditions.

## Preview an idea

```powershell
./tools/validate_release.ps1 -PlanOnly -ChangedFiles settings_panel.gd
./tools/validate_release.ps1 -PlanOnly -ChangedFiles seed_catalog.gd
./tools/validate_release.ps1 -PlanOnly -ChangedFiles 'game.gd::harvest'
./tools/validate_release.ps1 -PlanOnly -ChangedFiles save_batch.gd
```

Previews use the same input set as each suite fingerprint. This includes implicit foundation inputs, literal resource dependencies, and dispatcher calls found in fixtures. `predicted_invalidations` lists every matching suite. Focused mode displays only the unit suites it would schedule.

A path-only preview assumes the specified fingerprint changes. Use `game.gd::$contract` for signature, RPC declaration, or shared declaration edits. Use `game.gd::function` for a known body token and include any region tokens affected by the edit. An unqualified `game.gd` conservatively includes the shared contract. A bare scoped text file name previews its normalized base. Include `path::#region` for every affected region. Normalized-away edits, such as local export path changes, can leave fingerprints unchanged. New dependency edges, changes to ownership or validation infrastructure, and compound edits may require inspecting the edited files to determine the exact impact.

An unrecognized proposed input reports `blocked` and shows all suites as a conservative estimate. The actual runner stops before launching tests when it discovers unmapped runtime inputs or unregistered fixtures. Classify the input or inspect the edited project to resolve the estimate. Actual validation hashes current files and checks cached evidence integrity independently of the preview.

Asset ownership uses the first matching `asset_rules` pattern after exact file ownership. Put narrow patterns before broader matches. The part-icon rule `assets/ui/parts/**` assigns `items` and `presentation` coverage before the generic UI rule assigns `presentation` and `progression`.

Scope checks use the same normalization order as fingerprinting. A zero-match scope blocks validation and reports its token. If the anchor exists in the original file, the diagnostic identifies that an earlier scope consumed it. Correct the anchor or retire it with evidence that its implementation has moved or been removed. Record planned features in design documentation until they have code to anchor.

## Adding content or tests

Import new scripts/resources with Godot before source validation so generated `.uid` files are included in the baseline. Classify new runtime scripts and their generated resource IDs in the dependency map; an ID first generated during export invalidates its consumers’ prior evidence.

1. Content added through an existing template keeps its existing system ownership. Update the relevant content-validation/template tests when needed.
2. For a new runtime file, add its system ownership or a specific asset rule to `tools/test_map.json`. Unmapped runtime files block validation until classified.
3. Register a new suite's runner (`unit`, `pair`, `solo`, `party`, `smoke`), covered systems and packaged-test capability. The discovery audit catches unregistered tests. Optional benchmarks need an explicit explanation in `ignored_tests`.
4. Packaged unit tests must work with compiled scripts and replace `res://.godot/` fixtures with `user://release-fixtures/`. Source-only tests can inspect source; mark them accordingly. Every package always receives startup/catalog/exclusion smoke and a real host/three-guest connection smoke. Portable affected suites add feature-specific checks.
5. Regenerate the human-readable map:

```powershell
python ./tools/test_workflow.py document
```

The wrapper finds the bundled Python runtime automatically; the planner requires only Python's standard library. To run its self-tests directly:

```powershell
python -m unittest discover -s ./tools/tests
```

## Evidence and reports

- `.godot/validation/plan-preview.json`: selected suites and reasons.
- `.godot/validation/latest-report.json`: executed/reused counts, timings and release readiness.
- `.godot/validation/runs/`: immutable per-run plans, results and game logs.
- `.godot/validation/cache.json`: current per-suite fingerprints and hashed evidence logs.
- `.godot/validation/full-baseline.json`: trusted full-run boundary and weekly age.
- `.godot/validation/package-plan.json`: selected packaged tests and reusable results.
- `.godot/validation/last-package.json`: verified staged EXE hash and packaged plan.

These are machine-local generated files. Deleting the cache is safe; it requires validation again. Old release reports without dependency fingerprints are not imported as trusted cached passes. The lock prevents simultaneous source-validation runs from fighting over test ports or evidence.

The old validation/release scripts were preserved under `docs/change-backups/20261109-selective-validation` for comparison and recovery.

Network process checks use PowerShell 7 (the bundled runtime is supported). The older Windows PowerShell process wrapper can lose peer exit codes; the planner deliberately refuses to treat missing exit codes as passes. A changed release export template also forces fresh packaged checks.


Keep validation caches local to this development computer; do not copy them into another developer's project. Godot's console launcher and its paired engine binary are fingerprinted together.

## Additive Garden adapter boundaries

G-01 extends exact dispatcher regions with `additive: true` for multi-line wiring. The declared fragment must occur exactly once in its named function; its baseline restores the previous body before existing region coordinates are measured. This keeps unrelated hashes stable while new hooks and their service remain covered by `garden_observations`/`garden_costs`. Missing fragments block planning. Unscoped edits and signature/RPC/global declaration changes remain conservative. Preserve existing LF/CRLF conventions when editing; do not let a helper rewrite the entire dispatcher. The planner self-tests cover Windows newlines, unrelated-body invalidation and malformed graph edges. See GARDEN_INTERACTIONS.md for the milestone evidence and the stopped formatting-only attempt.

## Cosmetic GLB boundaries

`binary_regions` extends the existing scoped-source mechanism to the two traveller GLBs. Verified pre-overhaul asset hashes preserve incidental dependency identity for unrelated mechanics; actual bytes still enter the visual token, raw stability check, broad source checks and package/source identity. Same-bone/morph/action/no-collision contracts are covered by character/weapon suites. This is not a general exemption for model changes: bone/action contracts or gameplay collision changes require broader ownership. Whole-file character presentation adapters and a separate crafted-ready transition keep their real consumers explicit. Planner tests verify unrelated reuse, actual visual invalidation, invalid metadata rejection and stale-package refusal. No passing evidence is invented, copied or rewritten.
