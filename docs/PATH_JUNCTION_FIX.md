# Path junction fix — 2026-11-07
The existing field blended dirt boundaries but left some merged shoulders narrower than the player's clearance. Increased the rounded junction blend from 1.8 to 4.0 so nearby corridors join with traversable space. Rendering, movement, navigation and floor-map discovery continue to use the same field. Decorative path-bank roots are clipped out of traversable junctions instead of drawing an apparent barrier across an open crossing.

Added tests/path_junctions.gd: 26 bidirectional parallel-path shoulder crossings, checked with both incremental walking and dash; also verifies separate routes and cover stay blocked. This fixture fails with the previous blend.

Passed: new junction regression, 48 deterministic exploration maps including route following, floor-map/fog checks, shrine and knockback checks. Rendered an active encounter under the Compatibility renderer. Rebuilt Mystical Garden v0.1.exe and verified standalone startup (exit 0).

Original source preserved under docs/change-backups/pathing-20261107-175755; previous executable preserved in the Codex workspace work/change-preview/Mystical Garden v0.1-before-pathing.exe. Tests used isolated saves.

Screenshots do not include the map seed, so the exact pictured floors could not be replayed. The regression recreates the narrow parallel-path seam visible in the examples.
