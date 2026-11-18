extends SceneTree
## Gate A accuracy checks: the native core must agree with Battlefield geometry on real maps.

const Battlefield = preload("res://battlefield.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const DT := 1.0 / 60.0
const SPEED := 2.2
## The quarter-unit clearance grid can read up to about 0.08 high right at a sharp corner.
const MARGIN := 0.09
const CLIP_TOLERANCE := 0.02
const ARRIVAL := 0.52
const AUTHORED_EDGE := 0.5
const ROUTES := 20
const ROUTE_LIMIT := 3600
const CROWD := 100
const CROWD_TICKS := 1800
const CROWD_STOP := 5.0
const SEEDS := [11, 2222, 987654, 41, 73019, 500009, 6, 88172]

var totals := {"maps": 0, "clearance_points": 0, "clearance_errors": 0, "sight_pairs": 0, "sight_errors": 0,
	"sight_exact_mismatches": 0, "reach_pairs": 0, "reach_lost": 0, "reach_extra": 0, "routes": 0, "routes_arrived": 0,
	"routes_current_arrived": 0, "native_ticks": 0, "current_ticks": 0, "route_clips": 0, "crowd_agents": 0,
	"crowd_arrived": 0, "crowd_clips": 0, "determinism_failures": 0, "bake_failures": 0}
var worst_map := {"map": "", "crowd_arrived_share": 1.0}
var sight_examples: Array = []
var clip_examples: Array = []


func _initialize() -> void:
	call_deferred("run")


func free_points(field: RefCounted, count: int, rng: RandomNumberGenerator) -> Array[Vector3]:
	var cells: Array[Vector2i] = []
	var region: Rect2i = field.navigation.region
	for x in range(region.position.x, region.end.x):
		for z in range(region.position.y, region.end.y):
			if not field.navigation.is_point_solid(Vector2i(x, z)):
				cells.append(Vector2i(x, z))
	var out: Array[Vector3] = []
	for i in count:
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		out.append(Vector3(c.x * 0.5, 0, c.y * 0.5))
	return out


## Battlefield grows barriers with square corners. Clearance is a true distance, so corners are round.
func within_clearance(field: RefCounted, at: Vector3) -> bool:
	if not field.inside_floor(at, Battlefield.CLEARANCE):
		return true
	var point := Vector2(at.x, at.z)
	for rect: Rect2 in field.barriers:
		var nearest := point.clamp(rect.position, rect.end)
		if nearest.distance_to(point) < Battlefield.CLEARANCE:
			return true
	return false


func check_clearance(field: RefCounted, world: RefCounted, rng: RandomNumberGenerator) -> void:
	for i in 4000:
		var at := Vector3(rng.randf_range(-30.0, 30.0), 0, rng.randf_range(-29.0, 29.0))
		# Authored arenas apply no clearance at their outer edge. The native core deliberately does.
		if not field.procedural and not Rect2(-29.5, -28.5, 59.0, 57.0).grow(-AUTHORED_EDGE).has_point(Vector2(at.x, at.z)):
			continue
		var native: float = world.clearance(at.x, at.z)
		totals.clearance_points += 1
		var blocked := within_clearance(field, at)
		if native >= Battlefield.CLEARANCE + MARGIN and blocked:
			totals.clearance_errors += 1
		elif native <= Battlefield.CLEARANCE - MARGIN and not blocked:
			totals.clearance_errors += 1


func check_sight(field: RefCounted, world: RefCounted, points: Array[Vector3], rng: RandomNumberGenerator) -> void:
	for i in 1500:
		var a: Vector3 = points[rng.randi_range(0, points.size() - 1)]
		var b: Vector3 = points[rng.randi_range(0, points.size() - 1)]
		totals.sight_pairs += 1
		var old_open: bool = field.clear_line(a, b, 0.0)
		var native_open: bool = world.line_clear(a.x, a.z, b.x, b.z, 0.0) != 0
		if old_open != native_open:
			totals.sight_exact_mismatches += 1
		# A mismatch is an error only when the line is not within a margin of grazing a wall.
		var native_margin: bool = world.line_clear(a.x, a.z, b.x, b.z, MARGIN) != 0
		var old_margin: bool = field.clear_line(a, b, MARGIN)
		if (native_margin and not old_open) or (old_margin and not native_open):
			totals.sight_errors += 1
			if sight_examples.size() < 6:
				sight_examples.append({"a": [a.x, a.z], "b": [b.x, b.z], "old_open": old_open, "old_margin": old_margin,
					"native_open": native_open, "native_margin": native_margin, "procedural": field.procedural})


func check_reach(field: RefCounted, world: RefCounted, points: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var target: Vector3 = points[rng.randi_range(0, points.size() - 1)]
	world.set_targets(PackedFloat32Array([target.x, target.z]))
	world.load_agents(PackedFloat32Array())
	world.tick(DT)
	var goal: Vector2i = field.free_cell(target)
	for i in 200:
		var at: Vector3 = points[rng.randi_range(0, points.size() - 1)]
		totals.reach_pairs += 1
		var old_reach: bool = not field.navigation.get_id_path(field.free_cell(at), goal).is_empty()
		var native_reach: bool = world.path_cost(0, at.x, at.z) >= 0.0
		if old_reach and not native_reach:
			totals.reach_lost += 1
		elif native_reach and not old_reach:
			totals.reach_extra += 1


func check_routes(field: RefCounted, points: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var world: RefCounted = NavWorld.create(1, 1)
	NavWorld.bake(world, field)
	for route in ROUTES:
		var start: Vector3 = points[rng.randi_range(0, points.size() - 1)]
		var finish: Vector3 = points[rng.randi_range(0, points.size() - 1)]
		for attempt in 40:
			if start.distance_to(finish) >= 8.0:
				break
			finish = points[rng.randi_range(0, points.size() - 1)]
		totals.routes += 1
		world.set_targets(PackedFloat32Array([finish.x, finish.z]))
		world.load_agents(PackedFloat32Array([1.0, start.x, start.z, SPEED, Battlefield.CLEARANCE, 0.5, 0.0, float(NavWorld.Mode.SEEK), 0.0, 0.0]))
		var native_ticks := -1
		for tick in ROUTE_LIMIT:
			world.tick(DT)
			var xz: PackedFloat32Array = world.positions()
			var at := Vector3(xz[0], 0, xz[1])
			if field.occupied(at, Battlefield.CLEARANCE - CLIP_TOLERANCE):
				totals.route_clips += 1
			if at.distance_to(finish) <= ARRIVAL:
				native_ticks = tick + 1
				break
		field.routes.clear()
		var current := start
		var current_ticks := -1
		for tick in ROUTE_LIMIT:
			current = field.navigate(current, finish, SPEED * DT, 0)
			if current.distance_to(finish) <= ARRIVAL:
				current_ticks = tick + 1
				break
		if current_ticks >= 0:
			totals.routes_current_arrived += 1
		if native_ticks >= 0:
			totals.routes_arrived += 1
		if native_ticks >= 0 and current_ticks >= 0:
			totals.native_ticks += native_ticks
			totals.current_ticks += current_ticks


func crowd_run(field: RefCounted, starts: Array[Vector3], targets: PackedFloat32Array, audit: bool) -> Dictionary:
	var world: RefCounted = NavWorld.create(CROWD, 4)
	NavWorld.bake(world, field)
	world.set_targets(targets)
	var rows := PackedFloat32Array()
	for at in starts:
		rows.append_array(PackedFloat32Array([1.0, at.x, at.z, SPEED, Battlefield.CLEARANCE, CROWD_STOP,
			float(NavWorld.NEAREST_TARGET), float(NavWorld.Mode.SEEK), 0.0, 0.0]))
	world.load_agents(rows)
	var clips := 0
	for tick in CROWD_TICKS:
		world.tick(DT)
		if audit and tick % 3 == 0:
			var xz: PackedFloat32Array = world.positions()
			for i in CROWD:
				var body := Vector3(xz[i * 2], 0, xz[i * 2 + 1])
				if field.occupied(body, Battlefield.CLEARANCE - CLIP_TOLERANCE):
					clips += 1
					if clip_examples.size() < 6:
						clip_examples.append({"at": [body.x, body.z], "native_clearance": world.clearance(body.x, body.z), "tick": tick})
	var final: PackedFloat32Array = world.positions()
	var arrived := 0
	for i in CROWD:
		var at := Vector3(final[i * 2], 0, final[i * 2 + 1])
		for t in 4:
			if at.distance_to(Vector3(targets[t * 2], 0, targets[t * 2 + 1])) <= CROWD_STOP + 2.5:
				arrived += 1
				break
	return {"arrived": arrived, "clips": clips, "hash": world.state_hash()}


func check_map(label: String, field: RefCounted, seed_value: int) -> void:
	totals.maps += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 77
	var world: RefCounted = NavWorld.create(1, 1)
	if NavWorld.bake(world, field) != OK:
		totals.bake_failures += 1
		return
	var points := free_points(field, 600, rng)
	check_clearance(field, world, rng)
	check_sight(field, world, points, rng)
	check_reach(field, world, points, rng)
	check_routes(field, points, rng)
	var starts := free_points(field, CROWD, rng)
	var targets := PackedFloat32Array()
	for at in free_points(field, 4, rng):
		targets.append(at.x)
		targets.append(at.z)
	var first := crowd_run(field, starts, targets, true)
	var second := crowd_run(field, starts, targets, false)
	totals.crowd_agents += CROWD
	totals.crowd_arrived += first.arrived
	totals.crowd_clips += first.clips
	if first.hash != second.hash:
		totals.determinism_failures += 1
	var share: float = first.arrived / float(CROWD)
	if share < worst_map.crowd_arrived_share:
		worst_map = {"map": label, "crowd_arrived_share": share}


func run() -> void:
	if not NavWorld.ensure_loaded():
		printerr("FAIL native extension did not load")
		quit(2)
		return
	for site in 3:
		for index in SEEDS.size():
			var field = Battlefield.new()
			field.configure(site, 2 + index, SEEDS[index])
			check_map("site %d seed %d" % [site, SEEDS[index]], field, SEEDS[index] + site)
		var authored = Battlefield.new()
		authored.configure(site, 1)
		check_map("authored %d" % site, authored, 900 + site)
	for boss in [20, 21, 22, 23]:
		var lair = Battlefield.new()
		lair.configure(0, 10, 5150 + boss, boss, 0)
		check_map("lair %d" % boss, lair, 5150 + boss)
	var passed: bool = totals.clearance_errors == 0 and totals.reach_lost == 0 and totals.route_clips == 0 \
		and totals.crowd_clips == 0 and totals.determinism_failures == 0 and totals.bake_failures == 0 \
		and totals.routes_arrived >= totals.routes_current_arrived and totals.sight_errors == 0
	print("VERIFY_RESULT ", JSON.stringify({"passed": passed, "totals": totals, "worst_crowd_map": worst_map,
		"sight_examples": sight_examples, "clip_examples": clip_examples}))
	quit(0 if passed else 1)
