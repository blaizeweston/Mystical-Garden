extends RefCounted
## Fixed player slots supplied by the host each tick. Slot k is always player k.

var count := 0
var present := PackedByteArray()
var alive := PackedByteArray()
var x := PackedFloat32Array()
var z := PackedFloat32Array()
var vx := PackedFloat32Array()
var vz := PackedFloat32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var attackers := PackedInt32Array()
## Combat stats per player, set by the host with set_stats: STAT_COUNT floats each, in Stat order.
enum Stat { MELEE_DAMAGE, RANGED_DAMAGE, MELEE_RANGE, RANGED_RANGE, SPEED, ATTACK_SPEED, ARMOUR }
const STAT_COUNT := 7
var stats := PackedFloat32Array()
## Per player, in ticks: when its dodge is ready, when its current wind-up ends, when its current dodge ends.
enum Clocks { DODGE_READY, WINDUP_UNTIL, DODGE_UNTIL }
const TIMER_COUNT := 3
var timers := PackedInt32Array()


func _init(players: int) -> void:
	count = players
	for table: PackedByteArray in [present, alive]:
		table.resize(players)
		table.fill(0)
	for table: PackedFloat32Array in [x, z, vx, vz, hp, max_hp]:
		table.resize(players)
		table.fill(0.0)
	attackers.resize(players)
	attackers.fill(0)
	stats.resize(players * STAT_COUNT)
	stats.fill(0.0)
	timers.resize(players * TIMER_COUNT)
	timers.fill(0)


## Publishes one player's combat stats: damage and range of its melee and ranged attacks, move speed, attacks
## per second and armour (the share of damage it ignores).
func set_stats(slot: int, values: PackedFloat32Array) -> void:
	for index in mini(values.size(), STAT_COUNT):
		stats[slot * STAT_COUNT + index] = values[index]


func set_timers(slot: int, dodge_ready: int, windup_until: int, dodge_until: int) -> void:
	timers[slot * TIMER_COUNT + Clocks.DODGE_READY] = dodge_ready
	timers[slot * TIMER_COUNT + Clocks.WINDUP_UNTIL] = windup_until
	timers[slot * TIMER_COUNT + Clocks.DODGE_UNTIL] = dodge_until


func set_player(slot: int, at: Vector2, velocity: Vector2, health: float, health_max: float) -> void:
	present[slot] = 1
	alive[slot] = int(health > 0.0)
	x[slot] = at.x
	z[slot] = at.y
	vx[slot] = velocity.x
	vz[slot] = velocity.y
	hp[slot] = health
	max_hp[slot] = health_max


func clear_player(slot: int) -> void:
	present[slot] = 0
	alive[slot] = 0
	hp[slot] = 0.0


func targetable(slot: int) -> bool:
	return present[slot] != 0 and alive[slot] != 0
