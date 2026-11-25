extends RefCounted
## Derived cultivation coverage. The construction inventory and Heart own the saved facts.
const Catalog = preload("res://garden_structure_catalog.gd")
const RADIUS_M: float = Catalog.DEFINITIONS.sprinkler.radius_m
var radius_base_sprinkler := RADIUS_M
var supplied := false
var bed_centers := {}
var watered_slots := {}
var effects := {} # crop slot -> effect strengths currently in range
var research: Array = []
var _inventory := {}
var _revision := -1

func set_sprinkler_radius(value: float, inventory: Dictionary, unlocked: Array) -> void:
	radius_base_sprinkler = value
	_revision = -1
	resolve(inventory,unlocked)

func radius(kind: String) -> float:
	var definition: Dictionary = Catalog.DEFINITIONS[kind]
	if research.has(kind + "_coverage"): return definition.extended_m
	return radius_base_sprinkler if kind == "sprinkler" else definition.radius_m

func strength(kind: String) -> float:
	var definition: Dictionary = Catalog.DEFINITIONS[kind]
	return definition.improved if research.has(kind + "_effectiveness") else definition.base

func resolve(inventory: Dictionary, unlocked: Array = []) -> void:
	if is_same(_inventory, inventory) and _revision == inventory.revision and research == unlocked: return
	_inventory = inventory
	_revision = inventory.revision
	research = unlocked.duplicate()
	supplied = false
	bed_centers.clear()
	watered_slots.clear()
	effects.clear()
	var emitters: Array[Dictionary] = []
	for entry: Dictionary in inventory.instances.values():
		if not entry.placed: continue
		match entry.kind:
			"intake": supplied = true
			"bed": bed_centers[entry.slot] = entry.at
			_:
				if Catalog.DEFINITIONS[entry.kind].has("effect"): emitters.append(entry)
	for entry in emitters:
		var kind: String = entry.kind
		if kind == "sprinkler" and not supplied: continue
		var value := strength(kind)
		if kind == "bud_sanctuary":
			if entry.care_mode == "disabled": continue
			if entry.care_mode == "standard": value = 1
		var effect: String = Catalog.DEFINITIONS[kind].effect
		for slot in beds_in_range(entry.at,kind):
			if not effects.has(slot): effects[slot] = {}
			effects[slot][effect] = maxf(effects[slot].get(effect,0.0),value)
			if kind == "sprinkler": watered_slots[slot] = true

func beds_in_range(center: Vector2, kind := "sprinkler") -> Array[int]:
	var slots: Array[int] = []
	var distance_sq := pow(radius(kind),2)
	for slot: int in bed_centers:
		if center.distance_squared_to(bed_centers[slot]) <= distance_sq: slots.append(slot)
	slots.sort()
	return slots
