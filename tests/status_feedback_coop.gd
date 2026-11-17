extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")
const Status=preload("res://combat_status.gd")
const Attacks=preload("res://enemy_attack.gd")
var game: Node
var base: String
var role: String
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL status co-op ",role,": ",message)
func mark(key: String):
 var file=FileAccess.open(base+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/status-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: status co-op ",role," authoritative player callouts, enemy icons, consumed marks and proc paths")
 quit(1 if failed else 0)
func host_run():
 check(game.host_game()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):check(false,"registration");return
 var id: int=game.players.keys().filter(func(i):return i!=1)[0];var p: Dictionary=game.players[id]
 for player in game.players.values():player.wild=true;player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10);player.pos=Vector3(0,0,-1)
 game.scouts.clear();game.enemy_hp=80;game.enemy_pos=Vector3(0,0,1);game.enemy_ready_at=Time.get_ticks_msec()+60000;game.enemy_winding_up=false;game.enemy_mutations=0
 check(await until(func():return marked("ready")),"guest sees Wilds")
 var now:=Time.get_ticks_msec();p.slow_until=now+12000
 var stats: Dictionary=game.weapon_stats(p);stats.mark_damage=2;stats.damage=1
 game.apply_weapon_hit(p,-1,p.pos,stats,now);Status.sync(game,now)
 check(await until(func():return marked("icons")),"guest sees slow and mark")
 game.apply_weapon_hit(p,-1,p.pos,stats,Time.get_ticks_msec());Status.sync(game,Time.get_ticks_msec())
 Status.proc(game,"echo",p.pos,game.enemy_pos,-1)
 check(await until(func():return marked("consumed")),"guest sees consumption")
 var guard: Dictionary=game.make_scout(0,Vector3(0,0,1),1)
 guard.variant="bark_guard"
 game.scouts.assign([guard])
 now=Time.get_ticks_msec()
 Attacks.lock(game,guard,"swipe",p.pos,now+12000)
 Status.sync(game,now)
 check(await until(func():return marked("guard-seen")),"guest sees Bark Guard and its sector")
 guard.windup=0;guard.erase("attack");guard.ready=Time.get_ticks_msec()+60000
 Status.sync(game,Time.get_ticks_msec())
 check(await until(func():return marked("guard-ended")),"guest removes expired Bark Guard")
 mark("done");check(await until(func():return game.players.size()==1),"disconnect")
func guest_run():
 game.guest_character.save_profile();check(game.join_game()==OK,"guest connects")
 var id:=game.multiplayer.get_unique_id()
 if not await until(func():return game.session=="Guest" and not game.client_details.is_empty() and game.players.get(id,{}).get("wild",false)):check(false,"Wilds arrives");return
 mark("ready")
 check(await until(func():return game.combat_visuals.statuses.active.values().any(func(item):return item.event.shape=="marked") and game.combat_visuals.statuses.active.values().any(func(item):return item.event.shape=="slow" and item.event.combo==id)),"guest renderer has authoritative icons")
 var visuals: Node3D=game.combat_visuals
 var active: Dictionary=visuals.statuses.active
 var repeated: Array=[]
 for item in active.values():
  if item.event.shape=="marked" or (item.event.shape=="slow" and int(item.event.combo)==id):
   repeated.append(item.event.duplicate(true))
 var count:=active.size()
 var hints: Array=visuals.hints.values().map(func(item):return item.event)
 visuals.sync(repeated,hints,visuals.floor_key,visuals.observer,visuals.sight)
 check(repeated.size()==2 and active.size()==count and repeated.all(func(event):return active.has(event.id)),"replaying the same status snapshot preserves both icons")
 mark("icons")
 check(await until(func():return not game.combat_visuals.statuses.active.values().any(func(item):return item.event.shape=="marked") and game.received_combat_events.any(func(e):return e.event.kind=="proc" and e.event.shape=="mark_break")),"mark consumed with proc")
 check(await until(func():return game.received_combat_events.any(func(e):return e.event.kind=="proc" and e.event.shape=="echo")),"echo path replicated")
 mark("consumed")
 check(await until(func():return game.combat_visuals.statuses.active.values().any(func(item):return item.event.shape=="bark_guard" and item.label.text=="Bark Guard") and game.players[id].get("attack_hints",[]).any(func(h):return h.get("actor",-1)==0 and h.role=="enemy_sweep" and h.span>0)),"guest renders named guard and matching sweep")
 mark("guard-seen")
 check(await until(func():return not game.combat_visuals.statuses.active.values().any(func(item):return item.event.shape=="bark_guard")),"guard indicator clears with its effect")
 mark("guard-ended")
 check(await until(func():return marked("done")),"host finishes");game.leave_game("Status fixture")
