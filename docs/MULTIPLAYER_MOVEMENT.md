# Multiplayer movement improvements

Guests immediately predict ordinary walking using the host's movement-speed modifier, Garden radius and the generated collision field. Sequenced input history is acknowledged by the host and replayed after each authority update; partial command acknowledgements preserve simulated time. A redundant batch covers the latest 18 commands. Invalid, duplicate, old-world and stale inputs cannot grant additional simulation time. Pending history, server queues and speculative travel are bounded.

World/biome/floor/seed, Garden/Wilds state and fallen state form a movement epoch. Changing epochs discards previous movement. Death/revival, teleports, dodges, skills, damage, inventory, gates and combat remain authoritative. This update predicts walking only; it does not predict skill outcomes or damage. Guests cannot use local movement to authorize actions.

Other players are rendered from a 100 ms position-history buffer; this does not modify authoritative player dictionaries. Silence holds the latest position instead of extrapolating indefinitely. Existing visual smoothing handles corrections and snaps large discontinuities. The host snapshot scheduler preserves its fractional remainder to maintain the intended 20 Hz average. Larger inventory/research/details refreshes are reduced from about 8 Hz to 4 Hz; reliable health events remain immediate. Movement input and world snapshots have independent unreliable-ordered channels (3 and 4).

Protocol is now 17. All co-op copies need the updated build. Persistent saves and character formats are unchanged. There is no router/port change.

Validation includes deterministic delayed/lost input recovery, matching travel distance, release convergence, partial acknowledgements, stale/invalid input rejection, bounded speculative movement, slow/fallen states, bounds/terrain collision, floor resets and remote interpolation. A separate real host/guest suite exercises the actual movement RPC and acknowledgements. Existing four-player, combat/life, diagnostics, gates and packaged checks remain required by the validation planner. Loopback and simulated latency tests do not replace a real internet playtest.

The original source files are backed up in `docs/change-backups/20261110-movement`. Raw playtest logs and previous report outputs are unchanged.

## Installed build

Updated `C:/Users/sutte/Desktop/Mystical Garden v0.5.2.0.exe`. All 71 source suites passed, followed by 38 packaged suites, startup/catalog smoke and the real host/three-guest connection smoke. Installed EXE SHA-256: `177ee9fb8804aa8f36f7fda42c07ce1f544e0d957b84bea6c655f233ad60cec4`.

The previous EXE is backed up at `.godot/release/backup-20261109-234109-Mystical Garden v0.5.2.0.exe`. Source evidence is in `.godot/validation/latest-report.json`; packaged evidence is in `.godot/validation/last-package.json`. Real internet playtesting is still needed to assess the reported guests’ experience.
