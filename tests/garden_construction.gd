extends SceneTree

const P = preload("res://assets/terrain_m02/terrain_preview.tscn")
const C = preload("res://assets/terrain_m02/garden_construction.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Forest = preload("res://assets/terrain_m02/garden_forest_barrier.gd")
const Placement = preload("res://tests/support/garden_placement_case.gd")

var errors := 0
var elapsed := PackedInt64Array()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL: " + label)

func run() -> void:
	var scene := P.instantiate()
	root.add_child(scene)
	await process_frame
	var view = scene.expansion
	view.knowledge.set_sandbox(true)
	var build = view.construction
	var model: C = build.model
	build.toggle.button_pressed = true
	check(build.enabled and build.panel.visible, "Build opens an isolated construction toolbar")
	var garden = view.state
	var query_boundary := Forest.new()
	root.add_child(query_boundary)
	query_boundary.bind(garden, false)
	var rendered_centres := PackedVector2Array()
	for section: Dictionary in view.barrier.sections:
		for i in section.count:
			var at: Vector3 = section.clumps[i].position
			rendered_centres.append(Vector2(at.x, at.z))
	check(query_boundary.get_child_count() == 0 and query_boundary.parts.is_empty(), "query-only forest creates no wall meshes")
	check(query_boundary.thicket_centres() == rendered_centres, "construction clearances exactly match the former rendered positions")
	query_boundary.free()
	var start_positions: Dictionary = garden.landmarks.duplicate(true)
	var heading := 0.37
	var bed := Placement.find(model, "bed", Vector2(2.34, -4.58), heading, view.pawn)
	check(bed.is_finite(), "a rotated bed fits beyond the fully grown Heart")
	check(Grid.cell_to_world(Grid.world_to_cell(bed, garden.spacing), garden.spacing) != bed, "fixture uses continuous coordinates")
	var span := model.footprint("bed", bed, heading).outline as PackedVector2Array
	var covered := {}
	for corner in span:
		covered[Grid.world_to_cell(corner, garden.spacing)] = true
	check(covered.size() >= 3, "rotated test footprint spans several hexes")
	var pointer := InputEventMouseMotion.new()
	pointer.position = root.get_visible_rect().get_center() + Vector2(76, -48)
	var ray: Vector3 = scene.camera.project_ray_normal(pointer.position)
	var origin: Vector3 = scene.camera.project_ray_origin(pointer.position)
	var click: Vector3 = Plane(Vector3.UP, 0.0).intersects_ray(origin, ray)
	scene._expansion_input(pointer)
	var projected: Vector2 = build.target
	check(projected.distance_to(Vector2(click.x, click.z)) < 0.002 and projected.distance_to(
		Grid.cell_to_world(Grid.world_to_cell(projected, garden.spacing), garden.spacing)) > 0.1,
		"mouse projection preserves the clicked ground point without snapping")
	build.yaw = heading
	build.preview(bed)
	check(build.ghost.visible and not build.apply.disabled, "valid placement displays a live ghost")
	var touched := Grid.world_to_cell(span[0], garden.spacing)
	var original_terrain: StringName = garden.terrain[touched]
	garden.terrain[touched] = &"stone"
	check(model.validate("bed", bed, heading, view.pawn).is_empty(),
		"an owned stone-labeled hex does not reject a clear footprint")
	garden.terrain[touched] = original_terrain
	var starter: Dictionary = garden.landmarks.monster_studies
	build.preview(starter.center)
	check(build.apply.disabled and build.blocker.visible and "monster studies" in build.reason
		and build.blocker_outline == Shape.boundary(starter),
		"the demo station's reserved area is outlined when it blocks placement (%s)" % build.reason)
	build.preview(bed)
	check(not build.blocker.visible and not build.apply.disabled, "the blocker clears when placement is valid again")
	build.yaw = 0.0
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_E
	scene._expansion_input(key)
	check(is_equal_approx(build.yaw, PI / 12.0), "rotation can snap to fifteen degrees")
	build.snap.button_pressed = false
	scene._expansion_input(key)
	check(not is_equal_approx(build.yaw, snappedf(build.yaw, PI / 12.0)), "rotation can move off snap increments")
	build.yaw = heading
	var id: int = build.confirm()
	check(id == 1 and model.records[id].at == bed and model.records[id].yaw == heading, "confirmation stores the exact pose")
	if id == 0:
		quit(1)
		return
	model.records[id].state = {"crop": "moonleaf", "growth": 0.64}
	var record_state: Dictionary = model.records[id].state
	var art: Node = build.objects[id]
	check(not view.barrier.walkable(bed), "placed footprints block actual Garden walking")
	check("another structure" in model.validate("bed", bed, heading, view.pawn), "overlapping placement is rejected")
	check(not model.CATALOG.has("spring") and model.validate("spring", Vector2(-6.64, 4.23), 0.0, view.pawn)=="Choose a Garden structure.", "retired spring fixture cannot be constructed")
	check("Heart" in model.validate("bed", Vector2.ZERO, 0.0, view.pawn), "Heart reservation is protected")
	check("water" in model.validate("archive", garden.layout.water[0].bounds.get_center(), 0.0, view.pawn), "pond rejects full footprint")
	var approach: PackedVector2Array = garden.layout.paths[0].spine
	var on_path := approach[approach.size() / 2]
	check("Wilds approach" in model.validate("archive", on_path, 0.0, view.pawn), "Gate corridor is protected")
	check("player" in model.validate("bed", Vector2(-3.25, -5.25), 0.37, Vector2(-3.25, -5.25)),
		"placement cannot enclose the current player")
	var study_site := Placement.find(model, "study", Vector2(-6.67, 4.44), heading, view.pawn)
	var unique: int = model.commit("study", study_site, heading, view.pawn)
	check(unique > 0 and "already" in model.validate("study", Vector2.ZERO, 0.0, view.pawn), "field study is unique")
	var repeat_site := Placement.find(model, "bed", Vector2(0.17, 5.58), heading, view.pawn)
	var repeat: int = model.commit("bed", repeat_site, heading, view.pawn)
	check(repeat > unique, "repeatable beds receive distinct increasing IDs")
	_find_rotated_overhang(model, view.pawn)
	_check_denied_access(model, view.pawn)
	build.preview(Vector2.ZERO)
	check(build.apply.disabled and build.ghost.visible and not build.reason.is_empty(), "invalid ghost gives a reason")
	var before_cancel: Dictionary = model.records.duplicate(true)
	build._cancel()
	check(model.records == before_cancel and not build.ghost.visible, "cancel preserves all records")
	var expanded := 0
	for sector in [4, 6, 1, 0, 2, 5]:
		if _expand(view, sector):
			expanded += 1
		if expanded == 2:
			break
	check(expanded == 2 and model.records[id].at == bed and build.objects[id] == art, "growth leaves buildings in place")
	var reclaimed := _reclaimed_site(model, view.pawn, id)
	check(reclaimed.is_finite(), "a full rotated footprint fits on new land")
	if reclaimed.is_finite():
		build.toggle.button_pressed = true
		build.move_mode.button_pressed = true
		build.press(bed)
		check(build.moving == id, "mouse selects the placed structure by footprint")
		build.preview(reclaimed)
		check(build.confirm() == id and model.records[id].at == reclaimed and model.records[id].state == record_state
			and build.objects[id] == art, "relocation preserves object identity, model, and crop state")
		check(view.barrier.walkable(bed), "relocation removes the old collision")
		var previous_pawn: Vector2 = view.pawn
		view.pawn = model._door_position(model.records[id])
		view.walk.button_pressed = true
		scene._expansion_input(key)
		check("moonleaf" in view.status.text and ("#%d" % id) in view.status.text,
			"walking to the relocated bed exposes the same crop state through the preview interaction")
		view.walk.button_pressed = false
		view.pawn = previous_pawn
	for sector in [2, 3, 5, 6, 0, 1, 4]:
		if _expand(view, sector):
			expanded += 1
			break
	check(expanded >= 3 and model.records.size() == 3 and garden.landmarks == start_positions,
		"construction survives another expansion and fixed landmarks stay anchored")
	var pawn: Vector2 = approach[-1]
	for i in range(approach.size() - 1, -1, -1):
		pawn = view.barrier.move(pawn, approach[i] - pawn)
	check(pawn.is_equal_approx(garden.landmarks.wilds_entrance.center), "walking path still reaches the Wilds Gate")
	print("M14_METRICS ", JSON.stringify({"runs": elapsed.size(), "p50_us": _percentile(0.5),
		"p95_us": _percentile(0.95), "growth_count": expanded, "placed": model.records.size()}))
	view.reset_garden()
	check(view.construction.model.records.is_empty() and view.barrier.construction.is_empty(), "reset clears the in-memory construction session")
	scene.free()
	if errors == 0:
		print("PASS: rotated construction footprints, route protection, relocation identity and expansion compatibility")
	quit(int(errors > 0))

func _expand(view, sector: int) -> bool:
	view.set_active(true)
	if not view.select_frontier(sector):
		return false
	view.confirm_growth()
	if not view.growing:
		return false
	view.finish_animation()
	return true

func _reclaimed_site(model: C, pawn: Vector2, id: int) -> Vector2:
	for cell in model.forest.garden.owned:
		if model.forest.garden.owned[cell] == 0:
			continue
		var center := Grid.cell_to_world(cell, model.forest.garden.spacing)
		for offset in [Vector2(0.16, 0.11), Vector2(-0.43, -0.24), Vector2(0.43, 0.25)]:
			var at: Vector2 = center + offset
			if model.validate("bed", at, model.records[id].yaw, pawn, id).is_empty():
				return at
	return Vector2.INF

func _find_rotated_overhang(model: C, pawn: Vector2) -> void:
	var garden = model.forest.garden
	var found := false
	for cell in garden.owned:
		var at := Grid.cell_to_world(cell, garden.spacing) + Vector2(0.22, -0.16)
		if not model.forest.fixed_walkable(at):
			continue
		var started := Time.get_ticks_usec()
		var verdict := model.validate("archive", at, 0.68, pawn)
		elapsed.append(Time.get_ticks_usec() - started)
		check(model.validate("archive", at, 0.68, pawn) == verdict, "equal inputs give deterministic validation")
		found = found or "unclaimed hex" in verdict or "forest edge" in verdict
	check(found, "owned center alone does not permit an overhanging footprint")
	elapsed.sort()

func _check_denied_access(model: C, pawn: Vector2) -> void:
	var found := false
	for x in range(-12, 12):
		for z in range(-12, 13):
			var at := Vector2(x, z) * 0.57 + Vector2(0.17, -0.12)
			var verdict := model.validate("archive", at, 0.39, pawn)
			if "walkable approach" in verdict:
				check(model.commit("archive", at, 0.39, pawn) == 0, "inaccessible walking routes prevent commitment")
				found = true
				break
		if found:
			break
	check(found, "there is an allowed footprint with an unreachable approach in this fixture")

func _percentile(fraction: float) -> int:
	return elapsed[floori((elapsed.size() - 1) * fraction)] if not elapsed.is_empty() else 0
