extends SceneTree

const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Layout = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Enclosure = preload("res://assets/terrain_m02/terrain_enclosure.gd")
const Geometry = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Mask = preload("res://assets/terrain_m02/terrain_feature_mask.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Garden = preload("res://assets/terrain_m02/garden_clearing.tres")
const Wilds = preload("res://assets/terrain_m02/wilds_riverwood.tres")
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")

var failed := false

func _initialize() -> void:
	call_deferred("run")

func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", description)

func run() -> void:
	for example in [[117, 14, true, 1.75], [118, 28, true, 2.0], [241, 14, false, 1.75],
			[517, 14, false, 1.50], [823, 14, false, 2.0], [241, 28, false, 1.75]]:
		_layout(example[0], example[1], example[2], example[3])
	await _scene()
	if not failed:
		print("PASS: five Heart silhouettes, connected trail/bridge footprints, signed masks, deterministic layouts and preserved comparisons")
	quit(1 if failed else 0)

func _layout(seed_value: int, radius: int, garden: bool, spacing: float) -> void:
	var cells := Generator.generate(seed_value, radius, Garden if garden else Wilds, Catalog)
	var layout := Layout.build(cells, spacing, radius, seed_value, garden, true)
	var fingerprint := Layout.digest(layout)
	var previous := Layout.build(cells, spacing, radius, seed_value, garden)
	_check(fingerprint == Layout.digest(Layout.build(cells, spacing, radius, seed_value, garden, true)),
		"identical seed, graph and feature layout")
	_check(layout.water == previous.water and layout.clearings == previous.clearings,
		"water shapes and placement reservations match the previous mode")
	if spacing == 1.75 and radius == 14:
		var expected := "0a9cfe11b0bf02384590ff33612f090091f7d2c7757ad0321112e12f5a41137f" if garden \
			else "c1e7eb3ad3909d646f8c895d0d2c6c6bd7c6c35a790faf8628f4438662c7f466"
		_check(Layout.digest(previous) == expected, "historical M04 feature hash")
	_graph(layout, garden)
	_mask(layout, radius, spacing)
	var enclosed := Enclosure.build(layout, cells, spacing, seed_value, garden)
	for plant in enclosed.plants:
		_check(not Geometry.in_trails(layout, plant.center, plant.clearance), "vegetation respects every trail footprint")
	for rock in enclosed.rocks:
		_check(not Geometry.in_trails(layout, rock.center, rock.radius), "rock footprints leave every trail clear")
	for trunk in enclosed.enclosure:
		_check(not Geometry.in_trails(layout, trunk.at, 0.58), "enclosure trunks clear the trail")
	print("M06B_LAYOUT ", seed_value, " ", radius, " ", spacing, " ", fingerprint)

func _graph(layout: Dictionary, garden: bool) -> void:
	var graph: Dictionary = layout.trail_network
	var required := ["arrival", "heart_threshold"] if garden \
		else ["west_glade", "west_bank", "east_bank", "east_glade", "fern_hollow"]
	_check(graph.nodes.size() == required.size() and layout.paths.size() == graph.edges.size(), "network has named destinations and one ribbon per edge")
	var pending: Array[String] = [required[0]]
	var reached := {required[0]: true}
	var water: Dictionary = layout.water[0]
	for edge_index in graph.edges.size():
		var edge: Dictionary = graph.edges[edge_index]
		var path: Dictionary = layout.paths[edge_index]
		var spine: PackedVector2Array = path.spine
		_check(path.id == edge.id and spine[0] == graph.nodes[edge.from] and spine[-1] == graph.nodes[edge.to],
			"render ribbon begins and ends at exact graph positions")
		_check(not Geometry2D.triangulate_polygon(path.outline).is_empty(), "ribbon triangulates")
		if not edge.get("bridge", false):
			_check(Geometry2D.intersect_polygons(path.outline, water.outline).is_empty(),
				"only the defined crossing overlaps water")
		for i in spine.size() - 1:
			var at := spine[i].lerp(spine[i + 1], 0.5)
			_check(Geometry.in_trails(layout, at), "ribbon covers the centerline between samples")
			if edge.get("bridge", false):
				_check(Geometry.in_any(layout.crossings, at), "bridge contains centerline of crossing edge")
			else:
				_check(not Geometry.in_any(layout.water, at, path.half_widths[i]), "unbridged trail footprint remains dry")
	while not pending.is_empty():
		var node: String = pending.pop_back()
		for edge in graph.edges:
			var next: String = edge.to if edge.from == node else edge.from if edge.to == node else ""
			if not next.is_empty() and not reached.has(next):
				reached[next] = true
				pending.append(next)
	for node in required:
		_check(reached.has(node) and Geometry.in_trails(layout, graph.nodes[node]),
			"destination is connected and visibly capped: " + node)
	if garden:
		_check(layout.crossings.is_empty() and Geometry.contains(layout.clearings[0], graph.nodes.heart_threshold),
			"dry approach reaches the protected Heart clearing")
	else:
		_check(layout.crossings.size() == 1, "one dedicated bridge")
		var deck: Dictionary = layout.crossings[0]
		var span: PackedVector2Array = deck.bridge
		_check(span[0] == graph.nodes.west_bank and span[1] == graph.nodes.east_bank
			and not Geometry.contains(water, span[0]) and not Geometry.contains(water, span[1])
			and Geometry.contains(water, span[0].lerp(span[1], 0.5)), "bridge spans wet center and meets both dry approaches")

func _mask(layout: Dictionary, radius: int, spacing: float) -> void:
	var atlas := Mask.bake(layout, spacing, radius)
	var texels: PackedByteArray = atlas.image.get_data()
	var step: Vector2 = atlas.frame.size / (Vector2(atlas.size) - Vector2.ONE)
	var groups := [layout.water, layout.paths + layout.path_joins, layout.ground_clearings]
	var max_error := 0.0
	for y in range(0, atlas.size.y, 4):
		for x in range(0, atlas.size.x, 4):
			var at: Vector2 = atlas.frame.position + Vector2(x, y) * step
			for channel in groups.size():
				var distance := Mask.MAX_DISTANCE
				for feature in groups[channel]:
					distance = minf(distance, Geometry.signed_distance(feature, at, Mask.MAX_DISTANCE))
				var value: int = texels[(y * atlas.size.x + x) * 3 + channel]
				var decoded := (float(value) / 127.5 - 1.0) * Mask.MAX_DISTANCE
				max_error = maxf(max_error, absf(distance - decoded))
	_check(max_error < 0.007, "rendered mask agrees with water, trail and clearing footprints at texel centers")

func _scene() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	var heart = scene.growing_heart
	var selector: OptionButton = scene.heart_stage
	var modes: OptionButton = scene.render_mode
	var terrain: Mesh = scene.ground.mesh
	# Switch into M06B for the first time with an edited seed that has not been generated.
	modes.select(0)
	modes.item_selected.emit(0)
	scene.show_example(0, 117, 1, false)
	terrain = scene.ground.mesh
	_check(scene.continuity_layout.is_empty(), "historical render leaves M06B layout deferred")
	scene.seed_field.set_value_no_signal(777)
	modes.select(5)
	modes.item_selected.emit(5)
	var placement := Layout.digest(scene.continuity_layout)
	var expected := Layout.build(scene.cells, 1.75, 14, 117, true, true)
	_check(scene.continuity_layout.paths == expected.paths and scene.continuity_layout.water == expected.water,
		"deferred M06B layout uses the generated seed until Generate is pressed")
	var model_sizes := {}
	var vertex_counts := {}
	var previous_height := 0.0
	_check(selector.item_count == 5 and selector.is_visible_in_tree() and modes.selected == 5,
		"the initial M06B Garden exposes five stage choices")
	for index in selector.item_count:
		selector.select(index)
		selector.item_selected.emit(index)
		var active := 0
		for model in heart.models:
			active += int(model.is_visible_in_tree())
		var mesh: ArrayMesh = heart.models[index].mesh
		_check(heart.stage == index and active == 1 and heart.models[index].is_visible_in_tree(), "selected stage is the only visible form")
		_check(mesh.get_surface_count() == 2 and not model_sizes.has(mesh.get_aabb().size)
			and not vertex_counts.has(mesh.surface_get_array_len(0)), "every stage has distinct geometry and an embedded emissive surface")
		var height := mesh.get_aabb().size.y
		_check(height > previous_height, "each restoration stage grows vertically")
		previous_height = height
		model_sizes[mesh.get_aabb().size] = true
		vertex_counts[mesh.surface_get_array_len(0)] = true
		_check(scene.ground.mesh == terrain and Layout.digest(scene.continuity_layout) == placement,
			"stage changes never regenerate the map")
	await create_timer(0.40).timeout
	_check(heart.models[4].scale.is_equal_approx(Vector3.ONE) and heart.models[4].position.is_zero_approx(),
		"growth presentation settles to authored proportions")
	_check(heart.models[4].mesh.get_aabb().size.y > 2.0 * heart.models[0].mesh.get_aabb().size.y,
		"restored Heart grows above the dormant silhouette")
	_check(scene.metrics.digest == "728d2f22b8a1b049de2ca68da9c6ffc5c48025155cda6a6f2e92d1acf3adb17e", "Garden cell identity preserved")
	for mode in [0, 5]:
		modes.select(mode)
		modes.item_selected.emit(mode)
		_check(selector.is_visible_in_tree() == (mode == 5) and heart.is_visible_in_tree() == (mode == 5)
			and scene.natural_material.get_shader_parameter("continuity_mode") == (mode == 5)
			and scene.ground.mesh == terrain, "historical comparison swaps rendering without modifying terrain")
	scene.show_example(1, 241, 1, false)
	_check(not selector.is_visible_in_tree() and not heart.is_visible_in_tree()
		and scene.feature_view.crossings.get_child_count() == 3, "Wilds hides the Heart and draws the connected bridge")
	_check(scene.metrics.digest == "97712e282096db9b6c8dab52972f57d648dc74ccd48a0b7a5905c9dbe131a1df", "Wilds cell identity preserved")
	scene.free()
