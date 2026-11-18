extends RefCounted
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
	var target: int = game.closest_enemy(player.pos)
	if target < -1:
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
		game.use_class_skill(peer, player, rng.randi_range(0, 1))


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
	var points: PackedVector2Array = field.navigation.get_point_path(field.free_cell(from), field.free_cell(at))
	var heading := at - from
	for index in mini(points.size(), ROUTE_LOOKAHEAD):
		var point := Vector3(points[index].x, 0.0, points[index].y)
		if index == 0 or field.clear_line(from, point, clearance):
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
