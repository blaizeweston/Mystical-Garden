extends SceneTree
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL movement co-op ",role,": ",message)
func mark(key: String):
 var f=FileAccess.open(base+key,FileAccess.WRITE);f.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/movement-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 Input.action_release("right");game.free()
 if not failed:print("PASS: movement co-op ",role," predicted input, authoritative acknowledgements, release convergence and timing diagnostics")
 quit(1 if failed else 0)
func host_run():
 check(game.host_game()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):check(false,"registration");return
 var id: int=game.players.keys().filter(func(i):return i!=1)[0]
 check(await until(func():return game.net_motion.servers.has(id) and game.net_motion.servers[id].ack>0),"new movement channel receives and consumes commands")
 var initial: Vector3=game.players[id].pos
 mark("ready")
 check(await until(func():return marked("released")),"guest finishes movement")
 check(initial.distance_to(game.players[id].pos)>2.0,"host simulates guest travel")
 check(await until(func():return marked("verified")),"guest verifies convergence")
 game.diagnostic_watch.tick(true);mark("done")
 check(await until(func():return game.players.size()==1),"guest disconnects")
func guest_run():
 game.guest_character.save_profile();check(game.join_game()==OK,"guest connects")
 if not await until(func():return game.session=="Guest" and game.players.has(game.multiplayer.get_unique_id())):check(false,"state arrives");return
 var id:=game.multiplayer.get_unique_id()
 game.overlay.hide()
 check(await until(func():return marked("ready")),"host ready")
 Input.action_press("right")
 var until_ms:=Time.get_ticks_msec()+1200
 while Time.get_ticks_msec()<until_ms:await process_frame
 Input.action_release("right");mark("released")
 check(await until(func():return int(game.players[id].get("motion_ack",{}).get("ack",0))>30),"acknowledgements reach guest")
 var stopped_at:=Time.get_ticks_msec()+700
 while Time.get_ticks_msec()<stopped_at:await process_frame
 var before: Vector3=game.players[id].pos
 var stable_until:=Time.get_ticks_msec()+300
 while Time.get_ticks_msec()<stable_until:await process_frame
 check(before.distance_to(game.players[id].pos)<.15,"release settles without runaway correction")
 check(game.net_motion.pending.size()<20,"unacknowledged history stays bounded")
 game.diagnostic_watch.tick(true)
 check(game.net_motion.last_packet_ms>0,"movement timing observes snapshots")
 mark("verified");check(await until(func():return marked("done")),"host finishes");game.leave_game("Movement fixture")
