extends RefCounted
## Fixed ring of simulation events. Rewards, effects and network updates each keep their own cursor.

## DODGED: a hit landed during a dodge window and was ignored. a is the source player.
## HIT: a release or hazard the simulation resolved itself struck a player. a is the player, b root ticks,
## value the damage, radius the pull distance toward from_x and from_z.
## HEALED: slot healed mob a (itself for a corpse tether) by value.
## EVADED: player a dodged slot's attack. Pushed by a host that resolves player dodges (the training party).
enum Kind { SPAWN, DEATH, INTENT, WINDUP, RELEASE, INTERRUPT, DAMAGE_TAKEN, DAMAGE_DEALT, DODGED, HIT, HEALED, EVADED }

const CAPACITY := 8192

var head := 0
var _kind := PackedByteArray()
var _tick := PackedInt32Array()
var _slot := PackedInt32Array()
var _generation := PackedInt32Array()
var _a := PackedInt32Array()
var _b := PackedInt32Array()
var _x := PackedFloat32Array()
var _z := PackedFloat32Array()
var _from_x := PackedFloat32Array()
var _from_z := PackedFloat32Array()
var _value := PackedFloat32Array()
var _radius := PackedFloat32Array()


func _init() -> void:
	_kind.resize(CAPACITY)
	for table: PackedInt32Array in [_tick, _slot, _generation, _a, _b]:
		table.resize(CAPACITY)
	for table: PackedFloat32Array in [_x, _z, _from_x, _from_z, _value, _radius]:
		table.resize(CAPACITY)


func push(kind: int, tick: int, slot: int, generation: int, a: int = 0, b: int = 0, x: float = 0.0, z: float = 0.0,
		value: float = 0.0, radius: float = 0.0, from_x: float = 0.0, from_z: float = 0.0) -> void:
	var at := head % CAPACITY
	_kind[at] = kind
	_tick[at] = tick
	_slot[at] = slot
	_generation[at] = generation
	_a[at] = a
	_b[at] = b
	_x[at] = x
	_z[at] = z
	_from_x[at] = from_x
	_from_z[at] = from_z
	_value[at] = value
	_radius[at] = radius
	head += 1


## Returns the events after the cursor. A reader that fell behind by a full ring starts at the oldest event.
func read_since(cursor: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(maxi(cursor, head - CAPACITY), head):
		var at := index % CAPACITY
		result.append({"kind": _kind[at], "tick": _tick[at], "slot": _slot[at], "generation": _generation[at],
			"a": _a[at], "b": _b[at], "x": _x[at], "z": _z[at], "from_x": _from_x[at], "from_z": _from_z[at],
			"value": _value[at], "radius": _radius[at]})
	return result
