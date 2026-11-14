extends Node3D
## Input and presentation for the isolated Garden. The model retains all ownership state.

signal camera_changed(target: Vector2, size: float)

const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const RootMeshes = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const GateMesh = preload("res://assets/terrain_m02/wilds_massing_mesh.gd")
const ALTAR = preload("res://assets/altar.glb")
const REVEAL_TIME := 1.65
const MAX_ZOOM := 27.0
const OVERVIEW_ZOOM := 27.0

var state: Garden
var material: ShaderMaterial
var enclosure: Node3D
var bar: HBoxContainer
var enter: CheckButton
var choices: OptionButton
var confirm: Button
var cancel: Button
var reset: Button
var debug: CheckButton
var status: Label
var focus := Vector2.ZERO
var zoom := 16.5
var preview: Dictionary = {}
var active := false
var growing := false
var roots: Node3D
var landmark_view: Node3D
var markers: Node3D
var debug_view: MeshInstance3D
var footprint: MeshInstance3D
var footprint_border: MeshInstance3D
var root_material: StandardMaterial3D
var root_mesh: MeshInstance3D
var tween: Tween
var rim_from: PackedFloat32Array
var rim_to: PackedFloat32Array
var base_rim: PackedFloat32Array
var last_metrics := {}
var max_animation_usec := 0
var last_root_tip := -1

func bind_controls(container: HBoxContainer, info: Label, forest: Node3D) -> void:
	bar = container
	status = info
	enclosure = forest
	enter = CheckButton.new()
	enter.text = "Expand Garden"
	bar.add_child(enter)
	enter.toggled.connect(set_active)
	choices = OptionButton.new()
	choices.tooltip_text = "Choose a frontier or click a gold marker on the map"
	bar.add_child(choices)
	choices.item_selected.connect(func(index): select_frontier(choices.get_item_id(index)))
	confirm = _button("Confirm growth", confirm_growth)
	cancel = _button("Cancel", func(): set_active(false))
	reset = _button("Reset Garden", reset_garden)
	debug = CheckButton.new()
	debug.text = "Land ownership"
	debug.tooltip_text = "Show starting, newly reclaimed and protected hexes"
	debug.toggled.connect(func(_on): _build_debug())
	bar.add_child(debug)
	roots = Node3D.new()
	add_child(roots)
	landmark_view = Node3D.new()
	add_child(landmark_view)
	markers = Node3D.new()
	add_child(markers)
	debug_view = _mesh_node(self)
	footprint = _mesh_node(self)
	footprint.material_override = _material(Color(0.87, 0.66, 0.31, 0.24), true)
	footprint_border = _mesh_node(self)
	footprint_border.material_override = _material(Color(1.0, 0.76, 0.40, 0.92), true)
	root_material = _material(Color.WHITE, false, true)
	bar.hide()
	status.hide()

func _button(title: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = title
	item.pressed.connect(action)
	bar.add_child(item)
	return item

func start(cells: Dictionary, features: Dictionary, spacing: float, seed_number: int, radius: int) -> void:
	clear()
	state = Garden.new(cells, features, spacing, seed_number, radius)
	base_rim = state.enclosure_support()
	focus = Vector2.ZERO
	zoom = 16.5
	_landmarks()

func show_garden(enabled: bool) -> void:
	if not enabled:
		finish_animation()
		set_active(false)
	visible = enabled
	bar.visible = enabled
	status.visible = enabled
	if enabled:
		_build_debug()
		_update_controls()

func attach_material(ground: ShaderMaterial) -> void:
	material = ground
	var perimeter := state.enclosure_support()
	_set_rim(perimeter, perimeter, 1.0)

func clear() -> void:
	if tween != null:
		tween.kill()
		tween = null
	growing = false
	active = false
	state = null
	preview = {}
	last_metrics = {}
	for group in [roots, landmark_view, markers]:
		_clear_children(group)
	debug_view.mesh = null
	footprint.mesh = null
	footprint_border.mesh = null
	show_garden(false)

func reset_garden() -> void:
	if state == null or growing:
		return
	state = Garden.new(state.terrain, state.layout, state.spacing, state.seed_value,
		roundi(state.extent / state.spacing))
	base_rim = state.enclosure_support()
	_clear_children(roots)
	_set_rim(base_rim, base_rim, 1.0)
	_build_debug()
	_update_controls()

func set_active(enabled: bool) -> void:
	active = enabled and state != null and not growing
	if active:
		focus = Vector2.ZERO
		zoom = OVERVIEW_ZOOM
		camera_changed.emit(focus, zoom)
	_update_controls()

func _update_controls() -> void:
	enter.set_pressed_no_signal(active)
	enter.disabled = growing
	choices.visible = active
	confirm.visible = active
	cancel.visible = active
	reset.disabled = growing or state == null or state.revision == 0
	choices.clear()
	preview = {}
	footprint.mesh = null
	footprint_border.mesh = null
	_clear_children(markers)
	if state == null:
		return
	if active:
		choices.add_item("Choose a frontier", 100)
		for proposal: Dictionary in state.frontier_options():
			var sector: int = proposal.sector
			choices.add_item(Garden.DIRECTIONS[sector], sector)
			_marker(proposal.frontier, sector, Garden.DIRECTIONS[sector])
		status.text = "Click a marked frontier to preview the Heart’s growth." if choices.item_count > 1 else "No connected frontier fits here."
	elif growing:
		status.text = "The Heart is reclaiming the clearing…"
	else:
		status.text = "%d reclaimed clearings  ·  %d usable hexes" % [state.revision, state.available.size()]
	confirm.disabled = true

func select_frontier(sector: int) -> bool:
	if not active:
		return false
	preview = state.proposal(sector)
	confirm.disabled = preview.is_empty()
	footprint.mesh = null if preview.is_empty() else _surface(preview.new_area)
	footprint_border.mesh = null if preview.is_empty() else _border(preview.new_area)
	if preview.is_empty():
		status.text = "That frontier cannot be reached safely."
		return false
	choices.select(choices.get_item_index(sector))
	status.text = "%s frontier  ·  %d usable hexes  ·  approximately %.1f square units" % [
		Garden.DIRECTIONS[sector], preview.cells.size(), preview.area]
	return true

func click_frontier(at: Vector2) -> void:
	var best := 2.4
	var sector := -1
	for marker in markers.get_children():
		var distance := at.distance_to(Vector2(marker.position.x, marker.position.z))
		if distance < best:
			best = distance
			sector = marker.get_meta("sector")
	select_frontier(sector)

func confirm_growth() -> void:
	if not active or preview.is_empty():
		return
	var started := Time.get_ticks_usec()
	var proposal := preview
	rim_from = state.enclosure_support()
	if not state.apply(proposal):
		_update_controls()
		status.text = "The frontier changed. Choose it again."
		return
	var logical := Time.get_ticks_usec()
	rim_to = state.enclosure_support()
	root_mesh = _mesh_node(roots)
	root_mesh.material_override = root_material
	last_root_tip = -1
	max_animation_usec = 0
	growing = true
	active = false
	_update_controls()
	_set_rim(rim_from, rim_to, 0.0)
	_animate(0.0)
	last_metrics = {"cells_gained": proposal.cells.size(), "area": proposal.area,
		"mutation_usec": logical - started, "setup_usec": Time.get_ticks_usec() - logical}
	tween = create_tween()
	tween.tween_method(_animate, 0.0, 1.0, REVEAL_TIME)
	tween.finished.connect(finish_animation)

func _animate(progress: float) -> void:
	var started := Time.get_ticks_usec()
	var root: PackedVector2Array = state.roots[-1]
	var tip := clampi(ceili(progress * root.size()), 2, root.size())
	if tip != last_root_tip:
		last_root_tip = tip
		root_mesh.mesh = RootMeshes.reclaiming_root(root, tip)
	var reveal := smoothstep(0.32, 1.0, progress)
	material.set_shader_parameter("garden_reveal", reveal)
	enclosure.position_frontier(rim_from, rim_to, reveal)
	max_animation_usec = maxi(max_animation_usec, Time.get_ticks_usec() - started)

func finish_animation() -> void:
	if not growing:
		return
	if tween != null:
		tween.kill()
		tween = null
	_animate(1.0)
	growing = false
	last_metrics["peak_animation_update_usec"] = max_animation_usec
	_build_debug()
	_update_controls()

func _set_rim(from: PackedFloat32Array, to: PackedFloat32Array, progress: float) -> void:
	var packed := PackedFloat32Array()
	for i in from.size():
		packed.append_array([from[i], to[i], base_rim[i], 0.0])
	var image := Image.create_from_data(from.size(), 1, false, Image.FORMAT_RGBAF, packed.to_byte_array())
	material.set_shader_parameter("garden_perimeter", ImageTexture.create_from_image(image))
	material.set_shader_parameter("garden_reveal", progress)
	enclosure.position_frontier(from, to, progress)

func set_camera(target: Vector2, size: float) -> void:
	focus = target.limit_length(state.extent * 0.80)
	zoom = clampf(size, 5.0, MAX_ZOOM)
	camera_changed.emit(focus, zoom)

func _landmarks() -> void:
	for id in ["wilds_entrance", "altar", "starter_bed"]:
		var node := _mesh_node(landmark_view)
		var at: Vector2 = state.landmarks[id].center
		node.position = Vector3(at.x, 0.035, at.y)
		node.name = id
		if id == "wilds_entrance":
			node.mesh = GateMesh.gate()
			node.material_override = _material(Color.WHITE, false, true)
			continue
		if id == "altar":
			var altar := ALTAR.instantiate() as Node3D
			altar.scale = Vector3.ONE * 0.58
			node.add_child(altar)
			continue
		var marker := CylinderMesh.new()
		marker.top_radius = 0.80
		marker.bottom_radius = 0.88
		marker.height = 0.18
		marker.radial_segments = 9
		node.mesh = marker
		node.material_override = _material(Color("#5a3527"))

func _marker(at: Vector2, sector: int, title: String) -> void:
	var marker := _mesh_node(markers)
	var glyph := TorusMesh.new()
	glyph.inner_radius = 0.34
	glyph.outer_radius = 0.48
	glyph.rings = 16
	glyph.ring_segments = 8
	marker.mesh = glyph
	marker.material_override = _material(Color("#efc478"), true)
	marker.position = Vector3(at.x, 0.25, at.y)
	marker.set_meta("sector", sector)
	var label := Label3D.new()
	label.text = title
	label.position = Vector3(0.0, 1.25, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 44
	label.pixel_size = 0.011
	label.modulate = Color("#ffe6a7")
	marker.add_child(label)

func _build_debug() -> void:
	debug_view.mesh = null
	if state == null or not debug.button_pressed:
		return
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, _material(Color.WHITE, true, true))
	for cell: Vector2i in state.owned:
		var tint := Color("#a5ac71") if state.owned[cell] == 0 else Color("#7cebbb")
		if state.reserved_cells.has(cell):
			tint = Color("#f4ab60")
		lines.surface_set_color(tint)
		for i in 6:
			for corner in [i, (i + 1) % 6]:
				var point := Grid.key_to_world(Grid.corner_key(cell, corner), state.spacing)
				lines.surface_add_vertex(Vector3(point.x, 0.088, point.y))
	lines.surface_end()
	debug_view.mesh = lines

func _surface(points: PackedVector2Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in Geometry2D.triangulate_polygon(points):
		var point := points[index]
		tool.add_vertex(Vector3(point.x, 0.065, point.y))
	return tool.commit()

func _border(points: PackedVector2Array) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in points.size() + 1:
		var at := points[i % points.size()]
		mesh.surface_add_vertex(Vector3(at.x, 0.077, at.y))
	mesh.surface_end()
	return mesh

func _material(color: Color, unshaded: bool = false, vertex: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.vertex_color_use_as_albedo = vertex
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.no_depth_test = true
	return result

func _mesh_node(parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	parent.add_child(node)
	return node

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.free()
