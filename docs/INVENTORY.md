# Inventory and reusable item system

## Controls

Press **I** to open inventory. In the Garden choose **Personal stash** or **Shared Garden**. During an expedition the grid shows the backpack and a separate safe-pouch slot. The four equipped/prepared weapon components remain visible as read-only squares; change them at the departure gate or a Wilds grafting altar.

Identical items stack to their item's stack limit (normally **99**). Overflow appears in additional square slots. The grid starts with 40 visible spaces and expands for additional stacks; this milestone does not impose a hard backpack weight or slot-cap penalty.

Use type and rarity filters, select Name / Rarity / Type / Quantity, and use **Sort** to toggle ascending or descending order. Filters only change the display. Dragging within a grid reorders its visible slots; sorting clears that manual ordering. Personal/shared material transfers also have a selected-stack button in the Garden.

- Drag a stack outside the inventory window to drop it nearby.
- **Shift + drag** moves just one item.
- Close inventory and press **E** near a dropped stack to recover it.
- Drag a backpack stack into the safe-pouch square to protect it; drag it back into the backpack to remove protection. One pouch slot holds one item type, up to that item's stack limit. Compatible stacks can merge if space remains.
- **P** remains a shortcut to protect one mysterious seed when the pouch is empty.

The entire pouch stack survives defeat and is banked into personal storage. Extraction banks both backpack and pouch. Deliberately abandoning a run discards both, as the confirmation explains. Already banked items stay banked. The inventory does not pause combat.

Mysterious seeds share a concealed stack. Their actual species remain server-side and are preserved through pouch movement, dropping and pickup. Neither inventory snapshots nor ground-item labels reveal those species.

Garden ground drops are saved. Wilds drops are limited to their current encounter and are lost on advancing or ending the run. Dropped items become available for nearby players to pick up; collected Garden drops enter that player's personal stash. Backpack and pouch contents are private in player snapshots.

## Item template

Existing seeds and parts automatically receive stable item definitions in `item_catalog.gd`. The registry provides ID, display name, category, rarity, stack limit, item tags, monster loot tags, icon, description, pouch eligibility and loot weight. Existing numeric seed and weapon-part IDs remain intact underneath this adapter, preserving planting, crafting, grafting and saves.

Copy the example in **docs/item_template.json** into the array in **assets/items/custom_items.json**, give it a unique stable ID, and rebuild the game. A generic new item then supports stacking, filtering, inventory transfer, ground drops, pickup, safe storage and persistence without additional save fields. An optional icon path can point to a texture; otherwise a generic inventory glyph is used. Item-specific use effects and new weapon behaviors still require their appropriate gameplay definitions. For new graftable components, extend the existing weapon-part template; their inventory definitions are generated automatically.

Rarities match seed progression: **Common, Uncommon, Rare, Epic, Mythic**. Unknown seeds retain an Unknown display state. Rarity controls the border, tooltip and filter; loot probability is controlled separately by `loot_weight`.

## Monster loot tags

Each monster's **assets/enemies/catalog.json** entry now includes `loot_tags`: its stable species ID, plant/eldritch identity and behavior role. Runtime adaptation adds `adapted` and applicable `reach`, `armored`, `spores`, `mobile` or `juvenile` tags.

An item's `monster_tags` list specifies tags the monster must possess. All listed tags must match. An empty list does not automatically enter monster loot pools. Matching items compete by their positive `loot_weight` values. For example, `["nightbloom", "adapted"]` permits an item only from an adapted Nightbloom; `["plant"]` permits a general plant-monster material.

The existing encounter trophy cadence remains unchanged: guaranteed every third encounter, otherwise a 35% chance. Eligible items now resolve through tags and weights. This does not introduce individual per-enemy kill drops or rolled affixes.

## Saves and verification

Generic personal item counts and Garden ground stacks save under a new inventory section. Existing resources retain their prior storage and behavior. Before converting an existing save, a `.pre-inventory-v1.bak` recovery copy is retained. Failed Garden item transfers, drops and pickups restore the item counts.

Passed checks include registry extension, bounded stack splitting, loot-tag matching, personal/shared transfers, failed-save rollback, ground persistence and pickup, concealed seed payloads, full-stack pouch recovery and extraction, abandonment loss, generic-item persistence, legacy save migration, filter/sort safety and private snapshots. A graphical test performed real mouse drags into the pouch and outside the window, then checked the resulting inventory and ground stack. The full solo gameplay test and existing crafting, grafting, checkpoints, Heart, seeds, HUD, save-slot and deletion tests passed.

The exported Windows build passed the focused inventory tests. Both existing playable executables (v0.1 and v0.2) were refreshed after backing up their previous versions; v0.2 launched successfully.
