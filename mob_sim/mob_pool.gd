extends RefCounted
## All mob state in fixed slots. A leader or elite is a normal slot with a flag.
## Position is read here but only MobLocomotion replaces it.

const Catalog = preload("res://enemy_catalog.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const FLAG_LEADER := 1
const FLAG_ELITE := 2
const NO_PLAYER := 255
const MOBILITY_SPEED := 1.18
const JUVENILE_SPEED := 1.15
const REACH_BONUS := 0.65
const NEVER_SENSED := -1000000


class Spawn:
	var species := 0
	var at := Vector2.ZERO
	var hp := 1.0
	var damage := 0.0
	var speed_scale := 1.0
	var windup_scale := 1.0
	var recovery_scale := 1.0
	var mutations := 0
	var flags := 0
	var leader := -1
	var intelligence := 1.0
	var ready_delay_ticks := 0
	## Armoured regardless of mutations, from the species' traits.
	var armoured := false


var capacity := 0
var attacks := 0
var active := PackedInt32Array()
var alive := PackedByteArray()
var generation := PackedInt32Array()
var species := PackedInt32Array()
var flags := PackedByteArray()
var mutations := PackedInt32Array()
var leader := PackedInt32Array()
var leader_generation := PackedInt32Array()

var xz := PackedFloat32Array()
var spawn_x := PackedFloat32Array()
var spawn_z := PackedFloat32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var speed := PackedFloat32Array()
var damage := PackedFloat32Array()
var reach_bonus := PackedFloat32Array()
var windup_scale := PackedFloat32Array()
var recovery_scale := PackedFloat32Array()
var intelligence := PackedFloat32Array()
var slow_scale := PackedFloat32Array()

var next_decision := PackedInt32Array()
var decision_interval := PackedInt32Array()
var behaviour := PackedByteArray()
var enemy_target := PackedByteArray()
var ally_target := PackedByteArray()
var manoeuvre := PackedByteArray()
var message_a := PackedByteArray()
var message_b := PackedByteArray()
var hold_until := PackedInt32Array()
var behaviour_since := PackedInt32Array()

var ready_at := PackedInt32Array()
var cooldown_until := PackedInt32Array()
var windup_until := PackedInt32Array()
var windup_attack := PackedByteArray()
var aim_player := PackedByteArray()
var aim_x := PackedFloat32Array()
var aim_z := PackedFloat32Array()

var stun_until := PackedInt32Array()
var root_until := PackedInt32Array()
var slow_until := PackedInt32Array()
var haste_until := PackedInt32Array()
var engaged := PackedByteArray()
var last_sensed := PackedInt32Array()
## Status fields owned by MobStatus. Damage over time per second, when it ends, who caused it and the next application.
var dot_dps := PackedFloat32Array()
var dot_until := PackedInt32Array()
var dot_source := PackedByteArray()
var dot_next := PackedInt32Array()
## Nonzero when damage taken is scaled by the shared armour ratio, from the Bark mutation or the species.
var armour := PackedByteArray()
var dodge_until := PackedInt32Array()
var channel_until := PackedInt32Array()


func _init(slots: int, attack_slots: int) -> void:
	capacity = slots
	attacks = attack_slots
	for table: PackedByteArray in [alive, flags, behaviour, enemy_target, ally_target, manoeuvre, message_a, message_b,
			windup_attack, aim_player, engaged, dot_source, armour]:
		table.resize(slots)
		table.fill(0)
	for table: PackedInt32Array in [generation, species, mutations, leader, leader_generation, next_decision, decision_interval,
			hold_until, behaviour_since, ready_at, windup_until, stun_until, root_until, slow_until, haste_until, last_sensed,
			dot_until, dot_next, dodge_until, channel_until]:
		table.resize(slots)
		table.fill(0)
	cooldown_until.resize(slots * attack_slots)
	cooldown_until.fill(0)
	for table: PackedFloat32Array in [spawn_x, spawn_z, hp, max_hp, speed, damage, reach_bonus, windup_scale, recovery_scale,
			intelligence, slow_scale, aim_x, aim_z, dot_dps]:
		table.resize(slots)
		table.fill(0.0)
	xz.resize(slots * 2)
	xz.fill(0.0)


func first_free() -> int:
	for slot in capacity:
		if alive[slot] == 0:
			return slot
	return -1


func spawn(request: Spawn, table: Species, tick: int, interval: int) -> int:
	return spawn_at(first_free(), request, table, tick, interval)


## Fills one chosen slot, so an outside roster can keep its own slot numbers.
func spawn_at(slot: int, request: Spawn, table: Species, tick: int, interval: int) -> int:
	if slot < 0 or slot >= capacity or alive[slot] != 0 or request.species < 0 or request.species >= table.count \
			or table.spawnable[request.species] == 0 or request.hp <= 0.0:
		return -1
	alive[slot] = 1
	generation[slot] += 1
	species[slot] = request.species
	flags[slot] = request.flags
	mutations[slot] = request.mutations
	set_leader(slot, request.leader)
	xz[slot * 2] = request.at.x
	xz[slot * 2 + 1] = request.at.y
	spawn_x[slot] = request.at.x
	spawn_z[slot] = request.at.y
	hp[slot] = request.hp
	max_hp[slot] = request.hp
	speed[slot] = table.speed[request.species] * request.speed_scale \
		* (MOBILITY_SPEED if request.mutations & Catalog.MOBILITY else 1.0) \
		* (JUVENILE_SPEED if request.mutations & Catalog.JUVENILE else 1.0)
	damage[slot] = request.damage
	reach_bonus[slot] = REACH_BONUS if request.mutations & Catalog.REACH else 0.0
	windup_scale[slot] = request.windup_scale
	recovery_scale[slot] = request.recovery_scale
	intelligence[slot] = clampf(request.intelligence, 0.0, 1.0)
	slow_scale[slot] = 1.0
	decision_interval[slot] = interval
	next_decision[slot] = tick + 1 + slot % interval
	behaviour[slot] = 0
	enemy_target[slot] = 0
	ally_target[slot] = 0
	manoeuvre[slot] = 0
	message_a[slot] = 0
	message_b[slot] = 0
	hold_until[slot] = 0
	behaviour_since[slot] = tick
	ready_at[slot] = tick + request.ready_delay_ticks
	for attack in attacks:
		cooldown_until[slot * attacks + attack] = 0
	windup_until[slot] = 0
	aim_player[slot] = NO_PLAYER
	stun_until[slot] = 0
	root_until[slot] = 0
	slow_until[slot] = 0
	haste_until[slot] = 0
	engaged[slot] = 0
	last_sensed[slot] = NEVER_SENSED
	dot_dps[slot] = 0.0
	dot_until[slot] = 0
	dot_source[slot] = NO_PLAYER
	dot_next[slot] = 0
	armour[slot] = int(request.mutations & Catalog.BARK != 0 or request.armoured)
	dodge_until[slot] = 0
	channel_until[slot] = 0
	_rebuild_active()
	return slot


func despawn(slot: int) -> void:
	alive[slot] = 0
	windup_until[slot] = 0
	aim_player[slot] = NO_PLAYER
	_rebuild_active()


func set_leader(slot: int, leader_slot: int) -> void:
	var valid := leader_slot >= 0 and leader_slot < capacity and leader_slot != slot and alive[leader_slot] != 0
	leader[slot] = leader_slot if valid else -1
	leader_generation[slot] = generation[leader_slot] if valid else 0


func leader_of(slot: int) -> int:
	var chosen := leader[slot]
	return chosen if chosen >= 0 and alive[chosen] != 0 and generation[chosen] == leader_generation[slot] else -1


func is_leader(slot: int) -> bool:
	return flags[slot] & (FLAG_LEADER | FLAG_ELITE) != 0


func distance_to(slot: int, x: float, z: float) -> float:
	var dx := xz[slot * 2] - x
	var dz := xz[slot * 2 + 1] - z
	return sqrt(dx * dx + dz * dz)


func state_hash() -> int:
	return hash([xz, hp, alive, behaviour, enemy_target, windup_until, ready_at])


func _rebuild_active() -> void:
	active.clear()
	for slot in capacity:
		if alive[slot] != 0:
			active.append(slot)
