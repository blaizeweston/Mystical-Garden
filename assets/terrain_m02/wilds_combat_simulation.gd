extends "res://assets/terrain_m02/wilds_play_simulation.gd"
## Local prototype authority. Actors reuse the terrain's swept X/Z queries.

const Navigation = preload("res://assets/terrain_m02/wilds_combat_navigation.gd")
const MAX_HEALTH := 100
const ENEMY_HEALTH := 2
const ENEMY_SPEED := 2.65
const DETECT := SIGHT
const MELEE_REACH := 1.27
const SHOT_RANGE := 6.1
const BOLT_SPEED := 14.0
const BOLT_RADIUS := 0.10
const SWING_WINDUP := 0.42
const SHOT_WINDUP := 0.57
const DODGE_TIME := 0.22
const DODGE_SPEED := 10.0
const ROUTE_COOLDOWN := 0.30
const REPATH_DISTANCE := 0.85
const STALL_TIME := 0.27

var navigation: Navigation
var health := MAX_HEALTH
var player_attack := 0.0
var dodge_recovery := 0.0
var dodge_left := 0.0
var dodge_direction := Vector2.ZERO
var projectiles: Array[Dictionary] = []
var event := ""
var shots_blocked := 0
var route_queries := 0
var route_failures := 0
var route_recoveries := 0
var route_usec := 0
var route_peak_usec := 0
var update_usec := 0
var update_count := 0
var route_used_this_tick := false

func _init(play_surface: Surface) -> void:
	super(play_surface)
	if not ready:
		return
	ready = false
	navigation = Navigation.new(surface)
	var ranged_room: String = surface.layout.combat_rooms.back()
	for enemy in encounters:
		var room: String = enemy.id.rsplit("_", true, 1)[0]
		if not navigation.room_reachable("arrival", room) or not navigation.traversable(enemy.approach, enemy.position):
			return
		enemy.merge({"room": room, "role": "ranged" if room == ranged_room else "melee", "health": ENEMY_HEALTH,
			"state": "idle", "route": PackedVector2Array(), "index": 0,
			"target": Vector2.INF, "retry": 0.0, "stall": 0.0, "attack": 0.0, "windup": 0.0,
			"aim": Vector2.ZERO})
	ready = true

func move(delta: Vector2) -> void:
	if health > 0 and dodge_left <= 0.0:
		super(delta)

func dodge(direction: Vector2) -> bool:
	if not ready or finished or health <= 0 or dodge_recovery > 0.0 or direction.is_zero_approx():
		return false
	dodge_direction = direction.normalized()
	dodge_left = DODGE_TIME
	dodge_recovery = 0.70
	event = ""
	return true

func tick(delta: float) -> void:
	if not ready or finished or health <= 0:
		return
	var started := Time.get_ticks_usec()
	route_used_this_tick = false
	player_attack = maxf(0.0, player_attack - delta)
	dodge_recovery = maxf(0.0, dodge_recovery - delta)
	if dodge_left > 0.0:
		position = surface.slide(position, dodge_direction * DODGE_SPEED * minf(delta, dodge_left))
		observe()
	for enemy in encounters:
		if not enemy.cleared:
			_enemy_tick(enemy, delta)
	_projectile_tick(delta)
	dodge_left = maxf(0.0, dodge_left - delta)
	update_usec += Time.get_ticks_usec() - started
	update_count += 1

func _enemy_tick(enemy: Dictionary, delta: float) -> void:
	var from: Vector2 = enemy.position
	var gap := from.distance_to(position)
	enemy.attack = maxf(0.0, enemy.attack - delta)
	enemy.retry = maxf(0.0, enemy.retry - delta)
	if enemy.state == "idle":
		if gap > DETECT or not surface.clear_line(from, position):
			return
		enemy.state = "pursuit"
	if enemy.state == "windup":
		enemy.windup -= delta
		if enemy.windup <= 0.0:
			_resolve_attack(enemy)
		return
	var reach := SHOT_RANGE if enemy.role == "ranged" else MELEE_REACH
	if gap <= reach and surface.clear_line(from, position, BOLT_RADIUS):
		if enemy.attack <= 0.0:
			enemy.state = "windup"
			enemy.windup = SHOT_WINDUP if enemy.role == "ranged" else SWING_WINDUP
			enemy.aim = position
		return
	_pursue(enemy, delta)

func _pursue(enemy: Dictionary, delta: float) -> void:
	var from: Vector2 = enemy.position
	var exclusions: Array = []
	for other in encounters:
		if other.id != enemy.id and not other.cleared and from.distance_squared_to(other.position) < 16.0:
			exclusions.append({"center": other.position, "radius": 2.0 * Navigation.RADIUS})
	var target := position.move_toward(from, MELEE_REACH * 0.8)
	var step_to := from.move_toward(target, ENEMY_SPEED * delta)
	if from.distance_to(target) <= Navigation.SHORTCUT_DISTANCE and navigation.traversable(from, target, exclusions):
		enemy.position = step_to
		enemy.stall = 0.0
		enemy.route = PackedVector2Array()
		return
	var recovering: bool = enemy.stall >= STALL_TIME
	if not route_used_this_tick and enemy.retry <= 0.0 and (enemy.route.is_empty() or enemy.index >= enemy.route.size()
			or position.distance_to(enemy.target) > REPATH_DISTANCE or recovering):
		_find_route(enemy, exclusions)
	if enemy.index >= enemy.route.size():
		return
	var waypoint: Vector2 = enemy.route[enemy.index]
	if from.distance_to(waypoint) < 0.035:
		enemy.index += 1
		return
	step_to = from.move_toward(waypoint, ENEMY_SPEED * delta)
	if navigation.traversable(from, step_to, exclusions):
		enemy.position = step_to
		enemy.stall = 0.0
	else:
		enemy.stall += delta

func _find_route(enemy: Dictionary, exclusions: Array) -> void:
	var started := Time.get_ticks_usec()
	route_used_this_tick = true
	enemy.target = position
	enemy.retry = ROUTE_COOLDOWN
	enemy.index = 0
	var from: Vector2 = enemy.position
	var goal := _pursuit_goal(from)
	# A clear static route is cheap to cache. Rebuild around moving bodies
	# only after an actual stall, while all movement still checks them.
	var recovering: bool = enemy.stall >= STALL_TIME
	enemy.route = navigation.route(from, goal, exclusions if recovering else [])
	if not enemy.route.is_empty():
		enemy.stall = 0.0
	route_queries += 1
	route_failures += int(enemy.route.is_empty())
	route_recoveries += int(recovering and not enemy.route.is_empty())
	var elapsed := Time.get_ticks_usec() - started
	route_usec += elapsed
	route_peak_usec = maxi(route_peak_usec, elapsed)

func _pursuit_goal(from: Vector2) -> Vector2:
	var direction := (from - position).normalized()
	for angle in [0.0, PI / 3.0, -PI / 3.0, 2.0 * PI / 3.0, -2.0 * PI / 3.0, PI]:
		var at := position + direction.rotated(angle) * MELEE_REACH * 0.8
		if surface.walkable(at, Navigation.RADIUS) and surface.clear_line(at, position, BOLT_RADIUS):
			return at
	return position

func _resolve_attack(enemy: Dictionary) -> void:
	enemy.state = "pursuit"
	enemy.attack = 0.95
	var from: Vector2 = enemy.position
	if enemy.role == "melee":
		if from.distance_to(position) <= MELEE_REACH and surface.clear_line(from, position, BOLT_RADIUS):
			_damage(12)
		return
	var direction: Vector2 = (enemy.aim - from).normalized()
	if not direction.is_zero_approx():
		projectiles.append({"position": from, "direction": direction, "range": SHOT_RANGE + 0.45})

func _projectile_tick(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var bolt := projectiles[i]
		var from: Vector2 = bolt.position
		var length := minf(bolt.range, delta * BOLT_SPEED)
		var to: Vector2 = from + bolt.direction * length
		var radius := Surface.CLEARANCE + BOLT_RADIUS
		var offset := position - from
		var along: float = offset.dot(bolt.direction)
		var beside := offset.length_squared() - along * along
		var hit := INF
		if offset.length_squared() <= radius * radius:
			hit = 0.0
		elif along > 0.0 and beside <= radius * radius:
			hit = along - sqrt(radius * radius - beside)
		var stop: Vector2 = from + bolt.direction * minf(hit, length)
		if not surface.clear_line(from, stop, BOLT_RADIUS):
			shots_blocked += 1
			projectiles.remove_at(i)
		elif hit <= length:
			_damage(9)
			projectiles.remove_at(i)
		else:
			bolt.position = to
			bolt.range -= length
			if bolt.range <= 0.0:
				projectiles.remove_at(i)

func _damage(amount: int) -> void:
	if dodge_left <= 0.0:
		health = maxi(0, health - amount)
		event = "Hit for %d" % amount

func strike() -> String:
	if not ready or finished or health <= 0 or player_attack > 0.0 or dodge_left > 0.0:
		return ""
	player_attack = 0.29
	var closest := {}
	var reach := STRIKE
	for enemy in encounters:
		if enemy.cleared:
			continue
		var gap := position.distance_to(enemy.position)
		if gap <= reach and surface.clear_line(position, enemy.position):
			reach = gap
			closest = enemy
	if closest.is_empty():
		event = "Strike missed"
		return ""
	closest.health -= 1
	if closest.health > 0:
		event = "Strike hit"
		return ""
	closest.cleared = true
	event = "Enemy defeated"
	return closest.id

func use_gate() -> bool:
	return health > 0 and super()
