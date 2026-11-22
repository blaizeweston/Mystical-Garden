extends RefCounted
const ClassActions = preload("res://native_class_actions.gd")
## A scripted party member. It plays through the same movement, attack and skill calls as a person.

const CAMERA_TURN := atan2(3.3, 14.0)
const PLAN_TICKS := 6
const SKILL_TICKS := 45
const DODGE_TICKS := 3
const DODGE_WARNING_MS := 450
const CURSOR_OFFSET := 2.0
const MAX_CURSOR := 20.0
const ROUTE_MARGIN := 0.12
const ROUTE_LOOKAHEAD := 14
const STUCK_DISTANCE := 0.04
const UNSTICK_TURN := 1.8
## In darkness a bot goes to where it last saw an enemy for this long, then roams the map's spawn points.
const MEMORY_TICKS := 240
const ROAM_TICKS := 300
const ROAM_ARRIVAL := 2.0
## A route is reused while its goal stays this close and it is younger than ROUTE_TICKS.
const ROUTE_REUSE := 1.5
const ROUTE_TICKS := 30

var game: Node
var peer := 0
var rng := RandomNumberGenerator.new()
var move_direction := Vector2.ZERO
var _tick := 0
var _reach := 2.0
var _keep_share := 0.8
var _back_off_share := 0.4
var _dodge_chance := 0.5
var _strafe := 1.0
var _last_position := Vector3.INF
var _last_seen := Vector3.INF
var _last_seen_tick := -MEMORY_TICKS
var _roam := Vector3.INF
var _roam_tick := 0
var _target := -2
var _route := PackedVector2Array()
var _route_goal := Vector3.INF
var _route_tick := 0


func _init(world: Node, peer_id: int, seed_value: int) -> void:
	game = world
	peer = peer_id
	rng.seed = seed_value + peer_id


## Picks a fighting style and reads the weapon reach for this round.
func begin_round() -> void:
	_tick = 0
	_keep_share = rng.randf_range(0.6, 0.95)
	_back_off_share = rng.randf_range(0.2, 0.6)
	_dodge_chance = rng.randf_range(0.2, 0.9)
	_strafe = -1.0 if rng.randf() < 0.5 else 1.0
	_last_seen = Vector3.INF
	_last_seen_tick = -MEMORY_TICKS
	_roam = Vector3.INF
	_target = -2
	_route = PackedVector2Array()
	_route_goal = Vector3.INF
	var player: Dictionary = game.players.get(peer, {})
	if not player.is_empty():
		_reach = float(game.weapon_stats(player).reach)


func act(now: int) -> void:
	_tick += 1
	var player: Dictionary = game.players.get(peer, {})
	move_direction = move_direction if game.Life.alive(player) else Vector2.ZERO
	if not game.Life.alive(player):
		return
	var rescue: int = game.Life.nearest(game, player)
	if rescue != 0:
		game.Life.revive(game, peer, rescue)
	# The target is chosen every PLAN_TICKS, like movement, and kept in between while it lives and is seen.
	var target := _target
	if (_tick + peer) % PLAN_TICKS == 0 or not _still_valid(target):
		target = _pick_target(player)
		_target = target
	if target < -1:
		if _in_darkness():
			_search(player)
		else:
			move_direction = Vector2.ZERO
		_send_motion(now)
		return
	var at: Vector3 = game.enemy_position(target)
	var distance: float = player.pos.distance_to(at)
	if (_tick + peer) % PLAN_TICKS == 0:
		_plan_motion(player, at, distance)
	_send_motion(now)
	var aim := Vector2(at.x - player.pos.x, at.z - player.pos.z)
	if aim.length() > 0.05:
		game.mouse_controls.receive(game, peer, aim.normalized() * (minf(distance, MAX_CURSOR) + CURSOR_OFFSET), distance <= _reach, now)
	if (_tick + peer) % DODGE_TICKS == 0:
		_consider_dodge(player, now)
	if (_tick + peer) % SKILL_TICKS == 0 and distance <= _reach + 3.0:
		ClassActions.cast_world(game, peer, rng.randi_range(0, 1))


func _still_valid(target: int) -> bool:
	if target == -1:
		return game.enemy_health() > 0 and (not _in_darkness() or game.bridge.player_sees(peer, game.bridge.leader_slot))
	if target < 0 or target >= game.encounter.scout_count() or game.encounter.hp(target) <= 0:
		return false
	return not _in_darkness() or game.bridge.player_sees(peer, target)


func _in_darkness() -> bool:
	var bridge = game.get("bridge")
	return bridge != null and bridge.light != null and bridge.light.enabled


## The closest enemy this bot can see. In daylight that is the game's own closest enemy.
func _pick_target(player: Dictionary) -> int:
	if not _in_darkness():
		return game.closest_enemy(player.pos)
	var best := INF
	var chosen := -2
	if game.enemy_health() > 0 and game.bridge.player_sees(peer, game.bridge.leader_slot):
		best = player.pos.distance_squared_to(game.tactics.position)
		chosen = -1
	for slot in game.encounter.scout_count():
		if game.encounter.hp(slot) <= 0 or not game.bridge.player_sees(peer, slot):
			continue
		var distance: float = player.pos.distance_squared_to(game.encounter.scout(slot).pos)
		if distance < best:
			best = distance
			chosen = slot
	if chosen >= -1:
		_last_seen = game.tactics.position if chosen == -1 else game.encounter.scout(chosen).pos
		_last_seen_tick = _tick
	return chosen


## Walks to where an enemy was last seen, then roams between spawn points until one shows itself.
func _search(player: Dictionary) -> void:
	if (_tick + peer) % PLAN_TICKS != 0:
		return
	var goal := _last_seen if _tick - _last_seen_tick < MEMORY_TICKS else _roam
	if _tick - _last_seen_tick >= MEMORY_TICKS and (not _roam.is_finite() or _tick - _roam_tick >= ROAM_TICKS
			or player.pos.distance_to(_roam) < ROAM_ARRIVAL):
		var points: Array = game.battlefield.spawn_points
		_roam = points[rng.randi_range(0, points.size() - 1)] if not points.is_empty() else player.pos
		_roam_tick = _tick
		goal = _roam
	if not goal.is_finite() or player.pos.distance_to(goal) < ROAM_ARRIVAL:
		move_direction = Vector2.ZERO
		return
	move_direction = _input_direction(_route_heading(player.pos, goal))


func _send_motion(now: int) -> void:
	if peer != game.HOST:
		game.motions[peer] = [move_direction, now]


func _plan_motion(player: Dictionary, at: Vector3, distance: float) -> void:
	var heading := Vector3.ZERO
	if distance > _reach * _keep_share:
		heading = _route_heading(player.pos, at)
	elif distance < _reach * _back_off_share:
		heading = player.pos - at
	else:
		heading = (at - player.pos).cross(Vector3.UP) * _strafe
	if player.pos.distance_to(_last_position) < STUCK_DISTANCE and not move_direction.is_zero_approx():
		heading = heading.rotated(Vector3.UP, rng.randf_range(-UNSTICK_TURN, UNSTICK_TURN))
	_last_position = player.pos
	move_direction = _input_direction(heading)


## Walks straight when the way is clear, otherwise toward the farthest visible point on the route.
func _route_heading(from: Vector3, at: Vector3) -> Vector3:
	var field: RefCounted = game.battlefield
	var clearance: float = field.CLEARANCE + ROUTE_MARGIN
	if field.clear_line(from, at, clearance):
		return at - from
	if _route.is_empty() or not _route_goal.is_finite() or _route_goal.distance_to(at) > ROUTE_REUSE or _tick - _route_tick >= ROUTE_TICKS:
		_route = field.navigation_graph.route(Vector2(from.x,from.z),Vector2(at.x,at.z))
		_route_goal = at
		_route_tick = _tick
	# A reused route starts at the point nearest the bot, so points already passed are skipped.
	var start := 0
	var nearest := INF
	for index in _route.size():
		var distance := Vector2(from.x, from.z).distance_squared_to(_route[index])
		if distance < nearest:
			nearest = distance
			start = index
	var heading := at - from
	for index in range(start, mini(_route.size(), start + ROUTE_LOOKAHEAD)):
		var point := Vector3(_route[index].x, 0.0, _route[index].y)
		if index == start or field.clear_line(from, point, clearance):
			heading = point - from
	return heading


## Converts a world direction into the camera-relative input that move_player expects.
func _input_direction(heading: Vector3) -> Vector2:
	if heading.length_squared() < 0.0001:
		return Vector2.ZERO
	var turned := heading.normalized().rotated(Vector3.UP, -CAMERA_TURN)
	return Vector2(turned.x, turned.z)


func _consider_dodge(player: Dictionary, now: int) -> void:
	for slot in game.encounter.scout_count():
		var scout: Dictionary = game.encounter.scout(slot)
		var due := int(scout.get("windup", 0))
		if due <= now or due - now > DODGE_WARNING_MS or not game.encounter.alive(slot):
			continue
		var radius := float(scout.get("attack", {}).get("radius", 1.0))
		var blast: Vector3 = scout.blast
		if player.pos.distance_to(blast) <= radius + 0.4 and rng.randf() < _dodge_chance:
			game.dodge_player(peer, _input_direction((player.pos - blast).cross(Vector3.UP) * _strafe))
			return
