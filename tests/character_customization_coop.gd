extends SceneTree
const Appearance = preload("res://character_appearance.gd")
const SessionCase = preload("res://tests/support/session_case.gd")
const Expedition = preload("res://tests/support/expedition_case.gd")
var game: Node
var role := ""
var base := ""
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failed=true; printerr("FAIL customization co-op ",role,": ",message)
func mark(key: String) -> void:
	var file := FileAccess.open(base+key,FileAccess.WRITE)
	file.store_string("ok")
func marked(key: String) -> bool: return FileAccess.file_exists(base+key)
func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+18000
	while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
	return condition.call()
func starting_look() -> Array:
	var look := Appearance.DEFAULT.duplicate()
	look[5]=1; look[3]=2; look[6]=100; look[7]=0
	look[Appearance.HOOD]=0; look[Appearance.SHOULDER_ARMOR]=0; look[Appearance.BRACERS]=1; look[Appearance.BELTS]=0
	return look
func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	base="res://.godot/character-customization-"+OS.get_cmdline_user_args()[1]
	game=preload("res://world.tscn").instantiate()
	game.progress.path=base+role+".garden"; game.local_character.path=base+role+".character"; game.guest_character.path=base+role+".guest"
	root.add_child(game)
	if role=="host": await host_run()
	else: await guest_run()
	if game.network_session.transport()!=null: game.session_world.leave("Character customization fixture")
	game.queue_free(); await process_frame
	if not failed: print("PASS: customization co-op ",role," registration, independent flags, authoritative changes, Wilds locking and profile recovery")
	quit(1 if failed else 0)
func host_run() -> void:
	check(game.session_world.host()==OK,"host opens")
	if not await until(func(): return game.players.size()==2 and game.players.values().all(func(p): return SessionCase.Session.ready_for(p))): check(false,"registration"); return
	var id: int = game.players.keys().filter(func(peer): return peer!=1)[0]
	var player: Dictionary = game.players[id]
	check(player.character.appearance==starting_look(),"host receives every saved appearance field")
	mark("ready")
	if not await until(func(): return player.character.appearance[Appearance.HOOD]==1): check(false,"host authorizes guest hood change"); return
	var expected := starting_look(); expected[Appearance.HOOD]=1
	check(player.character.appearance==expected,"hood request cannot change body, hairstyle, sliders or other accessories")
	mark("changed")
	if not await until(func(): return marked("projected")): check(false,"guest receives authoritative profile and snapshot"); return
	for action in ["look_9","look_13","look_-1","look_05","look_bad"]: game.garden_action(id,action)
	check(player.character.appearance==expected,"invalid indices cannot reach unrelated fields")
	Expedition.set_membership(game,player,true)
	game.garden_action(id,"look_6")
	check(player.character.appearance==expected,"host rejects expedition appearance edits")
	Expedition.set_membership(game,player,false)
	mark("done")
	check(await until(func(): return game.players.size()==1),"guest leaves safely")
func guest_run() -> void:
	game.guest_character.data.appearance=starting_look()
	check(game.guest_character.save_profile()==OK,"isolated guest profile saves")
	check(game.session_world.join()==OK,"guest joins")
	if not await until(func(): return game.network_session.role()=="Guest" and game.players.has(game.local_player_id()) and marked("ready")): check(false,"guest admission"); return
	var id: int = game.local_player_id()
	check(await until(func(): return Array(game.players[id].appearance)==starting_look()),"unchanged-size snapshot carries all cosmetic flags")
	game.send_garden_action("look_5")
	if not await until(func(): return marked("changed") and game.guest_character.data.appearance[Appearance.HOOD]==1 and game.players[id].appearance[Appearance.HOOD]==1): check(false,"authoritative hood update"); return
	var expected := starting_look(); expected[Appearance.HOOD]=1
	check(game.guest_character.data.appearance==expected and Array(game.players[id].appearance)==expected,"profile and public projection agree")
	mark("projected")
	check(await until(func(): return marked("done")),"host finishes")
	game.session_world.leave("Character customization fixture")
	var restored := preload("res://character_profile.gd").new(); restored.path=game.guest_character.path
	check(restored.load_profile()==OK and restored.data.appearance==expected,"guest profile retains independent cosmetics after departure")
