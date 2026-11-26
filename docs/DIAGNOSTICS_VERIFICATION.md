# Diagnostic logging verification

Implemented for Mystical Garden v0.5.1.3, protocol 16.

- All 70 registered source suites passed, including the new diagnostics unit and real host/guest suites.
- All 37 portable packaged suites passed, including four-player connection/overflow checks and host/guest report correlation.
- Real script-error capture with a nonempty stack and abrupt child-process termination passed in source and compiled-package checks.
- The actual release EXE was launched with isolated app data, produced session/heartbeat files automatically, and retained those flushed events after a controlled external process termination. This validates breadcrumbs for abrupt termination; it is not a reproduction of a native memory-fault stack. Its runtime source fingerprint matches the installed build.
- The Diagnostics settings tab was rendered and inspected, including issue marking and the exported ZIP path.
- Threaded writes, rotation/rate/line limits, active-session retention, disk-write failure isolation, report contents and omission of profile/name/address fields passed.
- The generated build-metadata dependency bug was corrected and regression-tested (27 planner self-tests now pass). A post-export source recheck executed zero game suites and reused all 70 results.
- The final install ran packaged startup and host/three-guest smoke while reusing the other 36 packaged results. Only the highest revision EXE was replaced, with a recovery backup.

See DIAGNOSTICS.md for collection instructions and data/retention details.

Installed SHA-256: `3dd1a16a6ffd577207c118414d8b5fb2d118b0079b52d2601fb095f992133303`

Runtime source fingerprint: `D9555D13218676AED342CEC4DE4A0F9DA34D762600D0F84BF32F76D87036FB3D`

## ST01 ordinary multiplayer reproductions

The committed INT01 baseline was `9c167d3a58e90f885f081bb1abecf05112f6cba5`. One unmodified two-player Spirit, four-player Water and four-player extraction check each passed on loopback. The failures below used the same committed baseline, independent Godot processes and disposable profiles. Connection or registration failures occur before either gameplay assertion and are a separate result.

* **Checkpoint.** Three of four consecutive Water party traces timed out waiting for a guest checkpoint revision and three card faces. In the first failing run, expedition 1, floor 3, the host received the guest's interaction at the gate with owned drop `2:25:1542797978` in pickup range. Pickup has priority. There was no ledger offer or outgoing card message for that guest. The other guests received offers, including the charged reroll for one player. The fixture used the host's filesystem marker as guest readiness and issued one interaction. Logging-only source delta SHA-256 was `e0a6fde33b07834f90a0761fee785ae237345a20d3fcacbb0185c4ed14a8bf70`.
* **Finalized summary.** The four-player extraction check waits for both the exact restored HP revision and the visible personal report. Delaying only the membership snapshots for early returners and delivering their real waiting-state vitals after their real report reproduced the original assertion. The first guest's report opened at 30,084 ms, its 100-HP waiting record arrived at 30,103 ms, and spectator focus closed the report at 30,320 ms. The second guest showed the same sequence. The still-current Wilds membership and newly published fallen flag form a transitional spectator frame. The UI had already marked the report as opened, so later duplicate delivery could not reopen it. Host settlement and report identity had succeeded. The disposable ordering probe's source delta SHA-256 was `e7740383079ca159b7764a56d5e0e7686d00d74d11e59dcc2b7cf2577dfcbcc5`.

### ST01 verification

At `67f3fa8835b19d90ff356918942736be18025907`, three independent two-player Spirit runs, three four-player Water runs, and three four-player staggered-extraction runs passed on local loopback (nine attempts, zero failures). Each staggered-extraction run exercised equal-depth individual departures, deeper party extraction, Garden rejoin, a second expedition ending in a wipe, stale and duplicate result delivery, and fifth-client refusal. The separate controlled four-player ordering that previously closed two reports also passed after the presentation fix.

The card ledger checks cover a recovered unresolved offer on a replacement peer binding, zero eligible choices, rerolls, repeated selections, and stale selections for the same numbered floor in a later expedition. Two- and four-player Wilds suspension/resumption, the voluntary title handoff, and the rollback, cleanup-pending and uncertain-outcome checks in `legacy_departure_outcomes` passed in disposable storage.

One separate guarded-disconnect test remains red on pristine INT01 and ST01. Its three failing assertions each require an already removed synthetic guest dictionary to have no wallet key. An isolated readback found a wallet with zero spendable Essence. The disconnected peer could not receive new credit, rollback preserved the original disk bytes, and the retry banked the expected XP and pouch once. The original assertions and settlement behavior are preserved.
