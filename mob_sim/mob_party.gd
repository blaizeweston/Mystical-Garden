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
## Combat stats per player: STAT_COUNT floats each, in Stat order. The host sets the first seven with set_stats,
## the class with set_class and the changing effects with set_effects. CLASS is the player's class as its position
## in the contract's party_classes plus one (0 unknown); SPEED_SCALE is its current move speed over its normal one
## (0 rooted, below 1 slowed, above 1 hastened); GUARD is its remaining guard charges over MAX_GUARD_CHARGES; BARK
## is its remaining bark armour in health points.
enum Stat { MELEE_DAMAGE, RANGED_DAMAGE, MELEE_RANGE, RANGED_RANGE, SPEED, ATTACK_SPEED, ARMOUR, CLASS, SPEED_SCALE, GUARD, BARK }
const STAT_COUNT := 11
const MAX_GUARD_CHARGES := 4.0
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
	for slot in players:
		stats[slot * STAT_COUNT + Stat.SPEED_SCALE] = 1.0
	timers.resize(players * TIMER_COUNT)
	timers.fill(0)


## Publishes one player's combat stats: damage and range of its melee and ranged attacks, move speed, attacks
## per second and armour (the share of damage it ignores).
func set_stats(slot: int, values: PackedFloat32Array) -> void:
	for index in mini(values.size(), STAT_COUNT):
		stats[slot * STAT_COUNT + index] = values[index]


## class_number is the player's class position in the contract's party_classes plus one; 0 means unknown.
func set_class(slot: int, class_number: int) -> void:
	stats[slot * STAT_COUNT + Stat.CLASS] = class_number


## The player's changing effects: move speed over its normal speed, guard charges left and bark armour left.
func set_effects(slot: int, speed_scale: float, guard_charges: int, bark: float) -> void:
	stats[slot * STAT_COUNT + Stat.SPEED_SCALE] = speed_scale
	stats[slot * STAT_COUNT + Stat.GUARD] = clampf(guard_charges / MAX_GUARD_CHARGES, 0.0, 1.0)
	stats[slot * STAT_COUNT + Stat.BARK] = maxf(0.0, bark)


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
