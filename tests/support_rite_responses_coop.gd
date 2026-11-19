extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
const Conditions = preload("res://player_hit_conditions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Preview = preload("res://combat_balance_preview.gd")

const Core = preload("res://core_combat.gd")
const Attacks = preload("res://enemy_attack.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const RESPONSES := [Tactics.ECHO_TOLL, Tactics.SPARE_TETHER, Tactics.ANTIPHON]

var game: Node
var base: String
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL learned support rites co-op: ", detail)


func mark(key: String, value: String = "ok") -> void:
	var file := FileAccess.open(base + key, FileAccess.WRITE)
	file.store_string(value)


func marked(key: String) -> bool:
	return FileAccess.file_exists(base + key)


func until(predicate: Callable, ms: int = 10500) -> bool:
	var end := Time.get_ticks_msec() + ms
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return predicate.call()


func actor(kind: int, at: Vector3, dead: bool = false) -> Dictionary:
	var scout: Dictionary = game.make_scout(kind, at, game.encounter.scout_count() + 1)
	scout.engaged = true
	scout.stagger_until = Time.get_ticks_msec() + 60000
	if dead:
		scout.hp = 0
	game.encounter.register_scout(scout)
	return scout


func run() -> void:
	var args := OS.get_cmdline_user_args()
	base = "res://.godot/support-rites-coop-" + args[1]
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
		print("PASS: learned support rite warnings and outcomes " + args[0])
	quit(1 if failed else 0)


func prepare(response: String) -> Dictionary:
	var profile: Dictionary = Tactics.RESPONSES[response]
	var kind: int = profile.kind
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	ExpeditionCase.set_world(game, {"encounter_number": profile.floor})
	ExpeditionCase.set_world(game, {"map_seed": 0})
	game.battlefield.configure(game.participation.route(), game.participation.depth(), game.participation.seed())
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.encounter.set_hp(-1, 500)
	game.enemy_kind = 0
	game.tactics.position = Vector3(12, 0, 5)
	game.tactics.engaged = false
	game.encounter.clear_scouts()
	Core.reset(game)
	for member in game.players.values():
		ExpeditionCase.set_membership(game, member, true)
		member[PlayerVitals.STATE] = member[PlayerVitals.STATE].with_hp(100)
		member[Conditions.STATE] = member[Conditions.STATE].clear_grace()
		member.pos = Vector3(0, 0, 1.4)
	var caster := actor(kind, Vector3.ZERO)
	# Pick an eligible route while keeping the networked scene on the same flat test layout.
	caster.route = 10 + posmod(-3 * (kind * 19 + int(profile.floor) * 11), 10)
	match response:
		Tactics.ECHO_TOLL:
			actor(0, Vector3(-1.6, 0, 0))
			actor(0, Vector3(3.5, 0, 0))
			actor(0, Vector3(4.3, 0, 0))
		Tactics.SPARE_TETHER:
			game.encounter.set_hp(game.encounter.scout_slot(caster), 30)
			actor(0, Vector3(0, 0, -1.4), true)
			actor(0, Vector3(5.8, 0, 0), true)
			actor(0, Vector3(-1.5, 0, 0))
			actor(0, Vector3(2.2, 0, 0))
		Tactics.ANTIPHON:
			actor(0, Vector3(2.15, 0, .9))
			actor(0, Vector3(-3.8, 0, 0))
	return caster


func host() -> void:
	check(SessionCase.World.host(game) == OK, "host opens")
	if not await until(func(): return game.players.size() == 2 and game.players.values().all(func(p): return SessionCase.Session.ready_for(p))):
		check(false, "guest registers")
		return
	var guest_id: int = game.players.keys().filter(func(id): return id != 1)[0]
	game.progress.wilds_memory.score[Tactics.CAST_DENIAL] = 6
	for response in RESPONSES:
		var caster := prepare(response)
		var role: String = game.Enemies.get_kind(caster.kind).role
		var player: Dictionary = game.players[1]
		Attacks.lock(game, caster, role, player.pos, Time.get_ticks_msec() + 4500)
		OutgoingHits.hit_world(game, HitSession.peer_for(player), game.encounter.scout_slot(caster), player.pos, {"damage":1,"stagger":180}, Time.get_ticks_msec())
		if not await until(func(): return Tactics.evidence(game).get(Tactics.CAST_DENIAL, 0) == 1 and Time.get_ticks_msec() >= int(caster.ready)):
			check(false, "Native stagger stops the ordinary rite before " + response)
			return
		# The live physics loop may already have locked the learned retry.
		# Never replace that one-use commitment with a second plan.
		if int(caster.windup) <= 0:
			preload("res://enemy_formation.gd").follow_support(game, caster, preload("res://enemy_formation.gd").allies(game, caster), game.Enemies.get_kind(caster.kind), 0.0, .016, Time.get_ticks_msec())
		var plan: Dictionary = caster.get("attack", {})
		if plan.get("variant") != response:
			check(false, "host locks " + response)
			return
		if not await until(func(): return marked("seen-" + response), 1080):
			check(false, "guest reads " + response + " before resolution")
			return
		if response == Tactics.ANTIPHON:
			var origin: Vector3 = plan.rite_anchor.point
			var facing := (Vector3(plan.face) - origin).normalized()
			game.players[guest_id].pos = origin - facing
		var health_before_heal: int = game.encounter.hp_for(caster)
		var heal_state: int = Preview.heal_rng.state
		var expected_heal: int = game.Director.Balance.corpse_heal(game,caster,true) if response == Tactics.SPARE_TETHER else 0
		Preview.heal_rng.state = heal_state
		var choir_damage: int = Preview.effect_hp(game.Director.Balance.scout_hit(game,game.Enemies.get_kind(caster.kind),caster))
		if response == Tactics.SPARE_TETHER: mark("corpse-heal",str(expected_heal))
		check(await until(func(): return caster.windup == 0), "the warned move resolves")
		match response:
			Tactics.ECHO_TOLL:
				check(game.encounter.scout(1).haste_until == 0 and game.encounter.scout(3).haste_until > 0, "offset toll only buffs the cluster (anchor %s, scouts %s)" % [plan.rite_anchor, game.encounter.scout_tactics().map(func(s): return [s.pos, s.haste_until])])
			Tactics.SPARE_TETHER:
				check(game.encounter.hp_for(caster) == health_before_heal+expected_heal and caster.consumed_corpses == [plan.corpse.token], "alternate corpse heals once")
			Tactics.ANTIPHON:
				check(PlayerVitals.current_hp(player) == 100-choir_damage and PlayerVitals.current_hp(game.players[guest_id]) == 100, "offset sector hits only the player who stays")
		mark("resolved-" + response)
		if not await until(func(): return marked("clear-" + response)):
			check(false, "guest sees warning clear")
			return
	SessionCase.World.leave(game,"Support rite fixture")


func displayed(response: String) -> bool:
	var cue: String = Tactics.RESPONSES[response].cue
	return WorldViewCase.component(game,"combat").hints.values().any(func(hint): return hint.has("label") and hint.label.visible and hint.label.text == cue)


func shown_status(shape: String, actor_id: int) -> bool:
	return WorldViewCase.component(game,"combat").statuses.active.values().any(func(item): return item.node.visible and item.label.visible and item.event.shape == shape and item.event.combo == actor_id)


func guest() -> void:
	game.guest_character.save_profile()
	check(SessionCase.World.join(game) == OK, "guest connects")
	for response in RESPONSES:
		if not await until(func(): return displayed(response)):
			check(false, "guest sees " + response)
			return
		var roles: Array = WorldViewCase.component(game,"combat").hints.values().map(func(hint): return hint.event.role)
		var expected: String = {Tactics.ECHO_TOLL: "chant", Tactics.SPARE_TETHER: "corpse_tether", Tactics.ANTIPHON: "enemy_sweep"}[response]
		check(roles.has(expected) and roles.has("rally_link"), "warning has an impact and a tether for " + response)
		mark("seen-" + response)
		check(await until(func(): return marked("resolved-" + response) and not displayed(response)), "guest sees " + response + " clear")
		match response:
			Tactics.ECHO_TOLL:
				check(await until(func(): return shown_status("haste", 3)), "buffed escort shows Hastened")
			Tactics.SPARE_TETHER:
				check(await until(func(): return WorldViewCase.component(game,"combat").feedback.labels.any(func(item): return item.node.visible and item.node.text == "+" + FileAccess.get_file_as_string(base + "corpse-heal"))), "actual corpse heal shows its current resolved HP amount")
				check(await until(func(): return shown_status("haste", 3)), "Spare Tether marks the hasted escort")
			Tactics.ANTIPHON:
				check(await until(func(): return shown_status("slow", 1)), "guest sees the host's short Slowed callout")
				check(not shown_status("slow", game.multiplayer.get_unique_id()), "dodging guest gets no status")
				check(await until(func(): return not shown_status("slow", 1)), "Slowed clears after Antiphon expires")
		mark("clear-" + response)
	check(await until(func(): return game.network_session.role() == "Solo"), "host finishes")
