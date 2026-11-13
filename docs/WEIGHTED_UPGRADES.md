> Current expansion: 24 species, seven class levels, 12 choices per class and 104 checkpoint cards. See [current content depth](CONTENT_DEPTH_2026-11-08.md); historical counts below describe earlier milestones.

# Weighted checkpoint upgrades

At cleared encounters **5, 10, 15…**, press **E** at the onward gate. Three text cards appear before travel, with an **8% chance** of revealing a fourth. Click a card or press **1–4**. Purchase one upgrade or explicitly continue without buying. Cards show rarity, the source of eligibility, exact effects, rank and cost.

The system currently contains **69 upgrades**: six weapon fundamentals, fifteen class techniques, fifteen weapon-specific awakenings, thirteen plant-affinity upgrades, ten monster-component echoes, five graft-tag upgrades and five rare affinity links.

## What shapes a draw

- Only the current class's techniques enter its pool.
- Each of the fifteen basic weapons has its own awakening.
- Installed plant materials unlock matching affinity cards. Repeated matching affinities increase weight. Core contributions carry weight 2.0, Form 1.0 and Catalyst 0.8.
- An installed monster part unlocks its species-specific echo and matching graft-tag upgrades. Merely carrying a monster trophy does not qualify.
- Combined plant and graft affinities can qualify for rarer links. Rift Hook requires installed Veilcap and Briar Hook.

Draws are weighted without replacement. Common / Uncommon / Rare / Epic use rarity multipliers **1 / 0.55 / 0.18 / 0.06**. Eligible class, weapon, monster, graft-tag and linked cards receive further biases. Rare and Epic weights gradually grow deeper into a run. Repeatedly buying the same upgrade reduces its draw weight; capped ranks leave the eligible pool. Fundamentals remain repeatable so long expeditions retain choices.

The first selection comes from affordable eligible cards when any exist. This ensures an affordable option without granting free purchases. Current costs are **6** for most Common cards, **8** for Uncommon cards and Practiced Technique, **10** for Rare, and **12** for Epic. Players continue earning two essence per cleared encounter and spend independently.

Offers are generated once per player per checkpoint using a dedicated random seed. Closing/reopening the menu, changing the combat RNG or changing a graft does not reroll them. Current prerequisites and funds are rechecked when purchasing. If a player changes the component needed by a cached offer, that card becomes unavailable; the player can still choose another card or skip.

## Run effects

Upgrades affect live weapon and class-skill stats: damage, Core technique, reach, attack timing, targets, stagger, knockback, pull, enemy recovery, maximum health, kill healing, skill healing, skill duration, skill recovery, dodge recovery and graft chance. Effects keep existing combat safety limits for timing and target counts; run health/healing bonuses are capped.

Purchased effects are recorded independently of equipped parts. Replacing a monster graft removes that part's own effects but preserves all checkpoint purchases, including its purchased echo. Plant slots and prior upgrades are not replaced or made dormant. Rift Hook continues to refresh dodge on wind-up hits and teaches its first discovery to the Garden.

Most specialized cards have three ranks, affinity links generally have two, and Rift Hook has one. Upgrades and their offers clear when returning to the Garden or ending the run; they do not spend class progression points or modify permanent character choices. Maximum-health upgrades immediately update the player's health capacity.

## Extending the pool

The data template is **assets/upgrades/checkpoint_upgrades.json**. Each entry contains a stable `id`, name, rarity, essence cost, base weight, maximum rank, description and numeric effects. Optional requirements include `classes`, `weapons`, `plant_tags`, `graft_tags`, `grafts` (monster species index), `plant_parts` (stable part IDs), or `all_tags` (combined installed affinities). All listed tags must match. Keep published IDs stable.

`run_upgrade_catalog.gd` owns eligibility, weights, seeded draws, effect aggregation and descriptions. `game.gd` owns cached offers, authoritative purchase validation, live stat integration and the text-card interface. The previous fixed three-upgrade system and its separate 30% Rift Hook roll have been replaced.

## Verification

Passed: all five class and fifteen weapon matches, all ten monster-graft matches, plant-slot weighting, unique eligible draws, cached offers, malformed/stale choice rejection, affordability, one purchase per checkpoint, fourth-card purchase, rank limits, live health effects, persistent graft echoes and reset on Garden return. A 2,000-draw test produced 159 fourth-card offers (7.95%). Three/four-card layouts were rendered and checked against viewport bounds, including selection using keyboard 4. Full solo gameplay plus inventory, grafting, checkpoints, class weapons, skills, HUD and Heart tests passed.

These weights and prices are an initial balance pass; variety is implemented, while long-run pacing still needs playtesting.

The exported Windows build passed the focused weighted-upgrade test. Both playable executables were refreshed with their prior builds backed up; v0.2 launched successfully.
