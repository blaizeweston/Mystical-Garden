extends RefCounted
## One coherent channel system with shaped banks and an emergent wetland island.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Streams = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Trails = preload("res://assets/terrain_m02/terrain_trail_network.gd")
const TRIES := 4
const TRAIL_WIDTH := 0.76
const BANK_BUFFER := 1.25

static func compose(seed_value: int, radius: int, spacing: float, climate: Dictionary) -> Dictionary:
	var random := Streams.random_stream(seed_value, "wilds_valley")
	var extent := radius * spacing * sqrt(3.0) * 0.5
	var unit := extent / 21.2
	var valley := {"offset": random.randf_range(-2.0, 1.8), "phase": random.randf_range(-PI, PI),
		"scale": unit, "extent": extent, "crossing": random.randf_range(-1.65, 1.65) * unit,
		"island": random.randf_range(-8.1, -5.8) * unit, "climate": climate}
	valley.phase += (climate.floor_number - 1) * 0.028
	valley.crossing += (climate.floor_number - 1) * 0.032 * unit
	for attempt in TRIES:
		# Narrow lobes and relax route bends on bounded retries. Keep the same valley and seed.
		valley["repair"] = attempt
		var water := _water(valley)
		var layout := {"water": [water], "clearings": [], "paths": [], "crossings": [],
			"plants": [], "rocks": [], "enclosure": [], "accents": [], "formations": [],
			"repair": attempt}
		_routes(layout, valley)
		if _valid(layout, radius, spacing):
			layout["ground_clearings"] = Trails.natural_clearings(layout.clearings, seed_value)
			return layout
	return {}

static func _center(z: float, valley: Dictionary) -> float:
	var scale: float = valley.scale
	var p := z / scale
	return scale * (valley.offset * 0.62 + valley.climate.river_offset + 1.72 * sin(p * 0.222 + valley.phase)
		+ 0.56 * sin(p * 0.42 - valley.phase))

static func _width(z: float, valley: Dictionary) -> float:
	var scale: float = valley.scale
	var p := z / scale
	var island: float = valley.island / scale
	var repair_scale := 1.0 - 0.14 * int(valley.repair)
	# Linked pool lobes widen the same continuous strip of water. The cross-section never vanishes.
	var pools := exp(-pow((p - island) / 3.8, 2.0)) + 0.77 * exp(-pow((p - island - 12.0) / 4.4, 2.0))
	return scale * (valley.climate.width + 0.15 * sin(p * 0.54 + valley.phase)
		+ valley.climate.pools * pools * repair_scale)

static func _water(valley: Dictionary) -> Dictionary:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var count := ceili(2.0 * valley.extent / 0.46)
	for i in count + 1:
		# End a little beyond the disk so the stream meets the edge cleanly.
		var z := lerpf(-valley.extent - 1.0, valley.extent + 1.0, float(i) / count)
		var x := _center(z, valley)
		var width := _width(z, valley)
		left.append(Vector2(x - width, z))
		right.append(Vector2(x + width, z))
	right.reverse()
	left.append_array(right)
	var water := Shape.shape("valley_water", "watercourse", left)
	var emergence := smoothstep(0.27, 0.94, valley.climate.weights.y)
	if emergence > 0.0:
		var points := PackedVector2Array()
		for i in 32:
			var angle := TAU * i / 32
			var warp := 1.0 + 0.13 * sin(angle * 3 + valley.phase) + 0.10 * sin(angle * 5)
			var z: float = valley.island + sin(angle) * 2.88 * valley.scale * emergence * warp
			points.append(Vector2(_center(z, valley) + cos(angle) * _width(z, valley) * 0.46 * emergence * warp, z))
		water["holes"] = [points]
	return water

static func _bank(z: float, side: float, distance: float, valley: Dictionary) -> Vector2:
	return Vector2(_center(z, valley) + side * (_width(z, valley) + distance), z)

static func _routes(layout: Dictionary, valley: Dictionary) -> void:
	var z: float = valley.crossing
	var spread: float = valley.scale
	var west := _landing(z, -1.0, valley)
	var east := _landing(z, 1.0, valley)
	var size := lerpf(2.55, 2.20, valley.climate.weights.z)
	var arrival := _bank(8.9 * spread, -1.0, size + 2.35, valley)
	var terrace := _bank(-7.3 * spread, -1.0, size + 2.25, valley)
	var far := _bank(-3.3 * spread, 1.0, size + 2.08, valley)
	var nodes := {"arrival": arrival, "terrace": terrace, "far_glade": far, "west_bank": west, "east_bank": east}
	for id in ["arrival", "terrace", "far_glade"]:
		layout.clearings.append(Shape.disk(id, "reserved", nodes[id], size))
	var edges: Array[Dictionary] = [
		Trails._edge("approach", "arrival", "west_bank", _verge(arrival.y, z, -1.0, valley), TRAIL_WIDTH),
		Trails._edge("terrace_trail", "west_bank", "terrace", _verge(z, terrace.y, -1.0, valley), TRAIL_WIDTH),
		Trails._edge("east_trail", "east_bank", "far_glade", _verge(z, far.y, 1.0, valley), TRAIL_WIDTH),
	]
	var deck := Trails._edge("bank_crossing", "west_bank", "east_bank", PackedVector2Array(), TRAIL_WIDTH)
	deck["bridge"] = true
	edges.append(deck)
	Trails._set_graph(layout, nodes, edges)

static func _landing(z: float, side: float, valley: Dictionary) -> Vector2:
	var at := _bank(z, side, BANK_BUFFER, valley)
	for step in [-1.0, 1.0]:
		var verge := _bank(z + step * TRAIL_WIDTH, side, BANK_BUFFER, valley)
		at.x = maxf(at.x, verge.x) if side > 0.0 else minf(at.x, verge.x)
	return at

static func _verge(from: float, to: float, side: float, valley: Dictionary) -> PackedVector2Array:
	var via := PackedVector2Array()
	for t in [0.27, 0.58, 0.81]:
		var z := lerpf(from, to, t)
		var drift: float = (1.0 - 0.20 * valley.repair) * sin(t * TAU + valley.phase)
		via.append(_bank(z, side, 2.15 + drift * 0.57, valley))
	return via

static func _valid(layout: Dictionary, radius: int, spacing: float) -> bool:
	var water: Dictionary = layout.water[0]
	for clearing in layout.clearings:
		if Shape.in_any(layout.water, clearing.center, clearing.radius + 0.05):
			return false
		for point in Shape.boundary(clearing):
			if not _inside_disk(point, radius, spacing):
				return false
	for hole: PackedVector2Array in water.get("holes", []):
		for point in hole:
			if Shape.polygon_distance(water.outline, point) >= -0.12:
				return false
	var deck: Dictionary = layout.crossings[0]
	var span: PackedVector2Array = deck.bridge
	if Shape.in_any(layout.water, span[0], TRAIL_WIDTH) or Shape.in_any(layout.water, span[1], TRAIL_WIDTH) \
			or not Shape.contains(water, span[0].lerp(span[1], 0.5)):
		return false
	for cap in layout.path_joins:
		if not Geometry2D.intersect_polygons(cap.outline, water.outline).is_empty():
			return false
	for path in layout.paths:
		if Geometry2D.triangulate_polygon(path.outline).is_empty():
			return false
		for point in path.outline:
			if not _inside_disk(point, radius, spacing):
				return false
		if path.id != "bank_crossing" and not Geometry2D.intersect_polygons(path.outline, water.outline).is_empty():
			return false
	return true

static func _inside_disk(point: Vector2, radius: int, spacing: float) -> bool:
	var cell := Grid.world_to_cell(point, spacing)
	return maxi(maxi(absi(cell.x), absi(cell.y)), absi(cell.x + cell.y)) <= radius
