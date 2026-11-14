extends Node3D
## Preview presentation and input only. The simulation determines all clear and Gate outcomes.

signal exit_requested

const Boundary = preload("res://assets/terrain_m02/wilds_boundary.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Simulation = preload("res://assets/terrain_m02/wilds_play_simulation.gd")
const Fog = preload("res://assets/terrain_m02/wilds_play_fog.gdshader")
const CAMERA_OFFSET := Vector3(3.3, 14.0, 14.0)
const PIXEL := 0.28
const MOVE_SPEED := 4.6

var run: Simulation
var allow_camera_control := false
var pan := Vector2.ZERO
var camera: Camera3D
var fog: ColorRect
var deck_gate: Node3D
var readout: Label
var marker: MeshInstance3D
var indicator: MeshInstance3D
var gate_tint: StandardMaterial3D
var figures: Dictionary = {}
var explored: Image
var texture: ImageTexture
var map_margin: float
var last_reveal := Vector2.INF
var fog_enabled := true

func _ready() -> void:
	set_physics_process(false)

func start(cells: Dictionary, layout: Dictionary, spacing: float) -> bool:
	stop()
	run = Simulation.new(Surface.new(cells, layout, spacing))
	if not run.ready:
		run = null
		readout.text = "This seed has no certified route to all required encounters. Try another seed."
		return false
	marker = _pawn(Color("#e4d4a0"), 0.27, 1.72)
	for enemy in run.encounters:
		var target := _pawn(Color("#ad5846"), 0.33, 1.30)
		target.position = _world(enemy.position, 0.65)
		figures[enemy.id] = target
	gate_tint = StandardMaterial3D.new()
	gate_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	indicator = MeshInstance3D.new()
	var band := TorusMesh.new()
	band.inner_radius = 0.65
	band.outer_radius = 0.75
	indicator.mesh = band
	indicator.material_override = gate_tint
	indicator.position = _world(run.gate, 0.10)
	add_child(indicator)
	map_margin = (layout.grid_radius + 1.0) * spacing
	var size := ceili(2.0 * map_margin / PIXEL)
	explored = Image.create_empty(size, size, false, Image.FORMAT_R8)
	explored.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(explored)
	var material := ShaderMaterial.new()
	material.shader = Fog
	material.set_shader_parameter("world_min", Vector2.ONE * -map_margin)
	material.set_shader_parameter("world_size", Vector2.ONE * map_margin * 2.0)
	material.set_shader_parameter("explored", texture)
	fog.material = material
	run.observe()
	_update_view()
	set_physics_process(true)
	return true

func stop() -> void:
	run = null
	pan = Vector2.ZERO
	set_physics_process(false)
	explored = null
	texture = null
	for node in get_children():
		node.free()
	figures.clear()
	if is_instance_valid(deck_gate):
		deck_gate.show()
	if fog != null:
		fog.hide()
		fog.material = null
	last_reveal = Vector2.INF

func _physics_process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var input := Vector2(
		int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if not input.is_zero_approx():
		step(input.normalized() * MOVE_SPEED * delta)

func step(delta: Vector2) -> void:
	run.move(delta)
	_update_view()

func _unhandled_key_input(event: InputEvent) -> void:
	if run == null or not event.is_pressed() or event.is_echo():
		return
	match event.physical_keycode:
		KEY_SPACE:
			perform_strike()
		KEY_E:
			interact_gate()
		KEY_ESCAPE:
			exit_requested.emit()
		_:
			return
	get_viewport().set_input_as_handled()

func perform_strike() -> void:
	var defeated := run.strike()
	_update_view()
	if defeated.is_empty() and not run.finished:
		readout.text += "  No visible marker in reach."

func interact_gate() -> void:
	var used := run.use_gate()
	_update_view()
	if not used and not run.finished:
		if not run.gate_discovered:
			readout.text += "  Find the Gate."
		elif not run.gate_active():
			readout.text += "  Clear the remaining enemies first."
		else:
			readout.text += "  Move closer to the Gate."

func set_fog(enabled: bool) -> void:
	fog_enabled = enabled
	if run != null:
		_update_view()

func _update_view() -> void:
	var target := _world(run.position)
	marker.position = target + Vector3.UP * 0.86
	_follow_camera()
	_reveal()
	_align_fog()
	fog.visible = fog_enabled
	for enemy in run.encounters:
		figures[enemy.id].visible = not enemy.cleared and (not fog_enabled
			or (run.position.distance_to(enemy.position) <= Simulation.SIGHT
				and run.surface.clear_line(run.position, enemy.position)))
	var show_gate := run.gate_discovered or not fog_enabled
	if is_instance_valid(deck_gate):
		deck_gate.visible = show_gate
	indicator.visible = show_gate
	gate_tint.albedo_color = Color("#78d6a7") if run.gate_active() else Color("#d68b53")
	var gate_status := "Gate undiscovered"
	if run.gate_discovered:
		gate_status = "Gate active" if run.gate_active() else "Gate sealed"
	readout.text = "%d required enemies left  |  %s" % [run.remaining(), gate_status]
	if run.finished:
		readout.text = "Floor cleared. Gate entered. Restart to explore again."

func set_pan(offset: Vector2) -> void:
	pan = offset.limit_length(Boundary.MAX_PAN)
	_follow_camera()
	_align_fog()

func _follow_camera() -> void:
	var focus := _world(run.position + pan)
	camera.position = focus + CAMERA_OFFSET
	camera.look_at(focus)

func _reveal() -> void:
	if last_reveal.distance_to(run.position) < PIXEL:
		return
	last_reveal = run.position
	var density := explored.get_width() / (2.0 * map_margin)
	var center := (run.position + Vector2.ONE * map_margin) * density
	var range_px := Simulation.SIGHT * density
	for y in range(maxi(0, floori(center.y - range_px)), mini(explored.get_height(), ceili(center.y + range_px))):
		for x in range(maxi(0, floori(center.x - range_px)), mini(explored.get_width(), ceili(center.x + range_px))):
			var distance := (Vector2(x + 0.5, y + 0.5) - center).length() / range_px
			var value := 1.0 - smoothstep(0.79, 1.0, distance)
			if value > explored.get_pixel(x, y).r:
				explored.set_pixel(x, y, Color(value, 0.0, 0.0))
	texture.update(explored)

func _align_fog() -> void:
	var corner := _ground(Vector2.ZERO)
	var size := get_viewport().get_visible_rect().size
	var material := fog.material as ShaderMaterial
	material.set_shader_parameter("screen_origin", corner)
	material.set_shader_parameter("screen_across", _ground(Vector2(size.x, 0.0)) - corner)
	material.set_shader_parameter("screen_down", _ground(Vector2(0.0, size.y)) - corner)

func _ground(screen: Vector2) -> Vector2:
	var ray := camera.project_ray_normal(screen)
	var origin := camera.project_ray_origin(screen)
	var point := origin - ray * (origin.y / ray.y)
	return Vector2(point.x, point.z)

func _pawn(tint: Color, radius: float, height: float) -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.85
	var view := MeshInstance3D.new()
	view.mesh = capsule
	view.material_override = material

	add_child(view)
	return view

func _world(at: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(at.x, y, at.y)
