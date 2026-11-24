extends RefCounted
## Natural specimen balance. Each eligible floor has one independent opportunity.

const Seeds = preload("res://seed_catalog.gd")
const SPAWN_CHANCE := 0.40
const PREFERRED_BIOME_WEIGHT := 1.5
const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Mythic"]
# Minimum global encounter and relative rarity weights (absent pools are skipped).
const DEPTH_BANDS := [
	[1,  [100, 0, 0, 0, 0]],
	[6,  [65, 35, 0, 0, 0]],
	[16, [45, 35, 20, 0, 0]],
	[31, [25, 30, 35, 10, 0]],
	[51, [15, 25, 35, 20, 5]],
	[60, [10, 20, 35, 25, 10]],
]

static func floor_random(floor_key: Vector3i, global_floor: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	var identity := "wild_flora/v1/%d/%d/%d/%d" % [floor_key.x, floor_key.y, floor_key.z, global_floor]
	random.seed = identity.sha256_buffer().decode_u32(0)
	return random

static func weights_at_depth(global_floor: int) -> PackedFloat32Array:
	for index in range(DEPTH_BANDS.size() - 1, -1, -1):
		if global_floor >= DEPTH_BANDS[index][0]:
			return PackedFloat32Array(DEPTH_BANDS[index][1])
	return PackedFloat32Array()

static func roll_species(global_floor: int, biome: int, random: RandomNumberGenerator) -> int:
	var weights := weights_at_depth(global_floor)
	if weights.is_empty():
		return -1
	var pools := [[], [], [], [], []]
	for species in Seeds.DEFINITIONS.size():
		var definition: Dictionary = Seeds.DEFINITIONS[species]
		var rarity := RARITIES.find(definition.rarity)
		if rarity >= 0 and global_floor >= int(definition.wild_min):
			pools[rarity].append(species)
	for rarity in pools.size():
		if pools[rarity].is_empty():
			weights[rarity] = 0.0
	if weights.count(0.0) == weights.size():
		return -1
	var pool: Array = pools[random.rand_weighted(weights)]
	var species_weights := PackedFloat32Array()
	for species: int in pool:
		species_weights.append(PREFERRED_BIOME_WEIGHT if Seeds.DEFINITIONS[species].biome == biome else 1.0)
	return pool[random.rand_weighted(species_weights)]
