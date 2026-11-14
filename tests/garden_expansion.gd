extends SceneTree

const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Digest = preload("res://assets/terrain_m02/terrain_feature_layout.gd")

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
	check(view.visible and view.enter.visible, "the Garden preview exposes the expansion controls")
	var original := _snapshot(scene)
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
	scene.heart_stage.select(4)
	scene.heart_stage.item_selected.emit(4)
	check(heart.stage == 4 and view.state.revision == 5, "Heart stage selector works after expansion")
	scene.render_mode.select(4)
	scene.render_mode.item_selected.emit(4)
	check(not view.visible and not scene.get_node("GardenExterior").visible, "historical render disables expansion presentation")
	scene.render_mode.select(6)
	scene.render_mode.item_selected.emit(6)
	check(view.visible and view.roots.get_child_count() == 5 and view.state.revision == 5,
		"returning to M06C keeps reclaimed ownership and roots")
	_covered(scene)
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
	check(view.growing and state.roots.size() == root_count + 1
		and view.material.get_shader_parameter("garden_reveal") == 0.0, "growth starts at the Heart before the ground reveal")
	view._animate(0.64)
	var partial: float = view.material.get_shader_parameter("garden_reveal")
	check(partial > 0.0 and partial < 1.0, "shore and perimeter reveal progressively")
	view.finish_animation()
	check(not view.growing and view.last_root_tip == state.roots[-1].size()
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
