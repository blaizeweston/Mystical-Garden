extends SceneTree
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Heart = preload("res://assets/terrain_m02/terrain_heart_preview.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Placement = preload("res://tests/support/garden_placement_case.gd")
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; printerr("FAIL Heart reservation: ", message)
func run() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	await process_frame
	var view = scene.expansion
	view.knowledge.set_sandbox(true)
	var model = view.construction.model
	check(model.placement_issue("bed", Vector2(-3.25, -5.25), 0.37, view.pawn).get("blocker", {}).get("id") != "heart",
		"overhead branches do not reserve ground; ordinary obstruction rules remain separate")
	var footprint := Heart.maximum_base_outline()
	check(footprint.size() >= 3 and Geometry2D.triangulate_polygon(footprint).size() > 0, "maximum model has a valid ground-level base footprint")
	var sculpt := Heart.SCULPT.instantiate() as Node3D
	var mature := sculpt.get_node("HeartStage5") as MeshInstance3D
	var ids: Array = Heart.Research.DEFINITIONS.map(func(entry): return entry.id)
	mature.position = Vector3.ZERO
	mature.scale = Heart.research_scale(maxi(22, Heart.Growth.count(ids))) # Pre-HG01 build reservation.
	var pose := sculpt.transform * mature.transform
	var canopy_points := PackedVector2Array()
	var base_vertices := 0
	for surface in mature.mesh.get_surface_count():
		var vertices: PackedVector3Array = mature.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var at := pose * vertex
			canopy_points.append(Vector2(at.x, at.z))
			if at.y < 0.0 or at.y > Heart.BUILD_BASE_HEIGHT_M: continue
			base_vertices += 1
			if Shape.polygon_distance(footprint, Vector2(at.x, at.z)) > 0.0001:
				check(false, "all exposed ground-level roots at maximum research remain within the reservation")
				break
	var base_bounds: Rect2 = Shape.shape("base", "heart_base", footprint).bounds
	var canopy_outline := Geometry2D.convex_hull(canopy_points)
	var canopy_bounds: Rect2 = Shape.shape("canopy", "canopy", canopy_outline).bounds
	check(base_vertices > 0 and base_bounds.size.x < canopy_bounds.size.x * 0.7
		and base_bounds.size.y < canopy_bounds.size.y * 0.7, "overhead canopy and buried geometry do not reserve building land")
	var crossings := Shape.project_height_band(PackedVector3Array([Vector3(-2,-1,-1), Vector3(2,1,-1), Vector3(0,1,1)]), Transform3D.IDENTITY, 0.0, Heart.BUILD_BASE_HEIGHT_M)
	check(crossings.has(Vector2(0,-1)) and crossings.has(Vector2(-1,0)), "root faces crossing the ground band are retained even without a vertex inside it")
	check(Shape.project_height_band(PackedVector3Array([Vector3(-20,3,0), Vector3(20,3,0), Vector3(0,4,2),
		Vector3(-20,-3,0), Vector3(20,-3,0), Vector3(0,-4,2)]), Transform3D.IDENTITY, 0.0, Heart.BUILD_BASE_HEIGHT_M).is_empty(), "wholly overhead or buried faces add no restriction")
	var issue: Dictionary = model.placement_issue("bed", Vector2.ZERO, 0.0, view.pawn)
	check(issue.get("blocker", {}).get("id") == "heart" and issue.blocker.outline == footprint
		and issue.blocker.kind == "heart_base" and "base" in issue.message, "the actual Heart base remains protected with an accurate blocker outline")
	var outside := Placement.find(model, "bed", Vector2(3.5, 5), 0.0, view.pawn)
	check(outside.is_finite() and model.validate("bed", outside, 0.0, view.pawn).is_empty(), "starting clearing has usable construction space")
	var saved := footprint.duplicate()
	footprint[0] = Vector2.INF
	check(Heart.maximum_base_outline() == saved, "public footprint views cannot mutate the cached source")
	print("HEART_BASE_METRICS ", JSON.stringify({"base_m": base_bounds.size, "canopy_m": canopy_bounds.size, "base_vertices": base_vertices}))
	sculpt.free()
	scene.free()
	await check_starting_garden(canopy_outline)
	if not failed: print("PASS: maximum Heart ground-base protection, buildable starting clearing, under-canopy placement, relocation and detached cache")
	quit(1 if failed else 0)

func check_starting_garden(canopy_outline: PackedVector2Array) -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/vd/"):
		check(false, "production placement probe requires disposable save storage")
		return
	var menu = preload("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.new_game()
	menu.creator.hide()
	menu.create_character("Heart Base Builder", 0, preload("res://character_appearance.gd").DEFAULT)
	for frame in 30:
		await process_frame
		if current_scene != menu: break
	if current_scene == menu:
		check(false, "disposable new Garden opens")
		menu.free()
		return
	var game: Node = current_scene
	game.set_process(false)
	game.set_physics_process(false)
	game.app_settings.values.garden_cinematics = false
	game.players[1].pos = Vector3(0,0,1.5)
	var garden = game.stage.experimental_garden
	var crop_records: Array = game.progress.plots.duplicate(true)
	for slot in 3:
		var id: int = garden.bed_ids[slot]
		var bed_target := Placement.find(garden.construction, "bed", garden.construction.records[id].at, 0.2, garden.planar(game.players[1].pos), id)
		check(bed_target.is_finite() and garden.place("bed", bed_target, 0.2, id), "starting bed %d moves before any expansion/research" % (slot + 1))
	var altar: int = garden.station_ids.altar
	var target := Placement.find(garden.construction, "altar", garden.construction.records[altar].at, 0.2, garden.planar(game.players[1].pos), altar)
	check(target.is_finite() and garden.place("altar", target, 0.2, altar), "starting altar moves before any expansion/research")
	check(game.progress.plots == crop_records, "moving the starting structures preserves every crop record")
	game.run_heart_save(func(): game.progress.heart.unlock_direct("plot_4"))
	target = Placement.find(garden.construction, "bed", Vector2(-3.25,-5.25), 0.37, garden.planar(game.players[1].pos))
	check(target.is_finite() and garden.place("bed", target, 0.37), "newly researched bed can be built in the original clearing")
	check(Geometry2D.is_point_in_polygon(target, canopy_outline), "real new bed fits beneath the canopy that previously prohibited construction")
	check(game.progress.plots.size() == 4 and garden.state.revision == 0 and garden.state.reclaimed_cells == 0
		and not game.progress.heart.has("clearing_1"), "construction requires no land expansion or clearing research")
	game.free()
