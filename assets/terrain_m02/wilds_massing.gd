extends RefCounted
## Environmental walls are connected ribbons. A fragment is rejected unless long enough to read as one mass.

const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Geo = preload("res://assets/terrain_m02/wilds_geography.gd")
const Biomes = preload("res://assets/terrain_m02/wilds_biome.gd")
const Stream = preload("res://assets/terrain_m02/terrain_feature_layout.gd")

static func build(layout: Dictionary, seed_value: int, radius: int, spacing: float, climate: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var random := Stream.random_stream(seed_value, "wilds_mass")
	var bounds := float(radius) * spacing
	# Broad sweeping walls along two banks and transverse chamber rims. Intersections
	# with reservations are deliberate openings, not random gaps between props.
	for row in 19:
		var west := row % 2 == 0
		var side := -1.0 if west else 1.0
		var group := row / 2
		var shift := random.randf_range(-0.65, 0.65)
		var spine := PackedVector2Array()
		for j in 45:
			var t := float(j) / 44.0
			var z := (t - 0.50) * bounds * 1.48
			var x := side * (4.8 + group * 3.9 + shift) * bounds / 24.5 \
				+ 1.37 * sin(t * TAU * 1.45 + row * 0.73 + shift)
			if group >= 5:
				x = (t - 0.52) * bounds * 1.4 + shift
				z = side * (8.7 + (group - 5) * 4.8) * bounds / 24.5 + 1.3 * cos(t * TAU * 1.33 + shift)
			if row >= 14 and row < 17:
				var strut := row - 14
				var clearing: Dictionary = layout.clearings[strut]
				var room: Vector2 = clearing.center
				x = room.x + (t - 0.40) * bounds * 0.63 + 0.8 * sin(t * TAU)
				z = room.y + (4.1 if strut != 0 else -4.5) + 1.0 * sin(t * 5.0 + shift)
			if row >= 17:
				# Grow chamber islands inside the dry bypass loop, enclosing both routes
				# without forcing the arrival or terrace through a single corridor.
				var chamber: Vector2 = layout.trail_network.nodes.get("side_chamber", Vector2(-12, 0))
				var landing: Vector2 = layout.trail_network.nodes.west_bank
				var center := chamber.lerp(landing, 0.44 if row == 17 else 0.30)
				x = center.x + (0.95 if row == 18 else 0.0) + 0.9 * sin(t * 4.8 + shift)
				z = center.y + (t - 0.5) * bounds * 0.40
			spine.append(Vector2(x, z))
		var family := Biomes.family(climate.weights, random.randf())
		var width := lerpf(0.91, 1.43, climate.weights.z) + random.randf_range(-0.10, 0.18)
		_place_segments(result, layout, spine, row, family, width, radius, spacing)
	return result

static func _place_segments(result: Array[Dictionary], layout: Dictionary, guide: PackedVector2Array,
		row: int, family: int, width: float, radius: int, spacing: float) -> void:
	var run := PackedVector2Array()
	var chunk := 0
	for j in range(guide.size() + 1):
		var fits := j < guide.size() and _free(layout, result, guide[j], width + 0.10, radius, spacing)
		if fits:
			run.append(guide[j])
			continue
		if run.size() > 4 and run[0].distance_to(run[-1]) > 3.3:
			var widths := PackedFloat32Array()
			for i in run.size():
				var t := float(i) / (run.size() - 1)
				widths.append(width * (0.46 + 0.54 * pow(sin(t * PI), 0.45)))
			var id := "mass_%d_%d" % [row, chunk]
			var ribbon := Shape.ribbon(id, ["grove", "mire", "hollow"][family], run, widths)
			if _valid_outline(ribbon, layout, result, radius, spacing):
				ribbon["family"] = family
				result.append(ribbon)
				chunk += 1
		run = PackedVector2Array()

static func _valid_outline(formation: Dictionary, layout: Dictionary, existing: Array[Dictionary],
		radius: int, spacing: float) -> bool:
	if Geometry2D.triangulate_polygon(formation.outline).is_empty():
		return false
	for point in formation.outline:
		if not Geo._inside_disk(point, radius, spacing):
			return false
	for region in layout.paths + layout.path_joins + layout.clearings + existing:
		if not formation.bounds.intersects(region.bounds):
			continue
		if not Geometry2D.intersect_polygons(formation.outline, Shape.boundary(region)).is_empty():
			return false
	# Test the computed shoreline, including any dry island holes.
	var outline: PackedVector2Array = formation.outline
	for i in outline.size():
		for t in [0.0, 0.5]:
			var point := outline[i].lerp(outline[(i + 1) % outline.size()], t)
			if Shape.in_any(layout.water, point):
				return false
	return true

static func _free(layout: Dictionary, existing: Array[Dictionary], at: Vector2, pad: float,
		radius: int, spacing: float) -> bool:
	if Shape.in_any(layout.water, at, pad) or Shape.in_trails(layout, at, pad + 0.34) \
			or Shape.in_any(layout.clearings, at, pad + 0.38) or Shape.in_any(existing, at, pad + 0.32):
		return false
	for i in 6:
		if not Geo._inside_disk(at + Vector2.from_angle(i * TAU / 6.0) * pad, radius, spacing):
			return false
	return true
