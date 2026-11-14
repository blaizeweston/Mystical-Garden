extends RefCounted
## Continuous X/Z queries for the terrain lab. Sight crosses water; feet need a bridge.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const CLEARANCE := 0.34
const SAMPLE_STEP := 0.13

var cells: Dictionary
var spacing: float
var layout: Dictionary
var blockers: Array = []
var arena := {}
var water: Array

func _init(labels: Dictionary, features: Dictionary, cell_spacing: float) -> void:
	cells = labels
	layout = features
	spacing = cell_spacing
	blockers = layout.masses + layout.rocks
	water = layout.water
	if layout.has("boundary"):
		arena = layout.boundary.playable
		water = layout.boundary.water
		for strip in layout.boundary.rim:
			if not strip.wet:
				blockers.append(strip)
	for plant in layout.plants:
		if plant.kind == "tree" and not plant.has("on_mass"):
			blockers.append(Shape.disk(plant.id, "trunk", plant.center, plant.height * 0.105))

func walkable(point: Vector2, radius: float = CLEARANCE) -> bool:
	if not arena.is_empty():
		if Shape.signed_distance(arena, point, radius + 0.01) >= -radius:
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
	elif not Shape.contains(arena, from) or not Shape.contains(arena, to):
		return false
	var bounds := Rect2(min_point, max_point - min_point).grow(radius + 0.001)
	for block in blockers:
		if not bounds.intersects(block.bounds):
			continue
		if _hits_block(from, to, radius, block):
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
