extends SceneTree

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
var game: Node
var role: String
var base: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL class depth co-op ",role,": ",message)
func mark(key: String) -> void:
 var file:=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+20000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func mask(right: bool) -> int:
 var result:=0
 for i in ([1,3,5,7,9,11] if right else [0,2,4,6,8,10]):result|=1<<i
 return result
func _initialize() -> void:call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/class-depth-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: class depth co-op ",role," all ten specialization paths, twenty remote skill variants, actual combat/support and synchronized HUD")
 quit(1 if failed else 0)
func host_run() -> void:
 check(game.host_game()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):
  check(false,"guest registers");return
 var id:=int(game.players.keys()[1]);var p: Dictionary=game.players[id]
 for c in 5:
  for right in [false,true]:
   var phase: String=str(c)+str(right)
   game.battlefield.configure(0,1);game.encounter.set_hp(-1, 100);game.tactics.position=Vector3.ZERO;game.tactics.stagger_until=Time.get_ticks_msec()+60000;game.enemy_traits.clear();game.trait_events.clear();game.encounter.clear_scouts();game.combat_epoch+=1
   p.character.active_class=c;p.character.xp[c]=2600;p.character.upgrades.fill(0);p.character.upgrades[c]=mask(right);p.frame=c;p.weapon_kind=0;p.weapon=0;p.secondary=0;p.catalyst=0;p.graft_part=0;p.run_upgrades={}
   for player in game.players.values():player.wild=true;player.pos=Vector3(0,0,-1.5);player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(5);player[PlayerLifecycle.STATE] = player[PlayerLifecycle.STATE].clear_inactive()
   p.facing=Vector3.BACK
   p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0).with_deadline(Cooldowns.R, 0)
   for key in ["guard_until","front_guard_until","counter_guard_until","counter_until","hurt_until","decoy_ready","prepared_mark_until"]:p[key]=0
   game.publish_character(id);mark("ready-"+phase)
   check(await until(func():return p[Cooldowns.STATE].deadline(Cooldowns.Q)>0),"guest Q "+phase)
   if c==0:game.apply_enemy_hit(id,p,Time.get_ticks_msec(),1,0,game.tactics.position)
   mark("q-"+phase)
   check(await until(func():return p[Cooldowns.STATE].deadline(Cooldowns.R)>0),"guest R "+phase)
   await create_timer(.8).timeout
   check(game.enemy_health()<100 or (c==4 and not right and PlayerVitals.current_hp(p)>5),"actual damage or support "+phase)
   mark("cast-"+phase)
   check(await until(func():return marked("seen-"+phase)),"guest confirms HUD "+phase)
 mark("done");check(await until(func():return game.players.size()==1),"guest leaves");game.leave_game("Class depth fixture complete")
func guest_run() -> void:
 game.guest_character.save_profile();check(game.join_game()==OK,"guest joins")
 check(await until(func():return game.session=="Guest" and not game.client_details.is_empty()),"guest admitted")
 var id:=game.multiplayer.get_unique_id()
 for c in 5:
  for right in [false,true]:
   var phase: String=str(c)+str(right)
   check(await until(func():return marked("ready-"+phase) and game.players[id].get("frame",-1)==c and game.guest_character.data.active_class==c and game.guest_character.data.upgrades[c]==mask(right) and game.players[id].get("skill_ready",false) and game.players[id].get("skill_two_ready",false)),"specialization ready "+phase)
   game.send_garden_action("class_skill");check(await until(func():return marked("q-"+phase)),"host accepts Q "+phase)
   game.send_garden_action("class_skill_two");check(await until(func():return marked("cast-"+phase)),"host accepts R "+phase)
   game._process(.016)
   var expected: Array=[game.Skills.resolve(c,0,game.guest_character.data).name,game.Skills.resolve(c,1,game.guest_character.data).name]
   check(game.player_hud.state.skill_names==expected and game.players[id].skill_cooldowns[0]>0 and game.players[id].skill_cooldowns[1]>0,"resolved names and independent cooldowns "+phase)
   mark("seen-"+phase)
 check(await until(func():return marked("done")),"host finishes");game.leave_game("Class depth fixture complete")
