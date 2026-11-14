extends Node3D

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.gd")
const Transitions = preload("res://assets/terrain_m02/terrain_transitions.gd")
const SHORT_NAMES := {&"meadow": "M", &"soil": "D", &"forest_floor": "F", &"stone": "S", &"water": "W"}

func rebuild(cells: Dictionary, spacing: float, compiled: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	var lines := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var seen := {}
	for cell: Vector2i in cells:
		for side in 6:
			var key := Grid.edge_key(cell, side)
			if seen.has(key):
				continue
			seen[key] = true
			var rule: String = compiled.edge_rules[key]
			var color := Color("#dedbc2")
			match rule:
				"blend": color = Color("#ffc77b")
				"shore": color = Color("#9feaff")
				"incompatible": color = Color("#ff4444")
				"solid": color = Color("#718169")
			lines.surface_set_color(color)
			lines.surface_add_vertex(_position(Grid.corner_key(cell, side), spacing))
			lines.surface_add_vertex(_position(Grid.corner_key(cell, (side + 1) % 6), spacing))
	lines.surface_end()
	var display := MeshInstance3D.new()
	display.mesh = lines
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(display)
	var junctions := ImmediateMesh.new()
	var marked := false
	junctions.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for key: Vector2i in compiled.corner_rules:
		var rule: String = compiled.corner_rules[key]
		if rule != "three_way" and rule != "shore_corner":
			continue
		marked = true
		var point := _position(key, spacing) + Vector3.UP * 0.018
		junctions.surface_set_color(Color("#a8eaff") if rule == "shore_corner" else Color("#f2a7ff"))
		junctions.surface_add_vertex(point - Vector3.RIGHT * 0.075)
		junctions.surface_add_vertex(point + Vector3.RIGHT * 0.075)
		junctions.surface_add_vertex(point - Vector3.BACK * 0.075)
		junctions.surface_add_vertex(point + Vector3.BACK * 0.075)
	# A small map may have no mixed corners.
	if not marked:
		junctions.surface_add_vertex(Vector3.ZERO)
		junctions.surface_add_vertex(Vector3.ZERO)
	junctions.surface_end()
	var dots := MeshInstance3D.new()
	dots.mesh = junctions
	dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dots)
	for cell: Vector2i in cells:
		var center := Grid.cell_to_world(cell, spacing)
		var label := Label3D.new()
		label.position = Vector3(center.x, 0.06, center.y)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 25
		label.pixel_size = 0.012
		label.outline_size = 7
		label.text = "(%d,%d) %s" % [cell.x, cell.y, SHORT_NAMES[cells[cell]]]
		add_child(label)

func inspect(cells: Dictionary, catalog: Catalog, point: Vector2, spacing: float) -> String:
	var cell := Grid.world_to_cell(point, spacing)
	if not cells.has(cell):
		return ""
	var edge_index := 0
	var corner_index := 0
	for side in range(1, 6):
		var edge_pos := Grid.key_to_world(Grid.edge_key(cell, side), spacing)
		var corner_pos := Grid.key_to_world(Grid.corner_key(cell, side), spacing)
		if edge_pos.distance_squared_to(point) < Grid.key_to_world(Grid.edge_key(cell, edge_index), spacing).distance_squared_to(point):
			edge_index = side
		if corner_pos.distance_squared_to(point) < Grid.key_to_world(Grid.corner_key(cell, corner_index), spacing).distance_squared_to(point):
			corner_index = side
	var edge := Transitions.edge(cells, catalog, cell, edge_index)
	var corner := Transitions.corner(cells, catalog, cell, corner_index)
	return "(%d, %d)  %s    •    Edge %s    •    Corner %s" % [
		cell.x, cell.y, catalog.definition(cells[cell]).display_name,
		_describe(edge, catalog), _describe(corner, catalog)]

func _describe(transition: Dictionary, catalog: Catalog) -> String:
	var labels := PackedStringArray()
	for id: StringName in transition.ids:
		labels.append(catalog.definition(id).display_name)
	return "%s (%s)" % [transition.rule.replace("_", " "), " + ".join(labels)]

func _position(key: Vector2i, spacing: float) -> Vector3:
	var point := Grid.key_to_world(key, spacing)
	return Vector3(point.x, 0.025, point.y)
