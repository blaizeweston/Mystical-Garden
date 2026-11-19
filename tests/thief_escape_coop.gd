extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Escape = preload("res://thief_escape.gd")
var game: Node
var base := ""
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL thief co-op: ",message)


func until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+14000
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await process_frame
	return predicate.call()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var role: String = args[0]
	base = "res://.godot/thief-coop-"+args[1]
	game = load("res://world.tscn").instantiate()
	game.progress.path = base+role+".cfg"
	game.local_character.path = base+role+".character"
	game.guest_character.path = base+role+".guest"
	root.add_child(game)
	if role=="host":
		await host()
	else:
		await guest()
	SessionCase.World.leave(game,"Fixture complete")
	check(game.network_session.transport() == null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "network shuts down before world removal")
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: thief co-op ",role," party alert, moving route, and portal after escape")
	quit(1 if failed else 0)


func host() -> void:
	check(SessionCase.World.host(game)==OK,"host starts")
	if not await until(func(): return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):
		check(false,"guest profile reaches the host")
		return
	var at := Vector3(0,0,-6)
	game.battlefield.configure(0,1,0)
	ExpeditionCase.set_world(game, {"map_seed": 0})
	game.encounter.set_hp(-1, 0)
	game.tactics.winding_up = false
	game.encounter_rewarded = false
	for player in game.players.values():
		ExpeditionCase.set_membership(game, player, true)
		player.pos = at + Vector3(1.0,0,0)
	var thief: Dictionary = game.make_scout(Escape.KIND,at,2)
	game.encounter.clear_scouts();game.encounter.register_scout(thief)
	game.wild_item_drops.assign([{"id":"net-trophy","owner":1,"stack":{"item":game.Items.part_id(game.Parts.monster_part(0)),"quantity":1},
		"position":[at.x,0,at.z]}])
	check(await until(func(): return thief.get("escaped",false) and game.encounter_rewarded),"real host tick frees the portal")
	check(game.wild_item_drops.is_empty() and game.encounter_kills.is_empty() and game.enemy_death_events.is_empty(),"fleeing grants no drop or kill")
	check(await until(func(): return FileAccess.file_exists(base+"guest-saw-escape")),"guest confirms the updated floor")


func guest() -> void:
	check(SessionCase.World.join(game)==OK,"guest connects")
	if not await until(func(): return game.network_session.role()=="Guest" and WorldViewCase.component(game,"map").thief_routes.size()==1 and game.status.contains("stole a trophy")):
		check(false,"thief marker and party alert reach the guest")
		return
	var audio: Node = game.get_node("EventAudio")
	check(await until(func(): return audio.last_played.has("trophy_taken")),"guest receives the dedicated theft cue")
	var first: Vector3 = WorldViewCase.component(game,"map").thief_routes[0].pos
	var tunnel: Vector3 = WorldViewCase.component(game,"map").thief_routes[0].tunnel
	check(not game.stage.wild_portal.visible and WorldViewCase.component(game,"map").thief_tunnels.size()==1,"the tunnel is drawn while the portal is closed")
	check(await until(func(): return not WorldViewCase.component(game,"map").thief_routes.is_empty() and WorldViewCase.component(game,"map").thief_routes[0].pos.distance_to(first)>.35),
		"guest minimap tracks a moving thief")
	check(not WorldViewCase.component(game,"map").thief_routes.is_empty() and WorldViewCase.component(game,"map").thief_routes[0].tunnel==tunnel,"destination stays fixed throughout the chase")
	check(await until(func(): return game.encounter_cleared() and game.stage.wild_portal.visible and WorldViewCase.component(game,"map").thief_routes.is_empty() and WorldViewCase.component(game,"map").thief_tunnels.is_empty()),
		"guest removes both markers and sees the portal light")
	check(await until(func(): return audio.last_played.has("gate_ready")),"guest receives the committed portal cue")
	var receipt := FileAccess.open(base+"guest-saw-escape",FileAccess.WRITE)
	receipt.store_string("ok")
