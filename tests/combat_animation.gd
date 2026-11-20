extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Motion=preload("res://weapon_motion.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL combat animation: ",message)
func _initialize():
 call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/combat_anim_"+token+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false);WorldViewCase.component(game,"combat").set_process(false)
 var p: Dictionary=game.players[1]
 ExpeditionCase.set_world(game, {"destination": 0});ExpeditionCase.set_world(game, {"depth": 1});ExpeditionCase.set_world(game, {"map_seed": 0});game.battlefield.configure(0,1);preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[]);game.encounter.clear_scouts()
 ExpeditionCase.set_membership(game, p, true);p.pos=Vector3(0,0,4);p.weapon=0;p.secondary=0;p.catalyst=0
 var poses: Array=[];var projectiles:=0
 for c in 5:
  for weapon in 3:
   p.frame=c;p.weapon_kind=weapon;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
   var tree=game.Classes.connected_tree(c)
   p.character[tree.profile_key]=tree.state([tree.nodes[0].id])
   game.encounter.set_hp(-1, 20);game.tactics.position=Vector3(0,0,5);game.weapon_attacks.clear()
   var form:=Motion.form(p);var pose:=Motion.pose(form,.5,true,0)
   poses.append(str(pose))
   WeaponCase.start(game,1,p.pos)
   check(p[WeaponActions.STATE].pose_until_ms()>Time.get_ticks_msec() and int(p[WeaponActions.STATE].duration_ms())>0,"weapon has timed attack pose: "+form)
   if Motion.is_projectile(form):
    projectiles+=1
    check(game.enemy_health()==20 and game.weapon_attacks.pending_count()==1,"ranged damage waits for projectile: "+form)
    var due: int=game.weapon_attacks.views()[0].due
    WeaponCase.advance(game,int(game.weapon_attacks.views()[0].release)-1);check(game.enemy_health()==20,"flight cannot hit before weapon release")
    WeaponCase.advance(game,due+1);check(game.enemy_health()<20,"projectile damages on arrival: "+form)
   else:
    check(game.enemy_health()==20,"melee waits for contact: "+form)
    var due: int=game.weapon_attacks.views()[0].due
    WeaponCase.advance(game,due-1);check(game.enemy_health()==20,"melee cannot hit before contact")
    WeaponCase.advance(game,due+1);check(game.enemy_health()<20,"melee or pulse delivers at contact: "+form)
   check(not game.combat_events.is_empty(),"attack emits visible effect")
 var unique: Array=[]
 for pose in poses:
  if not unique.has(pose): unique.append(pose)
 check(unique.size()==15 and projectiles==7,"fifteen distinct weapon poses and seven projectile forms")
 p.frame=2;p.weapon_kind=0;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);game.encounter.set_hp(-1, 20);game.weapon_attacks.clear()
 WeaponCase.start(game,1,p.pos)
 var retired: int = PlayerLifecycle.generation(p)
 p[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
 WeaponCase.advance(game,Time.get_ticks_msec()+1000)
 check(not PlayerLifecycle.matches(p,retired) and int(p.lost_health)==0 and game.enemy_health()==20
  and game.weapon_attacks.is_empty(),"previous-life projectile cannot hit at the same injury and floor")
 p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
 WeaponCase.start(game,1,p.pos)
 p.lost_health=20
 WeaponCase.advance(game,Time.get_ticks_msec()+1000)
 check(game.enemy_health()<20,"a current-life projectile still hits after an injury-only change")
 p.lost_health=0
 game.weapon_attacks.clear()
 # Reused brood slots must not receive a projectile intended for their predecessor.
 p.frame=2;p.weapon_kind=0;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);game.encounter.set_hp(-1, 0)
 var victim: Dictionary=game.make_scout(0,Vector3(0,0,5),1);victim.hp=20;game.encounter.clear_scouts();game.encounter.register_scout(victim)
 WeaponCase.start(game,1,p.pos)
 game.encounter.register_scout(game.make_scout(0,Vector3(0,0,5),1), 0);game.encounter.set_hp(0, 20)
 WeaponCase.advance(game,Time.get_ticks_msec()+600)
 check(game.encounter.hp(0)==20,"target identity prevents hits on a reused slot")
 verify_ray_contact_batch(game)
 # A marked stag lane matches the real swept charge, not only its final landing.
 var stag: Dictionary=game.make_scout(2,Vector3.ZERO,1);stag.mode="charge";stag.windup=Time.get_ticks_msec()+1000;stag.blast=Vector3(0,0,4)
 game.encounter.clear_scouts();game.encounter.register_scout(stag);game.encounter.set_hp(-1, 0);p.pos=Vector3(0,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Protection.STATE] = p[Protection.STATE].clear_guard()
 var hints: Array=game.attack_hints_snapshot()
 check(hints.size()==1 and hints[0].role=="charge" and Vector3(hints[0].to[0],hints[0].to[1],hints[0].to[2]).distance_to(Vector3(0,0,4))<.1,"charge snapshot carries origin and locked endpoint")
 WorldViewCase.component(game,"combat").sync([],hints,"test-lane",p.pos)
 check(WorldViewCase.component(game,"combat").hints[0].mesh.mesh.get_surface_count()==1,"directional V lane has visible geometry")
 preload("res://scout_behavior.gd").release(game, stag,game.Enemies.get_kind(2),Time.get_ticks_msec()+1000)
 check(PlayerVitals.current_hp(p)<100 and PlayerVitals.current_hp(p)>0,"mid-lane player is struck by the projected charge")
 stag.pos=Vector3.ZERO;stag.blast=Vector3(0,0,4);p.pos=Vector3(2.5,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
 preload("res://scout_behavior.gd").release(game, stag,game.Enemies.get_kind(2),Time.get_ticks_msec()+1000)
 check(PlayerVitals.current_hp(p)==100,"player outside lane and landing marker is safe")
 preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[Rect2(-1.5,1.8,3,.4)]);stag.pos=Vector3.ZERO;stag.blast=Vector3(0,0,4);stag.windup=1000
 hints=game.attack_hints_snapshot()
 check(float(hints[0].to[2])<1.8,"charge projection stops before blocking terrain")
 WorldViewCase.component(game,"combat").sync([],[],"next-floor",p.pos)
 check(WorldViewCase.component(game,"combat").hints.is_empty() and WorldViewCase.component(game,"combat").active.is_empty(),"effect cleanup follows floor transitions")
 game.expedition_transitions.return_member(preload("res://network_session.gd").peer_for(p))
 check(p[WeaponActions.STATE].pose_until_ms()==0,"Garden return clears attack animation")
 game.free()
 if not failed: print("PASS: fifteen weapon motions, seven delayed projectile forms, impact events, target identity, stag chevrons, swept damage, safe lanes and terrain clipping")
 quit(1 if failed else 0)


func verify_ray_contact_batch(game: Node) -> void:
 var Rules = preload("res://combat_ruleset.gd")
 var Events = preload("res://combat_action_events.gd")
 game.encounter.clear_scouts()
 game.encounter.register_scout(game.make_scout(0,Vector3(0,0,2),1))
 game.encounter.register_scout(game.make_scout(0,Vector3(0,0,4),2))
 game.encounter.set_hp(0,20)
 game.encounter.set_hp(1,20)
 var retired: int=game.encounter.token(1)
 var now:=Time.get_ticks_msec()

 game.set_meta(Events.RECORD,func(event):
  if event.target==str(game.encounter.token(0)):
   game.encounter.register_scout(game.make_scout(0,Vector3(0,0,4),2),1)
   game.encounter.set_hp(1,20))
 var action: RefCounted=Events.begin(game,1,"native_weapon",{}, {},["weapon_contact"],now+1000)
 var stats := {"damage":2,"targets":2,"pattern":"single","knockback":-.35,"reach":6.0,Events.CONTEXT:action}
 var p: Dictionary=game.players[1]
 p.pos=Vector3.ZERO;p.mouse_aim=true;p.aim_direction=Vector3.BACK
 WeaponCase.schedule(game,1,Vector3.ZERO,stats,now,"bow",0)
 WeaponCase.advance(game,int(game.weapon_attacks.views().back().due)+1)
 check(game.encounter.hp(0)<20 and game.encounter.token(1)!=retired
  and game.encounter.hp(1)==20,"a later sampled ray contact cannot hit an enemy that joined the batch's old slot")
 game.remove_meta(Events.RECORD)
