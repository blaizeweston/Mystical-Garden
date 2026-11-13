extends SceneTree

const Tx = preload("res://game_transaction.gd")
const Batch = preload("res://save_batch.gd")
const Slots = preload("res://save_slots.gd")
const Gate = preload("res://persistence_writer_integration.gd")
const Ops = preload("res://persistence_operations.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
const G := "user://saves/slot_1/garden.cfg"
const C := "user://saves/characters/slot_1/character.cfg"
var failed := false
var world: Node

func _initialize() -> void:
 preload("res://combat_balance_preview.gd").enabled = false
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func disk() -> Dictionary:
 var result := {}
 for path in [G, C]:
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
 if not failed: print("PASS: guarded Garden actions, harvest, grafting, cards, loadouts, abort, uncertainty and cleanup")
 quit(1 if failed else 0)

func fail_stage(phase: String, _path: String) -> Error:
 return ERR_FILE_CANT_WRITE if phase=="stage" else OK

func gameplay() -> void:
 var p: Dictionary = world.players[1]
 var parts = world.Parts
 var items = world.Items
 var before := disk()
 p.pos = world.Stage.ALTAR
 world.progress.stock[0] = 4
 world.progress.stock[1] = 4
 world.garden_action(1,"experiment")
 check(world.progress.stock[0]==3 and world.progress.stock[1]==3 and disk()[G]!=before[G] and disk()[C]==before[C], "experiment consumes seeds and commits only Garden")
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
 check(disk()[G]!=altar_before[G] and disk()[C]==altar_before[C]
  and world.progress.altar_recipes.size()==recipes_before.size()+1,"Altar combine commits Garden-only recipe")
 record("altar_combine_commit",altar_before,{"feedback":world.status})
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
  and research_stages == [G + ".txn_stage"], "research abort restores Knowledge, research and bytes without success")
 record("research_abort",research_before,{"stages":research_stages,"feedback":world.status})
 world.garden_action(1, "research")
 check(world.progress.heart.active == "flowering" and world.status.begins_with("Researching")
  and disk()[G] != research_before[G] and disk()[C] == research_before[C], "research starts with Garden-only commit")
 var infused_before: int = world.progress.heart.infused.get("flowering", 0)
 world.garden_action(1, "research")
 check(int(world.progress.heart.infused.get("flowering", 0)) == infused_before + 1,
  "offering advances the committed research")
 record("research_start_and_infuse_commit",research_before,{"active":world.progress.heart.active,"feedback":world.status})
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
 p.character.xp[1]=1000
 p.pos=world.Stage.HEART
 var learn := "learn_1_"+str(world.Classes.DEFINITIONS[1].nodes.size())
 var learn_before := disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.garden_action(1,learn)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(p.character.upgrades[1]==0 and disk()==learn_before and world.status.begins_with("Save cancelled"),
  "learning abort preserves skill points, profile bytes and failure feedback")
 record("class_learn_abort",learn_before,{"feedback":world.status})
 world.garden_action(1,learn)
 check(p.character.upgrades[1]!=0 and world.status.begins_with("Learned"), "class learning commits")
 world.handle_loadout_action(1,p,"respec_1")
 check(p.character.upgrades[1]==0 and world.status.begins_with("Class points refunded"), "class respec commits")
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
  and world.rng.state!=rng_before and disk()[G]!=before[G] and disk()[C]!=before[C] and audio_count()==start_audio+1,
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
  and disk()[G]!=before[G] and disk()[C]!=before[C] and Plan.discover(PackedStringArray([G])).state=="pending_recovery"
  and world.feedback.text.contains("Harvested two") and world.feedback.text.contains("Recovery cleanup is pending"),
  "flowering confirmed with one success/audio and retained cleanup warning")
 var committed:=disk()
 world.garden_action(1,"flower")
 check(disk()==committed and audio_count()==start_audio+2,"pending blocks replay")
 record("flower_committed_cleanup_pending",before,{"notice":Tx.pending_notice(world),"feedback":world.feedback.text,"audio":audio_count()})
 check(Ops.recover(PackedStringArray([G])).value.verified and disk()[G]==committed[G] and disk()[C]==committed[C], "verified B2 cleanup preserves committed bytes")
 close_world()
 await process_frame
 if not open_world(): return
 p=world.players[1]
 check(p.character.plants[0]==2 and Tx.session_writable(world) and audio_count()==0, "reopen restores availability without replay")

 p.wild=true
 world.encounter_number=8
 p.pos=world.battlefield.graft
 p.carried_parts[parts.HOOK]=2
 var chosen_seed:=0
 for seed in range(100):
  world.rng.seed=seed
  if world.rng.randf()<world.graft_chance(p,parts.HOOK):
   chosen_seed=seed
   break
 world.rng.seed=chosen_seed
 var graft_before := disk()
 var graft_rng: int = world.rng.state
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 world.garden_action(1,"graft_install_"+str(parts.HOOK))
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(p.graft_part!=parts.HOOK and p.carried_parts[parts.HOOK]==2 and disk()==graft_before
  and world.rng.state==graft_rng and not world.graft_menu.visible,"graft abort keeps trophy, RNG and menu closed")
 record("graft_abort",graft_before,{"feedback":world.status})
 world.garden_action(1,"graft_install_"+str(parts.HOOK))
 check(p.graft_part==parts.HOOK and p.carried_parts[parts.HOOK]==1 and p.graft_message.contains("grafted"), "graft success consumes one and shows after commit")
 world.encounter_number=16
 p.carried_parts[18]=1
 for seed in range(100):
  world.rng.seed=seed
  if world.rng.randf()>=world.graft_chance(p,18):
   chosen_seed=seed
   break
 world.rng.seed=chosen_seed
 world.garden_action(1,"graft_install_18")
 check(p.graft_part==parts.HOOK and p.carried_parts[18]==0 and p.graft_message.contains("failed"), "failed graft commits consumption and preserves prior part")
 world.encounter_number=18
 world.deepest_milestone=18
 world.enemy_hp=0
 world.scouts.clear()
 world.checkpoint_pending=true
 p.pos=world.battlefield.advance
 p.weapon=parts.VEIL
 p.offer_floor=18
 p.checkpoint_offers=["rift_hook","power","reach"]
 world.choose_checkpoint_card(1,p,0)
 check(p.rift_hook and world.progress.rift_hook_discovered and p.spent>0 and world.checkpoint_ready.get(1)==18
  and world.encounter_number==18,"card purchase commits Garden discovery without checkpoint advancement")
 var spent: int=p.spent
 world.choose_checkpoint_card(1,p,0)
 check(p.spent==spent,"duplicate card cannot spend twice")
 world.progress.heart.unlocked.append("checkpoint_deposit")
 p.carried_parts[1]=1
 world.garden_action(1,"bank_part_1")
 check(p.last_deposit==18 and p.carried_parts[1]==0 and world.seed_reserve(p).parts[1]==1, "courier persists one stack item")
 world.progress.heart.unlocked.append("perfect_recollection")
 world.consider_recollection()
 check(not world.progress.heart.recollection_seen, "retired finale recollection remains dormant")
 record("graft_cards_courier_recollection",before,{"spent":spent,"floor":world.encounter_number,"graft":p.graft_part,"status":world.status})

 p.wild=false
 p.pos=world.Stage.PLOTS[0]
 mature(0,0)
 before=disk()
 rng_before=world.rng.state
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="replace" and path==G:return ERR_CANT_CREATE
  return ERR_FILE_CANT_WRITE if phase=="restore" else OK)
 check(not world.harvest(1,0), "uncertain actual harvest withholds success")
 world.remove_meta(&"guarded_gameplay_test_fault")
 var split:=disk()
 check(world.progress.plots[0].species<0 and p.character.plants[0]==3 and world.rng.state!=rng_before and audio_count()==0
  and split[C]!=before[C] and split[G]==before[G] and Tx.pending_notice(world).contains("uncertain"),"uncertainty preserves tentative memory and split proof without cue")
 check(not world.harvest(1,0) and split==disk(),"uncertain replay refused")
 record("harvest_uncertain",before,{"tentative_familiarity":p.character.plants[0],"notice":Tx.pending_notice(world)})
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
 cfg.set_value("transaction","entries",{G:{"exists":true,"bytes":FileAccess.get_file_as_bytes(G)}})
 cfg.set_value("transaction","committed",false)
 check(cfg.save(G+".transaction")==OK,"create pending journal")
 before=disk()
 check(not world.harvest(1,0) and disk()==before and world.progress.plots[0].species==0 and Tx.pending_notice(world).contains("recovery is pending"),"pending journal refuses without mutation")
 record("lease_and_recovery_refusals",before,{"notice":Tx.pending_notice(world)})
 check(Ops.recover(PackedStringArray([G])).value.verified,"recover disposable pending fixture")
 close_world()
 await process_frame
