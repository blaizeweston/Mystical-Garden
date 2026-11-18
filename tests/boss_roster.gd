extends SceneTree

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Lairs=preload("res://boss_lair_fights.gd")
const Phases=preload("res://boss_phase_fights.gd")
var failed=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL bosses: ",message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game=load("res://world.tscn").instantiate()
 game.progress.path="res://.godot/boss-roster-"+str(Time.get_ticks_usec())+".cfg";game.local_character.path=game.progress.path+".character"
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true);p[PlayerVitals.STATE] = PlayerVitals.Health.new(100, 100)
 check(game.Enemies.all().size()==24 and game.Parts.MONSTER_DEFINITIONS.size()==24,"twenty regular enemies plus four bosses and matching components")
 var normal={}
 for floor_number in range(1,40):
  for seed_value in range(1,40):
   for slot in [0,1,2,4]:
    var kind=game.Enemies.choose(seed_value%3,floor_number,slot,seed_value);normal[kind]=true
    check(kind<20,"boss excluded from normal spawn selector")
 check(normal.size()==20,"all twenty ordinary enemies remain available")
 var selected=0;var used: Array=[]
 for floor_number in range(1,3000):
  var kind=game.Bosses.choose(floor_number,0,100+floor_number,used)
  if floor_number<10: check(kind==-1,"opening expedition protected")
  if kind>=0: check(not used.has(kind),"boss cannot repeat");used.append(kind);selected+=1
 check(selected==4,"all four distinct bosses can occur in a sufficiently long run")
 check(game.Bosses.choose(500,3,1,[])==-1,"Heart finale does not roll expedition threats")
 var rolls=0
 for seed_value in 10000:
  if game.Bosses.choose(20,0,seed_value,[])>=0: rolls+=1
 check(rolls>170 and rolls<340,"rare 2.5 percent per eligible floor")
 for kind in range(20,24):
  ExpeditionCase.set_membership(game, p, false)
  ExpeditionCase.Transitions.reset(game);ExpeditionCase.set_world(game, {"destination": 0});ExpeditionCase.set_world(game, {"encounter_number": 20});ExpeditionCase.set_world(game, {"depth": 2});ExpeditionCase.set_world(game, {"map_seed": 9871})
  game.boss_floors["20"]=kind;game.used_bosses.append(kind);game.reset_encounter()
  check(game.tactics.boss_kind==kind and game.enemy_kind==kind and game.enemy_health()>=500,"boss installed as primary actor")
  check(game.battlefield.connected(),"boss lair connects entry, gate, altar and cache")
  check(game.battlefield.boss_kind==kind,"authority uses lair geometry")
  var guest_field=load("res://battlefield.gd").new();guest_field.configure(0,2,9871,kind,0)
  check(guest_field.clearings==game.battlefield.clearings and guest_field.barriers==game.battlefield.barriers,"guest deterministic lair")
  if kind==20: check(game.battlefield.clearings[0].z==22,"Orchard has a broad oversized arena")
  var count: int=game.used_bosses.size();game.reset_encounter()
  check(game.tactics.boss_kind==kind and game.used_bosses.size()==count,"combat reset preserves floor decision")
  var packet: PackedInt32Array=game.campaign_snapshot()
  check(packet[game.EncounterConfig.BOSS_KIND]==kind,"public map descriptor in snapshot")
  ExpeditionCase.set_membership(game, p, true);p[PlayerLifecycle.STATE] = p[PlayerLifecycle.STATE].clear_inactive();p.pos=Vector3(0,0,2);p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(100);p.hurt_until=0
  for move in game.Enemies.get_kind(kind).moves:
   game.tactics.position=Vector3(0,0,5);game.enemy_hazards.clear()
   if Lairs.Routes.supports(kind):
    check(Lairs.commit(game,move,1,1000),"lair commits "+move)
   else:
    check(Phases.commit(game,move,1,1000),"phase fight commits "+move)
   game.Bosses.resolve(game,1000)
   check(not game.tactics.winding_up and game.tactics.ready_at>1000,"move resolves with recovery: "+move)
  check(game.enemy_hazards.size()<=32,"boss hazard budget")
  if kind==22:
   check(game.encounter.scout_tactics().any(func(s):return s.get("summoned",false)),"Matriarch actually breeds finite nonrewarding minions")
   for phase in 3:
    game.battlefield.configure(0,2,9871,kind,phase);check(game.battlefield.connected(),"reshaped nest remains connected")
  game.stage.draw_state(game.players,1,game.tactics.position,game.enemy_health(),false,3,Vector3.ZERO,false,[],2,6,true,false,false,packet,game.scout_snapshot(1000),.016)
  check(game.stage.visual_field.boss_kind==kind,"rendered stage preserves boss lair")
  game.enemy_kind=kind;game.encounter.set_hp(-1, 100);game.tactics.position=Vector3(0,0,3.2);p.pos=Vector3.ZERO;p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0);p.weapon=0;p.secondary=0;p.catalyst=0;p.frame=0;p.weapon_kind=0
  game.tactics.position=Vector3(0,0,float(game.Enemies.get_kind(kind).hurt_radius)+float(game.weapon_stats(p).reach)-.2)
  check(game.select_attack_target(p,float(game.weapon_stats(p).reach))==-1,"large boss can be struck at its visible body edge")
  game.strike_enemy(1,p,p.pos);game.update_projectiles(Time.get_ticks_msec()+1500)
  check(game.enemy_health()<100,"committed melee release respects boss hurtbox")
  game.enemy_kind=kind;game.encounter.set_hp(-1, 0);ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)});game.monster_rewards.retire_completed();game.wild_item_drops.clear()
  game.record_enemy_death(-1,game.tactics.position,p.pos);game.record_enemy_death(-1,game.tactics.position,p.pos)
  check(game.monster_rewards.pending_count()==1,"boss reward receipt deduplicates")
  check(game.flush_kill_rewards(),"boss reward transaction commits")
  check(game.wild_item_drops.count(game.wild_item_drops[0])>=1 if not game.wild_item_drops.is_empty() else false,"boss has drops")
  var seeds: Array=game.wild_item_drops.filter(func(d):return d.stack.item=="boss_mystery_seed")
  check(seeds.size()==1,"one opaque ancient seed per player per boss")
  check(not seeds[0].stack.has("seeds"),"boss seed species remains undisclosed")
 var active_boss_history: Array=game.used_bosses.duplicate()
 ExpeditionCase.Transitions.reset(game)
 check(game.participation.active() and game.used_bosses==active_boss_history and game.boss_floors.has("20"),"active expedition reset is refused without erasing boss history")
 ExpeditionCase.set_membership(game, p, false)
 ExpeditionCase.Transitions.reset(game);check(game.used_bosses.is_empty() and not game.boss_floors.has("20") and game.tactics.boss_kind==-1,"fresh run clears only run-local boss history")
 var tiers={};var random=RandomNumberGenerator.new();random.seed=1789
 for i in 5000:
  var species=game.Bosses.seed_species(random);var tier=int(game.Seeds.DEFINITIONS[species].tier);tiers[tier]=int(tiers.get(tier,0))+1
 check(not tiers.has(1) and not tiers.has(2) and tiers.get(4,0)>2300 and tiers.get(5,0)>800,"ancient seed tier weighting")
 ExpeditionCase.set_membership(game, p, true);p.safe_items=[];p.pouch=false;p.carried_items={}
 game.InventoryModel.put(game,p,"carry",{"item":"boss_mystery_seed","quantity":2})
 game.InventoryModel.transfer(game,p,"carry","pouch","boss_mystery_seed",2)
 check(p.safe_items.size()==1 and p.safe_items[0].quantity==2,"ancient stack fits safe pouch")
 game.InventoryModel.bank_safe(game,p)
 check(game.Altar.ancient_count(game,p)==2,"safe recovery banks ancient seeds")
 ExpeditionCase.set_membership(game, p, false);p.pos=game.Stage.ALTAR
 var saved_path: String=game.progress.path;var saved_rng: int=game.rng.state
 game.progress.path="res://.godot/absent-boss-seed-directory/fail.cfg"
 game.Altar.identify_all(game,p)
 check(game.Altar.ancient_count(game,p)==2 and game.rng.state==saved_rng,"failed identification restores seeds and frozen randomness")
 game.progress.path=saved_path
 var stored=game.InventoryModel.take(game,p,"stash","boss_mystery_seed",2)
 check(stored.quantity==2,"ancient generic stack can be moved intact")
 game.InventoryModel.put(game,p,"stash",{"item":"boss_mystery_seed","quantity":2})
 var before=game.seed_reserve(p).stock.reduce(func(a,b):return a+b,0)
 var message=game.Altar.identify_all(game,p)
 check(game.Altar.ancient_count(game,p)==0 and game.seed_reserve(p).stock.reduce(func(a,b):return a+b,0)==before+2,"identify all includes ancient seeds: "+message)
 game.queue_free();await process_frame
 if not failed: print("PASS: 24 enemies, rare nonrepeating boss scheduling, four lairs/move sets, bounded brood, public map descriptors, deduplicated private rewards and ancient identification")
 quit(1 if failed else 0)
