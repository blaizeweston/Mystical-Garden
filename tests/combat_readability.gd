extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")
const Hurt=preload("res://enemy_hurtbox.gd")
const Motion=preload("res://weapon_motion.gd")
const Feedback=preload("res://combat_feedback.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL combat readability: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();var token=str(Time.get_ticks_usec())
 game.progress.path="res://.godot/readability-"+token+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.combat_visuals.set_process(false)
 var p: Dictionary=game.players[1];p.wild=true;p.pos=Vector3.ZERO;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.power=0;p.weapon=0;p.secondary=0;p.catalyst=0
 game.encounter.clear_scouts();game.depth=1;game.destination=0;game.battlefield.configure(0,1);game.battlefield.barriers=[]
 game.enemy_mutations=0;game.enemy_growth=0;game.enemy_pos=Vector3(0,0,2)
 for kind in 24:
  game.enemy_kind=kind;game.boss_kind=kind if kind>=20 else -1
  var definition: Dictionary=game.Enemies.get_kind(kind)
  check(definition.has("hitbox") and str(definition.hitbox.shape)=="body_circle","species explicitly defines a reusable body profile: "+str(kind))
  var body=load("res://assets/enemies/"+str(definition.id)+".glb").instantiate();root.add_child(body)
  var core: MeshInstance3D=body.find_child("EnemyCore",true,false)
  var box: AABB=core.global_transform*core.get_aabb()
  var extent:=maxf(maxf(absf(box.position.x),absf(box.end.x)),maxf(absf(box.position.z),absf(box.end.z)))
  check(float(definition.hitbox.radius)+.03>=extent,"profile covers the actual model core: "+str(definition.id)+" extent="+str(extent)+" radius="+str(definition.hitbox.radius))
  body.free()
  var radius:=Hurt.radius(game,-1)
  check(radius>.3,"authored body footprint: "+str(kind))
  check(not Hurt.sweep(game,-1,Vector3(-5,0,2+radius*.85),Vector3(5,0,2+radius*.85)).is_empty(),"body edge and high-speed sweep hit: "+str(kind))
  check(Hurt.sweep(game,-1,Vector3(-5,0,2+radius+.3),Vector3(5,0,2+radius+.3)).is_empty(),"outside silhouette misses: "+str(kind))
 game.enemy_kind=0;game.boss_kind=-1
 var ordinary:=Hurt.radius(game,-1);game.depth=2
 check(Hurt.radius(game,-1)>ordinary*1.2,"leader render scale applies to hit region")
 game.depth=1;game.enemy_mutations=game.Enemies.JUVENILE;game.enemy_growth=2
 check(absf(Hurt.radius(game,-1)-ordinary*.65*1.14)<.0001,"growth and juvenile scale match renderer")
 game.enemy_mutations=0;game.enemy_growth=0;game.battlefield.barriers=[Rect2(-2,.9,4,.2)]
 check(Hurt.sweep(game,-1,Vector3.ZERO,Vector3(0,0,4)).is_empty(),"wall prevents a body-edge hit through terrain")
 game.enemy_kind=20;game.boss_kind=20
 var contact:=Hurt.contact(game,-1,Vector3.ZERO)
 check(not game.battlefield.clear_line(Vector3.ZERO,contact),"large melee footprint cannot reach through overlapping cover")
 game.enemy_kind=0;game.boss_kind=-1
 game.enemy_pos=Vector3(sin(1.15)*1.8,0,cos(1.15)*1.8)
 var edge_stats={"pattern":"single","reach":2.0}
 check(game.MouseCombat.contact(game,Vector3.ZERO,Vector3(0,0,2),game.enemy_contact_point(-1,Vector3.ZERO),edge_stats,"blade",-1),"visible flank intersects a melee arc despite its center being outside")
 game.enemy_pos=Vector3(0,0,-1)
 check(not game.MouseCombat.contact(game,Vector3.ZERO,Vector3(0,0,2),game.enemy_contact_point(-1,Vector3.ZERO),edge_stats,"blade",-1),"body-aware melee still misses an enemy behind the player")
 game.enemy_pos=Vector3(0,0,3)
 check(not game.MouseCombat.contact(game,Vector3.ZERO,Vector3(0,0,2),game.enemy_contact_point(-1,Vector3.ZERO),edge_stats,"blade",-1),"body-aware melee still respects maximum reach")
 game.enemy_pos=Vector3(0,0,2)
 game.battlefield.barriers=[];game.encounter.set_hp(-1, 1)
 var stats: Dictionary=game.weapon_stats(p);stats.damage=9
 game.apply_weapon_hit(p,-1,p.pos,stats,Time.get_ticks_msec())
 var impact: Dictionary=game.combat_events.filter(func(e):return e.kind=="impact").back()
 check(impact.amount==1 and impact.target_id==-1,"finishing blow displays actual remaining HP, not overkill")
 game.encounter.set_hp(-1, 30);game.enemy_pos=Vector3(0,0,2);game._process(.016)
 var fx=game.combat_visuals;fx.clear();fx.sync([impact,impact],[],"test",Vector3.ZERO)
 check(fx.feedback.labels.size()==1,"duplicate RPC/detail events produce one damage number")
 check(fx.feedback.flashes.size()==1,"confirmed contact flashes the enemy silhouette")
 fx.step(.18);check(fx.feedback.flashes.is_empty(),"flash restores original materials")
 fx.step(1);check(fx.feedback.labels.is_empty(),"damage text expires")
 fx.clear();fx.sync([impact],[],"fog",Vector3(25,0,25))
 check(fx.feedback.labels.is_empty() and fx.feedback.flashes.is_empty(),"unseen combat creates no text or flash through fog")
 # Real cursor projectile crosses the first body, stops its visual and cannot hit the second.
 p.frame=2;p.weapon_kind=0;p.strike_at=0;p.attack_until=0;p.cast_until=0;p.mouse_aim=true;p.aim_direction=Vector3.RIGHT
 game.encounter.set_hp(-1, 30);game.enemy_pos=Vector3(1,0,0);game.encounter.clear_scouts();game.encounter.register_scout(game.make_scout(0,Vector3(2,0,0),1));game.encounter.set_hp(0, 30)
 game.projectile_queue.clear();game.combat_events.clear();game.strike_enemy(1,p,p.pos)
 var shot: Dictionary=game.projectile_queue[0];shot.remaining=1
 game.update_projectiles(int(shot.due))
 check(game.enemy_health()<30 and game.encounter.hp(0)==30,"single-target shot hits the first swept body only")
 check(game.combat_events.any(func(e):return e.kind=="projectile_end"),"confirmed projectile hit terminates flight visual")
 fx.clear();fx.sync(game.combat_events_snapshot(),[],"projectile",p.pos)
 check(not fx.active.values().any(func(e):return e.event.kind=="projectile"),"hit projectile is removed from rendered effects")
 # Every ability family has a distinct mesh and a readable name; no legacy ring needed.
 game.combat_events.clear();fx.clear()
 for mode in ["guard","growth","bind","charge","salvo","quake"]:
  game.emit_combat_event("ability",mode,Vector3.ZERO,Vector3(0,0,2),.8,Color("#a6e5bc"),2,1)
 fx.sync(game.combat_events_snapshot(),[],"abilities",p.pos);fx.step(.2)
 check(fx.active.size()==6 and fx.feedback.labels.size()==6,"six ability families have geometry and labels")
 check(Feedback.family("guard")!=Feedback.family("bind") and Feedback.family("salvo")!=Feedback.family("growth"),"control, guard, ranged and restore styles differ")
 var actor: Dictionary={};var packet={"active":true,"phase":.1,"combo":12,"duration":500,"form":"weapon"}
 Motion.advance(actor,packet,1.0/240)
 for i in 24:Motion.advance(actor,packet,1.0/240)
 check(float(actor.motion_phase)>.29,"guest pose advances between network packets")
 packet.phase=.12;var after:=Motion.advance(actor,packet,.001)
 check(after.phase>.29,"late phase cannot rewind an ongoing attack")
 p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.guard_until=Time.get_ticks_msec()+2000;p.guard_charges=1;p.hurt_until=0
 game.combat_events.clear();game.apply_enemy_hit(1,p,Time.get_ticks_msec(),1)
 check(PlayerVitals.current_hp(p)==10 and game.combat_events.back().shape=="block","blocked contact is labeled without inventing damage")
 var delayed: Dictionary=game.combat_events.back().duplicate();delayed.age=.7;delayed.duration=.85
 var key:=str([game.destination,game.encounter_number,game.map_seed])
 game.received_combat_events.assign([{"event":delayed,"key":key,"born":Time.get_ticks_msec()}])
 var received: Array=game.guest_combat_events({})
 check(received.size()==1 and float(received[0].age)>=.7,"delayed event keeps host age rather than restarting its animation")
 # Rollback drops damage and its visual event together.
 game.combat_events.clear();game.encounter.set_hp(-1, 30);var old_hp: int=game.enemy_health()
 var committed=game.Transactions.run(game,func():game.apply_weapon_hit(p,-1,p.pos,stats,Time.get_ticks_msec());game.SaveBatch.failure=ERR_CANT_CREATE)
 check(committed==false and game.enemy_health()==old_hp and game.combat_events.is_empty(),"rolled-back damage cannot leave a confirmed-hit event")
 fx.sync([],[],"garden",Vector3.ZERO);check(fx.feedback.labels.is_empty() and fx.feedback.flashes.is_empty(),"floor cleanup includes labels and material overlays")
 game.queue_free();await process_frame
 if not failed:print("PASS: 24 scaled body footprints, swept edge hits, cover, confirmed damage, visual termination, fog, six ability families, smooth packet phases and rollback")
 quit(1 if failed else 0)
