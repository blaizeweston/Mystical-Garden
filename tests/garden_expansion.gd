extends SceneTree

const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Digest = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const RootArt = preload("res://assets/terrain_m02/garden_heart_roots.gd")

var errors := 0
var samples := []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		if errors < 35:
			printerr("FAIL: ", message)

func run() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	var view = scene.expansion
	view.knowledge.set_sandbox(true)
	check(view.visible and view.enter.visible, "the Garden preview exposes the expansion controls")
	var original := _snapshot(scene)
	_ground_boundary(view)
	var first_outline: PackedVector2Array = view.barrier.visible_outline
	_boundary(view)
	_art(view)
	var directions: Array = view.state.frontier_options()
	check(directions.size() >= 4, "reference Garden has multiple eligible sectors")
	var outlines := {}
	var total_gained := 0
	for offer in directions:
		view.reset_garden()
		var footprint: PackedVector2Array = view.state.outline
		view.enter.button_pressed = true
		# Use the actual preview's world click. The same selector is available by keyboard.
		view.click_frontier(offer.frontier)
		check(view.preview == offer and view.footprint.mesh != null, "same frontier previews deterministic geometry")
		check(view.state.revision == 0 and view.state.outline == footprint, "preview is read-only")
		view.cancel.pressed.emit()
		check(view.state.revision == 0 and not view.active and view.footprint.mesh == null, "cancel discards the preview")
		var deterministic := _fresh(view.state)
		check(deterministic.apply(offer) and not deterministic.apply(offer), "exact proposal applies once")
		var forged: Dictionary = offer.duplicate(true)
		forged.cells[Vector2i.ZERO] = &"soil"
		check(not _fresh(view.state).apply(forged), "a modified plan cannot consume occupied land")
		_grow(scene, offer)
		check(view.state.outline == deterministic.outline and view.state.roots == deterministic.roots,
			"model and interactive path agree")
		total_gained += offer.cells.size()
		outlines[JSON.stringify(view.state.outline, "", true, true).sha256_text()] = true
		_preserved(scene, original)
		_boundary(view)
	check(outlines.size() == directions.size(), "different directions give distinct outlines")
	view.reset_garden()
	check(view.state.owned == original.owned and view.roots.get_child_count() == 0, "reset restores exact initial ownership")
	check(view.state.proposal(-1).is_empty() and view.state.proposal(8).is_empty(), "out-of-range frontiers are rejected")
	check(view.state.proposal(7).is_empty(), "pond-side frontier that cannot fit is refused")
	var grown := 0
	for i in 5:
		var options: Array = view.state.frontier_options()
		if options.is_empty():
			break
		var old: Dictionary = view.state.owned.duplicate()
		_grow(scene, options[0])
		for cell in old:
			check(view.state.owned[cell] == old[cell], "existing growth generations remain stable")
		_preserved(scene, original)
		grown += options[0].cells.size()
	check(view.state.revision == 5, "five consecutive expansions stay connected")
	var heart = scene.growing_heart
	var grown_outline: PackedVector2Array = view.barrier.visible_outline
	_network(view)
	for stage in 5:
		scene.heart_stage.select(stage)
		scene.heart_stage.item_selected.emit(stage)
		check(view.barrier.visible_outline == grown_outline
			and view.material.get_shader_parameter("garden_frontier"), "all Heart stages retain concealment")
		_network(view)
	check(heart.stage == 4 and view.state.revision == 5, "Heart stage selector works after expansion")
	_roots(view)
	scene.render_mode.select(4)
	scene.render_mode.item_selected.emit(4)
	check(not view.visible and not scene.get_node("GardenExterior").visible, "historical render disables expansion presentation")
	scene.render_mode.select(6)
	scene.render_mode.item_selected.emit(6)
	check(view.visible and view.roots.get_child_count() == 5 and view.state.revision == 5,
		"returning to M06C keeps reclaimed ownership and roots")
	check(view.barrier.visible_outline == grown_outline, "comparison mode restores exactly the same concealment")
	_covered(scene)
	view.reset_garden()
	check(view.barrier.visible_outline == first_outline and view.network.is_empty(),
		"reset restores the exterior and removes every reclaimed root")
	scene.map_size.select(1)
	scene.map_size.item_selected.emit(1)
	check(scene.cells.size() == 2437 and view.state.revision == 0, "large comparison initializes a separate Garden")
	var large: Array = view.state.frontier_options()
	check(not large.is_empty(), "large map has eligible frontiers")
	if not large.is_empty():
		_grow(scene, large[0])
		_covered(scene)
	var terrain_test: Dictionary = scene.cells
	for spec in [[109, 0], [642, 2]]:
		scene.show_example(0, spec[0], spec[1], false)
		var options: Array = view.state.frontier_options()
		check(options.size() >= 2, "alternate seed and spacing preserve real choices")
		if not options.is_empty():
			_grow(scene, options[0])
	check(scene.cells != terrain_test, "changing seed regenerates only on request")
	scene.example.select(1)
	scene.example.item_selected.emit(1)
	check(not view.visible and not scene.get_node("GardenExterior").visible and scene.render_mode.selected == 11,
		"switching to Wilds preserves historical M10 startup")
	print("M11_METRICS ", JSON.stringify({"initial_owned": original.owned.size(),
		"initial_usable": original.available, "initial_choices": directions.size(), "first_choice_cells_combined": total_gained,
		"sequential_cells": grown, "sequential_area": grown * 1.75 * 1.75 * sqrt(3.0) / 2.0, "samples": samples}))
	scene.free()
	if errors == 0:
		print("PASS: connected deterministic Garden expansion, protected landmarks, incremental reveal and scenic enclosure")
	quit(int(errors > 0))

func _fresh(from: Garden) -> Garden:
	return Garden.new(from.terrain, from.layout, from.spacing, from.seed_value, roundi(from.extent / from.spacing))

func _snapshot(scene) -> Dictionary:
	var view = scene.expansion
	var locations := {}
	for landmark in view.landmark_view.get_children():
		locations[landmark.name] = landmark.transform
	return {"cells": scene.cells.duplicate(), "layout": Digest.digest(scene.continuity_layout),
		"landmarks": view.state.landmarks.duplicate(true), "positions": locations,
		"terrain_mesh": scene.ground.mesh, "scenic_mesh": scene.get_node("GardenExterior").mesh,
		"heart_id": scene.growing_heart.get_instance_id(), "heart_transform": scene.tree.transform,
		"owned": view.state.owned.duplicate(), "available": view.state.available.size()}

func _preserved(scene, original: Dictionary) -> void:
	var current := _snapshot(scene)
	for key in ["cells", "layout", "landmarks", "positions", "terrain_mesh", "scenic_mesh", "heart_id", "heart_transform"]:
		check(current[key] == original[key], "growth preserved " + key)

func _grow(scene, offer: Dictionary) -> void:
	var view = scene.expansion
	var state: Garden = view.state
	var prop_count: int = scene.feature_view.vegetation.get_child_count()
	var visible_batch: Node = scene.enclosure_view.get_child(0)
	var prior := state.owned.duplicate()
	var root_count := state.roots.size()
	var original_support := state.enclosure_support()
	view.enter.button_pressed = true
	check(view.select_frontier(offer.sector), "frontier can be selected")
	view.confirm.pressed.emit()
	_ground_boundary(view)
	check(view.growing and state.roots.size() == root_count + 1
		and view.material.get_shader_parameter("garden_reveal") == 0.0, "growth starts at the Heart before the ground reveal")
	var before: PackedVector2Array = view.barrier.visible_outline
	var transforms := []
	for section: Dictionary in view.barrier.sections:
		transforms.append(section.clumps[0].transform)
	view._animate(0.25)
	check(view.barrier.visible_outline == before and view.heart.pulse.light_energy > 0.36,
		"Heart brightens before the forest moves")
	view._animate(minf(0.95, view.breach + 0.11))
	var partial: float = view.material.get_shader_parameter("garden_reveal")
	check(partial > 0.0 and partial < 1.0, "shore and perimeter reveal progressively")
	_ground_boundary(view)
	var fixed_sections := 0
	for i in before.size():
		var next := (i + 1) % before.size()
		if before[i] == view.barrier.visible_outline[i] and before[next] == view.barrier.visible_outline[next]:
			fixed_sections += 1
			check(transforms[i] == view.barrier.sections[i].clumps[0].transform,
				"growth leaves unaffected forest placements alone")
	check(fixed_sections > before.size() / 2, "the forest update is local to the expanding sector")
	_boundary(view)
	view.finish_animation()
	_ground_boundary(view)
	check(not view.growing and view.root_mesh.material_override.get_shader_parameter("root_progress") == 1.0
		and view.material.get_shader_parameter("garden_reveal") == 1.0, "root reveal ends at the chosen frontier")
	check(state.owned.size() - prior.size() == offer.cells.size(), "only declared cells were added")
	var destination: Vector2 = state.roots[-1][-1]
	check(offer.cells.has(Grid.world_to_cell(destination, state.spacing))
		and state.roots[-1][0].length() < 1.0, "root begins at the Heart and lands inside new terrain")
	check(state.entrance_clear(), "existing Wilds approach remains continuous and clear")
	for point in state.roots[-1]:
		check(not Shape.in_any(state.root_exclusions, point, 0.36)
			and not Shape.in_any(state.layout.water, point, 0.36)
			and not Shape.in_any(state.occupied, point, 0.36), "root avoids protected features")
	for cell in offer.cells:
		var at := Grid.cell_to_world(cell, state.spacing)
		var suitability := state.suitability(at, state.spacing * 0.48)
		check(not prior.has(cell) and suitability.usable and suitability.terrain == offer.cells[cell],
			"new cell had no prior ownership or protected footprint")
	for item in state.landmarks.values():
		check(not state.suitability(item.center, 0.25).usable, "landmark cannot be built over")
	var next_support := state.enclosure_support()
	for i in next_support.size():
		check(next_support[i] >= original_support[i] - 0.002, "enclosure never encroaches on previously owned land")
		check(absf(next_support[i] - next_support[(i + 1) % next_support.size()]) < state.spacing * 2.35 + 0.001,
			"adjacent forest sections stay continuous")
	check(scene.feature_view.vegetation.get_child_count() == prop_count
		and scene.enclosure_view.get_child(0) == visible_batch, "the forest and vegetation batches were reused")
	_linked(offer.cells, prior, state)
	var result: Dictionary = view.last_metrics.duplicate()
	result["map_cells"] = scene.cells.size()
	result["sector"] = Garden.DIRECTIONS[offer.sector]
	samples.append(result)

func _ground_boundary(view) -> void:
	var image: Image = view.material.get_shader_parameter("garden_perimeter").get_image()
	var polygon: PackedVector2Array = view.barrier.visible_outline
	var reveal: float = view.material.get_shader_parameter("garden_reveal")
	check(image.get_width() == polygon.size(), "terrain and collision use the same radial outline")
	for i in polygon.size():
		var edge := image.get_pixel(i, 0)
		check(is_equal_approx(lerpf(edge.r, edge.g, reveal), polygon[i].length()),
			"concealment follows the current forest outline")
	if reveal >= 1.0:
		for cell in view.state.available:
			var at := Grid.cell_to_world(cell, view.state.spacing)
			check(Shape.polygon_distance(polygon, at, 0.52) < 0.0,
				"usable cell centers stay inside the visible Garden")

func _network(view) -> void:
	var rebuilt: Array[Dictionary] = []
	var sockets := {}
	var branch_count := 0
	for path: PackedVector2Array in view.state.roots:
		var plan := RootArt.plan(path, view.heart.stage, view.state, rebuilt)
		check(plan == view.network[rebuilt.size()], "rebuilding a stage produces the same root network")
		var at: Vector3 = plan.main[-1]
		check(Vector2(at.x, at.z) == path[-1], "network preserves each expansion destination")
		if plan.connection.is_empty():
			check(not sockets.has(plan.socket), "each buttress has only one primary root")
			sockets[plan.socket] = true
		else:
			branch_count += 1
			var parent: Dictionary = rebuilt[plan.connection.parent]
			check(plan.main[0] == parent.main[plan.connection.index] and plan.radius < parent.radius,
				"new limb starts inside an older tapered root")
			check(plan.main[0].length() > 1.8, "reused roots do not coat the Heart with another primary mesh")
		rebuilt.append(plan)
	check(branch_count >= 1, "successive expansions reuse an existing root where their routes converge")

func _linked(added: Dictionary, old: Dictionary, state: Garden) -> void:
	var first: Vector2i = added.keys()[0]
	var pending: Array[Vector2i] = [first]
	var seen := {first: true}
	var joined := false
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for direction in Grid.NEIGHBORS:
			var next := cell + direction
			joined = joined or (old.has(next) and state.available.has(next))
			if added.has(next) and not seen.has(next):
				seen[next] = true
				pending.append(next)
	check(seen.size() == added.size() and joined, "added ownership is single-component and joined")

func _covered(scene) -> void:
	var exterior: MeshInstance3D = scene.get_node("GardenExterior")
	var plane: PlaneMesh = exterior.mesh
	var viewport: Vector2 = root.get_visible_rect().size
	var view = scene.expansion
	for heading in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		view.set_camera(heading * 1000, 1000.0)
		for corner in [Vector2.ZERO, viewport, Vector2(viewport.x, 0), Vector2(0, viewport.y)]:
			var point: Vector3 = scene._ground_point(corner)
			check(absf(point.x) < plane.size.x / 2.0 and absf(point.z) < plane.size.y / 2.0,
				"scenic ground covers maximal pan and zoom")

func _boundary(view) -> void:
	var barrier = view.barrier
	var polygon: PackedVector2Array = barrier.visible_outline
	check(polygon.size() == Garden.FOREST_SECTORS and barrier.sections.size() == polygon.size(),
		"one closed forest band wraps the entire collision outline")
	for i in polygon.size():
		var section: Dictionary = barrier.sections[i]
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var edge := a.lerp(b, 0.5)
		var away := Vector2(b.y - a.y, a.x - b.x).normalized()
		check(section.a.is_equal_approx(a) and section.b.is_equal_approx(b)
			and section.count * barrier.CLUMP_SPACING >= a.distance_to(b), "fixed-size thickets cover each section")
		for j in section.count:
			var mesh: MeshInstance3D = section.clumps[j]
			check(mesh.visible and mesh.transform.basis.get_scale().is_equal_approx(Vector3.ONE),
				"forest pieces move without geometry stretch")
		check(not barrier.walkable(edge + away * 0.52), "no walkable opening through the thicket")
		var start := edge - away * 0.62
		if barrier.walkable(start):
			var stop: Vector2 = barrier.move(start, away * 5.0)
			check(barrier.walkable(stop) and not stop.is_equal_approx(start + away * 5.0), "swept motion cannot leave the forest")
	var route: PackedVector2Array = view.state.layout.paths[0].spine.duplicate()
	route.reverse()
	var player := route[0]
	for target in route:
		player = barrier.move(player, target - player)
		check(player.is_equal_approx(target), "walking controller reaches every permanent entrance approach sample")
	check(player.is_equal_approx(view.state.landmarks.wilds_entrance.center), "can stand under the permanent Gate")

func _art(view) -> void:
	var state: Garden = view.state
	check(state.landmarks.altar.center == Vector2(4.20, 1.5) and is_equal_approx(state.landmarks.altar.radius, 1.06)
		and state.landmarks.starter_bed.center == Vector2(-4.30, -1.8)
		and is_equal_approx(state.landmarks.starter_bed.radius, 1.15), "M11 altar and bed footprints retained")
	var snapshot := state.landmarks.duplicate(true)
	var render_count: int = view.landmark_view.get_child_count()
	check(render_count == state.landmarks.size()-1 and not state.landmarks.has("spring"), "all current landmarks are represented without the retired spring")
	for child in view.landmark_view.get_children():
		if child.name == "wilds_entrance":
			continue
		var radius: float = state.landmarks[str(child.name)].radius
		for vertex: Vector3 in child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			check(Vector2(vertex.x, vertex.z).length() * child.scale.x <= radius + 0.005,
				"decorative station geometry fits the reserved footprint")
	view.comparison.button_pressed = true
	check(view.landmark_view.get_child_count() == 3 and snapshot == state.landmarks, "prop comparison preserves reservations")
	view.comparison.button_pressed = false

func _roots(view) -> void:
	var state: Garden = view.state
	var root: PackedVector2Array = state.roots[0]
	var sizes := {}
	for stage in 5:
		var plan := RootArt.plan(root, stage, state)
		var target: Vector3 = plan.main[-1]
		var point: Vector3 = plan.main[0]
		var authored: Array = RootArt.SOCKETS[plan.socket]
		var socket := (authored[0] as Vector3).lerp(authored[1], 0.30)
		check(point.is_equal_approx(socket * Vector3(0.77 + stage * 0.112, 1.0, 0.77 + stage * 0.112)),
			"root starts in a known sculpted buttress at each stage")
		check(Vector2(target.x, target.z) == root[-1] and plan == RootArt.plan(root, stage, state),
			"root reaches its committed destination deterministically")
		check(plan.branches.size() >= 2, "main root divides into secondary and tertiary geometry")
		sizes[plan.radius] = true
		for limb in [{"points": plan.main, "radius": plan.radius}] + plan.branches:
			var points: Array = limb.points
			for i in range(1, points.size()):
				var a: Vector3 = points[i - 1]
				var b: Vector3 = points[i]
				check(a.distance_to(b) < 0.85, "no disconnected root segment")
				for fraction in [0.0, 0.5, 1.0]:
					var at := a.lerp(b, fraction)
					var ground := Vector2(at.x, at.z)
					if Shape.in_any(view.barrier.buildings.slice(1), ground, 0.06):
						check(at.y < -0.08, "visible root geometry avoids protected structures")
	check(sizes.size() == 5, "the same root can scale with all five Heart stages")
