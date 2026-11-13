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
