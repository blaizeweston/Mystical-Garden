extends SceneTree

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Transitions = preload("res://assets/terrain_m02/terrain_transitions.gd")
const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Compiler = preload("res://assets/terrain_m02/terrain_mesh.gd")
const MaterialField = preload("res://assets/terrain_m02/terrain_material_field.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.gd")
const CATALOG = preload("res://assets/terrain_m02/terrain_catalog.tres")
const GARDEN = preload("res://assets/terrain_m02/garden_clearing.tres")
const WILDS = preload("res://assets/terrain_m02/wilds_riverwood.tres")
const PREVIEW = preload("res://assets/terrain_m02/terrain_preview.tscn")

var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ", description)

func run() -> void:
	_coordinates()
	_transitions()
	_generation()
	_topology()
	_render_field()
	_scene()
	if not failed:
		print("PASS: hex terrain coordinates, compatibility, transitions, generation, welded topology, material lookup and preview")
	quit(1 if failed else 0)

func _coordinates() -> void:
	check(Grid.disk(14).size() == 631, "radius 14 contains 631 cells")
	for spacing in [1.5, 1.75, 2.0]:
		for cell in Grid.disk(5):
			var center := Grid.cell_to_world(cell, spacing)
			check(Grid.world_to_cell(center, spacing) == cell, "round trip at signed axial coordinate")
			for side in 6:
				var neighbor := cell + Grid.NEIGHBORS[side]
				var opposite := (side + 3) % 6
				check(neighbor + Grid.NEIGHBORS[opposite] == cell, "reciprocal neighbor")
				check(is_equal_approx(center.distance_to(Grid.cell_to_world(neighbor, spacing)), spacing),
					"center spacing is identical in all six directions")
				var edge := Grid.edge_key(cell, side)
				var corner := Grid.corner_key(cell, side)
				check(edge == Grid.edge_key(neighbor, opposite), "canonical edge identity")
				check(corner == Grid.corner_key(neighbor, (opposite + 1) % 6), "edge endpoint agrees")
				var edge_owner := Grid.world_to_cell(Grid.key_to_world(edge, spacing), spacing)
				check(edge_owner == _first([cell, neighbor]), "exact edge uses lexicographic owner")
				var previous := cell + Grid.NEIGHBORS[(side + 5) % 6]
				var corner_owner := Grid.world_to_cell(Grid.key_to_world(corner, spacing), spacing)
				check(corner_owner == _first([cell, neighbor, previous]),
					"exact corner uses lexicographic owner")

func _first(incident: Array) -> Vector2i:
	incident.sort()
	return incident[0]

func _transitions() -> void:
	for a in Catalog.IDS:
		check(CATALOG.definition(a) != null and CATALOG.allows(a, a), "stable ID and same-type contact")
		for b in Catalog.IDS:
			check(CATALOG.allows(a, b) == CATALOG.allows(b, a), "compatibility is symmetric")
	check(not CATALOG.allows(&"water", &"meadow"), "unbuffered grassy water edge is disallowed")
	check(CATALOG.allows(&"water", &"soil"), "soil can meet water")
	var cells := {Vector2i.ZERO: &"soil", Vector2i.RIGHT: &"stone", Vector2i.DOWN: &"water"}
	var edge := Transitions.edge(cells, CATALOG, Vector2i.ZERO, 0)
	check(edge == Transitions.edge(cells, CATALOG, Vector2i.RIGHT, 3), "edge rule/weights from both sides")
	var corner := Transitions.corner(cells, CATALOG, Vector2i.ZERO, 0)
	check(corner == Transitions.corner(cells, CATALOG, Vector2i.RIGHT, 4), "corner from east incident cell")
	check(corner == Transitions.corner(cells, CATALOG, Vector2i.DOWN, 2), "corner from southern incident cell")
	check(corner.rule == "shore_corner" and corner.ids.size() == 3, "three-way shore corner")
	check(is_equal_approx(corner.weights[1] + corner.weights[3] + corner.weights[4], 1.0),
		"shore corner weights are normalized")
	cells[Vector2i.DOWN] = &"forest_floor"
	check(Transitions.corner(cells, CATALOG, Vector2i.ZERO, 0).rule == "three_way", "dry three-way corner")
	cells[Vector2i.DOWN] = &"soil"
	check(Transitions.corner(cells, CATALOG, Vector2i.ZERO, 0).rule == "blend", "repeated-material corner")
	check(Transitions.edge(cells, CATALOG, Vector2i.ZERO, 5).rule == "solid", "same-terrain edge")
	check(Transitions.edge(cells, CATALOG, Vector2i.ZERO, 2).rule == "rim", "open perimeter edge")
	cells[Vector2i.DOWN] = &"water"
	cells[Vector2i.ZERO] = &"meadow"
	check(Transitions.edge(cells, CATALOG, Vector2i.ZERO, 5).rule == "incompatible", "invalid edge diagnosed")

func _generation() -> void:
	for palette in [GARDEN, WILDS]:
		var seed_value := 117 if palette == GARDEN else 241
		var cells := Generator.generate(seed_value, 14, palette, CATALOG)
		var duplicate := Generator.generate(seed_value, 14, palette, CATALOG)
		var reordered := {}
		var backwards: Array = duplicate.keys()
		backwards.reverse()
		for cell in backwards:
			reordered[cell] = duplicate[cell]
		var fingerprint := Generator.digest(cells, palette.id, seed_value)
		check(cells == duplicate, "repeated seed generates the same map")
		check(fingerprint == Generator.digest(reordered, palette.id, seed_value),
			"map digest independent of key insertion order")
		var other := Generator.generate(seed_value + 1, 14, palette, CATALOG)
		check(cells != other, "changing the seed changes terrain labels")
		if palette == GARDEN:
			check(cells[Vector2i.ZERO] == &"meadow", "Garden tree sits in meadow")
		_water_feature(cells, palette == WILDS)
		var same_edges := 0
		var edges := 0
		for id in Catalog.IDS:
			check(id in cells.values(), "reference seed uses %s" % id)
		for cell: Vector2i in cells:
			for direction in Grid.NEIGHBORS:
				var neighbor := cell + direction
				if cells.has(neighbor):
					edges += 1
					var current: StringName = cells[cell]
					var next: StringName = cells[neighbor]
					check(CATALOG.allows(current, next), "generated edge respects terrain rules")
					same_edges += int(current == next)
		check(float(same_edges) / edges > 0.58, "regional coherence across neighboring cells")
		print("M02_DIGEST ", palette.id, " ", fingerprint, " shared-type edge ratio ", float(same_edges) / edges)
	check(Generator.generate(117, 14, WILDS, CATALOG) != Generator.generate(117, 14, GARDEN, CATALOG),
		"palette changes region distribution for the same seed")

func _water_feature(cells: Dictionary, is_stream: bool) -> void:
	var count := 0
	var pending: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if cells[cell] == &"water":
			if pending.is_empty():
				pending.append(cell)
			count += 1
	if pending.is_empty():
		check(false, "reference water feature is present")
		return
	var visited := {pending[0]: true}
	var min_row := 0
	var max_row := 0
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		min_row = mini(min_row, cell.y)
		max_row = maxi(max_row, cell.y)
		for direction in Grid.NEIGHBORS:
			var neighbor := cell + direction
			if cells.get(neighbor) == &"water" and not visited.has(neighbor):
				pending.append(neighbor)
				visited[neighbor] = true
	check(visited.size() == count, "reference water feature is connected")
	if is_stream:
		check(min_row == -14 and max_row == 14, "Wilds river crosses the sampled region")
	else:
		check(min_row > -14 and max_row < 14, "Garden lake stays within the sampled region")

func _topology() -> void:
	var cells := {Vector2i.ZERO: &"soil", Vector2i.RIGHT: &"stone", Vector2i.DOWN: &"water"}
	var spacing := 1.75
	var compiled := Compiler.compile(cells, spacing, CATALOG)
	var mesh: ArrayMesh = compiled.mesh
	check(mesh.get_surface_count() == 1 and compiled.triangles == 108, "one mesh surface with 36 triangles per cell")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var shared := Grid.key_to_world(Grid.corner_key(Vector2i.ZERO, 0), spacing)
	var corner_index := vertices.find(Vector3(shared.x, 0.0, shared.y))
	var corner_uses := 0
	var area := 0.0
	var incidence := {}
	for i in range(0, indices.size(), 3):
		var ids := [indices[i], indices[i + 1], indices[i + 2]]
		var a := vertices[ids[0]]
		var b := vertices[ids[1]]
		var c := vertices[ids[2]]
		var cross := (b - a).cross(c - a)
		check(cross.y < 0.0, "clockwise, nondegenerate flat triangles")
		check(a.y == 0.0 and b.y == 0.0 and c.y == 0.0, "no elevation or vertical edges")
		area += absf(cross.y) * 0.5
		corner_uses += int(corner_index in ids)
		for j in 3:
			var first: int = ids[j]
			var second: int = ids[(j + 1) % 3]
			var key := Vector2i(mini(first, second), maxi(first, second))
			incidence[key] = incidence.get(key, 0) + 1
	check(is_equal_approx(area, cells.size() * spacing * spacing * Grid.SQRT_3 / 2.0),
		"triangles cover exactly the three-cell area")
	check(corner_index >= 0 and corner_uses == 9, "one three-cell corner index shared by all incident faces")
	if corner_index >= 0:
		check(uv[corner_index].is_equal_approx(Vector2(0.0, 1.0 / 3.0))
			and uv2[corner_index].is_equal_approx(Vector2(0.0, 1.0 / 3.0)), "three-way corner shader weights")
	var perimeter_edges := 0
	for count in incidence.values():
		check(count <= 2, "triangle edges are manifold")
		perimeter_edges += int(count == 1)
	check(perimeter_edges == 24, "only true perimeter edges are open")

func _render_field() -> void:
	var empty_corner := Vector2i(-1, -1)
	var labels := {Vector2i.ZERO: &"soil", Vector2i(-1, 0): &"water", Vector2i(0, -1): &"forest_floor"}
	var field := MaterialField.bake(labels)
	var reversed := {Vector2i(0, -1): &"forest_floor", Vector2i(-1, 0): &"water", Vector2i.ZERO: &"soil"}
	check(field == MaterialField.bake(reversed), "same field bytes regardless of cell insertion order")
	check(field.origin == empty_corner and field.size == Vector2i(2, 2), "signed field bounds")
	check(field.labels == PackedByteArray([255, 2, 4, 1]), "empty texel and logical labels map to exact channel IDs")
	for radius in [14, 28]:
		var cells := Generator.generate(241, radius, WILDS, CATALOG)
		field = MaterialField.bake(cells)
		var holes := 0
		for y in field.size.y:
			for x in field.size.x:
				var cell: Vector2i = field.origin + Vector2i(x, y)
				var expected := Catalog.IDS.find(cells[cell]) if cells.has(cell) else 255
				var actual: int = field.labels[y * field.size.x + x]
				check(expected == actual, "render labels exactly match the logical grid")
				holes += int(actual == 255)
		check(holes + cells.size() == field.labels.size(), "one sample per cell and empty extent area")
		var elapsed := Time.get_ticks_usec()
		var material := MaterialField.material(field, 1.75, 241, CATALOG)
		var same := MaterialField.material(field, 1.75, 241, CATALOG)
		var different := MaterialField.material(field, 1.75, 242, CATALOG)
		check(material.get_shader_parameter("seed_offset") == same.get_shader_parameter("seed_offset"),
			"same seed yields the same shader variation")
		check(material.get_shader_parameter("seed_offset") != different.get_shader_parameter("seed_offset"),
			"seed changes decorative variation independently of the label map")
		var texture: Texture2D = material.get_shader_parameter("cell_labels")
		check(texture.get_size() == Vector2(field.size), "uploaded mask dimensions")
		print("M03_FIELD radius=", radius, " payload=", field.labels.size(), " bytes, setup check=",
			(Time.get_ticks_usec() - elapsed) / 1000.0, " ms")

func _scene() -> void:
	var scene: Node3D = PREVIEW.instantiate()
	root.add_child(scene)
	var renderer: OptionButton = scene.get_node("%Rendering")
	# Exercise the unchanged riverwood baseline in a historical mode.
	renderer.select(5)
	renderer.item_selected.emit(5)
	var example: OptionButton = scene.get_node("%Example")
	example.select(1)
	example.item_selected.emit(1)
	check(scene.metrics.seed == 241 and scene.metrics.palette == WILDS.id, "example control selects palette and seed")
	var spacing_button: OptionButton = scene.get_node("%Spacing")
	spacing_button.select(0)
	spacing_button.item_selected.emit(0)
	var overlay: CheckButton = scene.get_node("%Overlay")
	overlay.button_pressed = true
	check(scene.metrics.cells == 631 and scene.metrics.spacing == 1.50, "overlay scene can switch biome and spacing")
	check(scene.get_node("HexDebug").visible and not scene.get_node("TreePosition").visible, "Wilds overlay controls")
	var seed: SpinBox = scene.get_node("%Seed")
	seed.value = 51
	var generate: Button = scene.get_node("%Generate")
	generate.pressed.emit()
	check(scene.metrics.seed == 51, "generate reads the edited seed")
	var next: Button = scene.get_node("%NextSeed")
	next.pressed.emit()
	check(scene.metrics.seed == 52, "next-seed control regenerates")
	scene.show_example(0, 117, 2, false)
	check(not scene.get_node("HexDebug").visible and scene.get_node("TreePosition").visible, "Garden marker and hidden grid")
	var mesh := (scene.get_node("Ground") as MeshInstance3D).mesh
	var mesh_instance := scene.get_node("Ground") as MeshInstance3D
	var metrics_before: Dictionary = scene.metrics.duplicate()
	check(mesh_instance.material_override == scene.natural_material, "M03 renderer is default")
	renderer.select(4)
	renderer.item_selected.emit(4)
	check(mesh_instance.material_override == null, "M02 uses the original mesh surface material")
	renderer.select(0)
	renderer.item_selected.emit(0)
	check(mesh_instance.material_override == scene.natural_material, "M03 material restored")
	check(mesh_instance.mesh == mesh and scene.metrics == metrics_before, "render comparison does not rebuild or alter the map")
	check(scene.metrics.digest == "728d2f22b8a1b049de2ca68da9c6ffc5c48025155cda6a6f2e92d1acf3adb17e",
		"Garden logical digest matches the accepted M02 checkpoint")
	var map_size: OptionButton = scene.get_node("%MapSize")
	map_size.select(1)
	map_size.item_selected.emit(1)
	check(scene.metrics.cells == 2437 and scene.metrics.terrain_meshes == 1, "large map uses one continuous mesh")
	scene.free()
