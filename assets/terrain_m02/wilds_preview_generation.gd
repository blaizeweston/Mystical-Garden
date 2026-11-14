extends RefCounted
## Labels, habitat patches and props are derived from the same valley geometry.
const Rooms = preload("res://assets/terrain_m02/wilds_rooms.gd")
const Massing = preload("res://assets/terrain_m02/wilds_massing.gd")
const Biomes = preload("res://assets/terrain_m02/wilds_biome.gd")
const Geography = preload("res://assets/terrain_m02/wilds_geography.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Field = preload("res://assets/terrain_m02/terrain_generator.gd")

static func build(seed_value: int, floor_number: int, radius: int, spacing: float, catalog,
		windows: Array = Biomes.WINDOWS, massed: bool = false) -> Dictionary:
	var climate := Biomes.climate(floor_number, windows)
	var layout := Geography.compose(seed_value, radius, spacing, climate)
	if layout.is_empty():
		return {}
	if massed:
		layout = Rooms.expand(layout, seed_value, radius, spacing)
		if layout.is_empty():
			return {}
		layout["seed"] = seed_value
		layout["masses"] = Massing.build(layout, seed_value, radius, spacing, climate)
	var cells := {}
	var dry := {}
	for cell in Grid.disk(radius):
		var at := Grid.cell_to_world(cell, spacing)
		var bank := Shape.signed_distance(layout.water[0], at, 3.0)
		var sample: Vector2 = at / spacing + Vector2(0.019, -0.014) * (climate.floor_number - 1)
		var forest := Field._noise(sample * 0.18, seed_value + 2421) * 0.75 \
			+ Field._noise(sample * 0.35, seed_value + 844) * 0.25
		var rock := Field._noise(sample * 0.28, seed_value + 647)
		var ridge := absf(sin(sample.y * 0.35 + sample.x * 0.61 + float(seed_value % 31)))
		var wet: float = climate.moisture * 0.61 + maxf(0.0, 0.54 - bank * 0.15)
		var reserve := Shape.in_any(layout.clearings, at, 0.18) or Shape.in_trails(layout, at)
		var terrain: StringName = &"meadow"
		if wet > 0.77 or Field._noise(sample * 0.31, seed_value + 586) > 0.64 - climate.moisture * 0.91:
			terrain = &"soil"
		if not reserve:
			if rock * 0.56 + ridge * 0.34 > 0.72 - climate.stone_cover * 0.61:
				terrain = &"stone"
			elif forest > 0.61 - climate.forest * 1.17 and wet < 0.90:
				terrain = &"forest_floor"
		if massed and not reserve:
			for wall in layout.masses:
				if wall.bounds.has_point(at) and Shape.contains(wall, at):
					terrain = [&"forest_floor", &"soil", &"stone"][wall.family]
					break
		dry[cell] = terrain
		cells[cell] = &"water" if bank < 0.0 else terrain
	for cell: Vector2i in cells:
		if cells[cell] != &"water":
			continue
		for direction in Grid.NEIGHBORS:
			var other: Vector2i = cell + direction
			if cells.has(other) and not catalog.allows(cells[cell], cells[other]):
				cells[other] = &"soil"
	# Water is polygonal. The material field retains the true substrate under its shoreline and islands.
	layout["grid_radius"] = radius
	layout["spacing"] = spacing
	_populate(layout, cells, seed_value, spacing, climate)
	if massed:
		_mass_communities(layout, seed_value)
	return {"cells": cells, "substrate": dry, "layout": layout, "climate": climate}

static func _populate(layout: Dictionary, cells: Dictionary, seed_value: int, spacing: float, climate: Dictionary) -> void:
	var formations: Array[Dictionary] = []
	_place_obstacles(layout, formations, cells, seed_value, spacing, climate)
	for cell: Vector2i in cells:
		var at := Grid.cell_to_world(cell, spacing)
		var bank := Shape.signed_distance(layout.water[0], at, 3.0)
		if bank < 0.0:
			continue
		var id := "%d_%d" % [cell.x, cell.y]
		var family := Biomes.family(climate.weights, _roll(seed_value, id, "family"))
		var drift := Vector2.from_angle(_roll(seed_value,id,"yaw") * TAU) * 0.36 * spacing
		var point := at + drift
		var height := lerpf(2.0, 4.3, _roll(seed_value,id,"size"))
		var land: StringName = cells[cell]
		if (land == &"forest_floor" or (family == 1 and bank < 4.7 and bank > 0.8)) \
				and _roll(seed_value,id,"tree") < climate.forest * 0.67:
			height *= [1.37, 1.02, 0.68][family]
			var spread: float = height * (0.41 if family == 0 else 0.27)
			if not layout.get("masses", []).is_empty() and family == 2:
				height *= 0.73
			if _open(layout, point, spread):
				layout.plants.append(_plant(id, "tree", point, height, spread, family, seed_value))
		var habitat := Field._noise(at / spacing * 0.32, seed_value + 1907)
		if _roll(seed_value,id,"cover") > climate.ground_cover or not _open(layout, point, 0.32):
			continue
		var kind := "fern" if habitat > -0.2 else "grass"
		var amount := 2
		if family == 1:
			kind = "reed" if bank < 2.65 and habitat > -0.53 else "grass"
			amount = 3 if kind == "reed" else 1
		elif family == 2:
			kind = "fungus" if habitat > 0.03 and land in [&"stone", &"forest_floor"] else "wine_fern"
			amount = 3 if kind == "fungus" else 1
		for j in amount:
			var part := id + "_%d" % j
			var local := point + Vector2.from_angle(_roll(seed_value,part,"clump") * TAU) * 0.34 * j
			if _open(layout, local, 0.20):
				layout.plants.append(_plant(part, kind, local,
					lerpf(0.24, 0.74 if kind == "reed" else 0.49, _roll(seed_value,part,"size")), 0.20, family, seed_value))
	if layout.has("masses"):
		return
	# Taller ring trees frame the Grove while lower densities let the Mire and Hollow open up.
	for i in 44:
		var phase := TAU * i / 44.0
		var edge := Vector2(cos(phase), sin(phase) * 0.83) * spacing * (9.8 if cells.size() < 1000 else 13.6)
		var id := "edge_%d" % i
		var family := Biomes.family(climate.weights, _roll(seed_value,id,"family"))
		var scale := lerpf(2.4, 4.9, _roll(seed_value,id,"size"))
		if not _open(layout, edge, scale * 0.38) or _roll(seed_value,id,"edge") > climate.forest * 0.78 + 0.14:
			continue
		layout.plants.append(_plant(id, "tree", edge, scale, scale * 0.38, family, seed_value))

static func _place_obstacles(layout: Dictionary, formations: Array[Dictionary], cells: Dictionary,
		seed_value: int, spacing: float, climate: Dictionary) -> void:
	# The historical mode uses standalone root arches. M07B puts large roots along its barriers.
	for path in ([] if layout.has("masses") else layout.paths):
		if path.id == "bank_crossing":
			continue
		var spine: PackedVector2Array = path.spine
		for anchor in 2:
			var i := int(spine.size() * (0.31 + anchor * 0.37))
			var lane := (spine[i + 1] - spine[i - 1]).normalized()
			for side in [-1.0, 1.0]:
				var id := "%s_%d_%s" % [path.id, anchor, str(side)]
				var family := Biomes.family(climate.weights, _roll(seed_value, id, "root_family"))
				if family != 2:
					continue
				var at: Vector2 = spine[i] + lane.orthogonal() * side * 3.65
				_wood(layout, id, at, "root_arch", family, 2.12, seed_value, lane.angle())
	for cell: Vector2i in cells:
		var id := "%d_%d" % [cell.x, cell.y]
		var at := Grid.cell_to_world(cell, spacing)
		var family := Biomes.family(climate.weights, _roll(seed_value, id, "family"))
		var drift := Vector2.from_angle(_roll(seed_value, id, "yaw") * TAU) * 0.36 * spacing
		if cells[cell] == &"stone" and _roll(seed_value, id, "rock") < climate.stone_cover * 0.19 + 0.12:
			_formation(layout, formations, id, at + drift, family, seed_value)
		if family == 1 and Shape.in_any(layout.water, at, 2.85) \
				and _roll(seed_value, id, "deadwood") < 0.13 * climate.accent_density:
			_wood(layout, id, at, "fallen_timber", family, 1.16, seed_value)

static func _formation(layout: Dictionary, clusters: Array[Dictionary], id: String, at: Vector2,
		family: int, seed_value: int) -> void:
	var size := lerpf(0.66, 1.16, _roll(seed_value, id, "size"))
	if not _open(layout, at, size) or Shape.in_any(clusters, at, 2.5):
		return
	clusters.append(Shape.disk(id, "cluster", at, 0.72))
	var members: Array[String] = []
	for j in 4:
		var part := id + "_%d" % j
		var point := at + Vector2.from_angle(_roll(seed_value,part,"scatter") * TAU) * j * 0.56
		var radius := size if j == 0 else size * 0.49
		if not _open(layout, point, radius):
			continue
		var stone := Shape.disk(part, "rock", point, radius)
		stone.merge({"family": family, "variant": int(_roll(seed_value,part,"variant") * 4),
			"yaw": _roll(seed_value,part,"yaw") * TAU})
		layout.rocks.append(stone)
		members.append(part)
	layout.formations.append({"center": at, "members": members})

static func _wood(layout: Dictionary, id: String, at: Vector2, kind: String, family: int,
		width: float, seed_value: int, bearing: float = INF) -> void:
	if not _open(layout, at, width):
		return
	var wood := _plant(id, kind, at, width, width, family, seed_value)
	layout.rocks.append({"id": id + "_" + kind, "kind": kind, "center": at, "radius": width,
		"family": family, "variant": wood.variant, "yaw": wood.yaw if bearing == INF else -bearing,
		"bounds": Shape.disk(id, kind, at, width).bounds})

static func _open(layout: Dictionary, at: Vector2, radius: float) -> bool:
	if Shape.in_any(layout.water, at, radius) or Shape.in_trails(layout, at, radius) \
			or Shape.in_any(layout.clearings, at, radius) or Shape.in_any(layout.rocks, at, radius) \
			or Shape.in_any(layout.get("masses", []), at, radius):
		return false
	for i in 6:
		var limit := at + Vector2.from_angle(i * TAU / 6.0) * radius
		if not Geography._inside_disk(limit, layout.grid_radius, layout.spacing):
			return false
	return true

static func _mass_communities(layout: Dictionary, seed_value: int) -> void:
	for mass in layout.masses:
		var spine: PackedVector2Array = mass.spine
		var family: int = mass.family
		for i in range(1, spine.size() - 1):
			var center := spine[i]
			var axis := (spine[i + 1] - spine[i - 1]).normalized()
			var id := "%s_%d" % [mass.id, i]
			var roll := _roll(seed_value, id, "height")
			var width: float = mass.half_widths[i]
			if family == 0 or (family == 1 and i % 3 != 0):
				var height := lerpf(4.25, 6.1, roll) if family == 0 else lerpf(3.0, 4.55, roll)
				var crown := height * (0.48 if family == 0 else 0.36)
				var projected := center - Vector2(0.13, 0.55) * height
				if not Shape.in_trails(layout, center, crown) and not Shape.in_any(layout.clearings, center, crown) \
						and not Shape.in_any(layout.crossings, projected, 0.95):
					var trunk := _plant(id, "tree", center, height, width * 0.76, family, seed_value)
					trunk["on_mass"] = mass.id
					trunk["elevation"] = width * 0.26
					layout.plants.append(trunk)
			var kind: String = ["fern", "reed", "fungus"][family]
			for side in [-1.0, 1.0]:
				var patch_id := id + str(side)
				var density := Field._noise(center * 0.25, seed_value + 71)
				if family == 2 and (density < -0.18 or _roll(seed_value, patch_id, "patch") < 0.39):
					continue
				var stagger := _roll(seed_value, patch_id, "jitter")
				var at: Vector2 = center + axis.orthogonal() * side * (width + 0.39 + 0.52 * stagger) \
					+ axis * (stagger - 0.5) * 0.86
				if not _open(layout, at, 0.32):
					continue
				var cover := _plant(patch_id, kind, at, lerpf(0.34, 0.64, roll), 0.32, family, seed_value)
				cover["community"] = mass.id
				layout.plants.append(cover)

static func _roll(seed_value: int, id: String, stream: String) -> float:
	return float(("%d/%s/%s" % [seed_value, id, stream]).hash()) / 4294967296.0

static func _plant(id: String, kind: String, at: Vector2, height: float, gap: float, family: int, seed_value: int) -> Dictionary:
	return {"id": id + "_" + kind, "kind": kind, "center": at, "height": height, "clearance": gap,
		"family": family, "variant": int(_roll(seed_value,id,"variant") * 3),
		"yaw": _roll(seed_value,id,"yaw") * TAU, "tint": _roll(seed_value,id,"tone")}
