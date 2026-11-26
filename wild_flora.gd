extends RefCounted
## Host-owned botanical sites for the current expedition floor. The specimen and
## Returning Root share a floor identity. The specimen has one party-wide
## harvest; root deposits retain personal allowances by stable character.
const Seeds = preload("res://seed_catalog.gd")
const HARVEST_REACH := 1.55

var _floor_key := ""
var _specimen := {}
var _collected := {}
var _root_position := Vector3.INF
var _root_generated := false
var _deposits := {}

const BONUS_SEED := 0.25
const REFINED_MATERIAL := 0.15
const AWARENESS_RANGE := 6.0
const ROOT_CHANCE := 0.25
const TENDRILS_CHANCE := 0.40

## Stable, separate draws. Admission retries never advance another gameplay RNG.
static func bonus_roll(identity: String, character: String, reward: String) -> float:
	return JSON.stringify([identity, character, reward]).sha256_text().left(8).hex_to_int() / 4294967296.0

func generate_root(key: String, generate: Callable) -> void:
	if key == _floor_key and not _root_generated:
		_root_position = generate.call(_specimen.get("position", Vector3.INF))
		_root_generated = true

func root_view(character: String, capacity: int) -> Dictionary:
	if character.is_empty() or not _root_position.is_finite() or capacity <= 0: return {}
	var used := int(_deposits.get(character, 0))
	return {"identity":_floor_key, "position":_root_position, "used":used, "remaining":maxi(0,capacity-used)}

func record_deposit(character: String) -> void:
	_deposits[character] = int(_deposits.get(character,0)) + 1

static func aware(specimen: Dictionary, observer: Vector3, clear_line: Callable) -> bool:
	return specimen.get("awareness",false) and not specimen.get("claimed",true) and observer.is_finite() \
		and observer.distance_squared_to(specimen.position) <= AWARENESS_RANGE * AWARENESS_RANGE and clear_line.call(observer,specimen.position)

func clear() -> void:
	_floor_key = ""
	_specimen = {}
	_collected = {}
	_root_position = Vector3.INF
	_root_generated = false
	_deposits = {}

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
	result.claimed = not _collected.is_empty()
	return result

static func harvest_description(research: Array, species: int) -> String:
	var benefits := PackedStringArray(["One harvest per party", "1 %s Seed" % Seeds.NAMES[species]])
	if "careful_gathering" in research: benefits.append("25% extra seed")
	if "wild_harvest" in research: benefits.append("1 ordinary part")
	if "refined_gathering" in research: benefits.append("15% refined part")
	return " · ".join(benefits)

static func within_reach(specimen: Dictionary, position: Vector3, clear_line: Callable) -> bool:
	return not specimen.is_empty() and not specimen.claimed and position.is_finite() \
		and position.distance_to(specimen.position) <= HARVEST_REACH and clear_line.call(position, specimen.position)

func collect(identity: String, character: String, position: Vector3, clear_line: Callable, admit: Callable) -> bool:
	var specimen := view(character)
	if identity != _floor_key or not within_reach(specimen, position, clear_line):
		return false
	if not admit.call(specimen.species):
		return false
	_collected[character] = true
	return true

func savepoint() -> Dictionary:
	return {"floor":_floor_key, "specimen":_specimen.duplicate(), "collected":_collected.duplicate(),
		"root_position":_root_position, "root_generated":_root_generated, "deposits":_deposits.duplicate()}

func restore(state: Dictionary) -> void:
	_floor_key = state.floor
	_specimen = state.specimen.duplicate()
	_collected = state.collected.duplicate()
	_root_position = state.root_position
	_root_generated = state.root_generated
	_deposits = state.deposits.duplicate()

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
