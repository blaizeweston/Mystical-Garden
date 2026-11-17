extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Thorn = preload("res://thorn_adaptation.gd")
const Attacks = preload("res://enemy_attack.gd")
const Elite = preload("res://elite_enemy.gd")
const Learning = preload("res://wilds_learning.gd")

var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL thorn adaptation: ", detail)


func start_floor(game: Node) -> void:
	Core.reset(game)
	game.combat_epoch += 1
	game.encounter_rewarded = false
	game.encounter.set_hp(-1, 40)
	game.enemy_kind = 0
	game.enemy_pos = Vector3(9, 0, 7)
	game.encounter.clear_scouts()
	game.leader_brain.clear()


func place(game: Node, player: Dictionary) -> Dictionary:
	player.pos = Vector3(0, 0, -3)
	player.facing = Vector3.BACK
	player.wild = true
	player.weapon = game.Parts.THORN
	player.core_ready_at = 0
	player.core_cast_until = 0
	player.cast_until = 0
	game.garden_action(1, Core.request(game, player, Vector2.DOWN))
	return game.get_meta(Core.STATE, {}).get(1, {})


func crossing(game: Node, player: Dictionary) -> void:
	var line := place(game, player)
	var center: Vector3 = line.center
	var hound: Dictionary = game.make_scout(Thorn.HOUND, center - Vector3.BACK, 1)
	game.encounter.register_scout(hound)
	Core.tick(game, line.armed)
	hound.pos = center + Vector3.BACK
	Core.tick(game, line.armed + 50)
	check(game.encounter.hp_for(hound) < hound.max_hp and hound.rooted_until == 0, "ordinary moving enemy takes damage crossing the active line")


func clear_floor(game: Node) -> void:
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	game.finish_combat(1, Vector3.ZERO)


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/thorn-adaptation-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	game.encounter_number = 6
	game.map_seed = 3
	var player: Dictionary = game.players[1]
	start_floor(game)
	var line := place(game, player)
	var stationary: Dictionary = game.make_scout(Thorn.HOUND, line.center, 1)
	game.encounter.register_scout(stationary)
	Core.tick(game, line.armed)
	check(Thorn.evidence(game).armed == 1 and Thorn.evidence(game).crossings == 0, "arming on a stationary enemy does not teach a counter")
	clear_floor(game)
	check(game.progress.wilds_memory.score[Thorn.TACTIC] == 0, "placing a trap without a crossing does not raise the score")

	for index in 3:
		start_floor(game)
		crossing(game, player)
		if index == 0:
			game.encounter.clear_scouts()
			crossing(game, player)
			check(Thorn.evidence(game).crossings == 2, "two distinct crossings are recorded")
		clear_floor(game)
		check(game.progress.wilds_memory.score[Thorn.TACTIC] == (index + 1) * 2, "a cleared floor contributes only once")
		check(Thorn.selected(game, {"kind": Thorn.HOUND, "route": 1}) == (index == 2), "occasional use never enables the learned move")
	var save = load("res://progress.gd").new()
	save.path = game.progress.path
	check(save.load_garden() == OK and save.wilds_memory.score[Thorn.TACTIC] == 6, "training persists with the host world")
	check(Learning.normalize({"score": {"choke": 8}}).score[Thorn.TACTIC] == 0, "old world memories start without Thorn Line evidence")
	check(not Thorn.selected(game, {"kind": 0, "route": 1}), "another species cannot learn this response")
	check(not Thorn.selected(game, {"kind": Thorn.HOUND, "route": 6}), "the host still spawns ordinary Hounds")
	var quiet: Dictionary = save.wilds_memory.duplicate(true)
	for step in 5:
		Learning.observe(quiet, {}, 6)
	check(quiet.score[Thorn.TACTIC] == 6, "brief changes in tactics leave the score intact")
	Learning.observe(quiet, {}, 6)
	check(quiet.score[Thorn.TACTIC] == 5, "quiet floors gradually lower pressure")
	game.encounter_number = 5
	check(not Thorn.selected(game, {"kind": Thorn.HOUND, "route": 1}), "opening floors stay unadapted")
	game.encounter_number = 6

	start_floor(game)
	line = place(game, player)
	var center: Vector3 = line.center
	var origin := center - Vector3.BACK * 1.45
	var landing := center + Vector3.BACK * 1.65
	var hound: Dictionary = game.make_scout(Thorn.HOUND, origin, 1)
	game.encounter.register_scout(hound)
	Core.tick(game, line.armed)
	player.pos = landing
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)
	hound.engaged = true
	game.battlefield.barriers = [Rect2(-.45, center.z + .55, .9, .3)]
	check(Thorn.plan(game, hound, landing, line.armed).is_empty(), "a covered landing lane is rejected")
	game.battlefield.barriers.clear()
	check(Thorn.plan(game, hound, center - Vector3.BACK * 3.1, line.armed).is_empty(), "a trap off the pursuit path does not cause a vault")
	game.update_scouts(.01, line.armed)
	var attack: Dictionary = hound.get("attack", {})
	check(attack.get("variant") == Thorn.MOVE and attack.get("to") == landing, "the live scout locks the learned leap without a mobility mutation")
	if not attack.is_empty():
		var warning: Dictionary = Attacks.hints(attack, 0, 1.25)[0]
		check(warning.role == "vault" and warning.cue == Thorn.CUE and warning.radius == Thorn.LANDING_RADIUS, "warning shares the fixed landing and radius")
		player.pos = origin.lerp(landing, .5) + Vector3.RIGHT * 2.0
		game.update_scouts(.01, line.armed + Thorn.WINDUP)
		Core.tick(game, line.armed + Thorn.WINDUP)
		check(hound.pos == landing and PlayerVitals.current_hp(player) == 10, "a player can bait the leap and step aside")
		check(hound.rooted_until == 0 and Core.hints(game).size() == 1, "the chosen line survives the airborne crossing")
		check(Thorn.plan(game, hound, origin, line.armed + Thorn.WINDUP).is_empty(), "one leap per hound")

	start_floor(game)
	game.map_seed = 4
	line = place(game, player)
	center = line.center
	game.enemy_kind = Thorn.HOUND
	game.enemy_pos = center - Vector3.BACK * 1.45
	game.enemy_engaged = true
	player.pos = center + Vector3.BACK * 1.65
	Core.tick(game, line.armed)
	Elite.tick(game, .01, line.armed)
	check(game.enemy_winding_up and Elite.hints(game).any(func(hint): return hint.get("cue") == Thorn.CUE), "gate elite shares the warning")
	game.rooted_until = line.armed + Thorn.WINDUP + 500
	Elite.tick(game, .01, line.armed + Thorn.WINDUP)
	check(game.enemy_pos == center - Vector3.BACK * 1.45 and PlayerVitals.current_hp(player) == 10, "a root applied during windup cancels the elite vault")
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Thorn Line evidence, host memory, vault and counterplay")
	quit(1 if failed else 0)
