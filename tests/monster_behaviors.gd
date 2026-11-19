extends SceneTree
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Attacks=preload("res://enemy_attack.gd")
const Status=preload("res://combat_status.gd")
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL monster behaviors: ",message)
func _initialize():
 call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/monster-behaviors-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p=game.players[1];ExpeditionCase.set_membership(game, p, true);p.pos=Vector3(0,0,4);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
 game.battlefield.configure(0,1);preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[]);game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(0,0,5);game.enemy_mutations=0
 var shepherd=game.make_scout(10,Vector3(1,0,6),1);shepherd.mode="shepherd"
 var escort=game.make_scout(0,Vector3(0,0,6),2);game.encounter.clear_scouts();game.encounter.register_scout(shepherd);game.encounter.register_scout(escort);preload("res://scout_behavior.gd").release(game, shepherd,game.Enemies.get_kind(10),2000)
 check(int(escort.get("command_target",0))==1 and int(escort.get("command_until",0))>2000,"Shepherd coordinates its escorts against a live target")
 check(game.Director.target(game,escort.pos,escort,2100)==1,"command is respected by common targeting")
 game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();game.encounter.register_scout(game.make_scout(10,shepherd.pos,1));preload("res://enemy_formation.gd").arrange(game)
 check(not game.Enemies.is_support(int(game.encounter.scout(0).kind)),"Shepherd cannot spawn without escorts")
 var grazer=game.make_scout(11,Vector3(1,0,5),3);game.encounter.clear_scouts();game.encounter.register_scout(grazer);game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(0,0,5)
 OutgoingHits.hit_world(game, HitSession.peer_for(p), -1, p.pos, {"damage":4}, 3000)
 check(game.enemy_health()==70,"living grazer reduces the 40-damage hit by 25 percent")
 game.encounter.set_hp(0, 0);OutgoingHits.hit_world(game, HitSession.peer_for(p), -1, p.pos, {"damage":4}, 3200)
 check(game.enemy_health()==30,"protection ends immediately when grazer dies")
 var lure=game.make_scout(12,Vector3(0,0,7),4);lure.mode="lure";lure.blast=Vector3(0,0,4);lure.windup=4000
 p.pos=lure.blast;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Conditions.STATE] = p[Conditions.STATE].clear_grace();p[Protection.STATE] = p[Protection.STATE].clear_guard()
 var lure_damage: int=game.Life.Preview.effect_hp(game.Director.Balance.scout_hit(game,game.Enemies.get_kind(12),lure))
 preload("res://scout_behavior.gd").release(game, lure,game.Enemies.get_kind(12),4000)
 check(PlayerVitals.current_hp(p)==100-lure_damage and p.pos.z>4.5 and p[Conditions.STATE].slow_until_ms()>4000,"Lure damages, slows and pulls only at its telegraphed point")
 p.pos=Vector3(3,0,4);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);lure.mode="lure";lure.blast=Vector3(0,0,4)
 preload("res://scout_behavior.gd").release(game, lure,game.Enemies.get_kind(12),5000)
 check(PlayerVitals.current_hp(p)==100 and p.pos==Vector3(3,0,4),"dodging the lure circle avoids damage and forced movement")
 ExpeditionCase.set_world(game, {"encounter_number": 5})
 var now:=Time.get_ticks_msec()+2000
 var origin:=Vector3(-6.5,0,-4.5)
 var target:=Vector3(-6.5,0,-1)
 game.battlefield.configure(0,1)
 var hart: Dictionary=game.make_scout(17,origin,1,game.Enemies.MOBILITY)
 var landing:=Attacks.vault_target(game,hart,target)
 check(landing.is_finite(),"mobile charger can select a legal cover vault")
 var widow: Dictionary=game.make_scout(14,origin,1,game.Enemies.MOBILITY)
 check(not Attacks.vault_target(game,widow,target).is_finite(),"web caster keeps its attack instead of borrowing a vault")
 game.encounter.clear_scouts();game.encounter.register_scout(hart)
 Attacks.lock(game,hart,"vault",landing,now)
 var vault: Dictionary=game.attack_hints_snapshot().filter(func(h):return h.id==0)[0]
 check(vault.role=="vault" and hart.attack.variant==Attacks.VAULT_ID and vault.to[2]==landing.z,"vault announces the committed move and landing")
 p.pos=landing;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Conditions.STATE] = p[Conditions.STATE].clear_grace();p[Protection.STATE] = p[Protection.STATE].clear_guard()
 var hart_damage: int=game.Life.Preview.effect_hp(game.Director.Balance.scout_hit(game,game.Enemies.get_kind(17),hart))
 preload("res://scout_behavior.gd").release(game, hart,game.Enemies.get_kind(17),now)
 check(hart.pos==landing and PlayerVitals.current_hp(p)==100-hart_damage and game.enemy_hazards.is_empty(),"Hart vault lands without using its charge trail")

 hart.pos=origin
 Attacks.lock(game,hart,"vault",landing,now+1000)
 preload("res://tests/support/terrain_case.gd").add_wall(game.battlefield,Rect2(landing.x-.2,landing.z-.2,.4,.4))
 preload("res://scout_behavior.gd").release(game, hart,game.Enemies.get_kind(17),now+1000)
 check(hart.pos==origin and PlayerVitals.current_hp(p)==100-hart_damage,"invalidated landing cancels without an unmarked hit")
 preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])

 var stag: Dictionary=game.make_scout(2,Vector3.ZERO,1)
 game.encounter.clear_scouts();game.encounter.register_scout(stag)
 Attacks.lock(game,stag,"charge",Vector3(0,0,4),now+2000)
 var corridor: Dictionary=game.attack_hints_snapshot().filter(func(h):return h.id==0)[0]
 check(is_equal_approx(corridor.width,stag.attack.width+Attacks.CONTACT_PADDING),"charge warning includes collision padding")
 p.pos=Vector3(corridor.width-.02,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
 var stag_damage: int=game.Life.Preview.effect_hp(game.Director.Balance.scout_hit(game,game.Enemies.get_kind(2),stag))
 preload("res://scout_behavior.gd").release(game, stag,game.Enemies.get_kind(2),now+2000)
 check(PlayerVitals.current_hp(p)==100-stag_damage,"charge hits just inside its marked lane")
 stag.pos=Vector3.ZERO
 Attacks.lock(game,stag,"charge",Vector3(0,0,4),now+3000)
 p.pos=Vector3(corridor.width+.02,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
 preload("res://scout_behavior.gd").release(game, stag,game.Enemies.get_kind(2),now+3000)
 check(PlayerVitals.current_hp(p)==100,"charge misses just outside its marked lane")

 widow.pos=Vector3.ZERO
 game.encounter.clear_scouts();game.encounter.register_scout(widow)
 Attacks.lock(game,widow,"snare",Vector3(0,0,4),now+4000)
 var web_hints: Array=game.attack_hints_snapshot().filter(func(h):return h.get("actor",-1)==0)
 check(web_hints.size()==4 and web_hints.all(func(h):return h.pose=="snare"),"Widow projects all four web locations from one cast")
 preload("res://scout_behavior.gd").release(game, widow,game.Enemies.get_kind(14),now+4000)
 check(game.enemy_hazards.size()==4,"the committed web cast creates exactly four hazards")
 for i in mini(web_hints.size(),game.enemy_hazards.size()):
  var point: Vector3=game.enemy_hazards[i].point
  check(is_equal_approx(point.z,web_hints[i].to[2]) and is_equal_approx(game.enemy_hazards[i].radius,web_hints[i].radius),"web warning matches hazard footprint")

 game.encounter.clear_scouts();game.encounter.register_scout(lure);p.pos=Vector3(0,0,4);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Conditions.STATE] = p[Conditions.STATE].clear_grace();p[Conditions.STATE] = p[Conditions.STATE].cleanse_slow()
 lure.pos=Vector3(0,0,7);lure.ready=0;lure.windup=0;lure.engaged=true
 preload("res://scout_behavior.gd").tick(game, .016,now+5000)
 check(lure.windup>0 and lure.blast==p.pos,"live Lure aims its circle at a target instead of itself")
 var snare_due: int=lure.windup
 preload("res://scout_behavior.gd").release(game, lure,game.Enemies.get_kind(12),snare_due-1)
 check(lure.windup==snare_due and PlayerVitals.current_hp(p)==100 and p[Conditions.STATE].slow_until_ms()==0,"committed Lure cannot resolve before its real windup")
 var snare_damage: int=game.Life.Preview.effect_hp(game.Director.Balance.scout_hit(game,game.Enemies.get_kind(12),lure))
 preload("res://scout_behavior.gd").release(game, lure,game.Enemies.get_kind(12),snare_due)
 Status.sync(game,snare_due)
 check(PlayerVitals.current_hp(p)==100-snare_damage and p[Conditions.STATE].slow_until_ms()>snare_due and Status.snapshot(game,snare_due).any(func(event):return event.shape=="slow" and event.combo==1),"landed snare damages and displays Slowed at the real release time")

 var memory: Dictionary=game.Learning.blank()
 memory.score={"ranged":8,"choke":8}
 for stamp in 20:
  check(game.Learning.traits(memory,8,stamp)==game.Learning.traits(memory,8,stamp,{"ranged":4,"choke":4}),"older and newer measurements of the same pressure use one roll")
  check(game.Learning.traits(memory,1,stamp,{"ranged":8})==0,"opening encounters ignore adaptation")
 for kind in [10,11,12]:
  var part=game.Parts.monster_part(kind)
  check(part>0 and game.Items.get_item(game.Items.part_id(part)).monster_tags.has(game.Enemies.get_kind(kind).id),"each new monster has a species-specific graft part")
 game.queue_free();await process_frame
 if not failed:print("PASS: Shepherd commands and escorts, Grazer protection, Lure telegraph and unique graft components")
 quit(1 if failed else 0)
