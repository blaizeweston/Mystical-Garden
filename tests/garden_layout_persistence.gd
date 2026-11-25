extends SceneTree
## Real world/serializer integration in disposable fixture storage only.
const Saved = preload("res://garden_development_state.gd")
const Water = preload("res://garden_water.gd")
const Placement = preload("res://tests/support/garden_placement_case.gd")
var failed := false
var base := "res://.godot/garden-layout-" + str(Time.get_ticks_usec())

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Garden layout: ", message)

func world(fresh: bool = true) -> Node:
	var menu = preload("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	if fresh:
		menu.new_game()
		menu.creator.hide()
		menu.create_character("Layout Keeper", 0, preload("res://character_appearance.gd").DEFAULT)
	else:
		menu.continue_game()
	for frame in 30:
		await process_frame
		if current_scene != menu: break
	if current_scene == menu:
		check(false, "title opens disposable Garden: " + menu.notice.text)
		return null
	var game: Node = current_scene
	game.set_process(false)
	game.set_physics_process(false)
	game.app_settings.values.garden_cinematics = false
	game.players[1].pos = Vector3(0, 0, 1.5)
	return game

func relocation(garden: Node, kind: String, id: int) -> Vector2:
	var at: Vector2 = garden.construction.records[id].at
	return Placement.find(garden.construction, kind, at, 0.2, garden.planar(garden.game.players[1].pos), id)

func equivalent(a: Variant, b: Variant) -> bool:
	# ConfigFile uses text floats; geometry must retain its resolved precision.
	if a is float: return (b is float or b is int) and is_equal_approx(a, b)
	if a is Vector2 or a is Vector3: return typeof(a) == typeof(b) and a.is_equal_approx(b)
	if a is Dictionary:
		return b is Dictionary and a.size() == b.size() and a.keys().all(func(key): return b.has(key) and equivalent(a[key], b[key]))
	if a is Array or a is PackedVector2Array or a is PackedVector3Array:
		if not (b is Array or b is PackedVector2Array or b is PackedVector3Array) or a.size() != b.size(): return false
		for index in a.size():
			if not equivalent(a[index], b[index]): return false
		return true
	return a == b

func measure_space(garden: Node) -> void:
	var usable := 0
	var size := Rect2(Vector2.ZERO, Vector2.ZERO)
	for point: Vector2 in garden.state.outline: size = size.expand(point)
	for cell: Vector2i in garden.state.owned:
		var center: Vector2 = garden.state.Grid.cell_to_world(cell, garden.Spacing)
		if garden.construction.validate("bed", center, 0, Vector2(0,1.5)).is_empty(): usable += 1
	var frontiers := {}
	for proposal: Dictionary in garden.state.frontier_options():
		frontiers[garden.state.DIRECTIONS[proposal.sector]] = proposal.cells.size()
	print("GARDEN_SPACE ", {"clearing_m":size.size, "legal_centers":usable, "sample_area_m2":usable*garden.state.cell_area(), "frontiers":frontiers})

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/vd/") or OS.get_environment("MYSTICAL_VALIDATION_RUN").is_empty():
		printerr("FAIL: this fixture requires the validation runner's disposable save root")
		quit(1)
		return
	var game := await world()
	if game == null: quit(1); return
	var garden = game.stage.experimental_garden
	measure_space(garden)
	check(garden.bed_ids.size() == 3 and garden.station_ids.has("altar") and garden.construction.records.size() == 4,
		"all starting structures have exactly one placement record")
	check(not garden.state.landmarks.has("altar") and not garden.state.landmarks.has("bed_0"),
		"old fixed collision and root reservations are retired")
	var altar: int = garden.station_ids.altar
	var altar_target := Vector2(6.0, 1.5)
	check(garden.place("altar", altar_target, 0.0, altar), "the existing Garden Altar moves into the retired spring reservation")
	game.progress.plots[0].merge({"species": 0, "age": 300.0, "stage": 3}, true)
	preload("res://garden_crop_state.gd").ensure(game.progress.plots[0])
	preload("res://cultivation_growth.gd").initialize(game.progress.plots[0])
	game.progress.sync_plot_flags()
	var crop: Dictionary = game.progress.plots[0].duplicate(true)
	var ids: Dictionary = garden.bed_ids.duplicate()
	for slot in 3:
		var id: int = ids[slot]
		var target := relocation(garden, "bed", id)
		check(target.is_finite() and garden.place("bed", target, 0.2, id), "starting bed %d can move without research" % (slot + 1))
		check(game.stage.bed_position(slot).is_equal_approx(Vector3(target.x, 0, target.y)), "bed interaction uses current placement")
	check(game.progress.plots.size() == 3 and game.progress.plots[0] == crop and garden.bed_ids == ids,
		"moving retains the plot identity and complete crop record")
	check(game.stage.altar_position().is_equal_approx(Vector3(altar_target.x, 0, altar_target.y))
		and garden.structure_nodes.size() == 1, "altar art and interaction move together without an old copy")
	check(not garden.place("altar", Vector2.ZERO, 0.0), "a second starting altar cannot be purchased")
	garden.open_development()
	check(garden.building_picker.item_count == 4 and garden.building_picker.get_item_text(0) == "Starting bed 1",
		"building menu names all starting structures")
	garden.development_dialog.hide()
	# Real guarded/native failure injection: no successful-save assumption.
	var before: Dictionary = garden._capture_development()
	var bytes := FileAccess.get_file_as_bytes(game.progress.path)
	var path: String = game.progress.path
	game.progress.path = base + "-missing/failed.cfg"
	var retry := relocation(garden, "bed", ids[0])
	check(retry.is_finite() and not garden.place("bed", retry, 0.2, ids[0]), "failed serializer rejects relocation")
	check(garden._capture_development() == before and FileAccess.get_file_as_bytes(path) == bytes,
		"failed save restores placement, revisions and existing saved bytes")
	game.progress.path = path
	check(garden.place("bed", retry, 0.2, ids[0]), "confirmed rollback can be retried")
	# Offerings, reclaimed land and roots must reload with placements.
	game.progress.heart.unlock_direct("clearing_1")
	game.progress.add_parts(game.Parts.THORN, 50)
	garden.open_offerings()
	var item: String = game.Items.part_id(game.Parts.THORN)
	var knowledge_before: int = game.progress.knowledge
	var quote: Dictionary=garden.funds.quote({item:30})
	check(garden.contribute(quote) and game.progress.knowledge == knowledge_before + 30, "one offering grants both currencies immediately")
	check(not garden.contribute(quote) and game.progress.archive.garden.energy==quote.energy and game.progress.archive.characters[game.local_character.identity].energy==quote.energy,"a rejected repeat cannot increase lifetime contribution Energy")
	garden.offering_dialog.hide()
	garden.open_development()
	check(not garden.plans.is_empty(), "an expansion is available")
	if not garden.plans.is_empty():
		var sector: int = garden.plans.keys()[0]
		var receipts: Dictionary = game.progress.garden_interactions.duplicate(true)
		game.progress.path = base + "-missing/failed-expansion.cfg"
		check(not garden.expand(sector) and garden.state.revision == 0 and garden.reveal == null
			and game.progress.garden_interactions == receipts, "failed expansion publishes neither land nor a scene")
		game.progress.path = path
		check(garden.expand(sector) and not garden.expand(sector), "one expansion consumes its energy once")
		if garden.reveal != null: garden.reveal.custom_step(3.0)
	garden.development_dialog.hide()
	await process_frame
	var saved: Dictionary = garden._capture_development()
	var saved_inventory: Dictionary = game.progress.structures.duplicate(true)
	check(Saved.refusal(saved, 3).is_empty() and game.progress.save_garden() == OK, "complete Garden projection serializes")
	var positions: Array = game.stage.bed_positions().duplicate()
	var altar_position: Vector3 = game.stage.altar_position()
	game.free()
	game = await world(false)
	if game == null: quit(1); return
	garden = game.stage.experimental_garden
	var expansions: Array = game.progress.garden_interactions.growth.events.filter(func(e): return e.kind == "expansion")
	check(expansions.size() == 1 and expansions[0].expansion == garden.state.revision,
		"one saved scene identifies the committed frontier after reload")
	check(equivalent(garden._capture_development(), saved) and game.progress.plots[0] == crop,
		"fresh world reload preserves the layout, crop, reclaimed cells, roots, energy and placements")
	check(game.stage.bed_positions() == positions and game.stage.altar_position() == altar_position,
		"reloaded interactions use saved positions")
	check(equivalent(game.progress.structures,saved_inventory) and garden.roots.get_child_count() == saved.roots.size(),
		"stable structure IDs and root presentation survive restart")
	check(Water._features(game.stage) == garden.state.layout.water and Water.anchor(game.stage).is_finite(),
		"terrain water remains reachable after layout reload")
	var complete: Dictionary = garden._capture_development()
	var loaded = game.Progress.new()
	loaded.path = game.progress.path
	check(loaded.load_garden() == OK and loaded.garden_development == complete and loaded.knowledge == knowledge_before + 30,
		"layout and paid Knowledge share one durable commit")
	# Optional old-save section and malformed data are distinct outcomes.
	check(Saved.refusal({}).is_empty(), "older Garden without layout remains supported")
	for bad in [false, {"version": 999}]:
		check(not Saved.refusal(bad).is_empty(), "unsupported saved data fails closed")
	var malformed: Dictionary = saved_inventory.duplicate(true)
	malformed.instances[1].at = Vector2(NAN, 0)
	check(not game.Progress.Structures.valid(malformed,game.progress.plots), "nonfinite placement fails closed")
	var file := ConfigFile.new()
	check(file.load(loaded.path) == OK, "disposable save is readable")
	file.set_value("garden_development", "state", {"version": 999})
	var invalid_path := base + ".invalid"
	check(file.save(invalid_path) == OK, "write disposable malformed fixture")
	loaded.path = invalid_path
	var invalid_bytes := FileAccess.get_file_as_bytes(invalid_path)
	check(loaded.load_garden() == ERR_FILE_CORRUPT and loaded.save_garden() != OK
		and FileAccess.get_file_as_bytes(invalid_path) == invalid_bytes, "unknown layout cannot be overwritten by an empty fallback")
	game.free()
	if not failed: print("PASS: movable starting beds/altar, crop identity, transactional layout persistence, expansion/roots, studies, rollback and schema refusal")
	quit(1 if failed else 0)
