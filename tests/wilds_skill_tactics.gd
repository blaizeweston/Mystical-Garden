extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const Attacks = preload("res://enemy_attack.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Wilds skill tactics: ", detail)


func floor_fixture() -> void:
	Core.reset(game)
	game.combat_epoch += 1
	game.encounter_rewarded = false
	game.enemy_hp = 50
	game.enemy_kind = 0
	game.enemy_pos = Vector3(9, 0, 7)
	game.scouts.clear()
	game.leader_brain.clear()
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	player.pos = Vector3.ZERO
	player.wild = true
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)


func add_scout(kind: int, at: Vector3) -> Dictionary:
	var actor: Dictionary = game.make_scout(kind, at, game.scouts.size() + 1)
	game.scouts.append(actor)
	return actor


func shepherd_group() -> Dictionary:
	var shepherd := add_scout(10, Vector3(0, 0, -1.8))
	add_scout(0, Vector3(2.1, 0, -2))
	add_scout(0, Vector3(-2.1, 0, -2))
	shepherd.cast_target = 1
	return shepherd


func core_skill(species: String, distance: float) -> Dictionary:
	Core.reset(game)
	player.weapon = game.Parts.index_of("plant:" + species)
	player.core_ready_at = 0
	player.core_cast_until = 0
	player.cast_until = 0
	game.garden_action(1, Core.request(game, player, Vector2.UP, distance))
	var cast: Dictionary = game.get_meta(Core.STATE, {}).get(1, {})
	check(not cast.is_empty(), "Core command accepted for " + species)
	if not cast.is_empty():
		Core.tick(game, cast.armed)
	return cast


func finish() -> void:
	game.enemy_hp = 0
	game.scouts.clear()
	game.finish_combat(1, Vector3.ZERO)


func run() -> void:
	game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/skill-tactics-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player = game.players[1]
	game.encounter_number = 7
	game.map_seed = 6
	check_learning()
	check_relay()
	check_scatter()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Core evidence, host-world learning, relay, scattered hatches and player counterplay")
	quit(1 if failed else 0)


func check_learning() -> void:
	floor_fixture()
	var shepherd := shepherd_group()
	core_skill("hush_orchid", 2.0)
	check(Tactics.evidence(game).is_empty(), "Hush on an idle Shepherd is not evidence")
	core_skill("veilcap", 2.0)
	check(Tactics.evidence(game).is_empty(), "control with no actual damage is not area pressure")
	Attacks.lock(game, shepherd, "shepherd", player.pos, Time.get_ticks_msec() + 1400)
	game.apply_weapon_hit(player, 0, player.pos, {"damage": 1, "stagger": 180, "suppress": 1}, Time.get_ticks_msec())
	check(Tactics.evidence(game).get(Tactics.CAST_DENIAL) == 1 and shepherd.windup == 0, "a real interrupting strike contributes once")
	Attacks.lock(game, shepherd, "shepherd", player.pos, Time.get_ticks_msec() + 1400)
	shepherd.traits = {}
	shepherd.hp = 1
	game.apply_weapon_hit(player, 0, player.pos, {"damage": 4, "stagger": 180, "suppress": 1}, Time.get_ticks_msec())
	check(Tactics.evidence(game).get(Tactics.CAST_DENIAL) == 1, "a killing strike does not count as an interrupted rite")

	for index in 3:
		floor_fixture()
		check(Tactics.evidence(game).is_empty(), "new floor starts with no observations")
		shepherd = shepherd_group()
		game.scouts[1].pos = Vector3(.45, 0, -2.3)
		Attacks.lock(game, shepherd, "shepherd", player.pos, Time.get_ticks_msec() + 1400)
		core_skill("hush_orchid", 2.0)
		check(shepherd.windup == 0 and Tactics.evidence(game).get(Tactics.CAST_DENIAL) == 1, "Hush cancels the rally and records a confirmed denial")
		if index == 0:
			Attacks.lock(game, shepherd, "shepherd", player.pos, Time.get_ticks_msec() + 1400)
			check(shepherd.attack.variant != Tactics.RELAY, "one interrupted floor is below the response threshold")
		var embers := core_skill("ember_fern", 2.0)
		Core.tick(game, embers.armed + 850)
		check(int(Tactics.evidence(game).get(Tactics.AREA_PRESSURE, 0)) == 2, "two contact ticks hit a real cluster along the trail")
		finish()
		check(game.progress.wilds_memory.score[Tactics.CAST_DENIAL] == 2 * (index + 1) and game.progress.wilds_memory.score[Tactics.AREA_PRESSURE] == 2 * (index + 1), "each observed tactic scores once on a cleared floor")
	var saved = load("res://progress.gd").new()
	saved.path = game.progress.path
	check(saved.load_garden() == OK and saved.wilds_memory.score[Tactics.CAST_DENIAL] == 6 and saved.wilds_memory.score[Tactics.AREA_PRESSURE] == 6, "both memories survive a host-world reload")


func check_relay() -> void:
	floor_fixture()
	var shepherd := shepherd_group()
	var now := Time.get_ticks_msec()
	Attacks.lock(game, shepherd, "shepherd", player.pos, now + 1400)
	check(shepherd.attack.variant != Tactics.RELAY and shepherd.attack.escorts.size() == 2, "the first rally still needs a real interruption")
	core_skill("hush_orchid", 2.0)
	now = int(shepherd.ready) + 10
	game.update_support_position(shepherd, game.support_allies(shepherd), game.Enemies.get_kind(10), 0.0, .016, now)
	var attack: Dictionary = shepherd.get("attack", {})
	check(attack.get("variant") == Tactics.RELAY and shepherd.windup == now + Tactics.RELAY_WINDUP, "live AI locks a warned relay after the cancellation")
	if attack.get("variant") != Tactics.RELAY:
		return
	check(attack.escorts.size() == 1 and Attacks.hints(attack, 0, 1.15).any(func(hint): return hint.role == "rally_link"), "relay shows one escort's route")
	var chosen: int = attack.flank.escort.slot
	var other := 2 if chosen == 1 else 1
	game.resolve_scout(shepherd, game.Enemies.get_kind(10), shepherd.windup)
	check(game.scouts[chosen].command_via == attack.flank.via and not game.scouts[other].has("command_via") and PlayerVitals.current_hp(player) == 10, "relay only moves its warned escort")
	Attacks.lock(game, shepherd, "shepherd", player.pos, now + 5000)
	check(shepherd.attack.variant != Tactics.RELAY, "one relay per enemy")
	floor_fixture()
	shepherd = shepherd_group()
	shepherd.rite_disrupted_epoch = game.combat_epoch
	Attacks.lock(game, shepherd, "shepherd", player.pos, now + 1400)
	if shepherd.attack.get("variant") == Tactics.RELAY:
		chosen = shepherd.attack.flank.escort.slot
		game.scouts[chosen].rooted_until = now + 2000
		game.resolve_scout(shepherd, game.Enemies.get_kind(10), now + 1400)
		check(not game.scouts[chosen].has("command_target"), "rooting the escort denies the relay")


func check_scatter() -> void:
	floor_fixture()
	game.encounter_number = 9
	game.map_seed = 2
	player.pos = Vector3(0, 0, 2.7)
	var mother := add_scout(9, Vector3.ZERO)
	var now := Time.get_ticks_msec()
	Attacks.lock(game, mother, "brood", player.pos, now + 1500)
	check(mother.attack.variant != Tactics.SCATTER, "opening Broodmother floor does not scatter")
	game.encounter_number = 10
	Attacks.lock(game, mother, "brood", player.pos, now + 1500)
	var attack: Dictionary = mother.attack
	check(attack.variant == Tactics.SCATTER and attack.hatch.size() == 2, "repeated area pressure spreads the hatch points")
	if attack.hatch.size() != 2:
		return
	check(attack.hatch[0].distance_to(attack.hatch[1]) >= 6.0, "hatches are far enough apart to split most circles")
	check(Attacks.hints(attack, 0, 1.5).filter(func(hint): return hint.role == "hatch").size() == 2, "both sites are marked")
	player.pos = attack.hatch[0]
	game.resolve_scout(mother, game.Enemies.get_kind(9), now + 1500)
	check(mother.summons == 1 and game.scouts.any(func(s): return s.get("broodmother_spawn", false) and s.pos == attack.hatch[1]), "a player can deny one site by occupying it")
	check(game.combat_events.any(func(e): return e.kind == "proc" and e.shape == "hatch_blocked"), "blocked hatch gives immediate feedback")
	Attacks.lock(game, mother, "brood", player.pos, now + 3200)
	check(mother.attack.variant != Tactics.SCATTER and mother.attack.hatch.size() <= 1, "the response does not increase the ordinary brood budget")
	player.pos = Vector3(attack.hatch[1]) + Vector3.BACK * 1.8
	core_skill("ember_fern", 1.8)
	check(Tactics.evidence(game).get(Tactics.AREA_PRESSURE) == 1, "a burning trail that wipes out a Broodmother seedling counts even when it is alone")
