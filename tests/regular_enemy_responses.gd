extends SceneTree

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const Attacks = preload("res://enemy_attack.gd")
const Core = preload("res://core_combat.gd")
const Effects = preload("res://core_skill_effects.gd")
const Status = preload("res://combat_status.gd")
const Support = preload("res://enemy_support.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")

var game: Node
var player: Dictionary
var failed := false


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL regular responses: ", detail)


func setup(kind: int, profile: Dictionary) -> Dictionary:
	Core.reset(game)
	game.combat_epoch += 1
	game.encounter_rewarded = false
	game.encounter_number = profile.floor
	game.map_seed = 10 + posmod(-37 - kind * 19 - int(profile.floor) * 11, 10)
	game.boss_kind = -1
	game.encounter.set_hp(-1, 50)
	game.enemy_kind = 0
	game.enemy_pos = Vector3(-10, 0, 8)
	game.leader_brain.clear()
	game.encounter.clear_scouts()
	game.wild_item_drops.clear()
	game.enemy_hazards.clear()
	game.combat_events.clear()
	player.slow_until = 0
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	player.wild = true
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10)
	player.hurt_until = 0
	player.pos = Vector3(0, 0, -3.4)
	return add_actor(kind, Vector3.ZERO, 1)


func add_actor(kind: int, at: Vector3, route: int) -> Dictionary:
	var actor: Dictionary = game.make_scout(kind, at, route)
	actor.engaged = true
	actor.hp = 20
	game.encounter.register_scout(actor)
	return actor


func learn(actor: Dictionary, profile: Dictionary, now: int) -> void:
	match profile.tactic:
		Tactics.CAST_DENIAL:
			Attacks.lock(game, actor, profile.mode, player.pos, now + 1400)
			check(actor.attack.variant != profile.id, "ordinary opening for " + str(profile.id))
			Effects.affect_enemy(game, player, 0, actor.pos, {"id": "hush"}, {"only_winding": true, "interrupt_ms": 1000}, now)
			check(actor.windup == 0 and actor.get("rite_disrupted_epoch") == game.combat_epoch, "Hush stops the committed " + str(profile.mode))
		Tactics.ROUTE_DENIAL:
			actor.engaged = false
			Status.root(game, 0, now + 1000)
			check(Tactics.evidence(game).is_empty(), "idle root does not teach pursuit")
			actor.rooted_until = 0
			actor.engaged = true
			Status.root(game, 0, now + 1000)
			Status.root(game, 0, now + 1300)
			check(Tactics.evidence(game).get(Tactics.ROUTE_DENIAL) == 1, "a root on a pursuing actor counts once")
		Tactics.SHELTER_BREAK:
			var escort := add_actor(0, Vector3.RIGHT * 2.35, 2)
			check(not Support.shelter_source(game, 1, escort.pos, escort.pos, now, true).is_empty(), "escort starts sheltered")
			Effects.affect_enemy(game, player, 1, Vector3(2, 0, 0), {"id": "riptide"}, {"displace": .2}, now)
			check(Tactics.evidence(game).is_empty(), "a short nudge does not teach the Grazer")
			Effects.affect_enemy(game, player, 1, Vector3(2, 0, 0), {"id": "riptide"}, {"displace": 1.35}, now)
			check(Tactics.evidence(game).get(Tactics.SHELTER_BREAK) == 1 and escort.pos.x > 3.8, "real displacement out of shelter teaches the Grazer")


func arm(actor: Dictionary, profile: Dictionary, now: int) -> Dictionary:
	if Attacks.SkillResponses.APPROACH.has(actor.kind):
		Attacks.try_skill_approach(game, actor, player.pos, now)
	elif int(actor.kind) == 16:
		game.wild_item_drops.append({"id": "part", "stack": {"item": game.Items.part_id(game.Parts.monster_part(0)), "quantity": 1}, "position": [2.75, 0, 0]})
		game.EnemyBehaviors.tick(game, actor, .016, now)
	else:
		var point: Vector3 = player.pos if actor.kind != 0 else Vector3(0, 0, -1.9)
		Attacks.lock(game, actor, profile.mode, point, now + 1500)
	return actor.get("attack", {})


func validate_plan(kind: int, actor: Dictionary, attack: Dictionary) -> void:
	match kind:
		0, 7:
			player.pos = attack.from + (Vector3(attack.face) - Vector3(attack.from)).normalized() * 1.8
		1:
			check(attack.to.distance_to(actor.denied_aim) > 1.5, "Echo bud offsets the denied pulse")
			player.pos = attack.to
			actor.repeat = 1
		2:
			var hints := Attacks.hints(attack, 0, 1.2)
			check(hints.size() == 2 and hints[0].to == hints[1].from, "both charge legs share the locked bend")
			player.pos = attack.via
		5, 18:
			check(attack.spots.size() == 2, "both strikes are explicit")
			player.pos = attack.spots[0]
		6:
			check(attack.patches.size() == 3, "spore fan leaves separate beds")
		8, 13:
			player.pos = attack.to
		11:
			check(attack.role == "canopy" and Attacks.hints(attack, 0, 1.2).size() == 3, "canopy, relocation path and escort are warned")
		12:
			check(Vector3(attack.anchor).distance_to(attack.from) > 1.6, "lure telegraphs a real alternate pull origin")
			player.pos = attack.to
		14:
			check(attack.spots.size() == 2, "webs leave a gap")
		16:
			check(actor.pos.distance_to(attack.to) > 2.4, "Thief locks the actual drop beyond ordinary reach")
		17:
			check(attack.trail.size() == 2 and Vector3(attack.to).length() < 3.0, "Hart stops short and warns both ember beds")
			player.pos = attack.to


func validate_result(kind: int, actor: Dictionary, attack: Dictionary) -> void:
	match kind:
		6, 14:
			var expected := 3 if kind == 6 else 2
			check(game.enemy_hazards.size() == expected and PlayerVitals.current_hp(player) == 10, "only marked hazard beds are created")
		11:
			check(actor.pos.is_equal_approx(attack.to) and PlayerVitals.current_hp(player) == 10, "Grazer moves without hidden damage")
			var ally: Dictionary = game.encounter.scout(1)
			check(not Support.shelter_source(game, 1, ally.pos, ally.pos, actor.windup, true).is_empty(), "new canopy shelters the same escort")
		16:
			check(game.wild_item_drops.is_empty() and actor.get("stolen", []).size() == 1, "learned grab takes only the locked drop")
		_:
			check(PlayerVitals.current_hp(player) < 10, "warned impact is live for " + str(attack.variant))
	if kind == 1:
		check(actor.windup == 0, "learned pulse consumes the retry without an ordinary repeat")


func check_roster() -> void:
	for kind in Tactics.REGULAR_RESPONSES:
		var profile: Dictionary = Tactics.REGULAR_RESPONSES[kind]
		var actor := setup(kind, profile)
		var now := Time.get_ticks_msec()
		check(Attacks.SkillResponses.ready_profile(game, actor).is_empty(), "history needs a local observation for " + str(profile.id))
		learn(actor, profile, now)
		game.encounter_number = int(profile.floor) - 1
		check(Attacks.SkillResponses.ready_profile(game, actor).is_empty(), "introductory floors are protected for " + str(profile.id))
		game.encounter_number = profile.floor
		var move := arm(actor, profile, now + 1500)
		check(move.get("variant") == profile.id, "AI locks " + str(profile.id) + ", got " + str(move.get("variant")))
		if move.get("variant") != profile.id:
			continue
		check(Attacks.hints(move, 0, 1.2)[0].cue == profile.cue, "cue matches " + str(profile.id))
		check(Attacks.SkillResponses.ready_profile(game, actor).is_empty(), "once per actor for " + str(profile.id))
		validate_plan(kind, actor, move)
		var impact_at: int = actor.windup
		game.resolve_scout(actor, game.Enemies.get_kind(kind), impact_at)
		validate_result(kind, actor, move)
		validate_visibility(kind, move, impact_at)
		if kind == 16:
			game.EnemyBehaviors.death(game, actor, actor.pos)
			Status.sync(game, impact_at)
			check(game.wild_item_drops.size() == 1 and not Status.snapshot(game, impact_at).any(func(e): return e.shape == "trophy_carrier"), "recovering the trophy clears the carrier condition")


func validate_visibility(kind: int, attack: Dictionary, now: int) -> void:
	var releases: Array = game.combat_events.filter(func(e): return e.kind == "enemy_release")
	if kind not in [6, 14]:
		check(not releases.is_empty(), "resolved " + str(attack.variant) + " has a release effect")
	if kind in [0, 7]:
		check(releases.any(func(e): return e.shape == "sector" and is_equal_approx(e.span, attack.span) and is_equal_approx(e.reach, attack.radius)), "sweep release uses the committed span and reach")
	if kind in [5, 18]:
		check(releases.size() == 2 and releases.all(func(e): return is_equal_approx(e.reach, attack.spot_radius)), "each strike releases at its warned size")
	if kind in [6, 14, 17]:
		var hazard_kind: String = {6: "spores", 14: "web", 17: "ember"}[kind]
		var fx: Node = game.combat_visuals
		var warnings: Array = game.Bosses.hints(game).filter(func(h): return h.get("hazard_kind") == hazard_kind)
		check(not warnings.is_empty() and warnings.all(func(h): return h.has("cue") and h.has("remaining") and not h.active), "each pending bed identifies its hazard")
		if not warnings.is_empty():
			var warning: Dictionary = warnings[0]
			var at: Vector3 = fx.point(warning.to)
			fx.sync([], warnings, "hazard-" + hazard_kind, at)
			var preview: Dictionary = fx.hints[warning.id]
			var pending_count: int = preview.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
			check(preview.label.visible and preview.root.visible, "warning label is drawn")
			var active_hint := warning.duplicate()
			active_hint.active = true
			active_hint.erase("cue")
			active_hint.erase("remaining")
			fx.sync([], [active_hint], "hazard-" + hazard_kind, at)
			check(not preview.label.visible and preview.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > pending_count, "active hazard swaps the preview for its own pattern")
	if kind in [5, 12, 14]:
		if kind == 14:
			var web: Dictionary = game.enemy_hazards[0]
			player.pos = web.point
			now = int(web.activate)
			game.Bosses.tick_hazards(game, now)
		Status.sync(game, now)
		check(Status.snapshot(game, now).any(func(e): return e.form == "player" and e.shape == "slow"), "actual hit applies the visible Slowed condition")
		Status.sync(game, int(player.slow_until) + 1)
		check(not Status.snapshot(game, int(player.slow_until) + 1).any(func(e): return e.shape == "slow"), "Slowed clears at expiry")
	if kind == 12:
		check(releases.any(func(e): return e.shape == "pulled" and e.from != e.to), "pull feedback requires real displacement")
	if kind == 11:
		Status.sync(game, now)
		check(Status.snapshot(game, now).any(func(e): return e.form == "enemy" and e.combo == 1 and e.shape == "sheltered"), "escort visibly regains shelter")
	if kind == 16:
		Status.sync(game, now)
		check(Status.snapshot(game, now).any(func(e): return e.form == "enemy" and e.combo == 0 and e.shape == "trophy_carrier"), "successful thief shows trophy carrier")


func check_counterplay() -> void:
	var profile: Dictionary = Tactics.REGULAR_RESPONSES[2]
	var actor := setup(2, profile)
	var now := Time.get_ticks_msec()
	learn(actor, profile, now)
	var move := arm(actor, profile, now + 1500)
	check(move.get("variant") == profile.id, "charge is armed for cancel test")
	if move.get("variant") != profile.id:
		return
	actor.rooted_until = int(actor.windup) + 1
	game.resolve_scout(actor, game.Enemies.get_kind(2), actor.windup)
	check(actor.pos == Vector3.ZERO and PlayerVitals.current_hp(player) == 10 and game.combat_events.any(func(e): return e.shape == "stopped"), "a new root stops movement and shows the cancel cue")
	check(not game.combat_events.any(func(e): return e.kind == "enemy_release"), "canceled charge cannot show a successful impact")
	actor = setup(2, profile)
	learn(actor, profile, now)
	move = arm(actor, profile, now + 1500)
	if move.get("variant") == profile.id:
		game.set_meta(Core.STATE, {1: {"epoch": game.combat_epoch, "grown": true, "life": PlayerLifecycle.generation(player),
			"expires": actor.windup + 500, "from": Vector3(-2, 0, -1.8), "to": Vector3(2, 0, -1.8),
			"skill": {"mechanic": "line_trap", "radius": .35}}})
		game.resolve_scout(actor, game.Enemies.get_kind(2), actor.windup)
		check(actor.pos == Vector3.ZERO and PlayerVitals.current_hp(player) == 10, "a live Thorn Line placed during the warning stops a ground charge")
	actor = setup(2, profile)
	learn(actor, profile, now)
	game.battlefield.barriers.append(Rect2(-2, -2.8, 4, 1.6))
	check(arm(actor, profile, now + 1500).is_empty() and not actor.has("skill_response_used"), "blocked routes leave the response available for later")
	actor.summoned = true
	check(not Tactics.eligible(game, actor, profile.id), "summoned enemies cannot adapt")

	profile = Tactics.REGULAR_RESPONSES[11]
	actor = setup(11, profile)
	learn(actor, profile, now)
	move = arm(actor, profile, now + 1500)
	if move.get("variant") == profile.id:
		var old := Vector3(game.encounter.scout(1).pos)
		game.encounter.register_scout(game.make_scout(0, old, 2), 1)
		game.resolve_scout(actor, game.Enemies.get_kind(11), actor.windup)
		check(actor.pos == Vector3.ZERO, "a recycled escort slot cannot pull the Grazer across the field")


func check_memory() -> void:
	var profile: Dictionary = Tactics.REGULAR_RESPONSES[2]
	game.progress.wilds_memory.score[Tactics.ROUTE_DENIAL] = 0
	for i in 3:
		var actor := setup(2, profile)
		learn(actor, profile, Time.get_ticks_msec())
		game.encounter.set_hp(-1, 0)
		game.encounter.clear_scouts()
		game.finish_combat(1, Vector3.ZERO)
		check(game.progress.wilds_memory.score[Tactics.ROUTE_DENIAL] == (i + 1) * 2, "one learning update per cleared floor")
	var saved = load("res://progress.gd").new()
	saved.path = game.progress.path
	check(saved.load_garden() == OK and saved.wilds_memory.score.get(Tactics.ROUTE_DENIAL) == 6, "route learning survives a host-world reload")
	var independent = load("res://progress.gd").new()
	check(not independent.wilds_memory.score.has(Tactics.ROUTE_DENIAL), "route learning belongs to this host world")


func run() -> void:
	game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/regular-enemy-responses-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player = game.players[1]
	game.progress.wilds_memory.score = {Tactics.CAST_DENIAL: 6, Tactics.ROUTE_DENIAL: 6, Tactics.SHELTER_BREAK: 6}
	check_roster()
	check_counterplay()
	check_memory()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: 14 regular enemy responses, confirmed evidence, hit geometry, fallbacks, and persistence")
	quit(1 if failed else 0)
