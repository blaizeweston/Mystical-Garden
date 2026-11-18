extends RefCounted
## Runs telegraphed attacks. Aim locks when the wind-up starts and the release uses that locked aim.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Rules = preload("res://mob_sim/mob_rules.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const MELEE_LEAD := 0.12
const RANGED_LEAD := 0.28
const MAX_LEAD_SPEED := 6.0
const BUFF_NEIGHBOURS := 16
const HASTE_MS := 3500
const MIN_WINDUP_TICKS := 1

var pool: Pool
var party: Party
var species: Species
var rules: Rules
var events: Events
var locomotion: Locomotion


func _init(mob_pool: Pool, mob_party: Party, table: Species, game_rules: Rules, event_log: Events, mover: Locomotion) -> void:
	pool = mob_pool
	party = mob_party
	species = table
	rules = game_rules
	events = event_log
	locomotion = mover


func in_reach(slot: int, attack: int, player: int) -> bool:
	var at := pool.species[slot] * Species.ATTACKS + attack
	var distance := pool.distance_to(slot, party.x[player], party.z[player])
	return distance <= species.attack_range[at] + pool.reach_bonus[slot] and distance >= species.attack_min_range[at]


## Starts a wind-up if every rule allows it. The brain cannot skip any of these checks.
func begin(slot: int, attack: int, player: int, tick: int) -> bool:
	if tick < pool.stun_until[slot] or not party.targetable(player) or not rules.attack_ready(slot, attack, tick):
		return false
	if not in_reach(slot, attack, player) or not rules.can_claim_attacker(player):
		return false
	var at := pool.species[slot] * Species.ATTACKS + attack
	var x := pool.xz[slot * 2]
	var z := pool.xz[slot * 2 + 1]
	if species.attack_sight[at] != 0 and locomotion.world.line_clear(x, z, party.x[player], party.z[player], 0.0) == 0:
		return false
	var aim := _aim(slot, at, player)
	var ticks := maxi(MIN_WINDUP_TICKS, roundi(species.attack_windup[at] * pool.windup_scale[slot]))
	party.attackers[player] += 1
	pool.windup_until[slot] = tick + ticks
	pool.windup_attack[slot] = attack
	pool.aim_player[slot] = player
	pool.aim_x[slot] = aim.x
	pool.aim_z[slot] = aim.y
	locomotion.hold(slot)
	events.push(Events.Kind.WINDUP, tick, slot, pool.generation[slot], attack, ticks, aim.x, aim.y,
		pool.damage[slot], species.attack_area[at], x, z)
	return true


func _aim(slot: int, at: int, player: int) -> Vector2:
	var origin := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	var shape := species.attack_shape[at]
	if shape == Species.Shape.SELF_AREA or shape == Species.Shape.BUFF or shape == Species.Shape.SUMMON:
		return origin
	var lead := RANGED_LEAD if shape == Species.Shape.AIM_AREA or shape == Species.Shape.PULL else MELEE_LEAD
	var velocity := Vector2(party.vx[player], party.vz[player]).limit_length(MAX_LEAD_SPEED)
	var point := Vector2(party.x[player], party.z[player]) + velocity * lead
	if shape == Species.Shape.DASH or shape == Species.Shape.LEAP:
		return origin + (point - origin).limit_length(species.attack_range[at] + pool.reach_bonus[slot])
	return point


func tick_windups(tick: int) -> void:
	for slot in pool.active:
		if pool.windup_until[slot] > 0 and tick >= pool.windup_until[slot]:
			_release(slot, tick)


func _release(slot: int, tick: int) -> void:
	var attack := pool.windup_attack[slot]
	var at := pool.species[slot] * Species.ATTACKS + attack
	var shape := species.attack_shape[at]
	var player := pool.aim_player[slot]
	var from_x := pool.xz[slot * 2]
	var from_z := pool.xz[slot * 2 + 1]
	_finish_windup(slot)
	pool.ready_at[slot] = tick + roundi(species.attack_recovery[at] * pool.recovery_scale[slot])
	pool.cooldown_until[slot * pool.attacks + attack] = pool.ready_at[slot]
	if shape == Species.Shape.DASH or shape == Species.Shape.LEAP:
		locomotion.displace(slot, pool.aim_x[slot], pool.aim_z[slot])
	elif shape == Species.Shape.BUFF:
		_haste_allies(slot, species.attack_area[at], tick)
	events.push(Events.Kind.RELEASE, tick, slot, pool.generation[slot], attack, shape | (player << 8),
		pool.aim_x[slot], pool.aim_z[slot], pool.damage[slot], species.attack_area[at], from_x, from_z)


## Ends a wind-up early, for a stagger, without releasing the attack.
func interrupt(slot: int, delay_ticks: int, tick: int) -> void:
	if pool.windup_until[slot] <= 0:
		return
	_finish_windup(slot)
	pool.ready_at[slot] = maxi(pool.ready_at[slot], tick + delay_ticks)
	events.push(Events.Kind.INTERRUPT, tick, slot, pool.generation[slot])


## Clears attack state for a mob that died during a wind-up.
func cancel(slot: int) -> void:
	if pool.windup_until[slot] > 0:
		_finish_windup(slot)


func _finish_windup(slot: int) -> void:
	var player := pool.aim_player[slot]
	if player != Pool.NO_PLAYER:
		party.attackers[player] = maxi(0, party.attackers[player] - 1)
	pool.windup_until[slot] = 0
	pool.aim_player[slot] = Pool.NO_PLAYER


func _haste_allies(slot: int, radius: float, tick: int) -> void:
	var nearest: PackedFloat32Array = locomotion.world.nearest_batch(PackedFloat32Array([slot]), radius, BUFF_NEIGHBOURS)
	var x := pool.xz[slot * 2]
	var z := pool.xz[slot * 2 + 1]
	for index in BUFF_NEIGHBOURS:
		var other := int(nearest[index])
		if other < 0:
			return
		if species.support[pool.species[other]] == 0 \
				and locomotion.world.line_clear(x, z, pool.xz[other * 2], pool.xz[other * 2 + 1], 0.0) != 0:
			pool.haste_until[other] = tick + Clock.from_ms(HASTE_MS)
