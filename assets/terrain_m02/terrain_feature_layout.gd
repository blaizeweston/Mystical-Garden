extends RefCounted
## Environmental layers in dependency order: water, landmarks, trails, stone, woodland.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Trails = preload("res://assets/terrain_m02/terrain_trail_network.gd")
const Planting = preload("res://assets/terrain_m02/terrain_feature_placement.gd")

static func build(cells: Dictionary, spacing: float, radius: int, seed_value: int, garden: bool, continuous: bool = false) -> Dictionary:
	var layout := {"water": [], "clearings": [], "paths": [], "crossings": [], "rocks": [],
		"rock_formations": [], "rock_buckets": {}, "stands": [], "plants": []}
	var water := _water(seed_value, spacing, radius, garden)
	layout.water.append(water)
	if garden:
		layout.clearings.append(Shape.disk("heart", "clearing", Vector2.ZERO, 3.65))
		var arrival := Vector2(-radius * spacing * 0.25, radius * spacing * 0.47)
		layout.clearings.append(Shape.disk("arrival", "clearing", arrival, 1.7))
		var trail_random := random_stream(seed_value, "garden_approach")
		var bend := trail_random.randf_range(-1.35, 0.4)
		var points := PackedVector2Array([arrival, arrival * 0.69 + Vector2(bend, 0),
			Vector2(-3.2, 4.0), Vector2(-1.2, 2.95)])
		if continuous:
			Trails.garden(layout, arrival, bend)
		else:
			layout.paths.append(_path("garden_approach", points, 0.61))
	else:
		_wilds_routes(layout, cells, spacing, radius, seed_value, continuous)
	if continuous:
		layout["ground_clearings"] = Trails.natural_clearings(layout.clearings, seed_value)
	Planting.populate(layout, cells, spacing, seed_value, garden)
	layout.erase("rock_buckets")
	return layout

static func random_stream(seed_value: int, stream: String) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = ("%d/%s" % [seed_value, stream]).hash()
	return random

static func _water(seed_value: int, spacing: float, radius: int, garden: bool) -> Dictionary:
	var random := random_stream(seed_value, "water")
	if garden:
		var at := Vector2(5.6, -2.7) * spacing
		at += Vector2(random.randf_range(-1.2, 1.2), random.randf_range(-1.2, 1.2))
		var phase := random.randf_range(0, TAU)
		var points := PackedVector2Array()
		for i in 52:
			var angle := TAU * i / 52.0
			var edge := 1.0 + 0.13 * sin(3 * angle + phase) + 0.07 * cos(5 * angle - phase)
			points.append(at + Vector2(cos(angle) * 3.05, sin(angle) * 2.42).rotated(phase * 0.36) * edge)
		return Shape.shape("sanctuary_pond", "pond", points)
	var profile := {"base": random.randf_range(0.3, 3.5),
		"bend": random.randf_range(2.7, 4.5), "phase": random.randf_range(0, TAU),
		"bias": random.randf_range(-0.14, 0.14), "pool": random.randf_range(-5.0, 5.0)}
	var spine := PackedVector2Array()
	var widths := PackedFloat32Array()
	var extent := radius * spacing * 0.93
	var samples := ceili(extent * 1.85)
	for i in range(samples + 1):
		var y := lerpf(-extent, extent, float(i) / samples)
		spine.append(Vector2(_river_x(y, profile), y))
		widths.append(1.31 + 0.27 * sin(0.29 * y - profile.phase) + 0.18 * cos(0.59 * y)
			+ 0.89 * exp(-pow((y - profile.pool) / 2.75, 2.0)))
	var river := Shape.ribbon("river_main", "river", spine, widths)
	river["profile"] = profile
	return river

static func _river_x(y: float, profile: Dictionary) -> float:
	return profile.base + profile.bend * sin(y * 0.20 + profile.phase) 		+ 1.05 * sin(y * 0.39 - profile.phase) + profile.bias * y

static func _wilds_routes(layout: Dictionary, cells: Dictionary, spacing: float, radius: int, seed_value: int, continuous: bool) -> void:
	var random := random_stream(seed_value, "clearings")
	var river: Dictionary = layout.water[0]
	var profile: Dictionary = river.profile
	var crossing_y := random.randf_range(-3.7, 3.7)
	# The approach is perpendicular to the river locally, then turns toward dry clearings.
	var middle := Vector2(_river_x(crossing_y, profile), crossing_y)
	var slope := (_river_x(crossing_y + 0.1, profile) - _river_x(crossing_y - 0.1, profile)) / 0.2
	var across := Vector2(1.0, -slope).normalized()
	var west := _clearing(cells, layout.water, spacing, middle - across * 7.5, "west_glade", 2.45)
	var east := _clearing(cells, layout.water, spacing, middle + across * 7.5, "east_glade", 2.6)
	var south_y := minf(radius * spacing * 0.45, crossing_y + 9.5)
	var south_hint := Vector2(_river_x(south_y, profile) - 8.6, south_y)
	var south := _clearing(cells, layout.water, spacing, south_hint, "fern_hollow", 2.6)
	layout.clearings.append_array([west, east, south])
	var west_bank := middle - across * 3.35
	var east_bank := middle + across * 3.35
	var fork_y: float = (south.center.y + west.center.y) * 0.5
	var fork_bend := Vector2(_river_x(fork_y, profile) - 7.6, fork_y)
	if continuous:
		Trails.wilds(layout, west.center, east.center, south.center, west_bank, east_bank, fork_bend)
		return
	var west_start: Vector2 = west.center
	var east_end: Vector2 = east.center
	var cross := PackedVector2Array([west_start,
		(west_start + west_bank) * 0.5 + across.orthogonal() * 0.65,
		west_bank, middle, east_bank,
		(east_end + east_bank) * 0.5 - across.orthogonal() * 0.65, east_end])
	layout.paths.append(_path("river_trail", cross, 0.68))
	var fork := PackedVector2Array([south.center, fork_bend, west.center])
	layout.paths.append(_path("hollow_trail", fork, 0.63))
	for path in layout.paths:
		var intersections := Geometry2D.intersect_polygons(path.outline, river.outline)
		for i in intersections.size():
			var crossing := Shape.shape("%s_crossing_%d" % [path.id, i], "crossing", intersections[i])
			if path.id == "river_trail" and Shape.contains(crossing, middle):
				crossing["bridge"] = PackedVector2Array([west_bank, east_bank])
			layout.crossings.append(crossing)

static func _clearing(cells: Dictionary, water: Array, spacing: float, hint: Vector2, id: String, radius: float) -> Dictionary:
	var chosen := hint
	var best := INF
	var ordered: Array = cells.keys()
	ordered.sort()
	for cell: Vector2i in ordered:
		var p := Grid.cell_to_world(cell, spacing)
		var offset := p.distance_squared_to(hint)
		if offset > 23.0 or Shape.in_any(water, p, radius + 0.5):
			continue
		var biome_cost := 0.0
		match cells[cell]:
			&"stone": biome_cost = 7.0
			&"forest_floor": biome_cost = 3.5
		if offset + biome_cost < best:
			best = offset + biome_cost
			chosen = p
	return Shape.disk(id, "clearing", chosen, radius)

static func _path(id: String, controls: PackedVector2Array, base_width: float) -> Dictionary:
	var spine := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in range(controls.size() - 1):
		var a := controls[maxi(i - 1, 0)]
		var b := controls[i]
		var c := controls[i + 1]
		var d := controls[mini(i + 2, controls.size() - 1)]
		var steps := maxi(3, ceili(b.distance_to(c) * 2.0))
		for step in steps:
			var t := float(step) / steps
			spine.append(b.cubic_interpolate(c, a, d, t))
			widths.append(base_width * (0.96 + 0.12 * sin(i * 1.8 + t * 2.1)))
	spine.append(controls[controls.size() - 1])
	widths.append(base_width)
	return Shape.ribbon(id, "path", spine, widths)

static func digest(layout: Dictionary) -> String:
	# All arrays and feature records are emitted in stable order. Floats use full precision.
	return JSON.stringify(layout, "", true, true).sha256_text()
