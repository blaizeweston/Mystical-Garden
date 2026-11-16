extends RefCounted
## Continuous X/Z queries for the terrain lab. Sight crosses water; feet need a bridge.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const CLEARANCE := 0.34
const SAMPLE_STEP := 0.13
const EDGE_BUCKET_SIZE := 2.0

var cells: Dictionary
var spacing: float
var layout: Dictionary
var blockers: Array = []
var projectile_cover: Array = []
var arena := {}
var water: Array
var arena_outline := PackedVector2Array()
var arena_edges := {}

func _init(labels: Dictionary, features: Dictionary, cell_spacing: float) -> void:
	cells = labels
	layout = features
	spacing = cell_spacing
	blockers = layout.masses + layout.rocks
	water = layout.water
	if layout.has("boundary"):
		arena = layout.boundary.playable
		arena_outline = arena.outline
		_index_arena_edges()
		water = layout.boundary.water
		for strip in layout.boundary.rim:
			if not strip.wet:
				blockers.append(strip)
	for plant in layout.plants:
		if plant.kind == "tree" and not plant.has("on_mass"):
			blockers.append(Shape.disk(plant.id, "trunk", plant.center, plant.height * 0.105))
	for block: Dictionary in blockers:
		if block.get("cover_role", Shape.SOLID_COVER) != Shape.LOW_RUBBLE:
			projectile_cover.append(block)

# Ranged and sight clearance share solid footprints. Actor queries keep every blocker.
func projectile_block_fraction(from: Vector2, to: Vector2, radius: float) -> float:
	var fraction := _ranged_boundary(from, to, radius)
	var bounds := Rect2(from.min(to), (to - from).abs()).grow(radius + Shape.TRACE_EPSILON)
	for block in projectile_cover:
		if bounds.intersects(block.bounds, true):
			fraction = minf(fraction, Shape.cover_entry(block, from, to, radius))
	return fraction

func combat_sight(from: Vector2, to: Vector2) -> bool:
	return projectile_block_fraction(from, to, 0.0) == INF

func _ranged_boundary(from: Vector2, to: Vector2, radius: float) -> float:
	if not arena_outline.is_empty():
		if not Geometry2D.is_point_in_polygon(from, arena_outline):
			return 0.0
		# The first edge contact stops a shot, even when its endpoint is inside a concave arena.
		return Shape.outline_entry(arena_outline, from, to, radius)
	# Older laboratory layouts have cells but no compiled playable outline.
	var count := maxi(1, ceili(from.distance_to(to) / SAMPLE_STEP))
	for i in count + 1:
		var fraction := float(i) / count
		if not cells.has(Grid.world_to_cell(from.lerp(to, fraction), spacing)):
			return fraction
	return INF

func walkable(point: Vector2, radius: float = CLEARANCE) -> bool:
	if not arena.is_empty():
		if not _contains_clearance(point, radius):
			return false
	else:
		if not cells.has(Grid.world_to_cell(point, spacing)):
			return false
		for direction in Grid.NEIGHBORS:
			var offset := Grid.cell_to_world(direction, 1.0) * radius
			if not cells.has(Grid.world_to_cell(point + offset, spacing)):
				return false
	if Shape.in_any(blockers, point, radius):
		return false
	for wet in water:
		# When a disk overlaps water, its entire footprint must fit on a deck.
		if Shape.signed_distance(wet, point, radius + 0.01) > radius:
			continue
		var on_deck := false
		for deck in layout.crossings:
			if Shape.signed_distance(deck, point, radius + 0.01) < -radius:
				on_deck = true
				break
		if not on_deck:
			return false
	return true

func clear_line(from: Vector2, to: Vector2, radius: float = 0.0) -> bool:
	var min_point := from.min(to)
	var max_point := from.max(to)
	if arena.is_empty():
		if not cells.has(Grid.world_to_cell(from, spacing)) or not cells.has(Grid.world_to_cell(to, spacing)):
			return false
	elif not Geometry2D.is_point_in_polygon(from, arena_outline) or not Geometry2D.is_point_in_polygon(to, arena_outline):
		return false
	var bounds := Rect2(min_point, max_point - min_point).grow(radius + 0.001)
	for block in blockers:
		if not bounds.intersects(block.bounds):
			continue
		if _hits_block(from, to, radius, block):
			return false
	return true

func _edge_bucket(point: Vector2) -> Vector2i:
	return Vector2i((point / EDGE_BUCKET_SIZE).floor())

func _index_arena_edges() -> void:
	var previous := arena_outline[-1]
	for point in arena_outline:
		var first := _edge_bucket(previous.min(point))
		var last := _edge_bucket(previous.max(point))
		var edge := PackedVector2Array([previous, point])
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var bucket := Vector2i(x, y)
				if not arena_edges.has(bucket):
					arena_edges[bucket] = []
				arena_edges[bucket].append(edge)
		previous = point

func _contains_clearance(point: Vector2, radius: float) -> bool:
	if not Geometry2D.is_point_in_polygon(point, arena_outline):
		return false
	# Distance still uses the exact shared polygon. Only nearby edges can overlap the disk.
	var extent := Vector2.ONE * radius
	var first := _edge_bucket(point - extent)
	var last := _edge_bucket(point + extent)
	var limit := radius * radius
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for edge: PackedVector2Array in arena_edges.get(Vector2i(x, y), []):
				var nearest := Geometry2D.get_closest_point_to_segment(point, edge[0], edge[1])
				if point.distance_squared_to(nearest) <= limit:
					return false
	return true

func _hits_block(from: Vector2, to: Vector2, radius: float, block: Dictionary) -> bool:
	var limit := radius * radius
	if block.has("radius"):
		var closest := Geometry2D.get_closest_point_to_segment(block.center, from, to)
		return closest.distance_squared_to(block.center) <= pow(radius + block.radius, 2)
	if Shape.contains(block, from) or Shape.contains(block, to):
		return true
	var previous: Vector2 = block.outline[-1]
	for point: Vector2 in block.outline:
		var pair := Geometry2D.get_closest_points_between_segments(from, to, previous, point)
		if pair[0].distance_squared_to(pair[1]) <= limit + 0.000001:
			return true
		previous = point
	return false

func travel(from: Vector2, to: Vector2, radius: float = CLEARANCE) -> Vector2:
	var count := maxi(1, ceili(from.distance_to(to) / SAMPLE_STEP))
	var last := from
	for i in range(1, count + 1):
		var point := from.lerp(to, float(i) / count)
		if not walkable(point, radius) or not clear_line(last, point, radius):
			break
		last = point
	return last

func slide(from: Vector2, delta: Vector2) -> Vector2:
	var target := from + delta
	var straight := travel(from, target)
	if straight.is_equal_approx(target):
		return straight
	var x := travel(straight, straight + Vector2(target.x - straight.x, 0.0))
	var z := travel(straight, straight + Vector2(0.0, target.y - straight.y))
	return x if x.distance_squared_to(target) < z.distance_squared_to(target) else z

func reachable_nodes() -> Dictionary:
	# Certify continuous motion along each authored edge, then flood the certified graph.
	var graph: Dictionary = layout.trail_network
	var neighbors := {}
	for id in graph.nodes:
		neighbors[id] = []
	for i in graph.edges.size():
		var edge: Dictionary = graph.edges[i]
		var path: Dictionary = layout.paths[i]
		var spine: PackedVector2Array = path.spine
		var valid := walkable(spine[0])
		for j in range(1, spine.size()):
			if not valid or not travel(spine[j - 1], spine[j]).is_equal_approx(spine[j]):
				valid = false
				break
		if valid:
			neighbors[edge.from].append(edge.to)
			neighbors[edge.to].append(edge.from)
	var reached := {"arrival": true}
	var pending := ["arrival"]
	while not pending.is_empty():
		for id in neighbors[pending.pop_back()]:
			if not reached.has(id):
				reached[id] = true
				pending.append(id)
	return reached
