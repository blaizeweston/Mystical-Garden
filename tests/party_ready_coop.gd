extends SceneTree
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
 game.encounter_number=number;game.deepest_milestone=number;game.encounter.set_hp(-1, 0);game.encounter.clear_scouts()
 for p in game.players.values(): p.pos=game.battlefield.advance
func run():
 var role: String=OS.get_cmdline_user_args()[0]
 game=load("res://world.tscn").instantiate();game.progress.path="res://.godot/party_net_"+role+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":
  check(game.host_game()==OK,"host starts")
  if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)): check(false,"guest registers");quit(1);return
  var id: int=game.players.keys()[1];var host: Dictionary=game.players[1];var guest: Dictionary=game.players[id]
  host.pos=game.Stage.GATE;guest.pos=game.Stage.GATE
  game.enter_wilds(1,host)
  check(not host.wild and not guest.wild,"host cannot depart alone")
  game.garden_action(1,"travel_unready:"+str(game.travel_epoch))
  check(await until(func():return game.travel_votes.has(id)),"guest readiness reaches host")
  check(await until(func():return not game.travel_votes.has(id)),"guest can withdraw readiness")
  check(await until(func():return game.travel_votes.has(id)),"guest can confirm again")
  check(not host.wild and not guest.wild,"guest cannot depart without host")
  game.enter_wilds(1,host)
  check(host.wild and guest.wild,"party departs simultaneously")
  cleared(1);game.use_checkpoint(1,true)
  check(game.encounter_number==1,"ordinary gate waits")
  check(await until(func():return game.encounter_number==2),"both confirmations advance stage")
  cleared(6);game.use_checkpoint(1,true);game.choose_checkpoint_card(1,host,-1)
  check(await until(func():return game.checkpoint_all_ready()),"both upgrade decisions arrive")
  check(game.encounter_number==6,"cards do not advance without host travel consent")
  game.use_checkpoint(1,true)
  check(await until(func():return game.encounter_number==7),"checkpoint advances after both ready")
  cleared(12);host.carried_seeds=[0];guest.carried_seeds=[1];game.use_checkpoint(1,false)
  check(host.wild and guest.wild,"host cannot extract guest without consent")
  check(await until(func():return not host.wild and not guest.wild),"party extraction completes together")
  check(game.progress.unknown.has(0) and game.seed_reserve(guest).unknown.has(1),"both inventories bank separately")
  host.pos=game.Stage.GATE;guest.pos=game.Stage.GATE;game.enter_wilds(1,host)
  check(await until(func():return game.players.size()==1),"guest disconnect processed")
  check(not host.wild and game.travel_kind.is_empty(),"disconnect never silently launches remaining player")
 else:
  game.guest_character.data.name="Fern";game.guest_character.save_profile();check(game.join_game()==OK,"guest starts")
  check(await until(func():return game.session=="Guest" and game.party_travel_state().get("kind","")=="depart"),"party ready state reaches guest")
  game.send_travel_ready(false)
  check(await until(func():return game.party_travel_state().get("ready",false)),"guest sees its confirmation")
  game.send_travel_ready(true)
  check(await until(func():return not game.party_travel_state().get("ready",true)),"withdrawal synchronizes")
  game.send_travel_ready(false)
  check(await until(func():return game.players.get(game.multiplayer.get_unique_id(),{}).get("wild",false)),"guest enters with host")
  check(await until(func():return game.party_travel_state().get("kind","")=="advance" and game.encounter_number==1),"ordinary stage ready prompt arrives")
  game.send_travel_ready(false)
  check(await until(func():return game.checkpoint_menu.visible and game.encounter_number==6),"upgrade cards arrive")
  game.send_garden_action("checkpoint_choice_-1")
  check(await until(func():return not game.checkpoint_menu.visible),"card confirmation closes cards")
  game.send_travel_ready(false)
  check(await until(func():return game.party_travel_state().get("kind","")=="extract" and game.encounter_number==12),"extraction ready check arrives")
  game.send_travel_ready(false)
  check(await until(func():return not game.players.get(game.multiplayer.get_unique_id(),{}).get("wild",true)),"guest returns to Garden with party")
  check(await until(func():return game.party_travel_state().get("kind","")=="depart"),"next departure needs new confirmations")
  game.leave_game("Ready-check disconnect fixture")
 if not failed: print("PASS: party ready "+role+" departure, withdrawal, stages, cards, extraction and disconnect")
 quit(1 if failed else 0)
