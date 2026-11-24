extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")
var game: Node
var failed:=false
func check(value: bool,message: String):
	if not value: failed=true;printerr("FAIL seed co-op: ",message)
func _initialize(): call_deferred("run")
func until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+15000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func run():
	var mode: String=OS.get_cmdline_user_args()[0]
	game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/seed_coop_"+mode+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	game.local_character.path=game.progress.path+".character"
	game.guest_character.path=game.progress.path+".guest"
	root.add_child(game)
	if mode=="host":
		check(game.session_world.host()==OK,"host opens")
		print("SEED HOST READY")
		if not await until(func(): return game.players.size()==2):
			check(false,"guest joins");quit(1);return
		var id: int=game.players.keys()[1]
		if not await until(func(): return SessionCase.Session.ready_for(game.players[id])):
			check(false,"guest profile ready");quit(1);return
		check(game.players[id].character.plants[14]==8 and game.players[id].character.plants[23]==12,"all 24 familiarity entries transfer")
		var p: Dictionary=game.players[id]
		p.pos=game.stage.altar_position()
		game.progress.discover(0)
		game.progress.discover(3)
		var reserve: Dictionary=game.seed_reserve(p)
		reserve.stock[0]=1
		reserve.stock[3]=1
		reserve.parts[17]=2
		reserve.stock[23]=3;reserve.parts[game.Seeds.DEFINITIONS[23].part]=2;game.progress.discover(23)
		check(await until(func(): return reserve.stock[4]==1),"guest breeds with private seeds")
		check(game.progress.discoveries[4] and game.progress.stock[4]==0,"host owns discovery; resulting seed stays private")
		check(reserve.stock[0]==0 and reserve.stock[3]==0,"parents consumed once on host")
		await create_timer(1).timeout
	else:
		game.guest_character.data.plants[14]=8
		game.guest_character.data.plants[23]=12
		game.guest_character.save_profile()
		check(game.session_world.join()==OK,"guest connects")
		if not await until(func(): return game.network_session.role()=="Guest" and game.guest_replication.inventory().size()>6 and game.guest_replication.inventory()[6][3]==1):
			check(false,"expanded inventory arrives");quit(1);return
		var id: int=game.multiplayer.get_unique_id()
		check(game.players[id].reserve_parts[17]==2,"expanded private part inventory arrives")
		check(game.guest_replication.inventory()[6][23]==3 and game.players[id].reserve_parts[game.Seeds.DEFINITIONS[23].part]==2,"last new seed and material synchronize privately")
		game.send_altar_action("combine",[{"source":"stash","item":game.Items.seed_id(0)},{"source":"stash","item":game.Items.seed_id(3)}],1)
		check(await until(func(): return game.guest_replication.garden_progress().size()>13 and game.guest_replication.garden_progress()[13][4] and game.guest_replication.inventory()[6][4]==1),"seed and permanent tree discovery synchronize")
		check(game.guest_replication.inventory()[6][0]==0 and game.guest_replication.inventory()[6][3]==0,"updated parent counts synchronize")
		game.ui.toggle_panel("progression")
		UIFixture.control(game,"progression_view").refresh()
		check(UIFixture.control(game,"progression_view").known_flags()[4],"guest tree reads hosted discoveries")
	if not failed: print("PASS: seed co-op "+mode)
	quit(1 if failed else 0)
