extends SceneTree

const Tx=preload("res://game_transaction.gd")
const Slots=preload("res://save_slots.gd")
const Roster=preload("res://character_slots.gd")
const Owner=preload("res://guarded_title_session.gd")
const Profile=preload("res://character_profile.gd")
const G="user://saves/slot_1/garden.cfg"
const C="user://saves/characters/slot_2/character.cfg"
const Signals="user://release-fixtures/expedition-"
var world: Node
var host:=false
var failed:=false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 if not ok:
  failed=true
  printerr("FAIL: ",message)

func mark(key: String,value := "ready") -> void:
 var file:=FileAccess.open(Signals+key,FileAccess.WRITE)
 check(file!=null,"fixture signal "+key)
 if file!=null: file.store_string(value)

func marked(key: String) -> bool:
 return FileAccess.file_exists(Signals+key)

func read(key: String) -> String:
 return FileAccess.get_file_as_string(Signals+key)

func until(predicate: Callable) -> bool:
 var deadline:=Time.get_ticks_msec()+8500
 while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
 return predicate.call()

func record(key: String,before: String,facts: Dictionary) -> void:
 print("CASE ",JSON.stringify({"case":key,"run_id":OS.get_environment("MYSTICAL_VALIDATION_RUN"),
  "garden_before":before,"garden_after":Slots._save_digest(G),"guest_profile":Slots._save_digest(C),"facts":facts}))

func start() -> bool:
 var slots:=Slots.new()
 var roster:=Roster.new()
 if host:
  check(Owner.completed(Owner.prepare(slots,roster,false)),"prepare roots")
  check(Owner.completed(Owner.outcome(slots.new_world_guarded(0))),"create Garden")
  check(Owner.completed(Owner.outcome(roster.create_guarded(0,"Keeper",0,[]))),"create keeper")
  check(Owner.completed(Owner.outcome(roster.create_guarded(1,"Guest",0,[]))),"create guest")
 elif not await until(func():return marked("hosting")): return false
 var path: String=roster.paths(0 if host else 1).character
 world=load("res://world.tscn").instantiate()
 world.progress.path=G
 world.local_character.path=path
 world.guest_character.path=path
 world.slot_claimed=host
 world.joined_from_title=not host
 var started:=Owner.new().start(world,slots if host else null,0,Slots._save_digest(G) if host else "",roster,0 if host else 1,Slots._save_digest(path))
 if not Owner.completed(started):
  check(false,"guarded startup "+str(started))
  world.free()
  return false
 root.add_child(world)
 # Drive simulation and snapshots at explicit barriers. Both local peers use
 # the runner's disposable root, so unrelated heartbeats would add contention.
 world.set_process(false)
 world.set_physics_process(false)
 return true

func run() -> void:
 host=OS.get_cmdline_user_args()[0]=="host"
 if not await start():
  quit(1)
  return
 if host: await host_run()
 else: await guest_run()
 if is_instance_valid(world) and world.online_peer!=null: world.leave_game("Fixture finished")
 var offline:=await until(func():return root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer)
 check(offline,"offline peer before world removal")
 if offline and is_instance_valid(world): world.free()
 if not failed: print("PASS: guarded expedition co-op ","host" if host else "guest")
 quit(1 if failed else 0)

func host_run() -> void:
 check(world.host_game()==OK,"guarded host listens")
 mark("hosting")
 if not await until(func():return world.players.size()==2 and world.players.values().all(func(p):return p.profile_ready)):
  check(false,"guarded guest admission")
  return
 var id: int=world.players.keys().filter(func(p):return p!=1)[0]
 var leader: Dictionary=world.players[1]
 var guest: Dictionary=world.players[id]
 leader.pos=world.Stage.GATE
 guest.pos=world.Stage.GATE
 world.progress.add_parts(1,3)
 leader.prepared=1
 var before:=Slots._save_digest(G)
 var stages:={"count":0}
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="stage":
   stages.count+=1
   return ERR_FILE_CANT_WRITE
  return OK)
 world.enter_wilds(1,leader)
 mark("depart-abort",str(world.travel_epoch))
 if not await until(func():return stages.count==1 and marked("saw-abort")):
  check(false,"party departure fault")
  return
 check(not leader.wild and not guest.wild and Slots._save_digest(G)==before and world.progress.part_count(1)==3
  and world.run_wallet(leader)==0 and world.run_wallet(guest)==0,"no departure effects or Essence before commitment")
 record("party_departure_abort",before,{"wild":false,"stage_count":stages.count,"travel_epoch":world.travel_epoch})
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.enter_wilds(1,leader)
 mark("depart-commit",str(world.travel_epoch))
 if not await until(func():return leader.wild and guest.wild):
  check(false,"both votes commit one departure")
  return
 check(world.progress.part_count(1)==2 and world.run_wallet(leader)==0 and world.run_wallet(guest)==0,
  "party consumed one reserved part and both wallets start at zero")
 world.send_expedition_state(0,true)
 mark("departed")
 if not await until(func():return marked("saw-departure")):
  check(false,"guest sees committed floor")
  return
 world.record_enemy_death(-1,world.enemy_pos,Vector3.ZERO)
 world.record_enemy_death(-1,world.enemy_pos,Vector3.ZERO)
 world.enemy_hp=0
 world.scouts.clear()
 world.finish_combat(1,world.enemy_pos)
 var saved:=Slots._save_digest(G)
 var kill_sparks := int(world.Director.config().leader_essence_sparks) * (6 if world.Enemies.get_kind(world.enemy_kind).get("boss",false) else 1)
 @warning_ignore("integer_division")
 var reward_balance := 2 + kill_sparks / int(world.Director.config().essence_sparks_per_point)
 check(world.encounter_rewarded and world.MonsterRewards.flush(world) and Slots._save_digest(G)==saved
  and world.wallet_for(leader).earned_sparks()==kill_sparks and world.wallet_for(guest).earned_sparks()==kill_sparks
  and world.run_wallet(leader)==reward_balance and world.run_wallet(guest)==reward_balance,
  "one kill plus one floor milestone grants the same expected balance to both participants")
 world.send_expedition_state(0,true)
 mark("reward-wallet",str(reward_balance))
 mark("rewards",str(world.enemy_kind))
 if not await until(func():return marked("saw-rewards")):
  check(false,"guest stores one XP/monster projection")
  return
 check(guest.character.monsters[world.enemy_kind]==1,"duplicate kill is ignored")
 record("party_rewards",before,{"guest_count":guest.character.monsters[world.enemy_kind]})
 world.encounter_number=3
 world.deepest_milestone=3
 leader.pos=world.battlefield.advance
 guest.pos=world.battlefield.advance
 world.use_checkpoint(1,true)
 world.choose_checkpoint_card(1,leader,-1)
 mark("cards")
 if not await until(func():return world.checkpoint_ready.get(id)==3):
  check(false,"guest chooses checkpoint card")
  return
 check(world.encounter_number==3,"choosing cards does not travel")
 var before_travel: int = world.run_wallet(guest)
 world.use_checkpoint(1,true)
 mark("advance-wallet",str(before_travel))
 mark("advance",str(world.travel_epoch))
 if not await until(func():return world.encounter_number==4):
  check(false,"advancement commits after both consent")
  return
 check(world.run_wallet(guest)==before_travel,"floor travel retains the guest wallet")
 world.send_expedition_state(0,true)
 if not await until(func():return marked("saw-advance")):
  check(false,"guest sees committed advancement")
  return
 world.encounter_number=6
 world.deepest_milestone=6
 world.enemy_hp=0
 world.scouts.clear()
 world.encounter_rewarded=true
 leader.pos=world.battlefield.advance
 guest.pos=world.battlefield.advance
 guest.carried_seeds=[0]
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_CANT_CREATE if phase=="publish_receipt" else OK)
 world.use_checkpoint(1,false)
 mark("extract",str(world.travel_epoch))
 if not await until(func():return not world.expedition_active() and Tx.pending_notice(world)==Tx.CLEANUP_NOTICE):
  check(false,"party extraction commits with cleanup pending")
  return
 # Production keeps streaming public state after a cleanup-pending commit.
 # The one deferred snapshot is unreliable, so restore that normal send loop
 # now that no further simulation or canonical writes are allowed.
 world.set_physics_process(true)
 var committed:=Slots._save_digest(G)
 check(world.progress.reserve(guest.seed_owner).unknown==[0] and FileAccess.file_exists(G+".transaction")
  and world.run_wallet(leader)==0 and world.run_wallet(guest)==0,"extraction banks the guest seed and clears both wallets")
 if not await until(func():return marked("saw-extraction")):
  check(false,"guest sees Garden transition and retained warning")
  return
 world.tell(id,"A later host message.")
 mark("host-message")
 if not await until(func():return marked("guest-offline") and world.multiplayer.get_peers().is_empty()):
  check(false,"guest detached before host teardown")
  return
 check(Slots._save_digest(G)==committed and world.progress.reserve(guest.seed_owner).unknown==[0],"pending, duplicate votes and disconnect cannot change committed Garden")
 record("party_extraction_cleanup",before,{"guest_seed":1,"notice":Tx.pending_notice(world),"offline_guest":true})

func guest_run() -> void:
 check(world.join_game("127.0.0.1")==OK,"guest joins with own lease")
 if not await until(func():return world.session=="Guest" and marked("depart-abort")):
  check(false,"guest sees readiness barrier")
  return
 var original:=Slots._save_digest(G)
 world.send_garden_action("travel_ready:"+read("depart-abort"))
 if not await until(func():return world.status.begins_with("Save cancelled")):
  check(false,"guest sees verified abort")
  return
 check(Slots._save_digest(G)==original,"abort preserves Garden")
 mark("saw-abort")
 if not await until(func():return marked("depart-commit")):
  check(false,"new readiness epoch")
  return
 world.send_garden_action("travel_ready:"+read("depart-abort"))
 await create_timer(.12).timeout
 check(not marked("departed"),"stale readiness epoch cannot depart")
 world.send_garden_action("travel_ready:"+read("depart-commit"))
 if not await until(func():return marked("departed") and world.players.get(world.local_player_id(),{}).get("wild",false)):
  check(false,"guest enters Wilds after commit")
  return
 check(world.players.get(world.local_player_id(),{}).get("wallet",-1)==0,"guest projects a fresh wallet at departure")
 mark("saw-departure")
 var reward_received:=func():
  return (marked("rewards") and world.guest_character.data.monsters[int(read("rewards"))]==1
   and world.players.get(world.local_player_id(),{}).get("wallet",-1)==int(read("reward-wallet")))
 if not await until(reward_received):
  check(false,"guest persists one reward projection")
  return
 var after:=Slots._save_digest(C)
 var verified:=Profile.new()
 verified.path=C
 check(verified.load_profile(false)==OK and verified.data.monsters[int(read("rewards"))]==1,"guest disk confirms one kill receipt")
 mark("saw-rewards")
 if not await until(func():return marked("cards") and world.checkpoint_menu.visible):
  check(false,"guest sees checkpoint cards")
  return
 world.send_garden_action("checkpoint_choice_-1")
 if not await until(func():return marked("advance")):
  check(false,"guest checkpoint readiness prompt")
  return
 world.send_garden_action("travel_ready:"+read("advance"))
 var advance_received:=func():
  return (world.encounter_number==4
   and world.players.get(world.local_player_id(),{}).get("wallet",-1)==int(read("advance-wallet")))
 if not await until(advance_received):
  check(false,"guest observes authoritative advancement")
  return
 mark("saw-advance")
 if not await until(func():return marked("extract")):
  check(false,"guest extraction ready")
  return
 world.send_garden_action("travel_ready:"+read("extract"))
 if not await until(func():return not world.players.get(world.local_player_id(),{}).get("wild",true) and world.get_meta(&"guarded_host_cleanup_notice","")==Tx.CLEANUP_NOTICE):
  check(false,"guest sees committed Garden transition with warning")
  return
 world.send_garden_action("travel_ready:"+read("extract"))
 check(world.players.get(world.local_player_id(),{}).get("wallet",-1)==0,"guest Garden snapshot carries no departed balance")
 mark("saw-extraction")
 if not await until(func():return marked("host-message") and world.status.begins_with("A later")):
  check(false,"guest gets later ordinary feedback")
  return
 world.toast_until=0
 world.refresh_feedback()
 check(world.feedback.text==Tx.CLEANUP_NOTICE and Slots._save_digest(C)==after,"cleanup warning survives toast and extraction does not duplicate profile credit")
 record("guest_transition_and_warning",original,{"floor":world.encounter_number,"feedback":world.feedback.text})
 world.leave_game("Guest fixture complete")
 check(world.online_peer==null and world.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"guest offline before detachment")
 mark("guest-offline")
