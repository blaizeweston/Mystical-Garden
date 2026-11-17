extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Attacks = preload("res://enemy_attack.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")

var game: Node
var base: String
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Wilds skill tactics co-op: ", detail)


func mark(key: String) -> void:
	var file := FileAccess.open(base + key, FileAccess.WRITE)
	file.store_string("ok")


func marked(key: String) -> bool:
	return FileAccess.file_exists(base + key)


func until(predicate: Callable, ms: int = 12500) -> bool:
	var end := Time.get_ticks_msec() + ms
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return predicate.call()


func add_scout(kind: int, at: Vector3) -> Dictionary:
	var actor: Dictionary = game.make_scout(kind, at, game.encounter.scout_count() + 1)
	actor.engaged = true
	actor.stagger_until = Time.get_ticks_msec() + 60000
	game.encounter.register_scout(actor)
	return actor


func run() -> void:
	var args := OS.get_cmdline_user_args()
	base = "res://.godot/skill-tactics-coop-" + args[1]
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
		print("PASS: learned rally and hatch warnings " + args[0])
	quit(1 if failed else 0)


func host() -> void:
	check(game.host_game() == OK, "host opens")
	if not await until(func(): return game.players.size() == 2 and game.players.values().all(func(p): return p.profile_ready)):
		check(false, "guest registers")
		return
	var id: int = game.players.keys().filter(func(peer): return peer != 1)[0]
	ExpeditionCase.set_world(game, {"encounter_number": 7})
	ExpeditionCase.set_world(game, {"map_seed": 6})
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	game.progress.wilds_memory.score[Tactics.CAST_DENIAL] = 6
	game.progress.wilds_memory.score[Tactics.AREA_PRESSURE] = 6
	game.encounter.set_hp(-1, 40)
	game.enemy_kind = 0
	game.tactics.position = Vector3(12, 0, 5)
	game.tactics.engaged = false
	game.encounter.clear_scouts()
	for p in game.players.values():
		ExpeditionCase.set_membership(game, p, true)
		p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10)
		p.pos = Vector3.ZERO
	var guest_player: Dictionary = game.players[id]
	guest_player.frame = game.Frames.RANGER
	guest_player.weapon = game.Parts.index_of("plant:hush_orchid")
	var shepherd := add_scout(10, Vector3(0, 0, -1.8))
	add_scout(0, Vector3(2.1, 0, -2))
	add_scout(0, Vector3(-2.1, 0, -2))
	shepherd.cast_target = id
	Attacks.lock(game, shepherd, "shepherd", guest_player.pos, Time.get_ticks_msec() + 3500)
	if not await until(func(): return Tactics.evidence(game).get(Tactics.CAST_DENIAL, 0) == 1):
		check(false, "guest's Hush interrupts the host rally")
		return
	check(shepherd.windup == 0, "host cancels the first rally")
	await until(func(): return Time.get_ticks_msec() >= int(shepherd.ready))
	preload("res://enemy_formation.gd").follow_support(game, shepherd, preload("res://enemy_formation.gd").allies(game, shepherd), game.Enemies.get_kind(10), 0.0, .016, Time.get_ticks_msec())
	if shepherd.get("attack", {}).get("variant") != Tactics.RELAY:
		check(false, "host locks the relay")
		return
	var escort: Dictionary = game.encounter.scout(shepherd.attack.flank.escort.slot)
	if not await until(func(): return marked("relay"), 950):
		check(false, "guest reads relay before release")
		return
	escort.rooted_until = Time.get_ticks_msec() + 1800
	check(await until(func(): return shepherd.windup == 0), "relay resolves")
	check(not escort.has("command_via"), "rooted escort cannot complete the relay")
	mark("relay-resolved")
	if not await until(func(): return marked("relay-cleared")):
		check(false, "guest sees relay warning clear")
		return

	game.encounter.clear_scouts()
	ExpeditionCase.set_world(game, {"encounter_number": 10})
	ExpeditionCase.set_world(game, {"map_seed": 2})
	for p in game.players.values():
		p.pos = Vector3(0, 0, 2.7)
	var mother := add_scout(9, Vector3.ZERO)
	Attacks.lock(game, mother, "brood", guest_player.pos, Time.get_ticks_msec() + 1500)
	check(mother.attack.get("variant") == Tactics.SCATTER, "host chooses scattered hatch")
	if not await until(func(): return marked("hatch"), 1250):
		check(false, "guest sees both hatch warnings in time")
		return
	check(await until(func(): return mother.summons == 2), "two hatch sites resolve on the host")
	mark("done")
	check(await until(func(): return marked("verified")), "guest verifies cleanup")
	game.leave_game("Wilds skill tactics fixture")


func hints(role: String) -> Array:
	return game.combat_visuals.hints.values().filter(func(hint): return hint.event.get("role") == role)


func cue(value: String) -> bool:
	return game.combat_visuals.hints.values().any(func(hint): return hint.has("label") and hint.label.visible and hint.label.text == value)


func guest() -> void:
	game.guest_character.data.active_class = game.Frames.RANGER
	game.guest_character.save_profile()
	check(game.join_game() == OK, "guest connects")
	var id: int = game.multiplayer.get_unique_id()
	if not await until(func(): return game.session == "Guest" and game.player_hud.state.get("core", {}).get("name") == "Hush" and cue("Rally")):
		check(false, "guest sees the live rally and has Hush")
		return
	game.send_garden_action(Core.request(game, game.players[id], Vector2.UP, 1.8))
	if not await until(func(): return cue("Relay order") and hints("rally_link").size() == 2):
		check(false, "guest reads the new relay label, tether and flank")
		return
	mark("relay")
	check(await until(func(): return marked("relay-resolved") and not cue("Relay order")), "guest sees the rooted relay end")
	mark("relay-cleared")
	if not await until(func(): return cue("Scattered hatch") and hints("hatch").size() == 2):
		check(false, "guest reads both scattered hatch markers")
		return
	mark("hatch")
	check(await until(func(): return marked("done") and hints("hatch").is_empty()), "hatch warnings clear at release")
	mark("verified")
	check(await until(func(): return game.session == "Solo"), "host finishes")
