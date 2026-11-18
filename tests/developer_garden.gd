extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Developer = preload("res://developer_mode.gd")
const Growth = preload("res://garden_growth_service.gd")
const Inventory = preload("res://inventory_model.gd")

var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL developer garden: ",message)


func run() -> void:
	var base := "res://.godot/developer-test-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var menu: Node = load("res://main_menu.tscn").instantiate()
	menu.storage.root_path = base
	menu.settings_path = base.path_join("settings.cfg")
	menu.import_legacy = false
	menu.restore_last_selection = false
	root.add_child(menu)
	current_scene = menu
	check(menu.storage.new_world(1)==OK,"ordinary world fixture")
	check(menu.characters.create(1,"Fern",1,[])==OK,"ordinary character fixture")
	menu.select_slot(1)
	menu.select_character(1)
	var original_garden: String = menu.storage.paths(1).garden
	var original_character: String = menu.characters.paths(1).character
	var garden_digest := FileAccess.get_sha256(original_garden)
	var character_digest := FileAccess.get_sha256(original_character)

	var settings: Window = menu.settings_dialog
	settings.begin(menu.app_settings)
	var options: Node = settings.developer_controls
	check(not options.toggle.button_pressed and not options.tools.visible,"developer mode defaults to off")
	options.toggle.button_pressed = true
	check(options.tools.visible,"toggling shows the developer entry point")
	settings.cancel()
	check(not menu.app_settings.values.developer_mode,"cancelling discards the toggle")
	settings.begin(menu.app_settings)
	options.toggle.button_pressed = true
	options.open_garden()
	var game := current_scene
	if not Developer.is_test_garden(game):
		check(false,"settings opens the isolated Developer Garden")
		quit(1)
		return
	game.set_process(false)
	game.set_physics_process(false)
	var view: Node = game.get_node("GardenInteractions/GrowthScenes")
	view.set_process(false)
	var progress: RefCounted = game.progress
	check(game.app_settings.values.developer_mode and Developer.can_edit(game),"saved preference enables the tools in the solo test world")
	check(progress.path.begins_with(base.path_join("developer-garden")) and game.local_character.path!=original_character,"the developer world and character use their own paths")
	check(SessionCase.World.host(game)==ERR_UNAVAILABLE and SessionCase.World.join(game,"127.0.0.1")==ERR_UNAVAILABLE,"the test Garden cannot host or join")
	SessionCase.set_role(game, "Guest")
	game.settings_dialog.developer_controls.setup(true)
	check(game.settings_dialog.developer_controls.toggle.disabled and not game.settings_dialog.developer_controls.tools.visible,"co-op disables the developer setting and buttons")
	check(not Developer.can_edit(game) and Developer.grant_resources(game).contains("available"),"an online role cannot change developer progress")
	check(Developer.stock_materials(game).contains("available"),"material stock rejects an online role")
	SessionCase.set_role(game, "Solo")
	await test_wilds_settings(game)

	var start_knowledge: int = progress.knowledge
	var parts_before: int = progress.parts[0]
	var seeds_before: int = progress.stock[0]
	game.settings_dialog.begin(game.app_settings)
	var tools: Node = game.settings_dialog.developer_controls
	tools.grant_button.pressed.emit()
	check(progress.knowledge==start_knowledge+100 and progress.parts[0]==parts_before+25 and progress.stock[0]==seeds_before+5,"settings button grants saved research and crafting supplies")
	test_material_stock(game, tools, base)
	game.settings_dialog.cancel()

	progress.heart.start(progress,"plot_4")
	game.settings_dialog.begin(game.app_settings)
	check(not tools.finish_button.disabled,"active research can be finished from Settings")
	tools.finish_button.pressed.emit()
	check(progress.heart.has("plot_4") and progress.plots.size()==4 and not game.settings_dialog.visible,"finish research creates the real plot and closes Settings")
	var count: int = progress.garden_interactions.growth.events.size()
	game.settings_dialog.begin(game.app_settings)
	for index in tools.tech_picker.item_count:
		if tools.tech_picker.get_item_metadata(index)=="irrigation":
			tools.tech_picker.select(index)
			break
	tools.unlock_button.pressed.emit()
	var events: Array = progress.garden_interactions.growth.events
	check(progress.heart.has("irrigation") and progress.heart.has("flowering"),"selected unlock stages its prerequisites")
	check(events.size()==count+1 and events.back().technology=="irrigation" and events.back().kind=="spring","the selected unlock queues one real spring reveal")
	check(Growth.projection(game,1).pending.any(func(event):return event.technology=="irrigation"),"the reveal reaches the normal playback queue")
	var restored: RefCounted = game.Progress.new()
	restored.path = progress.path
	check(restored.load_garden()==OK and restored.heart.has("irrigation") and restored.plots.size()==4,"developer unlocks persist through the normal save format")

	var stable_state: Dictionary = progress.heart.serialize()
	var stable_path: String = progress.path
	progress.path = base.path_join("missing").path_join("garden.cfg")
	check(Developer.test_unlock(game,"plot_6").contains("Could not save"),"a save error is reported")
	check(progress.heart.serialize()==stable_state and progress.plots.size()==4,"failed test unlock rolls prerequisites and plots back")
	progress.path = stable_path
	game.app_settings.values.developer_mode = false
	check(not Developer.can_edit(game) and Developer.grant_resources(game).contains("available"),"switching the setting off blocks mutations")
	check(Developer.stock_materials(game).contains("available"),"stocking also requires the enabled setting")
	game.return_to_main_menu()
	await process_frame
	menu = current_scene
	check(menu.storage.root_path==base and menu.selected==1 and menu.selected_character==1,"exiting restores the original menu and selections")
	check(FileAccess.get_sha256(original_garden)==garden_digest and FileAccess.get_sha256(original_character)==character_digest,"ordinary Garden and character files are unchanged")

	menu.settings_dialog.begin(menu.app_settings)
	options = menu.settings_dialog.developer_controls
	options.reset.button_pressed = true
	options.open_garden()
	game = current_scene
	check(Developer.is_test_garden(game) and not game.progress.heart.has("irrigation"),"start fresh resets only the test Garden")
	check(FileAccess.get_sha256(original_garden)==garden_digest,"reset preserves ordinary Garden")
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: developer settings toggle, separate saves, solo enforcement, complete material stocks, real research and reveals, save rollback and reset")
	quit(1 if failed else 0)


func test_wilds_settings(game: Node) -> void:
	var player: Dictionary = game.players[game.HOST]
	ExpeditionCase.set_membership(game, player, true)
	var window: Window = game.settings_dialog
	window.begin(game.app_settings)
	var footer := window.find_child("SettingsActions", true, false) as HBoxContainer
	var pages := window.find_child("SettingsCategories", true, false) as TabContainer
	var tools: Node = game.settings_dialog.developer_controls
	check(tools.tools.visible and tools.grant_button.disabled, "the full Developer Mode section is present in the Wilds")
	for dimensions in [Vector2i(650,480), Vector2i(460,280)]:
		window.size = dimensions
		for tab in pages.get_tab_count():
			pages.current_tab = tab
			await process_frame
			await process_frame
			var window_rect := window.get_visible_rect()
			check(window_rect.encloses(footer.get_global_rect()), "all footer actions fit at %s on %s" % [dimensions,pages.get_tab_title(tab)])
			if tab == 0:
				var gameplay := pages.get_tab_control(tab) as ScrollContainer
				var bar := gameplay.get_v_scroll_bar()
				check(bar.max_value > bar.page, "overflowing Wilds gameplay settings can scroll")
				gameplay.ensure_control_visible(tools.tech_picker)
				check(gameplay.scroll_vertical > 0, "the last developer control is reachable")
	pages.current_tab = 0
	window.cancel()
	ExpeditionCase.set_membership(game, player, false)


func test_material_stock(game: Node, tools: Node, base: String) -> void:
	var progress: RefCounted = game.progress
	var player: Dictionary = game.players[game.HOST]
	var rare: int = game.Parts.rare_part(game.Seeds.DEFINITIONS.size()-1)
	var trophy: int = game.Parts.monster_part(0)
	var stock: Array = game.seed_reserve(player).stock
	var high_seed := stock.size()-1
	var known: Array = progress.discoveries.duplicate()
	var knowledge: int = progress.knowledge
	progress.add_parts(rare, Developer.MATERIAL_STOCK+2)
	stock[high_seed] = Developer.SEED_STOCK+1
	check(not tools.materials_button.disabled,"the material button is usable in the test Garden")
	tools.materials_button.pressed.emit()
	var shared := Inventory.counts(game, player, "shared")
	for part in range(1, game.Parts.DEFINITIONS.size()):
		if game.Parts.is_plant(part) or game.Parts.is_monster(part):
			check(int(shared.get(Inventory.Items.part_id(part),0))>=Developer.MATERIAL_STOCK, "shared inventory stocks "+game.Parts.part_name(part))
	var stash := Inventory.counts(game, player, "stash")
	for species in game.Seeds.DEFINITIONS.size():
		check(int(stash.get(Inventory.Items.seed_id(species),0))>=Developer.SEED_STOCK,"the personal stash stocks "+game.Seeds.NAMES[species])
	check(stash.unidentified_seed==Developer.SEED_STOCK and stash.boss_mystery_seed==Developer.SEED_STOCK,"both mystery seed types are stocked for altar tests")
	check(progress.part_count(rare)==Developer.MATERIAL_STOCK+2 and stock[high_seed]==Developer.SEED_STOCK+1,"top-up preserves quantities above the minimum")
	check(progress.knowledge==knowledge and progress.discoveries==known,"stocking preserves Knowledge and seed discoveries")
	check(Developer.stock_materials(game).contains("already full"),"a repeat click does not add more materials")

	player.pos=game.Stage.GATE
	UIFixture.control(game,"loadout_view").refresh()
	check(UIFixture.control(game,"loadout_view").slots[0].get_item_index(rare)>=0 and UIFixture.control(game,"loadout_view").cargo_pick.get_item_index(trophy)>=0,"the weapon bench can use the rare part and pack the trophy")
	player.pos=game.Stage.ALTAR
	var offering: Array=[{"item":Inventory.Items.seed_id(0),"source":"stash"},{"item":Inventory.Items.seed_id(high_seed),"source":"stash"}]
	check(game.Altar.validate(game, player, offering).is_empty(),"stocked seeds can be offered at the Altar")

	var restored: RefCounted = game.Progress.new()
	restored.path = progress.path
	check(restored.load_garden()==OK and restored.part_count(rare)==Developer.MATERIAL_STOCK+2 and restored.part_count(trophy)==Developer.MATERIAL_STOCK,"rare parts and trophies persist in the Garden save")
	check(restored.reserve(SessionCase.Session.inventory_owner(player)).stock==stock and restored.item_stashes[SessionCase.Session.inventory_owner(player)].boss_mystery_seed==Developer.SEED_STOCK,"identified and mystery seeds survive reload")

	progress.add_parts(trophy, -1)
	progress.add_parts(rare, -3)
	game.seed_reserve(player).stock[0] -= 1
	var unknown: Array = game.seed_reserve(player).unknown
	unknown.pop_back()
	var extras := Inventory.extra_stash(game, player)
	extras.boss_mystery_seed -= 1
	var stable_path: String = progress.path
	progress.path=base.path_join("missing").path_join("garden.cfg")
	var shared_before := Inventory.counts(game, player, "shared")
	var stash_before := Inventory.counts(game, player, "stash")
	check(Developer.stock_materials(game).contains("Could not save"),"stocking reports a save error")
	check(Inventory.counts(game, player, "shared")==shared_before and Inventory.counts(game, player, "stash")==stash_before,"failed save rolls back all inventory buckets")
	progress.path=stable_path
	player.pos=game.Stage.HEART
	ExpeditionCase.set_membership(game, player, true)
	check(Developer.stock_materials(game).contains("available"),"an active expedition prevents stocking")
	ExpeditionCase.set_membership(game, player, false)
