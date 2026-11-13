# Avoidable expedition pressure — 2026-11-10

The old `update_pressure` timer removed HP directly after the first full biome circuit. It had no attack, distance check or opportunity to dodge. That behavior has been removed. `expedition_pressure.gd` now owns transient reinforcement scheduling; ordinary enemy AI remains the only source of damage from these waves.

## Player-facing rules

- Pressure starts on repeat circuits (normally encounter 19 onward). First-cycle encounters and authored boss/Heart encounters are excluded.
- The first warning starts after 35 seconds on the first repeat circuit. Every arrival has a three-second blue ground-ring/countdown warning and a HUD message. Existing owner snapshots carry the warning to guests; fog still limits individual marker visibility.
- Waves start at one enemy and grow to at most four. Later circuits, additional players and successive waves increase pressure. Intervals shorten to an 18-second minimum, plus the warning period. Population stays within the normal solo/co-op scout limit and the synchronized 20-slot ceiling.
- Arrivals must be on usable terrain, at least six meters from every living player, separated from enemies and clear of entry/exit gates. Each warned position is checked again at arrival. An unsafe site is skipped, never silently relocated.
- Arriving enemies have 700 ms of attack grace, then use their normal movement, telegraphs and attacks. Independent support monsters and bosses are excluded from the wave pool.
- Clearing the floor immediately cancels pending arrivals and permits normal gate interaction. Waves also cancel on party wipe, return to the Garden and encounter reset. A warning cannot hold a cleared floor closed or resurrect its encounter.
- Reinforcements use existing summoned-enemy reward rules. They cannot produce endless XP, essence, parts or adaptation observations by waiting at a gate. Natural encounter enemies retain their normal individual rewards.

## Ownership and compatibility

Only the host schedules and spawns waves. Transient state lives inside the encounter's existing `leader_brain` dictionary and is reset by the existing encounter reset. No world/character save migration or RPC layout change is needed. The existing campaign countdown field now means next reinforcement warning/arrival; the HUD no longer calls it a damaging pulse.

The scheduler uses a private deterministic RNG, preserving combat and loot rolls. It reuses dead scout slots with fresh spawn tokens. It does not write saves each wave. The shared diagnostic journal records `combat/pressure_warning` and `combat/pressure_reinforcements`, including wave/floor/count and skipped arrivals, once per transition.

## Validation boundary

`tests/expedition_pressure.gd` checks warning timing and graphics, unchanged health, safe arrivals for all players, grace, unsafe-site cancellation, clear/reset/wipe cancellation, deterministic RNG isolation, excluded encounters/supporters, summoned reward suppression, escalation caps and dead-slot identity reuse. `tests/expedition_pressure_coop.gd` uses a real admitted host/guest connection and the production snapshot path to check warning replication, authoritative arrivals, guest non-authority, unchanged HP and clear cancellation. The playable smoke now expects a reinforcement countdown instead of automatic damage.

The reusable mechanics map owns the service and its small dispatcher/render hooks under `expedition_pressure`. Unchanged unrelated suites reuse their verified evidence. Automated checks do not establish final difficulty tuning or internet latency; those still need normal playtesting.

## Verified release

Connected run `20261110-175615-b2ead59f`: four affected suites passed, 94 unchanged suites reused; 39 planner self-tests passed. Packaged validation ran three selected checks with 62 unchanged packaged results reused, plus startup/catalog validation and a real host/three-guest connect-and-play smoke. Both source and packaged reinforcement host/guest checks passed.

Installed only `C:/Users/sutte/Desktop/Mystical Garden v0.5.2.1.exe` after it was closed; SHA256 `f0576969520e2482ee4581e151770e739c33c5fb82f3d22dec97861a37693a0a`. Its prior build is retained at `.godot/release/backup-20261110-175726-Mystical Garden v0.5.2.1.exe`. The protected pre-cleanup backup was not accessed.
