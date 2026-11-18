extends SceneTree

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
var game: Node
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL mouse combat: ",message)
func _initialize():call_deferred("run")
func run():
 game=load("res://world.tscn").instantiate();var base="res://.godot/mouse-combat-"+Crypto.new().generate_random_bytes(8).hex_encode();game.progress.path=base;game.local_character.path=base+".character";root.add_child(game);game.set_physics_process(false);game.set_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true);p.pos=Vector3.ZERO;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.weapon=0;p.secondary=0;p.catalyst=0;p.power=0;p.frame=0;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
 game.encounter.clear_scouts();game.battlefield.procedural=false;game.battlefield.barriers=[];game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(0,0,-1);game.ui.close_panels()
 var now=Time.get_ticks_msec();game.mouse_controls.receive(game,1,Vector2(0,1),true,now);game.mouse_controls.tick(game,now)
 game.update_projectiles(int(game.projectile_queue[0].due)+1)
 check(p[WeaponActions.STATE].sequence()==1 and game.enemy_health()==100,"melee faces cursor and misses enemy behind")
 game.mouse_controls.tick(game,now);check(p[WeaponActions.STATE].sequence()==1,"held attack respects cooldown")
 p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);game.mouse_controls.receive(game,1,Vector2(0,-1),true,now);game.mouse_controls.tick(game,now)
 check(p[WeaponActions.STATE].sequence()==2 and not game.projectile_queue.is_empty(),"held strike repeats when weapon ready")
 game.update_projectiles(now+2000);check(game.enemy_health()<100,"forward melee deals shared weapon damage")
 p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);game.mouse_controls.release(game);game.mouse_controls.tick(game,now);check(p[WeaponActions.STATE].sequence()==2,"release stops attack")
 game.mouse_controls.receive(game,1,Vector2(1,0),true,now);game.mouse_controls.tick(game,now+300);check(p[WeaponActions.STATE].sequence()==2,"stale network input stops attack")
 p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);game.mouse_controls.receive(game,1,Vector2(1,0),true,now);game.ui.toggle_panel("session");game.mouse_controls.tick(game,now);check(p[WeaponActions.STATE].sequence()==2,"open menu stops attacks");game.ui.close_panels()
 game.projectile_queue.clear();p.frame=1;p.weapon=0;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);game.tactics.position=Vector3(0,0,-1)
 var stats: Dictionary=game.weapon_stats(p);game.mouse_controls.receive(game,1,Vector2(1,0),true,now)
 game.mouse_controls.queue_attack(game,1,p,p.pos,stats,now,"bow",300)
 check(game.projectile_queue.size()==1 and game.projectile_queue[0].mouse_ray and game.projectile_queue[0].aim.x>0,"ranged attacks fire toward cursor without snapping to enemy")
 var shot: Dictionary=game.projectile_queue[0];var hp=game.enemy_health();game.mouse_controls.ray_tick(game,shot,int(shot.due));check(game.enemy_health()==hp,"projectile misses enemy outside flight path")
 game.tactics.position=Vector3(1,0,0);shot.previous=shot.origin;shot.hits.clear();shot.remaining=1;game.mouse_controls.ray_tick(game,shot,int(shot.due));check(game.enemy_health()<hp,"projectile intersects target along flight path")
 game.projectile_queue.clear()
 p.frame=2;p.weapon_kind=0;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
 p.pos=Vector3.ZERO;game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(1.2,0,3.0)
 now=Time.get_ticks_msec()
 game.mouse_controls.receive(game,1,Vector2(1,0),true,now)
 game.strike_enemy(1,p,p.pos)
 var turning: Dictionary=game.projectile_queue[0]
 var release:=int(turning.release)
 p.pos=Vector3(1.2,0,0)
 game.mouse_controls.receive(game,1,Vector2(0,1),false,release-1)
 var pose: Dictionary=game.attack_animation_snapshot(p)
 check(pose.aim_live and pose.direction.is_equal_approx(Vector3.BACK),"wind-up snapshots show the newest aim")
 game.update_projectiles(release-1)
 check(not turning.emitted and game.enemy_health()==100,"turning the cursor does not fire early")
 game.update_projectiles(release)
 check(turning.emitted and turning.direction.is_equal_approx(Vector3.BACK) and turning.launch_position.is_equal_approx(p.pos),"launch samples the new aim and moved character position")
 var new_muzzle: Vector3=turning.origin
 var new_endpoint: Vector3=turning.aim
 game.mouse_controls.receive(game,1,Vector2(-1,0),false,release+1)
 game.update_projectiles(int(turning.due))
 check(game.enemy_health()<100 and turning.origin==new_muzzle and turning.aim==new_endpoint,"projectile hits on the release line even when the cursor moves again")
 game.free()
 if not failed:print("PASS: cursor melee and projectile direction, shared hit effects, hold cooldown, release, stale input and menu safety")
 quit(1 if failed else 0)
