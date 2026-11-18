extends SceneTree
const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Cards = preload("res://affinity_cards.gd")

const Tx = preload("res://game_transaction.gd")
const Batch = preload("res://save_batch.gd")
const Slots = preload("res://save_slots.gd")
const Gate = preload("res://persistence_writer_integration.gd")
const Ops = preload("res://persistence_operations.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
var garden_path := "user://saves/slot_1/garden.cfg"
const C := "user://saves/characters/slot_1/character.cfg"
var failed := false
var world: Node

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func disk() -> Dictionary:
 var result := {}
 for path in [garden_path, C]:
  for suffix in [""] + Plan.ARTIFACTS:
   result[path + suffix] = Slots._save_digest(path + suffix)
 return result

func record(name: String, before: Dictionary, facts: Dictionary) -> void:
 print("CASE ", JSON.stringify({"case":name, "run_id":OS.get_environment("MYSTICAL_VALIDATION_RUN"),
  "before":before, "after":disk(), "facts":facts}))

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
  if title.creator.visible:
   title.creator.name_field.text = "Candidate Keeper"
   title.creator.confirmed.emit()
  if current_scene == title: title.new_button.pressed.emit()
 else:
  title.continue_button.pressed.emit()
 if current_scene == title or not SessionCase.has_guarded_session(current_scene):
  check(false, "guarded title handoff failed: " + title.notice.text)
  return false
 world = current_scene
 check(world.persistence_session.owns_leases(), "title handoff owns Garden and profile leases")
 world.set_process(false)
 world.set_physics_process(false)
 var actor: Dictionary=world.players[1]
 var tree=world.Classes.connected_tree(int(actor.frame))
 if tree.focus(actor.character).is_empty():
  var prior_position: Vector3=actor.pos
  actor.pos=world.Stage.HEART
  world.handle_loadout_action(1,actor,"learn_%d_64"%int(actor.frame))
  actor.pos=prior_position
  world.toggle_overlay(null)
 return true

func close_world() -> void:
 world.return_to_main_menu()
 check(current_scene != world and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,
  "guarded title return installs offline peer")

func mature(slot: int, species: int) -> void:
 world.progress.plots[slot] = world.progress.empty_plot().merged({"species":species,"stage":3,"age":10000.0},true)
 world.progress.sync_plot_flags()

func audio_count() -> int:
 return world.combat_events.filter(func(event): return event.shape == "crop_harvested").size()

func run() -> void:
 set_meta(Gate.VALIDATION_ROUTE, true)
 if not open_world(true):
  quit(1)
  return
 await gameplay()
 if not failed:
  current_scene.select_slot(1)
  garden_path = "user://saves/slot_2/garden.cfg"
  await caller_effects()
 if not failed: print("PASS: guarded Garden actions, harvest, modern cards, loadouts, abort, uncertainty and cleanup")
 quit(1 if failed else 0)

func fail_stage(phase: String, _path: String) -> Error:
 return ERR_FILE_CANT_WRITE if phase=="stage" else OK

func historical_refund() -> void:
 var actor: Dictionary=world.players[1]
 var original: Dictionary=actor.character.duplicate(true)
 var historical: Dictionary=world.Character.blank()
 historical.upgrades[0]=1
 historical.xp[0]=350
 # Install the fixture through the canonical guarded profile owner before
 # testing rollback. Replacing only the actor dictionary would leave its
 # serializer pointing at a different, unmodified character.
 var initialized: Dictionary=world.run_guarded_action(1,Tx.Scope.PAIR,func(effects):
  world.players[1].character=historical.duplicate(true)
  world.save_action_profile(1,effects))
 actor=world.players[1]
 check(Tx.committed(initialized.persistence) and actor.character==historical and world.local_character.data==historical,
  "historical fixture is durably initialized with one canonical profile")
 actor.pos=world.Stage.HEART
 var before:=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.handle_loadout_action(1,actor,"respec_0")
 world.remove_meta(&"guarded_gameplay_test_fault")
 actor=world.players[1]
 check(actor.character==historical and disk()==before,"failed historical refund restores masks, XP and durable files")
 world.handle_loadout_action(1,actor,"respec_0")
 check(actor.character.upgrades[0]==0 and actor.character.xp[0]==350
  and world.Classes.connected_tree(0).eligible(actor.character),"accepted historical refund retains XP and archives investments")
 var restored: Dictionary=world.run_guarded_action(1,Tx.Scope.PAIR,func(effects):
  world.players[1].character=original
  world.save_action_profile(1,effects))
 check(Tx.committed(restored.persistence) and world.players[1].character==original and world.local_character.data==original,
  "fixture restores the original canonical character before subsequent cases")

func gameplay() -> void:
 historical_refund()
 var p: Dictionary = world.players[1]
 var parts = world.Parts
 var items = world.Items
 var before := disk()
 p.pos = world.Stage.ALTAR
 world.progress.stock[0] = 4
 world.progress.stock[1] = 4
 world.garden_action(1,"experiment")
 check(world.progress.stock[0]==3 and world.progress.stock[1]==3 and disk()[garden_path]!=before[garden_path] and disk()[C]==before[C], "experiment consumes seeds and commits only Garden")
 var breeding_before := disk()
 var breeding_rng: int = world.rng.state
 var breeding_stock: Array = world.progress.stock.duplicate()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.garden_action(1,"breed_0_1")
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(disk()==breeding_before and world.progress.stock==breeding_stock and world.rng.state==breeding_rng
  and world.status.begins_with("Save cancelled"),"breeding abort restores both parents and RNG")
 record("breeding_abort",breeding_before,{"feedback":world.status})
 world.garden_action(1,"breed_0_1")
 check(world.progress.stock[0]==2 and world.progress.stock[1]==2 and world.status.contains("seed gained"), "breeding consumes one per parent and reports success")
 var altar_before := disk()
 var ingredients := [{"source":"stash","item":items.seed_id(0)},{"source":"stash","item":items.seed_id(1)}]
 var recipes_before: Dictionary = world.progress.altar_recipes.duplicate(true)
 var altar_rng: int = world.rng.state
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.send_altar_action("combine",ingredients,1)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(disk()==altar_before and world.progress.altar_recipes==recipes_before and world.rng.state==altar_rng
  and world.status.begins_with("Save cancelled"),"Altar combine abort restores ingredients, recipes and RNG")
 record("altar_combine_abort",altar_before,{"feedback":world.status})
 world.send_altar_action("combine",ingredients,2)
 check(disk()[garden_path]!=altar_before[garden_path] and disk()[C]==altar_before[C]
  and world.progress.altar_recipes.size()==recipes_before.size()+1,"Altar combine commits Garden-only recipe")
 record("altar_combine_commit",altar_before,{"feedback":world.status})
 world.seed_reserve(p).unknown.assign([0,1])
 var identify_before := disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.send_altar_action("identify_all",[],3)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(disk()==identify_before and world.seed_reserve(p).unknown==[0,1]
  and world.status.begins_with("Save cancelled"),"identify-all abort preserves mystery seeds")
 record("identify_all_abort",identify_before,{"feedback":world.status})
 world.send_altar_action("identify_all",[],4)
 check(world.seed_reserve(p).unknown.is_empty() and disk()[garden_path]!=identify_before[garden_path]
  and disk()[C]==identify_before[C],"identify-all commits only Garden")
 record("identify_all_commit",identify_before,{"feedback":world.status})
 # Restore the ingredient count needed by the independent donation scenarios.
 world.progress.stock[0]=2
 world.progress.stock[1]=2
 p.pos = world.Stage.HEART
 world.seed_reserve(p).parts[1] = 2
 var shared: int = world.progress.part_count(1)
 world.garden_action(1,"donate")
 check(world.seed_reserve(p).parts[1]==1 and world.progress.part_count(1)==shared+1 and world.status.begins_with("Donated"), "part donation commits shared storage")
 world.handle_inventory_action(1,p,JSON.stringify({"operation":"transfer","source":"stash","target":"shared","item":items.seed_id(0),"quantity":1}))
 check(world.progress.stock[0]==1 and world.status.contains("Moved"), "seed donation uses guarded stash transfer")
 record("experiment_breeding_donations",before,{"stock":world.progress.stock.slice(0,3),"status":world.status})
 world.progress.knowledge = 40
 world.progress.add_parts(1, 4)
 var research_before := disk()
 var heart_before: Dictionary = world.progress.heart.serialize()
 var parts_before: Array = world.progress.parts.duplicate()
 var research_stages: Array[String] = []
 world.set_meta(&"guarded_gameplay_test_fault", func(phase, path):
  if phase == "stage": research_stages.append(path)
  return ERR_FILE_CANT_WRITE if phase == "stage" else OK)
 world.garden_action(1, "research")
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(disk() == research_before and world.progress.heart.serialize() == heart_before
  and world.progress.parts == parts_before and world.status.begins_with("Save cancelled")
  and research_stages == [garden_path + ".txn_stage"], "research abort restores Knowledge, research and bytes without success")
 record("research_abort",research_before,{"stages":research_stages,"feedback":world.status})
 world.garden_action(1, "research")
 check(world.progress.heart.active == "flowering" and world.status.begins_with("Researching")
  and disk()[garden_path] != research_before[garden_path] and disk()[C] == research_before[C], "research starts with Garden-only commit")
 var infused_before: int = world.progress.heart.infused.get("flowering", 0)
 world.garden_action(1, "research")
 check(int(world.progress.heart.infused.get("flowering", 0)) == infused_before + 1,
  "offering advances the committed research")
 record("research_start_and_infuse_commit",research_before,{"active":world.progress.heart.active,"feedback":world.status})
 var heart = world.progress.heart
 heart.work.flowering = heart.duration("flowering") - 0.1
 var timer_before := disk()
 var timer_model: Dictionary = heart.serialize()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.growth_clock=1.0
 world._physics_process(0.2)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(disk()==timer_before and heart.serialize()==timer_model and not world.progress.flowering_unlocked,
  "periodic completion abort restores research and unlock state")
 record("research_completion_abort",timer_before,{"feedback":world.status})
 world.growth_clock=1.0
 world._physics_process(0.2)
 check(world.progress.flowering_unlocked and disk()[garden_path]!=timer_before[garden_path] and disk()[C]==timer_before[C],
  "periodic completion commits Garden unlock")
 record("research_completion_commit",timer_before,{"feedback":world.status})
 var growth = world.progress.garden_interactions.growth
 var who: String = world.local_character.identity
 var seen_before: int = growth.seen.get(who,0)
 var sequence: int = preload("res://garden_growth_service.gd").projection(world,1).pending[0].sequence
 check(sequence>seen_before,"completed research creates a pending reveal")
 var receipt_before := disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.garden_action(1,"growth_ack:"+str(sequence))
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(disk()==receipt_before and int(world.progress.garden_interactions.growth.seen.get(who,0))==seen_before,
  "growth receipt abort preserves unseen reveal")
 record("growth_receipt_abort",receipt_before,{"seen":seen_before,"sequence":sequence})
 world.garden_action(1,"growth_ack:"+str(sequence))
 check(int(world.progress.garden_interactions.growth.seen.get(who,0))==sequence and disk()[garden_path]!=receipt_before[garden_path],
  "growth receipt commits matching reveal")
 var acknowledged := disk()
 world.garden_action(1,"growth_ack:"+str(sequence))
 check(disk()==acknowledged,"duplicate growth receipt cannot stage again")
 record("growth_receipt_commit",receipt_before,{"seen":sequence})
 world.progress.heart.unlocked.append("seed_archive")
 world.progress.heart.unlocked.append("monster_studies")
 p.pos = world.Stage.HEART_STATIONS.seed_archive
 world.progress.discoveries[0] = true
 world.seed_reserve(p).parts[int(world.Seeds.DEFINITIONS[0].part)] = 20
 var seed_count: int = world.progress.stock[0]
 world.garden_action(1,"care_reclaim_0")
 check(world.progress.stock[0]==seed_count+1 and world.status.begins_with("Reclaimed"), "reclaim commits replacement seed")
 p.pos = world.Stage.HEART_STATIONS.monster_studies
 world.seed_reserve(p).parts[parts.HOOK] = 1
 var knowledge: int = world.progress.knowledge
 world.garden_action(1,"care_offer_"+str(parts.HOOK))
 check(world.progress.knowledge==knowledge+4 and world.progress.heart.offered.has(parts.HOOK), "first offering consumes trophy and grants Knowledge")
 world.drop_inventory_stack(1,p,"stash",items.part_id(1),2)
 check(world.progress.ground_items.size()==1 and world.status.begins_with("Dropped"), "Garden stack committed to ground")
 if not world.progress.ground_items.is_empty():
  var key: String = world.progress.ground_items[0].id
  world.pickup_inventory_drop(1,p,key)
  check(world.progress.ground_items.is_empty() and world.status.begins_with("Picked up"), "Garden pickup commits once")
  var after := disk()
  world.pickup_inventory_drop(1,p,key)
  check(disk()==after,"duplicate pickup cannot credit twice")
 p.pos = world.Stage.GATE
 world.handle_loadout_action(1,p,"class_1")
 world.handle_loadout_action(1,p,"loadweapon_1")
 world.handle_loadout_action(1,p,"loadpart_0_1")
 check(p.frame==1 and p.weapon_kind==1 and p.prepared==1 and p.character.loadouts[1].parts[0]==1, "class and loadout selection update profile")
 world.seed_reserve(p).parts[1] = 0
 world.progress.add_parts(1,-world.progress.part_count(1))
 world.show_gate_preparation(1)
 check(world.loadout_menu.visible and p.prepared==0 and p.character.loadouts[1].parts[0]==0, "crafting reconciliation persisted before opening panel")
 var weaver_progression=world.Classes.connected_tree(1)
 p.character.xp[1]=weaver_progression.XP_THRESHOLDS[1]
 p.pos=world.Stage.HEART
 var learn := "learn_1_"+str(weaver_progression.REQUEST_OFFSET)
 var learn_before := disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.garden_action(1,learn)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(weaver_progression.path(p.character).is_empty() and disk()==learn_before and world.status.begins_with("Save cancelled"),
  "learning abort preserves skill points, profile bytes and failure feedback")
 record("class_learn_abort",learn_before,{"feedback":world.status})
 world.garden_action(1,learn)
 check(weaver_progression.path(p.character)==["thornbinder"] and world.status.begins_with("Learned"), "connected focus learning commits")
 world.garden_action(1,"learn_1_67")
 check(weaver_progression.path(p.character)==["thornbinder","twining_reach"] and p.character.xp[1]==50,"earned second level grants its connected selection")
 world.handle_loadout_action(1,p,"respec_1")
 check(weaver_progression.path(p.character).is_empty() and p.character.xp[1]==50 and world.status.begins_with("Class points refunded"), "connected respec commits without changing XP")
 record("stations_inventory_class_loadout",before,{"profile":p.character.loadouts[1],"status":world.status})

 p.pos=world.Stage.PLOTS[0]
 mature(0,0)
 before=disk()
 var rng_before: int=world.rng.state
 var start_audio:=audio_count()
 var stage_attempts: Array[String] = []
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="stage": stage_attempts.append(path)
  return ERR_FILE_CANT_WRITE if phase=="stage" and path==C+".txn_stage" else OK)
 check(not world.harvest(1,0), "profile serializer failure aborts actual harvest")
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(stage_attempts.has(C+".txn_stage") and disk()==before and world.progress.plots[0].species==0
  and p.character.plants[0]==0 and world.rng.state==rng_before and audio_count()==start_audio
  and world.status.begins_with("Save cancelled"), "abort restores bytes, bed, profile, RNG and withholds audio")
 record("harvest_serializer_abort",before,{"staged":stage_attempts,"status":world.status,"audio":audio_count()})
 check(world.harvest(1,0) and world.progress.plots[0].species<0 and p.character.plants[0]==1
  and world.rng.state!=rng_before and disk()[garden_path]!=before[garden_path] and disk()[C]!=before[C] and audio_count()==start_audio+1,
  "retry commits crop, Garden and profile, with one post-commit cue")
 check(not world.harvest(1,0) and audio_count()==start_audio+1, "duplicate harvest cannot reward or emit")
 record("harvest_retry_committed",before,{"profile":p.character.plants[0],"status":world.status,"audio":audio_count()})
 world.progress.flowering_unlocked=true
 mature(0,0)
 before=disk()
 rng_before=world.rng.state
 seed_count=world.progress.stock[0]
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_CANT_CREATE if phase=="publish_receipt" else OK)
 world.garden_action(1,"flower")
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.refresh_feedback()
 check(world.progress.stock[0]==seed_count+2 and p.character.plants[0]==2 and world.rng.state==rng_before and audio_count()==start_audio+2
  and disk()[garden_path]!=before[garden_path] and disk()[C]!=before[C] and Plan.discover(PackedStringArray([garden_path])).state=="pending_recovery"
  and world.feedback.text.contains("Harvested two") and world.feedback.text.contains("Recovery cleanup is pending"),
  "flowering confirmed with one success/audio and retained cleanup warning")
 var committed:=disk()
 world.garden_action(1,"flower")
 check(disk()==committed and audio_count()==start_audio+2,"pending blocks replay")
 record("flower_committed_cleanup_pending",before,{"notice":world.persistence_session.pending_notice(),"feedback":world.feedback.text,"audio":audio_count()})
 check(Ops.recover(PackedStringArray([garden_path])).value.verified and disk()[garden_path]==committed[garden_path] and disk()[C]==committed[C], "verified B2 cleanup preserves committed bytes")
 close_world()
 await process_frame
 if not open_world(): return
 p=world.players[1]
 check(p.character.plants[0]==2 and world.persistence_session.can_write() and audio_count()==0, "reopen restores availability without replay")

 ExpeditionCase.set_membership(world, p, true)
 # Cumulative graft rollback is covered by cr05_native_grafts.
 ExpeditionCase.set_world(world, {"encounter_number": 18})
 world.deepest_milestone=18
 world.encounter.set_hp(-1, 0)
 world.encounter.clear_scouts()
 world.checkpoint_pending=true
 p.pos=world.battlefield.advance
 p.weapon=parts.VEIL
 var offer: Dictionary=world.checkpoint_card_data(p)[0]
 var spent: int=world.wallet_for(p).spent_essence()
 var command: String=world.affinity_checkpoint_action(offer.revision,"0")
 world.send_garden_action(command)
 check(Cards.ledger(p).count()==1 and world.wallet_for(p).spent_essence()==spent and world.checkpoint_ready.get(1)==18
  and world.participation.floor()==18,"free card is acquired without checkpoint advancement or Essence spending")
 world.send_garden_action(command)
 check(Cards.ledger(p).count()==1 and world.wallet_for(p).spent_essence()==spent,"duplicate card cannot acquire or spend twice")
 world.progress.heart.unlocked.append("checkpoint_deposit")
 p.carried_parts[1]=1
 world.garden_action(1,"bank_part_1")
 check(p.last_deposit==18 and p.carried_parts[1]==0 and world.seed_reserve(p).parts[1]==1, "courier persists one stack item")
 world.progress.heart.unlocked.append("perfect_recollection")
 world.consider_recollection()
 check(not world.progress.heart.recollection_seen, "retired finale recollection remains dormant")
 record("cards_courier_recollection",before,{"spent":spent,"floor":world.participation.floor(),"cards":Cards.ledger(p).count(),"status":world.status})

 ExpeditionCase.set_membership(world, p, false)
 p.pos=world.Stage.PLOTS[0]
 mature(0,0)
 before=disk()
 rng_before=world.rng.state
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="replace" and path==garden_path:return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase=="restore" else OK)
 check(not world.harvest(1,0), "uncertain actual harvest withholds success")
 world.remove_meta(&"guarded_gameplay_test_fault")
 var split:=disk()
 check(world.progress.plots[0].species<0 and p.character.plants[0]==3 and world.rng.state!=rng_before and audio_count()==0
  and split[C]!=before[C] and split[garden_path]==before[garden_path] and world.persistence_session.pending_notice().contains("uncertain"),"uncertainty preserves tentative memory and split proof without cue")
 check(not world.harvest(1,0) and split==disk(),"uncertain replay refused")
 record("harvest_uncertain",before,{"tentative_familiarity":p.character.plants[0],"notice":world.persistence_session.pending_notice()})
 check(Ops.recover(PackedStringArray([C])).value.verified and disk()==before, "reverse recovery restores original pair")
 close_world()
 await process_frame
 if not open_world(): return
 p=world.players[1]
 p.pos=world.Stage.PLOTS[0]
 mature(0,0)
 before=disk()
 var lease_path: String=C.get_base_dir().path_join("session.cfg")
 var original_lease:=FileAccess.get_file_as_bytes(lease_path)
 var cfg:=ConfigFile.new()
 cfg.set_value("session","process_id",OS.get_process_id()+90000)
 cfg.set_value("session","updated",Time.get_unix_time_from_system())
 check(cfg.save(lease_path)==OK and not world.harvest(1,0) and disk()==before and world.progress.plots[0].species==0,"foreign lease refuses before callback")
 cfg.set_value("session","process_id",OS.get_process_id())
 cfg.set_value("session","updated",Time.get_unix_time_from_system()-9999)
 check(cfg.save(lease_path)==OK and not world.harvest(1,0) and disk()==before and world.progress.plots[0].species==0,"expired lease refuses before callback")
 var lease:=FileAccess.open(lease_path,FileAccess.WRITE)
 lease.store_buffer(original_lease)
 lease.close()
 cfg=ConfigFile.new()
 cfg.set_value("transaction","entries",{garden_path:{"exists":true,"bytes":FileAccess.get_file_as_bytes(garden_path)}})
 cfg.set_value("transaction","committed",false)
 check(cfg.save(garden_path+".transaction")==OK,"create pending journal")
 before=disk()
 check(not world.harvest(1,0) and disk()==before and world.progress.plots[0].species==0 and world.persistence_session.pending_notice().contains("recovery is pending"),"pending journal refuses without mutation")
 record("lease_and_recovery_refusals",before,{"notice":world.persistence_session.pending_notice()})
 check(Ops.recover(PackedStringArray([garden_path])).value.verified,"recover disposable pending fixture")
 close_world()
 await process_frame
 await terminal_wilds_faults()


func terminal_wilds_faults() -> void:
 if not open_world(): return
 var actor: Dictionary = world.players[1]
 ExpeditionCase.set_membership(world, actor, true)
 # Cumulative graft terminal outcomes are exercised by the GA01A fixtures.
 ExpeditionCase.set_world(world, {"encounter_number": 6})
 world.encounter.set_hp(-1, 0)
 world.encounter.clear_scouts()
 world.encounter_rewarded=true
 actor.pos=world.battlefield.advance
 world.progress.heart.unlocked.append("checkpoint_deposit")
 actor.carried_parts[1]=1
 var initial:=disk()
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):
  return ERR_CANT_CREATE if phase in ["publish_commit_marker","restore"] else OK)
 world.garden_action(1,"bank_part_1")
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(actor.carried_parts[1]==0 and actor.last_deposit==6 and world.persistence_session.pending_notice().contains("uncertain")
  and not world.status.begins_with("Banked") and disk()[garden_path+".transaction"]!="absent",
  "courier uncertainty retains tentative cargo and withholds success")
 var unresolved := disk()
 world.garden_action(1,"bank_part_1")
 check(disk()==unresolved,"courier replay is blocked")
 record("courier_uncertain",initial,{"notice":world.persistence_session.pending_notice()})
 close_world()
 await process_frame
 current_scene.garden_recovery_button.pressed.emit()
 current_scene.recovery_confirmation.confirmed.emit()
 check(disk()==initial,"title B2 restores courier original bytes")

func caller_effect_fault(phase: String, _path: String, outcome: String, attempts: Dictionary) -> Error:
 if phase=="stage":
  attempts.count+=1
  if outcome=="ABORTED_RESTORED": return ERR_FILE_CANT_WRITE
 if outcome=="UNCERTAIN" and phase in ["publish_commit_marker","restore"]: return ERR_CANT_CREATE
 if outcome=="COMMITTED_CLEANUP_PENDING" and phase=="publish_receipt": return ERR_CANT_CREATE
 return OK

func caller_effects() -> void:
 var fresh := true
 for action in ["water","observation"]:
  for outcome in ["ABORTED_RESTORED","UNCERTAIN","COMMITTED_CLEANUP_PENDING"]:
   if not open_world(fresh): return
   fresh=false
   var player: Dictionary=world.players[1]
   var committed: bool = outcome=="COMMITTED_CLEANUP_PENDING"
   var aborted: bool = outcome=="ABORTED_RESTORED"
   var command := ""
   match action:
    "water":
     for tech in ["clearing_1","irrigation"]:
      if not world.progress.heart.has(tech): world.progress.heart.unlocked.append(tech)
     var bed: Dictionary=world.progress.empty_plot().merged({"species":0,"stage":1},true)
     preload("res://garden_crop_state.gd").ensure(bed)
     preload("res://cultivation_growth.gd").initialize(bed)
     world.progress.plots[0]=bed
     world.progress.sync_plot_flags()
     player.spring_water=true
     player.pos=world.Stage.PLOTS[0]
     command="garden:"+JSON.stringify({"point":"bed_1","action":"water_crop","request":"f6-water",
      "revision":bed.care.revision,"stage":1,"cycle":bed.care.cycle})
    "observation":
     var point := preload("res://garden_interaction_catalog.gd").point("heart_root_scar")
     player.pos=point.position
     command="garden:"+JSON.stringify({"point":point.id,"action":"observe","request":"f6-observation",
      "revision":world.progress.garden_interactions.get("revision",0)})
   var before := disk()
   var journal = preload("res://diagnostic_journal.gd").current
   var sequence_before: int=journal.sequence
   var rng_before: int=world.rng.state
   var attempts := {"count":0}
   world.set_meta(&"guarded_gameplay_test_fault",caller_effect_fault.bind(outcome,attempts))
   world.send_garden_action(command)
   var after := disk()
   var status: String=world.status
   var notice: String = world.persistence_session.pending_notice()
   var staged: int=attempts.count
   var finalization := {}
   for line in FileAccess.get_file_as_string(journal.file.get_path()).split("
",false):
    var row: Variant=JSON.parse_string(line)
    if row is Dictionary and row.seq>sequence_before and row.event=="guarded_gameplay_result":
     finalization=row.data
   check(finalization.get("outcome")==outcome,action+" produced exact typed finalization")
   var facts := {"outcome":finalization,"status":status,"notice":notice,"stages":staged,
    "rng_before":str(rng_before),"rng_after":str(world.rng.state)}
   check(staged>0 and world.rng.state==rng_before,action+" stages without consuming RNG")
   check((after==before and notice.is_empty() and status.begins_with("Save cancelled")) if aborted else
    (after[garden_path]!=before[garden_path] and after[garden_path+".transaction"]!="absent" and not world.persistence_session.can_write()
     and ((notice==Tx.CLEANUP_NOTICE) if committed else notice.contains("uncertain"))),action+" "+outcome+" evidence")
   player=world.players[1]
   match action:
    "water":
     var watered := preload("res://cultivation_growth.gd").watered(world.progress.plots[0])
     var cues: int=world.combat_events.filter(func(event):return event.shape=="crop_watered").size()
     check(watered==not aborted and bool(player.spring_water)==not committed and cues==int(committed)
      and status.begins_with("Spring water nourishes")==committed,"water cost, crop, and cue match "+outcome)
     facts.merge({"watered":watered,"vessel_filled":player.spring_water,"cues":cues,
      "revision":world.progress.plots[0].care.revision})
    "observation":
     var state: Dictionary=world.progress.garden_interactions
     var recorded := preload("res://garden_interaction_state.gd").observed(state,"old_root_scar")
     var receipt := preload("res://garden_interaction_state.gd").receipt(state,world.local_character.identity+":f6-observation")
     check(recorded==not aborted and receipt.is_empty()==aborted
      and status.begins_with("Garden observation recorded")==committed,"observation discovery and notification match "+outcome)
     facts.merge({"recorded":recorded,"receipt":receipt,"revision":state.get("revision",0)})
   if not aborted:
    world.send_garden_action(command)
    world.refresh_feedback()
    check(attempts.count==staged and disk()==after and world.rng.state==rng_before
     and world.feedback.text.contains(notice),action+" replay leaves bytes, RNG, and visible warning intact")
    facts["feedback_after_replay"]=world.feedback.text
   world.remove_meta(&"guarded_gameplay_test_fault")
   record(action+"_"+outcome.to_lower(),before,facts)
   close_world()
   await process_frame
   if not aborted:
    current_scene.garden_recovery_button.pressed.emit()
    check(not current_scene.recovery_confirmation.get_ok_button().disabled,action+" recovery plan selectable")
    current_scene.recovery_confirmation.confirmed.emit()
    current_scene.recovery_confirmation.hide()
    check(disk()[garden_path]==(after[garden_path] if committed else before[garden_path]) and disk()[C]==(after[C] if committed else before[C])
     and disk()[garden_path+".transaction"]=="absent",action+" recovery preserves the authoritative version")
