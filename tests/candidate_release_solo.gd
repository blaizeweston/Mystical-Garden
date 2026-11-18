extends SceneTree
const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Cards = preload("res://affinity_cards.gd")
const Gate = preload("res://persistence_writer_integration.gd")
const Tx = preload("res://game_transaction.gd")
const Slots = preload("res://save_slots.gd")
const G = "user://saves/slot_1/garden.cfg"
const P = "user://saves/characters/slot_1/character.cfg"
var failed := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, what: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", what)

func record(label: String, detail := {}) -> void:
 print("CASE ",JSON.stringify({"case":label,"garden":Slots._save_digest(G),"profile":Slots._save_digest(P),"detail":detail}))

func until(condition: Callable) -> bool:
 var deadline := Time.get_ticks_msec()+10000
 while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
 return condition.call()

func run() -> void:
 check(not Gate.PRODUCTION_CUTOVER_APPROVED and Gate.VERIFIED_WRITERS.is_empty() and not Gate.default_route(self),"normal release route stays off")
 set_meta(Gate.VALIDATION_ROUTE,true)
 # Negative startup only. All positive startup uses the main scene below.
 var unowned: Node = load("res://world.tscn").instantiate()
 root.add_child(unowned)
 var unowned_id := unowned.get_instance_id()
 check(await until(func(): return not is_instance_id_valid(unowned_id)), "world without valid guarded ownership is detached")
 var refused: Node = current_scene
 check(refused!=null and refused.production_route and refused.return_message.contains("claim the save"),"unowned world returns to candidate title")
 check(not FileAccess.file_exists(G) and not FileAccess.file_exists(P),"unowned startup wrote no canonical file")
 record("unowned_startup_refused")
 refused.queue_free()
 await process_frame
 var stale: Node = load("res://world.tscn").instantiate()
 var invalid: Dictionary = stale.persistence_session.start(stale.progress, stale.local_character, stale.guest_character,
  null, -1, "", null, -1, "")
 check(not preload("res://guarded_title_session.gd").completed(invalid)
  and not stale.persistence_session.is_guarded(),"failed confirmation grants no session authority")
 root.add_child(stale)
 var stale_id := stale.get_instance_id()
 check(await until(func(): return not is_instance_id_valid(stale_id)), "failed session confirmation refuses world startup")
 check(not FileAccess.file_exists(G) and not FileAccess.file_exists(P),"failed session confirmation wrote no canonical file")
 record("failed_session_confirmation_refused")
 current_scene.queue_free()
 await process_frame
 check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"load configured main scene")
 await scene_changed
 var title: Node = current_scene
 check(title.production_route and title.guarded_persistence,"candidate real main scene")
 title.new_button.pressed.emit()
 check(title.creator.visible,"New Garden opens real creator")
 title.creator.name_field.text = "Release Keeper"
 title.creator.confirmed.emit()
 check(await until(func(): return is_instance_valid(current_scene) and SessionCase.has_guarded_session(current_scene)),"creator completes New Garden title handoff")
 if not is_instance_valid(current_scene) or not SessionCase.has_guarded_session(current_scene):
  quit(1)
  return
 var world: Node = current_scene
 check(world.persistence_session.owns_leases() and world.local_character.data.name=="Release Keeper","Garden and roster leases own correct canonical paths")
 check(world.progress.save_garden()==ERR_UNAUTHORIZED and world.local_character.save_profile()==ERR_UNAUTHORIZED,"legacy standalone serializers cannot save active candidate session")
 world.set_process(false)
 world.set_physics_process(false)
 var actor: Dictionary = world.players[1]
 actor.pos=world.Stage.HEART
 world.handle_loadout_action(1,actor,"learn_0_64")
 world.toggle_overlay(null)
 actor.pos = world.Stage.PLOTS[0]
 world.progress.plots[0] = world.progress.empty_plot().merged({"species":0,"stage":3,"age":10000.0},true)
 world.progress.sync_plot_flags()
 var garden_before := Slots._save_digest(G)
 var profile_before := Slots._save_digest(P)
 var prior_rng: int = world.rng.state
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,path): return ERR_FILE_CANT_WRITE if phase=="stage" and path==P+".txn_stage" else OK)
 check(not world.harvest(1,0) and Slots._save_digest(G)==garden_before and Slots._save_digest(P)==profile_before and world.rng.state==prior_rng,"failed harvest rolls back without a legacy fallback")
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(world.harvest(1,0) and world.progress.plots[0].species<0 and actor.character.plants[0]==1 and Slots._save_digest(G)!=garden_before and Slots._save_digest(P)!=profile_before,"harvest commits Garden and profile through admitted world")
 record("harvest_pair_commit",{"garden_before":garden_before,"profile_before":profile_before})
 world.seed_reserve(actor).parts[1] = 2
 world.drop_inventory_stack(1,actor,"stash",world.Items.part_id(1),1)
 check(world.progress.ground_items.size()==1,"drop through admitted world")
 if not world.progress.ground_items.is_empty():
  world.pickup_inventory_drop(1,actor,world.progress.ground_items[0].id)
 check(world.progress.ground_items.is_empty(),"pickup through admitted world")
 actor.pos=world.Stage.GATE
 actor.prepared=1
 world.progress.add_parts(1,3)
 world.open_gate_preparation()
 world.garden_action(1,"depart")
 check(ExpeditionCase.is_wild(actor) and actor.weapon==1,"guarded departure from real title world")
 world.encounter.set_hp(-1, 0)
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 world.encounter.clear_scouts()
 world.finish_combat(1,world.tactics.position)
 check(world.encounter_rewarded and actor.loot_pending and world.progress.wilds_memory.encounters==1,"guarded combat settlement")
 clear_floor(world,actor,3)
 ExpeditionCase.Transitions.checkpoint(world, 1,true)
 var offer: Dictionary=world.checkpoint_card_data(actor)[0]
 world.send_garden_action(world.affinity_checkpoint_action(offer.revision,"0"))
 ExpeditionCase.Transitions.checkpoint(world, 1,true)
 check(world.participation.floor()==4 and Cards.ledger(actor).count()==1,"free checkpoint card and guarded advancement")
 clear_floor(world,actor,6)
 actor.carried_seeds=[0]
 ExpeditionCase.Transitions.checkpoint(world, 1,false)
 check(not ExpeditionCase.is_wild(actor) and world.progress.campaign.best_extraction==6 and world.progress.unknown.size()>0,"guarded extraction banks loot")
 record("expedition_and_inventory_commit",{"floor":world.participation.floor(),"best_extraction":world.progress.campaign.best_extraction})
 world.return_to_main_menu()
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer and not has_lease(G) and not has_lease(P),"return goes offline and releases leases")
 await process_frame
 title=current_scene
 title.continue_button.pressed.emit()
 check(is_instance_valid(current_scene) and SessionCase.has_guarded_session(current_scene),"real Continue loads saved world")
 if not is_instance_valid(current_scene) or not SessionCase.has_guarded_session(current_scene):
  quit(1)
  return
 world=current_scene
 check(world.progress.campaign.best_extraction==6 and world.local_character.data.plants[0]==1,"Continue reloads committed Garden and profile")
 var before_close := Slots._save_digest(G)
 world.progress.knowledge+=3
 world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(Slots._save_digest(G)!=before_close and not has_lease(G) and not has_lease(P),"close notification commits and releases")
 record("close_notification",{"prior":before_close,"offline":root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer})
 if not failed: print("PASS: candidate title, solo gameplay, return and shutdown")
 quit(1 if failed else 0)

func has_lease(path: String) -> bool:
 return FileAccess.file_exists(path.get_base_dir().path_join("session.cfg"))

func clear_floor(world: Node, actor: Dictionary, floor: int) -> void:
 ExpeditionCase.set_world(world, {"encounter_number": floor})
 world.deepest_milestone=floor
 world.encounter.set_hp(-1, 0)
 world.encounter.clear_scouts()
 world.encounter_rewarded=true
 actor.pos=world.battlefield.advance
