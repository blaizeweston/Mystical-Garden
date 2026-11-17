extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Thorn = preload("res://thorn_adaptation.gd")
var game: Node
var base: String
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL thorn adaptation co-op: ", detail)


func mark(key: String) -> void:
	var file := FileAccess.open(base + key, FileAccess.WRITE)
	file.store_string("ok")


func marked(key: String) -> bool:
	return FileAccess.file_exists(base + key)


func until(predicate: Callable, ms: int = 12000) -> bool:
	var end := Time.get_ticks_msec() + ms
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return predicate.call()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	base = "res://.godot/thorn-net-" + args[1]
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
		print("PASS: Thorn vault host and guest " + args[0])
	quit(1 if failed else 0)


func host() -> void:
	check(game.host_game() == OK, "host opens")
	if not await until(func(): return game.players.size() == 2 and game.players.values().all(func(p): return p.profile_ready)):
		check(false, "guest registers")
		return
	var id: int = game.players.keys().filter(func(peer): return peer != 1)[0]
	var player: Dictionary = game.players[1]
	var other: Dictionary = game.players[id]
	game.encounter_number = 6
	game.map_seed = 3
	game.progress.wilds_memory.score[Thorn.TACTIC] = 6
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	game.enemy_hp = 40
	game.enemy_pos = Vector3(12, 0, 5)
	game.enemy_ready_at = Time.get_ticks_msec() + 60000
	game.enemy_winding_up = false
	game.scouts.clear()
	player.wild = true
	other.wild = true
	player.pos = Vector3(0, 0, -3)
	other.pos = Vector3(0, 0, 3)
	player.weapon = game.Parts.THORN
	other[PlayerVitals.STATE] = other[PlayerVitals.STATE].with_hp(10)
	if not await until(func(): return marked("ready")):
		check(false, "guest sees Wilds")
		return
	game.garden_action(1, Core.request(game, player, Vector2.DOWN))
	var line: Dictionary = game.get_meta(Core.STATE, {}).get(1, {})
	if line.is_empty():
		check(false, "host places line")
		return
	var center: Vector3 = line.center
	player.pos = center + Vector3.RIGHT * 6
	other.pos = center + Vector3.BACK * 1.65
	var hound: Dictionary = game.make_scout(Thorn.HOUND, center - Vector3.BACK * 1.45, 1)
	hound.engaged = true
	hound.stagger_until = line.armed
	game.scouts.append(hound)
	if not await until(func(): return hound.get("attack", {}).get("variant") == Thorn.MOVE):
		check(false, "host locks a live vault")
		return
	var end: Vector3 = hound.attack.to
	if not await until(func(): return marked("warning"), 1100):
		check(false, "guest renders the warning in time")
		return
	other.pos = end + Vector3.RIGHT * 2
	check(await until(func(): return hound.pos == end, 1500), "host resolves the locked landing")
	check(PlayerVitals.current_hp(other) == 10 and hound.rooted_until == 0 and Core.hints(game).size() == 1, "guest escapes the landing and line remains active")
	mark("landed")
	check(await until(func(): return marked("verified")), "guest verifies outcome")
	game.leave_game("Thorn vault fixture complete")


func guest() -> void:
	game.guest_character.save_profile()
	check(game.join_game() == OK, "guest connects")
	var id := game.multiplayer.get_unique_id()
	if not await until(func(): return game.session == "Guest" and game.players.get(id, {}).get("wild", false)):
		check(false, "Wilds state arrives")
		return
	mark("ready")
	var warning := func(): return game.combat_visuals.hints.values().any(func(hint): return hint.event.get("cue") == Thorn.CUE and hint.has("label") and hint.label.text == Thorn.CUE)
	if not await until(warning):
		check(false, "guest sees the landing warning and its label")
		return
	mark("warning")
	check(await until(func(): return marked("landed") and not warning.call()), "landing warning clears")
	check(game.players[id].hp == 10 and not game.progress.wilds_memory.score.has(Thorn.TACTIC), "guest keeps full health and owns no world learning")
	mark("verified")
	check(await until(func(): return game.session == "Solo"), "host finishes")
