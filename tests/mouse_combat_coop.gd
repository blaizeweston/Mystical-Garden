extends SceneTree
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
var game: Node
var role: String
var base: String
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL mouse co-op ",role,": ",message)
func mark(key: String):
 var f=FileAccess.open(base+key,FileAccess.WRITE);f.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+15000
 while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/mouse-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.free()
 if not failed:print("PASS: mouse co-op ",role," held input, authority, direction, cooldown, damage and release")
 quit(1 if failed else 0)
func host_run():
 check(SessionCase.World.host(game)==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"registration");return
 game.set_physics_process(false);game.set_process(false)
 var id=game.players.keys().filter(func(i):return i!=1)[0];var p: Dictionary=game.players[id]
 ExpeditionCase.set_membership(game, p, true);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.pos=Vector3.ZERO;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
 game.encounter.clear_scouts();preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[]);game.tactics.position=Vector3(0,0,-1);game.encounter.set_hp(-1, 10000)
 mark("ready")
 var end=Time.get_ticks_msec()+1400
 while Time.get_ticks_msec()<end:
  var now=Time.get_ticks_msec();game.mouse_controls.tick(game,now);WeaponCase.advance(game,now);await process_frame
 check(p[WeaponActions.STATE].sequence()>=2 and p[WeaponActions.STATE].sequence()<=7,"hold respects authoritative attack speed")
 check(game.enemy_health()<10000 and p.facing.z<-.9,"remote cursor sets direction and hits")
 mark("stop");check(await until(func():return marked("released")),"guest released")
 await create_timer(.1).timeout
 var combo=p[WeaponActions.STATE].sequence();p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);game.mouse_controls.tick(game,Time.get_ticks_msec());check(p[WeaponActions.STATE].sequence()==combo,"remote release stops new attacks")
 mark("done");await create_timer(.3).timeout
func guest_run():
 game.guest_character.save_profile();check(SessionCase.World.join(game)==OK,"guest joins")
 if not await until(func():return game.network_session.role()=="Guest" and marked("ready")):check(false,"ready");return
 while not marked("stop"):
  game.submit_combat.rpc_id(1,Vector2(0,-1),true);await create_timer(.05).timeout
 game.submit_combat.rpc_id(1,Vector2(0,-1),false);await create_timer(.1).timeout;mark("released")
 check(await until(func():return marked("done")),"host verifies");SessionCase.World.leave(game,"mouse fixture")
