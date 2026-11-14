extends RefCounted
## Query the shared edge/corner from any incident cell and get the same answer.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.gd")

static func edge(cells: Dictionary, catalog: Catalog, cell: Vector2i, side: int) -> Dictionary:
	var ids: Array[StringName] = [cells[cell]]
	var other := cell + Grid.NEIGHBORS[side]
	if cells.has(other):
		ids.append(cells[other])
	return _resolve(ids, catalog, false)

static func corner(cells: Dictionary, catalog: Catalog, cell: Vector2i, index: int) -> Dictionary:
	var ids: Array[StringName] = [cells[cell]]
	for direction in [Grid.NEIGHBORS[(index + 5) % 6], Grid.NEIGHBORS[index]]:
		var other: Vector2i = cell + direction
		if cells.has(other):
			ids.append(cells[other])
	return _resolve(ids, catalog, true)

static func weights(id: StringName) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(Catalog.IDS.size())
	result[Catalog.IDS.find(id)] = 1.0
	return result

static func _resolve(ids: Array[StringName], catalog: Catalog, at_corner: bool) -> Dictionary:
	ids.sort()
	var blend := PackedFloat32Array()
	blend.resize(Catalog.IDS.size())
	var distinct: Array[StringName] = []
	for id in ids:
		blend[Catalog.IDS.find(id)] += 1.0 / ids.size()
		if distinct.is_empty() or distinct.back() != id:
			distinct.append(id)
	var rule := "solid"
	if ids.size() == 1:
		rule = "rim"
	elif distinct.size() > 1:
		rule = "three_way" if distinct.size() == 3 else "blend"
		if &"water" in distinct:
			rule = "shore_corner" if at_corner else "shore"
		for a in distinct:
			for b in distinct:
				if not catalog.allows(a, b):
					rule = "incompatible"
	return {"rule": rule, "ids": distinct, "weights": blend}