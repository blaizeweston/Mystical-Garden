extends RefCounted

const Seeds = preload("res://seed_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Items = preload("res://item_catalog.gd")

# CR01 metadata is separate from the live combat tags and species signatures.
# These skill IDs identify the approved affinity families for the future resolver.
const CORE_SKILL_BY_PRIMARY := {
	"frost": "rime_bloom",
	"fire": "ember_wake",
	"water": "dewfall",
	"vital": "vital_bloom",
	"thorn": "thorn_line",
	"wood": "ironbark",
	"storm": "chain_spark",
	"spirit": "phantom_step",
	"void": "gravity_well",
}
const SUPPORTING_ONLY := [
	"piercing", "volatile", "spore", "brace", "mark", "echo", "grave", "tide",
	"hush", "dream", "link", "force", "lunar", "radiant", "blood",
]
const BY_SPECIES := {
	"thorn_bloom": {"primary_affinity": "thorn", "supporting_affinities": ["piercing"]},
	"lantern_moss": {"primary_affinity": "vital", "supporting_affinities": ["radiant"]},
	"veilcap": {"primary_affinity": "thorn", "supporting_affinities": ["spore"]},
	"ember_fern": {"primary_affinity": "fire", "supporting_affinities": ["volatile"]},
	"cinder_vine": {"primary_affinity": "fire", "supporting_affinities": ["piercing"]},
	"dewcap": {"primary_affinity": "water", "supporting_affinities": ["vital"]},
	"bloodbriar": {"primary_affinity": "vital", "supporting_affinities": ["blood"]},
	"ghost_fern": {"primary_affinity": "spirit", "supporting_affinities": ["hush"]},
	"storm_reed": {"primary_affinity": "storm", "supporting_affinities": ["force"]},
	"moon_lotus": {"primary_affinity": "thorn", "supporting_affinities": ["lunar"]},
	"star_orchid": {"primary_affinity": "thorn", "supporting_affinities": ["piercing", "radiant"]},
	"void_willow": {"primary_affinity": "void", "supporting_affinities": ["force"]},
	"sun_spire": {"primary_affinity": "fire", "supporting_affinities": ["radiant"]},
	"eclipse_root": {"primary_affinity": "void", "supporting_affinities": ["blood"]},
	"worldseed": {"primary_affinity": "wood", "supporting_affinities": ["force", "vital"]},
	"frostbell": {"primary_affinity": "frost", "supporting_affinities": ["water"]},
	"ironroot": {"primary_affinity": "wood", "supporting_affinities": ["brace"]},
	"whispervine": {"primary_affinity": "spirit", "supporting_affinities": ["mark"]},
	"mirror_mint": {"primary_affinity": "spirit", "supporting_affinities": ["echo"]},
	"gravemoss": {"primary_affinity": "vital", "supporting_affinities": ["blood", "grave"]},
	"tide_lily": {"primary_affinity": "water", "supporting_affinities": ["tide"]},
	"hush_orchid": {"primary_affinity": "void", "supporting_affinities": ["hush"]},
	"dream_poppy": {"primary_affinity": "spirit", "supporting_affinities": ["dream"]},
	"crownroot": {"primary_affinity": "thorn", "supporting_affinities": ["link", "vital"]},
}


static func resolve_affinities(entry: Variant) -> Dictionary:
	if not entry is Dictionary or entry.size() != 2:
		return {}
	var primary = entry.get("primary_affinity")
	var authored_supports = entry.get("supporting_affinities")
	if not primary is String or not CORE_SKILL_BY_PRIMARY.has(primary) or not authored_supports is Array:
		return {}
	var supports: Array[String] = []
	for affinity in authored_supports:
		if not affinity is String or affinity == primary or supports.has(affinity):
			return {}
		if not CORE_SKILL_BY_PRIMARY.has(affinity) and not SUPPORTING_ONLY.has(affinity):
			return {}
		supports.append(affinity)
	supports.sort()
	return {
		"primary_affinity": primary,
		"supporting_affinities": supports,
		"affinity_core_skill_id": CORE_SKILL_BY_PRIMARY[primary],
	}


static func for_part(part: int) -> Dictionary:
	if not Parts.is_plant(part):
		return {}
	var species := Parts.plant_source(part)
	if species < 0 or species >= Seeds.DEFINITIONS.size():
		return {}
	var seed: Dictionary = Seeds.DEFINITIONS[species]
	# Use the cultivation registry's explicit pair, including the Heartwood Barb exception.
	var ordinary: int = seed.part
	var refined := Parts.rare_part(species)
	var item_id: String = Parts.DEFINITIONS[part].item_id
	if ordinary == refined or part not in [ordinary, refined] or item_id.is_empty():
		return {}
	var result := resolve_affinities(BY_SPECIES.get(seed.id))
	if result.is_empty():
		return {}
	result.species_id = seed.id
	result.item_id = item_id
	result.quality = "ordinary" if part == ordinary else "refined"
	return result


static func errors() -> Array[String]:
	var result: Array[String] = []
	for species_id in BY_SPECIES:
		if Seeds.index_of(species_id) < 0:
			result.append("Unknown plant affinity species: " + species_id)
	for species in Seeds.DEFINITIONS.size():
		var seed: Dictionary = Seeds.DEFINITIONS[species]
		var ordinary := for_part(seed.part)
		var refined := for_part(Parts.rare_part(species))
		if ordinary.get("species_id") != seed.id or ordinary.get("quality") != "ordinary":
			result.append("Invalid ordinary plant affinity metadata: " + seed.id)
		if refined.get("species_id") != seed.id or refined.get("quality") != "refined":
			result.append("Invalid refined plant affinity metadata: " + seed.id)
	var resolved_items := {}
	for part in range(1, Parts.DEFINITIONS.size()):
		if not Parts.is_plant(part):
			continue
		var metadata := for_part(part)
		if metadata.is_empty():
			result.append("Plant component has no valid affinity metadata: " + Parts.DEFINITIONS[part].id)
			continue
		var item := Items.get_item(metadata.item_id)
		if item.get("category") != "plant_part" or item.get("legacy_part") != part or resolved_items.has(metadata.item_id):
			result.append("Invalid plant affinity inventory identity: " + metadata.item_id)
		resolved_items[metadata.item_id] = part
	for item in Items.all().values():
		if item.category == "plant_part" and not resolved_items.has(item.id):
			result.append("Plant item has no explicit affinity metadata: " + item.id)
	return result
