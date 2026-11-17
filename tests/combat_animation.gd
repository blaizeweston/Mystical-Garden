extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Motion=preload("res://weapon_motion.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL combat animation: ",message)
func _initialize():
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate()
 var token=Crypto.new().generate_random_bytes(8).hex_encode()
 game.progress.path="res://.godot/combat_anim_"+token+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false);game.combat_visuals.set_process(false)
 var p: Dictionary=game.players[1]
 game.destination=0;game.depth=1;game.map_seed=0;game.battlefield.configure(0,1);game.battlefield.barriers=[];game.encounter.clear_scouts()
 p.wild=true;p.pos=Vector3(0,0,4);p.weapon=0;p.secondary=0;p.catalyst=0;p.power=0;p.technique=0;p.run_upgrades={}
 var poses: Array=[];var projectiles:=0
 for c in 5:
  for weapon in 3:
   p.frame=c;p.weapon_kind=weapon;p.strike_at=0
   game.encounter.set_hp(-1, 20);game.enemy_pos=Vector3(0,0,5);game.projectile_queue.clear()
   var form:=Motion.form(p);var pose:=Motion.pose(form,.5,true,0)
   poses.append(str(pose))
   game.strike_enemy(1,p,p.pos)
   check(p.attack_until>Time.get_ticks_msec() and int(p.attack_duration)>0,"weapon has timed attack pose: "+form)
   if Motion.is_projectile(form):
    projectiles+=1
    check(game.enemy_health()==20 and game.projectile_queue.size()==1,"ranged damage waits for projectile: "+form)
    var due: int=game.projectile_queue[0].due
    game.update_projectiles(int(game.projectile_queue[0].release)-1);check(game.enemy_health()==20,"flight cannot hit before weapon release")
    game.update_projectiles(due+1);check(game.enemy_health()<20,"projectile damages on arrival: "+form)
   else:
    check(game.enemy_health()==20,"melee waits for contact: "+form)
    var due: int=game.projectile_queue[0].due
    game.update_projectiles(due-1);check(game.enemy_health()==20,"melee cannot hit before contact")
    game.update_projectiles(due+1);check(game.enemy_health()<20,"melee or pulse delivers at contact: "+form)
   check(not game.combat_events.is_empty(),"attack emits visible effect")
 var unique: Array=[]
 for pose in poses:
  if not unique.has(pose): unique.append(pose)
 check(unique.size()==15 and projectiles==7,"fifteen distinct weapon poses and seven projectile forms")
 p.frame=2;p.weapon_kind=0;p.strike_at=0;game.encounter.set_hp(-1, 20);game.projectile_queue.clear()
 game.strike_enemy(1,p,p.pos)
 var retired: int = PlayerLifecycle.generation(p)
 p[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
 game.update_projectiles(Time.get_ticks_msec()+1000)
 check(not PlayerLifecycle.matches(p,retired) and int(p.lost_health)==0 and game.enemy_health()==20
  and game.projectile_queue.is_empty(),"previous-life projectile cannot hit at the same injury and floor")
 p.strike_at=0
 game.strike_enemy(1,p,p.pos)
 p.lost_health=2
 game.update_projectiles(Time.get_ticks_msec()+1000)
 check(game.enemy_health()<20,"a current-life projectile still hits after an injury-only change")
 p.lost_health=0
 game.projectile_queue.clear()
 # Reused brood slots must not receive a projectile intended for their predecessor.
 p.frame=2;p.weapon_kind=0;p.strike_at=0;game.encounter.set_hp(-1, 0)
 var victim: Dictionary=game.make_scout(0,Vector3(0,0,5),1);victim.hp=20;game.encounter.clear_scouts();game.encounter.register_scout(victim)
 game.strike_enemy(1,p,p.pos)
 game.encounter.register_scout(game.make_scout(0,Vector3(0,0,5),1), 0);game.encounter.set_hp(0, 20)
 game.update_projectiles(Time.get_ticks_msec()+600)
 check(game.encounter.hp(0)==20,"target identity prevents hits on a reused slot")
 verify_ray_contact_batch(game)
 # A marked stag lane matches the real swept charge, not only its final landing.
 var stag: Dictionary=game.make_scout(2,Vector3.ZERO,1);stag.mode="charge";stag.windup=Time.get_ticks_msec()+1000;stag.blast=Vector3(0,0,4)
 game.encounter.clear_scouts();game.encounter.register_scout(stag);game.encounter.set_hp(-1, 0);p.pos=Vector3(0,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.guard_until=0
 var hints: Array=game.attack_hints_snapshot()
 check(hints.size()==1 and hints[0].role=="charge" and Vector3(hints[0].to[0],hints[0].to[1],hints[0].to[2]).distance_to(Vector3(0,0,4))<.1,"charge snapshot carries origin and locked endpoint")
 game.combat_visuals.sync([],hints,"test-lane",p.pos)
 check(game.combat_visuals.hints[0].mesh.mesh.get_surface_count()==1,"directional V lane has visible geometry")
 game.resolve_scout(stag,game.Enemies.get_kind(2),Time.get_ticks_msec()+1000)
 check(PlayerVitals.current_hp(p)==9,"mid-lane player is struck by the projected charge")
 stag.pos=Vector3.ZERO;stag.blast=Vector3(0,0,4);p.pos=Vector3(2.5,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10)
 game.resolve_scout(stag,game.Enemies.get_kind(2),Time.get_ticks_msec()+1000)
 check(PlayerVitals.current_hp(p)==10,"player outside lane and landing marker is safe")
 game.battlefield.barriers=[Rect2(-1.5,1.8,3,.4)];stag.pos=Vector3.ZERO;stag.blast=Vector3(0,0,4);stag.windup=1000
 hints=game.attack_hints_snapshot()
 check(float(hints[0].to[2])<1.8,"charge projection stops before blocking terrain")
 game.combat_visuals.sync([],[],"next-floor",p.pos)
 check(game.combat_visuals.hints.is_empty() and game.combat_visuals.active.is_empty(),"effect cleanup follows floor transitions")
 game.return_to_garden(p)
 check(p.attack_until==0,"Garden return clears attack animation")
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
 game.set_meta(Rules.META,Rules.ID)
 game.set_meta(Events.RECORD,func(event):
  if event.target==str(game.encounter.token(0)):
   game.encounter.register_scout(game.make_scout(0,Vector3(0,0,4),2),1)
   game.encounter.set_hp(1,20))
 var action: RefCounted=Events.begin(game,1,"native_weapon",{}, {},["weapon_contact"],now+1000)
 var shot := {"player":1,"epoch":game.combat_epoch,"form":"bow","origin":Vector3.ZERO,
  "aim":Vector3(0,0,6),"previous":Vector3.ZERO,"release":now-100,"due":now,
  "remaining":2,"hits":[],"stats":{"damage":2,"targets":2,"pattern":"single","knockback":-.35,Events.CONTEXT:action}}
 game.MouseCombat.ray_tick(game,shot,now)
 check(shot.hits.size()==1 and game.encounter.hp(0)<20 and game.encounter.token(1)!=retired
  and game.encounter.hp(1)==20,"a later sampled ray contact cannot hit an enemy that joined the batch's old slot")
 game.remove_meta(Events.RECORD)
 game.remove_meta(Rules.META)
