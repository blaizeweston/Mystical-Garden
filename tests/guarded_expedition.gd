extends SceneTree

const Tx=preload("res://game_transaction.gd")
const Plan=preload("res://persistence_recovery_plan.gd")
const Ops=preload("res://persistence_operations.gd")
const Slots=preload("res://save_slots.gd")
const Gate=preload("res://persistence_writer_integration.gd")
const G="user://saves/slot_1/garden.cfg"
const C="user://saves/characters/slot_1/character.cfg"
var failed:=false
var world: Node

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed=true
  printerr("FAIL: ",message)

func disk() -> Dictionary:
 var result:={}
 for p in [G,C]:
  for suffix in [""]+Plan.ARTIFACTS: result[p+suffix]=Slots._save_digest(p+suffix)
 return result

func record(label: String,before: Dictionary) -> void:
 print("CASE ",JSON.stringify({"case":label,"run_id":OS.get_environment("MYSTICAL_VALIDATION_RUN"),"before":before,"after":disk(),
  "floor":world.encounter_number,"wild":world.expedition_active(),"pending":Tx.pending_notice(world),"status":world.status,
  "queued_kills":world.pending_kill_rewards.size(),"queued_departures":world.departure_settlement.count(),"event_serial":world.combat_event_serial}))

func open_world(fresh := false) -> bool:
 var title: Node = current_scene
 if title == null:
  var scene: String = ProjectSettings.get_setting("application/run/main_scene")
  title = load(scene).instantiate()
  root.add_child(title)
  current_scene = title
 check(title.production_route and title.guarded_persistence, "configured title selects guarded route")
 if fresh:
  title.new_button.pressed.emit()
  check(title.creator.visible, "New opens title character creator")
  title.creator.name_field.text = "Candidate Keeper"
  title.creator.confirmed.emit()
  if current_scene == title: title.new_button.pressed.emit()
 else:
  title.continue_button.pressed.emit()
 if current_scene == title or not current_scene.has_meta(Tx.SESSION):
  check(false, "guarded title handoff failed: " + title.notice.text)
  return false
 world = current_scene
 check(world.get_meta(Tx.SESSION).owns_leases(), "title handoff owns Garden and profile leases")
 world.set_process(false)
 world.set_physics_process(false)
 return true

func close_world() -> void:
 world.return_to_main_menu()
 check(current_scene != world and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,
  "guarded title return installs offline peer")

func fail_stage(phase: String,path: String) -> Error:
 return ERR_FILE_CANT_WRITE if phase=="stage" and path==C+".txn_stage" else OK

func fail_restore(phase: String,path: String) -> Error:
 if phase=="replace" and path==G: return ERR_CANT_CREATE
 return ERR_FILE_CANT_WRITE if phase=="restore" else OK

func fail_receipt(phase: String,_path: String) -> Error:
 return ERR_CANT_CREATE if phase=="publish_receipt" else OK

func clear_floor(actor: Dictionary,floor: int) -> void:
 world.encounter_number=floor
 world.deepest_milestone=floor
 world.enemy_hp=0
 world.scouts.clear()
 world.encounter_rewarded=true
 actor.pos=world.battlefield.advance

func start_save_set() -> bool:
 set_meta(Gate.VALIDATION_ROUTE, true)
 return open_world(true)

func check_departure_lifecycle() -> void:
 var ledger := preload("res://departure_settlement.gd").new()
 var phase := ledger.Phase
 var outcome := ledger.Result
 var identity := "detached-profile"
 var snapshot := {"wild":true, "character":{"xp":[7]}, "safe_items":[{"quantity":1}]}
 ledger.register(2,identity,snapshot)
 ledger.register(2,identity,{"wild":false})
 snapshot.character.xp[0]=99
 check(ledger.count()==1 and ledger.status(identity)==phase.WAITING and ledger.has_wild_departure(),
  "one detached departure owns captured profile and cargo")
 check(ledger.stage([identity]).is_empty() and ledger.blocks_admission(identity),
  "deferred Class XP prevents retirement and readmission")
 var work := ledger.stage([])
 check(work.size()==1 and work[0].actor.character.xp[0]==7 and ledger.stage([]).is_empty()
  and ledger.status(identity)==phase.SETTLING,"staging detaches captured state and admits no duplicate work")
 work[0].actor.safe_items[0].quantity=5
 ledger.finish(outcome.RESTORED)
 check(ledger.status(identity)==phase.RETRYABLE and ledger.blocks_admission(identity),
  "verified rollback leaves departure retryable and blocks readmission")
 work=ledger.stage([])
 check(work.size()==1 and work[0].actor.safe_items[0].quantity==1,"rollback retries original cargo")
 ledger.finish(outcome.CLEANUP_PENDING)
 check(ledger.status(identity)==phase.CLEANUP_PENDING and ledger.blocks_admission(identity)
  and ledger.stage([]).is_empty(),"committed cleanup hold retains identity without replaying cargo")
 ledger.register(3,"second-profile",snapshot)
 work=ledger.stage([])
 ledger.finish(outcome.UNCERTAIN)
 check(work.size()==1 and ledger.status("second-profile")==phase.UNCERTAIN
  and ledger.stage([]).is_empty(),"uncertain departure cannot replay")
 ledger.finish(outcome.COMMITTED)
 check(ledger.count()==2,"later unrelated confirmation cannot retire unresolved holds")

func run() -> void:
 check_departure_lifecycle()
 var interruption:=OS.get_environment("MYSTICAL_GROUP3B2B_MODE")
 if interruption=="recover":
  var before:=disk()
  var recovered:=Ops.recover(PackedStringArray([C]))
  var verified: bool=recovered.ran and recovered.value is Dictionary and recovered.value.get("verified",false)
  check(verified,"interrupted combat settlement restored through profile: "+str(recovered))
  print("CASE ",JSON.stringify({"case":"restart","before":before,"after":disk(),"verified":verified}))
 elif start_save_set():
  if interruption=="owner":
   interrupted()
  else:
   await exercise()
 if not failed: print("PASS: guarded expedition settlement and lifecycle")
 quit(1 if failed else 0)

func interrupted() -> void:
 var actor: Dictionary=world.players[1]
 actor.pos=world.Stage.GATE
 world.enter_wilds(1,actor)
 world.record_enemy_death(-1,world.enemy_pos,Vector3.ZERO)
 world.enemy_hp=0
 world.scouts.clear()
 var before:=disk()
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="replace" and path==G:
   record("interruption_barrier",before)
   while true: OS.delay_msec(100)
  return OK)
 world.finish_combat(1,world.enemy_pos)
 check(false,"must terminate the owner at replacement")

func exercise() -> void:
 var actor: Dictionary=world.players[1]
 actor.pos=world.Stage.GATE
 actor.prepared=1
 world.progress.add_parts(1,3)
 var before:=disk()
 var field: RefCounted=world.battlefield
 var seed: int=world.map_rng.state
 world.open_gate_preparation()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.garden_action(1,"depart")
 check(disk()==before and not actor.wild and actor.prepared==1 and world.battlefield==field and world.map_rng.state==seed
  and world.loadout_menu.visible and world.run_wallet(actor)==0,
  "departure abort restores map RNG, battlefield, material, actor and open UI")
 record("departure_abort",before)
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.garden_action(1,"depart")
 check(actor.wild and actor.weapon==1 and world.progress.part_count(1)==2 and not world.loadout_menu.visible
  and disk()[G]!=before[G] and world.run_wallet(actor)==0,"departure commits a fresh wallet before panel closure")
 var initial_wallet = world.wallet_for(actor)
 record("departure_commit",before)

 world.record_enemy_death(-1,world.enemy_pos,Vector3.ZERO)
 var frozen: int=world.rng.state
 world.record_enemy_death(-1,world.enemy_pos,Vector3.ZERO)
 check(world.pending_kill_rewards.size()==1 and world.rng.state==frozen,"duplicate receipt does not reroll")
 world.pending_kill_rewards[0].rewards[0].item=world.Items.part_id(world.Parts.HOOK)
 world.enemy_hp=0
 world.scouts.clear()
 world.burst_hits_this_room=3
 before=disk()
 var serial: int=world.combat_event_serial
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.finish_combat(1,world.enemy_pos)
 check(not world.encounter_rewarded and not actor.loot_pending and actor.character.monsters[world.enemy_kind]==0 and world.pending_kill_rewards.size()==1
  and world.wild_item_drops.is_empty() and world.combat_event_serial==serial and world.rng.state==frozen and disk()==before
  and world.wallet_for(actor)==initial_wallet and world.run_wallet(actor)==0,"encounter abort keeps the frozen receipt and withholds rewards, drop and cue")
 record("encounter_abort",before)
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.finish_combat(1,world.enemy_pos)
 var earned_wallet = world.wallet_for(actor)
 var earned_balance: int = world.run_wallet(actor)
 check(world.encounter_rewarded and actor.loot_pending and earned_wallet.earned_sparks()>0
  and earned_balance>=2 and actor.character.monsters[world.enemy_kind]==1
  and world.wild_item_drops.size()==1 and world.progress.wilds_memory.encounters==1 and disk()[G]!=before[G] and disk()[C]!=before[C],
  "encounter commits frozen XP, trophy, adaptation, and cue together")
 var committed:=disk()
 world.finish_combat(1,world.enemy_pos)
 check(world.MonsterRewards.flush(world) and disk()==committed and world.wild_item_drops.size()==1
  and world.wallet_for(actor)==earned_wallet and world.run_wallet(actor)==earned_balance,"repeat flush and completion cannot credit twice")
 record("encounter_commit",before)

 world.add_player(2)
 var ally: Dictionary=world.players[2]
 ally.profile_ready=true
 ally.seed_owner="ally"
 ally.wild=true
 world.battlefield.procedural=false
 world.battlefield.barriers.clear()
 actor.pos=Vector3.ZERO
 ally.pos=Vector3(.5,0,0)
 var hp: int=int(actor.hp)
 world.damage_player(1,actor,1)
 check(int(actor.hp)==hp-1 and disk()==committed,"nonlethal damage is runtime-only")
 world.damage_player(1,actor,999)
 check(actor.fallen and actor.hp==0 and world.wallet_for(actor)==earned_wallet
  and world.run_wallet(actor)==earned_balance,"the downed player keeps their run wallet")
 world.revive_player(2,1)
 var paid: int=int(actor.lost_health)
 check(not actor.fallen and actor.hp>0 and paid>0 and world.wallet_for(actor)==earned_wallet
  and world.run_wallet(actor)==earned_balance,"revival commits one maximum-health cost without changing Essence")
 world.revive_player(2,1)
 check(actor.lost_health==paid,"duplicate revival cannot charge twice")
 ally.wild=false
 world.players.erase(2)

 clear_floor(actor,3)
 actor.offer_floor=3
 actor.checkpoint_offers=["power"]
 world.use_checkpoint(1,true)
 check(world.checkpoint_pending and world.checkpoint_menu.visible and world.encounter_number==3,"checkpoint opens cards without travelling")
 world.choose_checkpoint_card(1,actor,0)
 check(world.encounter_number==3 and world.checkpoint_ready.get(1)==3 and actor.power>0,"card commits before travel")
 actor.hp=1
 field=world.battlefield
 seed=world.map_rng.state
 var healing_rng: int=world.Life.Preview.heal_rng.state
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.use_checkpoint(1,true)
 check(world.encounter_number==3 and world.battlefield==field and world.map_rng.state==seed and world.Life.Preview.heal_rng.state==healing_rng
  and actor.hp==1 and world.checkpoint_ready.get(1)==3 and disk()==before,"floor abort restores navigation, RNG, vitals and purchased card")
 record("checkpoint_abort",before)
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.use_checkpoint(1,true)
 check(world.encounter_number==4 and world.battlefield!=field and world.map_rng.state!=seed and actor.hp>1,"checkpoint advances after confirmed save")

 clear_floor(actor,6)
 actor.carried_seeds=[0,1]
 actor.carried_parts[1]=2
 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_receipt)
 world.use_checkpoint(1,false)
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.refresh_feedback()
 check(not actor.wild and world.progress.unknown.size()==3 and world.progress.campaign.best_extraction==6 and disk()[G]!=before[G]
  and world.feedback.text.contains("Extracted with") and world.feedback.text.contains(Tx.CLEANUP_NOTICE) and FileAccess.file_exists(G+".transaction"),
  "cleanup-pending extraction commits inventory and progression and retains notice")
 committed=disk()
 world.use_checkpoint(1,false)
 check(disk()==committed and world.progress.unknown.size()==3,"pending extraction cannot replay")
 record("extraction_cleanup_pending",before)
 check(Ops.recover(PackedStringArray([G])).value.verified and disk()[G]==committed[G],"cleanup preserves committed extraction")
 close_world()
 await process_frame
 if not open_world(): return
 actor=world.players[1]

 actor.pos=world.Stage.GATE
 world.enter_wilds(1,actor)
 clear_floor(actor,2)
 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 actor.carried_seeds=[1]
 var saved_seeds: int=world.progress.unknown.size()
 world.damage_player(1,actor,999)
 check(not actor.wild and world.progress.unknown.size()==saved_seeds+1 and world.status.contains("safe-pouch"),"wipe keeps only protected cargo")
 actor.pos=world.Stage.GATE
 world.enter_wilds(1,actor)
 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 saved_seeds=world.progress.unknown.size()
 world.abandon_run(1,actor)
 check(not actor.wild and world.progress.unknown.size()==saved_seeds and world.status.contains("abandoned"),"abandonment discards safe pouch")

 actor.pos=world.Stage.GATE
 world.enter_wilds(1,actor)
 clear_floor(actor,6)
 actor.carried_seeds=[1]
 world.record_enemy_death(-1,world.enemy_pos,Vector3.ZERO)
 before=disk()
 world.open_gate_preparation()
 world.set_meta(&"guarded_gameplay_test_fault",fail_restore)
 world.use_checkpoint(1,false)
 world.remove_meta(&"guarded_gameplay_test_fault")
 var split:=disk()
 check(not actor.wild and world.progress.unknown.size()==saved_seeds+1 and world.loadout_menu.visible and Tx.pending_notice(world).contains("uncertain")
  and split[C]!=before[C] and split[G]==before[G] and not world.status.contains("Extracted with"),"uncertain extraction keeps tentative memory and withholds notice/closure")
 world.use_checkpoint(1,false)
 check(disk()==split,"uncertain operation does not replay")
 record("extraction_uncertain",before)
 close_world()
 await process_frame
 check(current_scene.recovery_notice.visible and current_scene.continue_button.disabled
  and disk()==split,"uncertain return preserves blocked title warning and evidence")
 current_scene.garden_recovery_button.pressed.emit()
 current_scene.recovery_confirmation.confirmed.emit()
 check(disk()==before and not current_scene.recovery_notice.visible,"title B2 restoration clears uncertain warning")
 if not open_world(): return
 actor=world.players[1]

 world.add_player(2)
 ally=world.players[2]
 ally.profile_ready=true
 var departed_identity := "0000000000000000000000000000a404"
 ally.seed_owner=departed_identity
 var departed_class := int(ally.frame)
 var xp_before := int(ally.character.xp[departed_class])
 actor.pos=world.Stage.GATE
 ally.pos=world.Stage.GATE
 world.enter_wilds(1,actor)
 world.enter_wilds(2,ally)
 ally.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 world.record_enemy_death(-1,world.enemy_pos,Vector3.ZERO)
 var receipt: Dictionary = world.pending_kill_rewards[0]
 var earned_xp := 0
 for reward: Dictionary in receipt.rewards:
  if reward.id==2: earned_xp=int(reward.xp)
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.remove_player(2)
 check(not world.players.has(2) and world.departure_settlement.status(departed_identity)==world.DepartureSettlement.Phase.RETRYABLE
  and world.pending_kill_rewards.size()==1 and disk()==before
  and not ally.has(world.ExpeditionWallet.STATE) and world.run_wallet(ally)==0,
  "failed disconnect settlement retains cargo and frozen reward and clears run-only currency")
 var catalog: Dictionary = world.progress.ContentIDs.manifest()
 check(world.admission_error(departed_identity,catalog,world.Network.PROTOCOL).contains("still being saved"),
  "verified rollback does not release the character before rewards settle")
 world.grant_run_essence(2,ally,4)
 check(not ally.has(world.ExpeditionWallet.STATE) and world.run_wallet(ally)==0,"pending departure cannot receive a credit")
 world.remove_meta(&"guarded_gameplay_test_fault")
 ally.character.xp[departed_class]+=100
 ally.safe_items.clear()
 # Simulate a non-banking operation between departure and the experimental
 # floor checkpoint without starting another terrain session.
 world.set_meta(&"experimental_terrain",true)
 var deferred: Dictionary=world.run_guarded_action(1,Tx.Scope.PAIR,func(effects):
  world.settle_expedition_rewards(effects)
  return true)
 world.remove_meta(&"experimental_terrain")
 check(Tx.committed(deferred.persistence) and world.departure_settlement.blocks_admission(departed_identity)
  and world.pending_kill_rewards.size()==1 and not world.progress.character_records.has(departed_identity),
  "non-banking transaction cannot retire the recipient of frozen Class XP")
 check(world.MonsterRewards.flush(world) and world.departure_settlement.is_empty() and world.pending_kill_rewards.is_empty()
  and earned_xp>0 and int(world.progress.character_records[departed_identity].profile.xp[departed_class])==xp_before+earned_xp
  and world.progress.character_records[departed_identity].profile.monsters[world.enemy_kind]==1
  and world.progress.reserve(departed_identity).unknown.size()==1
  and not ally.has(world.ExpeditionWallet.STATE) and world.run_wallet(ally)==0,
  "flush credits detached Class XP and pouch once without restoring a run wallet")
 var settled_disk:=disk()
 world.MonsterRewards.queue(world,receipt.key,int(receipt.kind),0,receipt.position,false)
 check(world.MonsterRewards.flush(world) and world.pending_kill_rewards.is_empty() and disk()==settled_disk
  and world.progress.reserve(departed_identity).unknown.size()==1,"delayed duplicate receipt cannot change settled profile or cargo")
 record("disconnect_abort_then_commit",before)

 var lease:=G.get_base_dir().path_join("session.cfg")
 var foreign:=ConfigFile.new()
 foreign.set_value("session","process_id",OS.get_process_id()+1)
 foreign.set_value("session","updated",Time.get_unix_time_from_system())
 check(foreign.save(lease)==OK,"inject foreign lease")
 before=disk()
 hp=int(actor.hp)
 world.damage_player(1,actor,999)
 world.finish_combat(1,world.enemy_pos)
 world.abandon_run(1,actor)
 check(int(actor.hp)==hp and actor.wild and disk()==before,"lost lease prevents combat and settlement writes")
 world.return_to_main_menu()
 check(world.get_meta(Tx.STOPPING,false) and disk()==before,"lost lease shuts down without saving")
 record("lost_lease_shutdown",before)
 await process_frame
 check(current_scene != world and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"lost lease shutdown detaches after offline")
 check(DirAccess.remove_absolute(lease)==OK,"remove disposable foreign marker")
 current_scene.select_slot(0)
 if not open_world(): return
 actor=world.players[1]
 actor.pos=world.Stage.GATE
 world.enter_wilds(1,actor)

 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(not world.get_meta(Tx.STOPPING,false) and actor.wild and disk()==before and current_scene==world,
  "window-close settlement abort keeps the world and original saves")
 record("window_close_abort",before)
 world.return_to_main_menu()
 check(not world.returning_to_title and actor.wild and disk()==before,"title settlement abort stays in expedition")
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.return_to_main_menu()
 check(world.returning_to_title and not actor.wild and world.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and disk()[G]!=before[G],
  "title return settles exactly once and installs offline peer")
 record("title_commit",before)
