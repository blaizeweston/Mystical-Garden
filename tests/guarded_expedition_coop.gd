extends SceneTree
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")

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
 world.network_session.configure_join_origin(not host)
 var started: Dictionary =world.persistence_session.start(world.progress,world.local_character,world.guest_character,slots if host else null,0,Slots._save_digest(G) if host else "",roster,0 if host else 1,Slots._save_digest(path))
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
 if is_instance_valid(world) and world.network_session.transport()!=null: world.session_world.leave("Fixture finished")
 var offline:=await until(func():return root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer)
 check(offline,"offline peer before world removal")
 if offline and is_instance_valid(world): world.free()
 if not failed: print("PASS: guarded expedition co-op ","host" if host else "guest")
 quit(1 if failed else 0)

func host_run() -> void:
 check(world.session_world.host()==OK,"guarded host listens")
 mark("hosting")
 if not await until(func():return world.players.size()==2 and world.players.values().all(func(p):return SessionCase.Session.ready_for(p))):
  check(false,"guarded guest admission")
  return
 var id: int=world.players.keys().filter(func(p):return p!=1)[0]
 var leader: Dictionary=world.players[1]
 var guest: Dictionary=world.players[id]
 var guest_identity := SessionCase.Session.inventory_owner(guest)
 leader.pos=world.stage.gate_position()
 guest.pos=world.stage.gate_position()
 for actor in [leader,guest]:
  var tree=world.Classes.connected_tree(int(actor.frame))
  actor.character[tree.profile_key]=tree.state([tree.nodes[0].id])
 world.progress.add_parts(1,3)
 leader.prepared=1
 var before:=Slots._save_digest(G)
 var stages:={"count":0}
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="stage":
   stages.count+=1
   return ERR_FILE_CANT_WRITE
  return OK)
 world.expedition_transitions.enter(1)
 mark("depart-abort",str(world.participation.travel_epoch()))
 if not await until(func():return stages.count==1 and marked("saw-abort")):
  check(false,"party departure fault")
  return
 check(not ExpeditionCase.is_wild(leader) and not ExpeditionCase.is_wild(guest) and Slots._save_digest(G)==before and world.progress.part_count(1)==3
  and world.run_wallet(leader)==0 and world.run_wallet(guest)==0,"no departure effects or Essence before commitment")
 record("party_departure_abort",before,{"wild":false,"stage_count":stages.count,"travel_epoch":world.participation.travel_epoch()})
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.expedition_transitions.enter(1)
 mark("depart-commit",str(world.participation.travel_epoch()))
 if not await until(func():return ExpeditionCase.is_wild(leader) and ExpeditionCase.is_wild(guest)):
  check(false,"both votes commit one departure")
  return
 check(world.progress.part_count(1)==2 and world.run_wallet(leader)==0 and world.run_wallet(guest)==0,
  "party consumed one reserved part and both wallets start at zero")
 world.send_expedition_state(0,true)
 mark("departed")
 if not await until(func():return marked("saw-departure")):
  check(false,"guest sees committed floor")
  return
 world.encounter.set_hp(-1, 0)
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 world.encounter.clear_scouts()
 world.finish_combat(1,world.tactics.position)
 var saved:=Slots._save_digest(G)
 var kill_sparks := int(world.Director.config().leader_essence_sparks) * (6 if world.Enemies.get_kind(world.enemy_kind).get("boss",false) else 1)
 @warning_ignore("integer_division")
 var reward_balance := 2 + kill_sparks / int(world.Director.config().essence_sparks_per_point)
 check(world.encounter_rewarded and world.flush_kill_rewards() and Slots._save_digest(G)==saved
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
 ExpeditionCase.set_world(world, {"encounter_number": 3})
 world.deepest_milestone=3
 leader.pos=world.battlefield.advance
 guest.pos=world.battlefield.advance
 world.expedition_transitions.checkpoint(1,true)
 world.garden_action(1,world.affinity_checkpoint_action(int(world.checkpoint_card_data(leader)[0].revision),"skip"))
 mark("cards")
 if not await until(func():return world.checkpoint_ready.get(id)==3):
  check(false,"guest chooses checkpoint card")
  return
 check(world.participation.floor()==3,"choosing cards does not travel")
 var before_travel: int = world.run_wallet(guest)
 var now := Time.get_ticks_msec()
 var timers: Cooldowns.Timers = guest[Cooldowns.STATE].with_deadline(Cooldowns.Q, now+25000).with_deadline(Cooldowns.R, now+26000).with_deadline(Cooldowns.DODGE, now+27000)
 guest[Cooldowns.STATE] = timers
 guest[PlayerVitals.STATE] = guest[PlayerVitals.STATE].with_hp(1.0)
 var health_before: PlayerVitals.Health = guest[PlayerVitals.STATE]
 var life_before: PlayerLifecycle.Life = guest[PlayerLifecycle.STATE]
 world.expedition_transitions.checkpoint(1,true)
 mark("advance-wallet",str(before_travel))
 mark("advance",str(world.participation.travel_epoch()))
 if not await until(func():return world.participation.floor()==4):
  check(false,"advancement commits after both consent")
  return
 check(world.run_wallet(guest)==before_travel,"floor travel retains the guest wallet")
 check(is_same(guest[Cooldowns.STATE],timers) and is_same(guest[PlayerLifecycle.STATE],life_before),
  "floor travel preserves cooldown deadlines and the current life generation")
 var recovered: PlayerVitals.Health = guest[PlayerVitals.STATE]
 check(health_before.hp()==1.0 and recovered.hp()>1.0 and recovered.max_hp()==health_before.max_hp(),"floor recovery preserves native capacity")
 mark("advance-hp",str(recovered.hp()))
 world.send_expedition_state(0,true)
 if not await until(func():return marked("saw-advance")):
  check(false,"guest sees committed advancement")
  return
 ExpeditionCase.set_world(world, {"encounter_number": 6})
 var knowledge_before_extract: int=world.progress.knowledge
 world.deepest_milestone=6
 world.encounter.set_hp(-1, 0)
 world.encounter.clear_scouts()
 world.encounter_rewarded=true
 leader.pos=world.battlefield.advance
 guest.pos=world.battlefield.advance
 guest.carried_seeds=[0]
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_CANT_CREATE if phase=="publish_receipt" else OK)
 world.expedition_transitions.checkpoint(1,false)
 mark("extract",str(world.participation.travel_epoch()))
 if not await until(func():return not world.participation.active() and world.persistence_session.pending_notice()==Tx.CLEANUP_NOTICE):
  check(false,"party extraction commits with cleanup pending")
  return
 # Production keeps streaming public state after a cleanup-pending commit.
 # The one deferred snapshot is unreliable, so restore that normal send loop
 # now that no further simulation or canonical writes are allowed.
 world.set_physics_process(true)
 var committed:=Slots._save_digest(G)
 check(world.progress.knowledge==knowledge_before_extract+2 and world.progress.reserve(guest_identity).unknown==[0] and FileAccess.file_exists(G+".transaction")
  and world.run_wallet(leader)==0 and world.run_wallet(guest)==0,"extraction banks the guest seed and clears both wallets")
 if not await until(func():return marked("saw-extraction")):
  check(false,"guest sees Garden transition and retained warning")
  return
 world.tell(id,"A later host message.")
 mark("host-message")
 if not await until(func():return marked("guest-offline") and world.multiplayer.get_peers().is_empty()):
  check(false,"guest detached before host teardown")
  return
 check(Slots._save_digest(G)==committed and world.progress.knowledge==knowledge_before_extract+2 and world.progress.reserve(guest_identity).unknown==[0],"pending, duplicate votes and disconnect cannot change committed Garden")
 check(SessionCase.Session.peer_for(guest)==0 and not SessionCase.Session.ready_for(guest),"released guest link cannot authorize later work")
 record("party_extraction_cleanup",before,{"guest_seed":1,"notice":world.persistence_session.pending_notice(),"offline_guest":true})

func guest_run() -> void:
 check(world.session_world.join("127.0.0.1")==OK,"guest joins with own lease")
 if not await until(func():return world.network_session.role()=="Guest" and marked("depart-abort")):
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
 if not await until(func():return marked("departed") and ExpeditionCase.is_wild(world.players.get(world.local_player_id(),{}))):
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
 var verified:=Profile.new()
 verified.path=C
 check(verified.load_profile(false)==OK and verified.data.monsters[int(read("rewards"))]==1,"guest disk confirms one kill receipt")
 mark("saw-rewards")
 if not await until(func():return marked("cards")):
  check(false,"host reaches the upgrade gate")
  return
 world.send_action(false)
 if not await until(func():return marked("cards") and UIFixture.control(world,"checkpoint_menu").visible):
  check(false,"guest sees checkpoint cards")
  return
 world.send_garden_action(world.affinity_checkpoint_action(world.ui.checkpoint_revision(),"skip"))
 if not await until(func():return marked("advance")):
  check(false,"guest checkpoint readiness prompt")
  return
 world.send_garden_action("travel_ready:"+read("advance"))
 var advance_received:=func():
  var local: Dictionary = world.players.get(world.local_player_id(),{})
  var seconds: Array = local.get("skill_cooldowns", [0.0,0.0])
  return (world.participation.floor()==4 and local.get("wallet",-1)==int(read("advance-wallet"))
   and not local.get("skill_ready",true) and not local.get("skill_two_ready",true)
   and not local.get("dodge_ready",true) and seconds[0]>0.0 and seconds[1]>seconds[0]
   and not local.has(Cooldowns.STATE) and not local.has(PlayerVitals.STATE) and not local.has(PlayerLifecycle.STATE)
   and is_equal_approx(float(local.get("hp",0.0)),float(read("advance-hp"))))
 if not await until(advance_received):
  check(false,"guest observes advancement, projected cooldowns, and recovered health without host owner records")
  return
 mark("saw-advance")
 if not await until(func():return marked("extract")):
  check(false,"guest extraction ready")
  return
 world.send_garden_action("travel_ready:"+read("extract"))
 if not await until(func():return world.players.has(world.local_player_id()) and not ExpeditionCase.is_wild(world.players[world.local_player_id()]) and world.get_meta(&"guarded_host_cleanup_notice","")==Tx.CLEANUP_NOTICE):
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
 var before_profile:=verified.data.duplicate(true)
 before_profile.erase("archive_slice")
 var origin: String=world.get_meta("guest_projection_origin")
 check(await until(func():return world.guest_character.archive_visits.get(origin,{}).get("extracts")==1),"confirmed cleanup-pending extraction delivers the portable Archive slice")
 check(verified.load_profile(false)==OK and verified.archive_visits.get(origin,{}).get("runs")==1,"one expedition on the guest disk")
 var current_profile:=verified.data.duplicate(true)
 current_profile.erase("archive_slice")
 check(UIFixture.control(world,"feedback").text==Tx.CLEANUP_NOTICE and before_profile==current_profile,"cleanup notice persists and archive delivery leaves XP, monster rewards and equipment intact")
 record("guest_transition_and_warning",original,{"floor":world.participation.floor(),"feedback":UIFixture.control(world,"feedback").text})
 world.session_world.leave("Guest fixture complete")
 check(world.network_session.transport()==null and world.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"guest offline before detachment")
 mark("guest-offline")
