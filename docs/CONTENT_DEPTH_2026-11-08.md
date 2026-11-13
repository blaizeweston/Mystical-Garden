# Seed and class depth expansion

The roster now contains 24 species, 62 stable components (ordinary/refined plant materials plus existing monster trophies), 104 checkpoint cards, and five classes with 12 choices each across seven levels. Existing seed, component, class, weapon, and node IDs remain unchanged. New class thresholds are 140 and 260 XP; the first five level thresholds are unchanged.

## Sequential gates

1. Frostbell alone was added as species 16. `frostbell-first-species-gate.log` records passing altar discovery, weighted Wilds acquisition, growth, harvest, refinement, portrait/tree connections, actual third-contact shattering, a compatible checkpoint purchase, and persistence before the other eight species were authored.
2. The Warden alone was extended to 12 choices while the other four trees still had eight. `warden-first-class-gate.log` and `warden-first-class-network-gate.log` record passing behavior and real guest tests before the remaining classes were extended. The Warden test covered directional vulnerability, movement cost, ally protection, counter consumption, warding fields, plant/monster compatibility and a real three-card checkpoint purchase.
3. The shared templates were then applied to the other species and classes. `species_depth`, `class_depth`, `seed_template`, `warden_depth`, `warden_depth_coop` and `class_depth_coop` are required source and compiled-pack release checks. Test profiles are isolated; player saves are not used.

## New species

|Species|Parents|Wilds from encounter|Ordinary / refined material|Identity|
|---|---|---:|---|---|
|Frostbell|Lantern Moss + Dewcap|20|Chiming Sepal / Crystalline Bellheart|Hits build brittle for 4 seconds. Three stacks shatter for bonus damage. Slower swings reward repeated contact.|
|Ironroot|Ember Fern + Ember Fern|10|Banded Root / Ironwood Core|Stand still for half a second to brace: your next committed hit gains damage. A braced stance can block one hit every 4 seconds.|
|Whispervine|Thorn Bloom + Veilcap|18|Listening Tendril / Whisper Nerve|First contact marks for 4 seconds. Further contacts exploit the mark for extra damage.|
|Mirror Mint|Veilcap + Cinder Vine|22|Silvered Leaf / Prismatic Frond|Every third contact echoes once after a short delay at half strength. Echoes cannot echo themselves.|
|Gravemoss|Lantern Moss + Cinder Vine|24|Grave Filament / Funeral Spore|Natural killing blows store up to three death charges. A later hit consumes one for extra damage.|
|Tide Lily|Ember Fern + Dewcap|24|Dew Chalice / Pearl Stamen|Contact creates a brief healing pool with a 4.5s recovery. Living allies in the pool recover and cleanse slowing roots.|
|Hush Orchid|Ghost Fern + Frostbell|38|Silent Petal / Hollow Throat|A precisely timed contact interrupts an enemy wind-up. Each enemy resists another interruption for 4 seconds.|
|Dream Poppy|Bloodbriar + Mirror Mint|40|Dream Pollen / Lucid Capsule|Contact grows a short-lived decoy away from you. Foes pursuing you are drawn toward it; it cannot deal damage.|
|Crownroot|Hush Orchid + Dream Poppy|60|Woven Root / Sovereign Knot|Links a contact to a nearby second enemy at reduced strength. Linked hits may carry brittle or marks but cannot branch again.|

All species have normal growth stages, flowering, familiarities, inventory identities, ordinary and refined materials, an altar lineage recipe and a same-material refinement recipe. They can also be found through weighted mysterious-seed drops after their thresholds. Mythic materials refine within the capped Mythic rarity; the result has a distinct component identity and improved quality. Refinement strengthens positive properties while easing negative penalties. It does not uniformly multiply damage.

The altar retains two-slot drag-and-drop, unknown question-mark results, explicit confirmation, salvage, ownership accounting and saved recipes. Its recorded-recipe selector fills both sacrifice slots without spending anything; the player can still edit or clear them. Its heading shows discovered species out of 24. Seed tree nodes use portraits rendered from their actual mature growth models.

## Class directions

|Class|First direction|Second direction|
|---|---|---|
|Warden|Living Bastion|Thorn Vanguard|
|Weaver|Rootbinder|Bloomcaller|
|Ranger|Wildstalker|Snarekeeper|
|Reaper|Blood Harvester|Veilwalker|
|Oracle|Lifekeeper|Omenreader|

Each class retains three weapons, two starting skills, existing level 2–5 choices and original replacement skills. Levels 6 and 7 add specialization and its matching capstone. New nodes append after the original eight and use actual prerequisite IDs in the root tree; choices on competing branches are exclusive. Refunds stay at the Heart between expeditions. Learned choices remain character-owned; run upgrades remain expedition-owned.

The Warden gains a forward-facing Rootshield with reduced movement, an alternative guard that prepares a real counter, a stationary warding quake and a committed shattering charge. Weaver can spread binds or cultivate/detonate a stationary bloom. Ranger can exploit marks and retreat, or lure enemies into persistent snares. Reaper can build death charges and drain nearby victims, or prepare marks and resolve delayed strikes. Oracle can place healing/cleansing protection or mark and punish attack wind-ups. None of these heal or guard fallen characters into an automatic revival.

New cards include one signature per new species, three plant/monster links and four behavior cards per class. Skill-specific cards check the equipped skill modes; a trap or healing-only choice is excluded from incompatible kits. Cards keep three text choices and the existing 8% fourth-card chance. Rank caps prevent repeated purchases of one-time behavior unlocks.

## Shared behavior contract

`combat_traits.gd` owns the supported effects; plant slots, class bonuses and checkpoint cards all use the same vocabulary. Echoes and linked hits are secondary contacts and cannot recursively create more echoes, links, pools or decoys. A maximum of 24 queued contacts/fields is active. Delayed contacts carry an encounter epoch and target spawn identity, recheck owner/alive state and terrain sight, and cannot damage a replacement target on the next floor. Fields are stationary and owner-scoped. New runs clear temporary charges and recovery timers. Monster kill receipts remain the sole XP/loot route; summoned brood do not farm Gravemoss charges.

## Authoring

`assets/content/part_order.json` is now the append-only current component order; frozen v1/v2 migration files were not edited. Append both ordinary and refined component IDs there before assigning a new numeric seed.part. The validator rejects an uncovered or reordered registry. Examples are in `assets/data/plant_template.json`, `class_template.json`, `specialization_template.json` and `checkpoint_behavior_template.json`. Add a behavior to the resolver and its tests before describing a new effect key.

Network protocol 10 requires both peers to update. Public movement/health remains separate from reliable owner inventory and profile details. Cast fields reuse the existing bounded reliable combat-event channel. Local and graphical co-op checks do not prove real internet latency tolerance.
