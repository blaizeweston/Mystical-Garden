extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
const Warden = preload("res://warden_connected_tree.gd")
# Real guest input/RPC regression: Warden final kill, cleared floor, then next fight.
var game: Node
var base: String
var role: String
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok: failed=true;printerr("FAIL Warden co-op ",role,": ",message)
func mark(key: String) -> void:
 var file:=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ready")
func marked(key: String) -> bool: return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+20000
 while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
 return predicate.call()
func _initialize() -> void: call_deferred("run")
func run() -> void:
 role=OS.get_cmdline_user_args()[0];base="res://.godot/warden-"+OS.get_cmdline_user_args()[1]
 game=load("res://world.tscn").instantiate()
 game.progress.path=base+"-"+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest"
 root.add_child(game)
 if role=="host": await host_run()
 else: await guest_run()
 game.queue_free();await process_frame
 if not failed: print("PASS: Warden co-op ",role," pre-RPC compatibility, current starting focuses, final kills, cleared-floor spam and next encounter")
 quit(1 if failed else 0)
func prepare(p: Dictionary,focus: String) -> void:
 game.battlefield.configure(0,1);game.encounter.set_hp(-1, 1);game.tactics.position=Vector3.ZERO;game.tactics.winding_up=false;game.tactics.engaged=false
 game.tactics.ready_at=Time.get_ticks_msec()+60000;game.tactics.stagger_until=Time.get_ticks_msec()+60000
 var scout: Dictionary=game.make_scout(0,Vector3(.4,0,0),0)
 scout.hp=1;scout.stagger_until=Time.get_ticks_msec()+60000
 game.encounter.clear_scouts();game.encounter.register_scout(scout)
 game.encounter_rewarded=false
 for ally in game.players.values(): ExpeditionCase.set_membership(game, ally, true);ally.pos=Vector3(0,0,-1.5);ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(10)
 p.frame=0;p.weapon_kind=0;p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0);p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0);p.character.active_class=0;p.character.upgrades[0]=0;p.character[Warden.PROFILE_KEY]=Warden.state([focus]);p.character.xp[0]=int(game.Character.LEVEL_THRESHOLDS.back())
 game.publish_character(int(game.players.keys()[1]))
func host_run() -> void:
 check(SessionCase.World.host(game)==OK,"host opens")
 for kind in ["schema","protocol","growth","old_growth","garden","old_garden","legacy"]:
  check(await until(func(): return marked("rejected-"+kind)),"incompatible "+kind+" probe finishes")
  check(game.players.size()==1,"incompatible "+kind+" never creates a gameplay player")
  mark("confirmed-"+kind)
 if not await until(func(): return game.players.size()==2 and game.players.values().all(func(p): return SessionCase.Session.ready_for(p))):
  check(false,"compatible Warden admitted");return
 var id:=int(game.players.keys()[1]);var p: Dictionary=game.players[id]
 check(p.frame==0,"guest is Warden")
 for variant in ["vanguard","bastion"]:
  prepare(p,variant);mark("ready-"+str(variant))
  check(await until(func(): return marked("cleared-"+str(variant))),"guest sees final kill variant "+str(variant))
  check(game.encounter_cleared() and game.encounter_rewarded,"last primary and scout deaths finish combat once")
  var cooldowns: Array=[p[Cooldowns.STATE].deadline(Cooldowns.Q),p[Cooldowns.STATE].deadline(Cooldowns.R)];var fx:=int(p.get("skill_fx_seq",0));var health: float=PlayerVitals.current_hp(p)
  mark("spam-"+str(variant))
  check(await until(func(): return marked("spammed-"+str(variant))),"guest remains alive through cleared-floor requests")
  check([p[Cooldowns.STATE].deadline(Cooldowns.Q),p[Cooldowns.STATE].deadline(Cooldowns.R)]==cooldowns and int(p.get("skill_fx_seq",0))==fx and PlayerVitals.current_hp(p)==health,"cleared-floor requests cause no cast, cooldown, health or FX changes")
  check(game.players.has(id) and SessionCase.Session.ready_for(game.players[id]),"guest remains registered")
  mark("checked-"+str(variant))
  check(await until(func(): return marked("ack-"+str(variant))),"guest receives host acknowledgement")
 prepare(p,"rootkeeper");mark("next")
 check(await until(func(): return marked("next-cast")),"guest casts in next encounter")
 check(p[Cooldowns.STATE].deadline(Cooldowns.Q)>0,"post-clear guest still sends working abilities")
 mark("done")
 check(await until(func(): return game.players.size()==1),"guest leaves normally")
 SessionCase.World.leave(game,"Warden fixture complete")
func bad_begin(id: int,kind: String) -> void:
 game.network_session.compatibility_started()
 if kind=="legacy": return # old peer sends no pre-RPC compatibility data
 var payload: Dictionary={"game":"mystical-garden","protocol":game.Network.PROTOCOL,"contract":game.network_compatibility.signature,"terrain":preload("res://battlefield.gd").SIGNATURE,"garden":preload("res://garden_return_catalog.gd").signature,"cultivation":preload("res://cultivation_growth.gd").signature}
 payload.hp_per_point=game.Life.Preview.scale()
 payload.experimental_terrain=preload("res://assets/terrain_m02/experimental/experiment_mode.gd").network_identity(game)
 payload.combat_ruleset=preload("res://combat_ruleset.gd").network_identity(game)
 if kind=="schema": payload.contract="different-rpc-layout"
 elif kind=="growth": payload.cultivation="different-growth-rules"
 elif kind=="old_growth": payload.erase("cultivation")
 elif kind=="garden": payload.garden="different-garden-catalog"
 elif kind=="old_garden": payload.erase("garden")
 else: payload.protocol-=1
 game.multiplayer.send_auth(id,JSON.stringify(payload).to_utf8_buffer())
func cast(action: String) -> void:
 var id: int=game.multiplayer.get_unique_id()
 game.players[id].facing=Vector3.BACK
 var event:=InputEventAction.new();event.action=action;event.pressed=true
 game._unhandled_key_input(event)
 event.pressed=false
 game._input(event)
func guest_run() -> void:
 game.guest_character.data.active_class=0;game.guest_character.data.name="Warden regression";game.guest_character.save_profile()
 game.multiplayer.peer_authenticating.disconnect(game.network_compatibility.begin_check)
 for kind in ["schema","protocol","growth","old_growth","garden","old_garden","legacy"]:
  var callback:=bad_begin.bind(kind)
  game.multiplayer.peer_authenticating.connect(callback)
  game.multiplayer.auth_timeout=.6 if kind=="legacy" else 3.0
  check(SessionCase.World.join(game)==OK,"start incompatible "+kind+" probe")
  check(await until(func(): return game.network_session.role()=="Solo"),"incompatible "+kind+" rejected before gameplay")
  check(game.status.contains("same") and game.status.contains("build"),"incompatibility asks peers to use the same build: "+game.status)
  check(game.guest_character.data.xp[0]==0,"incompatible peer preserves character")
  game.multiplayer.peer_authenticating.disconnect(callback)
  mark("rejected-"+kind)
  check(await until(func(): return marked("confirmed-"+kind)),"host confirms rejection")
 game.multiplayer.auth_timeout=10.0;game.multiplayer.peer_authenticating.connect(game.network_compatibility.begin_check)
 check(SessionCase.World.join(game)==OK,"compatible guest connects")
 check(await until(func(): return game.network_session.role()=="Guest" and not game.client_details.is_empty()),"compatible guest accepted")
 var id:=game.multiplayer.get_unique_id()
 for variant in ["vanguard","bastion"]:
  check(await until(func(): return marked("ready-"+str(variant)) and ExpeditionCase.is_wild(game.players.get(id,{})) and not game.encounter_cleared() and Warden.focus(game.guest_character.data)==variant and not preload("res://network_action_identity.gd").current_stamp(game,game.players[id]).is_empty()),"combat and class choices arrive variant "+str(variant))
  cast("class_skill")
  check(await until(func(): return not game.players[id].get("skill_ready",true)),"guest Counter or Rootshield cooldown arrives")
  cast("class_skill_two")
  check(await until(func(): return game.encounter_cleared() and not game.players[id].get("skill_two_ready",true)),"guest Root Quake kills last enemies")
  mark("cleared-"+str(variant))
  check(await until(func(): return marked("spam-"+str(variant))),"host ready for cleared input")
  for i in 6:
   cast("class_skill");cast("class_skill_two")
   # Also exercise host validation when a request was sent before clear arrived.
   var aim=preload("res://ability_aim.gd")
   game.request_garden_action.rpc_id(1,aim.request(game,game.players[id],0,Vector2.DOWN))
   game.request_garden_action.rpc_id(1,aim.request(game,game.players[id],1,Vector2.DOWN))
   await create_timer(.12).timeout
  await create_timer(.4).timeout
  check(game.network_session.role()=="Guest" and game.players.has(id),"guest survives cleared-floor input")
  mark("spammed-"+str(variant))
  check(await until(func(): return marked("checked-"+str(variant))),"host validates unchanged cleared state")
  mark("ack-"+str(variant))
 check(await until(func(): return marked("next") and not game.encounter_cleared() and game.players[id].get("skill_ready",false)),"new encounter arrives")
 cast("class_skill")
 check(await until(func(): return not game.players[id].get("skill_ready",true)),"abilities work again in next encounter");mark("next-cast")
 check(await until(func(): return marked("done")),"host completes")
 SessionCase.World.leave(game,"Warden fixture complete")
