extends RefCounted
## Reference executors in GDScript. The simulation runs native/mob_exec.c through mob_executors.gd;
## tests/mob_native_parity.gd runs both on identical state every tick and requires identical decisions.
## Change this file and mob_exec.c together.

const Abilities = preload("res://mob_sim/mob_abilities.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Perception = preload("res://mob_sim/mob_perception.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const GOLDEN_ANGLE := 2.39996
const RING_MIN := 0.7
const RING_SHARE := 0.85
const MAX_RANGE_SHARE := 0.98
const CIRCLE_ANGLE := 0.9
const SEEK_STOP := 0.2
const WANDER_TICKS := 180
## Roaming: a new heading every ROAM_TICKS, walking up to one of ROAM_STEPS metres along it, turning by one of
## ROAM_TURNS when the way is blocked. The heading's error is ROAM_SPREAD_DEG / smell^2 + ROAM_SPREAD_MIN_DEG
## degrees either way, growing beyond ROAM_CLEAR_SMELLS smell ranges from the player, and any direction at all
## without smell.
const ROAM_TICKS := 180
const ROAM_STOP := 0.3
const ROAM_SPREAD_DEG := 1600.0
const ROAM_SPREAD_MIN_DEG := 2.0
const ROAM_CLEAR_SMELLS := 2.0
const ROAM_FADE_SMELLS := 4.0
const ROAM_STEPS := [8.0, 5.0, 3.0]
const ROAM_TURNS := [0.0, 0.4, -0.4, 0.8, -0.8]
const MASK_32 := 0xFFFFFFFF
const WANDER_RADIUS := 3.5
const WANDER_LEASH := 8.0
const WANDER_STOP := 0.3
const SEARCH_ARRIVAL := 1.0
const SEARCH_RING := 3.0
const SEARCH_TICKS := 120
const COVER_REFRESH_TICKS := 30
const COVER_ANGLES := 12
const COVER_RADII := [3.0, 6.0]
const COVER_CLEARANCE := 0.6
const COVER_STOP := 0.3
const DEFEND_DISTANCE := 1.6
const BLOCK_DISTANCE := 1.5
const STILL_SPEED := 0.1
const APPROACH_STOP := 0.12
const COMMAND_STOP := 0.25

var contract: Contract
var pool: Pool
var party: Party
var species: Species
var perception: Perception
var abilities: Abilities
var locomotion: Locomotion
var goal_refresh_ticks := 1
var cover_x := PackedFloat32Array()
var cover_z := PackedFloat32Array()
var cover_found := PackedByteArray()
var smell := PackedFloat32Array()
var _run: Array[Callable] = []
var _circle_left := 0
var _circle_right := 0
var _get_behind := 0
var _keep_range := 0


func _init(rules_contract: Contract, mob_pool: Pool, mob_party: Party, table: Species, senses: Perception, attacks: Abilities, mover: Locomotion) -> void:
	contract = rules_contract
	pool = mob_pool
	party = mob_party
	species = table
	perception = senses
	abilities = attacks
	locomotion = mover
	goal_refresh_ticks = int(contract.rules.goal_refresh_ticks)
	_circle_left = contract.manoeuvres.find("circle_left")
	_circle_right = contract.manoeuvres.find("circle_right")
	_get_behind = contract.manoeuvres.find("get_behind")
	_keep_range = contract.manoeuvres.find("keep_max_range")
	cover_x.resize(pool.capacity)
	cover_z.resize(pool.capacity)
	cover_found.resize(pool.capacity)
	cover_found.fill(0)
	for label in contract.names:
		_run.append(Callable(self, "_do_" + label))
	for kind in species.count:
		smell.append(species.tables.species_smell[kind] if species.tables != null else 0.0)


func has_executor(behaviour: int) -> bool:
	return behaviour >= 0 and behaviour < _run.size() and _run[behaviour].is_valid()


func run(tick: int) -> void:
	for slot in pool.active:
		if pool.windup_until[slot] > 0 or tick < pool.stun_until[slot]:
			continue
		# A handler's approach step, then a shepherd's route point, come before the behaviour.
		# Handlers check the approach line when they plan it, so the step walks straight there.
		if pool.approach_until[slot] > tick:
			if pool.distance_to(slot, pool.approach_x[slot], pool.approach_z[slot]) > APPROACH_STOP:
				locomotion.walk_straight(slot, pool.approach_x[slot], pool.approach_z[slot], APPROACH_STOP)
			else:
				locomotion.hold(slot)
			continue
		if pool.command_via[slot] != 0 and tick < pool.command_until[slot]:
			if _due(slot, tick):
				locomotion.go_to(slot, pool.command_via_x[slot], pool.command_via_z[slot], COMMAND_STOP)
			continue
		_run[pool.behaviour[slot]].call(slot, tick)


func _due(slot: int, tick: int) -> bool:
	return pool.behaviour_since[slot] == tick or (tick + slot) % goal_refresh_ticks == 0 or locomotion.is_holding(slot)


func _ring_offset(slot: int, player: int, ring: float, reach: float) -> Vector2:
	var away := Vector2(pool.xz[slot * 2] - party.x[player], pool.xz[slot * 2 + 1] - party.z[player])
	var bearing := away.angle() if away.length_squared() > 0.0001 else slot * GOLDEN_ANGLE
	var chosen := pool.manoeuvre[slot]
	var radius := maxf(RING_MIN, ring)
	if chosen == _circle_left:
		bearing += CIRCLE_ANGLE
	elif chosen == _circle_right:
		bearing -= CIRCLE_ANGLE
	elif chosen == _get_behind:
		var velocity := Vector2(party.vx[player], party.vz[player])
		bearing = velocity.angle() + PI if velocity.length() > STILL_SPEED else bearing + PI
	elif chosen == _keep_range:
		radius = maxf(RING_MIN, reach * MAX_RANGE_SHARE)
	return Vector2.from_angle(bearing) * radius


func _close_on(slot: int, player: int, ring: float, reach: float, tick: int) -> void:
	if not perception.sees(slot, player):
		_go_to_last_known(slot, player, tick)
	elif _due(slot, tick):
		locomotion.seek_player(slot, player, _ring_offset(slot, player, ring, reach), SEEK_STOP)


func _go_to_last_known(slot: int, player: int, tick: int) -> void:
	if not _due(slot, tick):
		return
	var at := slot * contract.players + player
	var x := perception.seen_x[at]
	var z := perception.seen_z[at]
	if pool.distance_to(slot, x, z) > SEARCH_ARRIVAL:
		locomotion.go_to(slot, x, z, SEEK_STOP)
		return
	var sweep := Vector2.from_angle(slot * GOLDEN_ANGLE + float(tick / SEARCH_TICKS) * GOLDEN_ANGLE) * SEARCH_RING
	locomotion.go_to(slot, x + sweep.x, z + sweep.y, SEEK_STOP)


func _target_player(slot: int) -> int:
	var player := pool.enemy_target[slot] - 1
	return player if player >= 0 and perception.knows(slot, player) else -1


func _attack(slot: int, tick: int) -> void:
	var player := _target_player(slot)
	if player < 0:
		locomotion.hold(slot)
		return
	var attack := contract.attack_slot[pool.behaviour[slot]]
	if perception.sees(slot, player) and abilities.begin(slot, attack, player, tick):
		return
	var reach := species.attack_range[pool.species[slot] * Species.ATTACKS + attack] + pool.reach_bonus[slot]
	# As in the game's scouts, a direct attacker runs at its target rather than to a ring inside its reach.
	_close_on(slot, player, RING_MIN if pool.manoeuvre[slot] == 0 else reach * RING_SHARE, reach, tick)


func _do_idle_wander(slot: int, tick: int) -> void:
	if pool.behaviour_since[slot] != tick and (tick + slot * 7) % WANDER_TICKS != 0:
		return
	var leader := pool.leader_of(slot)
	var home_x := pool.xz[leader * 2] if leader >= 0 else pool.spawn_x[slot]
	var home_z := pool.xz[leader * 2 + 1] if leader >= 0 else pool.spawn_z[slot]
	if pool.distance_to(slot, home_x, home_z) > WANDER_LEASH:
		locomotion.go_to(slot, home_x, home_z, WANDER_STOP)
		return
	var turn := slot * GOLDEN_ANGLE + float(tick / WANDER_TICKS) * GOLDEN_ANGLE
	var goal := Vector2(home_x, home_z) + Vector2.from_angle(turn) * WANDER_RADIUS
	var open: bool = locomotion.world.line_clear(pool.xz[slot * 2], pool.xz[slot * 2 + 1], goal.x, goal.y, Locomotion.CLEAR_BODY) != 0
	if open:
		locomotion.go_to(slot, goal.x, goal.y, WANDER_STOP)
	else:
		locomotion.hold(slot)


## A 32-bit hash of the slot's life and roaming period, so each heading's error is fixed for that period and the
## same in native/mob_exec.c.
static func roam_hash(slot: int, generation: int, period: int) -> int:
	var h := ((slot * 73856093) ^ (generation * 19349663) ^ (period * 83492791)) & MASK_32
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & MASK_32
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & MASK_32
	return h ^ (h >> 16)


## Heads a few metres toward the scent of the nearest player. Weak smell and distance blur the heading.
func _do_roam(slot: int, tick: int) -> void:
	if pool.behaviour_since[slot] != tick and (tick + slot * 7) % ROAM_TICKS != 0:
		return
	var nearest := -1
	var best := 0.0
	for player in contract.players:
		if not party.targetable(player):
			continue
		var distance := pool.distance_to(slot, party.x[player], party.z[player])
		if nearest < 0 or distance < best:
			nearest = player
			best = distance
	if nearest < 0:
		locomotion.hold(slot)
		return
	var at := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	var toward := Vector2(party.x[nearest] - at.x, party.z[nearest] - at.y)
	var scent: float = smell[pool.species[slot]]
	var spread := PI
	if scent > 0.0:
		spread = (ROAM_SPREAD_DEG / (scent * scent) + ROAM_SPREAD_MIN_DEG) * (PI / 180.0)
		if best > ROAM_CLEAR_SMELLS * scent:
			spread *= 1.0 + (best - ROAM_CLEAR_SMELLS * scent) / (ROAM_FADE_SMELLS * scent)
		spread = minf(spread, PI)
	var h := roam_hash(slot, pool.generation[slot], (tick + slot * 7) / ROAM_TICKS)
	# Smell leans the error toward the true bearing; without it every direction is equally likely.
	var noise := float(h & 0xFFFF) / 65536.0 + float(h >> 16) / 65536.0 - 1.0 if scent > 0.0 else 2.0 * float(h & 0xFFFF) / 65536.0 - 1.0
	var heading := toward.angle() + spread * noise
	for step: float in ROAM_STEPS:
		for turn: float in ROAM_TURNS:
			var goal := at + Vector2.from_angle(heading + turn) * step
			if locomotion.world.line_clear(at.x, at.y, goal.x, goal.y, Locomotion.CLEAR_BODY) != 0:
				locomotion.go_to(slot, goal.x, goal.y, ROAM_STOP)
				return
	locomotion.hold(slot)


func _do_search(slot: int, tick: int) -> void:
	var player := _target_player(slot)
	if player < 0:
		locomotion.hold(slot)
	else:
		_go_to_last_known(slot, player, tick)


func _do_approach(slot: int, tick: int) -> void:
	var player := _target_player(slot)
	if player < 0:
		locomotion.hold(slot)
		return
	var kind := pool.species[slot]
	_close_on(slot, player, species.preferred_range[kind], species.max_range[kind] + pool.reach_bonus[slot], tick)


func _do_melee_attack(slot: int, tick: int) -> void:
	_attack(slot, tick)


func _do_ranged_attack(slot: int, tick: int) -> void:
	_attack(slot, tick)


func _do_ability_1(slot: int, tick: int) -> void:
	_attack(slot, tick)


func _do_ability_2(slot: int, tick: int) -> void:
	_attack(slot, tick)


func _do_ability_3(slot: int, tick: int) -> void:
	_attack(slot, tick)


func _do_flee(slot: int, tick: int) -> void:
	var player := _target_player(slot)
	if player < 0:
		locomotion.hold(slot)
	elif _due(slot, tick):
		locomotion.flee_from(slot, player)


func _do_take_cover(slot: int, tick: int, hiding := false) -> void:
	var player := _target_player(slot)
	if player < 0:
		locomotion.hold(slot)
		return
	if pool.behaviour_since[slot] == tick or (tick + slot) % COVER_REFRESH_TICKS == 0:
		_find_cover(slot, player, hiding)
	if cover_found[slot] == 0:
		if _due(slot, tick):
			locomotion.flee_from(slot, player)
	elif _due(slot, tick):
		locomotion.go_to(slot, cover_x[slot], cover_z[slot], COVER_STOP)


## Picks the closest open point within reach that the target cannot see. When hiding, a dark point farther
## from the target than a player sees in darkness also counts.
func _find_cover(slot: int, player: int, hiding: bool) -> void:
	var points := PackedVector2Array()
	var queries := PackedFloat32Array()
	var origin := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	for radius: float in COVER_RADII:
		for step in COVER_ANGLES:
			var point := origin + Vector2.from_angle(step * TAU / COVER_ANGLES) * radius
			if locomotion.world.clearance(point.x, point.y) >= COVER_CLEARANCE:
				points.append(point)
				queries.append_array(PackedFloat32Array([party.x[player], party.z[player], point.x, point.y, 0.0]))
	cover_found[slot] = 0
	if points.is_empty():
		return
	var clear: PackedByteArray = locomotion.world.sight_clear_batch(queries)
	var best := INF
	for index in points.size():
		var distance := origin.distance_squared_to(points[index])
		var hidden := clear[index] == 0
		if not hidden and hiding and locomotion.world.sense_light_at(points[index].x, points[index].y) < Perception.LIT_THRESHOLD:
			var dx: float = party.x[player] - points[index].x
			var dz: float = party.z[player] - points[index].y
			hidden = dx * dx + dz * dz > Perception.PLAYER_DARK_SIGHT * Perception.PLAYER_DARK_SIGHT
		if hidden and distance < best:
			best = distance
			cover_x[slot] = points[index].x
			cover_z[slot] = points[index].y
			cover_found[slot] = 1


func _do_hide(slot: int, tick: int) -> void:
	_do_take_cover(slot, tick, true)


func _do_defend_ally(slot: int, tick: int) -> void:
	if not _due(slot, tick):
		return
	var ally := _chosen_ally(slot)
	if ally < 0:
		locomotion.hold(slot)
		return
	var at := Vector2(pool.xz[ally * 2], pool.xz[ally * 2 + 1])
	var threat := _nearest_known_player(slot, at)
	if threat < 0:
		locomotion.go_to(slot, at.x, at.y, DEFEND_DISTANCE)
		return
	var seen := slot * contract.players + threat
	var toward := (Vector2(perception.seen_x[seen], perception.seen_z[seen]) - at).normalized()
	locomotion.go_to(slot, at.x + toward.x * DEFEND_DISTANCE, at.y + toward.y * DEFEND_DISTANCE, SEEK_STOP)


func _chosen_ally(slot: int) -> int:
	var head := pool.ally_target[slot]
	if head == 0:
		return -1
	if head == contract.allies + 1:
		return pool.leader_of(slot)
	var ally := perception.ally(slot, head - 1)
	return ally if ally >= 0 and pool.alive[ally] != 0 else -1


func _nearest_known_player(slot: int, at: Vector2) -> int:
	var best := INF
	var chosen := -1
	for player in contract.players:
		if not perception.knows(slot, player):
			continue
		var seen := slot * contract.players + player
		var distance := at.distance_squared_to(Vector2(perception.seen_x[seen], perception.seen_z[seen]))
		if distance < best:
			best = distance
			chosen = player
	return chosen


func _do_block_enemy(slot: int, tick: int) -> void:
	var player := _target_player(slot)
	if player < 0:
		locomotion.hold(slot)
	elif not perception.sees(slot, player):
		_go_to_last_known(slot, player, tick)
	elif _due(slot, tick):
		var heading := Vector2(party.vx[player], party.vz[player])
		if heading.length() <= STILL_SPEED:
			heading = Vector2(pool.xz[slot * 2] - party.x[player], pool.xz[slot * 2 + 1] - party.z[player])
		locomotion.seek_player(slot, player, heading.normalized() * BLOCK_DISTANCE, SEEK_STOP)


func _do_dodge(slot: int, _tick: int) -> void:
	locomotion.hold(slot)


func _do_channel(slot: int, _tick: int) -> void:
	locomotion.hold(slot)
