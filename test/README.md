# Network connect-and-play smoke test

This adapts the supplied `test/` bundle to the current four-player game. It runs the real world scene, ENet admission, player profiles, motion requests, movement snapshots and reliable owner-detail channel. It complements the existing `tests/` regression suite.

## Quick run on Windows

From the project folder:

```powershell
.\test\run_net_test.ps1
```

Godot is detected beside the project, through `GODOT`, or on PATH. An explicit engine path is also accepted:

```powershell
.\test\run_net_test.ps1 -Godot '..\Godot_v4.7.2-stable_win64_console.exe' -Clients 3
```

The default starts one host at 60 FPS and three guests with a 240 FPS limit on UDP 24600. No windows need to be controlled. FPS values are limits, not guaranteed measured frame rates.

```powershell
# Smaller party and longer movement phase
.\test\run_net_test.ps1 -Clients 1 -Port 24601 -PlayMs 10000
# One-minute movement soak, with different frame-rate limits
.\test\run_net_test.ps1 -Clients 3 -PlayMs 60000 -HostFps 30 -GuestFps 144
# Load the exported game's actual code/assets instead of source resources
.\test\run_net_test.ps1 -Pack '.\Mystical Garden v0.5.1.exe'
```

Pack mode still needs the Godot engine. The shipping game binary intentionally disables command-line path overrides and cannot itself be used as `-Godot`. Pack runs use a separate resource directory so files in the source project cannot accidentally satisfy a missing packaged resource.

## What must pass

1. The host actually binds before automatic guests launch.
2. All expected guests finish the game's real protocol/content/identity checks.
3. A test-only RPC barrier starts movement after all peers see the full party.
4. The host observes its own movement and each guest's movement. Every guest observes movement from the host, itself and the other guests.
5. Each peer sees its own walking joints animate. Guests must receive multiple frequent snapshots, reliable details and unique party slots; other players' private bags must remain absent.
6. Guests send their measurements and remain connected for the host verdict. Verdicts are acknowledged before coordinated, sequential shutdown.
7. The launcher requires exit zero, a valid matching JSON result, a PASS marker, and no script/engine errors. Missing reports and killed processes fail.

Movement uses actual input actions, not position injection. The test-only RPCs coordinate the scenario; they do not replace gameplay RPCs. This smoke stays in the Garden. Actual combat damage, research, ready gates, loot, saves and unexpected disconnect/reconnect behavior are covered by the existing regression suites, especially `network_research_coop.gd` and `four_players_coop.gd`. Cleanup stops fixture traffic after verification; it is not a disconnect gameplay assertion.

## Testing between two computers

Use matching game builds and the same RunId, Clients count and port. The host must be reachable as with ordinary direct-IP play. This harness makes no firewall or router changes.

Host computer:

```powershell
.\test\run_net_test.ps1 -Role Host -Clients 1 -RunId garden-check -TimeoutMs 120000 -Pack '.\Mystical Garden v0.5.1.exe'
```

Friend's computer, replacing the example address with the reachable host IP:

```powershell
.\test\run_net_test.ps1 -Role Guest -Clients 1 -Index 0 -RunId garden-check -Address 192.168.1.50 -TimeoutMs 120000 -Pack '.\Mystical Garden v0.5.1.exe'
```

For three remote guests set Clients to 3 everywhere and use distinct guest indices 0, 1 and 2. RunIds need 1–80 letters, digits, underscores or hyphens. Each computer needs the Godot engine, the matching game EXE for pack mode, and this test folder. Only test reports are shared manually afterward; coordination does not rely on shared files or shared clocks.

Separate Host/Guest launchers were tested locally. Separate-household internet routing, latency, jitter and packet loss have not been measured by the local runs. The test does not simulate impaired networks or measure RTT. A 60-second run is a short smoke/soak, not a substitute for a long online playtest.

## Results and save isolation

Every run gets a fresh folder under `.godot/network-tests/`. The console prints its exact location. It contains:

- `summary.json`: overall outcome, configuration and all local peer results.
- `result_host_0.json` and guest result files: identity, protocol, measurements, exit status and failure reason.
- Per-peer stdout, stderr and Godot engine logs.
- Dedicated `saves/`, temporary data and application-data folders.

Actual Garden/character save paths are set to the run's `saves/` directory; active world/character leases are disabled for these newly generated fixture profiles. Normal player saves are not loaded or overwritten. Logs and fixture saves are retained for diagnosis. Tests are excluded from shipping resources via `.gdignore` and export filters.

Peer exit codes: 0 pass, 1 assertion/connection failure, 2 phase timeout, 3 setup failure. The launcher exits 1 if any peer or setup failed. To verify failure handling, run a Guest against an unused port with a short timeout; it must fail, not report a pass from an empty log.

## Options

| Option | Default | Meaning |
|---|---|---|
| Clients | 3 | Guests, 1–3 |
| Port | 24600 | Test UDP port, 1024–65535 |
| PlayMs | 2500 | Movement duration, minimum 500 ms |
| TimeoutMs | 20000 | Per-phase timeout, 1–120 seconds |
| HostFps / GuestFps | 60 / 240 | Frame-rate limits |
| Role | All | All local peers, Host only, or Guest only |
| Address | 127.0.0.1 | Host address for guests |
| Index | 0 | Guest index, distinct for remote guests |
| RunId | generated | Shared identifier; required in manual roles |
| Pack | empty | Optional exported EXE/PCK to test |
| LogRoot | .godot/network-tests | Parent directory for unique run folders |
| SkipImport | false | Skip source import when already prepared |

`ReturnResult` returns the summary to another PowerShell script without exiting its caller; the release tooling uses it. The Unix `run_net_test.sh` wrapper delegates to the same PowerShell implementation and requires PowerShell 7 (`pwsh`). It accepts the earlier environment options (`GODOT`, `CLIENTS`, `PORT`, `PLAY_MS`, `TIMEOUT_MS`) plus `HOST_FPS`, `GUEST_FPS`, `ROLE`, `ADDRESS`, `RUN_ID`, `INDEX` and `PACK`. Linux/macOS execution was not available for validation in this Windows environment.

## Changes from the supplied bundle

- Removed the stale protocol-5 claim; the harness uses the running game's protocol constant.
- Fixed quoted Windows paths, environment isolation, import failure checks, hidden launches, stderr capture and bounded process cleanup.
- Replaced independent exit timers with a start/report/verdict barrier and sequential teardown, preventing false failures caused by early departures.
- Added checks for all-party movement, walking animation, snapshot delivery, slot uniqueness and inventory privacy.
- Corrected JSON report locations and made missing/invalid results fail even when an engine process exits zero.
- Replaced the Bash subshell PID/wait implementation with one shared launcher implementation.
- Added source and exported-pack release gates; the test scene/scripts must not be included in the shipping pack.

The original supplied files were preserved in the Codex workspace before adaptation. No gameplay logic or current shipping EXE was changed for this work.
