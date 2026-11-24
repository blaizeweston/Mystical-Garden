extends RefCounted
## A derived index of live bed centers and watering sources. Nothing here is saved.
const Catalog = preload("res://garden_structure_catalog.gd")
const RADIUS_M: float = Catalog.DEFINITIONS.sprinkler.radius_m

var supplied := false
var bed_centers := {} # crop slot -> horizontal world position
var watered_slots := {}
var _inventory := {}
var _revision := -1

func resolve(inventory: Dictionary) -> void:
	if is_same(_inventory,inventory) and _revision == inventory.revision: return
	_inventory = inventory
	_revision = inventory.revision
	supplied = false
	bed_centers.clear()
	watered_slots.clear()
	var emitters: Array[Vector2] = []
	for entry: Dictionary in inventory.instances.values():
		if not entry.placed: continue
		match entry.kind:
			"intake": supplied = true
			"sprinkler": emitters.append(entry.at)
			"bed": bed_centers[entry.slot] = entry.at
	if supplied:
		for center in emitters:
			for slot in beds_in_range(center): watered_slots[slot] = true

func beds_in_range(center: Vector2) -> Array[int]:
	var slots: Array[int] = []
	for slot: int in bed_centers:
		if center.distance_squared_to(bed_centers[slot]) <= RADIUS_M * RADIUS_M: slots.append(slot)
	slots.sort()
	return slots
