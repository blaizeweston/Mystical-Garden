extends RefCounted
## Session-only inventory and energy. Quotes are valid for one inventory revision.

const Items = preload("res://item_catalog.gd")
const GROWTH_BY_RARITY := {"Common": 2, "Uncommon": 3, "Rare": 4, "Epic": 6, "Mythic": 9}
const KNOWLEDGE_BY_RARITY := {"Common": 1, "Uncommon": 2, "Rare": 3, "Epic": 5, "Mythic": 8}
const ENERGY_PER_CELL := 1.0
const CELLS_PER_SURCHARGE := 8
const TIER_DISCOUNT := 0.10

var items := {}
var inventory := {}
var reserved := {}
var energy := 0
var inventory_revision := 0
# Revision of the saved Garden from which this inventory preview was taken.
var garden_revision := 0

func _init() -> void:
	for id: String in Items.all():
		var item := Items.get_item(id)
		if item.category in ["plant_part", "monster_part"]:
			items[id] = item
	# A few weapon reservations in the development inventory stay visibly protected.
	var protected := {"plant_part": 0, "monster_part": 0}
	for id: String in items:
		var category: String = items[id].category
		if protected[category] < 2:
			reserved[id] = 2
			protected[category] += 1
	replenish()

func replenish() -> void:
	for id: String in items:
		inventory[id] = int(items[id].stack_limit)
	inventory_revision += 1

func available(id: String) -> int:
	return maxi(0, int(inventory.get(id, 0)) - int(reserved.get(id, 0)))

func unit_energy(id: String) -> int:
	if not items.has(id):
		return 0
	return int(GROWTH_BY_RARITY.get(items[id].rarity, 2))

func quote(selection: Dictionary) -> Dictionary:
	if selection.is_empty():
		return {}
	var total := 0
	var knowledge := 0
	for id in selection:
		var count = selection[id]
		if not id is String or not items.has(id) or not count is int or count < 1 or count > available(id):
			return {}
		total += count * unit_energy(id)
		knowledge += count * int(KNOWLEDGE_BY_RARITY[items[id].rarity])
	return {"revision": inventory_revision, "garden_revision": garden_revision, "items": selection.duplicate(), "energy": total, "knowledge": knowledge}

func offer(review: Dictionary) -> bool:
	if review.is_empty() or review.get("revision", -1) != inventory_revision or not review.get("items") is Dictionary:
		return false
	var current := quote(review.items)
	if current.is_empty() or current != review:
		return false
	for id: String in current.items:
		inventory[id] -= current.items[id]
	energy += int(current.energy)
	inventory_revision += 1
	return true

func expansion_cost(proposal: Dictionary, used_cells: int, tier: int) -> int:
	var base: float = proposal.cells.size() * ENERGY_PER_CELL
	var surcharge := floori(float(used_cells) / CELLS_PER_SURCHARGE)
	return maxi(1, ceili((base + surcharge) * (1.0 - TIER_DISCOUNT * clampi(tier - 1, 0, 2))))
