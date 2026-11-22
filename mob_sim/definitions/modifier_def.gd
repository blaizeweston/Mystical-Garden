extends RefCounted
## A spawn-time mutation such as Reach or Bark. The bit matches the enemy catalog's mutation mask.

const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Reader = preload("res://mob_sim/definitions/definition_reader.gd")

const FIELDS := ["id", "bit", "range_bonus", "radius_bonus", "speed_scale", "armour", "enables"]

var id := ""
var bit := 0
var range_bonus := 0.0
var radius_bonus := 0.0
var speed_scale := 1.0
var armour := false
## Movement options this mutation grants, such as the cover vault.
var enables := PackedInt32Array()


static func parse(data: Dictionary, reader: Reader) -> RefCounted:
	var modifier: RefCounted = new()
	reader.only(data, FIELDS)
	modifier.id = reader.text(data, "id", "", true)
	modifier.bit = int(reader.number(data, "bit", 0, 1, 1 << 30, true))
	if modifier.bit & (modifier.bit - 1) != 0:
		reader.fail("'bit' must be a single power of two")
	modifier.range_bonus = reader.number(data, "range_bonus", 0.0, 0.0, 3.0)
	modifier.radius_bonus = reader.number(data, "radius_bonus", 0.0, 0.0, 3.0)
	modifier.speed_scale = reader.number(data, "speed_scale", 1.0, 0.5, 2.0)
	modifier.armour = reader.flag(data, "armour")
	for name in reader.list(data, "enables"):
		var value := Enums.value_of(Enums.MOVEMENT_NAMES, str(name))
		if value < 0:
			reader.fail("enables unknown movement '%s'" % name)
		else:
			modifier.enables.append(value)
	return modifier
