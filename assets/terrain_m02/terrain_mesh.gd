extends RefCounted
## A planar indexed mesh. Shared vertices are welded by the grid's integer keys.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.gd")
const Transitions = preload("res://assets/terrain_m02/terrain_transitions.gd")
const TERRAIN_SHADER = preload("res://assets/terrain_m02/terrain_surface.gdshader")
const INNER_SCALE := 0.70

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var weights_a := PackedVector2Array()
var weights_b := PackedVector2Array()
var indices := PackedInt32Array()
var boundary := {}
var edge_rules := {}
var corner_rules := {}

static func compile(cells: Dictionary, spacing: float, catalog: Catalog) -> Dictionary:
	var builder := new()
	var ordered: Array = cells.keys()
	ordered.sort()
	for cell: Vector2i in ordered:
		builder._append_cell(cells, spacing, catalog, cell)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.vertices
	arrays[Mesh.ARRAY_NORMAL] = builder.normals
	# Two full-precision UV channels store four material weights. Water is the remainder.
	arrays[Mesh.ARRAY_TEX_UV] = builder.weights_a
	arrays[Mesh.ARRAY_TEX_UV2] = builder.weights_b
	arrays[Mesh.ARRAY_INDEX] = builder.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	for id in Catalog.IDS:
		var terrain := catalog.definition(id)
		material.set_shader_parameter(str(id) + "_color", terrain.color)
		material.set_shader_parameter(str(id) + "_shade", terrain.shade)
	mesh.surface_set_material(0, material)
	return {"mesh": mesh, "vertices": builder.vertices.size(), "triangles": int(builder.indices.size() / 3.0),
		"edge_rules": builder.edge_rules, "corner_rules": builder.corner_rules}

func _append_cell(cells: Dictionary, spacing: float, catalog: Catalog, cell: Vector2i) -> void:
	var center := Grid.cell_to_world(cell, spacing)
	var solid := Transitions.weights(cells[cell])
	var origin := _vertex(center, solid)
	var outer := PackedInt32Array()
	var inner := PackedInt32Array()
	for side in 6:
		var corner := Grid.corner_key(cell, side)
		var edge := Grid.edge_key(cell, side)
		if not boundary.has(corner):
			var transition := Transitions.corner(cells, catalog, cell, side)
			boundary[corner] = _vertex(Grid.key_to_world(corner, spacing), transition.weights)
			corner_rules[corner] = transition.rule
		if not boundary.has(edge):
			var transition := Transitions.edge(cells, catalog, cell, side)
			boundary[edge] = _vertex(Grid.key_to_world(edge, spacing), transition.weights)
			edge_rules[edge] = transition.rule
		for key in [corner, edge]:
			outer.append(boundary[key])
			inner.append(_vertex(center.lerp(Grid.key_to_world(key, spacing), INNER_SCALE), solid))
	for i in 12:
		var next := (i + 1) % 12
		indices.append_array(PackedInt32Array([
			origin, inner[next], inner[i],
			inner[i], inner[next], outer[i],
			outer[i], inner[next], outer[next],
		]))

func _vertex(point: Vector2, weights: PackedFloat32Array) -> int:
	var index := vertices.size()
	vertices.append(Vector3(point.x, 0.0, point.y))
	normals.append(Vector3.UP)
	weights_a.append(Vector2(weights[0], weights[1]))
	weights_b.append(Vector2(weights[2], weights[3]))
	return index