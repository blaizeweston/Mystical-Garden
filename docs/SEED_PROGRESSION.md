> Current expansion: 24 species, seven class levels, 12 choices per class and 104 checkpoint cards. See [current content depth](CONTENT_DEPTH_2026-11-08.md); historical counts below describe earlier milestones.

# Seed lineages and living-root progression

Open **Living Roots** with **O**, or from the Garden menu. It contains Seeds, Heart / Knowledge and Classes tabs. The Heart tab displays existing Garden milestones; the Classes tab now supports the five-class upgrade system described in CLASSES_AND_WEAPONS.md.

## Discovery and sacrifice

- All species can be found as mysterious seeds in the Wilds once their encounter threshold is reached. Rarer tiers have lower weighted chances. Biomes favor particular species; depth unlocks opportunities rather than guaranteeing a drop.
- Bank a mysterious seed, then identify it at the altar. First identification or successful breeding records the host-world discovery and grants 4 knowledge once.
- At the altar, choose two identified parent seeds in Living Roots and sacrifice them. Parent order does not matter. One of each is consumed; a matching pair costs two. Successful recipes return one child seed and become permanent discoveries. A failed combination returns one crafting part and a clue.
- Locked nodes conceal their names. Discovering lower lineages reveals hints. Discovered nodes become enveloped in living roots; connections grow between discovered parents and children.
- Each species grows in any bed. Mature harvest gives its crafting material and character-owned familiarity. Flowering returns two seeds instead of materials. Higher-tier plants take longer to mature; the original three retain their existing growth times.
- New material effects apply in both primary and graft slots. Technique upgrades use the primary material scaling. Long reach, strike damage, wind-up damage, enemy recovery, pull, attack speed, knockback, stagger and kill healing are implemented. Powerful damage or sustain plants often slow attacks. Rarity is not a uniform damage multiplier.

## Initial collection

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
