extends RefCounted
## Synthetic encounter used by the contract tests and the speed measurement.
## Stands in for the game: it walks four players, resolves released attacks and hurts nearby mobs.

const Battlefield = preload("res://battlefield.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Sim = preload("res://mob_sim/mob_sim.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const DT := 1.0 / 60.0
const PLAYER_SPEED := 4.5
const PLAYER_HP := 400.0
const PLAYER_REGEN := 0.25
const PLAYER_HIT := 12.0
const PLAYER_REACH := 3.0
const PLAYER_HIT_TICKS := 24
const MOB_HP := 40.0
const MOB_HIT := 8.0

var field: RefCounted
var sim: Sim
var rng := RandomNumberGenerator.new()
var player_at: Array[Vector2] = []
var player_goal: Array[Vector2] = []
var player_hp := PackedFloat32Array()
var spawnable := PackedInt32Array()
var open_cells: Array[Vector2] = []
var cursor := 0
var damage_dealt := 0.0
var mobs_killed := 0
var clip_count := 0
var max_attackers_seen := 0
var attacker_mismatches := 0
var fixed_intelligence := -1.0


func _init(map_seed: int, mob_count: int, intelligence: float = -1.0) -> void:
	fixed_intelligence = intelligence
	rng.seed = map_seed
	field = Battlefield.new()
	field.configure(0, 5, map_seed)
	sim = Sim.new(mob_count)
	sim.configure(field)
	for kind in sim.species.count:
		if sim.species.spawnable[kind] != 0:
			spawnable.append(kind)
	for x in range(-56,57):
		for z in range(-54,55):
			if not field.occupied(Vector3(x*.5,0,z*.5),.8):
				open_cells.append(Vector2(x*.5,z*.5))
	for player in sim.contract.players:
		player_at.append(_open_point())
		player_goal.append(_open_point())
		player_hp.append(PLAYER_HP)
	_publish_party(true)
	for index in mob_count:
		spawn_mob(index)


func _open_point() -> Vector2:
	return open_cells[rng.randi_range(0, open_cells.size() - 1)]


func spawn_mob(index: int) -> int:
	var request := Pool.Spawn.new()
	request.species = spawnable[index % spawnable.size()]
	request.at = _open_point()
	request.hp = MOB_HP
	request.damage = MOB_HIT
	request.intelligence = fixed_intelligence if fixed_intelligence >= 0.0 else float(index % 5) / 4.0
	request.mutations = (8 if index % 5 == 0 else 0) | (1 if index % 7 == 0 else 0)
	request.flags = Pool.FLAG_LEADER if index % 20 == 0 else 0
	return sim.spawn(request)


func _publish_party(first: bool) -> void:
	for player in sim.contract.players:
		var velocity := Vector2.ZERO
		if not first:
			var before := Vector3(player_at[player].x, 0, player_at[player].y)
			if before.distance_to(Vector3(player_goal[player].x, 0, player_goal[player].y)) < 1.0:
				player_goal[player] = _open_point()
			var goal := Vector3(player_goal[player].x, 0, player_goal[player].y)
			var moved: Vector3 = field.navigate(before, goal, PLAYER_SPEED * DT, 100000 + player)
			velocity = Vector2(moved.x - before.x, moved.z - before.z) / DT
			player_at[player] = Vector2(moved.x, moved.z)
			player_hp[player] = minf(PLAYER_HP, player_hp[player] + PLAYER_REGEN)
		sim.party.set_player(player, player_at[player], velocity, player_hp[player], PLAYER_HP)


## Everything the host does around one simulation tick.
func before_tick() -> void:
	_publish_party(false)


func after_tick() -> void:
	for event in sim.events.read_since(cursor):
		if event.kind == Events.Kind.RELEASE:
			_resolve_release(event)
	cursor = sim.events.head
	if sim.clock.tick % PLAYER_HIT_TICKS == 0:
		_players_strike()
	for index in sim.pool.capacity:
		if sim.pool.alive[index] == 0:
			spawn_mob(index)


func _resolve_release(event: Dictionary) -> void:
	var at := Vector2(event.x, event.z)
	for player in sim.contract.players:
		if sim.party.targetable(player) and player_at[player].distance_to(at) <= float(event.radius):
			player_hp[player] = maxf(1.0, player_hp[player] - float(event.value))
			damage_dealt += float(event.value)
			sim.record_hit(int(event.slot), int(event.generation), player, float(event.value))


func _players_strike() -> void:
	for player in sim.contract.players:
		for slot in sim.pool.active:
			if sim.pool.distance_to(slot, player_at[player].x, player_at[player].y) <= PLAYER_REACH:
				if sim.damage_mob(slot, PLAYER_HIT, player) > 0.0 and sim.pool.alive[slot] == 0:
					mobs_killed += 1
				break


## Checks the fairness and movement promises on the current tick.
func audit() -> void:
	var counted := PackedInt32Array()
	counted.resize(sim.contract.players)
	counted.fill(0)
	for slot in sim.pool.active:
		if sim.pool.windup_until[slot] > 0:
			counted[sim.pool.aim_player[slot]] += 1
		if sim.locomotion.world.clearance(sim.pool.xz[slot * 2], sim.pool.xz[slot * 2 + 1]) < Species.BODY_RADIUS:
			clip_count += 1
	for player in sim.contract.players:
		max_attackers_seen = maxi(max_attackers_seen, counted[player])
		if counted[player] != sim.party.attackers[player]:
			attacker_mismatches += 1
