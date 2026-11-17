extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Learning=preload("res://wilds_learning.gd")
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL combat balance: ",message)
func _initialize():
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/combat_balance_"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p: Dictionary=game.players[1];ExpeditionCase.set_membership(game, p, true)
 var counts: Array=[];var health: Array=[]
 for floor_number in [1,6,12,24,48]:
  ExpeditionCase.set_world(game, {"encounter_number": floor_number});ExpeditionCase.set_world(game, {"depth": (floor_number-1)%6+1});ExpeditionCase.set_world(game, {"destination": ((floor_number-1)/6)%3});ExpeditionCase.set_world(game, {"map_seed": 91300+floor_number});ExpeditionCase.set_world(game, {"difficulty_cycle": (floor_number-1)/18});game.reset_encounter()
  counts.append(game.encounter.scout_count());health.append(game.encounter_health())
  check(game.encounter.scout_count()<=game.EncounterConfig.MAX_SCOUTS,"population stays inside synchronized capacity")
  check(game.tactics.position.distance_to(game.battlefield.entry)>=8,"leader stays clear of player arrival")
  for i in game.encounter.scout_count():
   var scout: Dictionary=game.encounter.scout(i)
   check(scout.pos.distance_to(game.battlefield.entry)>=8 and not game.battlefield.occupied(scout.pos,.34),"scout spawns on walkable floor away from entry")
   for j in i: check(scout.pos.distance_to(game.encounter.scout(j).pos)>.7,"distinct spawn positions remain usable")
 check(counts[0]>=6 and counts[4]>counts[0] and health[4]>health[0],"endless progression retains pressure across biome resets")
 ExpeditionCase.set_world(game, {"destination": 0});ExpeditionCase.set_world(game, {"depth": 1});ExpeditionCase.set_world(game, {"encounter_number": 1});ExpeditionCase.set_world(game, {"difficulty_cycle": 0});ExpeditionCase.set_world(game, {"map_seed": 94127});game.reset_encounter()
 # Conservative interior cache must agree with exact terrain at sub-grid positions.
 var geometry_rng:=RandomNumberGenerator.new();geometry_rng.seed=9271
 for i in 3000:
  var point:=Vector3(geometry_rng.randf_range(-36,36),0,geometry_rng.randf_range(-32,32))
  for clearance in [0.0,.34,.8]: check(game.battlefield.inside_floor(point,clearance)==(game.battlefield.floor_distance(point)>=clearance),"cached collision preserves exact dirt boundaries")
 var solo_count: int=game.encounter.scout_count();var solo_hp: int=game.encounter_health()
 game.add_player(2);var friend: Dictionary=game.players[2];SessionCase.set_ready(game, friend, true);ExpeditionCase.set_membership(game, friend, true);SessionCase.set_identity(game, friend, "b".repeat(32));game.reset_encounter()
 check(game.encounter.scout_count()>solo_count and game.encounter_health()>solo_hp,"co-op adds combatants and health rather than just doubling player damage")
 var scaled_hp: int=game.encounter_health()
 check(game.player_snapshot(2,false)[2].enemy_max_hp==scaled_hp,"authoritative maximum health is included in movement snapshots")
 ExpeditionCase.set_membership(game, friend, false)
 check(game.encounter_health()==scaled_hp,"mid-encounter loss cannot rewrite enemy maximum health")
 ExpeditionCase.set_membership(game, friend, true);game.battlefield.configure(0,1);game.battlefield.barriers=[];p.pos=Vector3(-2,0,4);friend.pos=Vector3(2,0,4)
 var a: Dictionary=game.make_scout(0,Vector3(0,0,4),1);var b: Dictionary=game.make_scout(0,Vector3(0,0,4),2);a.engaged=true;b.engaged=true;game.encounter.clear_scouts();game.encounter.register_scout(a);game.encounter.register_scout(b);game.combat_threat.clear()
 var ta: int=game.Director.target(game,a.pos,a,1000);var tb: int=game.Director.target(game,b.pos,b,1000)
 check(ta!=tb,"equally reachable players share enemy attention")
 check(game.Director.target(game,a.pos,a,1100)==ta,"target remains stable inside commitment window")
 ExpeditionCase.set_membership(game, game.players[ta], false)
 check(game.Director.target(game,a.pos,a,1200)!=ta,"fallen/absent target is replaced immediately")
 ExpeditionCase.set_membership(game, p, true);ExpeditionCase.set_membership(game, friend, false);p.pos=Vector3(0,0,4);p.facing=Vector3.FORWARD
 game.encounter.set_hp(-1, 0);a.pos=Vector3(0,0,2.8);b.pos=Vector3(0,0,4.8);p.erase("aim_target");p.erase("aim_token")
 check(game.select_attack_target(p,3)==0,"aim assistance prefers reachable enemy in front over similar enemy behind")
 game.combat_velocity[1]=Vector3(4,0,0)
 var aim: Vector3=game.Director.predict(game,1,.3)
 check(aim.x>p.pos.x and aim.distance_to(p.pos)<1.7,"ranged prediction leads motion within a bounded readable offset")
 p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(10);p.hurt_until=0;p.guard_until=0
 IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(p), 1000, 1);IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(p), 1001, 1)
 check(PlayerVitals.current_hp(p)==9,"simultaneous swarm contacts do not erase several hearts in one instant")
 IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(p), 1250, 1);check(PlayerVitals.current_hp(p)==8,"protection expires and later telegraphs still damage")
 var memory:=Learning.blank()
 for i in 3: Learning.observe(memory,{"ranged":true,"kite":true},1)
 check(memory.score.ranged==6 and memory.score.kite==6,"repeated successful tactics build evidence")
 var traits:=0
 for stamp in 100: traits|=Learning.traits(memory,10,stamp)
 check(traits&1 and traits&8,"learned ranged and kiting counters actually enter mutation pool")
 for i in 100: Learning.observe(memory,{},8)
 check(memory.peak.ranged==6 and memory.score.ranged>=3,"changed tactics reduce current pressure without deleting learned history")
 var varied:=Learning.blank()
 for i in 20: Learning.observe(varied,{},8)
 check(Learning.traits(varied,8,0)&4,"world can develop variation without repeated player tactics")
 for floor_number in [1,3,10,30]:
  for stamp in 20:
   var bounded:=Learning.bounded(15,floor_number,stamp);var count:=0
   for flag in [1,2,4,8]: count+=int((bounded&flag)!=0)
   check(count<=(0 if floor_number<3 else 1 if floor_number<9 else 2 if floor_number<24 else 3),"adaptations obey depth budget")
 game.progress.wilds_memory=memory;game.progress.save_garden()
 var reload=game.Progress.new();reload.path=game.progress.path;check(reload.load_garden()==OK and reload.wilds_memory==memory,"host-world learning survives reload")
 var initial: Dictionary=game.progress.wilds_memory.duplicate(true);var path: String=game.progress.path
 game.progress.path="res://.godot/missing-combat-memory/fail.cfg";game.encounter_rewarded=false;ExpeditionCase.set_world(game, {"encounter_number": 4});ExpeditionCase.set_world(game, {"destination": 0});game.damage_this_room=10;game.ranged_damage_this_room=10;game.encounter.set_hp(-1, 0);game.encounter.clear_scouts();game.finish_combat(1,p.pos)
 check(game.progress.wilds_memory==initial and not game.encounter_rewarded,"failed settlement cannot partially commit learning")
 game.progress.path=path;ExpeditionCase.set_world(game, {"encounter_number": 3});ExpeditionCase.set_world(game, {"depth": 3});game.encounter_kill_records.assign([{"kind":2,"mask":0}]);game.rng.seed=12345
 var drops:=0;var empty:=0
 for i in 1000:
  var item: String=game.roll_kill_trophy(2)
  if item.is_empty(): empty+=1
  else: drops+=1;check(item==game.Parts.DEFINITIONS[game.Parts.monster_part(2)].item_id,"trophy keeps actual killed species identity")
 check(drops>20 and drops<80 and empty>900,"even a third stage has a bounded non-guaranteed trophy rate")
 game.encounter_kill_records.clear()
 check(game.Director.trophy_chance(100,true,true)<=.15,"deep guardians and adaptations cannot make trophies guaranteed")
 print(JSON.stringify({"solo_scouts_by_depth":counts,"leader_health_by_depth":health,"trophies_per_1000":drops}))
 game.queue_free();await process_frame
 if not failed: print("PASS: pressure scaling, safe spawns, co-op budgets, threat targeting, player aim, hit grace, persistent learning and trophy odds")
 quit(1 if failed else 0)
