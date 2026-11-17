extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Aim = preload("res://ability_aim.gd")

var game: Node
var base: String
var failed := false


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Core roster co-op: ", detail)


func mark(key: String) -> void:
	var file := FileAccess.open(base + key, FileAccess.WRITE)
	file.store_string("ok")


func marked(key: String) -> bool:
	return FileAccess.file_exists(base + key)


func until(predicate: Callable) -> bool:
	var end := Time.get_ticks_msec() + 12500
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return predicate.call()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	base = "res://.godot/core-roster-coop-" + args[1]
	game = load("res://world.tscn").instantiate()
	game.progress.path = base + args[0]
	game.local_character.path = game.progress.path + ".character"
	game.guest_character.path = game.progress.path + ".guest"
	root.add_child(game)
	if args[0] == "host":
		await host()
	else:
		await guest()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Core roster co-op " + args[0])
	quit(1 if failed else 0)


func host() -> void:
	check(game.host_game() == OK, "host opens")
	if not await until(func(): return game.players.size() == 2 and game.players.values().all(func(p): return p.profile_ready)):
		check(false, "guest registers")
		return
	var id: int = game.players.keys().filter(func(peer): return peer != 1)[0]
	var player: Dictionary = game.players[id]
	for member in game.players.values():
		ExpeditionCase.set_membership(game, member, true)
		member.pos = Vector3.ZERO
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 30)
	game.enemy_kind = 0
	game.enemy_mutations = 0
	game.tactics.position = Vector3(0, 0, -5.8)
	game.tactics.engaged = true
	game.tactics.winding_up = true
	game.tactics.strike_at = Time.get_ticks_msec() + 90000
	player.frame = game.Frames.RANGER
	player.weapon_kind = 0
	player.weapon = game.Parts.index_of("plant:ember_fern")
	player.run_upgrades = {"core_ember_wake": 1}
	if not await until(func(): return marked("ember") and game.enemy_health() <= 26):
		check(false, "Banked Coals keeps the trail hot for four damage ticks on the host")
		return
	game.encounter.set_hp(-1, 30)
	game.tactics.position = Vector3(0, 0, -2)
	player.core_ready_at = 0
	player.core_cast_until = 0
	player.cast_until = 0
	player.weapon = game.Parts.index_of("plant:storm_reed")
	player.run_upgrades = {"core_chain_spark": 1}
	var scout: Dictionary = game.make_scout(0, Vector3(1.8, 0, -2), 1)
	scout.stagger_until = Time.get_ticks_msec() + 20000
	game.encounter.register_scout(scout)
	check(await until(func(): return marked("spark") and game.enemy_health() == 28 and game.encounter.hp_for(scout) == scout.max_hp - 1 and scout.rooted_until > 0), "Chain Spark damage and purchased root are authoritative")
	mark("spark-done")
	if not await until(func(): return marked("spark-verified")):
		check(false, "guest confirms the chain result")
		return

	game.encounter.clear_scouts()
	game.tactics.rooted_until = 0
	game.tactics.position = Vector3(0, 0, -5.8)
	player.pos = Vector3.ZERO
	player.weapon = game.Parts.index_of("plant:ghost_fern")
	player.run_upgrades = {"core_phantom_step": 1}
	player.core_ready_at = 0
	player.core_cast_until = 0
	player.cast_until = 0
	check(await until(func(): return game.tactics.rooted_until > Time.get_ticks_msec() and Vector3(player.pos).distance_to(Vector3(0, 0, 1.7)) < .05), "the host resolves the remote root and backward movement")
	mark("done")
	check(await until(func(): return marked("verified")), "guest confirms movement and root")

	var ally: Dictionary = game.players[1]
	ally.pos = Vector3(0, 0, -1.6)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(6)
	player.pos = Vector3.ZERO
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(6)
	player.weapon = game.Parts.index_of("plant:tide_lily")
	player.run_upgrades = {}
	player.core_ready_at = 0
	player.core_cast_until = 0
	player.cast_until = 0
	check(await until(func(): return PlayerVitals.current_hp(ally) == 7 and PlayerVitals.current_hp(player) == 7), "the guest wave heals the host ally and caster on the return")
	mark("tide-done")
	check(await until(func(): return marked("tide-verified")), "guest confirms both crests and health")
	game.leave_game("Core roster fixture")


func preview_release(id: int) -> void:
	game.players[id].facing = Vector3.FORWARD
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	event.pressed = true
	game._unhandled_key_input(event)
	var preview = Aim.active(game)
	check(preview != null and preview.slot == 2 and preview.drawing.get_surface_count() == 1, "guest draws hold preview")
	event.pressed = false
	game._input(event)


func guest() -> void:
	game.guest_character.data.active_class = game.Frames.RANGER
	game.guest_character.save_profile()
	check(game.join_game() == OK, "guest connects")
	var id: int = game.multiplayer.get_unique_id()
	if not await until(func(): return game.session == "Guest" and game.player_hud.state.get("core", {}).get("tooltip", "").contains("Banked Coals")):
		check(false, "guest receives Ember Wake icon, tooltip and card")
		return
	preview_release(id)
	var has_field := func(): return game.combat_visuals.hints.values().any(func(hint): return hint.event.role == "core_field" and hint.event.get("core_shapes", []).any(func(shape): return shape.kind == "capsule"))
	check(await until(has_field), "the guest receives the authoritative Ember Wake trail shape")
	check(await until(func(): return game.received_combat_events.any(func(event): return event.event.get("label") == "Ember Wake")), "guest sees authored pulse label")
	mark("ember")
	if not await until(func(): return game.player_hud.state.get("core", {}).get("tooltip", "").contains("Grounded Current") and not has_field.call()):
		check(false, "field clears and the second skill arrives")
		return
	preview_release(id)
	check(await until(func(): return game.received_combat_events.any(func(event): return event.event.kind == "link" and event.event.shape == "chain_spark")), "guest sees a chain jump")
	mark("spark")
	check(await until(func(): return marked("spark-done") and game.combat_visuals.statuses.active.values().any(func(status): return status.event.shape == "rooted")), "the purchased status reaches the guest")
	mark("spark-verified")
	if not await until(func(): return game.player_hud.state.get("core", {}).get("tooltip", "").contains("Fading Step")):
		check(false, "guest receives the ranged variant tooltip")
		return
	preview_release(id)
	check(await until(func(): return marked("done") and Vector3(game.players[id].pos).distance_to(Vector3(0, 0, 1.7)) < .05), "guest movement reconciles to the retreat instead of the root")
	check(await until(func(): return game.combat_visuals.statuses.active.values().any(func(status): return status.event.shape == "rooted" and int(status.event.combo) == -1)), "root appears on the remote target")
	mark("verified")
	if not await until(func(): return game.player_hud.state.get("core", {}).get("name") == "Riptide"):
		check(false, "guest receives Riptide")
		return
	var player: Dictionary = game.players[id]
	game.send_garden_action(Core.request(game,player,Vector2.UP,2.5))
	var outbound := func(): return game.received_combat_events.any(func(item): return item.event.kind == "ability" and item.event.shape == "riptide")
	var returning := func(): return game.received_combat_events.any(func(item): return item.event.kind == "ability" and item.event.shape == "riptide_return")
	check(await until(outbound), "guest sees the outward wave")
	check(await until(returning), "guest sees the returning wave")
	check(await until(func(): return marked("tide-done") and game.players[id].hp == 7 and game.players[1].hp == 7), "guest sees the synchronized ally heal")
	mark("tide-verified")
	check(await until(func(): return game.session == "Solo"), "host finishes")
