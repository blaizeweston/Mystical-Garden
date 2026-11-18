extends SceneTree
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Elite=preload("res://elite_enemy.gd")
const Catalog=preload("res://enemy_catalog.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL gate elites: ",message)
func _initialize():
 call_deferred("run")
func run():
 var seen: Dictionary={}
 for site in 3:
  for floor_number in range(1,50):
   var previous:=-1
   for seed_value in range(1,25):
    var kind:=Elite.choose(site,floor_number,seed_value,previous);var entry:=Catalog.get_kind(kind)
    check(not Catalog.is_support(kind) and not entry.get("boss",false) and entry.role!="lure","no helpless supports or bosses in gate pool")
    check(Catalog.in_biome(entry,site) and floor_number>=int(entry.unlock),"biome and unlock respected")
    check(Elite.choose(site,floor_number,seed_value,previous)==kind,"selection uses an isolated deterministic roll")
    check(kind!=previous or Elite.pool(site,floor_number).size()==1,"consecutive selections differ")
    seen[kind]=true;previous=kind
 check(seen.size()==15 and seen.has(9),"fifteen independent species including summoner, observed "+str(seen.size()))
 for kind in seen:
  check(not Elite.empowered(kind).is_empty(),"every elite has a named signature: "+str(kind))
 var game=load("res://world.tscn").instantiate();var token:=str(Time.get_ticks_usec());game.progress.path="res://.godot/elites-"+token;game.local_character.path=game.progress.path+".character";root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.combat_visuals.set_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true);p.pos=Vector3(0,0,.8);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100)
 game.battlefield.configure(0,1);game.battlefield.barriers.clear();game.tactics.boss_kind=-1;ExpeditionCase.set_world(game, {"destination": 0})
 for kind in seen:
  var now:=Time.get_ticks_msec();game.enemy_kind=kind;game.tactics.position=Vector3.ZERO;game.encounter.begin_floor(800);game.tactics.ready_at=0;game.tactics.winding_up=false;game.tactics.engaged=true;game.tactics.stagger_until=0;game.tactics.rooted_until=0;game.enemy_mutations=0;game.tactics.longlimb=false;game.tactics.memory.clear();game.enemy_hazards.clear();game.tactics.recovery_bonus=0;p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Conditions.STATE] = p[Conditions.STATE].clear_grace();p[Protection.STATE] = p[Protection.STATE].clear_guard()
  Elite.tick(game,.016,now)
  check(game.tactics.winding_up and game.tactics.attack_mode==Catalog.get_kind(kind).role,"species attack: "+str(kind))
  var hints:=Elite.hints(game)
  var warning_role: String={0:"enemy_sweep",13:"burrow",14:"volley"}.get(kind,Catalog.get_kind(kind).role)
  var count_matches:=hints.size()==4 if kind==14 else hints.size()>=2 if kind in [9,17] else hints.size()==1
  check(count_matches and hints[0].role==warning_role,"telegraph matches species: "+str(kind))
  Elite.resolve(game,game.tactics.strike_at+1)
  if kind==1:
   check(game.tactics.winding_up and game.encounter.leader_tactics().attack.pulse==2,"Nightbloom keeps its specific second pulse")
   Elite.resolve(game,game.tactics.strike_at+1)
  check(not game.tactics.winding_up and game.tactics.ready_at>now,"recovery is finite: "+str(kind))
  if kind in [2,13]:check(game.enemy_hazards.is_empty(),"elite movement adds no unmarked trails")
  if kind==17:check(not game.enemy_hazards.is_empty(),"Ashen Hart retains its marked ember trail")
  if kind==9:
   check(game.encounter.scout_count()==2 and game.encounter.scout_tactics().all(func(s):return s.get("summoned",false)),"brood elite creates a two-minion wave")
   for i in 5:
    Elite.tick(game,.016,game.tactics.ready_at+1);Elite.resolve(game,game.tactics.strike_at+1)
   check(game.encounter.scout_views().filter(func(s):return s.hp>0 and s.get("elite_brood",false)).size()<=4,"brood has a four-living-child cap")
   game.encounter.set_hp(0, 0);Elite.tick(game,.016,game.tactics.ready_at+1);Elite.resolve(game,game.tactics.strike_at+1);check(game.encounter.scout_views().filter(func(s):return s.hp>0 and s.get("elite_brood",false)).size()==4,"brood can replenish a fallen child")
  game._process(.016)
  var model: Node3D=game.stage.foe_model.model;var growth: Node3D=model.get_node_or_null("EliteGrowth")
  check(is_instance_valid(growth) and growth.get_child_count()>0,"elite has anatomical growth beyond scaling: "+str(kind))
  var count: int=growth.get_child_count();Elite.decorate(game.stage,game.stage.foe_model,true);check(growth.get_child_count()==count,"decoration is cached")
 game.enemy_kind=11;game.encounter.begin_floor(800);game.tactics.position=Vector3.ZERO;game.tactics.memory.clear();game.encounter.register_scout(game.make_scout(0,Vector3(0,0,.5),1));game.encounter.set_hp(0, 200)
 game.apply_weapon_hit(p,0,p.pos,{"damage":4},Time.get_ticks_msec());check(game.encounter.hp(0)==170,"elite Grazer retains its protection aura, hp="+str(game.encounter.hp(0)))
 game.enemy_kind=16;game.encounter.begin_floor(800);game.tactics.memory.clear();var thief:=Elite.state(game);thief.stolen=[{"stack":{"item":"briar_hook","quantity":1},"position":[0,0,0]}];game.wild_item_drops.clear();game.EnemyBehaviors.death(game,thief,Vector3.ZERO);check(game.wild_item_drops.size()==1 and thief.get("stolen",[]).is_empty(),"elite Thief uses the same stolen-loot recovery hook")
 game.enemy_kind=7;ExpeditionCase.set_world(game, {"encounter_number": 12});game.tactics.position=Vector3.ZERO;game.encounter.begin_floor(800)
 game.tactics.winding_up=false;game.tactics.ready_at=0;game.tactics.stagger_until=0;game.tactics.engaged=true
 game.enemy_hazards.clear();game.tactics.memory.clear();p.pos=Vector3(0,0,1.3);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
 var now:=Time.get_ticks_msec()
 Elite.tick(game,.016,now)
 var marked: Array=Elite.hints(game).filter(func(hint):return hint.role=="aftershock")
 check(marked.size()==1,"Colossus previews its offset aftershock before the first stomp")
 Elite.resolve(game,game.tactics.strike_at)
 check(game.enemy_hazards.size()==1 and game.enemy_hazards[0].activate>now,"a delayed aftershock uses the pre-marked point")
 if marked.size()==1 and game.enemy_hazards.size()==1:
  check(game.enemy_hazards[0].point.is_equal_approx(Vector3(marked[0].to[0],0,marked[0].to[2])),"aftershock warning matches its eventual footprint")
 ExpeditionCase.set_world(game, {"map_seed": 883});ExpeditionCase.set_world(game, {"encounter_number": 12});var first:=Elite.select(game);check(Elite.select(game)==first,"resetting same encounter preserves elite identity")
 ExpeditionCase.set_world(game, {"encounter_number": game.participation.floor() + (1)});check(Elite.select(game)!=first,"next floor rotates the elite species")
 game.queue_free();await process_frame
 if not failed:print("PASS: fifteen biome/unlock-gated elites, no solo supports, deterministic rotation, species moves, telegraphs, bounded brood and anatomical upgrades")
 quit(1 if failed else 0)
