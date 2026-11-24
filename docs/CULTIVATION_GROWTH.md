# Cultivation timing and watering

Updated 2026-11-10. This supersedes the first G-04 timing and flowering-mode descriptions. G-05 remains the next milestone; these changes refine cultivation first.

## Current rules

| Tier | Rarity | Base growing time |
|---|---|---|
| 1 | Common | 5 minutes |
| 2 | Uncommon | 12 minutes |
| 3 | Rare | 25 minutes |
| 4 | Epic | 50 minutes |
| 5 | Mythic | 90 minutes |

These are initial balance values in each species definition's `grow_seconds`, not real-world/offline timers. All species of a tier currently share its duration. The old durations are retained only as `legacy_grow_seconds` migration metadata.

One host-owned clock advances occupied beds while the world is running. Growth is **2× while any player is in the Wilds**; it does not multiply again with party size. Existing Knowledge bonuses remain 1.2× for irrigation or 1.4× for the nursery. The nursery supersedes irrigation's rate, as before.

After **Reaching Roots** (`clearing_1`) and **Root Irrigation** (`irrigation`) are researched, approach a reachable dry bank of the Garden water and press **E** to fill your watering vessel. No spring fixture or watering basin needs to be built. Then choose **Water crop** at a growing crop. One fill waters one crop and grants **1.25× speed until that crop is harvested**; only an accepted watering transaction consumes the vessel. Watering is optional and available once per crop, with no drying-out timer or crop death. Duplicate requests cannot stack it. Replanting starts unwatered. Water, blocked approaches and remote requests do not become legal actor positions or fill locations.

Rates multiply: Wilds 2× × nursery 1.4× × watering 1.25× = **3.5×**. A Mythic crop therefore takes about 25 minutes 43 seconds under all three bonuses, before an optional preservation delay, versus 90 minutes with no bonuses. Preservation still adds 20% growing work and its bounded rare-part benefit; watering does not alter yields, familiarity or that chance.

The inspector shows the current rate, remaining time, Garden/Wilds estimates and watering state. The seed picker shows the base duration before planting. Watering adds a small local splash and damp-soil cue; disabling ambient motion suppresses droplets while retaining the state cue. Visuals do not grant progress or drive the clock.

## Flowering is a harvest choice

After Flowering is researched, a **mature** plant can be harvested for:

- Its normal crafting part, with the existing rare-part roll and any preserved-bud benefit; or
- Two personal seeds, sacrificing all crafting parts and the bud benefit.

Both consume the mature plant and empty its bed. Flowering does **not** reset its age, replant it or require another growing cycle. An immature request is rejected without changing the crop. The inspector offers both choices when ready; the normal interaction remains the quick parts harvest, and the flowering action chooses seeds. Native amounts/chance/familiarity are defined in `garden_cultivation.gd`; `garden_cultivation_world.gd` applies the payout through the existing transaction. No alternate Game harvest implementation remains.

Simultaneous choices resolve once. A failed seed-harvest save restores the original mature plant, so the player can choose again. Watering and seed harvesting add no extra Knowledge, class XP or familiarity beyond the established harvest award.

## Shared implementation and migration

Start in `garden_cultivation.gd` for pure planting, care, native yield and preview rules. `garden_cultivation_world.gd` is the peer/bed-ID integration API for host access, stock/material changes, transactions and publication. `progress.gd` remains the sole saved-bed/growth owner; there is no copied crop ledger. The old `garden_crop_service.gd` and six Game planting/harvest helpers are retired.

`cultivation_growth.gd` is the common policy for rates, duration, migration, water-unlock prerequisites and readable time text. `garden_water.gd` reads actual rendered water footprints and validates dry reachable banks; `garden_cultivation_world.gd::fill_water` retains host admission and vessel state. Saved observation/command IDs retain their historical spring names without retaining the fixture. `progress.advance_growth(seconds, in_wilds)` is still the only clock. The live host tick passes the existing `expedition_active()` flag; the view uses the same rate helper. The former expedition-milestone lump-sum crop advance is removed, so faster growth comes from time spent in the Wilds rather than an additional floor/departure payout. Heart research now completes at purchase.

Sprout and young stages remain at 22.5% and 56.25% of base work. Normal maturity is 100%; preserving a bud changes only maturity to 120%. Work is saved at stage transitions and when crossing 30-second work intervals, avoiding long high-tier crops depending solely on an infrequent stage save. This supplements existing action/return saves; it cannot guarantee progress through a disk failure.

Plots save `growth_rules: 2` and their `growth_base`. When loading older timing, the loader transfers the **fraction completed** into the new duration; mature plants remain mature. It removes the obsolete growing-for-seeds mode while retaining progress, so those plants receive the same seed-versus-part decision at maturity. A preserved crop retains its choice and frozen roll; its percentage is calculated against its old extended duration. Long saved ages are no longer capped at 1,000 seconds. Future growth versions are retained and not advanced by unsupported rules.

Before overwriting a save containing legacy crops, the normal save path creates `<save>.pre-tier-growth-v2.bak` once. Tests use isolated fixtures. The separately retained pre-cleanup backup is not involved.

The optional cultivation projection is version 2. Watering uses the existing Garden command route and crop cycle/revision guards, with a post-commit `crop_watered` diagnostic event. The pre-game multiplayer compatibility exchange now includes a cultivation-rules fingerprint so older builds with different harvesting behavior are rejected before gameplay. All players should use the updated EXE.

## Verification and future tuning

`cultivation_growth` verifies all 24 tier durations, the live host Wilds tick, Knowledge/water multiplication, once-only watering, no instant progress or bonus rewards, estimates, save/reload, failed actions, mature seed harvesting, progress-preserving migration and the separate migration backup. `garden_crop_care` retains the preservation/yield/rollback checks under the new timing. Real host/guest care tests cover duplicate watering and competing seed harvests. The Warden compatibility regression checks both missing and mismatched growth fingerprints before normal ability testing.

Existing lifecycle tests fast-forward their setup rather than waiting minutes; exact timing is owned by the new growth suite. Seed/crafting, research, inventory and run-flow consumers remain in the interaction map. Full game-suite runs remain reserved for major releases or explicit requests.

Future changes should tune the species data or shared multipliers, not add another crop timer. Preserve saved percentage when changing durations and keep watering bounded to a crop identity. G-07's proposed living water conduit can still add zone configuration; it must not duplicate this watering boost or create repeat-click acceleration.


## Cultivation refinement release — 2026-11-10T14:46:06-05:00

Implemented the user's pre-G-05 cultivation refinement: tier durations 5/12/25/50/90 minutes, shared 2× live Wilds growth, existing Knowledge rates, optional once-per-crop 1.25× spring watering, readable estimates, progress-preserving save migration and a separate pre-migration save backup. Flowering is now an alternative mature harvest of two seeds instead of parts; it neither resets age nor starts another growing phase. Both harvests empty the bed. Watering adds no XP or material grant. G-05 has not begun.

The first connected pass executed 39 related suites and reused 52; one four-player animation smoke check failed. It reproduced on an isolated retry: a guest's positions moved while its pose stayed still. Client renderer velocity hints can be zero after bounded prediction substeps. A narrow `avatar_motion_view.gd` adapter now derives walking from displayed travel, without changing movement simulation or combat. The regression checks movement with a zero hint, preserves the original simulation dictionary, and verifies settling at rest.

Final current run `20261110-144104-be2754e4`: 7 affected checks executed, 84 reused, 91 registered; all current evidence passed and all 36 planner self-tests passed. Packaged validation ran 27 selected suites with 31 reused, plus startup/catalog/exclusion and real host/three-guest connection checks. Full game-suite validation was not run. Only `Mystical Garden v0.5.2.0.exe` was replaced; installed SHA256 `3a691a7a940a401d23194aa9f7a562891e381045475d5e120857480d6e0cc343` matches the verified staged artifact. Co-op players must all use this build; the auth exchange rejects mismatched cultivation fingerprints.

Evidence: `.godot/growth-v2-unit.log`, `.godot/growth-v2-care.log`, `.godot/growth-v2-connected.log`, `.godot/growth-v2-connected-final.log`, `.godot/growth-v2-package.log`, `.godot/validation/runs/20261110-144104-be2754e4/` and `.godot/validation/last-package.json`. The in-engine Mythic watering/harvest frames `.godot/growth-v2-water-choice.png`, `.godot/growth-v2-watered.png` and `.godot/growth-v2-harvest.png` were reviewed. [Current rules and authoring boundaries](CULTIVATION_GROWTH.md). The protected pre-cleanup backup was not read, scanned, hashed or modified.
