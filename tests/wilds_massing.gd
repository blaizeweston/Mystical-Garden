extends SceneTree
const W = preload("res://assets/terrain_m02/wilds_preview_generation.gd")
const G = preload("res://assets/terrain_m02/wilds_geography.gd")
const B = preload("res://assets/terrain_m02/wilds_biome.gd")
const S = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const L = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const M = preload("res://assets/terrain_m02/wilds_massing_mesh.gd")
const C = preload("res://assets/terrain_m02/terrain_catalog.tres")
const P = preload("res://assets/terrain_m02/terrain_preview.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		if failures <= 24:
			printerr("FAIL: ", detail)

func run() -> void:
	var loops := 0
	var island_routes := {}
	for seed_value in [0, 117, 241, 517, 823, 9821]:
		for floor_number in [1, 6, 9, 13, 18]:
			for radius in [14, 28]:
				var map := W.build(seed_value, floor_number, radius, 1.75, C, B.WINDOWS, true)
				check(not map.is_empty(), "map generated")
				if map.is_empty():
					continue
				var repeat := W.build(seed_value, floor_number, radius, 1.75, C, B.WINDOWS, true)
				check(map == repeat, "complete maps are deterministic")
				var label := "%d/%d/%d" % [seed_value, floor_number, radius]
				_geometry(map.layout, radius, label)
				loops += int(map.layout.trail_network.nodes.has("side_chamber"))
				if floor_number == 9:
					island_routes[map.layout.crossings.size()] = true
				if seed_value == 241 and radius == 14 and floor_number in [1,9,18]:
					_meshes(map.layout, seed_value)
					check(map.layout.plants.any(func(item: Dictionary): return item.has("community")), "biotic community follows massif")
				print("M07B_MAP ", label, " ", map.layout.masses.size(), " masses ", map.layout.plants.size(),
					" plants ", map.layout.crossings.size(), " bridges ", L.digest(map.layout))
	check(loops == 60, "all sampled maps retain a dry bypass")
	check(island_routes.has(2) and island_routes.has(3), "Mire supports both a spur and a through-island alternative")
	_scene()
	print("M07B_CORPUS 60 maps, ", loops, " bypass loops, Mire bridge totals ", island_routes.keys())
	if failures == 0:
		print("PASS: environmental masses, protected routes, coherent meshes and preview comparison")
	quit(int(failures > 0))

func _geometry(layout: Dictionary, radius: int, label: String) -> void:
	var graph: Dictionary = layout.trail_network
	check(graph.nodes.has("arrival") and graph.nodes.has("exit_gate"), "required endpoints " + label)
	var reached := {"arrival": true}
	var pending := ["arrival"]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		for edge in graph.edges:
			var next: String = edge.to if edge.from == current else edge.from if edge.to == current else ""
			if not next.is_empty() and not reached.has(next):
				reached[next] = true
				pending.append(next)
	check(reached.size() == graph.nodes.size(), "all reserved destinations are connected " + label)
	if graph.nodes.has("side_chamber"):
		check(graph.edges.size() >= graph.nodes.size(), "side chamber supplies a genuine cycle " + label)
	var water: Dictionary = layout.water[0]
	for crossing in layout.crossings:
		var span: PackedVector2Array = crossing.bridge
		check(not S.in_any(layout.water, span[0], 0.75) and not S.in_any(layout.water, span[-1], 0.75)
			and crossing.spine.size() > 1, "crossings land dry " + label)
		var over_water := false
		for point in crossing.spine:
			over_water = over_water or S.contains(water, point)
		check(over_water, "a bridge spans the wet channel")
		for mass in layout.masses:
			check(not S.in_any([mass], span[0], 0.75) and not S.in_any([mass], span[-1], 0.75), "landings keep clearance")
	for i in layout.paths.size():
		var path: Dictionary = layout.paths[i]
		var edge: Dictionary = graph.edges[i]
		check(path.spine[0].is_equal_approx(graph.nodes[edge.from])
			and path.spine[-1].is_equal_approx(graph.nodes[edge.to]), "path connects its intended nodes")
	var previous: Array[Dictionary] = []
	for mass in layout.masses:
		check(mass.spine.size() > 4 and mass.spine[0].distance_to(mass.spine[-1]) > 3.3
			and not Geometry2D.triangulate_polygon(mass.outline).is_empty(), "connected valid formation " + label)
		for point in mass.outline:
			check(G._inside_disk(point, radius, 1.75) and not S.contains(water, point), "formation fits the dry terrain")
		for shape in layout.paths + layout.path_joins + layout.clearings + previous:
			if mass.bounds.intersects(shape.bounds):
				check(Geometry2D.intersect_polygons(mass.outline, S.boundary(shape)).is_empty(), "formation protects all route and chamber footprints")
		previous.append(mass)
	check(layout.masses.size() >= 7, "substantial formations form the map " + label)
	for plant in layout.plants:
		check(not S.in_any(layout.water + layout.clearings, plant.center, plant.clearance)
			and not S.in_trails(layout, plant.center, plant.clearance), "plants protect navigation geometry")

func _meshes(layout: Dictionary, seed_value: int) -> void:
	for mass in layout.masses:
		var geometry := M.mesh(mass, seed_value)
		var vertices: PackedVector3Array = geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(vertices.size() >= 90 and vertices.size() % 3 == 0, "connected mesh surface created")
		for vertex in vertices:
			check(vertex.is_finite() and S.signed_distance(mass, Vector2(vertex.x, vertex.z), 0.005) <= 0.001,
				"visible mesh projects into the logical footprint")

func _scene() -> void:
	var scene := P.instantiate()
	root.add_child(scene)
	var garden: String = scene.metrics.digest
	scene.example.select(3)
	scene.example.item_selected.emit(3)
	check(scene.render_mode.selected == 8 and scene.floor_choice.visible, "M07B is the default Wilds mode")
	check(scene.feature_view.massing.has_node("ExitGate"), "the new Gate is rendered")
	scene.render_mode.select(7)
	scene.render_mode.item_selected.emit(7)
	check(not scene.wilds.layout.has("masses") and scene.feature_view.massing.get_child_count() == 0, "historical M07 remains selectable")
	scene.example.select(0)
	scene.example.item_selected.emit(0)
	check(scene.metrics.digest == garden and scene.growing_heart.sculpt_models[0].is_visible_in_tree(), "Garden and Heart are preserved")
	scene.free()
