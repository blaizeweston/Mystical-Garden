extends Node3D

const Build = preload("res://assets/terrain_m02/garden_construction.gd")
const Stations = preload("res://assets/terrain_m02/garden_station_art.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const ANGLE_STEP := PI / 12.0
const VALID := Color("#74e2b2")
const INVALID := Color("#ec8a78")

var model: Build
var parent_view
var enabled := false
var moving := 0
var kind := "bed"
var target := Vector2.INF
var yaw := 0.0
var reason := ""
var toggle: CheckButton
var panel: HBoxContainer
var types: OptionButton
var snap: CheckButton
var move_mode: CheckButton
var apply: Button
var info: Label
var ghost: MeshInstance3D
var marker: MeshInstance3D
var blocker: MeshInstance3D
var blocker_mesh := ImmediateMesh.new()
var blocker_outline := PackedVector2Array()
var blocker_padding := 0.0
var meshes := {}
var objects := {}
var material: StandardMaterial3D
var tint: StandardMaterial3D
var outline: StandardMaterial3D
var query_usec := 0

func bind(owner_view, row: HBoxContainer, status: Label) -> void:
	parent_view = owner_view
	info = status
	toggle = CheckButton.new()
	toggle.text = "Build"
	toggle.toggled.connect(set_enabled)
	row.add_child(toggle)
	panel = HBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	row.get_parent().add_child(panel)
	panel.hide()
	types = OptionButton.new()
	types.item_selected.connect(func(index: int): _choose(Build.CATALOG.keys()[index]))
	panel.add_child(types)
	move_mode = CheckButton.new()
	move_mode.text = "Move"
	move_mode.tooltip_text = "Click a player-built structure, then choose where to move it"
	move_mode.toggled.connect(func(_value: bool): _cancel())
	panel.add_child(move_mode)
	snap = CheckButton.new()
	snap.text = "15° snap"
	snap.button_pressed = true
	snap.toggled.connect(func(_value: bool):
		if snap.button_pressed:
			yaw = snappedf(yaw, ANGLE_STEP)
		_update_ghost())
	panel.add_child(snap)
	apply = _button("Place", func(): confirm())
	_button("Cancel", _cancel)
	var help := Label.new()
	help.text = "Q / E rotate  ·  Enter confirm  ·  Esc cancel"
	panel.add_child(help)
	material = _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	tint = _material(Color(1.0, 1.0, 1.0, 0.50), true)
	outline = _material(VALID, true)
	ghost = _model(self)
	ghost.material_override = tint
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.hide()
	marker = _model(ghost)
	marker.material_override = outline
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blocker = _model(self)
	blocker.mesh = blocker_mesh
	blocker.material_override = _material(Color("#ffc454"), true)
	blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blocker.hide()

func _button(title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	panel.add_child(button)
	return button

func reset(barrier: Build.Forest) -> void:
	set_enabled(false)
	for node: Node3D in objects.values():
		node.free()
	objects.clear()
	model = Build.new(barrier)
	model.knowledge = parent_view.knowledge
	refresh_research()
	set_available(true)

func refresh_research() -> void:
	var index := 0
	types.clear()
	for id: String in Build.CATALOG:
		var reason := model.knowledge.construction_refusal(id, model.records)
		var badge := " · Locked" if not model.knowledge.locked_reason(id).is_empty() else (" · Limit reached" if not reason.is_empty() else "")
		types.add_item(Build.CATALOG[id].name + badge)
		types.set_item_tooltip(index, reason)
		index += 1
	types.select(Build.CATALOG.keys().find(kind))
	_update_ghost()

func set_available(available: bool) -> void:
	toggle.visible = available
	toggle.disabled = not available
	if not available:
		set_enabled(false)

func set_enabled(active: bool) -> void:
	enabled = active and model != null and not parent_view.growing and parent_view.visible
	toggle.set_pressed_no_signal(enabled)
	if enabled:
		parent_view.set_active(false)
		parent_view.walk.button_pressed = false
		toggle.release_focus()
	else:
		if parent_view.visible and parent_view.state != null:
			parent_view._update_controls()
	panel.visible = enabled
	move_mode.set_pressed_no_signal(false)
	_cancel()

func _choose(id: String) -> void:
	types.select(Build.CATALOG.keys().find(id))
	kind = id
	moving = 0
	move_mode.set_pressed_no_signal(false)
	_update_ghost()

func _cancel() -> void:
	moving = 0
	target = Vector2.INF
	ghost.hide()
	blocker.hide()
	apply.disabled = true
	if enabled:
		info.text = "Select a placed structure to move." if move_mode.button_pressed else "Move the pointer over reclaimed land to place a structure."

func preview(at: Vector2) -> void:
	if not enabled or (move_mode.button_pressed and moving == 0):
		return
	if target.distance_squared_to(at) < 0.000025:
		return
	target = at
	_update_ghost()

func turn_ghost(direction: float) -> void:
	var step := ANGLE_STEP if snap.button_pressed else PI / 90.0
	yaw = wrapf(yaw + direction * step, -PI, PI)
	_update_ghost()

func inspect_at(at: Vector2) -> void:
	var entry := model.interaction_at(at)
	if entry.is_empty():
		info.text = "Stand at the front of a player-built structure to inspect it."
		return
	var title := "%s #%d" % [Build.CATALOG[entry.kind].name, entry.id]
	if entry.kind == "bed":
		var crop: String = entry.state.crop
		info.text = title + (" is empty." if crop.is_empty() else " holds " + crop + ".")
	else:
		info.text = title + " is ready."

func press(at: Vector2) -> void:
	if move_mode.button_pressed and moving == 0:
		for id: int in model.records:
			var record: Dictionary = model.records[id]
			if Shape.contains(record.footprint, at):
				moving = id
				kind = record.kind
				yaw = record.yaw
				types.select(Build.CATALOG.keys().find(kind))
				target = record.at
				_update_ghost()
				return
		info.text = "Select a player-built structure. Starter landmarks are fixed."
		return
	target = at
	confirm()

func confirm() -> int:
	if not enabled or not target.is_finite() or (move_mode.button_pressed and moving == 0):
		return 0
	var id := model.commit(kind, target, yaw, parent_view.pawn, moving)
	if id == 0:
		_update_ghost()
		return 0
	if not objects.has(id):
		var node := _model(self)
		node.mesh = _mesh(kind)
		node.material_override = material
		objects[id] = node
	objects[id].position = Vector3(target.x, 0.025, target.y)
	objects[id].rotation.y = -yaw
	target = Vector2.INF
	moving = 0
	ghost.hide()
	blocker.hide()
	apply.disabled = true
	parent_view._update_reset_availability()
	refresh_research()
	info.text = "%s #%d ready. %d structures in the Garden." % [Build.CATALOG[kind].name, id, model.records.size()]
	return id

func _update_ghost() -> void:
	if not enabled or not target.is_finite():
		return
	var started := Time.get_ticks_usec()
	var issue := model.placement_issue(kind, target, yaw, parent_view.pawn, moving)
	query_usec = Time.get_ticks_usec() - started
	reason = issue.get("message", "")
	_show_blocker(issue.get("blocker", {}), issue.get("padding", 0.0))
	var color := VALID if reason.is_empty() else INVALID
	tint.albedo_color = Color(color, 0.56)
	outline.albedo_color = color
	ghost.mesh = _mesh(kind)
	ghost.position = Vector3(target.x, 0.04, target.y)
	ghost.rotation.y = -yaw
	ghost.show()
	marker.mesh = _footprint_mesh(kind)
	apply.text = "Relocate" if moving != 0 else "Place"
	apply.disabled = not reason.is_empty()
	info.text = reason if not reason.is_empty() else "%s  ·  %d°  ·  Ready to %s" % [
		Build.CATALOG[kind].name, roundi(rad_to_deg(yaw)), "relocate" if moving != 0 else "place"]

func _show_blocker(feature: Dictionary, padding: float) -> void:
	blocker.visible = not feature.is_empty()
	if not blocker.visible:
		return
	var points := Shape.boundary(feature)
	if points == blocker_outline and is_equal_approx(padding, blocker_padding):
		return
	blocker_outline = points
	blocker_padding = padding
	var boundaries := Geometry2D.offset_polygon(points, padding) if padding > 0.0 else [points]
	if boundaries.is_empty():
		boundaries.append(points)
	blocker_mesh.clear_surfaces()
	for boundary: PackedVector2Array in boundaries:
		blocker_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in boundary:
			blocker_mesh.surface_add_vertex(Vector3(point.x, 0.085, point.y))
		blocker_mesh.surface_add_vertex(Vector3(boundary[0].x, 0.085, boundary[0].y))
		blocker_mesh.surface_end()

func _mesh(id: String) -> Mesh:
	if not meshes.has(id):
		meshes[id] = Stations.build(Build.CATALOG[id].art)
	return meshes[id]

func _footprint_mesh(id: String) -> Mesh:
	var key := id + "_footprint"
	if meshes.has(key):
		return meshes[key]
	var half: Vector2 = Build.CATALOG[id].half
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for at: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		mesh.surface_add_vertex(Vector3(at.x * half.x, 0.025, at.y * half.y))
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_add_vertex(Vector3(-0.19, 0.025, half.y + 0.06))
	mesh.surface_add_vertex(Vector3(0.19, 0.025, half.y + 0.06))
	mesh.surface_add_vertex(Vector3(0, 0.025, half.y + 0.37))
	mesh.surface_end()
	meshes[key] = mesh
	return mesh

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result

func _model(parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	parent.add_child(node)
	return node
