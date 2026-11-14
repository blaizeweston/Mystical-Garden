extends RefCounted
## Aggregate woodland by connected terrain and populate features after exclusions.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")

static func populate(layout: Dictionary, cells: Dictionary, spacing: float, seed_value: int, garden: bool) -> void:
	var ordered: Array = cells.keys()
	ordered.sort()
	_rocks(layout, cells, ordered, spacing, seed_value, garden)
	var seen := {}
	for first: Vector2i in ordered:
		if cells[first] != &"forest_floor" or seen.has(first):
			continue
		var component: Array[Vector2i] = [first]
		seen[first] = true
		var i := 0
		while i < component.size():
			var cell := component[i]
			i += 1
			for direction in Grid.NEIGHBORS:
				var next := cell + direction
				if not seen.has(next) and cells.get(next) == &"forest_floor":
					seen[next] = true
					component.append(next)
		if component.size() < 2:
			continue
		component.sort()
		var id := "stand_%d_%d" % [first.x, first.y]
		var bounds := Rect2(Grid.cell_to_world(first, spacing), Vector2.ZERO)
		for cell in component:
			bounds = bounds.expand(Grid.cell_to_world(cell, spacing))
		layout.stands.append({"id": id, "kind": "woodland", "cells": component, "bounds": bounds.grow(spacing * 0.58)})
		_woodland(layout, cells, component, spacing, seed_value, id, garden)
	_ground_cover(layout, cells, ordered, spacing, seed_value, garden)

static func _random(seed_value: int, id: String) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = ("%d/%s" % [seed_value, id]).hash()
	return random

static func _rocks(layout: Dictionary, cells: Dictionary, ordered: Array, spacing: float, seed_value: int, garden: bool) -> void:
	var clusters: Array[Vector2] = []
	for cell: Vector2i in ordered:
		if cells[cell] != &"stone":
			continue
		var center := Grid.cell_to_world(cell, spacing)
		var id := "formation_%d_%d" % [cell.x, cell.y]
		var random := _random(seed_value, id)
		if random.randf() > (0.27 if garden else 0.45):
			continue
		if _excluded(layout, center, 0.88) or _near_centers(clusters, center, 3.1 if garden else 2.6):
			continue
		var rocks: Array[String] = []
		var bounds := Rect2(center, Vector2.ZERO)
		for member in random.randi_range(3, 6 if garden else 8):
			var at := center
			if member > 0:
				at += Vector2.from_angle(random.randf_range(0.0, TAU)) * random.randf_range(0.4, 1.85)
			var footprint := random.randf_range(0.46, 0.79) if member == 0 else random.randf_range(0.16, 0.39)
			if not cells.has(Grid.world_to_cell(at, spacing)) or _excluded(layout, at, footprint + 0.06) 					or _near_rock(layout, at, footprint + 0.07):
				continue
			var rock_id := "%s_%d" % [id, member]
			var rock := Shape.disk(rock_id, "rock", at, footprint)
			rock["variant"] = random.randi_range(0, 4)
			rock["yaw"] = random.randf_range(0.0, TAU)
			rock["formation"] = id
			layout.rocks.append(rock)
			var bucket := Vector2i((at / 2.0).floor())
			if not layout.rock_buckets.has(bucket):
				layout.rock_buckets[bucket] = []
			layout.rock_buckets[bucket].append(rock)
			rocks.append(rock_id)
			bounds = bounds.merge(rock.bounds)
		if not rocks.is_empty():
			clusters.append(center)
			layout.rock_formations.append({"id": id, "kind": "stone_formation", "cell": cell, "bounds": bounds, "members": rocks})

static func _woodland(layout: Dictionary, cells: Dictionary, component: Array[Vector2i],
		spacing: float, seed_value: int, stand: String, garden: bool) -> void:
	var trees: Array[Vector2] = []
	for cell in component:
		var interior := 0
		for direction in Grid.NEIGHBORS:
			interior += int(cells.get(cell + direction) == &"forest_floor")
		var density := interior / 6.0
		var center := Grid.cell_to_world(cell, spacing)
		var id := "%s_%d_%d" % [stand, cell.x, cell.y]
		var random := _random(seed_value, id)
		var at := center + Vector2.from_angle(random.randf_range(0.0, TAU)) * random.randf_range(0.06, spacing * 0.38)
		var tree_chance := lerpf(0.12, 0.57 if garden else 0.76, density)
		var height := random.randf_range(1.45, 3.1 if garden else 4.2)
		var crown := height * 0.37
		if random.randf() < tree_chance and not _excluded(layout, at, crown) 				and not _near_rock(layout, at, 0.33) and not _near_centers(trees, at, 1.42):
			trees.append(at)
			_plant(layout, id + "_tree", "tree", at, height, random, stand, crown)
		var understory := _random(seed_value, id + "_understory")
		for i in range(1 + int(density * 3.8)):
			var spot := center + Vector2.from_angle(understory.randf_range(0.0, TAU)) * understory.randf_range(0.15, spacing * 0.47)
			if _excluded(layout, spot, 0.23) or _near_rock(layout, spot, 0.16):
				continue
			if understory.randf() < 0.55:
				var shrub := understory.randf() < 0.25
				_plant(layout, "%s_under_%d" % [id, i], "shrub" if shrub else "fern", spot,
					understory.randf_range(0.26, 0.59), understory, stand, 0.20)

static func _ground_cover(layout: Dictionary, cells: Dictionary, ordered: Array, spacing: float, seed_value: int, garden: bool) -> void:
	for cell: Vector2i in ordered:
		var terrain: StringName = cells[cell]
		if terrain == &"stone":
			continue
		var center := Grid.cell_to_world(cell, spacing)
		var id := "cover_%d_%d" % [cell.x, cell.y]
		var random := _random(seed_value, id)
		var near_bank := Shape.in_any(layout.water, center, 1.3)
		var amount := 5 if terrain == &"meadow" and garden else 3
		for i in amount:
			var at := center + Vector2.from_angle(random.randf_range(0.0, TAU)) * random.randf_range(0.04, spacing * 0.52)
			var chance := 0.76 if terrain == &"meadow" or near_bank else 0.40
			if random.randf() < chance and not _excluded(layout, at, 0.15) and not _near_rock(layout, at, 0.1):
				var tall := near_bank and random.randf() < 0.24
				_plant(layout, "%s_%d" % [id, i], "grass", at, random.randf_range(0.22, 0.51) if tall else random.randf_range(0.11, 0.25), random, "", 0.10)

static func _plant(layout: Dictionary, id: String, kind: String, at: Vector2, height: float,
		random: RandomNumberGenerator, stand: String, clearance: float) -> void:
	layout.plants.append({"id": id, "kind": kind, "center": at, "height": height, "stand": stand,
		"clearance": clearance, "variant": random.randi_range(0, 2), "yaw": random.randf_range(0.0, TAU),
		"tint": random.randf_range(0.0, 1.0)})

static func _excluded(layout: Dictionary, at: Vector2, padding: float) -> bool:
	return Shape.in_any(layout.clearings, at, padding) or Shape.in_any(layout.water, at, padding) 		or Shape.in_any(layout.paths, at, padding)

static func _near_rock(layout: Dictionary, at: Vector2, padding: float) -> bool:
	var bucket := Vector2i((at / 2.0).floor())
	for y in range(-1, 2):
		for x in range(-1, 2):
			if Shape.in_any(layout.rock_buckets.get(bucket + Vector2i(x, y), []), at, padding):
				return true
	return false

static func _near_centers(centers: Array[Vector2], at: Vector2, distance: float) -> bool:
	for center in centers:
		if center.distance_squared_to(at) < distance * distance:
			return true
	return false
