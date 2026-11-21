extends "res://tests/guarded_garden_actions.gd"
## Reuses only the disposable guarded title/lease fixture and disk assertions.

func target_for(garden: Node, id: int) -> Vector2:
	var at: Vector2 = garden.construction.records[id].at
	var candidates: Array[Vector2] = []
	for x in range(-13, 14):
		for y in range(-13, 14):
			var point := Vector2(x, y) * 0.5
			if point.distance_to(at) > 0.3: candidates.append(point)
	candidates.sort_custom(func(a, b): return a.distance_squared_to(at) < b.distance_squared_to(at))
	for point in candidates:
		if garden._build_refusal("bed", point, 0.2, id).is_empty(): return point
	return Vector2.INF

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/vd/") or OS.get_environment("MYSTICAL_VALIDATION_RUN").is_empty():
		printerr("FAIL: this fixture requires the validation runner's disposable save root")
		quit(1)
		return
	set_meta(Gate.VALIDATION_ROUTE, true)
	if not open_world(true): quit(1); return
	world.players[1].pos = Vector3(0, 0, 1.5)
	var garden = world.stage.experimental_garden
	var id: int = garden.bed_ids[0]
	var before: Dictionary = garden._capture_development()
	var original := disk()
	var target := target_for(garden, id)
	check(target.is_finite(), "starting bed has a legal relocation")
	world.set_meta(&"guarded_gameplay_test_fault", fail_stage)
	check(not garden.place("bed", target, 0.2, id), "failed guarded stage refuses relocation")
	world.remove_meta(&"guarded_gameplay_test_fault")
	check(garden._capture_development() == before and disk() == original, "rollback restores live Garden and disk together")
	check(garden.place("bed", target, 0.2, id), "a confirmed rollback permits retry")
	var committed_position: Vector3 = world.stage.bed_position(0)
	# Receipt cleanup failure is a committed save, not permission to retry spending.
	target = target_for(garden, id)
	world.set_meta(&"guarded_gameplay_test_fault", func(phase, _path): return ERR_CANT_CREATE if phase == "publish_receipt" else OK)
	check(garden.place("bed", target, 0.2, id), "committed cleanup-pending relocation is applied")
	world.remove_meta(&"guarded_gameplay_test_fault")
	committed_position = garden.world(target)
	check(world.stage.bed_position(0).is_equal_approx(committed_position) and not world.persistence_session.can_write(),
		"live position follows committed bytes while pending recovery blocks further placement")
	var committed := disk()
	check(not garden.place("bed", target, 0.2, id) and disk() == committed, "pending cleanup cannot replay the transaction")
	check(Ops.recover(PackedStringArray([garden_path])).value.verified and disk()[garden_path] == committed[garden_path],
		"cleanup preserves committed layout")
	close_world()
	await process_frame
	if not open_world(): quit(1); return
	world.players[1].pos = Vector3(0, 0, 1.5)
	garden = world.stage.experimental_garden
	check(world.stage.bed_position(0).is_equal_approx(committed_position), "reopen retains committed relocation")
	id = garden.bed_ids[0]
	before = garden._capture_development()
	original = disk()
	target = target_for(garden, id)
	world.set_meta(&"guarded_gameplay_test_fault", func(phase, _path):
		return ERR_CANT_CREATE if phase in ["publish_commit_marker", "restore"] else OK)
	check(not garden.place("bed", target, 0.2, id), "uncertain outcome withholds success")
	world.remove_meta(&"guarded_gameplay_test_fault")
	check(garden._capture_development() == before and world.persistence_session.pending_notice().contains("uncertain"),
		"uncertainty retains last confirmed live layout and blocks unsafe replay")
	var uncertain := disk()
	check(not garden.place("bed", target, 0.2, id) and disk() == uncertain, "uncertain request cannot repeat")
	check(Ops.recover(PackedStringArray([garden_path])).value.verified and disk() == original, "reverse recovery restores original saved layout")
	close_world()
	await process_frame
	if not open_world(): quit(1); return
	check(world.stage.bed_position(0).is_equal_approx(committed_position) and world.persistence_session.can_write(),
		"reconciled reopen restores safe construction without tentative relocation")
	close_world()
	await process_frame
	if not failed: print("PASS: guarded Garden layout rollback, committed cleanup, uncertain outcome, replay refusal and reconciled reopen")
	quit(1 if failed else 0)
