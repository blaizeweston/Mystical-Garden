extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Mode = preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Menu = preload("res://main_menu.tscn")
const Appearance = preload("res://character_appearance.gd")
const Items = preload("res://item_catalog.gd")

const Aim = preload("res://ability_aim.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const RIVER_SEED := 9 # Grove floor 1, map seed 410173068.
const RIVER_FROM := Vector3(3, 0, -17)
const RIVER_TARGET := Vector3(7.8, 0, -17)

var role := ""
var signals := ""
var port := 0
var failed := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	role = OS.get_cmdline_user_args()[0]
	port = int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT"))
	signals = OS.get_environment("MYSTICAL_TERRAIN_TEST_SIGNALS")
	if not check(Mode.verified() and not signals.is_empty() and port > 0, "disposable experimental runtime"):
		quit(1)
		return
	var menu := Menu.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	if role == "host":
		await host_run(menu)
	else:
		await guest_run(menu)
	if not failed:
		print("PASS: experimental terrain co-op ", role)
	quit(int(failed))

func check(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		printerr("FAIL: ", role, " ", message)
	return condition

func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 18000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()

func mark(key: String, value := "ok") -> void:
	var file := FileAccess.open(signals.path_join(key), FileAccess.WRITE)
	if check(file != null, "write synchronization marker " + key):
		file.store_string(value)

func read(key: String) -> String:
	return FileAccess.get_file_as_string(signals.path_join(key))

func floor_identity(field) -> String:
	var layout: Dictionary = field.generated.layout
	return str([field.configured_key, field.entry, field.advance, field.spawn_points,
		layout.water, layout.trail_network, field.ground.projectile_cover, field.has_seed_cache(), field.cache]).sha256_text()

func sees_salvo(events: Array, endpoint: Vector3) -> bool:
	for event in events:
		if event.kind != "subclass_release" or event.shape != "salvo":
			continue
		var end := Vector3(event.to[0], event.to[1], event.to[2])
		if end.is_equal_approx(endpoint):
			return true
	return false

func river_preview(game: Node, archer: Dictionary, field: RefCounted) -> Dictionary:
	var preview := Aim.footprint(game, archer, field, 0, Vector3.RIGHT, 6.0)
	var rays: Array = preview.get("shapes", []).filter(func(shape):return shape.kind == "strip")
	return rays[0] if preview.get("valid", false) and rays.size() == 1 else {}

func river_host(game: Node, archer: Dictionary, key: String) -> bool:
	var field = game.battlefield
	var middle := RIVER_FROM.lerp(RIVER_TARGET, .5)
	if not check(Shape.in_any(field.ground.water,Vector2(middle.x,middle.z))
			and field.occupied(middle) and not field.dash(RIVER_FROM,RIVER_TARGET).is_equal_approx(RIVER_TARGET),
			"river midpoint is actual impassable water"):
		return false
	archer.pos = RIVER_FROM
	game.tactics.position = RIVER_TARGET
	game.tactics.winding_up = false
	game.tactics.stagger_until = Time.get_ticks_msec() + 12000
	for scout in game.encounter.scout_tactics():
		scout.windup = 0
		scout.stagger_until = game.tactics.stagger_until
	var ray := river_preview(game, archer, field)
	if not check(not ray.is_empty(), "host preview recognizes the eligible far-bank target"):
		return false
	var before: int = game.enemy_health()
	mark(key, str(before))
	if not check(await until(func(): return game.enemy_health() < before and sees_salvo(game.combat_events, ray.to)),
			"guest Hunter's Salvo damages the far-bank target and uses the host preview endpoint"):
		return false
	mark(key + "-hp", str(game.enemy_health()))
	return check(await until(func(): return read(key + "-observed") == "ok"),
		"guest reports the authoritative Salvo endpoint and enemy health")

func river_guest(game: Node, id: int, key: String) -> bool:
	var world_id := game.get_instance_id()
	var positions_ready := func() -> bool:
		var world = instance_from_id(world_id)
		return (world != null and not read(key).is_empty() and world.players.has(id)
			and Vector3(world.players[id].pos).is_equal_approx(RIVER_FROM)
			and world.tactics.position.is_equal_approx(RIVER_TARGET)
			and world.players[id].get("skill_ready", false))
	if not check(await until(positions_ready), "guest receives the archer and target positions"):
		return false
	var local: Dictionary = game.players[id]
	var ray := river_preview(game, local, game.stage.visual_field)
	if not check(not ray.is_empty(), "guest aims at the same valid far-bank enemy"):
		return false
	var seen := [false]
	game.send_garden_action(Aim.request(game, local, 0, Vector2.RIGHT, 6.0))
	var observed := func() -> bool:
		var world = instance_from_id(world_id)
		if world == null:
			return false
		seen[0] = seen[0] or sees_salvo(world.guest_combat_events(local), ray.to)
		return seen[0] and not read(key + "-hp").is_empty() and world.enemy_health() == int(read(key + "-hp"))
	if not check(await until(observed), "guest preview, received Salvo and host health agree"):
		return false
	mark(key + "-observed")
	return true

func ready_guest(game: Node) -> int:
	for id in game.players:
		if id != game.HOST and SessionCase.Session.ready_for(game.players[id]):
			return id
	return 0

func host_run(menu: Node) -> void:
	menu.host_port = port
	menu.host_choice.button_pressed = true
	var title_id := menu.get_instance_id()
	menu.new_game()
	menu.create_character("Terrain Keeper", 0, Appearance.DEFAULT)
	if not check(await until(func(): return current_scene.get_instance_id() != title_id and SessionCase.role(current_scene) == "Host"), "host created through title"):
		return
	var game := current_scene
	check(not game.multiplayer.server_relay, "the authoritative host roster does not use the engine peer relay")
	game.network_dialog.dismiss()
	var garden = game.stage.experimental_garden
	var keeper: Dictionary = game.players[game.HOST]
	keeper.pos = Vector3(0, 0, 1.5)
	var part: int = game.Parts.THORN
	var offering: String = Items.part_id(part)
	game.run_heart_save(func():
		game.progress.knowledge = 30
		game.progress.add_parts(part, 60)
		for id in ["plot_4", "clearing_1"]:
			game.progress.heart.start(game.progress, id)
			game.progress.heart.add_work(game.progress, 60.0))
	garden.open_offerings()
	var quote: Dictionary = garden.funds.quote({offering: 16})
	if not check(garden.contribute(quote) and not garden.contribute(quote), "one guarded offering consumes parts once"):
		return
	check(game.progress.part_count(part) == 44, "exact shared part debit")
	garden.offering_dialog.hide()
	if not check(garden.place("bed", Vector2(2.34, -4.58), 0.37), "build a real cultivation bed while hosting"):
		return
	var bed_id: int = garden.bed_ids[3]
	mark("host-ready", str(bed_id))
	if not check(await until(func(): return ready_guest(game) != 0 and read("guest-layout") == "ok"), "guest admitted with the developed layout"):
		return
	var peer := ready_guest(game)
	var traveller: Dictionary = game.players[peer]
	game.Transactions.run_gameplay(game, game.Transactions.Scope.GARDEN, func(): game.seed_reserve(traveller).stock[0] = 1)
	traveller.pos = game.stage.bed_position(3) + Vector3(0, 0, 1.43)
	mark("plant")
	if not check(await until(func(): return game.progress.plots[3].species == 0), "guest plants through production RPC"):
		return
	check(game.seed_reserve(traveller).stock[0] == 0, "guest consumes one seed")
	keeper.pos = game.stage.gate_position()
	traveller.pos = keeper.pos
	for member_id in [game.HOST, peer]:
		var member: Dictionary = game.players[member_id]
		var starting_tree = game.Classes.connected_tree(int(member.frame))
		game.handle_loadout_action(member_id, member, "learn_%d_%d" % [member.frame, starting_tree.REQUEST_OFFSET])
	check(game.Classes.connected_tree(int(keeper.frame)).focus(keeper.character) == "vanguard"
		and game.Classes.connected_tree(int(traveller.frame)).focus(traveller.character) == "wildstalker",
		"the host validates both explicit free starting-focus choices")
	game.map_rng.seed = RIVER_SEED
	game.PartyTravel.request(game, game.HOST, "depart")
	mark("depart", str(game.participation.travel_epoch()))
	if not check(await until(func(): return ExpeditionCase.is_wild(traveller) and not game.battlefield.generated.is_empty()), "party enters generated Wilds"):
		return
	mark("floor", floor_identity(game.battlefield))
	var host_entry: Vector3 = keeper.pos
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		game.move_player(game.HOST, direction, 0.14)
		if keeper.pos.distance_to(host_entry) > 0.2:
			break
	check(keeper.pos.distance_to(host_entry) > 0.2, "host moves on generated terrain")
	var origin: Vector3 = traveller.pos
	var moved_and_stopped := func() -> bool:
		var last_move := int(read("guest-stopped"))
		var ack: Dictionary = game.net_motion.acknowledgement(peer, game.net_motion.world_key(game, traveller))
		return last_move > 0 and int(ack.ack) >= last_move and Vector3(traveller.pos).distance_to(origin) > 0.2
	if not check(await until(moved_and_stopped), "host acknowledges guest movement and release before staging the shot"):
		return
	if not await river_host(game, traveller, "river"):
		return
	var stats: Dictionary = game.weapon_stats(keeper)
	stats.damage = 10000
	for target in range(-1, game.encounter.scout_count()):
		var hit_at: Vector3 = game.tactics.position if target == -1 else game.encounter.scout(target).pos
		var kind: int = game.enemy_kind if target == -1 else game.encounter.scout(target).kind
		var mask: int = game.enemy_mutations if target == -1 else game.encounter.scout(target).mutations
		for seed_value in range(1, 40):
			game.rng.seed = seed_value
			var before_roll: int = game.rng.state
			if not game.roll_kill_trophy(kind, mask, target == -1).is_empty():
				game.rng.state = before_roll
				break
		OutgoingHits.hit_world(game, HitSession.peer_for(keeper), target, hit_at, stats, Time.get_ticks_msec())
	if not check(await until(func(): return game.encounter_rewarded and game.encounter_cleared()), "real enemy clear commits and activates the Gate"):
		return
	check(not game.wild_item_drops.is_empty(), "real encounter creates monster drops")
	keeper.pos = game.battlefield.advance
	traveller.pos = keeper.pos
	ExpeditionCase.Transitions.checkpoint(game, game.HOST, true)
	mark("advance", str(game.participation.travel_epoch()))
	if not check(await until(func(): return game.participation.depth() == 2), "party commits advancement"):
		print("STATE ", [game.status, game.participation.travel_kind(), game.participation.travel_epoch(), game.participation.vote_count(), game.checkpoint_ready, traveller.pos, game.battlefield.advance, game.persistence_session.pending_notice()])
		return
	mark("second-floor", floor_identity(game.battlefield))
	if not check(await until(func(): return read("guest-second") == "ok"), "guest sees next generated floor"):
		return
	# Exercise the real extraction boundary without playing six complete floors.
	ExpeditionCase.set_world(game, {"encounter_number": 6})
	game.deepest_milestone = 6
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	game.encounter_rewarded = true
	keeper.pos = game.battlefield.advance
	traveller.pos = keeper.pos
	ExpeditionCase.Transitions.checkpoint(game, game.HOST, false)
	mark("extract", str(game.participation.travel_epoch()))
	if not check(await until(func(): return not game.participation.active() and read("guest-return") == "ok"), "party extracts to the same developed Garden"):
		return
	keeper.pos = Vector3(0, 0, 1.5)
	garden.open_development()
	if not check(not garden.plans.is_empty() and garden.expand(garden.plans.keys()[0]), "host expands with the guest connected"):
		return
	garden.development_dialog.hide()
	mark("expansion", str(garden.state.outline).sha256_text())
	if not check(await until(func(): return ready_guest(game) == 0 and game.departure_settlement.is_empty()), "host settles the original disconnect"):
		return
	mark("detached")
	if not check(await until(func(): return read("rejoined") == "ok" and ready_guest(game) != 0), "same character reconnects with developed Garden"):
		return
	check(garden.bed_ids[3] == bed_id and game.progress.plots[3].species == 0, "cultivation survives return and reconnect")
	traveller = game.players[ready_guest(game)]
	keeper.pos = game.stage.gate_position()
	traveller.pos = keeper.pos
	game.map_rng.seed = RIVER_SEED
	game.PartyTravel.request(game, game.HOST, "depart")
	mark("depart-again", str(game.participation.travel_epoch()))
	if not check(await until(func(): return ExpeditionCase.is_wild(traveller) and read("guest-floor-again") == "ok"), "rejoined guest enters the repeated seed"):
		return
	check(floor_identity(game.battlefield) == read("floor"), "repeated seed retains the same cover after reconnect")
	if not await river_host(game, traveller, "river-again"):
		return
	game.return_to_main_menu()
	await process_frame
	check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer, "host goes offline before teardown")
	mark("host-offline")

func join(menu: Node) -> Node:
	var title_id := menu.get_instance_id()
	menu.show_page(2)
	menu.join_button.pressed.emit()
	if not check(menu.network_dialog.visible, "real title opens Join by IP"):
		return null
	menu.network_dialog.address_field.text = "127.0.0.1:" + str(port)
	menu.network_dialog.submit.pressed.emit()
	if not check(await until(func(): return current_scene.get_instance_id() != title_id and SessionCase.role(current_scene) == "Guest" and current_scene.stage.experimental_garden.remote_revision >= 0), "title admits guest and supplies Garden"):
		print("JOIN STATE ", [SessionCase.role(current_scene), current_scene.get("status"), current_scene.get("return_message")])
		return null
	return current_scene

func guest_run(menu: Node) -> void:
	menu.request_create_character()
	menu.create_character("Terrain Explorer", 2, Appearance.DEFAULT)
	if not check(await until(func(): return not read("host-ready").is_empty()), "host ready"):
		return
	var game := await join(menu)
	if game == null:
		return
	check(not game.multiplayer.server_relay, "the guest consumes the host roster")
	var garden = game.stage.experimental_garden
	var id: int = game.local_player_id()
	var bed: int = int(read("host-ready"))
	check(not game.persistence_session.authorizes(game.progress.path)
		and garden.bed_ids.get(3) == bed and game.stage.bed_position(3).is_equal_approx(Vector3(2.34, 0, -4.58))
		and is_equal_approx(garden.bed_yaw(3), -0.37), "guest has matching stable bed transform and no host save access")
	check(not garden.remote_development.queue.is_empty() and garden.remote_development.energy > 0
		and not garden.place("bed", Vector2.ZERO, 0.0), "study and energy mirrored; guest cannot build independently")
	mark("guest-layout")
	if not check(await until(func(): return read("plant") == "ok" and Vector3(game.players[id].pos).distance_to(game.stage.bed_position(3)) < 1.65), "guest arrives at the real bed"):
		return
	game.send_garden_action("plant_at_3_0")
	if not check(await until(func(): return not read("depart").is_empty() and game.Progress.decode_plots(game.guest_replication.garden_progress()[12])[3].species == 0), "planted crop appears on guest"):
		return
	game.send_garden_action("travel_ready:" + read("depart"))
	var first_floor_ready := func() -> bool:
		return (not read("floor").is_empty() and game.stage.has_floor()
			and ExpeditionCase.is_wild(game.players.get(game.local_player_id(),{}))
			and game.stage.visual_field.configured_key==Vector3i(game.participation.route(),game.participation.depth(),game.participation.seed())
			and not preload("res://core_combat.gd").cast_key(game,game.players[game.local_player_id()]).is_empty())
	if not check(await until(first_floor_ready), "guest receives the actual first floor and current action identity"):
		return
	check(floor_identity(game.stage.visual_field) == read("floor") and WorldViewCase.component(game,"map").fog.visible
		and not WorldViewCase.component(game,"map").seen(game.stage.visual_field.advance), "matching waterways/routes and unexplored Gate")
	mark("guest-floor")
	Input.action_press("right")
	await create_timer(0.45).timeout
	Input.action_release("right")
	var previous_sequence: int = game.net_motion.sequence
	if not check(await until(func(): return game.net_motion.sequence > previous_sequence), "guest submitted post-release movement"):
		return
	mark("guest-stopped", str(game.net_motion.sequence))
	if not await river_guest(game, id, "river"):
		return
	if not check(await until(func(): return not read("advance").is_empty() and game.enemy_health() == 0), "guest sees authoritative enemy clear"):
		return
	if not check(await until(func(): return int(game.party_travel_state().get("epoch", -1)) == int(read("advance"))), "guest receives the next Gate readiness prompt"):
		return
	game.send_travel_ready(false)
	if not check(await until(func(): return not read("second-floor").is_empty() and game.participation.depth() == 2 and game.stage.visual_field.configured_key.z == game.participation.seed()), "guest follows party advancement"):
		return
	check(floor_identity(game.stage.visual_field) == read("second-floor"), "second floor reconstruction matches")
	check(game.participation.active() and game.participation.contains(id) and game.participation.participants().size() == 2, "guest participation owner matches accepted party snapshot")
	mark("guest-second")
	if not check(await until(func(): return not read("extract").is_empty() and int(game.party_travel_state().get("epoch", -1)) == int(read("extract"))), "host proposes extraction"):
		return
	game.send_travel_ready(false)
	if not check(await until(func(): return not ExpeditionCase.is_wild(game.players[id])), "guest returns through party extraction"):
		return
	check(garden.bed_ids.get(3) == bed and game.Progress.decode_plots(game.guest_replication.garden_progress()[12])[3].species == 0, "return preserves bed and crop")
	mark("guest-return")
	if not check(await until(func(): return not read("expansion").is_empty() and garden.state.revision == 1), "guest receives growth and forest geometry"):
		return
	check(str(garden.state.outline).sha256_text() == read("expansion"), "outer forest matches the host")
	var identity: String = game.guest_character.identity
	var world_id := game.get_instance_id()
	game.return_to_main_menu()
	if not check(await until(func(): return current_scene.get_instance_id() != world_id and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer), "offline before exiting for reconnect"):
		return
	if not check(await until(func(): return read("detached") == "ok"), "host has released the previous connection"):
		return
	game = await join(current_scene)
	if game == null:
		return
	garden = game.stage.experimental_garden
	check(game.guest_character.identity == identity and garden.state.revision == 1 and garden.bed_ids.get(3) == bed
		and str(garden.state.outline).sha256_text() == read("expansion"), "reconnect restores host layout and guest identity")
	mark("rejoined")
	if not check(await until(func(): return not read("depart-again").is_empty()), "rejoined guest receives second travel"):
		return
	game.send_garden_action("travel_ready:" + read("depart-again"))
	var rebuilt := func() -> bool:
		return (game.stage.has_floor() and game.stage.visual_field.configured_key.z == game.participation.seed()
			and ExpeditionCase.is_wild(game.players[game.local_player_id()]))
	if not check(await until(rebuilt), "rejoined guest reconstructs the repeated seed"):
		return
	check(floor_identity(game.stage.visual_field) == read("floor"), "rejoined guest reconstructs identical projectile cover")
	mark("guest-floor-again")
	if not await river_guest(game, game.local_player_id(), "river-again"):
		return
	check(await until(func(): return read("host-offline") == "ok" and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer), "guest observes host shutdown")
