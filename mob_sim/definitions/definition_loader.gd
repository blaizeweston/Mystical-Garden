extends RefCounted
## Loads the framework's enemy data, parses it into typed definitions and checks every cross-reference.
## Loading happens once per process. The result is cached and never changes afterwards.

const Ability = preload("res://mob_sim/definitions/ability_def.gd")
const Catalog = preload("res://enemy_catalog.gd")
const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Modifier = preload("res://mob_sim/definitions/modifier_def.gd")
const Reader = preload("res://mob_sim/definitions/definition_reader.gd")
const DefinitionSet = preload("res://mob_sim/definitions/definition_set.gd")
const Species = preload("res://mob_sim/definitions/species_def.gd")

const ABILITIES_PATH := "res://mob_sim/data/abilities.json"
const SPECIES_PATH := "res://mob_sim/data/species.json"
const MODIFIERS_PATH := "res://mob_sim/data/modifiers.json"
const SCHEMA_VERSION := 1
const VAULT_DELIVERIES := [Enums.Delivery.MELEE, Enums.Delivery.LEAP]

## Behaviour classes that abilities may name. Phase 3 replaces this list with the ability registry.
const HANDLERS := ["antiphon", "boss_plan", "brood_hatch", "canopy_shift", "choir_pulse", "corpse_tether", "cover_first",
	"cutoff_aim", "denied_aim", "echo_toll", "flank_route", "glass_feint", "learned_approach", "planted_canopy",
	"relay_order", "scattered_hatch", "seam_route", "shelter", "shepherd_command", "side_anchor", "side_approach", "trophy_grab"]

## Mutation bits the enemy catalog defines, by mutation id.
const CATALOG_BITS := {"reach": Catalog.REACH, "bark": Catalog.BARK, "spores": Catalog.SPORES, "mobility": Catalog.MOBILITY, "juvenile": Catalog.JUVENILE}

static var _cached: DefinitionSet


## Returns the project's definitions, loading them on first use.
static func shared() -> DefinitionSet:
	if _cached == null:
		_cached = load_files(ABILITIES_PATH, SPECIES_PATH, MODIFIERS_PATH, Catalog.all())
	return _cached


static func load_files(abilities_path: String, species_path: String, modifiers_path: String, catalog: Array) -> DefinitionSet:
	var documents := []
	var failures := PackedStringArray()
	for path in [abilities_path, species_path, modifiers_path]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			failures.append("%s: not a readable JSON object" % path)
			parsed = {}
		documents.append(parsed)
	var result := parse(documents[0], documents[1], documents[2], catalog)
	result.errors = failures + result.errors
	return result


## Parses already-decoded documents. Tests use this to feed deliberately broken data.
static func parse(abilities_data: Dictionary, species_data: Dictionary, modifiers_data: Dictionary, catalog: Array) -> DefinitionSet:
	var result := DefinitionSet.new()
	var reader := Reader.new()
	result.catalog = catalog
	result.index_species()
	for document in [["abilities", abilities_data], ["species", species_data], ["modifiers", modifiers_data]]:
		if int(document[1].get("version", 0)) != SCHEMA_VERSION:
			reader.push(document[0])
			reader.fail("version must be %d" % SCHEMA_VERSION)
			reader.pop()
	_parse_abilities(abilities_data, reader, result)
	_parse_species(species_data, reader, result)
	_parse_modifiers(modifiers_data, reader, result)
	if not reader.has_errors():
		_check_references(reader, result)
	result.errors = reader.errors
	return result


static func _parse_abilities(data: Dictionary, reader: Reader, result: DefinitionSet) -> void:
	reader.push("abilities")
	reader.only(data, ["version", "note", "abilities"])
	var entries := reader.list(data, "abilities", true)
	for index in entries.size():
		reader.push("[%d]" % index)
		if typeof(entries[index]) != TYPE_DICTIONARY:
			reader.fail("must be an object")
		else:
			var ability: Ability = Ability.parse(entries[index], reader)
			if result.abilities.any(func(other: Ability) -> bool: return other.id == ability.id):
				reader.fail("ability id '%s' is used twice" % ability.id)
			result.abilities.append(ability)
		reader.pop()
	reader.pop()
	result.index_abilities()


static func _parse_species(data: Dictionary, reader: Reader, result: DefinitionSet) -> void:
	reader.push("species")
	reader.only(data, ["version", "note", "species"])
	var by_kind := {}
	var entries := reader.list(data, "species", true)
	for index in entries.size():
		reader.push("[%d]" % index)
		if typeof(entries[index]) != TYPE_DICTIONARY:
			reader.fail("must be an object")
		else:
			var species: Species = Species.parse(entries[index], reader)
			var kind := result.species_index(species.id)
			if kind < 0:
				reader.fail("species '%s' is not in the enemy catalog" % species.id)
			elif by_kind.has(kind):
				reader.fail("species '%s' is listed twice" % species.id)
			else:
				by_kind[kind] = species
		reader.pop()
	for kind in result.catalog.size():
		if not by_kind.has(kind):
			reader.fail("catalog species '%s' has no framework entry" % result.catalog[kind].id)
		else:
			result.species.append(by_kind[kind])
	reader.pop()


static func _parse_modifiers(data: Dictionary, reader: Reader, result: DefinitionSet) -> void:
	reader.push("modifiers")
	reader.only(data, ["version", "note", "mutations", "vault", "support_fallback"])
	var entries := reader.list(data, "mutations", true)
	for index in entries.size():
		reader.push("mutations[%d]" % index)
		if typeof(entries[index]) != TYPE_DICTIONARY:
			reader.fail("must be an object")
		else:
			var modifier: Modifier = Modifier.parse(entries[index], reader)
			if not CATALOG_BITS.has(modifier.id):
				reader.fail("mutation '%s' is not one of the catalog's mutations" % modifier.id)
			elif CATALOG_BITS[modifier.id] != modifier.bit:
				reader.fail("mutation '%s' uses bit %d but the catalog uses %d" % [modifier.id, modifier.bit, CATALOG_BITS[modifier.id]])
			result.mutations.append(modifier)
		reader.pop()
	for id in CATALOG_BITS:
		if not result.mutations.any(func(modifier: Modifier) -> bool: return modifier.id == id):
			reader.fail("catalog mutation '%s' has no entry" % id)
	var vault := reader.dictionary(data, "vault", true)
	reader.push("vault")
	reader.only(vault, ["range_min", "range", "windup_ms", "unlock_floor"])
	result.vault_range_min = reader.number(vault, "range_min", 0.0, 0.0, 10.0, true)
	result.vault_range = reader.number(vault, "range", 0.0, 0.1, 10.0, true)
	result.vault_windup_ms = int(reader.number(vault, "windup_ms", 0, 100, 5000, true))
	result.vault_unlock_floor = int(reader.number(vault, "unlock_floor", 1, 1, 200, true))
	reader.pop()
	result.support_fallback = reader.text(data, "support_fallback", "", true)
	reader.pop()


## Checks that every name points at something real and that species traits agree with the catalog.
static func _check_references(reader: Reader, result: DefinitionSet) -> void:
	var used := {}
	var fallback := result.ability(result.support_fallback)
	if fallback == null:
		reader.fail("support_fallback '%s' is not an ability" % result.support_fallback)
	elif fallback.slot != Enums.Slot.BASIC:
		reader.fail("support_fallback '%s' must be a basic ability" % result.support_fallback)
	used[result.support_fallback] = true
	for kind in result.species.size():
		var species: Species = result.species[kind]
		var entry: Dictionary = result.catalog[kind]
		reader.push("species/%s" % species.id)
		for slot in Enums.SLOTS:
			var id := species.kit[slot]
			if id.is_empty():
				continue
			var ability := result.ability(id)
			if ability == null:
				reader.fail("kit %s names unknown ability '%s'" % [Enums.SLOT_NAMES[slot], id])
				continue
			if ability.slot != slot:
				reader.fail("ability '%s' is a %s ability but sits in the %s slot" % [id, Enums.SLOT_NAMES[ability.slot], Enums.SLOT_NAMES[slot]])
			if used.has(id) and id != result.support_fallback:
				reader.fail("ability '%s' is already used by another species" % id)
			used[id] = true
		var basic := result.ability(species.kit[Enums.Slot.BASIC])
		if species.has_movement(Enums.Movement.VAULT) and basic != null and not VAULT_DELIVERIES.has(basic.delivery):
			reader.fail("only melee and leaping species can vault")
		if species.has_movement(Enums.Movement.DODGE) != species.traits.can_dodge():
			reader.fail("'dodge' movement and dodge traits must be set together")
		var hovers := str(entry.get("motion", "")) == "hover"
		if hovers != (species.traits.layer == Enums.Layer.AIR):
			reader.fail("only species whose catalog motion is 'hover' fly, and they all must")
		if species.traits.uses_mana() and species.traits.mana_channel_per_second <= 0.0:
			reader.fail("a mana pool needs a channel rate")
		reader.pop()
	for ability in result.abilities:
		reader.push("abilities/%s" % ability.id)
		if not used.has(ability.id):
			reader.fail("no species uses this ability")
		if not ability.handler.is_empty() and not HANDLERS.has(ability.handler):
			reader.fail("unknown handler '%s'" % ability.handler)
		for effect in ability.effects:
			if not effect.handler.is_empty() and not HANDLERS.has(effect.handler):
				reader.fail("unknown effect handler '%s'" % effect.handler)
			if effect.kind == Enums.Effect.SUMMON and result.species_index(effect.species) < 0:
				reader.fail("summons unknown species '%s'" % effect.species)
		reader.pop()
