extends RefCounted
const REACH := 1
const BARK := 2
const SPORES := 4
const MOBILITY := 8
const JUVENILE := 16
static var definitions: Array = []

static func all() -> Array:
	if definitions.is_empty():
		definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/catalog.json"))
	return definitions

static func get_kind(kind: int) -> Dictionary:
	return all()[clampi(kind, 0, all().size() - 1)]

static func choose(site: int, encounter: int, slot: int, seed_value: int) -> int:
	var pool: Array[int] = []
	for i in all().size():
		var entry := get_kind(i)
		if not entry.get("boss",false) and in_biome(entry, site) and encounter >= int(entry.unlock) and ranged(i) == (slot % 3 == 1):
			pool.append(i)
	if pool.is_empty():
		return 1 if slot % 3 == 1 else 0
	return pool[posmod(slot + seed_value % 101 + encounter, pool.size())]

# Encounter bands advance only after whole groups of seven.
@warning_ignore_start("integer_division")
static func tier(encounter: int, cycle: int) -> int:
	return clampi((encounter - 1) / 7 + cycle, 0, 2)

@warning_ignore_restore("integer_division")
static func mutations(kind: int, growth: int, ranged_pressure: int, burst_pressure: int, choke_pressure: int, encounter: int, stamp: int) -> int:
	if encounter < 3:
		return 0
	var mask := 0
	if ranged_pressure >= 3 and posmod(stamp + kind, 3) != 0:
		mask |= REACH
	if burst_pressure >= 3 and encounter >= 4 and posmod(stamp + kind, 3) != 1:
		mask |= BARK
	if choke_pressure >= 3 and encounter >= 5 and posmod(stamp + kind, 3) != 2:
		mask |= MOBILITY
	if growth > 0 and posmod(stamp + kind, 4 if growth == 1 else 2) == 0:
		mask |= int(get_kind(kind).affinity)
	return mask

static func encode(kind: int, mask: int, growth: int) -> int:
	return (kind & 65535) | ((mask & 31) << 16) | ((growth & 127) << 24)

static func decode(value: int) -> Dictionary:
	return {"kind": value & 65535, "mask": (value >> 16) & 31, "tier": (value >> 24) & 127}

static func radius(kind: int, mask: int = 0) -> float:
	var radius_value := float(get_kind(kind).radius)
	if mask & REACH:
		radius_value += 0.35
	if mask & SPORES:
		radius_value += 0.35
	return radius_value

static func ranged(kind: int) -> bool:
	return get_kind(kind).role in ["volley", "chant", "snare", "artillery", "brood", "shepherd", "lure"]


static func in_biome(entry: Dictionary, site: int) -> bool:
	for biome in entry.biomes:
		if int(biome) == site:
			return true
	return false

static func is_support(kind: int) -> bool:
	return bool(get_kind(kind).get("support",false)) or str(get_kind(kind).role)=="chant"
