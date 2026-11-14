extends SceneTree

const Wilds = preload("res://assets/terrain_m02/wilds_preview_generation.gd")
const Biomes = preload("res://assets/terrain_m02/wilds_biome.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Sim = preload("res://assets/terrain_m02/wilds_play_simulation.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		printerr("FAIL: ", message)

func run() -> void:
	var count := 0
	for seed_value in [0, 117, 241, 517, 823, 9821]:
		for floor_number in [1, 6, 9, 13, 18]:
			for radius in [14, 28]:
				var map := Wilds.build(seed_value, floor_number, radius, 1.75, Catalog, Biomes.WINDOWS, true)
				check(not map.is_empty(), "terrain exists")
				if map.is_empty():
					continue
				var sim := Sim.new(Surface.new(map.cells, map.layout, 1.75))
				var label := "%d/%d/%d" % [seed_value, floor_number, radius]
				check(sim.ready and sim.remaining() == 3, "reachable combat positions " + label)
				if sim.ready:
					_play(sim, label)
					count += 1
	_surface()
	_preview()
	print("M08_CORPUS ", count, " admitted and cleared layouts")
	if not failed:
		print("PASS: movement, line queries, exploration, all-required-enemies Gate rule and preview isolation")
	quit(int(failed))

func _walk(sim: Sim, id: String, reverse: bool = false) -> void:
	for path in sim.surface.layout.paths:
		if path.id != id:
			continue
		var points: PackedVector2Array = path.spine.duplicate()
		if reverse:
			points.reverse()
		for point in points:
			sim.move(point - sim.position)
			check(sim.position.is_equal_approx(point), "real movement traverses " + id)
		return
	check(false, "route found " + id)

func _play(sim: Sim, label: String) -> void:
	check(not sim.gate_active() and not sim.gate_discovered and sim.strike().is_empty(), "starts unexplored and locked " + label)
	_walk(sim, "approach")
	_walk(sim, "bank_crossing")
	_walk(sim, "east_trail")
	check(sim.gate_discovered and not sim.gate_active() and not sim.use_gate(), "spatially discovered gate stays sealed " + label)
	check(not sim.strike().is_empty() and sim.remaining() == 2 and sim.strike().is_empty(), "a marker counts exactly once " + label)
	_walk(sim, "east_trail", true)
	_walk(sim, "bank_crossing", true)
	_walk(sim, "terrace_trail")
	check(not sim.strike().is_empty() and sim.remaining() == 1 and not sim.gate_active(), "one surviving marker holds gate closed")
	check(not sim.strike().is_empty() and sim.remaining() == 0 and sim.gate_active(), "last required enemy activates the gate")
	check(not sim.use_gate(), "gate interaction requires proximity")
	_walk(sim, "terrace_trail", true)
	_walk(sim, "bank_crossing")
	_walk(sim, "east_trail")
	check(sim.use_gate() and sim.finished and not sim.use_gate(), "can finish without visiting optional branch " + label)

func _surface() -> void:
	var map := Wilds.build(241, 18, 14, 1.75, Catalog, Biomes.WINDOWS, true)
	var surface := Surface.new(map.cells, map.layout, 1.75)
	var obstacle: Dictionary = map.layout.masses[0]
	var at: Vector2 = obstacle.spine[obstacle.spine.size() / 2]
	var from := at - Vector2(2.3, 0.0)
	var to := at + Vector2(2.3, 0.0)
	check(not surface.walkable(at) and not surface.clear_line(from, to), "mass blocks movement and sight")
	check(not surface.clear_line(from, to, 0.10), "swept projectile also meets geometry")
	check(not surface.travel(from, to).is_equal_approx(to), "dash displacement cannot tunnel through a barrier")
	var span: PackedVector2Array = map.layout.crossings[0].bridge
	check(surface.travel(span[0], span[-1]).is_equal_approx(span[-1]), "swept clearance traverses the deck")
	var wet := Vector2.INF
	for y in range(-15, 14):
		var point := Vector2(3.2, y)
		if Shape.in_any(map.layout.water, point) and not Shape.in_any(map.layout.crossings, point):
			wet = point
			break
	check(wet.is_finite() and not surface.walkable(wet), "water away from the bridge blocks feet")
	var gate: Vector2 = map.layout.trail_network.nodes.exit_gate
	surface.blockers.append(Shape.disk("blocked_gate", "test", gate, 2.7))
	var blocked := Sim.new(surface)
	check(not blocked.ready and not blocked.gate_active() and not blocked.use_gate(),
		"a broken route fails admission and cannot produce an active Gate")

func _preview() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	var button: CheckButton = scene.get_node("%PlayFloor")
	check(not button.visible, "Garden hides the play controls")
	scene.example.select(1)
	scene.example.item_selected.emit(1)
	check(button.visible and scene.walk_preview.run == null, "play mode is opt-in")
	button.button_pressed = true
	var view = scene.walk_preview
	check(view.run != null and view.fog.visible and not view.deck_gate.visible, "only arrival first is visible")
	var original: PackedByteArray = view.explored.get_data()
	var position: Vector2 = view.run.position
	var span: PackedVector2Array = scene.wilds.layout.paths[0].spine
	for point in span:
		view.step(point - view.run.position)
	check(view.run.position != position and view.explored.get_data() != original, "motion opens persistent exploration")
	var revealed: PackedByteArray = view.explored.get_data()
	for i in original.size():
		if revealed[i] < original[i]:
			check(false, "revealed pixels do not regress")
			break
	scene.get_node("%FogLayer").button_pressed = false
	check(not view.fog.visible and view.explored.get_data() == revealed, "visualization toggle preserves discovery")
	scene.get_node("%FogLayer").button_pressed = true
	scene.get_node("%RestartFloor").pressed.emit()
	check(not view.run.gate_discovered and view.run.remaining() == 3 and view.explored.get_data() == original, "restart resets run and reveals arrival only")
	var debug: CheckButton = scene.get_node("%Overlay")
	debug.button_pressed = true
	check(not scene.debug.visible and scene.detail.text.is_empty(), "debug inspection cannot reveal unexplored cells in play mode")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	view._unhandled_key_input(escape)
	check(not button.button_pressed and scene.debug.visible, "Escape restores the inspection view")
	check(view.run == null and view.deck_gate.visible and not view.fog.visible, "comparison view restored")
	scene.free()
