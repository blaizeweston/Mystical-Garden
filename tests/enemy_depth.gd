extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
var failed=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL enemy depth: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/enemy-depth-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true);p.pos=Vector3.ZERO;p[PlayerVitals.STATE] = PlayerVitals.Health.new(10, 10)
 game.battlefield.configure(0,1);game.battlefield.barriers=[];game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(0,0,1)
 for kind in range(13,24):
  var part=game.Parts.monster_part(kind);p.graft_part=part;p.run_upgrades={}
  check(game.Parts.DEFINITIONS[part].monster==kind,"stable trophy mapping")
  var card=game.RunUpgrades.get_upgrade("trophy_"+game.Enemies.get_kind(kind).id)
  check(game.RunUpgrades.requirement(card,p).is_empty(),"graft unlocks its card")
  var before: Dictionary=game.weapon_stats(p);p.run_upgrades[card.id]=1
  var after: Dictionary=game.weapon_stats(p)
  for key in card.effects: check(float(after.get(key,0))>float(before.get(key,0)),"card reaches real weapon stats: "+str(key))
  p.graft_part=0;check(not game.RunUpgrades.requirement(card,p).is_empty(),"card requires matching trophy")
 var synergy_tags: Array=[]
 for seed in game.Seeds.DEFINITIONS:
  for tag in seed.tags:
   if not synergy_tags.has(tag): synergy_tags.append(tag)
 for entry in game.RunUpgrades.all():
  if not str(entry.id).begins_with("trophy_"): continue
  for tag in entry.get("plant_tags",[]):check(synergy_tags.has(tag),"synergy is reachable: "+tag)
 p.graft_part=game.Parts.monster_part(13);p.run_upgrades={}
 check(game.weapon_stats(p).pattern=="line","Burrowing Tendon changes strikes into penetrating lines")
 # New actor mechanics exercise shared combat and drop ownership.
 var web=game.make_scout(14,Vector3(0,0,4),1);web.mode="snare";web.blast=Vector3.ZERO
 preload("res://scout_behavior.gd").release(game, web,game.Enemies.get_kind(14),1000);check(game.enemy_hazards.size()==4,"Widow weaves a line of delayed webs")
 var thief=game.make_scout(16,Vector3.ZERO,1)
 game.wild_item_drops=[{"id":"stolen","owner":1,"stack":{"item":"monster_0","quantity":1},"position":[0,0,0]}]
 game.EnemyBehaviors.tick(game,thief,.1,1000)
 check(thief.windup>1000 and game.wild_item_drops.size()==1,"Thief warns before grabbing the loose trophy")
 preload("res://scout_behavior.gd").release(game, thief,game.Enemies.get_kind(16),int(thief.windup))
 check(game.wild_item_drops.is_empty() and thief.get("stolen",[]).size()==1,"Thief takes the marked trophy after its warning")
 game.EnemyBehaviors.death(game,thief,Vector3(1,0,0))
 check(game.wild_item_drops.size()==1 and game.wild_item_drops[0].owner==1,"stolen trophy recovered with original owner")
 var pall=game.make_scout(15,Vector3.ZERO,1);var dead=game.make_scout(0,Vector3(0,0,1),2);dead.hp=0
 game.encounter.clear_scouts();game.encounter.register_scout(pall);game.encounter.register_scout(dead);pall.mode="chant";game.encounter.set_hp(0, game.encounter.hp(0)-2)
 var hp: int=game.encounter.hp(0);preload("res://scout_behavior.gd").release(game, pall,game.Enemies.get_kind(15),2000);check(game.encounter.hp(0)==hp+2,"Pallbearer consumes a corpse")
 hp=game.encounter.hp(0);preload("res://scout_behavior.gd").release(game, pall,game.Enemies.get_kind(15),3000);check(game.encounter.hp(0)==hp,"one corpse cannot be farmed repeatedly")
 p.graft_part=game.Parts.monster_part(17);p.run_upgrades={};game.encounter.clear_scouts();game.tactics.position=Vector3.ZERO;game.encounter.set_hp(-1, 100)
 game.apply_weapon_hit(p,-1,p.pos,game.weapon_stats(p),4000)
 hp=game.enemy_health();game.Traits.tick(game,4100);check(game.enemy_health()<hp,"Cinder graft creates actual damaging ground")
 p.graft_part=game.Parts.monster_part(19);game.trait_events.clear();p.chorus_contacts=0
 game.encounter.register_scout(game.make_scout(0,Vector3(.5,0,0),1));game.encounter.set_hp(0, 30)
 for i in 4:game.apply_weapon_hit(p,-1,p.pos,game.weapon_stats(p),5000+i*100)
 game.Traits.tick(game,5700);check(game.encounter.hp(0)<30,"Chorus graft releases a bounded nearby pulse")
 check(load("res://content_validator.gd").validate().is_empty(),"all catalog contracts validate")
 game.queue_free();await process_frame
 if not failed:print("PASS: eleven new trophy/card integrations, web hazards, corpse consumption, recoverable stolen loot, Cinder fields and Chorus pulses")
 quit(1 if failed else 0)
