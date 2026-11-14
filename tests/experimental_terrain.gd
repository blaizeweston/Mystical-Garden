extends SceneTree

const Mode = preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Field = preload("res://assets/terrain_m02/experimental/experiment_wilds.gd")
const Parts = preload("res://weapon_parts.gd")
const Items = preload("res://item_catalog.gd")
const Menu = preload("res://main_menu.tscn")
const Appearance = preload("res://character_appearance.gd")
const MATURE := 10000.0

var errors := 0
var screenshots := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL: ", label)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has(Mode.FLAG):
		_run_child()
		return
	if args.size() > 1:
		screenshots = args[1]
	var menu := Menu.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	if args.has("unsafe"):
		check(not Mode.verified() and not menu.has_meta(&"experimental_terrain") and menu.notice == null
			and not DirAccess.dir_exists_absolute("user://saves"), "unsafe experimental startup refuses before save browsing")
		if errors == 0: print("PASS: unsafe profile refused before saves")
		call("quit", int(errors > 0))
		return
	check(Mode.verified() and menu.has_meta(&"experimental_terrain"), "real title verifies and labels the isolated mode")
	if errors > 0:
		call("quit", 1)
		return
	await _capture("title")
	menu.new_game()
	menu.create_character("Terrain Explorer", 0, Appearance.DEFAULT)
	for i in 30:
		await process_frame
		if current_scene != menu:
			break
	if current_scene == menu:
		printerr("FAIL: title admission ", menu.notice.text)
		call("quit", 1)
		return
	var game: Node = current_scene
	var garden = game.stage.experimental_garden
	var player: Dictionary = game.players[game.HOST]
	check(garden != null and game.slot_claimed and game.character_slot_claimed and game.get_meta(game.Transactions.SESSION).owns_leases(),
		"real world shows terrain with the native owner")
	check(game.host_game() == ERR_UNAVAILABLE and game.join_game() == ERR_UNAVAILABLE, "experiment refuses online transport")
	check(garden.barrier.walkable(garden.planar(player.pos)), "production avatar starts on clear ground")
	var start: Vector3 = player.pos
	game.move_player(game.HOST, Vector2.RIGHT, 0.12)
	check(player.pos != start, "production movement advances on the experimental Garden")
	game.move_player(game.HOST, Vector2.RIGHT, 8.0)
	check(garden.barrier.walkable(garden.planar(player.pos)), "movement stays inside the visible forest barrier")
	player.pos = Vector3(0, 0, 1.5)
	await _capture("garden")
	# Seed only this disposable profile. Research uses the real catalog, timer and serializers.
	var garden_scope: int = game.Transactions.Scope.GARDEN
	game.Transactions.run_gameplay(game, garden_scope, func():
		game.progress.knowledge = 30
		game.progress.add_parts(Parts.THORN, 44)
		game.progress.add_parts(Parts.HOOK, 15)
		game.seed_reserve(player).stock[0] = 2)
	game.run_heart_save(func():
		return game.progress.heart.start(game.progress, "plot_4"))
	game.run_heart_save(func():
		return game.progress.heart.add_work(game.progress, 60.0))
	check(game.progress.heart.has("plot_4") and game.progress.plots.size() == 3,
		"real research unlocks a bed without placing it")
	game.run_heart_save(func():
		return game.progress.heart.start(game.progress, "clearing_1"))
	game.run_heart_save(func():
		return game.progress.heart.add_work(game.progress, 60.0))
	check(game.progress.heart.has("clearing_1") and garden.state.revision == 0, "research grants growth without spending energy or placing land")
	var place := Vector2(2.34, -4.58)
	var built: bool = garden.place("bed", place, 0.37)
	check(built and game.progress.plots.size() == 4, "placed bed receives a real production plot")
	if not built:
		printerr("FAIL: placement reason ", game.status)
		call("quit", 1)
		return
	player.pos = game.stage.bed_position(3) + Vector3(0, 0, 1.43)
	check(game.nearby_plot(player.pos) == 3 and game.plant_seed(game.HOST, 3), "real seed plants in the movable bed")
	game.Transactions.run_gameplay(game, garden_scope, func(): game.progress.advance_growth(MATURE, false))
	check(game.progress.plots[3].stage == 3 and game.harvest(game.HOST, 3), "real crop matures and returns plant parts")
	check(game.plant_seed(game.HOST, 3), "replant for preservation checks")
	await _capture("cultivation")
	player.pos = Vector3(0, 0, 1.5)
	player.prepared = Parts.THORN
	garden.open_offerings()
	var plant := Items.part_id(Parts.THORN)
	var monster := Items.part_id(Parts.HOOK)
	var before: int = game.progress.part_count(Parts.THORN)
	var reserved: Dictionary = garden.funds.quote({plant: before})
	check(reserved.is_empty(), "loadout reservation is excluded from offering")
	var quote: Dictionary = garden.funds.quote({plant: 32, monster: 12})
	check(garden.contribute(quote) and not garden.contribute(quote)
		and game.progress.part_count(Parts.THORN) == before - 32, "mixed parts debit via the guarded Garden with replay refusal")
	garden.offering_dialog.hide()
	for iteration in 2:
		garden.open_development()
		if garden.plans.is_empty():
			check(false, "eligible paid frontiers exist")
			break
		var id: int = garden.plans.keys()[0]
		var before_energy: int = garden.funds.energy
		var cost: int = garden.funds.expansion_cost(garden.plans[id], garden.state.reclaimed_cells, 1)
		check(garden.expand(id) and not garden.expand(id) and garden.funds.energy == before_energy - cost,
			"one paid expansion and one exact debit")
		garden.development_dialog.hide()
		if garden.reveal != null:
			garden.reveal.custom_step(3.0)
		await process_frame
	check(garden.state.revision == 2 and garden.network.size() == 2 and garden.state.entrance_clear(), "connected growth preserves the Gate and root network")
	var stable_id: int = garden.bed_ids[3]
	var planted: int = game.progress.plots[3].species
	var relocation := Vector2.INF
	for offset: Vector2 in [Vector2(0.25, 0), Vector2(-0.25, 0), Vector2(0, 0.3), Vector2(0, -0.4)]:
		if garden._build_refusal("bed", place + offset, 0.37, stable_id).is_empty():
			relocation = place + offset
			break
	check(relocation.is_finite() and garden.place("bed", relocation, 0.37, stable_id) and game.progress.plots[3].species == planted,
		"relocation preserves the real bed identity and crop")
	await _capture("garden-after-growth")

	player.pos = game.stage.gate_position()
	game.map_rng.seed = 241
	game.PartyTravel.request(game, game.HOST, "depart")
	for ignored in 3:
		await process_frame
	check(player.wild and game.battlefield is Field and not game.battlefield.generated.is_empty(),
		"production Gate enters the generated floor through guarded travel")
	if not player.wild or not game.battlefield is Field or game.battlefield.generated.is_empty():
		call("quit", 1)
		return
	var field: Field = game.battlefield
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_B
	shortcut.pressed = true
	game._unhandled_key_input(shortcut)
	check(not garden.development_dialog.visible, "Garden shortcut leaves Wilds weapon input available")
	check(game.exploration.fog.visible and not game.exploration.seen(field.advance), "exit starts obscured by production fog")
	check(not game.encounter_cleared() and not game.stage.wild_portal.visible and game.enemy_hp > 0, "real enemies seal the Gate")
	var route := field.navigation_graph.route(field.planar(field.entry), field.planar(field.leader))
	check(not route.is_empty(), "entry reaches real encounter position")
	for ignored in 3:
		await process_frame
	await _capture("wilds")
	var old_enemy: Vector3 = game.enemy_pos
	var goal := field.navigate(old_enemy, field.entry, 0.18, 1000)
	check(goal != old_enemy and not field.occupied(goal, Field.Navigation.RADIUS), "bounded pursuit follows continuous clearance")
	# Exercise actual hit and reward services with a decisive test hit for each spawned enemy.
	for target in range(-1, game.scouts.size()):
		if (game.enemy_hp if target == -1 else int(game.scouts[target].hp)) <= 0:
			continue
		player.pos = game.enemy_position(target) + Vector3(0.1, 0, 0)
		var stats: Dictionary = game.weapon_stats(player)
		stats.damage = 10000
		var kind: int = game.enemy_kind if target == -1 else game.scouts[target].kind
		var mask: int = game.enemy_mutations if target == -1 else game.scouts[target].mutations
		for seed_value in range(1, 40):
			game.rng.seed = seed_value
			var before_roll: int = game.rng.state
			if not game.roll_kill_trophy(kind, mask, target == -1).is_empty():
				game.rng.state = before_roll
				break
		game.apply_weapon_hit(player, target, player.pos, stats, Time.get_ticks_msec())
	var rewarded: bool = game.MonsterRewards.flush(game)
	for ignored in 3:
		await process_frame
	check(rewarded and game.encounter_cleared() and game.stage.wild_portal.visible, "real kills settle and activate the Gate")
	check(not game.wild_item_drops.is_empty() and Items.get_item(game.wild_item_drops[0].stack.item).category == "monster_part",
		"real enemy-specific part drops use the production item catalog")
	await _capture("cleared-gate")
	player.pos = field.advance
	game.use_checkpoint(game.HOST, true)
	await process_frame
	check(game.depth == 2 and game.battlefield is Field and not game.battlefield.generated.is_empty(), "the real Gate advances to another generated floor")
	game.abandon_run(game.HOST, player)
	await process_frame
	check(not player.wild and garden.state.revision == 2 and garden.bed_ids[3] == stable_id
		and game.progress.plots[3].species == planted and garden.barrier.walkable(garden.planar(player.pos)),
		"production return retains the session Garden and crop")
	var samples := 0
	var query_peak := field.query_peak_usec
	var route_failures := field.query_failures
	for spec: Array in [[game.Campaign.GROVE, 5, 241], [game.Campaign.MIRE, 1, 517],
			[game.Campaign.MIRE, 6, 241], [game.Campaign.HOLLOW, 2, 823], [game.Campaign.HOLLOW, 3, 517]]:
		var site: int = spec[0]
		var sample := Field.new()
		sample.configure(site, spec[1], spec[2])
		check(not sample.generated.is_empty() and sample.generated.climate.biome == site and sample.connected(), "biome and transition floor connects %s" % [spec])
		if sample.generated.is_empty():
			continue
		samples += 1
		for room: Vector3 in sample.spawn_points:
			sample.retry_at = 0
			var next := sample.navigate(room, sample.entry, 0.15, samples)
			check(next != room and not sample.occupied(next, Field.Navigation.RADIUS), "pursuit uses usable continuous space")
			samples += 1
		query_peak = maxi(query_peak, sample.query_peak_usec)
		route_failures += sample.query_failures
	var lair := Field.new()
	lair.configure(0, 6, 241, 20, 0)
	check(lair.generated.is_empty() and lair.boss_kind == 20 and lair.connected(), "boss uses its existing handcrafted lair")
	print("M17_ROUTE peak_usec=", query_peak, " failures=", route_failures, " cases=", samples)
	game.return_to_main_menu()
	await process_frame
	check(current_scene != game and current_scene.continue_button.disabled, "return to title separates transient Garden layout")
	if errors == 0:
		print("PASS: title, real cultivation, offerings, repeatable growth, generated combat, Gate and Garden return")
	call("quit", int(errors > 0))

func _capture(label: String) -> void:
	if screenshots.is_empty():
		return
	for frame in 6:
		await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots.path_join(label + ".png")) == OK, "saved " + label)

func _run_child() -> void:
	var folder := "mg-terrain-" + Crypto.new().generate_random_bytes(16).hex_encode()
	var isolated := OS.get_environment("TEMP").path_join(folder)
	DirAccess.make_dir_recursive_absolute(isolated)
	var marker := FileAccess.open(isolated.path_join("terrain-session.marker"), FileAccess.WRITE)
	marker.store_string(folder)
	marker.close()
	var env := {"APPDATA": OS.get_environment("APPDATA"), "LOCALAPPDATA": OS.get_environment("LOCALAPPDATA"),
		"MYSTICAL_TERRAIN_PROFILE": OS.get_environment("MYSTICAL_TERRAIN_PROFILE")}
	var output: Array = []
	var source: String = get_script().resource_path
	if source.begins_with("res://"):
		source = ProjectSettings.globalize_path(source)
	var project := ProjectSettings.globalize_path("res://")
	var launch := ["--headless", "--path", project, "--log-file", isolated.path_join("engine.log"),
		"--script", source, "--quit-after", "1200", "--", Mode.FLAG]
	var untrusted := OS.execute(OS.get_executable_path(), launch + ["unsafe"], output, true, false)
	for line in output:
		print(line)
	check(untrusted == 0 and "PASS: unsafe profile refused before saves" in "".join(output), "unverified profile fails closed")
	output.clear()
	for key in env:
		OS.set_environment(key, isolated)
	var exit_code := OS.execute(OS.get_executable_path(), launch, output, true, false)
	for key in env:
		OS.set_environment(key, env[key])
	var log := "".join(output)
	print(log)
	check(exit_code == 0 and "PASS: title, real cultivation" in log, "guarded experimental game finishes")
	if errors == 0: print("PASS: source game entry and isolated terrain loop")
	quit(int(errors > 0))
