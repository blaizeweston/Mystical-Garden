extends Node3D
## Input and presentation for the isolated Garden. The model retains all ownership state.

signal camera_changed(target: Vector2, size: float)

const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const RootArt = preload("res://assets/terrain_m02/garden_heart_roots.gd")
const Forest = preload("res://assets/terrain_m02/garden_forest_barrier.gd")
const Stations = preload("res://assets/terrain_m02/garden_station_art.gd")
const Construction = preload("res://assets/terrain_m02/garden_construction_view.gd")
const Knowledge = preload("res://assets/terrain_m02/garden_knowledge.gd")
const KnowledgeView = preload("res://assets/terrain_m02/garden_knowledge_view.gd")
const Offerings = preload("res://assets/terrain_m02/garden_offerings.gd")
const OfferingsView = preload("res://assets/terrain_m02/garden_offerings_view.gd")
const BARK_SHADER = preload("res://assets/terrain_m02/heart_bark.gdshader")
const GateMesh = preload("res://assets/terrain_m02/wilds_massing_mesh.gd")
const ALTAR = preload("res://assets/altar.glb")
const REVEAL_TIME := 2.45
const MAX_ZOOM := 27.0
const OVERVIEW_ZOOM := 27.0

var state: Garden
var material: ShaderMaterial
var enclosure: Node3D
var bar: HBoxContainer
var enter: CheckButton
var frontier_controls: HBoxContainer
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
var heart: Node3D
var barrier: Forest
var construction: Construction
var knowledge := Knowledge.new()
var knowledge_dialog: KnowledgeView
var offerings := Offerings.new()
var offering_dialog: OfferingsView
var walker: MeshInstance3D
var walk: CheckButton
var comparison: CheckButton
var pawn := Vector2.ZERO
var station_meshes := {}
var root_mesh: MeshInstance3D
var network: Array[Dictionary] = []
var tween: Tween
var rim_from: PackedFloat32Array
var rim_to: PackedFloat32Array
var base_rim: PackedFloat32Array
var last_metrics := {}
var max_animation_usec := 0
var root_stage := 0
var breach := 0.64

func bind_controls(container: HBoxContainer, info: Label, forest: Node3D) -> void:
	bar = container
	status = info
	enclosure = forest
	enter = CheckButton.new()
	enter.text = "Expand Garden"
	bar.add_child(enter)
	enter.toggled.connect(set_active)
	frontier_controls = HBoxContainer.new()
	frontier_controls.add_theme_constant_override("separation", 8)
	bar.get_parent().add_child(frontier_controls)
	frontier_controls.hide()
	choices = OptionButton.new()
	choices.tooltip_text = "Choose a frontier or click a gold marker on the map"
	frontier_controls.add_child(choices)
	choices.item_selected.connect(func(index): select_frontier(choices.get_item_id(index)))
	confirm = _button("Confirm growth", confirm_growth, frontier_controls)
	cancel = _button("Cancel", func(): set_active(false), frontier_controls)
	reset = _button("Reset Garden", reset_garden)
	debug = CheckButton.new()
	debug.text = "Land ownership"
	debug.tooltip_text = "Show starting, newly reclaimed and protected hexes"
	debug.toggled.connect(func(_on): _build_debug())
	bar.add_child(debug)
	walk = CheckButton.new()
	walk.text = "Walk Garden"
	walk.tooltip_text = "WASD or arrows to walk the Garden and test the forest boundary"
	bar.add_child(walk)
	walk.toggled.connect(_walk_enabled)
	comparison = CheckButton.new()
	comparison.text = "M11 props"
	comparison.tooltip_text = "Compare the original altar and plot at the same locations"
	bar.add_child(comparison)
	comparison.toggled.connect(func(_on): _landmarks())
	_button("Knowledge", _open_knowledge)
	knowledge_dialog = KnowledgeView.new()
	add_child(knowledge_dialog)
	knowledge.changed.connect(_refresh_knowledge)
	barrier = Forest.new()
	add_child(barrier)
	construction = Construction.new()
	add_child(construction)
	construction.bind(self, bar, status)
	_button("Offerings", open_offerings).tooltip_text = "Offer parts to the Heart"
	offering_dialog = OfferingsView.new()
	add_child(offering_dialog)
	offering_dialog.contributed.connect(_refresh_offerings)
	walker = _mesh_node(self)
	var capsule := CapsuleMesh.new()
	capsule.height = 1.62
	capsule.radius = 0.23
	walker.mesh = capsule
	walker.material_override = _material(Color("#d4c192"))
	walker.hide()
	set_physics_process(false)
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
	bar.hide()
	status.hide()

func _button(title: String, action: Callable, container: HBoxContainer = null) -> Button:
	var item := Button.new()
	item.text = title
	item.pressed.connect(action)
	(container if container != null else bar).add_child(item)
	return item

func start(cells: Dictionary, features: Dictionary, spacing: float, seed_number: int, radius: int) -> void:
	clear()
	# Selecting a new seed, spacing or map size starts a new lab Garden.
	var test_mode := knowledge.sandbox
	knowledge = Knowledge.new()
	knowledge.sandbox = test_mode
	knowledge.changed.connect(_refresh_knowledge)
	offerings = Offerings.new()
	state = Garden.new(cells, features, spacing, seed_number, radius)
	barrier.bind(state)
	construction.reset(barrier)
	pawn = state.layout.paths[0].spine[-1]
	base_rim = state.enclosure_support()
	focus = Vector2.ZERO
	zoom = 16.5
	_landmarks()

func show_garden(enabled: bool) -> void:
	if not enabled:
		knowledge_dialog.hide()
		offering_dialog.hide()
		finish_animation()
		set_active(false)
		walk.button_pressed = false
		construction.set_available(false)
	visible = enabled
	bar.visible = enabled
	status.visible = enabled
	if enabled:
		construction.set_available(not growing)
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
	if heart != null and heart.use_sculpt:
		heart.reclaim_light(0.0)
	active = false
	walk.set_pressed_no_signal(false)
	comparison.set_pressed_no_signal(false)
	_walk_enabled(false)
	state = null
	preview = {}
	last_metrics = {}
	for group in [roots, landmark_view, markers]:
		_clear_children(group)
	network.clear()
	debug_view.mesh = null
	footprint.mesh = null
	footprint_border.mesh = null
	show_garden(false)

func reset_garden() -> void:
	if state == null or growing:
		return
	state = Garden.new(state.terrain, state.layout, state.spacing, state.seed_value,
		roundi(state.extent / state.spacing))
	barrier.bind(state)
	offerings = Offerings.new()
	construction.reset(barrier)
	pawn = state.layout.paths[0].spine[-1]
	base_rim = state.enclosure_support()
	_clear_children(roots)
	network.clear()
	_set_rim(base_rim, base_rim, 1.0)
	_build_debug()
	_update_controls()

func set_active(enabled: bool) -> void:
	active = enabled and state != null and not growing and _can_expand()
	if active:
		construction.set_enabled(false)
		walk.button_pressed = false
		focus = Vector2.ZERO
		zoom = OVERVIEW_ZOOM
		camera_changed.emit(focus, zoom)
	_update_controls()

func _update_controls() -> void:
	enter.set_pressed_no_signal(active)
	enter.disabled = growing or not _can_expand()
	enter.tooltip_text = "Choose a frontier to reclaim." if _can_expand() else "Research a clearing upgrade in Knowledge."
	frontier_controls.visible = active
	_update_reset_availability()
	choices.clear()
	preview = {}
	footprint.mesh = null
	footprint_border.mesh = null
	_clear_children(markers)
	if state == null:
		return
	if active:
		choices.add_item("Choose a frontier", 100)
		var limited := 0
		for sector in Garden.DIRECTIONS.size():
			var proposal := state.proposal(sector, true)
			if proposal.get("coverage_limited", false):
				limited += 1
				continue
			if proposal.is_empty():
				continue
			var label := "%s · %d energy" % [Garden.DIRECTIONS[sector], _growth_cost(proposal)]
			choices.add_item(label, sector)
			_marker(proposal.frontier, sector, Garden.DIRECTIONS[sector])
		status.text = "%d growth energy stored. Choose a frontier." % offerings.energy if choices.item_count > 1 else "No connected frontier fits here."
		if limited > 0:
			status.text += " The generated terrain limit blocks %d of %d directions." % [limited, Garden.DIRECTIONS.size()]
	elif growing:
		status.text = "The Heart is reclaiming the clearing…"
	else:
		status.text = "%d reclaimed clearings  ·  %d usable hexes  ·  %d growth energy" % [state.revision, state.available.size(), offerings.energy]
	confirm.disabled = true

func _can_expand() -> bool:
	return state != null and (knowledge.sandbox or knowledge.clearing_tier() > 0)

func _growth_cost(proposal: Dictionary) -> int:
	return 0 if knowledge.sandbox else offerings.expansion_cost(proposal, state.reclaimed_cells, knowledge.clearing_tier())

func open_offerings() -> void:
	if state != null and not growing and visible:
		offering_dialog.present(offerings)

func _refresh_offerings() -> void:
	if active and not preview.is_empty():
		select_frontier(int(preview.sector))
	else:
		_update_controls()

func _open_knowledge() -> void:
	if state == null or growing:
		return
	knowledge_dialog.present(knowledge, construction.model.records)

func _refresh_knowledge() -> void:
	if state == null:
		return
	if not _can_expand():
		active = false
	_update_controls()
	construction.refresh_research()
	if knowledge_dialog.visible:
		knowledge_dialog.refresh()

func _update_reset_availability() -> void:
	reset.disabled = growing or state == null or (state.revision == 0 and construction.model.records.is_empty())

func select_frontier(sector: int) -> bool:
	if not active:
		return false
	preview = state.proposal(sector)
	confirm.disabled = preview.is_empty() or _growth_cost(preview) > offerings.energy
	footprint.mesh = null if preview.is_empty() else _surface(preview.new_area)
	footprint_border.mesh = null if preview.is_empty() else _border(preview.new_area)
	if preview.is_empty():
		status.text = "That frontier cannot be reached safely."
		return false
	choices.select(choices.get_item_index(sector))
	status.text = "%s frontier  ·  %d usable hexes  ·  approximately %.1f square units" % [
		Garden.DIRECTIONS[sector], preview.cells.size(), preview.area]
	status.text += "  ·  %d energy needed / %d stored" % [_growth_cost(preview), offerings.energy]
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
	if not active or preview.is_empty() or not _can_expand():
		return
	var started := Time.get_ticks_usec()
	var proposal := preview
	var cost := _growth_cost(proposal)
	if cost > offerings.energy:
		confirm.disabled = true
		status.text = "This expansion needs %d growth energy. The Heart holds %d." % [cost, offerings.energy]
		return
	var original_outline := state.outline
	rim_from = state.enclosure_support()
	if not state.apply(proposal):
		_update_controls()
		status.text = "The frontier changed. Choose it again."
		return
	offerings.energy -= cost
	var logical := Time.get_ticks_usec()
	rim_to = state.enclosure_support()
	barrier.begin_shape(original_outline, state.outline)
	root_mesh = _mesh_node(roots)
	root_stage = heart.stage
	_set_root(root_mesh, state.roots[-1])
	var plan: Dictionary = root_mesh.get_meta("root_plan")
	breach = 0.64
	for i in plan.main.size():
		var at: Vector3 = plan.main[i]
		if not Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), original_outline):
			breach = lerpf(0.14, 0.91, float(i) / (plan.main.size() - 1))
			break
	max_animation_usec = 0
	growing = true
	construction.set_available(false)
	active = false
	_update_controls()
	_set_rim(rim_from, rim_to, 0.0)
	_animate(0.0)
	last_metrics = {"cells_gained": proposal.cells.size(), "area": proposal.area, "energy_spent": cost,
		"mutation_usec": logical - started, "setup_usec": Time.get_ticks_usec() - logical}
	tween = create_tween()
	tween.tween_method(_animate, 0.0, 1.0, REVEAL_TIME)
	tween.finished.connect(finish_animation)

func _animate(progress: float) -> void:
	var started := Time.get_ticks_usec()
	var light := smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.57, 1.0, progress))
	heart.reclaim_light(light)
	var bark := root_mesh.material_override as ShaderMaterial
	var advance := 0.89 * clampf(inverse_lerp(0.14, 0.91, progress), 0.0, 1.0)
	advance += 0.11 * smoothstep(0.91, 1.0, progress)
	bark.set_shader_parameter("root_progress", advance)
	bark.set_shader_parameter("reclaim_pulse", light)
	var reveal := smoothstep(maxf(0.32, breach - 0.06), 1.0, progress)
	material.set_shader_parameter("garden_reveal", reveal)
	enclosure.position_frontier(rim_from, rim_to, reveal)
	barrier.update_shape(reveal)
	max_animation_usec = maxi(max_animation_usec, Time.get_ticks_usec() - started)

func finish_animation() -> void:
	if not growing:
		return
	if tween != null:
		tween.kill()
		tween = null
	_animate(1.0)
	growing = false
	construction.set_available(true)
	last_metrics["peak_animation_update_usec"] = max_animation_usec
	_build_debug()
	_update_controls()

func change_heart_stage(index: int) -> void:
	if growing:
		finish_animation()
	root_stage = index
	if state == null:
		return
	network.clear()
	for i in roots.get_child_count():
		_set_root(roots.get_child(i), state.roots[i])

func _set_root(node: MeshInstance3D, path: PackedVector2Array) -> void:
	var plan := RootArt.plan(path, root_stage, state, network)
	network.append(plan)
	node.mesh = RootArt.mesh(plan)
	node.set_meta("root_plan", plan)
	var bark := ShaderMaterial.new()
	bark.shader = BARK_SHADER
	bark.set_shader_parameter("growing_root", true)
	node.material_override = bark

func _walk_enabled(enabled: bool) -> void:
	if enabled and state != null:
		construction.set_enabled(false)
		set_active(false)
		walker.position = Vector3(pawn.x, 0.81, pawn.y)
		set_camera(pawn, 16.5)
		status.text = "Walk with WASD or arrows. Press E at the Heart or at a player-built structure."
	walker.visible = enabled
	set_physics_process(enabled)

func _physics_process(delta: float) -> void:
	if not visible or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var axis := Vector2(int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		- int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if axis.is_zero_approx():
		return
	var step := axis.normalized() * delta * 4.6
	var target := barrier.move(pawn, step)
	if target.distance_squared_to(pawn + step) > 0.000001:
		var along_x := barrier.move(target, Vector2(pawn.x + step.x - target.x, 0))
		var along_z := barrier.move(target, Vector2(0, pawn.y + step.y - target.y))
		target = along_x if along_x.distance_squared_to(pawn + step) < along_z.distance_squared_to(pawn + step) else along_z
	pawn = target
	walker.position = Vector3(pawn.x, 0.81, pawn.y)
	set_camera(pawn, zoom)

func _set_rim(from: PackedFloat32Array, to: PackedFloat32Array, progress: float) -> void:
	var from_outline: PackedVector2Array = barrier.starts
	var to_outline: PackedVector2Array = barrier.finishes
	var packed := PackedFloat32Array()
	for i in from_outline.size():
		packed.append_array([from_outline[i].length(), to_outline[i].length(), base_rim[i], 0.0])
	var image := Image.create_from_data(from_outline.size(), 1, false, Image.FORMAT_RGBAF, packed.to_byte_array())
	material.set_shader_parameter("garden_perimeter", ImageTexture.create_from_image(image))
	material.set_shader_parameter("garden_reveal", progress)
	enclosure.position_frontier(from, to, progress)

func set_camera(target: Vector2, size: float) -> void:
	focus = target.limit_length(state.extent * 0.80)
	zoom = clampf(size, 5.0, MAX_ZOOM)
	camera_changed.emit(focus, zoom)

func _landmarks() -> void:
	if state == null:
		return
	_clear_children(landmark_view)
	for id: String in state.landmarks:
		if id == "heart" or (comparison.button_pressed and id not in ["wilds_entrance", "altar", "starter_bed"]):
			continue
		var node := _mesh_node(landmark_view)
		var at: Vector2 = state.landmarks[id].center
		node.position = Vector3(at.x, 0.035, at.y)
		node.name = id
		if id == "wilds_entrance":
			node.mesh = GateMesh.gate()
			node.material_override = _material(Color.WHITE, false, true)
			continue
		if not comparison.button_pressed:
			if not station_meshes.has(id):
				station_meshes[id] = Stations.build(id)
			node.mesh = station_meshes[id]
			node.scale = Vector3.ONE * state.landmarks[id].radius
			node.material_override = _material(Color.WHITE, false, true)
			node.set_meta("label", Stations.NAMES[id])
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
