extends RefCounted
## Host-owned, floor-local specimen. Its hidden species is fixed at generation.
## Claims survive reconstruction and publication and use character identities.
const Seeds = preload("res://seed_catalog.gd")
const HARVEST_REACH := 1.55

var _floor_key := ""
var _specimen := {}
var _collected := {}

func clear() -> void:
	_floor_key = ""
	_specimen = {}
	_collected = {}

func begin(key: String, generate: Callable) -> void:
	if key == _floor_key:
		return
	clear()
	_floor_key = key
	var result: Dictionary = generate.call()
	if not result.is_empty():
		_specimen = {"identity":key, "position":result.position, "species":result.species}

func view(character: String) -> Dictionary:
	if character.is_empty() or _specimen.is_empty():
		return {}
	var result := _specimen.duplicate()
	result.claimed = _collected.has(character)
	return result

static func within_reach(specimen: Dictionary, position: Vector3) -> bool:
	return not specimen.is_empty() and not specimen.claimed and position.is_finite() \
		and position.distance_to(specimen.position) <= HARVEST_REACH

func collect(identity: String, character: String, position: Vector3, clear_line: Callable, admit: Callable) -> bool:
	var specimen := view(character)
	if identity != _floor_key or not within_reach(specimen, position):
		return false
	if not clear_line.call(position, specimen.position) or not admit.call(specimen.species):
		return false
	_collected[character] = true
	return true

func savepoint() -> Dictionary:
	return {"floor":_floor_key, "specimen":_specimen.duplicate(), "collected":_collected.duplicate()}

func restore(state: Dictionary) -> void:
	_floor_key = state.floor
	_specimen = state.specimen.duplicate()
	_collected = state.collected.duplicate()

## Missing starters override the ordinary roll only on the first two encounters.
static func starter(floor_number: int, available: Callable) -> int:
	if floor_number != 1 and floor_number != 2:
		return -1
	var thorn := Seeds.index_of("thorn_bloom")
	var moss := Seeds.index_of("lantern_moss")
	for species: int in ([thorn, moss] if floor_number == 1 else [moss, thorn]):
		if not available.call(species):
			return species
	return -1
