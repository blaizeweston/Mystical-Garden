extends RefCounted
## Reserve the exploration network before growing walls or woodland around it.

const Geo = preload("res://assets/terrain_m02/wilds_geography.gd")
const Trails = preload("res://assets/terrain_m02/terrain_trail_network.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Seed = preload("res://assets/terrain_m02/terrain_feature_layout.gd")

static func expand(layout: Dictionary, seed_value: int, radius: int, spacing: float) -> Dictionary:
	var original: Dictionary = layout.trail_network
	var random := Seed.random_stream(seed_value, "wilds_chambers")
	var side := -1.0
	var unit := float(radius) * spacing / 24.5
	var water: Dictionary = layout.water[0]
	var nodes: Dictionary = original.nodes.duplicate()
	nodes["exit_gate"] = nodes.far_glade
	nodes.erase("far_glade")
	var edges: Array[Dictionary] = []
	for edge in original.edges:
		var copy: Dictionary = edge.duplicate()
		if copy.to == "far_glade":
			copy.to = "exit_gate"
		edges.append(copy)
	var clearings: Array = layout.clearings.duplicate(true)
	clearings[2].id = "exit_gate"
	# Try the wider loop first, then a more compact route through the same bank.
	for width in [6.5, 5.6, 4.7, 3.9]:
		var trial_nodes: Dictionary = nodes.duplicate()
		var trial_edges := edges.duplicate()
		var trial_clearings := clearings.duplicate()
		var a: Vector2 = nodes.arrival
		var b: Vector2 = nodes.terrace
		var mid_z := lerpf(a.y, b.y, 0.55)
		var mid := Vector2(minf(a.x, b.x) + side * width * unit, mid_z)
		trial_nodes["side_chamber"] = mid
		trial_clearings.append(Shape.disk("side_chamber", "optional", mid, 2.05))
		var verge := random.randf_range(0.72, 1.24)
		var lead := Vector2(mid.x + verge * unit, lerpf(a.y, mid.y, 0.45))
		var tail := Vector2(mid.x + unit, lerpf(mid.y, b.y, 0.63))
		trial_edges.append(Trails._edge("outer_approach", "arrival", "side_chamber", PackedVector2Array([lead]), 0.95))
		trial_edges.append(Trails._edge("outer_return", "side_chamber", "terrace", PackedVector2Array([tail]), 0.95))
		var trial := _with_routes(layout, trial_nodes, trial_edges, trial_clearings, seed_value, radius, spacing)
		if not trial.is_empty():
			nodes = trial_nodes
			edges = trial_edges
			clearings = trial_clearings
			layout = trial
			break
	# Where a dry island exists, test shore-to-island spans on two sides. A long
	# bridge still connects the mainland even when an optional island spur fails validation.
	for hole: PackedVector2Array in water.get("holes", []):
		var center := Vector2.ZERO
		for point in hole:
			center += point
		center /= hole.size()
		if Shape.polygon_distance(hole, center) > -0.86:
			continue
		var bank_y := center.y
		var left := _shore(water, center, -1.0)
		var right := _shore(water, center, 1.0)
		if not is_finite(left.x) or not is_finite(right.x):
			continue
		for both in [true, false]:
			var more_nodes: Dictionary = nodes.duplicate()
			var more_edges := edges.duplicate()
			var more_clearings := clearings.duplicate()
			more_nodes["island"] = center
			more_nodes["island_west"] = left
			more_clearings.append(Shape.disk("island", "optional", center, 0.70))
			var west_bridge := Trails._edge("island_west_bridge", "island_west", "island", PackedVector2Array(), 0.76)
			west_bridge["bridge"] = true
			var via_w := Vector2(minf(left.x, nodes.terrace.x) - 0.7, lerpf(bank_y, nodes.terrace.y, 0.5))
			more_edges.append(Trails._edge("island_west_approach", "terrace", "island_west", PackedVector2Array([via_w]), 0.84))
			more_edges.append(west_bridge)
			if both:
				more_nodes["island_east"] = right
				var east_bridge := Trails._edge("island_east_bridge", "island", "island_east", PackedVector2Array(), 0.76)
				east_bridge["bridge"] = true
				var via_e := Vector2(maxf(right.x, nodes.exit_gate.x) + 0.7, lerpf(bank_y, nodes.exit_gate.y, 0.5))
				more_edges.append(Trails._edge("island_east_approach", "island_east", "exit_gate", PackedVector2Array([via_e]), 0.84))
				more_edges.append(east_bridge)
			var trial := _with_routes(layout, more_nodes, more_edges, more_clearings, seed_value, radius, spacing)
			if not trial.is_empty():
				return trial
	return _with_routes(layout, nodes, edges, clearings, seed_value, radius, spacing)

static func _with_routes(layout: Dictionary, nodes: Dictionary, edges: Array[Dictionary], clearings: Array,
		seed_value: int, radius: int, spacing: float) -> Dictionary:
	var trial := layout.duplicate()
	trial.clearings = clearings
	trial.paths = []
	trial.crossings = []
	Trails._set_graph(trial, nodes, edges)
	var water: Dictionary = trial.water[0]
	for clearing in clearings:
		if Shape.in_any(trial.water, clearing.center, clearing.radius + 0.06):
			return {}
		for point in Shape.boundary(clearing):
			if not Geo._inside_disk(point, radius, spacing):
				return {}
	for i in trial.paths.size():
		var path: Dictionary = trial.paths[i]
		var edge: Dictionary = edges[i]
		if Geometry2D.triangulate_polygon(path.outline).is_empty():
			return {}
		for point in path.outline:
			if not Geo._inside_disk(point, radius, spacing):
				return {}
		if edge.get("bridge", false):
			var spine: PackedVector2Array = path.spine
			if Shape.in_any(trial.water, spine[0], 0.75) or Shape.in_any(trial.water, spine[-1], 0.75):
				return {}
			var wet := false
			for point in spine:
				wet = wet or Shape.contains(water, point)
			if not wet:
				return {}
		elif not Geometry2D.intersect_polygons(path.outline, water.outline).is_empty():
			return {}
	for cap in trial.path_joins:
		for point in cap.outline:
			if Shape.contains(water, point) or not Geo._inside_disk(point, radius, spacing):
				return {}
	trial["ground_clearings"] = Trails.natural_clearings(clearings, seed_value)
	return trial

static func _shore(water: Dictionary, center: Vector2, side: float) -> Vector2:
	var crossed := false
	for i in range(1, 97):
		var at := center + Vector2(side * i * 0.22, 0.0)
		var gap := Shape.signed_distance(water, at, 2.0)
		crossed = crossed or gap < 0.0
		if crossed and gap > 1.2:
			return at
	return Vector2(INF, INF)
