extends Resource

const TerrainDefinition = preload("res://assets/terrain_m02/terrain_definition.gd")
# Explicit channel order for the prototype mesh/shader. Catalog order is arbitrary.
const IDS: Array[StringName] = [&"meadow", &"soil", &"forest_floor", &"stone", &"water"]

@export var definitions: Array[TerrainDefinition]

func definition(id: StringName) -> TerrainDefinition:
	for entry in definitions:
		if entry.id == id:
			return entry
	return null

func allows(a: StringName, b: StringName) -> bool:
	return b in definition(a).compatible and a in definition(b).compatible