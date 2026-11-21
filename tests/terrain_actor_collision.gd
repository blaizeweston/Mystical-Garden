extends SceneTree
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Props = preload("res://assets/terrain_m02/terrain_prop_geometry.gd")
const Motion = preload("res://assets/terrain_m02/terrain_actor_motion.gd")
const Art = preload("res://assets/terrain_m02/terrain_art_direction.gd")
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failed = true; printerr("FAIL actor collision: ", label)
func rectangle(id: String, half: Vector2, yaw: float = 0.0) -> Dictionary:
	var points := PackedVector2Array()
	for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]: points.append((corner * half).rotated(yaw))
	return Shape.shape(id, "fixture", points)
func surface(obstacles: Array, water: Array = [], decks: Array = []) -> RefCounted:
	return Surface.new({}, {"masses":obstacles,"rocks":[],"plants":[],"water":water,"crossings":decks,
		"boundary":{"playable":rectangle("arena",Vector2(10,10)),"rim":[],"water":water}}, 1.75)
func slide_cases(move: Callable, valid: Callable, label: String) -> void:
	var start := Vector2(-1.2,-0.65)
	var delta := Vector2(1.2,0)
	var end: Vector2 = move.call(start,delta)
	check(end.x > -0.60 and end.y < -0.80, label + " brushes around an off-center round obstacle instead of stopping on one axis")
	check(valid.call(end) and end.distance_to(start) <= delta.length() + 0.0001, label + " slides without penetration or acceleration")
	var mirrored: Vector2 = move.call(-start,-delta)
	check(mirrored.distance_to(-end) < 0.001, label + " has no axis or side bias")
	var head_on: Vector2 = move.call(Vector2(-1.4,0),Vector2(2,0))
	check(head_on.x < -0.93 and absf(head_on.y) < 0.0001, label + " solid head-on contact still stops without automatic steering")

func stability_cases() -> void:
	var field = surface([Shape.disk("round", "rock", Vector2.ZERO,0.6)])
	var endpoints := []
	for fps in [60,240]:
		var point := Vector2(-1.4,-0.65)
		for _tick in fps:
			var previous := point
			point = field.slide(point,Vector2(4.0/fps,0))
			check(field.walkable(point) and previous.distance_to(point) <= 4.0/fps + 0.0001, "repeated movement stays legal and within speed")
		endpoints.append(point)
	check(endpoints[0].distance_to(endpoints[1]) < 0.05, "60/240 Hz glancing movement remains close")
	field = surface([rectangle("horizontal",Vector2(4,0.1)),rectangle("vertical",Vector2(0.1,4))])
	var corner: Vector2 = field.slide(Vector2(-1,-1),Vector2(2,2))
	for _tick in 60: corner = field.slide(corner,Vector2(0.08,0.08))
	check(field.walkable(corner) and corner.x < -0.43 and corner.y < -0.43, "closed corners do not tunnel, jitter through walls or run unbounded")
	field = surface([], [rectangle("river",Vector2(0.8,5))], [rectangle("bridge",Vector2(2,0.8))])
	check(field.travel(Vector2(-3,0),Vector2(3,0)).is_equal_approx(Vector2(3,0)), "normal bridge crossing remains legal")
	var bank: Vector2 = field.slide(Vector2(-1.15,1.5),Vector2(1,1))
	check(bank.y > 2.3 and bank.x < -1.13 and field.walkable(bank), "water-bank contact slides along the bank without entering water")
	var deck: Vector2 = field.slide(Vector2(0,0.4),Vector2(0.5,1))
	check(deck.x > 0.45 and deck.y < 0.461 and field.walkable(deck), "bridge-edge sliding stays on the deck")
	var dry_rim := Shape.disk("dry perimeter", "rim", Vector2.ZERO, 0.6)
	dry_rim["wet"] = false
	var perimeter_layout: Dictionary = surface([]).layout.duplicate(true)
	perimeter_layout.boundary.rim = [dry_rim]
	field = Surface.new({}, perimeter_layout, 1.75)
	check(field.projectile_block_fraction(Vector2(-2,0), Vector2(2,0), 0.1) < INF,
		"dry perimeter cover retains its established projectile and sight blocking")

func prop_cases() -> void:
	for family in [-1,0,1,2]:
		for variant in 4:
			var prop := {"id":"boulder","kind":"rock","center":Vector2(2,1),"radius":0.9,"variant":variant,"yaw":0.7,"family":family}
			var body := Props.actor_shape(prop)
			check(not body.has("radius") and body.outline.size() >= 6 and body.bounds.get_area() < 4 * 0.9 * 0.9 * 0.9,
				"rock walking shape follows the mesh rather than its circumscribed disk")
			var source := Props.mesh("rock",variant,Art.profile(family+1),family+1,family)
			var bounds := source.get_aabb()
			# Established renderer sizing/centering is preserved, including yaw.
			var expected_basis := Basis(Vector3.UP,0.7).scaled(Vector3.ONE * (1.8 / Vector2(bounds.size.x,bounds.size.z).length()))
			check(Props.rock_basis(prop,bounds).is_equal_approx(expected_basis), "visual rock size is unchanged")
			var pose := Props.placed_pose(bounds,expected_basis,prop.center,-0.025)
			var visual := PackedVector2Array()
			for vertex in source.get_faces():
				var point: Vector3 = pose * vertex
				visual.append(Vector2(point.x,point.z))
			var visible_hull := Geometry2D.convex_hull(visual)
			for point in body.outline: check(Shape.polygon_distance(visible_hull,point) <= 0.0001, "walking hull does not extend beyond the visible rock")
			body.outline[0] = Vector2.INF
			check(Props.actor_shape(prop).outline[0].is_finite(), "callers cannot mutate the cached mesh outline")
	var tiny := {"id":"pebble","kind":"rock","center":Vector2.ZERO,"radius":0.16,"variant":0,"yaw":0.0,"family":0,"cover_role":Shape.LOW_RUBBLE}
	var body := Props.actor_shape(tiny)
	check(body.step_over and body.visual_height_m <= Props.STEP_OVER_HEIGHT_M, "low visual stone is classified as a step-over")
	var field = surface([])
	var layout: Dictionary = field.layout.duplicate(true)
	layout.rocks = [tiny]
	field = Surface.new({},layout,1.75)
	check(field.walkable(Vector2.ZERO) and field.travel(Vector2(-1,0),Vector2(1,0)) == Vector2(1,0), "tiny stones no longer stop a player's feet")
	check(field.projectile_block_fraction(Vector2(-1,0),Vector2(1,0),0.1) == INF, "low-rubble projectile semantics are unchanged")
	layout.water = [rectangle("water under pebble",Vector2(2,2))]
	layout.boundary.water = layout.water
	check(not Surface.new({},layout,1.75).walkable(Vector2.ZERO), "stepping over a pebble does not make water walkable")
	for family in [-1,0,1,2]:
		var tree := {"id":"tree","kind":"tree","center":Vector2.ZERO,"height":5.0,"variant":1,"yaw":0.5,"family":family}
		var trunk := Props.actor_shape(tree)
		var source := Props.mesh("tree",1,Art.profile(family+1),family+1,family)
		var bounds := source.get_aabb()
		var basis := Props.plant_basis(tree,bounds)
		var pose := Props.placed_pose(bounds,basis,tree.center)
		var crowns := PackedVector2Array()
		for vertex in source.get_faces():
			var point: Vector3 = pose * vertex
			crowns.append(Vector2(point.x,point.z))
		var crown: Dictionary = Shape.shape("visible tree","visual",Geometry2D.convex_hull(crowns))
		check(not trunk.step_over and trunk.bounds.get_area() < crown.bounds.get_area() * 0.6,
			"lower-trunk collision excludes the crown: family %d, trunk %s, crown %s" % [family,trunk.bounds.size,crown.bounds.size])
	var benchmark_shapes: Array = [Shape.disk("round","rock",Vector2.ZERO,0.6)]
	for index in 40:
		var prop := {"id":"benchmark_%d"%index,"kind":"rock","center":Vector2(index%8-4,index/8.0*2-5),"radius":0.4,"variant":index%4,"yaw":index*0.7,"family":index%3}
		benchmark_shapes.append(Props.actor_shape(prop))
	var clock := Time.get_ticks_usec()
	var benchmark = surface(benchmark_shapes)
	for peer in 4:
		var point := Vector2(-1.4,-0.65-peer*0.2)
		for _tick in 60: point = benchmark.slide(point,Vector2(4.0/60,0))
	print("ACTOR_COLLISION_METRICS ",JSON.stringify({"four_player_steps":240,"obstacles":benchmark_shapes.size(),"total_us":Time.get_ticks_usec()-clock}))
func run() -> void:
	var round_obstacle := Shape.disk("stone", "rock", Vector2.ZERO, 0.60)
	var field = surface([round_obstacle])
	slide_cases(field.slide, field.walkable, "Wilds")
	var axis := Vector2.from_angle(PI/4)
	var normal := axis.orthogonal()
	field = surface([rectangle("angled wall",Vector2(4,0.2),PI/4)])
	var start := normal * 0.56 - axis
	var end: Vector2 = field.slide(start, axis * 0.8 - normal * 0.5)
	check((end-start).dot(axis) > 0.65 and field.walkable(end), "angled wall preserves tangential movement")
	check(not field.travel(normal*2,-normal*2).is_equal_approx(-normal*2), "straight dash still stops at a wall")
	stability_cases()
	prop_cases()
	var scene := Preview.instantiate()
	root.add_child(scene)
	await process_frame
	var barrier = scene.expansion.barrier
	barrier.garden.layout.rocks = []
	barrier.garden.layout.plants = []
	barrier.bind(barrier.garden, false)
	barrier.visible_outline = rectangle("arena",Vector2(10,10)).outline
	barrier.buildings = []
	barrier.garden.occupied = []
	barrier.garden.layout.water = []
	barrier.construction = [round_obstacle]
	slide_cases(barrier.move, barrier.walkable, "Garden")
	check(barrier.move(Vector2(-2,-2),Vector2(NAN,0)) == Vector2(-2,-2), "invalid motion leaves a valid actor position unchanged")
	var model = scene.expansion.construction.model
	for yaw in [0.0,0.7,1.2]:
		var body: Dictionary = model.walking_footprint("bed",Vector2.ZERO,yaw)
		var reservation: Dictionary = model.footprint("bed",Vector2.ZERO,yaw)
		var corner := Vector2(1.2,0.9).rotated(yaw)
		barrier.construction = [body]
		check(Shape.signed_distance(reservation,corner) < Motion.RADIUS_M and barrier.walkable(corner), "rounded bed corners no longer stop a player at the rectangular reservation")
		check(not barrier.walkable(Vector2.ZERO), "cultivation beds remain physical obstacles despite their low rim")
	scene.free()
	if not failed: print("PASS: Garden/Wilds sliding, mesh-fitted rocks/trunks/buildings, low stones, frame rates, corners, bridges, bounded work and unchanged projectile cover")
	quit(1 if failed else 0)
