extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Attacks = preload("res://enemy_attack.gd")
const Effects = preload("res://core_skill_effects.gd")
const Status = preload("res://combat_status.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const Feint = preload("res://glasscap_feint.gd")
const GlasscapVisuals = preload("res://glasscap_visuals.gd")

var game: Node
var base: String
var failed := false


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL regular responses co-op: ", detail)


func mark(key: String) -> void:
	var file := FileAccess.open(base + key, FileAccess.WRITE)
	file.store_string("ok")


func marked(key: String) -> bool:
	return FileAccess.file_exists(base + key)


func until(predicate: Callable, ms: int = 8000) -> bool:
	var end := Time.get_ticks_msec() + ms
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return predicate.call()


func actor(kind: int, position: Vector3, route: int) -> Dictionary:
	var scout: Dictionary = game.make_scout(kind, position, route)
	scout.engaged = true
	scout.stagger_until = Time.get_ticks_msec() + 60000
	game.encounter.register_scout(scout)
	return scout


func run() -> void:
	var args := OS.get_cmdline_user_args()
	base = "res://.godot/regular-responses-coop-" + args[1]
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
		print("PASS: learned charge, canopy and Watcher swap " + args[0])
	quit(1 if failed else 0)


func prepare(kind: int) -> Dictionary:
	var profile: Dictionary = Tactics.REGULAR_RESPONSES[kind]
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	ExpeditionCase.set_world(game, {"encounter_number": profile.floor})
	ExpeditionCase.set_world(game, {"map_seed": 0})
	game.battlefield.configure(game.participation.route(), game.participation.depth(), game.participation.seed())
	game.battlefield.barriers.clear()
	game.encounter.set_hp(-1, 50)
	game.enemy_kind = 0
	game.tactics.position = Vector3(-11, 0, 6)
	game.tactics.stagger_until = Time.get_ticks_msec() + 60000
	game.encounter.clear_scouts()
	for member in game.players.values():
		ExpeditionCase.set_membership(game, member, true)
		member[PlayerVitals.STATE] = member[PlayerVitals.STATE].with_hp(10)
		member.hurt_until = 0
		member.pos = Vector3(0, 0, -3.4)
	var route := 10 + posmod(-3 * (kind * 19 + int(profile.floor) * 11), 10)
	return actor(kind, Vector3.ZERO, route)


func host() -> void:
	check(SessionCase.World.host(game) == OK, "host starts")
	if not await until(func(): return game.players.size() == 2 and game.players.values().all(func(p): return SessionCase.Session.ready_for(p))):
		check(false, "guest registers")
		return
	var guest_id: int = game.players.keys().filter(func(id): return id != 1)[0]
	game.progress.wilds_memory.score = {Tactics.ROUTE_DENIAL: 6, Tactics.SHELTER_BREAK: 6}
	var stag := prepare(2)
	var host_player: Dictionary = game.players[1]
	var guest_player: Dictionary = game.players[guest_id]
	var now := Time.get_ticks_msec()
	Status.root(game, 0, now + 200)
	if not await until(func(): return Time.get_ticks_msec() >= stag.rooted_until):
		check(false, "ordinary root expires")
		return
	if not Attacks.try_skill_approach(game, stag, host_player.pos, Time.get_ticks_msec()):
		check(false, "host locks both charge legs")
		return
	host_player.pos = stag.attack.via
	guest_player.pos = Vector3(-float(stag.attack.via.x), 0, -1.5)
	if not await until(func(): return marked("seen-charge"), 1000):
		check(false, "guest reads both warned legs before impact")
		return
	check(await until(func(): return stag.windup == 0), "charge resolves")
	check(PlayerVitals.current_hp(host_player) == 9 and PlayerVitals.current_hp(guest_player) == 10, "host damage follows the bend and preserves the dodge")
	mark("charge-resolved")
	if not await until(func(): return marked("charge-clear")):
		check(false, "guest sees charge markers clear")
		return

	var grazer := prepare(11)
	var escort := actor(0, Vector3.RIGHT * 2.35, 1)
	Effects.affect_enemy(game, host_player, 1, Vector3(2, 0, 0), {"id": "riptide"}, {"displace": 1.35}, Time.get_ticks_msec())
	if not Attacks.try_skill_approach(game, grazer, host_player.pos, Time.get_ticks_msec()):
		check(false, "host locks the canopy relocation")
		return
	guest_player.pos = Vector3.RIGHT * 2.8
	if not await until(func(): return marked("seen-canopy"), 1000):
		check(false, "guest reads canopy shift before movement")
		return
	check(await until(func(): return grazer.windup == 0), "canopy resolves")
	check(grazer.pos.x > 2.0 and escort.pos.x > 3.6 and PlayerVitals.current_hp(guest_player) == 10, "Grazer rejoins the displaced escort without dealing damage")
	mark("canopy-resolved")
	if not await until(func(): return marked("canopy-clear")):
		check(false, "guest sees canopy markers clear")
		return
	await host_glasscap()
	SessionCase.World.leave(game,"Regular response fixture")


func warning(cue: String) -> Dictionary:
	for hint in game.combat_visuals.hints.values():
		if hint.has("label") and hint.label.visible and hint.label.text == cue:
			return hint.event
	return {}


func guest() -> void:
	game.guest_character.save_profile()
	check(SessionCase.World.join(game) == OK, "guest connects")
	if not await until(func(): return not warning("Antler hook").is_empty()):
		check(false, "guest sees Antler hook")
		return
	var charge := warning("Antler hook")
	check(game.combat_visuals.hints.values().any(func(h): return h.event.role == "charge" and h.event.from == charge.to and h.event.to != charge.to), "second charge leg starts where the first ends")
	check(not game.stage.support_rings[0].visible, "exact charge paths suppress the legacy circle")
	mark("seen-charge")
	check(await until(func(): return marked("charge-resolved") and warning("Antler hook").is_empty()), "guest sees charge cleanup")
	mark("charge-clear")
	if not await until(func(): return not warning("Canopy shift").is_empty()):
		check(false, "guest sees Canopy shift")
		return
	var canopy := warning("Canopy shift")
	check(canopy.role == "canopy" and game.combat_visuals.hints.values().any(func(h): return h.event.role == "rally_link" and h.event.to == canopy.to), "guest sees the destination and relocation path")
	mark("seen-canopy")
	check(await until(func(): return marked("canopy-resolved") and warning("Canopy shift").is_empty()), "guest sees canopy cleanup")
	check(await until(func(): return game.combat_visuals.statuses.active.values().any(func(item): return item.event.shape == "sheltered" and item.event.combo == 1 and item.node.visible and item.label.text == "Sheltered")), "guest sees the actual sheltered escort")
	mark("canopy-clear")
	await guest_glasscap()
	check(await until(func(): return game.network_session.role() == "Solo"), "host finishes")


func host_glasscap() -> void:
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	ExpeditionCase.set_world(game, {"encounter_number": 12})
	game.progress.wilds_memory.score = {}
	game.encounter.clear_scouts()
	for member in game.players.values():
		member.pos = Vector3(0,0,-1)
	var watcher := actor(18,Vector3.ZERO,3)
	watcher.variant = "early_decoys"
	watcher.growth = 2
	watcher.mutations = game.Enemies.REACH
	var now := Time.get_ticks_msec()
	Attacks.lock(game,watcher,"volley",Vector3(0,0,5),now+4000)
	game.EnemyBehaviors.telegraph(game,watcher,now)
	if not await until(func(): return marked("glass-ready"),3000):
		check(false,"guest sees the formation during wind-up")
		return
	var sites: Array = watcher.glass_feint.points.duplicate()
	preload("res://scout_behavior.gd").release(game, watcher,game.Enemies.get_kind(18),Time.get_ticks_msec())
	check(sites.has(watcher.pos) and game.living_scout_count()==1,"host moves only the real Watcher")
	check(await until(func(): return marked("glass-clear"),3500),"guest sees the formation expire")


func glasscap_formation(released: bool) -> Dictionary:
	for hint in game.stage.get_meta(GlasscapVisuals.POSITIONS,{}).values():
		if hint.role==Feint.ROLE and hint.released==released and game.stage.get_meta(GlasscapVisuals.VIEWS,{}).has(hint.id):
			return hint
	return {}


func guest_glasscap() -> void:
	if not await until(func(): return not glasscap_formation(false).is_empty()):
		check(false,"host's Watcher formation arrives")
		return
	var before := glasscap_formation(false)
	var set_before: Array = before.decoys.duplicate()
	set_before.append(before.real)
	var copies: Array = game.stage.get_meta(GlasscapVisuals.VIEWS,{}).get(before.id,[])
	check(copies.size()==2 and copies.all(func(copy):return (copy.root.scale.is_equal_approx(game.stage.support_models[0].scale)
		and copy.root.find_child("Growth2",true,false).visible and copy.root.find_child("AdaptReach",true,false).visible)),
		"guest renders two bodies matching the live Watcher")
	mark("glass-ready")
	if not await until(func(): return not glasscap_formation(true).is_empty()):
		check(false,"guest sees the completed swap")
		return
	var after := glasscap_formation(true)
	check(before.decoys.has(after.real) and after.decoys.has(before.real) and after.decoys.all(func(point):return set_before.has(point)),
		"guest sees the same occupied positions after the swap")
	check(game.stage.support_models[0].position.is_equal_approx(game.stage.WILD_OFFSET+GlasscapVisuals.point(after.real)),
		"the real render model snaps to the host's swapped location")
	check(await until(func(): return game.stage.get_meta(GlasscapVisuals.VIEWS,{}).is_empty()),"guest removes expired decoys")
	mark("glass-clear")
