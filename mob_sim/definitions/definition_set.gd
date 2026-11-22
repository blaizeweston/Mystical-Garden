extends RefCounted
## Parsed and cross-checked enemy definitions. Built by DefinitionLoader, read by DefinitionTables.

const Ability = preload("res://mob_sim/definitions/ability_def.gd")
const Modifier = preload("res://mob_sim/definitions/modifier_def.gd")
const Species = preload("res://mob_sim/definitions/species_def.gd")

## Enemy catalog entries. Species index i matches catalog kind i, so legacy kind numbers carry over.
var catalog: Array = []
## Framework species in catalog order.
var species: Array[Species] = []
var abilities: Array[Ability] = []
var mutations: Array[Modifier] = []
var vault_range_min := 0.0
var vault_range := 0.0
var vault_windup_ms := 0
var vault_unlock_floor := 1
## Ability supports use when they have no escort.
var support_fallback := ""
var errors := PackedStringArray()

var _ability_index := {}
var _species_index := {}


func ok() -> bool:
	return errors.is_empty()


func index_abilities() -> void:
	_ability_index.clear()
	for index in abilities.size():
		_ability_index[abilities[index].id] = index


func index_species() -> void:
	_species_index.clear()
	for index in catalog.size():
		_species_index[str(catalog[index].id)] = index


func ability_index(id: String) -> int:
	return _ability_index.get(id, -1)


func ability(id: String) -> Ability:
	var index := ability_index(id)
	return abilities[index] if index >= 0 else null


## Catalog kind for a species id, or -1.
func species_index(id: String) -> int:
	return _species_index.get(id, -1)
