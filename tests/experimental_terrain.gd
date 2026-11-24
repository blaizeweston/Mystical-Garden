extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")
const Placement = preload("res://tests/support/garden_placement_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Mode = preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Field = preload("res://battlefield.gd")
const Parts = preload("res://weapon_parts.gd")
const Items = preload("res://item_catalog.gd")
const Menu = preload("res://main_menu.tscn")
const Appearance = preload("res://character_appearance.gd")
const GardenInteractions = preload("res://garden_interaction_service.gd")
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
	game.set_physics_process(false) # Step the existing gameplay clock deterministically in this fixture.
	var garden = game.stage.experimental_garden
	var player: Dictionary = game.players[game.HOST]
	check(garden != null and game.slot_claimed and game.character_slot_claimed and game.persistence_session.owns_leases(),
		"real world shows terrain with the native owner")
	check(UIFixture.control(game,"host_button").visible and game.session_world.join() == ERR_UNAUTHORIZED, "co-op uses title-owned guest admission")
	game._process(0.016) # The old Stage heartbeat used to reveal a hidden second Heart here.
	check(game.stage.heart_tree==garden.heart and garden.heart.sculpt_only and garden.heart.models.is_empty()
		and game.stage.find_children("HeartForm","Node3D",true,false).is_empty(), "regular scene updates retain only the imported Heart")
	check(garden.barrier.get_child_count()==0 and garden.forest.inspection().full_tree_instances>0,
		"complete forest trees replace the flat rendered barrier without replacing movement rules")
	check(garden.barrier.walkable(garden.planar(player.pos)), "production avatar starts on clear ground")
	var view := game.get_node("GardenInteractions")
	var scar := GardenInteractions.Catalog.point("heart_root_scar")
	var spring := GardenInteractions.Catalog.point("spring_water")
	view._process(0.0)
	check(not view.points[scar.id].visible and not game.garden_commands.allowed(scar),
		"the experimental Root Scar is hidden and unavailable before Reaching Roots")
	check(not view.points[spring.id].visible and not garden.structure_nodes.has("spring")
		and not garden.state.landmarks.has("spring") and not game.stage.station_position("spring").is_finite(),
		"there is no starter watering basin or reserved invisible footprint")
	var start: Vector3 = player.pos
	game.move_player(game.HOST, Vector2.RIGHT, 0.12)
	check(player.pos != start, "production movement advances on the experimental Garden")
	game.move_player(game.HOST, Vector2.RIGHT, 8.0)
	check(garden.barrier.walkable(garden.planar(player.pos)), "movement stays inside the visible forest barrier")
	player.pos = Vector3(0, 0, 1.5)
	game.stage.update_plots(game.progress.plots)
	check(game.stage.garden_beds.get_child_count() == 3, "starter beds rendered")
	for bed in game.stage.garden_beds.get_children():
		check(bed is MeshInstance3D and bed.mesh == garden.bed_mesh and bed.get_child_count() == 1
			and bed.get_child(0) is Label3D, "empty starter bed uses the rooted mesh with no crop decoration")
	await _capture("garden")
	# Seed only this disposable profile. Research uses the real catalog, timer and serializers.
	var garden_scope: int = game.Transactions.Scope.GARDEN
	game.Transactions.run_gameplay(game, garden_scope, func():
		game.progress.add_parts(Parts.THORN, 60)
		game.progress.add_parts(Parts.HOOK, 15)
		game.seed_reserve(player).stock[0] = 2)
	var plant := Items.part_id(Parts.THORN)
	var monster := Items.part_id(Parts.HOOK)
	garden.open_offerings()
	var panel = garden.offering_dialog
	var initial_parts: int = game.progress.part_count(Parts.THORN)
	var initial_knowledge: int = game.progress.knowledge
	check(garden.funds.quote({plant: initial_parts + 1}).is_empty(), "insufficient inventory cannot be confirmed")
	var initial_quote: Dictionary = garden.funds.quote({plant: 8})
	select_offering(panel, plant, 8)
	check(panel.status.text.contains("+8 Knowledge"), "panel quotes immediate Knowledge")
	panel.confirm_offer.pressed.emit()
	check(game.progress.part_count(Parts.THORN) == initial_parts - 8 and garden.funds.energy == initial_quote.energy
		and game.progress.knowledge == initial_knowledge + 8,
		"confirmed materials and both currency rewards apply once")
	check(not garden.contribute(initial_quote), "confirmed offering cannot be replayed")
	paused = true
	game.growth_clock = 1.0
	game.set_physics_process(true)
	for frame in 3:
		await physics_frame
	game.set_physics_process(false)
	paused = false
	check(game.growth_clock == 1.0, "paused world consumes no gameplay clock")
	game.growth_clock = 0.99
	game.set_physics_process(true)
	for frame in 4:
		await physics_frame
	game.set_physics_process(false)
	if DisplayServer.get_name() == "headless":
		var bytes := FileAccess.get_file_as_bytes(game.progress.path)
		var energy_before: int = garden.funds.energy
		game.set_meta(&"guarded_gameplay_test_fault", func(phase, _path): return ERR_CANT_CREATE if phase == "stage" else OK)
		check(not garden.contribute(garden.funds.quote({plant: 1})), "failed contribution refused")
		game.remove_meta(&"guarded_gameplay_test_fault")
		check(game.progress.knowledge == initial_knowledge + 8 and garden.funds.energy == energy_before
			and game.progress.part_count(Parts.THORN) == initial_parts - 8 and FileAccess.get_file_as_bytes(game.progress.path) == bytes,
			"aborted contribution restores inventory, both balances and Garden bytes")
	panel.hide()
	garden.open_development()
	var build_choices: OptionButton = garden.construction_kind
	check(build_choices.item_count == garden.Build.CATALOG.size() and garden.build_button.disabled,
		"no new structure can be selected at the start")
	for index in range(1, build_choices.item_count):
		check(build_choices.is_item_disabled(index) and build_choices.get_item_tooltip(index).begins_with("Research "),
			"every locked building is disabled and identifies its research")
	garden.begin_placement("bed")
	check(garden.development_dialog.visible and garden.build_kind.is_empty() and garden.ghost == null,
		"a stale request for a locked bed keeps the dialog open without starting placement")
	garden.development_dialog.hide()
	var available_before: int = game.progress.heart.available_insight(game.progress)
	game.run_heart_save(func():
		return game.progress.heart.purchase(game.progress, "plot_4"))
	check(game.progress.heart.has("plot_4") and game.progress.plots.size() == 3,
		"real research unlocks a bed without placing it")
	check(game.progress.heart.available_insight(game.progress) == available_before - 2,
		"existing research spends the Knowledge earned through contributions")
	game.run_heart_save(func():
		return game.progress.heart.purchase(game.progress, "clearing_1"))
	check(game.progress.heart.has("clearing_1") and garden.state.reclaimed_cells == 0, "research grants permission without paid reclamation")
	view._process(0.0)
	check(view.points[scar.id].visible and game.garden_commands.allowed(scar),
		"Reaching Roots reveals the original journal observation")
	var place := Placement.find(garden.construction, "bed", Vector2(2.34, -4.58), 0.37, garden.planar(game.players[1].pos))
	check(place.is_finite(), "new bed fits beyond the fully grown Heart")
	for cancel_with_mouse: bool in [false, true]:
		garden.open_development()
		check(build_choices.get_selected_metadata() == "bed" and not garden.build_button.disabled,
			"research enables the bed in the picker")
		garden.build_button.pressed.emit()
		await process_frame
		var motion := InputEventMouseMotion.new()
		motion.position = game.stage.camera.unproject_position(garden.world(place))
		root.push_input(motion, true)
		check(garden.build_kind == "bed" and garden.ghost != null,
			"starting placement creates a preview on pointer motion")
		var cancel: InputEvent
		if cancel_with_mouse:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_RIGHT
			click.position = motion.position
			click.pressed = true
			cancel = click
		else:
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.physical_keycode = KEY_ESCAPE
			escape.pressed = true
			cancel = escape
		root.push_input(cancel, true)
		check(garden.build_kind.is_empty() and garden.ghost == null and not game.ui.is_overlay_open()
			and game.progress.plots.size() == 3 and game.status == "Placement cancelled.",
			"cancel clears the ghost without opening the session menu or placing a bed")
	var menu_key := InputEventKey.new()
	menu_key.keycode = KEY_ESCAPE
	menu_key.physical_keycode = KEY_ESCAPE
	menu_key.pressed = true
	root.push_input(menu_key, true)
	check(game.ui.is_overlay_open(), "Escape still opens the session menu outside placement")
	root.push_input(menu_key, true)
	check(not game.ui.is_overlay_open(), "Escape closes the session menu outside placement")
	var built: bool = garden.place("bed", place, 0.37)
	check(built and game.progress.plots.size() == 4, "placed bed receives a real production plot")
	if not built:
		printerr("FAIL: placement reason ", game.status)
		call("quit", 1)
		return
	garden.open_development()
	check(garden.build_button.disabled and build_choices.is_item_disabled(1)
		and build_choices.get_item_tooltip(1) == "All researched bed spaces are used.",
		"the picker disables another bed once the researched capacity is used")
	garden.development_dialog.hide()
	player.pos = game.stage.bed_position(3) + Vector3(0, 0, 1.43)
	check(game.nearby_plot(player.pos) == 3 and game.cultivation.plant_seed(game.HOST, 3), "real seed plants in the movable bed")
	game.Transactions.run_gameplay(game, garden_scope, func(): game.progress.advance_growth(MATURE, false))
	check(game.progress.plots[3].stage == 3 and game.cultivation.harvest(game.HOST, 3), "real crop matures and returns plant parts")
	check(game.cultivation.plant_seed(game.HOST, 3), "replant for preservation checks")
	game.stage.update_plots(game.progress.plots)
	var plot: MeshInstance3D = game.stage.garden_beds.get_child(3)
	check(plot.mesh == garden.bed_mesh and plot.position.is_equal_approx(game.stage.bed_position(3))
		and is_equal_approx(plot.rotation.y, -0.37) and plot.get_child_count() == 2,
		"planted bed uses the starter mesh at the selected orientation")
	check(plot.get_child(0).position.is_equal_approx(Vector3.UP * garden.Stations.BED_SOIL_HEIGHT),
		"real crop is attached at the model's soil height")
	await _capture("cultivation")
	player.pos = Vector3(0, 0, 1.5)
	player.prepared = Parts.THORN
	garden.open_offerings()
	var before: int = game.progress.part_count(Parts.THORN)
	var reserved: Dictionary = garden.funds.quote({plant: before})
	check(reserved.is_empty(), "loadout reservation is excluded from offering")
	var quote: Dictionary = garden.funds.quote({plant: 32, monster: 12})
	var monster_before: int = game.progress.part_count(Parts.HOOK)
	check(garden.contribute(quote) and not garden.contribute(quote) and game.progress.part_count(Parts.THORN) == before - 32
		and game.progress.part_count(Parts.HOOK) == monster_before - 12, "mixed guarded offering debits both parts once")
	check(garden.contribute(garden.funds.quote({plant: 2})), "next valid contribution succeeds")
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
	check(garden.network.size() == 2 and garden.state.entrance_clear(), "connected growth preserves the Gate and root network")
	var stable_id: int = garden.bed_ids[3]
	var planted: int = game.progress.plots[3].species
	var relocation := Vector2.INF
	for offset: Vector2 in [Vector2(0.25, 0), Vector2(-0.25, 0), Vector2(0, 0.3), Vector2(0, -0.4)]:
		if garden._build_refusal("bed", place + offset, 0.37, stable_id).is_empty():
			relocation = place + offset
			break
	check(relocation.is_finite() and garden.place("bed", relocation, 0.37, stable_id) and game.progress.plots[3].species == planted,
		"relocation preserves the real bed identity and crop")
	game.stage.update_plots(game.progress.plots)
	plot = game.stage.garden_beds.get_child(3)
	check(plot.mesh == garden.bed_mesh and plot.position.is_equal_approx(game.stage.bed_position(3))
		and plot.get_child_count() == 2, "bed and crop render together after relocation")
	await _capture("garden-after-growth")

	game.run_heart_save(func(): return game.progress.heart.purchase(game.progress, "flowering"))
	check(game.progress.flowering_unlocked, "Flowering is usable immediately")
	player.pos = game.stage.gate_position()
	var starting_tree = game.Classes.connected_tree(int(player.frame))
	game.handle_loadout_action(game.HOST, player, "learn_%d_%d" % [player.frame, starting_tree.REQUEST_OFFSET])
	check(starting_tree.focus(player.character) == "vanguard", "the fresh Warden explicitly selects its free starting focus before departure")
	game.map_rng.seed = 16 # The second floor has an off-route cache.
	game.PartyTravel.request(game, game.HOST, "depart")
	for ignored in 3:
		await process_frame
	check(ExpeditionCase.is_wild(player) and game.battlefield is Field and not game.battlefield.generated.is_empty(),
		"production Gate enters the generated floor through guarded travel")
	if not ExpeditionCase.is_wild(player) or not game.battlefield is Field or game.battlefield.generated.is_empty():
		call("quit", 1)
		return
	var field: Field = game.battlefield
	check(not field.has_seed_cache() and not game.stage.seed_cache.visible and not WorldViewCase.component(game,"map").has_cache,
		"a floor without a cache has neither a prop nor a map marker")
	check(field.entry.distance_to(field.advance) > WorldViewCase.component(game,"map").SIGHT
		and not game.stage.experimental_exit.is_visible_in_tree()
		and not game.stage.deeper_gate.is_visible_in_tree(),
		"arrival is separated from the Gate and its marker stays hidden under unexplored fog")
	check(field.can_spawn(game.tactics.position) and game.encounter.scout_tactics().all(func(scout): return field.can_spawn(scout.pos)),
		"every live enemy is admitted to certified continuous terrain")
	step_progress(game, 1.0)
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_B
	shortcut.pressed = true
	game._unhandled_key_input(shortcut)
	check(not garden.development_dialog.visible, "Garden shortcut leaves Wilds weapon input available")
	check(WorldViewCase.component(game,"map").fog.visible and not WorldViewCase.component(game,"map").seen(field.advance), "exit starts obscured by production fog")
	check(not game.encounter_cleared() and not game.stage.wild_portal.visible and game.enemy_health() > 0, "real enemies seal the Gate")
	var route := field.navigation_graph.route(field.planar(field.entry), field.planar(field.leader))
	check(not route.is_empty(), "entry reaches real encounter position")
	for ignored in 3:
		await process_frame
	await _capture("wilds")
	var old_enemy: Vector3 = game.tactics.position
	var goal := field.navigate(old_enemy, field.entry, 0.18, 1000)
	check(goal != old_enemy and not field.occupied(goal, Field.Navigation.RADIUS), "bounded pursuit follows continuous clearance")
	var garden_path: String = game.progress.path
	var profile_path: String = game.local_character.path
	var floor_before := save_digests(garden_path, profile_path)
	var xp_before := class_xp(player)
	var kills_before := kill_count(player)
	var wallet_before = game.wallet_for(player)
	var essence_before: int = wallet_before.earned_sparks()
	# Exercise actual hit and reward services with a decisive test hit for each spawned enemy.
	for target in range(-1, game.encounter.scout_count()):
		if (game.enemy_health() if target == -1 else int(game.encounter.hp(target))) <= 0:
			continue
		player.pos = game.enemy_position(target) + Vector3(0.1, 0, 0)
		var stats: Dictionary = game.weapon_stats(player)
		stats.damage = 10000
		var kind: int = game.enemy_kind if target == -1 else game.encounter.scout(target).kind
		var mask: int = game.enemy_mutations if target == -1 else game.encounter.scout(target).mutations
		for seed_value in range(1, 40):
			game.rng.seed = seed_value
			var before_roll: int = game.rng.state
			if not game.roll_kill_trophy(kind, mask, target == -1).is_empty():
				game.rng.state = before_roll
				break
		OutgoingHits.hit_world(game, HitSession.peer_for(player), target, player.pos, stats, Time.get_ticks_msec())
		if target == -1:
			var frozen: Array = game.monster_rewards.pending_receipts()
			var drops: Array = game.wild_item_drops.duplicate(true)
			var rng_state: int = game.rng.state
			var leader_wallet = game.wallet_for(player)
			game.record_enemy_death(target, game.tactics.position, player.pos)
			check(game.monster_rewards.pending_receipts() == frozen and game.wild_item_drops == drops and game.rng.state == rng_state
				and game.wallet_for(player) == leader_wallet,
				"a duplicate death cannot reroll or grant rewards twice")
			check(frozen.size() == 1 and frozen[0].run_rewards_granted
				and game.monster_rewards.status(frozen[0].key) == game.MonsterRewards.Phase.PENDING
				and not game.encounter_cleared() and leader_wallet.earned_sparks() > essence_before
				and wallet_before.earned_sparks() == essence_before and not drops.is_empty(),
				"Essence and collectible drops appear before the floor clears")
			check(game.flush_kill_rewards() and game.monster_rewards.pending_receipts() == frozen
				and save_digests(garden_path, profile_path) == floor_before
				and class_xp(player) == xp_before and kill_count(player) == kills_before,
				"the mid-floor flush leaves XP and kill counts pending without changing save bytes")
	var expected_xp := xp_before + queued_xp(game)
	var expected_kills: int = kills_before + game.monster_rewards.pending_count()
	var expected_drops: Array = game.wild_item_drops.duplicate(true)
	var expected_wallet = game.wallet_for(player)
	var before_clear_balance: int = game.run_wallet(player)
	if DisplayServer.get_name() == "headless":
		var saved_tally: Array = game.monster_rewards.pending_receipts()
		game.set_meta(&"guarded_gameplay_test_fault", func(phase: String, _path: String):
			return ERR_CANT_CREATE if phase == "stage" else OK)
		game.finish_combat(game.HOST, game.tactics.position)
		game.remove_meta(&"guarded_gameplay_test_fault")
		check(not game.encounter_rewarded and game.monster_rewards.pending_receipts() == saved_tally
			and save_digests(garden_path, profile_path) == floor_before and class_xp(player) == xp_before
			and game.wallet_for(player) == expected_wallet and game.run_wallet(player) == before_clear_balance
			and game.wild_item_drops == expected_drops,
			"verified settlement abort restores the tally without rerolling or revoking live loot")
	var carried_before: int = player.carried_seeds.size()
	var rewarded: bool = game.flush_kill_rewards()
	game.finish_combat(game.HOST, game.tactics.position)
	check(game.encounter_rewarded, "the guarded combat settlement authorizes Gate progression")
	check(game.monster_rewards.pending_count()==0 and class_xp(player) == expected_xp
		and kill_count(player) == expected_kills and game.wallet_for(player) == expected_wallet
		and game.run_wallet(player) == before_clear_balance + 2 and game.wild_item_drops == expected_drops
		and save_digests(garden_path, profile_path) != floor_before,
		"floor clear adds the shared milestone and commits XP without repeating kill Essence or drops")
	var clear_digests := save_digests(garden_path, profile_path)
	game.finish_combat(game.HOST, game.tactics.position)
	check(save_digests(garden_path, profile_path) == clear_digests and class_xp(player) == expected_xp
		and game.wallet_for(player) == expected_wallet and game.run_wallet(player) == before_clear_balance + 2,
		"duplicate floor completion cannot commit the tally twice")
	for ignored in 3:
		await process_frame
	check(rewarded and game.encounter_cleared() and game.stage.wild_portal.visible, "real kills settle and activate the Gate")
	check(player.carried_seeds.size() == carried_before, "ordinary clear and duplicate settlement never award a seed")
	check(not game.wild_item_drops.is_empty() and Items.get_item(game.wild_item_drops[0].stack.item).category == "monster_part",
		"real enemy-specific part drops use the production item catalog")
	await _capture("cleared-gate")
	var drop: Dictionary = game.wild_item_drops[0]
	var trophy: String = drop.stack.item
	player.pos = Vector3(drop.position[0], drop.position[1], drop.position[2])
	game.pickup_inventory_drop(game.HOST, player, drop.id)
	transfer_part(game, player, trophy, "carry", "pouch")
	check(not player.safe_items.is_empty() and player.safe_items[0].item == trophy, "real monster drop fits in safe pouch")
	player.pos = field.advance
	game.expedition_transitions.checkpoint(game.HOST,true)
	await process_frame
	await process_frame
	check(game.participation.depth() == 2 and game.battlefield is Field and not game.battlefield.generated.is_empty(), "the real Gate advances to another generated floor")
	var next_field: Field = game.battlefield
	check(next_field.entry.distance_to(Vector3(player.pos)) < 1.2
		and next_field.entry.distance_to(next_field.advance) > WorldViewCase.component(game,"map").SIGHT
		and game.enemy_health() > 0 and game.encounter.scout_count()>0 and not game.encounter_cleared()
		and (game.stage.experimental_exit.global_position - game.Stage.WILD_OFFSET).is_equal_approx(next_field.advance)
		and not game.stage.deeper_gate.is_visible_in_tree() and not game.stage.wild_portal.visible,
		"new floor spawns a live encounter and its own distant, sealed Gate")
	check(next_field.has_seed_cache() and not game.stage.seed_cache.visible and not WorldViewCase.component(game,"map").seen(next_field.cache)
		and next_field._cache_site_clear(next_field.cache)
		and not next_field.navigation_graph.route(next_field.planar(next_field.entry), next_field.planar(next_field.cache)).is_empty(),
		"an undiscovered cache stays hidden in reachable space away from the Gate and arrival")
	player.pos = next_field.cache
	await process_frame
	await process_frame
	check(game.stage.seed_cache.visible and WorldViewCase.component(game,"map").has_cache and WorldViewCase.component(game,"map").seen(next_field.cache),
		"the actual cache prop and map marker appear when discovered")
	carried_before = player.carried_seeds.size()
	game.act(game.HOST, false)
	game.act(game.HOST, false)
	await process_frame
	await process_frame
	check(player.cache_claimed and player.carried_seeds.size() == carried_before + 1 and not WorldViewCase.component(game,"map").has_cache,
		"the cache interaction grants one carried seed once and removes its map marker")
	step_progress(game, 1.0)
	player.pos = Vector3(game.tactics.position) + Vector3(0.1, 0, 0)
	var last_hit: Dictionary = game.weapon_stats(player)
	last_hit.damage = 10000
	OutgoingHits.hit_world(game, HitSession.peer_for(player), -1, player.pos, last_hit, Time.get_ticks_msec())
	var loss_xp := class_xp(player) + queued_xp(game)
	var loss_kills: int = kill_count(player) + game.monster_rewards.pending_count()
	check(not game.encounter_cleared() and game.monster_rewards.pending_count()>0,
		"the next floor has pending XP before the run ends")
	IncomingPlayerHit.apply_health_loss(game, game.HOST, PlayerLifecycle.generation(player), int(PlayerVitals.current_hp(player)))
	await process_frame
	check(game.monster_rewards.pending_count()==0 and class_xp(player) == loss_xp and kill_count(player) == loss_kills,
		"losing the run commits the partial floor's tally")
	var stored_profile = game.Character.new()
	stored_profile.path = profile_path
	check(stored_profile.load_profile(false) == OK and stored_profile.data.xp == player.character.xp
		and stored_profile.data.monsters == player.character.monsters,
		"the loss settlement persisted exact XP and kill counts")
	check(not ExpeditionCase.is_wild(player) and garden.network.size() == 2 and garden.bed_ids[3] == stable_id
		and game.progress.plots[3].species == planted and garden.barrier.walkable(garden.planar(player.pos)),
		"production return retains the session Garden and crop")
	step_progress(game, 1.0)
	var trophy_part: int = Items.get_item(trophy).legacy_part
	var shared_before: int = game.progress.part_count(trophy_part)
	transfer_part(game, player, trophy, "stash", "shared")
	check(game.progress.part_count(trophy_part) == shared_before + 1, "recovered monster part moves to shared storage")
	player.pos = Vector3(0, 0, 1.5)
	garden.open_offerings()
	var expected: int = garden.funds.quote({trophy: 1}).knowledge
	var knowledge_before: int = game.progress.knowledge
	select_offering(panel, trophy, 1)
	panel.confirm_offer.pressed.emit()
	var cfg := ConfigFile.new()
	check(game.progress.part_count(trophy_part) == shared_before and game.progress.knowledge == knowledge_before + expected
		and cfg.load(game.progress.path) == OK and cfg.get_value("garden", "knowledge") == knowledge_before + expected,
		"actual monster drop pays its Knowledge immediately and durably")
	panel.hide()
	var after_contribution: int = game.progress.heart.available_insight(game.progress)
	game.run_heart_save(func(): return game.progress.heart.purchase(game.progress, "plot_5"))
	check(game.progress.heart.has("plot_5") and game.progress.plots.size() == 4
		and game.progress.heart.available_insight(game.progress) == after_contribution - 3,
		"Contributed Knowledge funds the next existing bed research without automatic placement")
	garden.open_development()
	if not garden.plans.is_empty():
		check(garden.expand(garden.plans.keys()[0]), "energy still funds player-chosen expansion after return")
		if garden.reveal != null:
			garden.reveal.custom_step(3.0)
	garden.development_dialog.hide()
	check(garden.network.size() == 3 and garden.state.entrance_clear() and garden.bed_ids[3] == stable_id
		and game.progress.plots[3].species == planted, "further growth preserves ownership, Gate and cultivation")
	game.run_heart_save(func(): return game.progress.heart.purchase(game.progress, "irrigation"))
	var bank:=preload("res://garden_water.gd").anchor(game.stage)
	player.pos=bank;view._process(0.0)
	check(game.progress.heart.has("irrigation") and bank.is_finite() and garden.barrier.walkable(garden.planar(bank))
		and game.garden_commands.allowed(spring) and game.cultivation.spring_ready()
		and game.cultivation.fill_water(game.HOST) and player.get("spring_water",false),
		"Root Irrigation unlocks a dry bank of existing Garden water without basin construction")
	check(not garden.Build.CATALOG.has("spring") and not garden._placement_refusal("spring",0).is_empty()
		and not garden.place("spring",Vector2.ZERO,0.0),"retired basin requests cannot place a hidden fixture")
	check(not game.stage.garden_edge.has_node("DormantSpringSite") and not game.stage.garden_edge.has_node("ShelteredSpring"),"neither old spring fixture is present")
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
	check(lair.generated.layout.layout_kind == "boss_lair" and lair.boss_kind == 20 and lair.connected(), "boss preserves its authored lair on the modern terrain pipeline")
	check(not lair.has_seed_cache() and lair.generate_flora(6).is_empty(), "boss ambient seed rewards stay separate from authored rewards")
	var repeat := Field.new()
	repeat.configure(game.Campaign.GROVE, 2, 91301383)
	check(repeat.has_seed_cache() and repeat.cache.is_equal_approx(next_field.cache)
		and repeat.generate_flora(2) == next_field.generate_flora(2), "the same floor seed reproduces cache and flora placement")
	var miss := Field.new()
	miss.configure(game.Campaign.GROVE, 1, 1095491782)
	check(not miss.has_seed_cache(), "this floor has no ordinary mystery seed cache")
	print("M17_ROUTE peak_usec=", query_peak, " failures=", route_failures, " cases=", samples)
	game.return_to_main_menu()
	await process_frame
	check(current_scene != game and current_scene.continue_button.disabled, "isolated title keeps normal production save browsing disabled")
	if errors == 0:
		print("PASS: title, real cultivation, offerings, repeatable growth, generated combat, Gate and Garden return")
	call("quit", int(errors > 0))

func step_progress(game: Node, seconds: float) -> void:
	game.growth_clock = seconds
	game._physics_process(0.0)

func select_offering(panel: Window, id: String, amount: int) -> void:
	for index in panel.list.item_count:
		if panel.list.get_item_metadata(index) == id:
			panel.list.select(index)
			panel.list.item_selected.emit(index)
			panel.quantity.value = amount
			return
	check(false, "eligible part is present in Heart dialog")

func transfer_part(game: Node, player: Dictionary, item: String, source: String, target: String) -> void:
	game.handle_inventory_action(game.HOST, player, JSON.stringify({
		"operation": "transfer", "source": source, "target": target, "item": item, "quantity": 1}))

func _capture(label: String) -> void:
	if screenshots.is_empty():
		return
	for frame in 6:
		await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots.path_join(label + ".png")) == OK, "saved " + label)

func save_digests(garden_path: String, profile_path: String) -> Array[String]:
	return [FileAccess.get_sha256(garden_path), FileAccess.get_sha256(profile_path)]

func class_xp(player: Dictionary) -> int:
	var frame: int = player.frame
	return int(player.character.xp[frame])

func kill_count(player: Dictionary) -> int:
	var count := 0
	for kills: int in player.character.monsters:
		count += kills
	return count

func queued_xp(game: Node) -> int:
	var total := 0
	for kill: Dictionary in game.monster_rewards.pending_receipts():
		for reward: Dictionary in kill.rewards:
			total += int(reward.xp)
	return total

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
