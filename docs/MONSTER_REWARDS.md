# Individual monster rewards and first enemy expansion

The roster now contains 13 species. New entries are appended to preserve saved enemy IDs, component IDs and personal familiarity:

- Root Shepherd (floor 3+, Grove/Hollow): a bowed antlered plant with a crook. Requires two combat escorts. Its telegraphed command focuses nearby allies on a live player for a short coordinated advance. Drop: Shepherd Knot, adding a target and recovery pressure when grafted.
- Hollowback Grazer (floor 4+, Grove/Mire): a four-legged infested grazer with layered fungal shelves. Nearby allies receive one point of damage reduction, with a minimum of one damage. It does not protect itself; killing it removes the aura immediately. Drop: Hollow Carapace, adding maximum health and knockback.
- Lantern Lure (floor 5+, Mire/Hollow): a bent stem suspending a warm glowing bladder in a root cage. Its marked circle resolves into damage, slow and a short terrain-constrained pull toward the creature. Dodging the circle avoids all three. Drop: Lure Bladder, adding pull and recovery pressure.

Editable Blender sources are assets/source/enemies/*.blend. Regenerate individual species through tools/make_enemies.py -- SPECIES_ID. All use the same growth and adaptation sockets, death animation and encounter templates.

Each natural enemy death prepares exactly one reward event. Every active, living party member receives equal automatic essence sparks and class XP tenths, and an independent part roll based on the actual dead species and mutation tags. Supports receive full party credit; the final blow is not contested. Summoned brood award none of these rewards. Duplicate death events cannot award twice.

Initial tuning: ordinary enemies give 0.25 essence and 0.1 class XP; encounter leaders give 0.5 essence and 0.3 XP. Four sparks become one spendable essence, and ten XP tenths become one existing class XP unit. Existing class levels and earned XP are preserved. Fractional XP persists and appears in the class tree. The existing two-essence floor-clear bonus remains; clearing a floor no longer grants extra class XP or a group monster-part roll. Seed bundles and caches remain separate from monster parts.

Ordinary part chance starts at 4%, with small depth/adaptation bonuses; a guardian bonus applies only to an actual leader at a guardian floor. The total cap is 15%. Tune values in assets/content/balance.json. Part selection uses the dead creature's species and mutation tags, never a randomly selected member of the defeated group.

Successful parts appear at the kill location as personal ground items and discovered map markers. Other players cannot see or pick them up. A player can pick up their part, then deliberately drop it using the inventory to share it. Parts are carried loot: extraction banks them, and normal loss/pouch rules apply. Unclaimed ground drops disappear when leaving the floor. Essence and XP require no pickup; run essence resets when the expedition ends, while class XP remains earned even on failure.

Rewards are batched briefly and committed through the existing cross-file transaction system. Rolls are prepared once before persistence, so a failed save retains the exact pending rewards without rerolling. XP, monster familiarity, personal drops and party wallets roll back together. Notifications publish after successful settlement. Protocol 6 requires matching builds.

Checks cover individual non-final kills, per-owner visibility and pickup authorization, equal party credit, duplicate suppression, summon exclusion, bounded rates, XP persistence, save rollback/retry, all three enemy behaviors, four-player delivery and reconnect, and exported runtime behavior.

Each of the three new grafts also has a weighted Rare checkpoint upgrade: Shepherd Dominion, Canopy Remnant and Luring Undertow. These enter the card pool only while the matching component is installed; purchased effects remain after replacing the graft.
