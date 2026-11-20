extends SceneTree
const WorldViewCase = preload("res://tests/support/world_presentation_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Status=preload("res://combat_status.gd")
var game: Node
var base: String
var role: String
var failed:=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL elite co-op ",role,": ",message)
func mark(key: String):
 var file=FileAccess.open(base+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+16000
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/elite-net-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate();game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest";root.add_child(game)
 if role=="host":await host_run()
 else:await guest_run()
 game.queue_free();await process_frame
 if not failed:print("PASS: elite co-op ",role," species identity, matching telegraphs and synchronized elite brood")
 quit(1 if failed else 0)
func host_run():
 check(game.session_world.host()==OK,"host opens")
 if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))):check(false,"registration");return
 game.battlefield.configure(0,1);preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
 for player in game.players.values():ExpeditionCase.set_membership(game, player, true);player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(10);player.pos=Vector3(0,0,.8)
 game.encounter.clear_scouts();game.encounter.set_hp(-1, 80);game.tactics.position=Vector3.ZERO;game.tactics.ready_at=Time.get_ticks_msec()+60000;game.tactics.winding_up=false;game.enemy_mutations=0
 check(await until(func():return marked("ready")),"guest sees Wilds")
 for kind in [1,2,9,7,11]:
  game.tactics.memory.clear();game.enemy_kind=kind;game.tactics.position=Vector3.ZERO;game.encounter.begin_floor(80);game.tactics.engaged=true;game.tactics.ready_at=0;game.tactics.winding_up=false;game.tactics.stagger_until=0;game.tactics.rooted_until=0
  if kind==7:ExpeditionCase.set_world(game, {"encounter_number": 12})
  if kind==11:
   var escorted: Dictionary=game.make_scout(0,Vector3(0,0,1.8),2)
   escorted.ready=Time.get_ticks_msec()+60000
   game.encounter.register_scout(escorted)
  preload("res://leader_behavior.gd").tick(game, .016,Time.get_ticks_msec())
  game.tactics.strike_at=Time.get_ticks_msec()+12000
  check(await until(func():return marked("seen-"+str(kind))),"guest sees species "+str(kind))
  if kind==9:
   preload("res://leader_behavior.gd").resolve(game, Time.get_ticks_msec());game.tactics.ready_at=Time.get_ticks_msec()+60000
   check(await until(func():return marked("brood")),"guest sees brood wave")
  if kind==11:
   game.encounter.set_hp(-1, 0)
   game.tactics.winding_up=false
   check(await until(func():return marked("shelter-cleared")),"guest sees shelter end")
 mark("done");check(await until(func():return game.players.size()==1),"disconnect")
func guest_run():
 game.guest_character.save_profile();check(game.session_world.join()==OK,"connects")
 var id:=game.multiplayer.get_unique_id()
 if not await until(func():return game.network_session.role()=="Guest" and game.guest_replication.has_details() and ExpeditionCase.is_wild(game.players.get(id,{}))):check(false,"Wilds arrives");return
 mark("ready")
 for kind in [1,2,9,7,11]:
  check(await until(func():return game.enemy_kind==kind and game.stage.foe_model.kind==kind and game.players[id].get("attack_hints",[]).any(func(h):return h.id==-1 and h.role==game.Enemies.get_kind(kind).role)),"species and real attack hint "+str(kind))
  if kind==2:
   var warning: Dictionary=game.players[id].get("attack_hints",[]).filter(func(h):return h.id==-1)[0]
   check(await until(func():return game.stage.get_meta("enemy_attack_poses",{}).get(-1,{}).get("mode","")=="charge"),"guest applies the charge pose")
   var pose: Dictionary=game.stage.get_meta("enemy_attack_poses",{}).get(-1,{})
   check(warning.actor==-1 and warning.pose=="charge" and is_equal_approx(warning.radius,game.Enemies.radius(kind)+.35),"guest receives the full swept charge warning")
   check(pose.get("mode","")=="charge" and is_equal_approx(pose.get("target",Vector3.INF).z,warning.to[2]),"guest animation faces the same locked attack point")
  if kind==7:
   check(game.players[id].attack_hints.any(func(h):return h.role=="aftershock"),"guest sees the elite's separate aftershock location")
  if kind==11:
   check(await until(func():return WorldViewCase.component(game,"combat").statuses.active.values().any(func(s):return s.event.shape=="sheltered")),"guest displays Sheltered")
  var growth: Node3D=game.stage.foe_model.model.get_node_or_null("EliteGrowth");check(is_instance_valid(growth),"guest has anatomical elite features")
  mark("seen-"+str(kind))
  if kind==9:
   check(await until(func():return game.guest_replication.scouts().size()>=game.PACK_STRIDE*2 and game.stage.support_models.filter(func(model):return model.visible).size()>=2),"guest receives two summoned scouts")
   mark("brood")
  if kind==11:
   check(await until(func():return not WorldViewCase.component(game,"combat").statuses.active.values().any(func(s):return s.event.shape=="sheltered")),"guest clears the Sheltered label")
   mark("shelter-cleared")
 check(await until(func():return marked("done")),"host finishes");game.session_world.leave("Elite fixture")
