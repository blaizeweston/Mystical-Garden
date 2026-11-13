# Inventory and multiplayer material availability — 2026-11-10

## Findings and changes

Harvesting deposits plant components in shared Garden storage. The old inventory opened on Personal stash, hiding those materials behind a storage selection. The Garden inventory now defaults to All Garden storage, with separate personal/shared filters still available. Entries retain their actual storage bucket for transfers and dragging; tooltips and item details identify the bucket. Wilds inventory remains carried equipment/materials and safe pouch only.

The grid now uses 40-slot pages with previous/next controls and a stack count. Sorting and item/rarity filters apply to the complete collection before paging. Reordering an item into a blank slot in the combined view retains its ownership. Changing pages selects an item from that page rather than an invisible first-page item. Transfer results and reservation errors are visible inside the inventory window.

Seed stacks were explicitly blocked from shared storage. Identified, unidentified and ancient mystery seed stacks can now move into Shared Garden and be withdrawn into another player's stash. Unidentified seed species remain concealed and retain their per-seed identities. Shared seeds use a dedicated reserve in the world's existing reserve storage, not another player's personal stash. Ancient seeds use the corresponding shared extra-item store. Save/rollback paths preserve the transfer. Shared seeds must be withdrawn before personal planting/altar use.

The crafting filter previously subtracted only the current player's other weapon slots. `loadout_materials.gd` now calculates party availability: other confirmed Garden plans draw from their own personal materials first, then claim the required shared remainder. Each player's published stored_parts snapshot therefore excludes shared units assigned to other players while preserving their private materials. Authoritative slot changes check the same budget, including simultaneous requests. Clearing slots, changing class, departing and disconnecting release the corresponding claims. Opening the gate reconciles a restored plan before claiming it. Claims are temporary session state; no materials are consumed until departure. Existing atomic party-departure checks remain the final guard if inventory changes through another mechanic.

Inventory withdrawals/drops cannot remove reserved components; the message asks the player to clear the relevant gate slots. Failed-transfer restoration can bypass presentation reservations while still enforcing actual quantities, so a save failure cannot strand transferred items.

## Plant component icons

All 48 normal/rare plant components now use their own SVG icons under `assets/ui/parts`, rather than species portraits. Silhouettes depict harvested roots, barbs, fronds, caps, petals, pollen and other components, with distinct rare material treatment. Seed portraits remain unchanged. Inventory, equipment, altar lists and weapon preparation consume the shared item catalog; the weapon dropdown also displays the component icon.

Rebuild the icon set with `tools/make_plant_part_icons.py`, using `tools/plant_part_icons.json`. The generated assets are original code-authored vector specimens, not newly sculpted plant models.

## Checks

The new inventory_party suite covers merged visibility, 40-slot paging, filters and reordering without ownership changes, all 48 independent icon resources, seed-stack sharing/withdrawal (including hidden identities), persistence, cross-player claims, private materials, protected withdrawals and disconnect release.

The existing real host/guest crafting suite now additionally checks both directions of shared-part reservation, release/reselection, live guest dropdown filtering, guest seed sharing and host withdrawal reflected in the guest inventory. Existing inventory rollback/pouch/privacy, gate crafting, classes and party-readiness checks passed during implementation.

Tests and previews use isolated save directories. Only the highest numbered EXE is replaced, with an automatic backup. Final source/package results are appended below.
Release verification: all 80 source suites passed with stable inputs and complete release evidence. All 47 selected packaged suites plus startup/catalog checks and the four-player network smoke passed. Installed only Mystical Garden v0.5.2.0.exe, with automatic backup. Installed SHA256 matches verified package: 9C7F3C8D8F45D5E4AAE9CE332076EDC815A21EC4A74B70C90717735822425FDC. Source fingerprint: CF6F69DE2CF24FBF3244D2927AF735A027AEE03311916A977ADF141C17191C0E.
