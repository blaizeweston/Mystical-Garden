extends SceneTree
const Core=preload("res://core_combat.gd")
const Preview=preload("res://combat_balance_preview.gd")
const Journal=preload("res://diagnostic_journal.gd")
var game: Node
var failed=false
var base: String
var role: String
func check(ok: bool,message: String):
 if not ok: failed=true;printerr("FAIL four players ",role,": ",message)
func mark(key: String,value: String="ready"):
 var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string(value)
func marked(key: String) -> bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate: Callable,seconds: float=25.0) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
 return predicate.call()
func _initialize():call_deferred("run")
func clear_floor(number: int):
 game.encounter_number=number;game.deepest_milestone=number;game.enemy_hp=0;game.scouts.clear();game.encounter_rewarded=true
 for p in game.players.values():p.pos=game.battlefield.advance
func finish():
 game.queue_free();await process_frame
 if not failed:print("PASS: four players ",role," 100 HP, crafting, exact vitals, guest revival, party gates, cards, extraction and reconnect")
 quit(1 if failed else 0)
func run():
 role=OS.get_cmdline_user_args()[0];base="res://.godot/four-"+OS.get_cmdline_user_args()[1]
 Preview.enabled=true
 Preview.heal_rng.seed=9308
 Journal.current.detail=true
 Journal.event("test","four_player_combat_fixture",{"token":OS.get_cmdline_user_args()[1],"role":role})
 game=load("res://world.tscn").instantiate();game.progress.path=base+"-"+role+".cfg";game.local_character.path=game.progress.path+".character";game.guest_character.path=game.progress.path+".guest";root.add_child(game)
 if role=="host":await host_run()
 elif role=="overflow":
  check(await until(func():return marked("full")),"full party starts")
  check(game.join_game()==OK,"fifth connection attempted")
  game.connection_deadline=Time.get_ticks_msec()+4000
  check(await until(func():return game.session!="Connecting"),"fifth player rejected or times out")
  check(game.session=="Solo","fifth player cannot enter full session");mark("overflow_done")
 else:await guest_run(int(role))
 await finish()
func host_run():
 check(game.host_game()==OK,"host starts")
 if not await until(func():return game.players.size()==4 and game.players.values().all(func(p):return p.profile_ready)):
  check(false,"three guests register");return
 var slots=[];var identities=[];var spawn=[]
 for id in game.players:
  var p=game.players[id];slots.append(p.party_slot);spawn.append(p.pos)
  if id!=1:identities.append(p.seed_owner)
 check(slots.size()==4 and slots.count(0)==1 and slots.count(1)==1 and slots.count(2)==1 and slots.count(3)==1,"four distinct party slots")
 check(identities.size()==3 and identities[0]!=identities[1] and identities[1]!=identities[2] and identities[0]!=identities[2],"three independent guest identities")
 for i in spawn.size():
  for j in i:check(spawn[i].distance_to(spawn[j])>.8,"players arrive separately")
 mark("full");check(await until(func():return marked("overflow_done")),"capacity probe completes")
 check(game.players.size()==4,"fifth connection leaves party intact")
 for p in game.players.values():p.pos=game.Stage.GATE
 game.progress.parts[0]=1;game.progress.parts[1]=2
 game.handle_loadout_action(1,game.players[1],"loadpart_0_1")
 var thorn_guest:=0
 for id in game.players:
  if game.players[id].character.name=="Player 2":thorn_guest=int(id)
 if thorn_guest==0:
  check(false,"fixture identifies the second guest");return
 game.handle_loadout_action(thorn_guest,game.players[thorn_guest],"loadpart_0_1")
 check(game.players[thorn_guest].prepared==0 and game.players[1].prepared==1,"another player cannot claim the host's last Thorn Bloom")
 game.progress.parts[0]=2
 for id in game.players:
  if id==1:continue
  var player: Dictionary=game.players[id]
  match str(player.character.name):
   "Player 1":
    game.select_class(id,player,1)
    game.handle_loadout_action(id,player,"loadpart_0_2")
   "Player 2":
    game.handle_loadout_action(id,player,"loadpart_0_1")
   "Player 3":
    game.select_class(id,player,4)
    game.handle_loadout_action(id,player,"loadpart_0_2")
 game.enter_wilds(1,game.players[1])
 check(await until(func():return game.travel_votes.size()==3),"first three readiness votes arrive")
 check(not game.players[1].wild and game.travel_members.size()==4,"three votes cannot launch four players")
 mark("last_ready")
 check(await until(func():return game.players.values().all(func(p):return p.wild)),"all four depart together")
 check(game.progress.parts[0]==0 and game.progress.parts[1]==0,"party consumes two copies of each starter part exactly once")
 check(game.players.values().all(func(p):return not game.weapon_stats(p).core_build.skill.is_empty()),"each party member has a live Core skill")
 check(await until(func():return marked("core-1") and marked("core-2") and marked("core-3")),"all guests get the correct private Core inventory and ready HUD")
 check(game.encounter_party_size==4 and game.scouts.size()>=12 and game.scouts.size()<=game.Director.scout_count(game),"encounter population scales to four")
 check(game.encounter_health()>=80,"four player leader health scales in preview HP")
 check(game.players.values().all(func(p):return p.max_hp==100 and p.hp==100),"four players depart at 100 HP")
 var entries=[]
 for id in game.players:entries.append(game.wild_entry(id))
 for i in entries.size():
  for j in i:check(entries[i].distance_to(entries[j])>.6,"Wilds arrivals separated")
 for viewer in game.players:
  var snapshot=game.player_snapshot(viewer)
  check(snapshot.size()==4,"snapshot includes whole party")
  for other in game.players:
   if other!=viewer:check(not snapshot[other].has("bag") and not snapshot[other].has("carried_parts") and not snapshot[other].has("core_state"),"private inventory and Core readiness stay owner-only")
 await guest_lantern()
 # A natural kill rewards all four and exposes a different owned pickup to each guest.
 var config=game.Director.config();var old_chance=config.trophy_chance;var old_cap=config.trophy_cap
 config.trophy_chance=1.0;config.trophy_cap=1.0
 var victim=game.make_scout(10,game.players[1].pos+Vector3(0,0,1),1);victim.hp=1;game.scouts[0]=victim
 game.apply_weapon_hit(game.players[1],0,game.players[1].pos,{"damage":1},Time.get_ticks_msec())
 check(game.MonsterRewards.flush(game),"four-way individual kill rewards commit")
 config.trophy_chance=old_chance;config.trophy_cap=old_cap
 check(await until(func():return marked("kill_verified_1") and marked("kill_verified_2") and marked("kill_verified_3")),"all guests receive their own monster reward and XP")
 if not await guest_vitals(thorn_guest):
  return
 clear_floor(1);game.use_checkpoint(1,true)
 check(await until(func():return game.encounter_number==2),"four ready votes advance ordinary gate")
 clear_floor(6);game.use_checkpoint(1,true);game.choose_checkpoint_card(1,game.players[1],-1)
 check(await until(func():return game.checkpoint_all_ready()),"all four choose checkpoint cards")
 check(game.encounter_number==6,"card choices do not imply host travel consent")
 game.use_checkpoint(1,true)
 check(await until(func():return game.encounter_number==7),"checkpoint advances with all confirmations")
 clear_floor(12)
 for id in game.players:game.players[id].carried_seeds=[game.players[id].party_slot]
 game.use_checkpoint(1,false)
 check(await until(func():return game.players.values().all(func(p):return not p.wild)),"all four extract together")
 check(game.players[thorn_guest].hp==100 and game.players[thorn_guest].lost_health==0,"extraction restores the sealed capacity")
 if not await publish_vitals("restored",thorn_guest):return
 for id in game.players:
  var p=game.players[id]
  check(game.seed_reserve(p).unknown.has(p.party_slot),"each player's seed banks to their own reserve")
 for p in game.players.values():p.pos=game.Stage.GATE
 game.enter_wilds(1,game.players[1]);mark("disconnect")
 check(await until(func():return game.players.size()==3),"one guest disconnects")
 check(game.travel_kind.is_empty() and not game.players[1].wild,"disconnect cancels pending travel")
 mark("rejoin")
 check(await until(func():return game.players.size()==4 and game.players.values().all(func(p):return p.profile_ready)),"guest rejoins remaining party")
 var found=false
 for p in game.players.values():
  if p.character.name=="Player 2":
   found=true;check(p.character.xp[0]==12 and p.character.xp_tenths[0]==1,"reconnected character retains progression")
 check(found,"reconnected identity restored")
 check(await until(func():return marked("rejoined_snapshot")),"rejoining guest receives all four peers")
 mark("done");check(await until(func():return game.players.size()==1),"all guests leave cleanly");game.leave_game("Four player test complete")
func all_guests_marked(stage: String) -> bool:
 for index in range(1,4):
  if not marked("%s-%d"%[stage,index]):return false
 return true


func publish_vitals(stage: String,id: int) -> bool:
 game.net_view.observe(game)
 game.diagnostic_watch.tick(true)
 var actor: Dictionary=game.players[id]
 mark(stage,JSON.stringify({"id":id,"hp":actor.hp,"max_hp":actor.max_hp,"lost_health":actor.lost_health,
  "fallen":actor.fallen,"revision":actor.vitals_revision,"damage_seq":actor.damage_seq}))
 var arrived:=await until(func():return all_guests_marked(stage),10)
 check(arrived,"all guests see authoritative "+stage+" at the exact HP revision")
 return arrived


func guest_vitals(id: int) -> bool:
 var actor: Dictionary=game.players[id]
 var now:=Time.get_ticks_msec()
 game.enemy_stagger_until=now+45000
 for scout in game.scouts:
  scout.ready=now+45000
  scout.rooted_until=now+45000
  scout.windup=0
 var helper: Dictionary={}
 for player in game.players.values():
  if player.character.name=="Player 1":
   helper=player
   break
 if helper.is_empty():
  check(false,"guest reviver is available")
  return false
 helper.pos=actor.pos
 game.damage_player(id,actor,35)
 if not await publish_vitals("wounded",id):return false
 check(actor.hp==65,"35 applied damage leaves 65 HP")
 now=Time.get_ticks_msec()
 actor.renewal_until=now+1000
 actor.renewal_tick=now
 game.update_support_effects(now)
 actor.renewal_until=0
 var healed:=int(actor.hp)-65
 check(healed in range(3,6),"Renewal restores one rolled tick")
 if not await publish_vitals("renewed",id):return false
 var last_hp:=int(actor.hp)
 game.damage_player(id,actor,500)
 check(actor.hp==0 and actor.fallen and actor.damage_amount==last_hp,"lethal damage reports the HP actually lost")
 if not await publish_vitals("fallen",id):return false
 helper.pos=actor.pos
 mark("revive")
 if not await until(func():return not actor.fallen,10):
  check(false,"guest interact revives another guest")
  return false
 check(actor.hp==80 and actor.max_hp==80 and actor.lost_health==20,"revival seals 20 maximum HP")
 return await publish_vitals("revived",id)


func guest_lantern() -> void:
 var caster: Dictionary={}
 for p in game.players.values():
  if p.character.name=="Player 1":caster=p;break
 if caster.is_empty():
  check(false,"Weaver guest available")
  return
 var aim:=Vector3.ZERO
 var placement: Dictionary={}
 for i in 36:
  var candidate:=Vector3.FORWARD.rotated(Vector3.UP,i*TAU/36.0)
  placement=Core.aim_cast(game.battlefield,caster.pos,candidate,Core.equipped(caster))
  if not placement.is_empty():
   aim=candidate
   break
 if placement.is_empty():
  check(false,"Weaver guest finds clear placement")
  return
 var target: Dictionary=game.scouts[0]
 target.pos=placement.center
 var now:=Time.get_ticks_msec()
 target.rooted_until=now+6000;target.ready=now+6000;target.windup=0
 mark("try-lantern",JSON.stringify([aim.x,aim.z]))
 check(await until(func():return marked("lantern-seen-1") and marked("lantern-seen-2") and marked("lantern-seen-3"),8),"guests receive Weaver's committed Lantern Burst")
 check(caster.core_ready_at>0 and game.combat_events.any(func(e):return e.shape=="lantern_burst"),"host accepts the guest cast and spends that player's cooldown")


func verify_vitals_marker(stage: String,index: int) -> void:
 var ack:="%s-%d"%[stage,index]
 if not marked(stage) or marked(ack):return
 var expected=JSON.parse_string(FileAccess.get_file_as_string(base+"-"+stage))
 if not expected is Dictionary:return
 var actor: Dictionary=game.players.get(int(expected.id),{})
 if int(actor.get("vitals_revision",0))!=int(expected.revision):return
 for field in ["hp","max_hp","lost_health","fallen","damage_seq"]:
  if actor.get(field)!=expected[field]:return
 mark(ack)


func guest_run(index: int):
 game.guest_character.data.name="Player "+str(index);game.guest_character.data.xp[0]=10+index;game.guest_character.data.appearance[5]=index%2;game.guest_character.save_profile()
 check(game.join_game()==OK,"guest connects")
 if not await until(func():return game.session=="Guest" and game.players.size()==4):check(false,"whole party snapshot arrives");return
 var saw_cards=false;var saw_four=false;var epochs={};var reconnected=false;var lantern_requested=false;var revive_requested=false
 var deadline=Time.get_ticks_msec()+90000
 while not marked("done") and Time.get_ticks_msec()<deadline:
  if index==2 and marked("disconnect") and not reconnected:
   game.leave_game("Four player reconnect test")
   check(await until(func():return marked("rejoin")),"host allows reconnect")
   check(game.join_game()==OK,"rejoin starts")
   check(await until(func():return game.session=="Guest" and game.players.size()==4),"rejoin receives full party")
   reconnected=true;mark("rejoined_snapshot")
  if game.session=="Guest":
   var id=game.multiplayer.get_unique_id()
   if game.players.size()==4 and game.players.has(id):
    saw_four=true;check(game.guest_character.data.name=="Player "+str(index),"owner profile preserved")
   if not marked("core-"+str(index)) and game.players.get(id,{}).get("wild",false):
    var bag: Dictionary=game.inventory_ui_data()
    var expected: String="Thorn Line" if index==2 else "Lantern Burst"
    if bag.get("core",{}).get("skill",{}).get("name","")==expected and game.player_hud.state.get("core",{}).get("name","")==expected and is_zero_approx(float(game.player_hud.state.core.remaining)):
     mark("core-"+str(index))
   if index==1 and not lantern_requested and marked("try-lantern"):
    var aim: Array=JSON.parse_string(FileAccess.get_file_as_string(base+"-try-lantern"))
    game.send_garden_action(Core.request(game,game.players[id],Vector2(aim[0],aim[1])))
    lantern_requested=true
   if not marked("lantern-seen-"+str(index)) and game.received_combat_events.any(func(e):return e.event.shape=="lantern_burst"):
    mark("lantern-seen-"+str(index))
   if game.checkpoint_menu.visible and game.encounter_number==6:
    if not saw_cards:game.send_garden_action("checkpoint_choice_-1");saw_cards=true;epochs.clear()
   if not marked("kill_verified_"+str(index)) and game.players.has(id):
    var own=game.players[id]
    if own.get("ground_items",[]).size()==1 and int(game.guest_character.data.get("xp_tenths",[0,0,0,0,0])[int(own.frame)])==1:
     check(str(own.ground_items[0].id).ends_with(":"+str(id)),"drop belongs to this guest")
     check(own.ground_items[0].item==game.Items.part_id(game.Parts.monster_part(10)),"drop preserves killed species")
     mark("kill_verified_"+str(index))
   for stage in ["wounded","renewed","fallen","revived","restored"]:
    verify_vitals_marker(stage,index)
   if index==1 and not revive_requested and marked("revive"):
    game.send_action(false)
    revive_requested=true
   var state=game.party_travel_state()
   if not state.is_empty() and not epochs.has(state.epoch) and not marked("disconnect"):
    if state.kind!="depart" or index!=3 or marked("last_ready"):
     if not game.checkpoint_menu.visible:
      game.send_travel_ready(false);epochs[state.epoch]=true
  await process_frame
 check(marked("done") and saw_four and saw_cards,"full-party flow completes")
 if index==2:check(reconnected,"disconnect and reconnect exercised")
 await create_timer(.25*index).timeout
 game.leave_game("Four player test complete")
