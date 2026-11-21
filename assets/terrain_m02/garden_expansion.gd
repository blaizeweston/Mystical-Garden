extends RefCounted
## A laboratory Garden owns a connected subset of the pre-existing terrain.
## Reclamation adds ownership records and moves the enclosure. Substrate and props stay put.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Boundary = preload("res://garden_boundary.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Features = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const DIRECTIONS := ["East", "Southeast", "South", "Southwest", "West", "Northwest", "North", "Northeast"]
const FOREST_SECTORS := 72
const MIN_GAIN := 7

var terrain: Dictionary
var layout: Dictionary
var spacing: float
var seed_value: int
var extent: float
var outline: PackedVector2Array
var owned := {}
var available := {}
var reserved_cells := {}
var landmarks := {}
var reserved: Array = []
var root_exclusions: Array = []
var occupied: Array = []
var construction_clearance: Array = []
var roots: Array[PackedVector2Array] = []
var revision := 0
var reclaimed_cells := 0
var expansion_history: Array[int] = []

func _init(cells: Dictionary, features: Dictionary, center_spacing: float, seed_number: int, radius: int, protected_landmarks: Array = []) -> void:
	terrain = cells
	layout = features
	spacing = center_spacing
	seed_value = seed_number
	extent = radius * spacing
	for item: Dictionary in layout.clearings:
		var id: String = "wilds_entrance" if item.id == "arrival" else item.id
		landmarks[id] = Shape.disk(id, "landmark", item.center, item.radius)
	landmarks["altar"] = Shape.disk("altar", "station", Vector2(4.20, 1.5), 1.06)
	landmarks["starter_bed"] = Shape.disk("starter_bed", "plot", Vector2(-4.30, -1.8), 1.15)
	landmarks["seed_archive"] = Shape.disk("seed_archive", "station", Vector2(5.45, -1.95), 0.86)
	landmarks["monster_studies"] = Shape.disk("monster_studies", "station", Vector2(-5.55, 0.95), 0.88)
	landmarks["living_archive"] = Shape.disk("living_archive", "station", Vector2(-0.90, -5.3), 0.97)
	if not protected_landmarks.is_empty():
		for id in ["starter_bed", "seed_archive", "monster_studies", "living_archive"]:
			landmarks.erase(id)
		for landmark: Dictionary in protected_landmarks:
			landmarks[landmark.id] = landmark
	reserved = landmarks.values() + layout.paths + layout.get("path_joins", [])
	root_exclusions = reserved.duplicate()
	root_exclusions.erase(landmarks.heart)
	for prop: Dictionary in layout.rocks:
		occupied.append(prop)
	for plant: Dictionary in layout.plants:
		if plant.kind in ["tree", "sapling"]:
			occupied.append(Shape.disk(plant.id, "trunk", plant.center, plant.height * 0.14))
	outline = _initial_outline()
	for cell: Vector2i in terrain:
		var at := Grid.cell_to_world(cell, spacing)
		if Geometry2D.is_point_in_polygon(at, outline):
			owned[cell] = 0
			if _clear(at, 0.35, outline):
				available[cell] = true
			elif Shape.in_any(reserved, at):
				reserved_cells[cell] = true

func _initial_outline() -> PackedVector2Array:
	var result := PackedVector2Array()
	var targets := PackedVector2Array()
	# Additional station art sits inside the original M11 sanctuary.
	var initial_landmarks: Array = landmarks.values() if not landmarks.has("starter_bed") else [
		landmarks.heart, landmarks.wilds_entrance, landmarks.altar, landmarks.starter_bed]
	for feature: Dictionary in initial_landmarks + layout.paths + layout.get("path_joins", []) + layout.water:
		if feature.get("requires_access",true):targets.append_array(Shape.boundary(feature))
	var entrance: Vector2 = landmarks.wilds_entrance.center
	var cove := Vector2.ZERO
	for feature: Dictionary in layout.water:
		cove = (feature.bounds as Rect2).get_center()
	for i in 120:
		var angle := TAU * i / 120.0
		var direction := Vector2.from_angle(angle)
		var distance := 7.75 + 0.64 * sin(angle * 3.0 + seed_value % 41) + 0.33 * sin(angle * 6.0)
		for center: Vector2 in [entrance, cove]:
			var alignment := maxf(0.0, direction.dot(center.normalized()))
			distance = maxf(distance, 7.6 + (center.length() + 5.0 - 7.6) * pow(alignment, 9.0))
		for point in targets:
			var lateral := absf(direction.cross(point))
			if lateral < 2.25:
				distance = maxf(distance, direction.dot(point) + 1.72 * cos(PI * lateral / 4.5))
		result.append(direction * distance)
	return result

func frontier_options() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for sector in DIRECTIONS.size():
		var candidate := proposal(sector)
		if not candidate.is_empty():
			choices.append(candidate)
	return choices

func proposal(sector: int, coverage_check: bool = false) -> Dictionary:
	if sector < 0 or sector >= DIRECTIONS.size():
		return {}
	var random := Features.random_stream(seed_value, "garden_growth_%d_%d" % [revision, sector])
	var base_angle := TAU * sector / DIRECTIONS.size() + random.randf_range(-0.16, 0.16)
	var touches_limit := false
	for adjustment in [0.0, -0.15, 0.15]:
		var aim := Vector2.from_angle(base_angle + adjustment)
		var frontier := edge_distance(outline, aim)
		var center := aim * (frontier + spacing * 1.13)
		var lobe := _lobe(center, aim, random)
		var merged := Geometry2D.merge_polygons(outline, lobe)
		if merged.size() != 1:
			continue
		if not _in_terrain(lobe):
			touches_limit = true
			continue
		var next_outline := Boundary.rounded_joins(merged[0])
		if not _in_terrain(next_outline):
			continue
		if _widens_gap(next_outline, aim):
			continue
		var candidates := _gain(lobe, next_outline)
		if candidates.size() < MIN_GAIN:
			continue
		var additions := Geometry2D.clip_polygons(lobe, outline)
		if additions.size() != 1:
			continue
		var ordered: Array = candidates.keys()
		ordered.sort_custom(func(a: Vector2i, b: Vector2i):
			var pa := Grid.cell_to_world(a, spacing)
			var pb := Grid.cell_to_world(b, spacing)
			var da := pa.dot(aim) - 0.75 * absf(aim.cross(pa))
			var db := pb.dot(aim) - 0.75 * absf(aim.cross(pb))
			return a < b if is_equal_approx(da, db) else da > db)
		for cell: Vector2i in ordered:
			var path := _root_to(Grid.cell_to_world(cell, spacing), aim, merged[0])
			if path.is_empty():
				continue
			return {"sector": sector, "revision": revision, "frontier": aim * frontier,
				"new_area": additions[0], "outline": next_outline, "cells": candidates, "root": path,
				"aim": aim, "area": candidates.size() * cell_area()}
	return {"coverage_limited": true} if coverage_check and touches_limit else {}

func _widens_gap(perimeter: PackedVector2Array, aim: Vector2) -> bool:
	# Keep one continuous forest ring. Reject skin-thin overlaps and sharp radial jumps
	# that would leave a visible seam in the tree verge.
	for lateral in [-spacing * 0.69, 0.0, spacing * 0.69]:
		var edge: Vector2 = aim * edge_distance(outline, aim) + aim.orthogonal() * lateral
		if Shape.polygon_distance(perimeter, edge, 0.9) > -0.62:
			return true
	var distances := enclosure_support(perimeter)
	for i in distances.size():
		if absf(distances[i] - distances[(i + 1) % distances.size()]) > spacing * 2.35:
			return true
	return false

func apply(proposed: Dictionary) -> bool:
	if proposed.is_empty() or proposed.get("revision", -1) != revision:
		return false
	var current := proposal(proposed.get("sector", -1))
	if current.is_empty() or current != proposed:
		return false
	revision += 1
	reclaimed_cells += current.cells.size()
	expansion_history.append(int(current.sector))
	outline = current.outline
	for cell: Vector2i in current.cells:
		owned[cell] = revision
		available[cell] = true
	roots.append(current.root)
	return true

func entrance_clear() -> bool:
	for path: Dictionary in layout.paths:
		for at: Vector2 in path.spine:
			if (Shape.polygon_distance(outline, at, 0.45) >= -0.40
					or Shape.in_any(layout.water, at, 0.40) or Shape.in_any(occupied, at, 0.40)):
				return false
	return true

func _lobe(center: Vector2, aim: Vector2, random: RandomNumberGenerator) -> PackedVector2Array:
	var result := PackedVector2Array()
	var depth := spacing * random.randf_range(2.85, 3.5)
	var width := spacing * random.randf_range(2.65, 3.68)
	var phase := random.randf() * TAU
	for i in 42:
		var angle := TAU * float(i) / 42.0
		var wave := 1.0 + 0.19 * sin(angle * 3.0 + phase) + 0.07 * cos(angle * 5.0 - phase)
		result.append(center + (aim * cos(angle) * depth + aim.orthogonal() * sin(angle) * width) * wave)
	return result

func _in_terrain(lobe: PackedVector2Array) -> bool:
	for point in lobe:
		if point.length() > extent * 0.81 or not terrain.has(Grid.world_to_cell(point, spacing)):
			return false
	return true

func _gain(lobe: PackedVector2Array, grown: PackedVector2Array) -> Dictionary:
	var bounds := Shape.shape("candidate", "clearing", lobe).bounds as Rect2
	var low := Grid.world_to_cell(Vector2(bounds.position.x, bounds.end.y), spacing) - Vector2i(2, 2)
	var high := Grid.world_to_cell(Vector2(bounds.end.x, bounds.position.y), spacing) + Vector2i(2, 2)
	var row_low := Grid.world_to_cell(bounds.position, spacing).y - 2
	var row_high := Grid.world_to_cell(bounds.end, spacing).y + 2
	var offered := {}
	for q in range(low.x, high.x + 1):
		for r in range(row_low, row_high + 1):
			var id := Vector2i(q, r)
			var at := Grid.cell_to_world(id, spacing)
			if (not owned.has(id) and terrain.has(id) and bounds.has_point(at)
					and Geometry2D.is_point_in_polygon(at, lobe) and _clear(at, spacing * 0.48, grown)):
				offered[id] = terrain[id]
	# Keep only a single component that connects through another clear sample.
	var seen := {}
	var best := {}
	for first: Vector2i in offered:
		if seen.has(first):
			continue
		var component := {first: offered[first]}
		var pending: Array[Vector2i] = [first]
		var connected := false
		seen[first] = true
		while not pending.is_empty():
			var current: Vector2i = pending.pop_front()
			for direction in Grid.NEIGHBORS:
				var next := current + direction
				if owned.has(next):
					connected = connected or available.has(next)
				elif offered.has(next) and not seen.has(next):
					seen[next] = true
					component[next] = offered[next]
					pending.append(next)
		if connected and component.size() > best.size():
			best = component
	return best

func _root_to(destination: Vector2, aim: Vector2, grown: PackedVector2Array) -> PackedVector2Array:
	for turn in [1.0, -1.0, 2.0, -2.0, 0.0]:
		var path := PackedVector2Array()
		var start := destination.normalized() * 0.75
		var distance := start.distance_to(destination)
		var steps := ceili(distance / 0.36)
		for i in range(steps + 1):
			var t := float(i) / steps
			var wave: float = sin(t * PI) * (0.65 + sin(t * 7.8) * 0.58) * turn
			var point := start.lerp(destination, t) + aim.orthogonal() * wave
			if not Geometry2D.is_point_in_polygon(point, grown) or Shape.in_any(layout.water, point, 0.36):
				break
			# Existing roots join the Heart itself. Only the central protection is exempt.
			if Shape.in_any(root_exclusions, point, 0.36):
				break
			if Shape.in_any(occupied, point, 0.36):
				break
			if Shape.in_any(construction_clearance, point, 0.36):
				break
			path.append(point)
		if path.size() == steps + 1:
			return path
	return PackedVector2Array()

func _clear(at: Vector2, radius: float, boundary: PackedVector2Array) -> bool:
	return (Shape.polygon_distance(boundary, at, radius + 0.02) < -radius
		and not Shape.in_any(layout.water, at, radius)
		and not Shape.in_any(occupied, at, radius)
		and not Shape.in_any(construction_clearance, at, radius)
		and not Shape.in_any(reserved, at, radius))

func suitability(at: Vector2, radius: float) -> Dictionary:
	var cell := Grid.world_to_cell(at, spacing)
	return {"usable": available.has(cell) and radius > 0.0 and _clear(at, radius, outline),
		"cell": cell, "terrain": terrain.get(cell, &""), "generation": owned.get(cell, -1)}

func cell_area() -> float:
	return spacing * spacing * sqrt(3.0) * 0.5

static func edge_distance(boundary: PackedVector2Array, direction: Vector2) -> float:
	var result := 0.0
	var previous := boundary[-1]
	for point in boundary:
		var a := direction.cross(previous)
		var b := direction.cross(point)
		if (a <= 0.0 and b > 0.0) or (b <= 0.0 and a > 0.0):
			result = maxf(result, direction.dot(previous.lerp(point, a / (a - b))))
		previous = point
	return result

func enclosure_support(boundary: PackedVector2Array = PackedVector2Array()) -> PackedFloat32Array:
	var perimeter := outline if boundary.is_empty() else boundary
	var raw := PackedFloat32Array()
	for i in FOREST_SECTORS:
		raw.append(edge_distance(perimeter, Vector2.from_angle(TAU * i / FOREST_SECTORS)))
	var distances := PackedFloat32Array()
	for i in FOREST_SECTORS:
		var distance := 0.0
		for step in range(-2, 3):
			var reach := raw[posmod(i + step, FOREST_SECTORS)]
			distance = maxf(distance, reach - absf(step) * 1.32)
		distances.append(distance)
	return distances

func scenic_woodland() -> Array[Dictionary]:
	var trees: Array[Dictionary] = []
	# This band is beyond every legal frontier and is never updated by expansion.
	for row in 5:
		var count := 54 + row * 21
		for i in count:
			var random := Features.random_stream(seed_value, "garden_exterior_%d_%d" % [row, i])
			var direction := Vector2.from_angle(TAU * (i + random.randf_range(-0.34, 0.34)) / count)
			var distance := extent * 0.83 + 5.7 + row * 5.2 + random.randf_range(-2.0, 2.4)
			trees.append({"at": direction * distance, "height": random.randf_range(4.2, 8.0),
				"crown": random.randf_range(1.26, 1.95), "variant": i % 4, "yaw": random.randf_range(0.0, TAU)})
	return trees

func forest_layout() -> Dictionary:
	var result := {"enclosure": [], "accents": [], "woodland_ferns": [], "movable_rim": true}
	for sector in FOREST_SECTORS:
		var random := Features.random_stream(seed_value, "garden_edge_%d" % sector)
		var angle := TAU * sector / FOREST_SECTORS
		var direction := Vector2.from_angle(angle)
		var foreground := smoothstep(0.18, 0.9, direction.dot(Vector2(0.23, 0.973)))
		for row in 4:
			var depth: float = [1.28, 3.85, 6.75, 10.7][row]
			var stagger := (0.48 if row % 2 != 0 else -0.34) * sin(sector * 1.71 + row)
			var at := direction * (depth + random.randf_range(0.0, 0.95)) + direction.orthogonal() * stagger
			var height := random.randf_range(5.0, 7.3) * lerpf(1.0, 0.58, foreground)
			if row >= 2:
				height *= random.randf_range(0.85, 1.28)
			result.enclosure.append({"id": "growth_rim_%d_%d" % [sector, row], "at": at, "sector": sector,
				"height": height, "crown": random.randf_range(1.62, 2.15),
				"variant": (sector + row) % 4, "yaw": random.randf_range(0.0, TAU)})
		if sector % 3 == 0:
			result.accents.append({"id": "root_verge_%d" % sector, "at": direction * 1.18, "sector": sector,
				"size": random.randf_range(1.4, 2.3), "yaw": angle + 0.45})
			result.accents.append({"id": "woodland_deadwood_%d" % sector, "at": direction * 4.2, "sector": sector,
				"size": random.randf_range(1.8, 2.9), "yaw": angle - random.randf_range(0.1, 1.7), "unlit": true})
		for patch in 3:
			var at := direction * (2.5 + patch * 2.4 + random.randf_range(-0.35, 0.8))
			at += direction.orthogonal() * random.randf_range(-1.05, 1.05)
			result.woodland_ferns.append({"at": at, "sector": sector,
				"size": random.randf_range(0.9, 2.1), "yaw": random.randf_range(0.0, TAU)})
	return result

func release_structure_landmarks() -> void:
	# Construction becomes the sole placement/collision authority for owned beds/altar.
	for id: String in landmarks.keys():
		if id == "altar" or id.begins_with("bed_") or id.begins_with("owned_bed_"):
			reserved.erase(landmarks[id])
			root_exclusions.erase(landmarks[id])
			landmarks.erase(id)
	refresh_owned_cells()

func refresh_owned_cells() -> void:
	available.clear()
	reserved_cells.clear()
	for cell: Vector2i in owned:
		var at := Grid.cell_to_world(cell, spacing)
		if _clear(at, 0.35, outline):
			available[cell] = true
		elif Shape.in_any(reserved, at):
			reserved_cells[cell] = true
