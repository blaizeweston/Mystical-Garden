extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Preview = preload("res://combat_balance_preview.gd")

const Core = preload("res://core_combat.gd")
const Attacks = preload("res://enemy_attack.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const Support = preload("res://enemy_support.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL support rites: ", message)


func actor(kind: int, at: Vector3, hp: int = -1) -> Dictionary:
	var scout: Dictionary = game.make_scout(kind, at, game.encounter.scout_count() + 1)
	if hp >= 0:
		scout.hp = hp
	game.encounter.register_scout(scout)
	return scout


func fixture(kind: int, floor_number: int) -> Dictionary:
	Core.reset(game)
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	ExpeditionCase.set_world(game, {"encounter_number": floor_number})
	ExpeditionCase.set_world(game, {"map_seed": 10 + posmod(-37 - kind * 19 - floor_number * 11, 10)})
	game.encounter.set_hp(-1, 500)
	game.enemy_kind = 0
	game.tactics.position = Vector3(12, 0, 5)
	game.encounter.clear_scouts()
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	ExpeditionCase.set_membership(game, player, true)
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(100)
	player.hurt_until = 0
	player.pos = Vector3(0, 0, 1.4)
	return actor(kind, Vector3.ZERO)


func cancel_rite(caster: Dictionary, role: String) -> bool:
	var now := Time.get_ticks_msec()
	Attacks.lock(game, caster, role, player.pos, now + 1600)
	game.apply_weapon_hit(player,game.encounter.scout_slot(caster),player.pos,{"damage":1,"stagger":180},now)
	return caster.windup == 0 and Tactics.evidence(game).get(Tactics.CAST_DENIAL, 0) == 1


func retry(caster: Dictionary, response: String) -> Dictionary:
	var now := int(caster.ready) + 1
	preload("res://enemy_formation.gd").follow_support(game, caster, preload("res://enemy_formation.gd").allies(game, caster), game.Enemies.get_kind(caster.kind), 0.0, .016, now)
	var plan: Dictionary = caster.get("attack", {})
	check(plan.get("variant") == response and caster.windup == now + int(Tactics.RESPONSES[response].windup), "live AI locks " + response)
	return plan if plan.get("variant") == response else {}


func run() -> void:
	game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/support-rites-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player = game.players[1]
	game.progress.wilds_memory.score[Tactics.CAST_DENIAL] = 6
	test_echo()
	test_tether()
	test_antiphon()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: learned support rites, alternate anchors, corpse accounting, and sector counterplay")
	quit(1 if failed else 0)


func test_echo() -> void:
	for displace in [false, true]:
		var cantor := fixture(3, 7)
		var close := actor(0, Vector3(-1.6, 0, 0))
		var anchor := actor(0, Vector3(3.5, 0, 0))
		var far := actor(0, Vector3(4.3, 0, 0))
		var outer := actor(0, Vector3(5.0, 0, 0))
		Attacks.lock(game, cantor, "chant", player.pos, Time.get_ticks_msec() + 1400)
		check(cantor.attack.get("variant") != Tactics.ECHO_TOLL, "prior memory alone keeps the opening toll ordinary")
		check(cancel_rite(cantor, "chant"), "Native stagger cancels a staffed Cantor rite")
		var plan := retry(cantor, Tactics.ECHO_TOLL)
		if plan.is_empty(): continue
		var warning: Array = Attacks.hints(plan, 0, 1.3)
		check(warning[0].from == [anchor.pos.x, 0, anchor.pos.z] and is_equal_approx(warning[0].radius, 2.35) and warning[1].role == "rally_link", "toll shows its offset circle and tether")
		if displace:
			anchor.pos.z += 1.0
		preload("res://scout_behavior.gd").release(game, cantor, game.Enemies.get_kind(3), cantor.windup)
		check((int(anchor.haste_until) > 0) != displace and (int(far.haste_until) > 0) != displace, "toll buffs two near the anchor or cancels if it moves")
		check(close.haste_until == 0 and outer.haste_until == 0 and PlayerVitals.current_hp(player) == 100, "no caster-centered fallback or player damage")
		Attacks.lock(game, cantor, "chant", player.pos, Time.get_ticks_msec() + 1400)
		check(cantor.attack.get("variant") != Tactics.ECHO_TOLL, "Cantor can only attempt one learned rite")


func test_tether() -> void:
	var bloom := fixture(15, 8)
	game.encounter.set_hp(game.encounter.scout_slot(bloom), 30)
	var initial := actor(0, Vector3(0, 0, -1.4), 0)
	var spare := actor(0, Vector3(5.8, 0, 0), 0)
	var first := actor(0, Vector3(-1.5, 0, 0))
	var second := actor(0, Vector3(2.2, 0, 0))
	check(cancel_rite(bloom, "chant") and bloom.disrupted_corpse == game.encounter.token_for(initial), "interruption remembers the first marked corpse")
	var plan := retry(bloom, Tactics.SPARE_TETHER)
	if not plan.is_empty():
		check(plan.corpse.token == game.encounter.token_for(spare) and Attacks.hints(plan, 0, 1.25)[0].role == "corpse_tether", "spare tether visibly commits to a different corpse")
		var health_before_heal: int = game.encounter.hp_for(bloom)
		var heal_state: int = Preview.heal_rng.state
		var expected_heal: int = game.Director.Balance.corpse_heal(game,bloom,true)
		Preview.heal_rng.state = heal_state
		preload("res://scout_behavior.gd").release(game, bloom, game.Enemies.get_kind(15), bloom.windup)
		check(bloom.consumed_corpses == [game.encounter.token_for(spare)] and game.encounter.hp_for(bloom) == health_before_heal+expected_heal, "spare is consumed once for its current capped rolled heal")
		check(first.haste_until > 0 and second.haste_until == 0, "only the marked escort gains haste")
		Support.resolve_corpse(game, bloom, plan, int(bloom.ready))
		check(game.encounter.hp_for(bloom) == health_before_heal+expected_heal, "a used corpse cannot heal twice")
	bloom = fixture(15, 8)
	initial = actor(0, Vector3(0, 0, -1.4), 0)
	actor(0, Vector3(-1.5, 0, 0))
	actor(0, Vector3(2.2, 0, 0))
	check(cancel_rite(bloom, "chant"), "a lone corpse can still teach denial")
	Attacks.lock(game, bloom, "chant", player.pos, Time.get_ticks_msec() + 1700)
	check(bloom.attack.get("variant") != Tactics.SPARE_TETHER and bloom.attack.corpse.token == game.encounter.token_for(initial), "one corpse gives an ordinary retry")


func test_antiphon() -> void:
	for dodge in [false, true]:
		var choir := fixture(19, 9)
		var anchor := actor(0, Vector3(2.15, 0, .9))
		actor(0, Vector3(-3.8, 0, 0))
		check(cancel_rite(choir, "shepherd"), "Native stagger stops a supported Choir pulse")
		var plan := retry(choir, Tactics.ANTIPHON)
		if plan.is_empty(): continue
		var warning: Array = Attacks.hints(plan, 0, 1.35)
		check(warning[0].role == "enemy_sweep" and warning[0].from == [anchor.pos.x, 0, anchor.pos.z] and warning[1].role == "rally_link", "Antiphon shows the locked sector and singer link")
		check(Support.interruptible(plan), "Antiphon stays interruptible")
		if dodge:
			player.pos = anchor.pos + (anchor.pos - Vector3(plan.face)).normalized()
		var choir_damage: int = Preview.effect_hp(game.Director.Balance.scout_hit(game,game.Enemies.get_kind(19),choir))
		preload("res://scout_behavior.gd").release(game, choir, game.Enemies.get_kind(19), choir.windup)
		check(PlayerVitals.current_hp(player) == (100 if dodge else 100-choir_damage) and choir.windup == 0, "only the marked sector hits and it fires once")
