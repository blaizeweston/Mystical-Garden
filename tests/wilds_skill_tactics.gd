extends SceneTree
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const Attacks = preload("res://enemy_attack.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Wilds skill tactics: ", detail)


func floor_fixture() -> void:
	Core.reset(game)
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	game.encounter_rewarded = false
	game.encounter.set_hp(-1, 500)
	game.enemy_kind = 0
	game.tactics.position = Vector3(9, 0, 7)
	game.encounter.clear_scouts()
	game.tactics.memory.clear()
	game.battlefield.configure(0, 1, 0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	player.pos = Vector3.ZERO
	ExpeditionCase.set_membership(game, player, true)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(100)


func add_scout(kind: int, at: Vector3) -> Dictionary:
	var actor: Dictionary = game.make_scout(kind, at, game.encounter.scout_count() + 1)
	game.encounter.register_scout(actor)
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
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	game.finish_combat(1, Vector3.ZERO)


func run() -> void:
	game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/skill-tactics-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player = game.players[1]
	ExpeditionCase.set_world(game, {"encounter_number": 7})
	ExpeditionCase.set_world(game, {"map_seed": 6})
	check_learning()
	check_relay()
	check_scatter()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: native interruption, recorded memory inputs, relay, scattered hatches and player counterplay")
	quit(1 if failed else 0)


func check_learning() -> void:
	floor_fixture()
	var shepherd := shepherd_group()
	core_skill("hush_orchid", 2.0)
	check(Tactics.evidence(game).is_empty(), "Gravity Well on an idle Shepherd does not invent cast-denial evidence")
	Attacks.lock(game, shepherd, "shepherd", player.pos, Time.get_ticks_msec() + 1400)
	OutgoingHits.hit_world(game, HitSession.peer_for(player), 0, player.pos, {"damage": 1, "stagger": 180}, Time.get_ticks_msec())
	check(Tactics.evidence(game).get(Tactics.CAST_DENIAL) == 1 and shepherd.windup == 0, "a real native stagger contact contributes once")
	Attacks.lock(game, shepherd, "shepherd", player.pos, Time.get_ticks_msec() + 1400)
	shepherd.traits = {}
	game.encounter.set_hp(game.encounter.scout_slot(shepherd), 1)
	OutgoingHits.hit_world(game, HitSession.peer_for(player), 0, player.pos, {"damage": 4, "stagger": 180}, Time.get_ticks_msec())
	check(Tactics.evidence(game).get(Tactics.CAST_DENIAL) == 1, "a killing strike does not count as an interrupted rite")

	for index in 3:
		floor_fixture()
		check(Tactics.evidence(game).is_empty(), "new floor starts with no observations")
		shepherd = shepherd_group()
		Attacks.lock(game, shepherd, "shepherd", player.pos, Time.get_ticks_msec() + 1400)
		OutgoingHits.hit_world(game, HitSession.peer_for(player), 0, player.pos, {"damage": 1, "stagger": 180}, Time.get_ticks_msec())
		check(shepherd.windup == 0 and Tactics.evidence(game).get(Tactics.CAST_DENIAL) == 1, "native stagger cancels the rally and records a confirmed denial")
		if index == 0:
			Attacks.lock(game, shepherd, "shepherd", player.pos, Time.get_ticks_msec() + 1400)
			check(shepherd.attack.variant != Tactics.RELAY, "one interrupted floor is below the response threshold")
		# The modern baseline has no AREA_PRESSURE producer. These explicit recorded
		# observations test the existing memory/response consumer, not Fire delivery.
		for observation in 2:
			Tactics.record(game,Tactics.AREA_PRESSURE,{"source":"fixture:recorded-area-observation","observation":observation})
		check(int(Tactics.evidence(game).get(Tactics.AREA_PRESSURE, 0)) == 2, "explicit recorded area observations reach the memory consumer")
		finish()
		check(game.progress.wilds_memory.score[Tactics.CAST_DENIAL] == 2 * (index + 1) and game.progress.wilds_memory.score[Tactics.AREA_PRESSURE] == 2 * (index + 1), "each observed tactic scores once on a cleared floor")
	var saved = load("res://progress.gd").new()
	saved.path = game.progress.path
	check(saved.load_garden() == OK and saved.wilds_memory.score[Tactics.CAST_DENIAL] == 6 and saved.wilds_memory.score[Tactics.AREA_PRESSURE] == 6, "native denial and recorded area memories survive a host-world reload")


func check_relay() -> void:
	floor_fixture()
	var shepherd := shepherd_group()
	var now := Time.get_ticks_msec()
	Attacks.lock(game, shepherd, "shepherd", player.pos, now + 1400)
	check(shepherd.attack.variant != Tactics.RELAY and shepherd.attack.escorts.size() == 2, "the first rally still needs a real interruption")
	OutgoingHits.hit_world(game, HitSession.peer_for(player), 0, player.pos, {"damage":1,"stagger":180}, now)
	now = int(shepherd.ready) + 10
	preload("res://enemy_formation.gd").follow_support(game, shepherd, preload("res://enemy_formation.gd").allies(game, shepherd), game.Enemies.get_kind(10), 0.0, .016, now)
	var attack: Dictionary = shepherd.get("attack", {})
	check(attack.get("variant") == Tactics.RELAY and shepherd.windup == now + Tactics.RELAY_WINDUP, "live AI locks a warned relay after the cancellation")
	if attack.get("variant") != Tactics.RELAY:
		return
	check(attack.escorts.size() == 1 and Attacks.hints(attack, 0, 1.15).any(func(hint): return hint.role == "rally_link"), "relay shows one escort's route")
	var chosen: int = attack.flank.escort.slot
	var other := 2 if chosen == 1 else 1
	preload("res://scout_behavior.gd").release(game, shepherd, game.Enemies.get_kind(10), shepherd.windup)
	check(game.encounter.scout(chosen).command_via == attack.flank.via and not game.encounter.scout(other).has("command_via") and PlayerVitals.current_hp(player) == 100, "relay only moves its warned escort")
	Attacks.lock(game, shepherd, "shepherd", player.pos, now + 5000)
	check(shepherd.attack.variant != Tactics.RELAY, "one relay per enemy")
	floor_fixture()
	shepherd = shepherd_group()
	shepherd.rite_disrupted_epoch = game.participation.epoch()
	Attacks.lock(game, shepherd, "shepherd", player.pos, now + 1400)
	if shepherd.attack.get("variant") == Tactics.RELAY:
		chosen = shepherd.attack.flank.escort.slot
		game.encounter.scout(chosen).rooted_until = now + 2000
		preload("res://scout_behavior.gd").release(game, shepherd, game.Enemies.get_kind(10), now + 1400)
		check(not game.encounter.scout(chosen).has("command_target"), "rooting the escort denies the relay")


func check_scatter() -> void:
	floor_fixture()
	ExpeditionCase.set_world(game, {"encounter_number": 9})
	ExpeditionCase.set_world(game, {"map_seed": 2})
	player.pos = Vector3(0, 0, 2.7)
	var mother := add_scout(9, Vector3.ZERO)
	var now := Time.get_ticks_msec()
	Attacks.lock(game, mother, "brood", player.pos, now + 1500)
	check(mother.attack.variant != Tactics.SCATTER, "opening Broodmother floor does not scatter")
	ExpeditionCase.set_world(game, {"encounter_number": 10})
	Attacks.lock(game, mother, "brood", player.pos, now + 1500)
	var attack: Dictionary = mother.attack
	check(attack.variant == Tactics.SCATTER and attack.hatch.size() == 2, "repeated area pressure spreads the hatch points")
	if attack.hatch.size() != 2:
		return
	check(attack.hatch[0].distance_to(attack.hatch[1]) >= 6.0, "hatches are far enough apart to split most circles")
	check(Attacks.hints(attack, 0, 1.5).filter(func(hint): return hint.role == "hatch").size() == 2, "both sites are marked")
	player.pos = attack.hatch[0]
	preload("res://scout_behavior.gd").release(game, mother, game.Enemies.get_kind(9), now + 1500)
	check(mother.summons == 1 and game.encounter.scout_tactics().any(func(s): return s.get("broodmother_spawn", false) and s.pos == attack.hatch[1]), "a player can deny one site by occupying it")
	check(game.combat_events.any(func(e): return e.kind == "proc" and e.shape == "hatch_blocked"), "blocked hatch gives immediate feedback")
	Attacks.lock(game, mother, "brood", player.pos, now + 3200)
	check(mother.attack.variant != Tactics.SCATTER and mother.attack.hatch.size() <= 1, "the response does not increase the ordinary brood budget")
	player.pos = Vector3(attack.hatch[1]) + Vector3.BACK * 1.8
	OutgoingHits.hit_world(game, HitSession.peer_for(player), 1, player.pos, {"damage":4}, now+3300)
	check(not game.encounter.alive(1) and game.monster_rewards.pending_count()==0, "the surviving hatchling remains a real killable nonrewarding summon")
