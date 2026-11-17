extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Attacks=preload("res://enemy_attack.gd")
const Variants=preload("res://enemy_variants.gd")
const Status=preload("res://combat_status.gd")
const Feint=preload("res://glasscap_feint.gd")
const GlasscapVisuals=preload("res://glasscap_visuals.gd")
const Elite=preload("res://elite_enemy.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:
  failed=true
  printerr("FAIL enemy variants: ",message)
func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func actor(game: Node,kind: int,variant: String,at:=Vector3.ZERO) -> Dictionary:
 var result: Dictionary=game.make_scout(kind,at,2)
 result.variant=variant
 return result
func run() -> void:
 var game=load("res://world.tscn").instantiate()
 var path: String="res://.godot/variant-"+str(Time.get_ticks_usec())
 game.progress.path=path;game.local_character.path=path+".character"
 root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 game.battlefield.configure(0,1);game.battlefield.barriers.clear()
 game.encounter.set_hp(-1, 0)
 var p: Dictionary=game.players[1]
 ExpeditionCase.set_membership(game, p, true);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.pos=Vector3(0,0,5)
 var now:=Time.get_ticks_msec()
 ExpeditionCase.set_world(game, {"encounter_number": 2})
 game.progress.wilds_memory.score={"ranged":20,"choke":20,"kite":20,"burst":20}
 for kind in Variants.PROFILES:
  check(Variants.choose(game,kind,2).is_empty(),"opening floor protects players")
 ExpeditionCase.set_world(game, {"encounter_number": 12})
 for kind in Variants.PROFILES:
  var eligible:=false;var baseline:=false
  for stamp in 10:
   ExpeditionCase.set_world(game, {"map_seed": stamp})
   var choice:=Variants.choose(game,kind,2)
   check(choice==Variants.choose(game,kind,2),"same host history and seed choose the same variant")
   eligible=eligible or choice==Variants.PROFILES[kind].id
   baseline=baseline or choice.is_empty()
  check(eligible and baseline,"base and adapted forms both remain in the pool")

 var stag:=actor(game,2,"angled_charge")
 check(Variants.prepare(game,stag,p.pos,.4,now) and absf(stag.pos.x)>.5 and stag.pos.z<0,"Stag sets up a new straight lane")
 var wasp:=actor(game,8,"wide_flank")
 check(Variants.prepare(game,wasp,p.pos,.4,now) and wasp.pos.x<-.5,"Wasp makes an opposing flank approach")

 var hound:=actor(game,4,"")
 game.combat_velocity[1]=Vector3.RIGHT*4
 var normal_aim:=Attacks.aim(game,hound,"pounce",1)
 hound.variant="leading_pounce"
 var long_aim:=Attacks.aim(game,hound,"pounce",1)
 check(long_aim.x>normal_aim.x+.5,"pounce leads an observed moving target farther")
 game.combat_velocity.clear()
 Attacks.lock(game,hound,"pounce",long_aim,now+1000)
 p.pos=long_aim*.5;p.hurt_until=0
 preload("res://scout_behavior.gd").release(game, hound,game.Enemies.get_kind(4),now+1000)
 check(PlayerVitals.current_hp(p)==10 and hound.pos.distance_to(long_aim)<.05,"pounce has a landing hit rather than a swept lane")

 var burrow:=actor(game,13,"bent_seam")
 Attacks.lock(game,burrow,"charge",Vector3(0,0,5),now+2000)
 var seam: Dictionary=Attacks.hints(burrow.attack,0,1.0)[0]
 check(seam.role=="burrow" and seam.has("via") and seam.has("cue"),"bent seam announces both legs and the eruption")
 p.pos=burrow.attack.via;p.hurt_until=0
 preload("res://scout_behavior.gd").release(game, burrow,game.Enemies.get_kind(13),now+2000)
 check(PlayerVitals.current_hp(p)==10 and burrow.pos==Vector3(0,0,5),"crossing the seam outside the eruption is safe")
 burrow.pos=Vector3.ZERO
 check(not Attacks.plan(game,burrow,"charge",Vector3(0,0,1.5)).via.is_finite(),"short paths fall back to a straight seam")
 var hart:=actor(game,17,"cutoff_charge")
 p.pos=Vector3(0,0,5)
 Attacks.lock(game,hart,"charge",Attacks.aim(game,hart,"charge",1),now+3000)
 var cutoff: Vector3=hart.attack.to
 var trail: Array=hart.attack.trail.duplicate()
 check(absf(cutoff.x)>1 and trail.size()==3 and trail[0].distance_to(trail[1])>1.7,"Hart cuts across an open lane and leaves gaps between embers")
 check(Attacks.hints(hart.attack,0,1.0).size()==4,"Hart previews its three ember patches")
 p.pos=Vector3(-4,0,4);game.enemy_hazards.clear()
 preload("res://scout_behavior.gd").release(game, hart,game.Enemies.get_kind(17),now+3000)
 check(game.enemy_hazards.size()==3 and game.enemy_hazards[1].point==trail[1],"ember positions stay locked through release")

 var pilgrim:=actor(game,0,"bark_guard")
 game.encounter.clear_scouts();game.encounter.register_scout(pilgrim)
 Attacks.lock(game,pilgrim,"swipe",Vector3(0,0,3),now+5000)
 check(Variants.guards(pilgrim,Vector3(0,0,3),now+4200) and not Variants.guards(pilgrim,Vector3(0,0,-3),now+4200),"guard protects the front and leaves the rear open")
 Status.sync(game,now+4200)
 check(Status.snapshot(game,now+4200).any(func(e):return e.shape=="bark_guard" and e.form=="enemy"),"Bark Guard has a visible condition")
 p.pos=Vector3(0,0,-1);p.hurt_until=0
 preload("res://scout_behavior.gd").release(game, pilgrim,game.Enemies.get_kind(0),now+5000)
 check(PlayerVitals.current_hp(p)==10,"sweep respects the sector rather than hitting behind the Pilgrim")

 var night:=actor(game,1,"late_pulse")
 night.repeat=1
 Attacks.lock(game,night,"volley",Vector3(0,0,5),now+6000)
 preload("res://scout_behavior.gd").release(game, night,game.Enemies.get_kind(1),now+6000)
 check(night.windup==now+7000 and Attacks.hints(night.attack,0,1.0)[0].cue=="Delayed pulse" and night.attack.pulse==2,"late pulse is separately telegraphed")
 var orchid:=actor(game,6,"offset_spores")
 Attacks.lock(game,orchid,"artillery",Vector3(0,0,5),now+7000)
 var patches: Array=orchid.attack.patches.duplicate()
 check(patches.size()==2 and patches[0].distance_to(patches[1])>orchid.attack.radius*2,"Orchid marks two distinct patches with a gap")
 game.enemy_hazards.clear();p.pos=Vector3(0,0,5)
 preload("res://scout_behavior.gd").release(game, orchid,game.Enemies.get_kind(6),now+7000)
 check(PlayerVitals.current_hp(p)==10 and game.enemy_hazards.size()==2 and game.enemy_hazards[1].activate>game.enemy_hazards[0].activate,"Orchid fields activate later and in order")

 var willow:=actor(game,5,"root_line")
 Attacks.lock(game,willow,"snare",Vector3(0,0,5),now+8000)
 check(Attacks.hints(willow.attack,0,1.0).size()==2,"Willow projects its two root areas")
 p.pos=willow.attack.spots[0];p.hurt_until=0
 preload("res://scout_behavior.gd").release(game, willow,game.Enemies.get_kind(5),now+8000)
 Status.sync(game,now+8000)
 check(Status.snapshot(game,now+8000).any(func(e):return e.shape=="slow" and e.form=="player"),"root line displays Slowed on a hit")
 var widow:=actor(game,14,"split_web")
 var web:=Attacks.plan(game,widow,"snare",Vector3(0,0,5))
 check(web.spots.size()==4 and absf(web.spots[0].x)>1.5 and absf(web.spots[2].x)>1.5,"split web keeps an open central lane")
 var fallback:=Attacks.plan(game,widow,"snare",Vector3(0,0,1.5))
 check(fallback.variant=="" and fallback.spots[0]==Vector3.ZERO,"narrow web plan falls back to a straight cast")

 check_glasscap(game,p,now+8000)
 game.queue_free()
 await process_frame
 if not failed:print("PASS: eleven normal/adapted species, legal movement, matching warnings, delayed hazards and visible conditions")
 quit(1 if failed else 0)


func check_glasscap(game: Node, p: Dictionary, now: int) -> void:
 ExpeditionCase.set_world(game, {"destination": 0});ExpeditionCase.set_world(game, {"depth": 1});ExpeditionCase.set_world(game, {"map_seed": 0});game.tactics.boss_kind=-1
 game.battlefield.configure(0,1,0);game.battlefield.barriers.clear()
 game.progress.wilds_memory.score={}
 p.pos=Vector3(0,0,-1)
 var watcher:=actor(game,18,"early_decoys")
 watcher.growth=2;watcher.mutations=game.Enemies.BARK
 game.encounter.clear_scouts();game.encounter.register_scout(watcher)
 Attacks.lock(game,watcher,"volley",Vector3(0,0,5),now+950)
 game.EnemyBehaviors.telegraph(game,watcher,now)
 var points: Array=watcher.glass_feint.points.duplicate()
 check(points.size()==2,"Watcher forms two decoys in an open arena")
 if points.size()!=2:return
 check(points[0].distance_to(points[1])>=Feint.SPACING and points.all(func(at):return Vector3(at).length()>=3.0 and not game.battlefield.occupied(at,.46)),
  "decoys spread out on safe ground")
 game._process(.016)
 var clones: Array=game.stage.get_meta(GlasscapVisuals.VIEWS,{}).get(watcher.glass_feint.id,[])
 check(clones.size()==2 and clones.all(func(copy):return (copy.root.basis.is_equal_approx(game.stage.support_models[0].basis)
  and copy.root.find_child("Growth2",true,false).visible and copy.root.find_child("AdaptBark",true,false).visible)),
  "scout decoys match the real scale, growth and adaptations")
 var real_pos: Vector3=watcher.pos
 preload("res://scout_behavior.gd").release(game, watcher,game.Enemies.get_kind(18),now+950)
 check(points.has(watcher.pos) and watcher.glass_feint.points.has(real_pos),"casting swaps the real Watcher with one decoy")
 check(Feint.holding(game,watcher,now+1000) and game.living_scout_count()==1,"recovery preserves the feint with one real target")
 game._process(.016)
 check(game.stage.support_models[0].position.is_equal_approx(game.stage.WILD_OFFSET+watcher.pos),"the real model snaps to its swapped hit location")
 check(Feint.hints(game,now+2600).is_empty(),"the decoys expire after recovery")

 game.encounter.set_hp(0, 0)
 game._process(.016)
 check(game.stage.get_meta(GlasscapVisuals.VIEWS,{}).is_empty(),"decoys clear with the real Watcher")

 game.encounter.clear_scouts();game.enemy_kind=18;game.encounter.set_hp(-1, 30);game.tactics.position=Vector3.ZERO
 var elite: Dictionary=Elite.state(game)
 elite.variant="early_decoys"
 Attacks.lock(game,elite,"volley",Vector3(0,0,5),now+3900)
 game.tactics.winding_up=true;game.tactics.attack_mode="volley";game.tactics.landing=elite.attack.to
 game.EnemyBehaviors.telegraph(game,elite,now+2800)
 var elite_points: Array=elite.glass_feint.points.duplicate()
 game._process(.016)
 var elite_copies: Array=game.stage.get_meta(GlasscapVisuals.VIEWS,{}).get(elite.glass_feint.id,[])
 check(elite_copies.size()==2 and elite_copies.all(func(copy):return (copy.root.basis.is_equal_approx(game.stage.foe.basis)
  and copy.root.find_child("EliteGrowth",true,false)!=null)),"guardian decoys include the elite model and its actual scale")
 Elite.resolve(game,now+3900)
 check(elite_points.has(game.tactics.position),"the gate elite changes its authoritative position too")

 game.encounter.set_hp(-1, 0);game.tactics.winding_up=false
 watcher.hp=20;watcher.pos=Vector3.ZERO
 game.encounter.clear_scouts();game.encounter.register_scout(watcher)
 Attacks.lock(game,watcher,"volley",Vector3(0,0,5),now+5000)
 game.EnemyBehaviors.telegraph(game,watcher,now+4100)
 var second: Array=watcher.glass_feint.points
 check(second!=points,"successive casts choose a different formation")
 for at in second:
  game.battlefield.barriers.append(Rect2(Vector2(at.x,at.z)-Vector2(.35,.35),Vector2(.7,.7)))
 preload("res://scout_behavior.gd").release(game, watcher,game.Enemies.get_kind(18),now+5000)
 check(watcher.pos==Vector3.ZERO and not watcher.has("glass_feint"),"blocked decoys never become the real enemy")
