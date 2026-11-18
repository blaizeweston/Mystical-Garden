extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var game: Node
var failed:=false
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL party ready co-op: ",message)
func _initialize(): call_deferred("run")
func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+18000
 while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
 return predicate.call()
func cleared(number: int):
 ExpeditionCase.set_world(game, {"encounter_number": number});game.deepest_milestone=number;game.encounter.set_hp(-1, 0);game.encounter.clear_scouts()
 for p in game.players.values(): p.pos=game.battlefield.advance
func run():
 var role: String=OS.get_cmdline_user_args()[0]
 game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/party_net_"+role+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":
  check(SessionCase.World.host(game)==OK,"host starts")
  if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return SessionCase.Session.ready_for(p))): check(false,"guest registers");quit(1);return
  var id: int=game.players.keys()[1];var host: Dictionary=game.players[1];var guest: Dictionary=game.players[id]
  host.pos=game.Stage.GATE;guest.pos=game.Stage.GATE
  for actor in [host,guest]:
   var tree=game.Classes.connected_tree(int(actor.frame))
   actor.character[tree.profile_key]=tree.state([tree.nodes[0].id])
  ExpeditionCase.Transitions.enter(game, 1,host)
  check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest),"host cannot depart alone")
  game.garden_action(1,"travel_unready:"+str(game.participation.travel_epoch()))
  check(await until(func():return game.participation.has_vote(id)),"guest readiness reaches host")
  check(await until(func():return not game.participation.has_vote(id)),"guest can withdraw readiness")
  check(await until(func():return game.participation.has_vote(id)),"guest can confirm again")
  check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest),"guest cannot depart without host")
  ExpeditionCase.Transitions.enter(game, 1,host)
  check(ExpeditionCase.is_wild(host) and ExpeditionCase.is_wild(guest),"party departs simultaneously")
  cleared(1);ExpeditionCase.Transitions.checkpoint(game, 1,true)
  check(game.participation.floor()==1,"ordinary gate waits")
  check(await until(func():return game.participation.floor()==2),"both confirmations advance stage")
  cleared(6);ExpeditionCase.Transitions.checkpoint(game, 1,true);game.garden_action(1,game.affinity_checkpoint_action(int(game.checkpoint_card_data(host)[0].revision),"skip"))
  check(await until(func():return game.checkpoint_all_ready()),"both upgrade decisions arrive")
  check(game.participation.floor()==6,"cards do not advance without host travel consent")
  ExpeditionCase.Transitions.checkpoint(game, 1,true)
  check(await until(func():return game.participation.floor()==7),"checkpoint advances after both ready")
  cleared(12);host.carried_seeds=[0];guest.carried_seeds=[1];ExpeditionCase.Transitions.checkpoint(game, 1,false)
  check(ExpeditionCase.is_wild(host) and ExpeditionCase.is_wild(guest),"host cannot extract guest without consent")
  check(await until(func():return not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(guest)),"party extraction completes together")
  check(game.progress.unknown.has(0) and game.seed_reserve(guest).unknown.has(1),"both inventories bank separately")
  host.pos=game.Stage.GATE;guest.pos=game.Stage.GATE;ExpeditionCase.Transitions.enter(game, 1,host)
  check(await until(func():return game.players.size()==1),"guest disconnect processed")
  check(not ExpeditionCase.is_wild(host) and game.participation.travel_kind().is_empty(),"disconnect never silently launches remaining player")
 else:
  game.guest_character.data.name="Fern";game.guest_character.save_profile();check(SessionCase.World.join(game)==OK,"guest starts")
  check(await until(func():return game.network_session.role()=="Guest" and game.party_travel_state().get("kind","")=="depart"),"party ready state reaches guest")
  game.send_travel_ready(false)
  check(await until(func():return game.party_travel_state().get("ready",false)),"guest sees its confirmation")
  game.send_travel_ready(true)
  check(await until(func():return not game.party_travel_state().get("ready",true)),"withdrawal synchronizes")
  game.send_travel_ready(false)
  check(await until(func():return ExpeditionCase.is_wild(game.players.get(game.multiplayer.get_unique_id(),{}))),"guest enters with host")
  check(await until(func():return game.party_travel_state().get("kind","")=="advance" and game.participation.floor()==1),"ordinary stage ready prompt arrives")
  game.send_travel_ready(false)
  check(await until(func():return UIFixture.control(game,"checkpoint_menu").visible and game.participation.floor()==6),"upgrade cards arrive")
  game.send_garden_action(game.affinity_checkpoint_action(game.ui.checkpoint_revision(),"skip"))
  check(await until(func():return not UIFixture.control(game,"checkpoint_menu").visible),"card confirmation closes cards")
  game.send_travel_ready(false)
  check(await until(func():return game.party_travel_state().get("kind","")=="extract" and game.participation.floor()==12),"extraction ready check arrives")
  game.send_travel_ready(false)
  check(await until(func():return game.players.has(game.multiplayer.get_unique_id()) and not ExpeditionCase.is_wild(game.players[game.multiplayer.get_unique_id()])),"guest returns to Garden with party")
  check(await until(func():return game.party_travel_state().get("kind","")=="depart"),"next departure needs new confirmations")
  SessionCase.World.leave(game,"Ready-check disconnect fixture")
 if not failed: print("PASS: party ready "+role+" departure, withdrawal, stages, cards, extraction and disconnect")
 quit(1 if failed else 0)
