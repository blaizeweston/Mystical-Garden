extends Node3D
## Preview presentation and input only. The simulation determines all clear and Gate outcomes.

signal exit_requested

const Boundary = preload("res://assets/terrain_m02/wilds_boundary.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Simulation = preload("res://assets/terrain_m02/wilds_play_simulation.gd")
const Combat = preload("res://assets/terrain_m02/wilds_combat_simulation.gd")
const Fog = preload("res://assets/terrain_m02/wilds_play_fog.gdshader")
const MELEE_MODEL = preload("res://assets/enemies/rootbound.glb")
const RANGED_MODEL = preload("res://assets/enemies/orchid.glb")
const CAMERA_OFFSET := Vector3(3.3, 14.0, 14.0)
const PIXEL := 0.28
const MOVE_SPEED := 4.6

const Atmosphere = preload("res://assets/terrain_m02/wilds_atmosphere.gd")
var atmosphere: Atmosphere
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
var windups: Dictionary = {}
var bolts: Array[MeshInstance3D] = []
var last_direction := Vector2.DOWN
var explored: Image
var texture: ImageTexture
var map_margin: float
var last_reveal := Vector2.INF
var fog_enabled := true

func _ready() -> void:
	set_physics_process(false)

func start(cells: Dictionary, layout: Dictionary, spacing: float, combat: bool = false) -> bool:
	stop()
	var surface := Surface.new(cells, layout, spacing)
	run = Combat.new(surface) if combat else Simulation.new(surface)
	if not run.ready:
		run = null
		readout.text = "Required encounter route failed its clearance check. Try another seed."
		return false
	last_direction = Vector2.DOWN
	marker = _pawn(Color("#e4d4a0"), 0.27, 1.72)
	for enemy in run.encounters:
		var ranged: bool = enemy.get("role") == "ranged"
		var target := _enemy_figure(ranged) if combat else _pawn(Color("#ad5846"), 0.33, 1.30)
		figures[enemy.id] = target
		if combat:
			windups[enemy.id] = _ring(Color("#f7a958"), 0.64)
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
	if is_instance_valid(atmosphere): atmosphere.observe(Vector2.ZERO, -1.0)
	run = null
	pan = Vector2.ZERO
	set_physics_process(false)
	explored = null
	texture = null
	for node in get_children():
		node.free()
	figures.clear()
	windups.clear()
	bolts.clear()
	if is_instance_valid(deck_gate):
		deck_gate.show()
	if fog != null:
		fog.hide()
		fog.material = null
	last_reveal = Vector2.INF

func _physics_process(delta: float) -> void:
	var input := _movement()
	if get_viewport().gui_get_focus_owner() is LineEdit:
		input = Vector2.ZERO
	if not input.is_zero_approx():
		last_direction = input.normalized()
		run.move(last_direction * MOVE_SPEED * delta)
	if run is Combat:
		run.tick(delta)
	if run is Combat or not input.is_zero_approx():
		_update_view()

func _movement() -> Vector2:
	var input := Vector2(
		int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	return input

func step(delta: Vector2) -> void:
	run.move(delta)
	_update_view()

func _unhandled_key_input(event: InputEvent) -> void:
	if run == null or not event.is_pressed() or event.is_echo():
		return
	match event.physical_keycode:
		KEY_SPACE:
			perform_strike()
		KEY_SHIFT:
			if not run is Combat or get_viewport().gui_get_focus_owner() is LineEdit:
				return
			var direction := _movement()
			run.dodge(last_direction if direction.is_zero_approx() else direction)
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
	if defeated.is_empty() and not run.finished and not run is Combat:
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
	if is_instance_valid(atmosphere): atmosphere.observe(run.position, Simulation.SIGHT if fog_enabled else -1.0)
	var target := _world(run.position)
	marker.position = target + Vector3.UP * 0.86
	_follow_camera()
	_reveal()
	_align_fog()
	fog.visible = fog_enabled
	for enemy in run.encounters:
		var figure: Node3D = figures[enemy.id]
		var at := _world(enemy.position, 0.0 if run is Combat else 0.65)
		if run is Combat:
			var facing := at - figure.position
			if enemy.state == "windup":
				facing = _world(enemy.aim) - at
			if facing.length_squared() > 0.0001:
				figure.rotation.y = atan2(facing.x, facing.z)
		figure.position = at
		figure.visible = not enemy.cleared and (not fog_enabled
			or (run.position.distance_to(enemy.position) <= Simulation.SIGHT
				and run.surface.clear_line(run.position, enemy.position)))
		if windups.has(enemy.id):
			var ring: MeshInstance3D = windups[enemy.id]
			ring.position = _world(enemy.position, 0.20)
			ring.visible = figure.visible and enemy.state == "windup"
	var show_gate := run.gate_discovered or not fog_enabled
	if is_instance_valid(deck_gate):
		deck_gate.visible = show_gate
	indicator.visible = show_gate
	gate_tint.albedo_color = Color("#78d6a7") if run.gate_active() else Color("#d68b53")
	var gate_status := "Gate undiscovered"
	if run.gate_discovered:
		gate_status = "Gate active" if run.gate_active() else "Gate sealed"
	readout.text = "%d required enemies left  |  %s" % [run.remaining(), gate_status]
	if run is Combat:
		_update_projectiles(run)
		readout.text = "%d HP  |  %s" % [run.health, readout.text]
		if not run.event.is_empty():
			readout.text += "  |  " + run.event
		if run.health <= 0:
			readout.text = "Defeated. Restart to try this floor again."
	if run.finished:
		readout.text = "Floor cleared. Gate entered. Restart to explore again."

func _update_projectiles(combat: Combat) -> void:
	while bolts.size() < combat.projectiles.size():
		bolts.append(_pawn(Color("#f0ac60"), 0.09, 0.42))
	for i in bolts.size():
		var view := bolts[i]
		view.visible = i < combat.projectiles.size()
		if view.visible:
			var bolt := combat.projectiles[i]
			view.visible = not fog_enabled or (run.position.distance_to(bolt.position) <= Simulation.SIGHT
				and run.surface.clear_line(run.position, bolt.position))
			view.position = _world(bolt.position, 0.64)
			view.rotation = Vector3.ZERO
			view.rotate_y(atan2(bolt.direction.x, bolt.direction.y))
			view.rotate_x(PI / 2.0)

func _ring(color: Color, radius: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.045
	mesh.outer_radius = radius
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	ring.material_override = material
	add_child(ring)
	return ring

func _enemy_figure(ranged: bool) -> Node3D:
	var figure := Node3D.new()
	var visual := (RANGED_MODEL if ranged else MELEE_MODEL).instantiate() as Node3D
	figure.add_child(visual)
	for group in ["Growth1", "Growth2", "AdaptReach", "AdaptBark", "AdaptSpore", "AdaptMobility"]:
		var part := visual.find_child(group, true, false) as Node3D
		if part != null:
			part.hide()
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var transform := mesh.transform
		var parent := mesh.get_parent() as Node3D
		var shown := mesh.visible
		while parent != figure:
			shown = shown and parent.visible
			transform = parent.transform * transform
			parent = parent.get_parent() as Node3D
		if shown:
			var box := transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
	var foot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var width := maxf(bounds.size.x, bounds.size.z)
	var factor := minf(1.6 / maxf(bounds.size.y, 0.1), 1.20 / maxf(width, 0.1))
	visual.scale = Vector3.ONE * factor
	visual.position = -foot * factor
	add_child(figure)
	return figure

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
