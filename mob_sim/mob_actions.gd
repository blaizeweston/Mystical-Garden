extends RefCounted
## Actions a mob takes on itself: spending and channeling mana, and dodging. MobRules calls on_change when
## a committed behaviour changes, so a dodge happens the moment it is chosen and a channel lasts exactly as
## long as the channel behaviour.
##
## Mana is settled lazily: while a mob channels, pool.mana holds its mana as of pool.channel_from and the
## refill is added when it is read through settle(). Nothing is visited per tick.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Perception = preload("res://mob_sim/mob_perception.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")

## channel_until while a channel lasts. The channel ends when the behaviour changes.
const CHANNEL_OPEN := 0x7FFFFFFF
## Clearance a dodge needs along its path.
const DODGE_CLEARANCE := 0.3

var pool: Pool
var party: Party
var species: Species
var perception: Perception
var locomotion: Locomotion
var dodge_id := -1
var channel_id := -1
var _dodge_hold := 0
var _players := 0


func _init(contract: Contract, mob_pool: Pool, mob_party: Party, table: Species, senses: Perception, mover: Locomotion) -> void:
	pool = mob_pool
	party = mob_party
	species = table
	perception = senses
	locomotion = mover
	dodge_id = contract.id("dodge")
	channel_id = contract.id("channel")
	_dodge_hold = Clock.from_ms(float(contract.hold_ms[dodge_id])) if dodge_id >= 0 else 0
	_players = contract.players


func channeling(slot: int, tick: int) -> bool:
	return tick < pool.channel_until[slot]


## Adds the refill since the channel started (or was last settled) to pool.mana.
func settle(slot: int, tick: int) -> void:
	if not channeling(slot, tick) or tick <= pool.channel_from[slot]:
		return
	var kind := pool.species[slot]
	pool.mana[slot] = minf(species.mana_pool[kind], pool.mana[slot] + species.mana_per_tick[kind] * (tick - pool.channel_from[slot]))
	pool.channel_from[slot] = tick


func can_afford(slot: int, attack: int) -> bool:
	return pool.mana[slot] >= species.attack_mana_cost[pool.species[slot] * Species.ATTACKS + attack]


func spend(slot: int, attack: int) -> void:
	var cost := species.attack_mana_cost[pool.species[slot] * Species.ATTACKS + attack]
	if cost > 0.0:
		pool.mana[slot] = maxf(0.0, pool.mana[slot] - cost)


func mana_fraction(slot: int, tick: int) -> float:
	var full := species.mana_pool[pool.species[slot]]
	if full <= 0.0:
		return 1.0
	settle(slot, tick)
	return pool.mana[slot] / full


func can_channel(slot: int) -> bool:
	return pool.mana[slot] < species.mana_pool[pool.species[slot]] and pool.windup_until[slot] <= 0


func can_dodge(slot: int, tick: int) -> bool:
	return species.can_dodge[pool.species[slot]] != 0 and tick >= pool.dodge_ready_at[slot] and pool.windup_until[slot] <= 0 \
		and tick >= pool.stun_until[slot] and tick >= pool.root_until[slot]


## Called by MobRules after a committed behaviour changes.
func on_change(slot: int, previous: int, behaviour: int, tick: int) -> void:
	if previous == channel_id:
		settle(slot, tick)
		pool.channel_until[slot] = 0
	if behaviour == channel_id:
		pool.channel_from[slot] = tick
		pool.channel_until[slot] = CHANNEL_OPEN
	elif behaviour == dodge_id:
		dodge(slot, tick)


## Sidesteps across the nearest known threat, or straight away from it when both sides are blocked, and
## ignores hits for the species' dodge window. The next decision comes when the dodge's hold ends.
func dodge(slot: int, tick: int) -> void:
	var kind := pool.species[slot]
	var origin := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	var away := origin - _threat(slot, origin)
	if away.length_squared() < 0.0001:
		away = Vector2.RIGHT
	away = away.normalized()
	var side := away.orthogonal() if slot % 2 == 0 else -away.orthogonal()
	var distance := species.dodge_distance[kind]
	for direction: Vector2 in [side, -side, away]:
		var point := origin + direction * distance
		if locomotion.world.line_clear(origin.x, origin.y, point.x, point.y, DODGE_CLEARANCE) != 0:
			locomotion.displace(slot, point.x, point.y)
			break
	pool.dodge_until[slot] = tick + species.dodge_ticks[kind]
	pool.dodge_ready_at[slot] = tick + species.dodge_cooldown[kind]
	pool.next_decision[slot] = mini(pool.next_decision[slot], tick + _dodge_hold)


func _threat(slot: int, origin: Vector2) -> Vector2:
	var best := INF
	var chosen := origin
	for player in _players:
		if not perception.knows(slot, player):
			continue
		var at := slot * _players + player
		var point := Vector2(perception.seen_x[at], perception.seen_z[at])
		var distance := origin.distance_squared_to(point)
		if distance < best:
			best = distance
			chosen = point
	return chosen
