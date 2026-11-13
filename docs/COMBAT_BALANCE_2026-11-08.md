# Enemy pressure, targeting, drops and learned world responses

## This tuning pass
- Opening solo encounters: one leader and six scouts, up from one leader and four scouts. Two-player encounters add four scouts, within the existing twelve-scout limit.
- Population and health use total expedition depth, preventing biome resets from discarding accumulated pressure. Co-op health is 30% higher initially, approaching 60% higher deeper in a run; maximum health is frozen per encounter and sent by the host.
- Wider line-of-sight engagement and local group alerts reduce isolated one-enemy pulls. Roles keep their distinct warnings and support escorts. Melee approach angles, crowd separation, stable threat commitments and shared player attention make groups less linear. Ranged warnings lead bounded movement at commitment time, then remain fixed so players can evade them.
- Players' basic attacks and aimed skills prefer visible, reachable targets with a modest facing/stability bias. Dead or reused targets do not receive old queued hits. Half-heart baseline damage remains; 220 ms of hit grace limits simultaneous swarm damage. Telegraphs stay at least 420 ms and recovery retains a floor.

## Trophy economy
One independent roll per player per natural cleared encounter, on loot claim. Base 24%, plus 0.4 percentage points per floor (maximum 12 points), ten points for guardians and three for an adapted source, with an overall 46% cap. The chosen source comes from actual natural kills and carries that creature's own tags. Summoned brood add neither trophy eligibility nor extra rolls. Seeds are unchanged. Item weights decide which eligible item follows a successful roll; weights do not replace the chance gate.

The deterministic 1,000-roll early-third-floor test returned 224 trophies and 776 empty rolls. This is verification of non-guaranteed behavior, not a promise of exactly 224 drops in a player's runs.

## What the Wilds remembers
The existing host-world adaptation was limited to expedition pressure. New versioned memory also records each settled encounter and evidence of repeated successful ranged, burst, narrow-path and moving-ranged tactics. Three consistent early victories can establish a response; deeper evidence accumulates faster. Active pressure fades only slowly after quiet encounters and retains a fraction of its learned peak. The original expedition pressure remains compatible with old saves.

Opening floors are protected, with one trait allowed early, two in the middle depths and three later. Traits use existing visible reach, bark, spore and mobility models and authored abilities. Natural variation develops after enough host-world encounters even without repeated tactics. A first-learning message makes new responses apparent. This is a rules-based adaptive director, not a neural network or unrestricted strategy invention. There are no cross-world observations or remote training services.

## Validation and limits
combat_balance.gd checks solo/co-op budgets, safe separated spawns, global-depth pressure, frozen replicated health, threat sharing, target commitment, player aim, bounded prediction, hit grace, learning persistence, settlement rollback and trophy distributions. 9,000 sub-grid collision comparisons agreed with exact terrain, and path-junction tests remain intact. Cached conservative interior checks and persistent navigation waypoints reduced the fully engaged twelve-scout CPU sample from roughly 65 ms to 1.4 ms p95; five-floor generation was roughly 308 ms p95. These are local headless CPU samples, excluding GPU rendering.

An automated movement/combat bot cleared the tuned opening encounter. Existing mechanic fixtures now set explicit enemy health where testing a fixed number of contacts; they do not weaken production encounters. Human solo/co-op runs, latency, different classes and long-term economy still need play data. This is a stronger, measurable baseline rather than a claim of final difficulty balance.
