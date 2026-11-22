extends SceneTree
## Checks the enemy framework definitions: they load cleanly, cover every legacy capability,
## inherit catalog values, compile deterministically and reject broken data.

const Attacks = preload("res://enemy_attack.gd")
const Catalog = preload("res://enemy_catalog.gd")
const Elite = preload("res://elite_enemy.gd")
const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Loader = preload("res://mob_sim/definitions/definition_loader.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Tables = preload("res://mob_sim/definitions/definition_tables.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const Variants = preload("res://enemy_variants.gd")

## Legacy tactic names for variants and responses, mapped to unlock evidence names.
const LEGACY_EVIDENCE := {"ranged": "ranged", "late": "late", "choke": "choke", "burst": "burst", "kite": "kite",
	Tactics.CAST_DENIAL: "cast_denial", Tactics.ROUTE_DENIAL: "route_denial", Tactics.SHELTER_BREAK: "shelter_break",
	Tactics.AREA_PRESSURE: "area_pressure"}
const COMPILE_BUDGET_MS := 100

var failures := 0
var checks := 0


func _initialize() -> void:
	var definitions := Loader.shared()
	check(definitions.ok(), "the project's enemy definitions load without errors")
	for error in definitions.errors:
		print("  ", error)
	if not definitions.ok():
		finish()
		return
	var tables = Tables.shared()
	check_catalog_coverage(definitions, tables)
	check_legacy_coverage(definitions)
	check_catalog_inheritance(tables)
	check_kits(definitions, tables)
	check_mutations(tables)
	check_movement(definitions, tables)
	check_compile(definitions)
	check_rejections()
	finish()


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)


func finish() -> void:
	print("PASSED: %d checks, %d failures" % [checks, failures] if failures == 0 else "FAILED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func ability_for_legacy(definitions, legacy: String) -> Object:
	for ability in definitions.abilities:
		if ability.legacy == legacy:
			return ability
	return null


func check_catalog_coverage(definitions, tables) -> void:
	check(definitions.species.size() == Catalog.all().size(), "every catalog species has a framework entry")
	var missing := PackedStringArray()
	for kind in tables.species_count:
		if not tables.has_ability(tables.row(kind, Enums.Slot.BASIC)):
			missing.append(str(Catalog.get_kind(kind).id))
	check(missing.is_empty(), "every species has a basic ability %s" % missing)


## Each legacy variant, learned response and elite signature must have a framework ability.
func check_legacy_coverage(definitions) -> void:
	var gaps := PackedStringArray()
	var wrong_unlock := PackedStringArray()
	var wrong_species := PackedStringArray()
	for kind in Variants.PROFILES:
		var profile: Dictionary = Variants.PROFILES[kind]
		_compare(definitions, kind, profile.id, int(profile.floor), profile.tactic, Enums.Slot.SIGNATURE, gaps, wrong_unlock, wrong_species)
	for kind in Tactics.REGULAR_RESPONSES:
		var response: Dictionary = Tactics.REGULAR_RESPONSES[kind]
		_compare(definitions, kind, response.id, int(response.floor), response.tactic, Enums.Slot.COUNTER, gaps, wrong_unlock, wrong_species)
	for id in Tactics.RESPONSES:
		var response: Dictionary = Tactics.RESPONSES[id]
		_compare(definitions, int(response.kind), id, int(response.floor), response.tactic, Enums.Slot.COUNTER, gaps, wrong_unlock, wrong_species)
	check(gaps.is_empty(), "every legacy variant and learned response has a framework ability %s" % gaps)
	check(wrong_unlock.is_empty(), "framework unlock floors and evidence match legacy %s" % wrong_unlock)
	check(wrong_species.is_empty(), "each legacy move sits in its own species' kit %s" % wrong_species)
	var elite_gaps := PackedStringArray()
	for kind in Elite.SIGNATURES:
		if ability_for_legacy(definitions, Elite.SIGNATURES[kind]) == null:
			elite_gaps.append(Elite.SIGNATURES[kind])
	check(elite_gaps.is_empty(), "every elite signature has a framework ability %s" % elite_gaps)
	var roles := PackedStringArray()
	for kind in Catalog.all().size():
		var entry := Catalog.get_kind(kind)
		if entry.get("boss", false):
			continue
		var basic = definitions.ability(definitions.species[kind].kit[Enums.Slot.BASIC])
		var expected: Array = [str(entry.role)]
		if kind == 13:
			expected = ["burrow"]
		elif kind == 15:
			expected = ["corpse_tether"]
		elif kind == 19:
			expected = ["choir"]
		if not expected.has(basic.legacy):
			roles.append("%s:%s" % [entry.id, basic.legacy])
	check(roles.is_empty(), "every basic ability reproduces its species' legacy role %s" % roles)
	var bosses := PackedStringArray()
	for kind in Catalog.all().size():
		var entry := Catalog.get_kind(kind)
		if entry.get("boss", false) and definitions.ability(definitions.species[kind].kit[Enums.Slot.BASIC]).legacy != "lair:" + str(entry.lair):
			bosses.append(str(entry.id))
	check(bosses.is_empty(), "every boss keeps its lair plan %s" % bosses)


func _compare(definitions, kind: int, legacy: String, floor_number: int, tactic: String, slot: int,
		gaps: PackedStringArray, wrong_unlock: PackedStringArray, wrong_species: PackedStringArray) -> void:
	var ability = ability_for_legacy(definitions, legacy)
	if ability == null:
		gaps.append(legacy)
		return
	if ability.unlock_floor != floor_number or Enums.EVIDENCE_NAMES[ability.unlock_evidence] != LEGACY_EVIDENCE.get(tactic, "?"):
		wrong_unlock.append("%s (floor %d %s, legacy floor %d %s)" % [legacy, ability.unlock_floor, Enums.EVIDENCE_NAMES[ability.unlock_evidence], floor_number, tactic])
	if definitions.species[kind].kit[slot] != ability.id:
		wrong_species.append(legacy)


func check_catalog_inheritance(tables) -> void:
	var mismatched := PackedStringArray()
	for kind in tables.species_count:
		var entry := Catalog.get_kind(kind)
		var basic: int = tables.row(kind, Enums.Slot.BASIC)
		if entry.get("boss", false):
			continue
		if kind not in [3, 10, 15, 19] and not is_equal_approx(tables.row_reach[basic], float(entry.range)):
			mismatched.append("%s range" % entry.id)
		if tables.row_windup_ms[basic] != int(entry.windup):
			mismatched.append("%s windup" % entry.id)
		if tables.row_recovery_ms[basic] < int(entry.recovery):
			mismatched.append("%s recovery" % entry.id)
	check(mismatched.is_empty(), "basic abilities inherit catalog range, wind-up and recovery %s" % mismatched)
	check(tables.row_recovery_ms[tables.row(2, Enums.Slot.BASIC)] == int(Catalog.get_kind(2).recovery) + 300, "authored recovery bonuses add to the catalog value")
	check(tables.row_windup_ms[tables.row(15, Enums.Slot.SIGNATURE)] == int(Catalog.get_kind(15).windup) + 380, "authored wind-up bonuses add to the catalog value")
	check(tables.row_flags[tables.row(0, Enums.Slot.BASIC)] & Tables.ROW_RADIUS_GROWS != 0, "catalog radii grow with mutations")
	check(tables.row_flags[tables.row(13, Enums.Slot.BASIC)] & Tables.ROW_RADIUS_GROWS == 0, "authored radii do not grow with mutations")
	check(is_equal_approx(tables.species_sight[0], float(preload("res://game_balance.gd").values.combat.aggro_radius)), "catalog sight uses the shared aggro radius")


func check_kits(definitions, tables) -> void:
	check(not tables.has_ability(tables.row(4, Enums.Slot.COUNTER)), "a species without a learned response has an empty counter slot")
	check(tables.has_ability(tables.row(16, Enums.Slot.SPECIAL)), "the Graft Thief's loot grab sits in its special slot")
	var supports_ok := true
	for kind in tables.species_count:
		var has_fallback: bool = tables.has_ability(tables.fallback_row[kind])
		if has_fallback != Catalog.is_support(kind):
			supports_ok = false
	check(supports_ok, "exactly the support species have an escort-less fallback attack")
	check(is_equal_approx(tables.row_reach[tables.fallback_row[3]], 1.15), "the support fallback keeps the legacy desperate reach")
	var summon_ok := false
	var start: int = tables.row_effect_start[tables.row(9, Enums.Slot.BASIC)]
	for index in tables.row_effect_count[tables.row(9, Enums.Slot.BASIC)]:
		summon_ok = summon_ok or (tables.effect_kind[start + index] == Enums.Effect.SUMMON and tables.effect_species[start + index] == 0)
	check(summon_ok, "Broodmother hatches resolve to the Rootbound species index")
	var flying := PackedStringArray()
	for kind in tables.species_count:
		if tables.species_layer[kind] == Enums.Layer.AIR:
			flying.append(str(Catalog.get_kind(kind).id))
	check(flying == PackedStringArray(["orchid", "wasp"]), "the hovering species fly %s" % flying)


func check_mutations(tables) -> void:
	check(is_equal_approx(tables.mutation_speed_scale[3], Pool.MOBILITY_SPEED), "Mobility speed matches the legacy value")
	check(is_equal_approx(tables.mutation_speed_scale[4], Pool.JUVENILE_SPEED), "Juvenile speed matches the legacy value")
	check(is_equal_approx(tables.mutation_range_bonus[0], Pool.REACH_BONUS), "Reach range bonus matches the legacy value")
	check(tables.mutation_armour[1] == 1, "Bark grants armour")
	check(tables.mutation_enables[3] & (1 << Enums.Movement.VAULT) != 0, "Mobility enables the cover vault")


func check_movement(definitions, tables) -> void:
	var wrong := PackedStringArray()
	for kind in tables.species_count:
		var entry := Catalog.get_kind(kind)
		var legacy_vault: bool = Attacks.VAULT_ROLES.has(str(entry.role)) and not entry.get("boss", false)
		if legacy_vault != (tables.species_movement[kind] & (1 << Enums.Movement.VAULT) != 0):
			wrong.append(str(entry.id))
	check(wrong.is_empty(), "exactly the legacy vault roles can vault %s" % wrong)
	check(tables.vault_windup_ms == Attacks.VAULT_WINDUP, "the vault wind-up matches the legacy value")


func check_compile(definitions) -> void:
	var started := Time.get_ticks_usec()
	var fresh := Loader.load_files(Loader.ABILITIES_PATH, Loader.SPECIES_PATH, Loader.MODIFIERS_PATH, Catalog.all())
	var first = Tables.compile(fresh, 11.5)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	var second = Tables.compile(Loader.load_files(Loader.ABILITIES_PATH, Loader.SPECIES_PATH, Loader.MODIFIERS_PATH, Catalog.all()), 11.5)
	check(first.fingerprint() == second.fingerprint(), "compiling the same data twice gives identical tables")
	check(elapsed_ms < COMPILE_BUDGET_MS, "loading and compiling takes %.1f ms, under %d ms" % [elapsed_ms, COMPILE_BUDGET_MS])
	check(first.row_count == first.species_count * Enums.SLOTS + first.species_count, "every species has four slot rows and a fallback row")
	print("DEFINITIONS ", JSON.stringify({"species": first.species_count, "abilities": definitions.abilities.size(), "rows": first.row_count,
		"effects": first.effect_kind.size(), "compile_ms": snappedf(elapsed_ms, 0.01)}))


## Each broken document must be refused with an error naming the problem.
func check_rejections() -> void:
	var cases := {
		"an unknown ability field": ["unknown field", func(a, _s, _m): a.abilities[0]["windup"] = 700],
		"a kit naming a missing ability": ["unknown ability", func(_a, s, _m): s.species[0].kit.basic = "no_such_ability"],
		"a duplicate ability id": ["used twice", func(a, _s, _m): a.abilities.append(a.abilities[0].duplicate(true))],
		"an ability in the wrong slot": ["sits in the basic slot", func(_a, s, _m): s.species[0].kit.basic = "rootbound_bark_guard"],
		"a missing catalog species": ["has no framework entry", func(_a, s, _m): s.species.remove_at(0)],
		"a mutation bit that disagrees with the catalog": ["but the catalog uses", func(_a, _s, m): m.mutations[0].bit = 2],
		"an unknown handler": ["unknown handler", func(a, _s, _m): a.abilities[1]["handler"] = "no_such_handler"],
		"a minimum range above the range": ["larger than", func(a, _s, _m): a.abilities[0]["range_min"] = 9.0; a.abilities[0]["range"] = 2.0],
		"a signature without an unlock rule": ["need an unlock rule", func(a, _s, _m): a.abilities[1].erase("unlock")],
		"a non-hovering species that flies": ["hover", func(_a, s, _m): s.species[0].traits.layer = "air"],
		"an unknown shape kind": ["expected one of", func(a, _s, _m): a.abilities[0].shape.kind = "cone"],
		"a wrong schema version": ["version must be", func(a, _s, _m): a.version = 2],
	}
	var base: Array = []
	for path in [Loader.ABILITIES_PATH, Loader.SPECIES_PATH, Loader.MODIFIERS_PATH]:
		base.append(JSON.parse_string(FileAccess.get_file_as_string(path)))
	for label in cases:
		var abilities: Dictionary = base[0].duplicate(true)
		var species: Dictionary = base[1].duplicate(true)
		var modifiers: Dictionary = base[2].duplicate(true)
		cases[label][1].call(abilities, species, modifiers)
		var result := Loader.parse(abilities, species, modifiers, Catalog.all())
		var named := false
		for error in result.errors:
			named = named or error.contains(cases[label][0])
		check(not result.ok() and named, "rejects %s with a matching error" % label)
		if not named:
			print("  errors: ", result.errors)
