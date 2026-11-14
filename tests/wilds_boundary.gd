extends SceneTree
const Biome = preload("res://assets/terrain_m02/wilds_biome.gd")
const Boundary = preload("res://assets/terrain_m02/wilds_boundary.gd")
const Rim = preload("res://assets/terrain_m02/wilds_boundary_mesh.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Geometry = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Sim = preload("res://assets/terrain_m02/wilds_play_simulation.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Wilds = preload("res://assets/terrain_m02/wilds_preview_generation.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures <= 30:
			printerr("FAIL: ", message)

func run() -> void:
	var total := 0
	for seed_value in [0, 117, 241, 517, 823, 9821]:
		for floor_number in [1, 6, 9, 13, 18]:
			for size in [Vector2(14, 1.50), Vector2(14, 2.0), Vector2(28, 1.75)]:
				var map := Wilds.build(seed_value, floor_number, int(size.x), size.y, Catalog, Biome.WINDOWS, true, true)
				var label := "%d/%d/%s" % [seed_value, floor_number, size]
				check(not map.is_empty(), "generated " + label)
				if map.is_empty():
					continue
				var replay := Boundary.build(map.layout, seed_value, int(size.x), size.y, map.climate)
				check(replay == map.layout.boundary, "deterministic boundary " + label)
				_check_floor(map, size.y, label)
				total += 1
	_scene()
	print("M09_CORPUS ", total, " layouts checked")
	if failures == 0:
		print("PASS: closed and visible Wilds boundaries, preserved floor routes, and projected scenic coverage")
	quit(int(failures > 0))

func _check_floor(map: Dictionary, spacing: float, label: String) -> void:
	var border: Dictionary = map.layout.boundary
	var surface := Surface.new(map.cells, map.layout, spacing)
	var sim := Sim.new(surface)
	check(sim.ready, "enemy rooms and Gate are reachable " + label)
	if not sim.ready:
		return
	var reachable := surface.reachable_nodes()
	check(reachable.size() == map.layout.trail_network.nodes.size(), "optional routes stay reachable " + label)
	for target in sim.encounters:
		check(surface.walkable(target.position) and Geometry.contains(border.playable, target.position), "enemy lies inside playable terrain")
	for strip in border.rim:
		var next: Dictionary = border.rim[(strip.start / 8 + 1) % border.rim.size()]
		check(strip.inner[-1] == next.inner[0] and strip.outer[-1] == next.outer[0], "neighboring barrier sections share exact vertices")
		for i in range(strip.inner.size() - 1):
			var edge: Vector2 = strip.inner[i].lerp(strip.inner[i + 1], 0.5)
			var normal := edge.normalized()
			var inside := edge - normal * 0.62
			var outside := edge + normal * 0.62
			var visible: Array = border.water if strip.wet else [strip]
			check(Geometry.in_any(visible, outside), "perimeter sample meets its visible barrier")
			check(not surface.walkable(outside), "unwalkable on far side of visible barrier")
			if surface.walkable(inside):
				check(not surface.travel(inside, outside, 0.1).is_equal_approx(outside),
					"a swept move cannot tunnel through the boundary")

func _scene() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	var garden: String = scene.metrics.digest
	for preset in [1, 2, 3]:
		scene.example.select(preset)
		scene.example.item_selected.emit(preset)
		check(scene.render_mode.selected == 9 and scene.scenic_ground != null and scene.metrics.triangles == 2,
			"M09 uses a continuous scenic plane")
		scene.get_node("%PlayFloor").button_pressed = true
		scene.get_node("%FogLayer").button_pressed = true
		var view = scene.walk_preview
		check(view.run != null and view.fog.visible and view.allow_camera_control, "playable boundary with fog")
		var surface: Surface = view.run.surface
		var points: PackedVector2Array = surface.arena.outline
		var plane: Vector2 = scene.scenic_ground.size * 0.5
		scene.camera.size = Boundary.MAX_ZOOM
		for i in range(0, points.size(), 2):
			# Overbound reachable player positions by every other vertex on the continuous arena.
			view.run.position = points[i]
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				view.set_pan(direction * 100.0)
				check(is_equal_approx(view.pan.length(), Boundary.MAX_PAN), "pan is bounded")
				var size := root.get_visible_rect().size
				for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
					var ray: Vector3 = scene._ground_point(corner)
					check(absf(ray.x) < plane.x and absf(ray.z) < plane.y, "camera corner hits exterior ground")
		scene.get_node("%FogLayer").button_pressed = false
		check(not view.fog.visible and scene.ground.mesh == scene.scenic_ground, "fog-off retains full exterior")
		var rim := Rim.build(scene.wilds.layout.boundary, scene.terrain_seed)
		check(rim.get_surface_count() == 1, "one mesh batches the dry barriers")
		scene.get_node("%PlayFloor").button_pressed = false
	scene.example.select(0)
	scene.example.item_selected.emit(0)
	check(scene.scenic_ground == null and scene.metrics.digest == garden, "Garden stays on its original path")
	scene.free()
