extends RefCounted
## Every timed area on the ground: hazards mobs leave for players, and fields players leave for mobs.
## Entries live in flat arrays so observations (schema v2) and native code can read them without copying.
##
## Two kinds of entry:
## - Local entries are added by the simulation: mob hazards in training (MobAbilities with resolve_hits),
##   and player fields a training scenario places with MobSim.add_player_field. The simulation applies
##   a local player field's effects to the mobs inside it.
## - Host entries are published by a host that resolves effects itself, as the Neural Arena does. They are
##   replaced wholesale on each publish and never applied here.
##
## Ground areas do not touch flyers.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")

enum Owner { MOBS, PLAYERS }

## A local player field touches the mobs inside it four times a second.
const APPLY_TICKS := 15
## How long a field's slow or root lasts after a touch, so it lapses soon after a mob leaves.
const HOLD_TICKS := 20
const FLAG_GROUND := 1
const FLAG_HOST := 2

var pool: Pool
var species: Species
var x := PackedFloat32Array()
var z := PackedFloat32Array()
var radius := PackedFloat32Array()
var activate := PackedInt32Array()
var until := PackedInt32Array()
var owner := PackedByteArray()
var flags := PackedByteArray()
## Party slot that made a player field, or -1.
var source := PackedInt32Array()
## Effects of local player fields: damage per second, slow scale (1 means none) and root.
var dps := PackedFloat32Array()
var slow := PackedFloat32Array()
var root := PackedByteArray()


func _init(mob_pool: Pool, table: Species) -> void:
	pool = mob_pool
	species = table


func count() -> int:
	return x.size()


## Adds a local entry. Returns its index, which changes when earlier entries expire.
func add(kind: Owner, at: Vector2, size: float, starts: int, ends: int, ground := true, from_player := -1,
		per_second := 0.0, slow_scale := 1.0, roots := false) -> int:
	return _append(kind, at, size, starts, ends, int(ground) * FLAG_GROUND, from_player, per_second, slow_scale, roots)


## Replaces every host entry. Each row is [owner, x, z, radius, activate_tick, until_tick, ground].
func publish(rows: Array) -> void:
	_keep(func(index: int) -> bool: return flags[index] & FLAG_HOST == 0)
	for row: Array in rows:
		_append(int(row[0]), Vector2(row[1], row[2]), float(row[3]), int(row[4]), int(row[5]),
			FLAG_HOST | (FLAG_GROUND if bool(row[6]) else 0), -1, 0.0, 1.0, false)


## Drops expired local entries. Host entries are refreshed by publish.
func prune(tick: int) -> void:
	if not until.is_empty():
		_keep(func(index: int) -> bool: return flags[index] & FLAG_HOST != 0 or tick < until[index])


func active(index: int, tick: int) -> bool:
	return tick >= activate[index] and tick < until[index]


## Whether an entry reaches a mob, which needs it to be active and not a ground area under a flyer.
func reaches(index: int, slot: int, tick: int) -> bool:
	if not active(index, tick) or (flags[index] & FLAG_GROUND != 0 and species.layer[pool.species[slot]] != 0):
		return false
	var dx: float = pool.xz[slot * 2] - x[index]
	var dz: float = pool.xz[slot * 2 + 1] - z[index]
	return dx * dx + dz * dz <= radius[index] * radius[index]


## Whether a mob stands in an active player field that reaches it.
func in_player_field(slot: int, tick: int) -> bool:
	for index in x.size():
		if owner[index] == Owner.PLAYERS and reaches(index, slot, tick):
			return true
	return false


## Indices of the entries nearest a point, closest edge first, up to limit. Expired entries are skipped;
## entries that have not started yet are kept, since a mob should see them coming.
func nearest(at: Vector2, limit: int, tick: int) -> PackedInt32Array:
	var found := []
	for index in x.size():
		if tick < until[index]:
			found.append([at.distance_to(Vector2(x[index], z[index])) - radius[index], index])
	found.sort()
	var result := PackedInt32Array()
	for entry in found.slice(0, limit):
		result.append(int(entry[1]))
	return result


## The touches local player fields make this tick, as [slot, damage, player, slow scale, roots] rows.
## MobSim deals the damage through damage_mob, so armour, dodges and deaths follow the usual rules, and
## applies the slow and root for HOLD_TICKS. Visits nothing when no local player field exists.
func due(tick: int) -> Array:
	var touches := []
	if tick % APPLY_TICKS != 0:
		return touches
	for index in x.size():
		if owner[index] != Owner.PLAYERS or flags[index] & FLAG_HOST != 0 or not active(index, tick):
			continue
		for slot in pool.active:
			if reaches(index, slot, tick):
				touches.append([slot, dps[index] * APPLY_TICKS / float(Clock.TICKS_PER_SECOND), source[index], slow[index], root[index] != 0])
	return touches


func _append(kind: int, at: Vector2, size: float, starts: int, ends: int, entry_flags: int, from_player: int,
		per_second: float, slow_scale: float, roots: bool) -> int:
	x.append(at.x)
	z.append(at.y)
	radius.append(size)
	activate.append(starts)
	until.append(ends)
	owner.append(kind)
	flags.append(entry_flags)
	source.append(from_player)
	dps.append(per_second)
	slow.append(clampf(slow_scale, 0.0, 1.0))
	root.append(int(roots))
	return x.size() - 1


func _keep(test: Callable) -> void:
	var kept := PackedInt32Array()
	for index in x.size():
		if test.call(index):
			kept.append(index)
	if kept.size() == x.size():
		return
	x = _floats(x, kept)
	z = _floats(z, kept)
	radius = _floats(radius, kept)
	dps = _floats(dps, kept)
	slow = _floats(slow, kept)
	activate = _ints(activate, kept)
	until = _ints(until, kept)
	source = _ints(source, kept)
	owner = _bytes(owner, kept)
	flags = _bytes(flags, kept)
	root = _bytes(root, kept)


static func _floats(values: PackedFloat32Array, kept: PackedInt32Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for index in kept:
		result.append(values[index])
	return result


static func _ints(values: PackedInt32Array, kept: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in kept:
		result.append(values[index])
	return result


static func _bytes(values: PackedByteArray, kept: PackedInt32Array) -> PackedByteArray:
	var result := PackedByteArray()
	for index in kept:
		result.append(values[index])
	return result
