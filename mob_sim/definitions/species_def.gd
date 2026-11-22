extends RefCounted
## Framework data for one catalog species: its ability kit, movement options and traits.
## Identity, base stats, models and loot stay in the enemy catalog.

const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Reader = preload("res://mob_sim/definitions/definition_reader.gd")
const Traits = preload("res://mob_sim/definitions/trait_set.gd")

const FIELDS := ["id", "kit", "movement", "traits"]

## Catalog species id, such as "rootbound".
var id := ""
## Ability id per slot, in Slot order. An empty id leaves the slot unused.
var kit := PackedStringArray(["", "", "", ""])
var movement := PackedInt32Array()
var traits: Traits


static func parse(data: Dictionary, reader: Reader) -> RefCounted:
	var species: RefCounted = new()
	reader.only(data, FIELDS)
	species.id = reader.text(data, "id", "", true)
	var kit := reader.dictionary(data, "kit", true)
	reader.push("kit")
	reader.only(kit, Enums.SLOT_NAMES)
	for slot in Enums.SLOTS:
		species.kit[slot] = reader.text(kit, Enums.SLOT_NAMES[slot], "", slot == Enums.Slot.BASIC)
	reader.pop()
	for name in reader.list(data, "movement"):
		var value := Enums.value_of(Enums.MOVEMENT_NAMES, str(name))
		if value < 0:
			reader.fail("movement '%s' is not one of %s" % [name, ", ".join(PackedStringArray(Enums.MOVEMENT_NAMES))])
		elif species.movement.has(value):
			reader.fail("movement '%s' is listed twice" % name)
		else:
			species.movement.append(value)
	reader.push("traits")
	species.traits = Traits.parse(reader.dictionary(data, "traits"), reader)
	reader.pop()
	return species


func has_movement(kind: int) -> bool:
	return movement.has(kind)
