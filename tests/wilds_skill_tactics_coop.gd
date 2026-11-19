extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

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
	check(SessionCase.World.host(game) == OK, "host opens")
	if not await until(func(): return game.players.size() == 2 and game.players.values().all(func(p): return SessionCase.Session.ready_for(p))):
		check(false, "guest registers")
		return
	var id: int = game.players.keys().filter(func(peer): return peer != 1)[0]
	ExpeditionCase.set_world(game, {"encounter_number": 7})
	ExpeditionCase.set_world(game, {"map_seed": 6})
	game.battlefield.configure(0, 1, 0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.progress.wilds_memory.score[Tactics.CAST_DENIAL] = 6
	# Existing recorded observation input exercises response replication; modern Fire
	# does not produce this memory input in the current baseline.
	game.progress.wilds_memory.score[Tactics.AREA_PRESSURE] = 6
	game.encounter.set_hp(-1, 40)
	game.enemy_kind = 0
	game.tactics.position = Vector3(12, 0, 5)
	game.tactics.engaged = false
	game.encounter.clear_scouts()
	for p in game.players.values():
		ExpeditionCase.set_membership(game, p, true)
		p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
		p.pos = Vector3.ZERO
	var guest_player: Dictionary = game.players[id]
	check(game.Classes.connected_tree(game.Frames.WARDEN).focus(guest_player.character)=="vanguard", "host receives the guest starting focus")
	var shepherd := add_scout(10, Vector3(0, 0, -1.8))
	# Quake must strike the caster without releasing the escorts' fixture hold.
	# Both escorts remain within native support reach and have a legal long flank.
	var first_escort := add_scout(0, Vector3(1.8, 0, -3.4))
	var second_escort := add_scout(0, Vector3(-1.8, 0, -3.4))
	var shepherd_health: int = game.encounter.hp_for(shepherd)
	var escort_health: Array[int] = [game.encounter.hp_for(first_escort),game.encounter.hp_for(second_escort)]
	shepherd.cast_target = id
	Attacks.lock(game, shepherd, "shepherd", guest_player.pos, Time.get_ticks_msec() + 3500)
	if not await until(func(): return Tactics.evidence(game).get(Tactics.CAST_DENIAL, 0) == 1):
		check(false, "guest's native Root Quake interrupts the host rally")
		return
	check(shepherd.windup == 0, "host cancels the first rally")
	check(game.encounter.hp_for(shepherd) < shepherd_health and game.encounter.hp_for(shepherd) > 0, "native Root Quake damages the surviving caster")
	check(game.encounter.hp_for(first_escort) == escort_health[0] and game.encounter.hp_for(second_escort) == escort_health[1] and escort_health.all(func(hp): return hp > 0), "out-of-footprint escorts remain alive and untouched by Quake")
	await until(func(): return Time.get_ticks_msec() >= int(shepherd.ready))
	# Keep an actual retry already scheduled by live physics.
	if int(shepherd.windup) <= 0:
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
	SessionCase.World.leave(game,"Wilds skill tactics fixture")


func hints(role: String) -> Array:
	return WorldViewCase.component(game,"combat").hints.values().filter(func(hint): return hint.event.get("role") == role)


func cue(value: String) -> bool:
	return WorldViewCase.component(game,"combat").hints.values().any(func(hint): return hint.has("label") and hint.label.visible and hint.label.text == value)


func guest() -> void:
	game.guest_character.data.active_class = game.Frames.WARDEN
	var tree: RefCounted = game.Classes.connected_tree(game.Frames.WARDEN)
	check(tree.learn(game.guest_character.data,tree.REQUEST_OFFSET).is_empty(), "zero-XP guest chooses Vanguard")
	game.guest_character.save_profile()
	check(SessionCase.World.join(game) == OK, "guest connects")
	var id: int = game.multiplayer.get_unique_id()
	if not await until(func(): return game.network_session.role() == "Guest" and game.Classes.connected_tree(game.Frames.WARDEN).focus(game.guest_character.data)=="vanguard" and not Core.cast_key(game,game.players.get(id,{})).is_empty() and cue("Rally")):
		check(false, "guest sees the live rally and has native Root Quake")
		return
	game.send_garden_action(preload("res://ability_aim.gd").request(game, game.players[id], 1, Vector2.UP))
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
	check(await until(func(): return game.network_session.role() == "Solo"), "host finishes")
