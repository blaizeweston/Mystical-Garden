# Seed lineages and living-root progression

## Current botanical progression (WF02)

All 24 species grow in ordinary Garden beds. Flowering reproduces the species planted. Natural specimens use the WF01 floor roll, depth bands and biome weights. A find fixes one species for everyone. Each participant can return one concealed seed per specimen and identify it at the starting altar.

| Natural founder | Earliest global encounter | Species reachable after adding this founder |
|---|---:|---:|
| Thorn Bloom and Lantern Moss | 1 | 5 |
| Ember Fern | 3 | 15 |
| Moon Lotus | 18 | 17 |
| Mirror Mint | 22 | 19 |
| Star Orchid | 31 | 21 |
| Sun Spire | 35 | 23 |
| Crownroot | 60 | 24 |

The last five founders require natural discovery for new rewards. Their catalog entries carry `seed_acquisition = wild_only`. Their parents still synthesize ordinary materials. Once a founder is obtained it can be shared, propagated and used in other recipes. The table is a reachability exercise with unlimited propagation. Finding other eligible species directly can open different routes.

Theoretical natural chances per eligible floor are shown below. Each range spans the three biomes and includes the 40% specimen roll, before terrain placement failures. The first column uses the founder’s first eligible encounter. Intervening floors change as more species and rarity tiers unlock.

| Founder | At first eligibility | From encounter 60 |
|---|---:|---:|
| Moon Lotus | 1.45–1.85% | 1.33–2.00% |
| Mirror Mint | 0.94–1.50% | 1.33–2.00% |
| Star Orchid | 1.60–2.40% | 1.67–2.50% |
| Sun Spire | 1.14–1.71% | 1.67–2.73% |
| Crownroot | 1.14–1.50% | 1.14–1.50% |

Ordinary caches retain their 20% opportunity, depth, biome and starter rules, drawing from the 19 open species. New Ancient seeds have their contents fixed at the boss's global encounter. Available Rare, Epic and Mythic tiers have relative weights of 25, 55 and 20. Early bosses use the highest available tier if none of those qualify. The altar reveals the concealed result. Pre-WF02 quantity-only Ancient stock retains its original identification roll, including the original chance of a now-exclusive species.

A discovered plant and a tested recipe are separate Garden records. Only a successful offering reveals a seed recipe in Living Roots. A failed pair records its one-material salvage. First species discovery grants 4 Knowledge. Testing a valid seed recipe for an already known species grants 2 once. See [Garden Altar](GARDEN_ALTAR.md) for the transaction rules.

## Historical initial collection

The table below records the initial prototype. For current acquisition, use the table above. Current growth and affinities are defined in `seed_catalog.gd` and the affinity families.

|Species|Rarity|Parents|Possible Wilds find from encounter|Growth (seconds)|Crafting effects|
|---|---|---|---:|---:|---|
|Thorn Bloom|Common|Basic lineage|1|80|reach 0.9|
|Lantern Moss|Common|Basic lineage|1|80|recovery 550|
|Veilcap|Uncommon|Thorn Bloom + Lantern Moss|6|80|windup_damage 1|
|Ember Fern|Common|Basic lineage|3|80|damage 1, cooldown -120|
|Cinder Vine|Uncommon|Thorn Bloom + Ember Fern|8|105|reach 0.5, damage 1, cooldown -100|
|Dewcap|Uncommon|Lantern Moss + Ember Fern|8|105|recovery 300, cooldown 70|
|Bloodbriar|Rare|Thorn Bloom + Cinder Vine|16|130|damage 1, heal_on_kill 1, cooldown -140|
|Ghost Fern|Rare|Lantern Moss + Veilcap|16|130|reach 0.4, recovery 850|
|Storm Reed|Rare|Cinder Vine + Dewcap|18|130|cooldown 100, knockback 0.65|
|Moon Lotus|Rare|Veilcap + Dewcap|18|130|windup_damage 2, recovery 400|
|Star Orchid|Epic|Bloodbriar + Ghost Fern|31|155|damage 1, reach 1.1, cooldown -170|
|Void Willow|Epic|Ghost Fern + Moon Lotus|31|155|pull 1.2, windup_damage 2, cooldown -140|
|Sun Spire|Epic|Bloodbriar + Storm Reed|35|155|damage 2, knockback 0.4, cooldown -200|
|Eclipse Root|Mythic|Star Orchid + Void Willow|51|180|reach 0.6, recovery 700, heal_on_kill 1, cooldown -240|
|Worldseed|Mythic|Void Willow + Sun Spire|56|180|windup_damage 3, stagger 180, knockback 0.8, cooldown -180|

## Extending the templates

seed_catalog.gd is the authoritative plant catalog. Append stable species IDs; never reorder existing entries. Use assets/data/plant_template.json as the field template. Set unique stable id/name, tier, two lower-tier parents (or no parents), Wilds threshold, biome, growth duration, color, form, part ID, effects and a clue. The first three species and first six part IDs preserve old saves. New part IDs must append contiguously.

weapon_parts.gd builds new plant material definitions directly from the catalog. Supported effect keys are reach, damage, windup_damage, cooldown, recovery, pull, knockback, stagger and heal_on_kill. Positive cooldown reduces the attack interval; negative cooldown increases it. Keys ending in _step add primary-slot technique scaling. Add combat handling before describing a new effect key to players.

stage.gd:build_lineage_crop builds seed/sprout/young/mature forms from the same data. Forms: cap, reed, willow, vine, fern, flower and lotus. This pass uses reusable generated 3D geometry; it does not introduce Blender-authored plant assets.

progression_tree.gd is a reusable view. It accepts node id, label, parent IDs, position, unlocked, detail and color; emits node_selected; draws dormant nodes and animated enclosing roots. See assets/data/progression_node_template.json. Unlock rules, currency costs and persistence stay in each progression system.

progression_panel.gd adapts plant discoveries, existing Heart flags and character class XP into that view. Extend those adapters as Heart and class progression are built out. Class levels 2–5 now each grant a choice row; see CLASSES_AND_WEAPONS.md.

## Compatibility and verification

Original plant/part IDs and save-slot layout are retained. Old three-species arrays expand with empty entries; existing crops, stock, shared/personal materials and per-character familiarity survive. Legacy discoveries are inferred without retroactive knowledge rewards. Hosted discoveries synchronize; personal seeds/materials remain private. Snapshots are compressed to avoid enlarged unreliable packets.

Tests: tests/seed_progression.gd covers recipes, consumption, failure return, tier gates, all species drops, growth/material mapping, familiarity, save round trips, legacy profiles, actual combat modifiers and tree adapters. tests/seed_coop.gd checks guest-owned breeding, world discoveries, expanded private inventory and portable familiarity. Existing solo/co-op, slot, gardening and HUD checks are also run with isolated saves.

Balance is an initial playable pass and needs extended playtesting. Source backups: docs/change-backups/seeds-20261107-180609.

Build validation: rebuilt the Windows release executable; verified packaged breeding, plant/material registry, progression tree and HUD using the installed console engine with the exported pack. The release executable itself passed its startup check (exit 0). Original executable: Codex workspace work/change-preview/Mystical Garden v0.1-before-seeds.exe. Real saves were not used for testing.

## Circular botanical tree update
Discovered nodes now show transparent portraits rendered from each species' actual mature 3D model. tools/render_seed_portraits.gd regenerates assets/ui/seeds when plant models change; run it with the graphical Godot renderer. Imported images are included in the Windows export.
Circular node hit targets match their visible shape. Hovering reveals the name and a quick effect description in the side panel and tooltip; clicking pins the full entry. Unknown species retain their clue and do not reveal their name or portrait. Shared Heart/class nodes use botanical runes and support hover descriptions.
The reusable node schema now accepts optional icon (Texture2D) and summary fields. The tree emits node_hovered as well as node_selected. Bark-colored winding vines, grain, curling shoots and leaves match the existing HUD palette; unlocked vines grow between discovered nodes and wrap around their circular frames.
Validation: tests/tree_portraits.gd and tests/seed_progression.gd passed. Reviewed rendered blank, partial and fully discovered trees. Original tree/panel scripts are under docs/change-backups/tree-portraits.
