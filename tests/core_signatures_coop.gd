extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")

const Core = preload("res://core_combat.gd")
const Mark = preload("res://core_strike_mark.gd")
var game: Node
var role: String
var base: String
var failed := false


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Core signatures co-op ", role, ": ", message)


func mark(key: String) -> void:
	var file := FileAccess.open(base + "-" + key, FileAccess.WRITE)
	file.store_string("ok")


func marked(key: String) -> bool:
	return FileAccess.file_exists(base + "-" + key)


func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 11000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()


func run() -> void:
	role = OS.get_cmdline_user_args()[0]
	base = "res://.godot/signature-net-" + OS.get_cmdline_user_args()[1]
	game = load("res://world.tscn").instantiate()
	game.progress.path = base + role + ".cfg"
	game.local_character.path = base + role + ".character"
	game.guest_character.path = base + role + ".guest"
	root.add_child(game)
	if role == "host":
		await host_run()
	else:
		await guest_run()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Core signatures co-op ", role, " guest mark, ally burst, private hover, public star and recast beam")
	quit(1 if failed else 0)


func host_run() -> void:
	check(game.host_game() == OK, "host opens")
	if not await until(func(): return game.players.size() == 2 and game.players.values().all(func(p): return p.profile_ready)):
		check(false, "guest registers")
		return
	var id: int = game.players.keys().filter(func(peer): return peer != 1)[0]
	var host: Dictionary = game.players[1]
	var guest: Dictionary = game.players[id]
	game.destination = 0;game.encounter_number = 1;game.depth = 1;game.map_seed = 0
	game.battlefield.configure(0,1,0)
	game.enemy_kind = 0;game.encounter.set_hp(-1, 30);game.tactics.position = Vector3(0,0,-2.3)
	game.tactics.winding_up = false;game.enemy_mutations = 0;game.tactics.boss_kind = -1
	game.tactics.stagger_until = Time.get_ticks_msec() + 25000
	game.encounter.clear_scouts()
	for p in [host,guest]:
		p.wild=true;p.pos=Vector3.ZERO;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10)
	host.weapon = game.Parts.index_of("plant:star_orchid")
	guest.frame = 2;guest.weapon_kind = 0
	guest.weapon = game.Parts.index_of("rare:whispervine")
	if not await until(func(): return game.enemy_traits.has(Mark.STATE) and marked("mark-visible")):
		check(false, "guest marks and sees the enemy")
		return
	check(game.enemy_traits[Mark.STATE].owner == id and game.enemy_health() == 30, "guest marks on host authority")
	game.apply_weapon_hit(host,-1,host.pos,{"damage":1,"knockback":-.35},Time.get_ticks_msec())
	check(game.enemy_health() == 27 and not game.enemy_traits.has(Mark.STATE), "host hit consumes guest mark once")
	game.tactics.stagger_until = Time.get_ticks_msec() + 15000
	if not await until(func(): return marked("burst-visible")):
		check(false, "guest receives the consumed mark")
		return
	game.garden_action(1,Core.request(game,host,Vector2(0,-1),1.5))
	if not await until(func(): return marked("anchor-visible")):
		check(false, "guest sees the host star")
		return
	game.tactics.position=Vector3(1.2,0,-1.5)
	var star: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
	if star.is_empty():
		check(false,"star is still charging")
		return
	game.mouse_controls.receive(game,1,Vector2.RIGHT,false,int(star.fires_at)-1)
	check(await until(func(): return Core.hints(game).is_empty() and game.tactics.rooted_until>Time.get_ticks_msec()),"host star automatically roots the enemy along the new aim")
	if not await until(func(): return marked("beam-visible")):
		check(false, "guest sees beam and anchored marker clears")
		return
	mark("done")
	check(await until(func(): return game.players.size() == 1), "guest disconnects")


func guest_run() -> void:
	game.guest_character.save_profile()
	check(game.join_game()==OK, "guest connects")
	var id := game.multiplayer.get_unique_id()
	if not await until(func(): return game.session=="Guest" and game.player_hud.state.get("core",{}).get("name")=="Whisper Mark"):
		check(false, "guest receives its skill HUD")
		return
	var p: Dictionary=game.players[id]
	var hud: Control=game.player_hud
	check(hud.core_icon.resource_path.ends_with("whisper_mark.png") and hud.skill_hover[2].tooltip_text.contains("next direct hit"),"guest gets the matching icon and tooltip")
	check(not game.players[1].has("core_state") and not game.players[1].has("weapon_stats"),"host ability details remain private")
	game.send_garden_action(Core.request(game,p,Vector2(0,-1)))
	var status := func(): return game.combat_visuals.statuses.active.values().any(func(item): return item.event.shape=="core_strike_mark")
	if not await until(status):
		check(false, "guest sees Core Mark status")
		return
	check(hud.state.core.remaining>0 and hud.core_icon.resource_path.ends_with("whisper_mark.png"),"icon persists during cooldown")
	mark("mark-visible")
	if not await until(func(): return not status.call() and game.received_combat_events.any(func(entry): return entry.event.shape=="core_mark_burst")):
		check(false, "guest sees mark burst and removal")
		return
	mark("burst-visible")
	var star := func(): return game.combat_visuals.hints.values().any(func(item): return item.event.role=="core_anchor")
	if not await until(star):
		check(false,"guest sees the other player's anchor")
		return
	mark("anchor-visible")
	check(await until(func(): return not star.call() and game.received_combat_events.any(func(entry): return entry.event.kind=="swing" and entry.event.shape=="constellation")),"guest sees beam and star removal")
	mark("beam-visible")
	check(await until(func(): return marked("done")), "host completes")
	game.leave_game("Signature fixture")
