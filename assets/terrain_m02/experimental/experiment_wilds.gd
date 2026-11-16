extends "res://battlefield.gd"

const Terrain = preload("res://assets/terrain_m02/wilds_preview_generation.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Navigation = preload("res://assets/terrain_m02/wilds_combat_navigation.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Campaign = preload("res://campaign.gd")
const SPACING := 1.75
const RADIUS := 14
const REPATH_MS := 70
const CACHE_CHANCE := 0.20
const CLEAR_SEED_CHANCE := 0.40

var generated := {}
var ground: Surface
var navigation_graph: Navigation
var retry_at := 0
var query_peak_usec := 0
var query_failures := 0
var _seed_cache_present := false
var _clear_seeds := 0

func configure(site: int, encounter: int, map_seed: int = 0, boss: int = -1, phase: int = 0) -> void:
	ground = null
	navigation_graph = null
	generated = {}
	_seed_cache_present = false
	_clear_seeds = 0
	var normal_floor := map_seed != 0 and boss < 0 and site in [Campaign.GROVE, Campaign.MIRE, Campaign.HOLLOW]
	var cache_rolled := false
	if normal_floor:
		# Separate deterministic rolls without advancing combat or layout RNG.
		var rolls := ("wilds_seed_rewards/%d" % map_seed).sha256_buffer()
		cache_rolled = float(rolls.decode_u32(0)) / 4294967296.0 < CACHE_CHANCE
		_clear_seeds = int(float(rolls.decode_u32(4)) / 4294967296.0 < CLEAR_SEED_CHANCE)
		var floor_number := site * 6 + clampi(encounter, 1, 6)
		generated = Terrain.build(map_seed, floor_number, RADIUS, SPACING, Catalog, Terrain.Biomes.WINDOWS, true, true, true, true, true)
		if not generated.is_empty() and _configure_floor(site, encounter, map_seed):
			if cache_rolled:
				var cache_random := RandomNumberGenerator.new()
				cache_random.seed = rolls.decode_u32(8)
				_seed_cache_present = _place_seed_cache(generated.layout, cache_random)
			return
		generated = {}
		ground = null
		navigation_graph = null
	super(site, encounter, map_seed, boss, phase)
	_seed_cache_present = cache_rolled and _cache_site_clear(cache) and connected()

func has_seed_cache() -> bool:
	return _seed_cache_present

func clear_seed_count(_depth: int) -> int:
	return _clear_seeds

func _configure_floor(site: int, encounter: int, map_seed: int) -> bool:
	var layout: Dictionary = generated.layout
	if generated.has("navigation"):
		navigation_graph = generated["navigation"]
		generated.erase("navigation")
		ground = navigation_graph.surface
	else:
		ground = Surface.new(generated.cells, layout, SPACING)
		navigation_graph = Navigation.new(ground)
	var nodes: Dictionary = layout.trail_network.nodes
	if not navigation_graph.room_reachable("arrival", "exit_gate"):
		return false
	var rooms: Array = layout.combat_rooms
	if rooms.is_empty():
		return false
	spawn_points.clear()
	for room: String in rooms:
		if not navigation_graph.room_reachable("arrival", room):
			return false
		spawn_points.append(world(nodes[room]))
	entry = world(nodes.arrival)
	extraction = entry
	advance = world(nodes.exit_gate)
	leader = spawn_points[0]
	graft = advance
	# Place utility interactions in clear reachable space beside existing rooms.
	var rooms_by_distance := spawn_points.duplicate()
	rooms_by_distance.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(advance) < b.distance_squared_to(advance))
	for place: Vector3 in rooms_by_distance:
		if place.distance_to(advance) > 2.1:
			graft = place
			break
	if graft == advance:
		return false
	configured_key = Vector3i(site, encounter, map_seed)
	boss_kind = -1
	boss_phase = 0
	surface = null
	procedural = true
	barriers.clear()
	clearings.assign(spawn_points)
	links.clear()
	routes.clear()
	retry_at = 0
	query_peak_usec = 0
	query_failures = 0
	return true

func _place_seed_cache(layout: Dictionary, random: RandomNumberGenerator) -> bool:
	var candidates := PackedVector2Array()
	for room: Dictionary in layout.clearings:
		if room.kind == "optional" and navigation_graph.room_reachable("arrival", room.id) and _cache_site_clear(world(room.center)):
			candidates.append(room.center)
	if candidates.is_empty():
		for index in layout.paths.size():
			var edge: Dictionary = layout.trail_network.edges[index]
			if edge.get("bridge", false) or not navigation_graph.certified.has(edge.id) \
					or not navigation_graph.room_reachable("arrival", edge.from):
				continue
			var spine: PackedVector2Array = layout.paths[index].spine
			for point_index in range(2, spine.size() - 2, 6):
				var center := spine[point_index]
				var shoulder := (spine[point_index + 1] - spine[point_index - 1]).normalized().orthogonal() * 1.15
				for point: Vector2 in [center + shoulder, center - shoulder]:
					if _cache_site_clear(world(point)) and ground.travel(center, point).is_equal_approx(point):
						candidates.append(point)
	if candidates.is_empty():
		return false
	cache = world(candidates[random.randi_range(0, candidates.size() - 1)])
	return true

func _cache_site_clear(point: Vector3) -> bool:
	if point.distance_squared_to(entry) < 25.0 or point.distance_squared_to(advance) < 25.0 \
			or point.distance_squared_to(graft) < 9.0 or occupied(point, Navigation.RADIUS):
		return false
	return ground == null or not ground.Shape.in_any(ground.water, planar(point), Navigation.RADIUS)

func floor_distance(position: Vector3) -> float:
	if ground == null:
		return super(position)
	return -ground.Shape.signed_distance(ground.arena, planar(position))

func inside_floor(position: Vector3, clearance: float = 0.0) -> bool:
	return super(position, clearance) if ground == null else floor_distance(position) > clearance

func occupied(position: Vector3, clearance: float = 0.0) -> bool:
	return super(position, clearance) if ground == null else not ground.walkable(planar(position), clearance)

func can_spawn(position: Vector3) -> bool:
	if ground == null:
		return true
	var point := planar(position)
	if not ground.walkable(point, Navigation.RADIUS):
		return false
	for room: Vector3 in spawn_points:
		if room.distance_squared_to(position) <= 16.0 and navigation_graph.traversable(planar(room), point):
			return true
	return false

func clear_line(from: Vector3, to: Vector3, clearance: float = 0.0) -> bool:
	return super(from, to, clearance) if ground == null else ground.clear_line(planar(from), planar(to), clearance)

func projectile_block_fraction(from: Vector3, to: Vector3, radius: float) -> float:
	return super(from, to, radius) if ground == null else ground.projectile_block_fraction(planar(from), planar(to), radius)

func combat_sight(from: Vector3, to: Vector3) -> bool:
	return super(from, to) if ground == null else ground.combat_sight(planar(from), planar(to))

func slide(from: Vector3, to: Vector3) -> Vector3:
	return super(from, to) if ground == null else world(ground.slide(planar(from), planar(to - from)))

func dash(from: Vector3, to: Vector3) -> Vector3:
	return super(from, to) if ground == null else world(ground.travel(planar(from), planar(to)))

func connected() -> bool:
	return super() if ground == null else navigation_graph.room_reachable("arrival", "exit_gate")

func navigate(from: Vector3, to: Vector3, distance: float, route_id: int = 0) -> Vector3:
	if ground == null:
		return super(from, to, distance, route_id)
	var origin := planar(from)
	var target := planar(to)
	var step := origin.move_toward(target, distance)
	if origin.distance_squared_to(target) <= 9.0 and navigation_graph.traversable(origin, target):
		routes.erase(route_id)
		return world(step)
	var now := Time.get_ticks_msec()
	var route: Dictionary = routes.get(route_id, {})
	if (route.is_empty() or (route.target as Vector2).distance_squared_to(target) > 2.25 or route.get("stalled", false)) and now >= retry_at and now >= int(route.get("after", 0)):
		retry_at = now + REPATH_MS
		var goal := _pursuit_goal(origin, target)
		var before := Time.get_ticks_usec()
		var points := navigation_graph.route(origin, goal) if goal.is_finite() else PackedVector2Array()
		query_peak_usec = maxi(query_peak_usec, Time.get_ticks_usec() - before)
		query_failures += int(points.is_empty())
		route = {"target": target, "points": points, "index": 0, "after": now + (500 if points.is_empty() else 200)}
		routes[route_id] = route
	if route.is_empty() or route.points.is_empty():
		return world(ground.travel(origin, step, Navigation.RADIUS))
	while route.index < route.points.size() and origin.distance_squared_to(route.points[route.index]) < 0.008:
		route.index += 1
	if route.index >= route.points.size():
		route.stalled = true
		return from
	var moved := ground.travel(origin, origin.move_toward(route.points[route.index], distance), Navigation.RADIUS)
	route.stalled = moved.is_equal_approx(origin)
	return world(moved)

func _pursuit_goal(origin: Vector2, target: Vector2) -> Vector2:
	if ground.walkable(target, Navigation.RADIUS):
		return target
	var direction := (origin - target).normalized()
	for radius in [0.8, 1.45]:
		for angle in [0.0, 0.8, -0.8, 1.6, -1.6, PI]:
			var near: Vector2 = target + direction.rotated(angle) * radius
			if ground.walkable(near, Navigation.RADIUS) and ground.clear_line(near, target):
				return near
	return Vector2.INF

static func planar(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)

static func world(at: Vector2) -> Vector3:
	return Vector3(at.x, 0, at.y)
