extends SceneTree

const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Catalog = preload("res://heart_catalog.gd")

var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL: ", label)

func run() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	await process_frame
	var view = scene.expansion
	var progress = view.knowledge
	var build = view.construction
	var model = build.model
	var site := Vector2(2.34, -4.58)
	var owned: Dictionary = view.state.owned.duplicate()
	var landmarks: Dictionary = view.state.landmarks.duplicate(true)
	view.set_active(true)
	check(not view.active and view.enter.disabled, "unresearched expansion is locked at the entry point")
	check(model.commit("bed", site, 0.37, view.pawn) == 0, "unresearched beds cannot be committed")
	view._open_knowledge()
	var panel = view.knowledge_dialog
	check(panel.visible and panel.capabilities.text.contains("Research Reaching Roots"),
		"the real modal displays the growth prerequisite")
	_choose(panel, "plot_5")
	check(panel.study.disabled and panel.detail.text.contains("Garden Bed 4"), "the modal displays prerequisite refusal")
	check(not progress.research("plot_5") and not progress.research("clearing_1"), "cannot bypass parents or knowledge")
	panel.grant.pressed.emit()
	_choose(panel, "plot_4")
	panel.study.pressed.emit()
	check(progress.unlocked.has("plot_4") and progress.spent == Catalog.get_node("plot_4").insight,
		"the modal completes research with its production cost")
	check(not progress.research("plot_4") and model.records.is_empty() and view.state.owned == owned,
		"unlock and duplicate refusal do not place objects or grow the Garden")
	_choose(panel, "clearing_1")
	panel.study.pressed.emit()
	check(view.state.revision == 0 and panel.capabilities.text.contains("Heart growth tier 1"),
		"research enables growth without changing terrain")
	panel.hide()
	view.set_active(true)
	check(not view.select_frontier(-1) and view.offerings.energy == 0, "invalid frontier spends nothing")
	view.set_active(false)
	build.toggle.button_pressed = true
	build.preview(site)
	var id: int = build.confirm()
	check(id > 0, "the unlocked bed is placeable through Build")
	if id <= 0:
		quit(1)
		return
	model.records[id].state = {"crop": "moonleaf", "growth": 0.64}
	check("bed spaces" in model.validate("bed", Vector2(6.44, 0.45), 0.37, view.pawn)
		and model.commit("bed", Vector2(6.44, 0.45), 0.37, view.pawn) == 0, "bed allotment enforced")
	var part: String = view.offerings.items.keys()[0]
	check(view.offerings.offer(view.offerings.quote({part: 90})), "research fixture funds player-selected growth")
	check(_grow(view, [4, 6, 1, 0, 2, 5]), "the player chooses the first eligible frontier")
	for i in 5:
		progress.grant_test_knowledge()
	check(progress.research("plot_5") and progress.research("clearing_2") and progress.research("clearing_3"),
		"higher tiers can be researched in prerequisite order")
	check(progress.research("flowering") and progress.research("seed_archive")
		and progress.research("monster_studies"), "existing altar prerequisites unlock lab structures")
	check(progress.locked_reason("spring").contains("Root Irrigation") and progress.research("irrigation")
		and progress.locked_reason("spring").is_empty(), "watering basin uses the sheltered spring prerequisites")
	check(model.records.size() == 1 and model.records[id].state.crop == "moonleaf",
		"research cannot overwrite the first crop or automatically add unlocked structures")
	check(_grow(view, [6, 1, 0, 2, 5, 4]) and _grow(view, [2, 3, 5, 6, 0, 1, 4]),
		"later growth can be used after construction")
	check(progress.clearing_tier() == 3 and not view.enter.disabled
		and view.state.revision == 3 and view.state.landmarks == landmarks,
		"research does not cap growth and fixed landmarks remain intact")
	build.toggle.button_pressed = true
	build.move_mode.button_pressed = true
	build.press(site)
	build.preview(Vector2(6.44, 0.45))
	check(build.confirm() == id and model.records[id].state.crop == "moonleaf",
		"move retains the original ID and crop")
	check("heart" in model.validate("archive", Vector2.ZERO, 0.0, view.pawn)
		and view.state.entrance_clear(), "protects landmarks and the Wilds entrance")
	progress.set_sandbox(true)
	check(not view.enter.disabled and progress.unlocked.has("plot_4"), "free-build preview mode is explicit")
	progress.set_sandbox(false)
	check(not view.enter.disabled and model.records.has(id), "leaving test mode preserves earned growth and buildings")
	view.reset_garden()
	check(view.state.revision == 0 and view.construction.model.records.is_empty()
		and progress.clearing_tier() == 3 and view.offerings.energy == 0, "Reset Garden resets layout and energy while retaining research")
	if errors == 0:
		print("PASS: Knowledge prerequisites, limits, construction, relocation and chosen growth")
	quit(int(errors != 0))

func _choose(panel, id: String) -> void:
	for index in panel.research_list.item_count:
		if panel.research_list.get_item_metadata(index) == id:
			panel.research_list.select(index)
			panel.research_list.item_selected.emit(index)
			return

func _grow(view, sectors: Array) -> bool:
	view.set_active(true)
	for sector: int in sectors:
		if not view.select_frontier(sector):
			continue
		view.confirm_growth()
		if view.growing:
			view.finish_animation()
			return true
	return false
