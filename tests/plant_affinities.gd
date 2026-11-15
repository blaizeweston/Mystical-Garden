extends SceneTree

const Affinities = preload("res://plant_affinities.gd")
const Items = preload("res://item_catalog.gd")
const Parts = preload("res://weapon_parts.gd")
const Seeds = preload("res://seed_catalog.gd")

# Approved CR01 species, primary, supports and stable inventory IDs.
const APPROVED_PAIRS := [
	["thorn_bloom", "thorn", ["piercing"],
		"part_1", "part_5"],
	["lantern_moss", "vital", ["radiant"],
		"part_2", "plant_part_rare_lantern_moss"],
	["veilcap", "thorn", ["spore"],
		"part_3", "plant_part_rare_veilcap"],
	["ember_fern", "fire", ["volatile"],
		"part_6", "plant_part_rare_ember_fern"],
	["cinder_vine", "fire", ["piercing"],
		"part_7", "plant_part_rare_cinder_vine"],
	["dewcap", "water", ["vital"],
		"part_8", "plant_part_rare_dewcap"],
	["bloodbriar", "vital", ["blood"],
		"part_9", "plant_part_rare_bloodbriar"],
	["ghost_fern", "spirit", ["hush"],
		"part_10", "plant_part_rare_ghost_fern"],
	["storm_reed", "storm", ["force"],
		"part_11", "plant_part_rare_storm_reed"],
	["moon_lotus", "thorn", ["lunar"],
		"part_12", "plant_part_rare_moon_lotus"],
	["star_orchid", "thorn", ["piercing", "radiant"],
		"part_13", "plant_part_rare_star_orchid"],
	["void_willow", "void", ["force"],
		"part_14", "plant_part_rare_void_willow"],
	["sun_spire", "fire", ["radiant"],
		"part_15", "plant_part_rare_sun_spire"],
	["eclipse_root", "void", ["blood"],
		"part_16", "plant_part_rare_eclipse_root"],
	["worldseed", "wood", ["force", "vital"],
		"part_17", "plant_part_rare_worldseed"],
	["frostbell", "frost", ["water"],
		"plant_part_plant_frostbell", "plant_part_rare_frostbell"],
	["ironroot", "wood", ["brace"],
		"plant_part_plant_ironroot", "plant_part_rare_ironroot"],
	["whispervine", "spirit", ["mark"],
		"plant_part_plant_whispervine", "plant_part_rare_whispervine"],
	["mirror_mint", "spirit", ["echo"],
		"plant_part_plant_mirror_mint", "plant_part_rare_mirror_mint"],
	["gravemoss", "vital", ["blood", "grave"],
		"plant_part_plant_gravemoss", "plant_part_rare_gravemoss"],
	["tide_lily", "water", ["tide"],
		"plant_part_plant_tide_lily", "plant_part_rare_tide_lily"],
	["hush_orchid", "void", ["hush"],
		"plant_part_plant_hush_orchid", "plant_part_rare_hush_orchid"],
	["dream_poppy", "spirit", ["dream"],
		"plant_part_plant_dream_poppy", "plant_part_rare_dream_poppy"],
	["crownroot", "thorn", ["link", "vital"],
		"plant_part_plant_crownroot", "plant_part_rare_crownroot"],
]
const APPROVED_SKILLS := {
	"frost": "rime_bloom", "fire": "ember_wake", "water": "dewfall",
	"vital": "vital_bloom", "thorn": "thorn_line", "wood": "ironbark",
	"storm": "chain_spark", "spirit": "phantom_step", "void": "gravity_well",
}
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL plant affinities: ", message)


func _initialize() -> void:
	check(Affinities.errors().is_empty(), "affinity catalog covers the live plant and item registries")
	check(Seeds.DEFINITIONS.size() == APPROVED_PAIRS.size(), "every live species is in the approved map")
	var plant_items := 0
	for item in Items.all().values():
		if item.category == "plant_part":
			plant_items += 1
	check(plant_items == 2 * APPROVED_PAIRS.size(), "all equippable plant materials have expected pairs")
	for row in APPROVED_PAIRS:
		check_pair(row)
	check_order_independence()
	check_invalid_metadata()
	print("PASS: " if failures == 0 else "FAIL: ", "CR01 plant affinities: ",
		APPROVED_PAIRS.size(), " species, ", plant_items, " materials, ", failures, " failures")
	quit(1 if failures else 0)


func check_pair(row: Array) -> void:
	var species_id: String = row[0]
	var expected_supports: Array = row[2].duplicate()
	expected_supports.sort()
	var expected_identity := {
		"species_id": species_id,
		"primary_affinity": row[1],
		"supporting_affinities": expected_supports,
		"affinity_core_skill_id": APPROVED_SKILLS[row[1]],
	}
	for quality_and_item in [["ordinary", row[3]], ["refined", row[4]]]:
		var item_id: String = quality_and_item[1]
		var item := Items.get_item(item_id)
		var expected := expected_identity.duplicate()
		expected.item_id = item_id
		expected.quality = quality_and_item[0]
		var resolved := Affinities.for_part(int(item.get("legacy_part", 0)))
		check(resolved == expected, species_id + " / " + item_id + " matches its approved identity and quality")


func check_order_independence() -> void:
	var forward := Affinities.resolve_affinities({
		"primary_affinity": "wood", "supporting_affinities": ["force", "vital"],
	})
	var reverse := Affinities.resolve_affinities({
		"supporting_affinities": ["vital", "force"], "primary_affinity": "wood",
	})
	check(not forward.is_empty() and forward == reverse, "support order cannot choose behavior")
	var material: Dictionary = Parts.DEFINITIONS[Parts.HEARTWOOD]
	var tags: Array = material.tags
	var original := Affinities.for_part(Parts.HEARTWOOD)
	var reversed := tags.duplicate()
	reversed.reverse()
	material.tags = reversed
	var reordered := Affinities.for_part(Parts.HEARTWOOD)
	material.tags = tags
	check(not original.is_empty() and original == reordered, "raw Heartwood Barb tag order cannot choose behavior")
	var returned_supports: Array = original.get("supporting_affinities", [])
	returned_supports.clear()
	check(reordered == Affinities.for_part(Parts.HEARTWOOD), "inspection does not expose shared authored data")
	var ordinary := Items.get_item("part_17")
	var refined := Items.get_item("plant_part_rare_worldseed")
	check(ordinary.rarity == refined.rarity, "Worldseed exercises explicit quality at identical rarity")


func check_invalid_metadata() -> void:
	check(Affinities.for_part(0).is_empty(), "empty loadout slot has no invented affinity")
	check(Affinities.for_part(-1).is_empty(), "invalid component has no affinity")
	check(Affinities.for_part(Parts.HOOK).is_empty(), "monster graft has no plant affinity")
	var invalid := [
		null,
		{},
		{"supporting_affinities": ["thorn", "piercing"]},
		{"primary_affinity": "thorn"},
		{"primary_affinity": ["thorn", "wood"], "supporting_affinities": ["piercing"]},
		{"primary_affinity": "piercing", "supporting_affinities": ["thorn"]},
		{"primary_affinity": "unknown", "supporting_affinities": ["piercing"]},
		{"primary_affinity": "thorn", "supporting_affinities": "piercing"},
		{"primary_affinity": "thorn", "supporting_affinities": ["thorn"]},
		{"primary_affinity": "thorn", "supporting_affinities": ["piercing", "piercing"]},
		{"primary_affinity": "thorn", "supporting_affinities": ["unknown"]},
		{"primary_affinity": "thorn", "supporting_affinities": [7]},
	]
	for retired_tag in ["luminous", "arcane", "control", "ancient"]:
		invalid.append({"primary_affinity": "wood", "supporting_affinities": [retired_tag]})
		invalid.append({"primary_affinity": retired_tag, "supporting_affinities": ["force"]})
	for entry in invalid:
		check(Affinities.resolve_affinities(entry).is_empty(), "rejects invalid new-format metadata " + str(entry))
