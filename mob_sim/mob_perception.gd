extends RefCounted
## What each mob currently senses. A player out of sight keeps the last position the mob knew.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const NEAREST_LIMIT := 12
const ALERT_NEIGHBOURS := 16

var pool: Pool
var party: Party
var species: Species
var nav: RefCounted
var players := 0
var ally_count := 0
var refresh_ticks := 1
var awareness_radius := 0.0
var ally_radius := 0.0
var ally_release_ticks := 0

var visible := PackedByteArray()
var seen_x := PackedFloat32Array()
var seen_z := PackedFloat32Array()
var seen_tick := PackedInt32Array()
var allies := PackedInt32Array()
var ally_generation := PackedInt32Array()
var ally_away_since := PackedInt32Array()


func _init(mob_pool: Pool, mob_party: Party, table: Species, contract: Contract, world: RefCounted) -> void:
	pool = mob_pool
	party = mob_party
	species = table
	nav = world
	players = contract.players
	ally_count = contract.allies
	refresh_ticks = int(contract.perception.refresh_ticks)
	awareness_radius = float(contract.perception.awareness_radius)
	ally_radius = float(contract.perception.ally_sense_radius)
	ally_release_ticks = Clock.from_ms(float(contract.perception.ally_release_ms))
	var sensed := pool.capacity * players
	visible.resize(sensed)
	visible.fill(0)
	seen_x.resize(sensed)
	seen_x.fill(0.0)
	seen_z.resize(sensed)
	seen_z.fill(0.0)
	seen_tick.resize(sensed)
	seen_tick.fill(-1)
	var slots := pool.capacity * ally_count
	allies.resize(slots)
	allies.fill(-1)
	ally_generation.resize(slots)
	ally_generation.fill(0)
	ally_away_since.resize(slots)
	ally_away_since.fill(-1)


func reset_slot(slot: int) -> void:
	for player in players:
		visible[slot * players + player] = 0
		seen_tick[slot * players + player] = -1
	for index in ally_count:
		allies[slot * ally_count + index] = -1
		ally_away_since[slot * ally_count + index] = -1


func knows(slot: int, player: int) -> bool:
	return seen_tick[slot * players + player] >= 0 and party.targetable(player)


func sees(slot: int, player: int) -> bool:
	return visible[slot * players + player] != 0 and party.targetable(player)


func ally(slot: int, index: int) -> int:
	return allies[slot * ally_count + index]


## Refreshes a staggered share of the mobs each tick so the cost stays even.
func update(tick: int) -> void:
	var queries := PackedFloat32Array()
	var owners := PackedInt32Array()
	var newly_engaged := PackedInt32Array()
	for slot in pool.active:
		if (tick + slot) % refresh_ticks != 0:
			continue
		var x := pool.xz[slot * 2]
		var z := pool.xz[slot * 2 + 1]
		var range_limit := species.vision[pool.species[slot]]
		for player in players:
			var at := slot * players + player
			visible[at] = 0
			if not party.targetable(player):
				continue
			var dx := party.x[player] - x
			var dz := party.z[player] - z
			var distance := sqrt(dx * dx + dz * dz)
			if distance <= range_limit:
				queries.append_array(PackedFloat32Array([x, z, party.x[player], party.z[player], 0.0]))
				owners.append(at)
			elif pool.engaged[slot] != 0 and distance <= awareness_radius:
				_remember(at, player, tick)
				pool.last_sensed[slot] = tick
	if owners.is_empty():
		return
	var clear: PackedByteArray = nav.line_clear_batch(queries)
	for index in owners.size():
		var at := owners[index]
		var slot := at / players
		var player := at % players
		if clear[index] != 0:
			visible[at] = 1
			_remember(at, player, tick)
			pool.last_sensed[slot] = tick
			if pool.engaged[slot] == 0:
				pool.engaged[slot] = 1
				newly_engaged.append(slot)
		elif pool.engaged[slot] != 0:
			_remember(at, player, tick)
			pool.last_sensed[slot] = tick
	if not newly_engaged.is_empty():
		_alert_neighbours(newly_engaged, tick)


func _remember(at: int, player: int, tick: int) -> void:
	seen_x[at] = party.x[player]
	seen_z[at] = party.z[player]
	seen_tick[at] = tick


## A mob that notices the party warns nearby mobs it can see.
func _alert_neighbours(sources: PackedInt32Array, tick: int) -> void:
	var slots := PackedFloat32Array()
	for slot in sources:
		slots.append(slot)
	var nearest: PackedFloat32Array = nav.nearest_batch(slots, species.group_alert_radius, ALERT_NEIGHBOURS)
	var queries := PackedFloat32Array()
	var pairs := PackedInt32Array()
	for index in sources.size():
		var source := sources[index]
		for n in ALERT_NEIGHBOURS:
			var other := int(nearest[index * ALERT_NEIGHBOURS + n])
			if other < 0:
				break
			if pool.engaged[other] != 0:
				continue
			queries.append_array(PackedFloat32Array([pool.xz[source * 2], pool.xz[source * 2 + 1], pool.xz[other * 2], pool.xz[other * 2 + 1], 0.0]))
			pairs.append(source)
			pairs.append(other)
	if pairs.is_empty():
		return
	var clear: PackedByteArray = nav.line_clear_batch(queries)
	for index in clear.size():
		if clear[index] == 0:
			continue
		var source := pairs[index * 2]
		var other := pairs[index * 2 + 1]
		pool.engaged[other] = 1
		pool.last_sensed[other] = tick
		for player in players:
			if seen_tick[source * players + player] >= 0:
				seen_x[other * players + player] = seen_x[source * players + player]
				seen_z[other * players + player] = seen_z[source * players + player]
				seen_tick[other * players + player] = seen_tick[source * players + player]


## An ally keeps its slot until it dies or stays out of range long enough.
func refresh_allies(slots: PackedInt32Array, tick: int) -> void:
	if slots.is_empty():
		return
	var query := PackedFloat32Array()
	for slot in slots:
		query.append(slot)
	var nearest: PackedFloat32Array = nav.nearest_batch(query, ally_radius, NEAREST_LIMIT)
	for index in slots.size():
		_refresh_one(slots[index], nearest, index * NEAREST_LIMIT, tick)


func _refresh_one(slot: int, nearest: PackedFloat32Array, offset: int, tick: int) -> void:
	var base := slot * ally_count
	var leader := pool.leader_of(slot)
	for index in ally_count:
		var other := allies[base + index]
		if other < 0:
			continue
		if pool.alive[other] == 0 or pool.generation[other] != ally_generation[base + index] or other == leader:
			allies[base + index] = -1
			ally_away_since[base + index] = -1
		elif pool.distance_to(slot, pool.xz[other * 2], pool.xz[other * 2 + 1]) <= ally_radius:
			ally_away_since[base + index] = -1
		elif ally_away_since[base + index] < 0:
			ally_away_since[base + index] = tick
		elif tick - ally_away_since[base + index] >= ally_release_ticks:
			allies[base + index] = -1
			ally_away_since[base + index] = -1
	var candidate := 0
	for index in ally_count:
		if allies[base + index] >= 0:
			continue
		while candidate < NEAREST_LIMIT:
			var other := int(nearest[offset + candidate])
			candidate += 1
			if other < 0:
				return
			if other != leader and not _is_slotted(base, other):
				allies[base + index] = other
				ally_generation[base + index] = pool.generation[other]
				ally_away_since[base + index] = -1
				break


func _is_slotted(base: int, other: int) -> bool:
	for index in ally_count:
		if allies[base + index] == other:
			return true
	return false
