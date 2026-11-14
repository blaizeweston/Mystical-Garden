extends RefCounted
## The generator owns semantic terrain labels. No rendering, game RNG, or save access.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.gd")
const Palette = preload("res://assets/terrain_m02/terrain_palette.gd")
const VERSION := 1

static func generate(seed_value: int, radius: int, palette: Palette, catalog: Catalog) -> Dictionary:
	assert(radius >= 1 and radius <= 30)
	var cells := {}
	var lake_center := Vector2(5.7, -2.7) + Vector2(
		_sample(Vector2i(21, 8), seed_value), _sample(Vector2i(6, 17), seed_value)) * 1.7
	for cell in Grid.disk(radius):
		var point := Grid.cell_to_world(cell, 1.0)
		var bend := Vector2(_noise(point * 0.15, seed_value + 41),
			_noise(point * 0.14, seed_value + 83))
		var warped := point + 3.0 * bend
		var broad := _noise(warped * 0.19, seed_value + 109)
		var forest := broad * 0.72 + _noise(warped * 0.38, seed_value + 191) * 0.28
		var stone := _noise(warped * 0.23, seed_value + 307)
		var soil := _noise(warped * 0.24, seed_value + 433)
		var water_distance := warped.distance_to(lake_center)
		if palette.water_is_stream:
			var river_x := 3.6 + _noise(Vector2(point.y * 0.14, 8.4), seed_value + 59) * 5.3
			water_distance = absf(point.x - river_x + bend.x * 0.86)
		var terrain: StringName = &"meadow"
		if water_distance < palette.water_width and (not palette.tree_at_origin or point.length() > 2.1):
			terrain = &"water"
		elif point.length() >= palette.clearing_radius and stone > 0.63 - palette.stone_bias:
			terrain = &"stone"
		elif point.length() >= palette.clearing_radius and forest > 0.27 - palette.forest_bias:
			terrain = &"forest_floor"
		elif soil > 0.43 - palette.soil_bias:
			terrain = &"soil"
		cells[cell] = terrain
	if palette.tree_at_origin:
		cells[Vector2i.ZERO] = &"meadow"
	# In this catalog the only forbidden pairs are dry ground against water.
	# Read from the first pass and place the declared soil intermediary on the dry side.
	var resolved: Dictionary = cells.duplicate()
	for cell: Vector2i in cells:
		if cells[cell] != &"water":
			continue
		for direction in Grid.NEIGHBORS:
			var neighbor := cell + direction
			if cells.has(neighbor) and not catalog.allows(cells[cell], cells[neighbor]):
				resolved[neighbor] = &"soil"
	return resolved

static func digest(cells: Dictionary, palette_id: StringName, seed_value: int) -> String:
	var ordered: Array = cells.keys()
	ordered.sort()
	var text := PackedStringArray([str(VERSION), str(palette_id), str(seed_value)])
	for cell: Vector2i in ordered:
		text.append("%d,%d,%s" % [cell.x, cell.y, cells[cell]])
	return "\n".join(text).sha256_text()

static func _noise(point: Vector2, seed_value: int) -> float:
	var base := Vector2i(point.floor())
	var blend := point - Vector2(base)
	blend = blend * blend * (Vector2(3.0, 3.0) - 2.0 * blend)
	return lerpf(
		lerpf(_sample(base, seed_value), _sample(base + Vector2i.RIGHT, seed_value), blend.x),
		lerpf(_sample(base + Vector2i.DOWN, seed_value),
			_sample(base + Vector2i.ONE, seed_value), blend.x),
		blend.y)

static func _sample(lattice: Vector2i, seed_value: int) -> float:
	# Bounded integer hash. No dependence on engine RNG state or dictionary order.
	var value := (seed_value ^ (lattice.x * 374761393) ^ (lattice.y * 668265263)) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float(value ^ (value >> 16)) / 1073741824.0 - 1.0
