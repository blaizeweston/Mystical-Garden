# Gameplay log analysis

This offline tool reads diagnostic folders, individual JSONL files, or exported ZIP reports. It never extracts ZIP contents to disk or edits the original logs. Python's standard library is sufficient; no game launch, multiplayer connection or EXE rebuild is required.

From the project folder:

```powershell
./tools/log_analysis/analyze_logs.ps1 -UtcOffset '-05:00'
```

The wrapper finds the bundled Python runtime automatically. The default input is `Gameplay logs`; outputs go to `docs/gameplay-analysis`. The current November playtest uses Eastern Standard Time, UTC−05:00. The offset is explicitly fixed, not an automatic daylight-saving conversion. Without an offset argument, output uses UTC; original UTC timestamps are always retained.

Alternate inputs:

```powershell
./tools/log_analysis/analyze_logs.ps1 -InputPath 'C:/Reports/host.zip','C:/Reports/guest.zip' -OutputPath 'C:/Reports/analysis' -UtcOffset '-05:00'
```

Or call Python directly:

```powershell
python tools/log_analysis/analyze_session_logs.py --input 'Gameplay logs' --output docs/gameplay-analysis --utc-offset=-05:00
```

## Outputs

- `report.md` / `report.html`: readable findings, coverage limits and supporting references.
- `coverage.svg`: timeline showing retained log segments and missing coverage.
- `summary.json`: full machine-readable analysis, input hashes, warnings and comparison evidence.
- `events.csv`: de-duplicated events in each application's local sequence order.
- `network.csv`: periodic RTT/loss estimates, counters and FPS; not packet-by-packet measurements.
- `damage.csv`: incoming player damage, actual HP lost when available, resulting HP and damage sequence.
- `healing.csv`: rolled and restored HP, healing source, party slot and resulting pool from detailed tracing.
- `encounters.csv`: observed clears and supported generation-to-clear timing.
- `life_events.csv`: downs, in-Wilds revivals and Garden restorations kept separate.
- `research.csv`: sampled research/Garden state, not a list of all completed projects.
- `upgrades.csv`: recorded purchases, with actor attribution only when a retained enclosing action provides it.

Session identity and event sequence de-duplicate nested folders, repeated exports and ZIP copies. Different snapshots of session metadata are resolved by their highest recorded sequence. Conflicting copies are flagged rather than silently counted twice. Unknown/malformed records and missing chunks are reported. Event references point back to the exact source file and line.

Health comparisons match host, world, actor and vitals revision. HP and damage sequence are compared across builds. Maximum HP, sealed HP and fallen state are compared when both logs contain them. Missing host samples leave a revision unverified. A missing clean-exit marker at export does not prove a crash.

`catalog.json` is an optional versioned label snapshot. The tool uses its class names only if its runtime source fingerprint matches every supplied session. The included snapshot was checked against the current project's runtime fingerprint; logs from other builds fall back to numeric class IDs. Do not relabel old builds using an unrelated current catalog.

Keep output outside the input folder. Archive limits protect against excessively large inputs; CSV free text is protected against formula interpretation, and HTML escapes log text. No network access or uploads occur. The `.gdignore` in `Gameplay logs` keeps local diagnostic data out of Godot's resource import/export scanning.

## Tests

```powershell
python -m unittest discover -s tools/log_analysis -p 'test_*.py'
```

These are independent analyzer tests, not gameplay release suites. They cover duplicate/conflicting records, metadata versions, rotation gaps, missing data/viewpoints, exact and ambiguous health revisions, revival classification, ZIP handling, malformed input, safe rendering, CSV output and preservation of originals.
