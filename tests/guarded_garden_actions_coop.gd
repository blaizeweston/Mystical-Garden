extends SceneTree

const Tx = preload("res://game_transaction.gd")
const Slots = preload("res://save_slots.gd")
const Roster = preload("res://character_slots.gd")
const Owner = preload("res://guarded_title_session.gd")
const Profile = preload("res://character_profile.gd")
const Crop = preload("res://garden_crop_state.gd")
const Garden := "user://saves/slot_1/garden.cfg"
const HostProfile := "user://saves/characters/slot_1/character.cfg"
const GuestProfile := "user://saves/characters/slot_2/character.cfg"
const Signals := "user://release-fixtures/guarded-garden-"
var game: Node
var host := false
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", message)

func mark(key: String) -> void:
 var file := FileAccess.open(Signals+key,FileAccess.WRITE)
 check(file!=null,"fixture signal "+key)
 if file!=null: file.store_string("ready")

func marked(key: String) -> bool:
 return FileAccess.file_exists(Signals+key)

func until(predicate: Callable) -> bool:
 var deadline := Time.get_ticks_msec()+7500
 while not predicate.call() and Time.get_ticks_msec()<deadline:
  await process_frame
 return predicate.call()

func crop_count() -> int:
 var profile := Profile.new()
 profile.path = GuestProfile
 return int(profile.data.plants[0]) if profile.load_profile(false)==OK else -1

func record(key: String, before: String, facts: Dictionary) -> void:
 print("CASE ",JSON.stringify({"case":key,"run_id":OS.get_environment("MYSTICAL_VALIDATION_RUN"),
  "garden_before":before,"garden_after":Slots._save_digest(Garden),"guest_after":Slots._save_digest(GuestProfile),"facts":facts}))

func open_world() -> bool:
 var roster := Roster.new()
 var slots := Slots.new()
 if host:
  check(Owner.completed(Owner.prepare(slots,roster,false)),"prepare root")
  check(Owner.completed(Owner.outcome(slots.new_world_guarded(0))),"create host Garden")
  check(Owner.completed(Owner.outcome(roster.create_guarded(0,"Keeper",0,[]))),"create host profile")
  check(Owner.completed(Owner.outcome(roster.create_guarded(1,"Visitor",0,[]))),"create guest profile")
 else:
  if not await until(func(): return marked("host")): return false
 var path := HostProfile if host else GuestProfile
 game=load("res://world.tscn").instantiate()
 game.progress.path=Garden
 game.local_character.path=path
 game.guest_character.path=path
 game.slot_claimed=host
 game.joined_from_title=not host
 var result := Owner.new().start(game,slots if host else null,0,Slots._save_digest(Garden) if host else "",roster,0 if host else 1,Slots._save_digest(path))
 check(Owner.completed(result),"real guarded launch: "+str(result))
 if not Owner.completed(result):
  game.free()
  return false
 root.add_child(game)
 # The runner gives both local peers one disposable root. Keep unrelated
 # frame-driven saves and lease heartbeats out of the action barriers.
 game.set_physics_process(false)
 game.set_process(false)
 return true

func run() -> void:
 host=OS.get_cmdline_user_args()[0]=="host"
 if not await open_world():
  check(false,"guarded fixture startup")
  quit(1)
  return
 if host: await host_run()
 else: await guest_run()
 if is_instance_valid(game) and game.online_peer!=null: game.leave_game("Guarded fixture complete")
 # A blocked host leaves through the existing deferred title shutdown.
 var stopped := await until(func():
  return not is_instance_valid(game) or (game.online_peer==null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer))
 check(stopped and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"offline before freeing guarded world")
 if stopped and is_instance_valid(game): game.free()
 if not failed: print("PASS: guarded Garden co-op ", "host" if host else "guest")
 quit(1 if failed else 0)

func prepare_crop(player: Dictionary, key: String) -> void:
 var bed: Dictionary=game.progress.empty_plot().merged({"species":0,"stage":3,"age":10000.0},true)
 Crop.ensure(bed)
 game.progress.plots[0]=bed
 game.progress.sync_plot_flags()
 var request_file := FileAccess.open(Signals+key, FileAccess.WRITE)
 request_file.store_string(JSON.stringify({"point":"bed_1","action":"harvest_crop","request":key,"revision":0,"stage":3,"cycle":bed.care.cycle}))
 request_file.close()
 player.pos=game.Stage.PLOTS[0]

func host_run() -> void:
 check(game.host_game()==OK,"guarded host opens")
 mark("host")
 if not await until(func():return game.players.size()==2 and game.players.values().any(func(p):return p.get("projection_delivery",{}).get("state")=="committed")):
  check(false,"guarded guest joins: "+game.status)
  return
 var id := int(game.players.keys().filter(func(peer): return peer!=1)[0])
 var player: Dictionary=game.players[id]
 var identity: String=player.seed_owner
 prepare_crop(player,"first")
 var original := Slots._save_digest(Garden)
 var guest_before:=Slots._save_digest(GuestProfile)
 var host_before:=Slots._save_digest(HostProfile)
 var rolls := {"count":0}
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,path):
  if phase=="stage" and path==Garden+".txn_stage":
   rolls.count+=1
   return ERR_FILE_CANT_WRITE
  return OK)
 mark("abort-ready")
 if not await until(func():return rolls.count==1 and marked("abort-seen")):
  check(false,"guest sees abort without harvest success")
  return
 check(Slots._save_digest(Garden)==original and Slots._save_digest(GuestProfile)==guest_before and player.character.plants[0]==0
  and game.progress.plots[0].species==0 and game.combat_events.is_empty(),"aborted guest action preserves crop, profiles and audio")
 record("guest_harvest_aborted",original,{"guest_familiarity":player.character.plants[0],"crop":game.progress.plots[0].species,"save_attempts":rolls.count})
 game.remove_meta(&"guarded_gameplay_test_fault")
 mark("commit-ready")
 if not await until(func():return marked("commit-seen")):
  check(false,"guest receives committed harvest and profile")
  return
 check(Slots._save_digest(Garden)!=original and Slots._save_digest(HostProfile)==host_before and game.progress.plots[0].species<0
  and player.character.plants[0]==1 and game.progress.character_records[identity].profile.plants[0]==1
  and crop_count()==1,"guest harvest commits Garden mirror and projects only the guest profile")
 check(game.combat_events.filter(func(event):return event.shape=="crop_harvested").size()==1,"guest harvest publishes audio once")
 record("guest_harvest_committed",original,{"guest_familiarity":player.character.plants[0],"guest_disk":crop_count(),"crop":game.progress.plots[0].species})
 game.send_committed_profile(id) # Deliver the identical existing projection again.
 player.pos=game.Stage.GATE
 mark("craft")
 if not await until(func():return marked("crafted")):
  check(false,"guest observes loadout projection: "+str([game.status,player.character.active_class,player.character.loadouts[1].weapon,player.pos,game.at_weapon_gate(player),Tx.pending_notice(game)]))
  return
 check(player.character.active_class==1 and player.character.loadouts[1].weapon==1 and player.character.plants[0]==1
  and game.progress.character_records[identity].profile.loadouts[1].weapon==1,"guest loadout persisted in Garden projection")
 record("guest_loadout_committed",original,{"class":player.character.active_class,"weapon":player.character.loadouts[1].weapon,"familiarity":player.character.plants[0]})
 prepare_crop(player,"reconnect")
 mark("reconnect-ready")
 if not await until(func():return marked("left-for-reconnect") and not game.players.has(id)):
  check(false,"host observes guest departure before the fixture rejoins")
  return
 mark("host-saw-departure")
 if not await until(func():return marked("guest-returned") and game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):
  check(false,"guest reconnects after local profile projection abort")
  return
 id=int(game.players.keys().filter(func(peer):return peer!=1)[0])
 player=game.players[id]
 check(player.character.plants[0]==2 and crop_count()==2 and game.progress.plots[0].species<0
  and player.character.loadouts[1].weapon==1,"reconnect recovers host-recorded familiarity without replay")
 record("guest_reconnect",original,{"guest_disk":crop_count(),"crop":game.progress.plots[0].species,"weapon":player.character.loadouts[1].weapon})
 prepare_crop(player,"cleanup")
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_CANT_CREATE if phase=="publish_receipt" else OK)
 mark("cleanup-ready")
 if not await until(func():return marked("cleanup-seen")):
  check(false,"guest sees confirmed harvest and persistent cleanup warning")
  return
 var committed:=Slots._save_digest(Garden)
 check(player.character.plants[0]==3 and crop_count()==3 and game.progress.plots[0].species<0
  and Tx.pending_notice(game)==Tx.CLEANUP_NOTICE and FileAccess.file_exists(Garden+".transaction"),
  "cleanup-pending host commit preserves evidence and guest projection")
 game.tell(id,"Later unrelated host message.")
 mark("host-done")
 check(await until(func():return marked("guest-offline") and game.multiplayer.get_peers().is_empty()),"guest detaches after offline replacement")
 check(Slots._save_digest(Garden)==committed and player.character.plants[0]==3,"later actions cannot replay or write")
 record("guest_harvest_cleanup_pending",original,{"guest_disk":crop_count(),"crop":game.progress.plots[0].species,"notice":Tx.pending_notice(game)})

func guest_run() -> void:
 check(game.join_game("127.0.0.1")==OK,"join without Garden lease")
 if not await until(func():return game.session=="Guest" and marked("abort-ready")):
  check(false,"admission/fixture ready: "+game.status)
  return
 var before:=Slots._save_digest(GuestProfile)
 # Use the same cycle and revision for the refused attempt and duplicate.
 var request: String=FileAccess.get_file_as_string(Signals+"first")
 game.send_garden_action("garden:"+request)
 if not await until(func():return game.status.begins_with("Save cancelled")):
  check(false,"no success for refused commit: "+game.status)
  return
 check(crop_count()==0 and Slots._save_digest(GuestProfile)==before,"abort did not project a guest profile")
 mark("abort-seen")
 if not await until(func():return marked("commit-ready")): return
 game.send_garden_action("garden:"+request)
 if not await until(func():return crop_count()==1 and game.status.begins_with("Harvested")):
  check(false,"committed harvest notice and projection arrive: "+game.status)
  return
 game.send_garden_action("garden:"+request)
 var harvested := Slots._save_digest(GuestProfile)
 var stage_attempts := {"count":0}
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):
  if phase=="stage": stage_attempts.count+=1
  return OK)
 mark("commit-seen")
 check(await until(func():return marked("craft")),"craft sync")
 # Allow the deliberately repeated reliable profile message to arrive.
 await create_timer(.25).timeout
 check(stage_attempts.count==0 and Slots._save_digest(GuestProfile)==harvested and crop_count()==1,"duplicate profile packet does not stage or award a second harvest")
 game.remove_meta(&"guarded_gameplay_test_fault")
 game.send_garden_action("class_1")
 if not await until(func():return game.guest_character.data.active_class==1):
  check(false,"class projection arrives: "+game.status)
  return
 game.send_garden_action("loadweapon_1")
 if not await until(func():return game.guest_character.data.active_class==1 and game.guest_character.data.loadouts[1].weapon==1):
  check(false,"ordered loadout projections arrive")
  return
 check(game.guest_character.data.plants[0]==1,"loadout projections preserve familiarity")
 mark("crafted")
 if not await until(func():return marked("reconnect-ready")):
  check(false,"host prepares second crop")
  return
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path): return ERR_FILE_CANT_WRITE if phase=="stage" else OK)
 game.send_garden_action("garden:"+FileAccess.get_file_as_string(Signals+"reconnect"))
 if not await until(func():return game.get_meta(&"guest_projection_notice","").contains("not saved")):
  check(false,"guest save failure is visible")
  return
 check(crop_count()==1 and not game.status.begins_with("Harvested"),"failed guest projection leaves its prior bytes and withholds success")
 game.remove_meta(&"guarded_gameplay_test_fault")
 game.leave_game("Reconnect to guarded Garden")
 check(game.online_peer==null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"offline before reconnect")
 mark("left-for-reconnect")
 if not await until(func():return marked("host-saw-departure")):
  check(false,"host processed the disconnect before reconnect")
  return
 check(game.join_game("127.0.0.1")==OK,"guest reconnect requested")
 if not await until(func():return is_instance_valid(game) and game.session=="Guest" and crop_count()==2):
  check(false,"familiarity restored from the host record: "+(game.status if is_instance_valid(game) else "returned to title"))
  return
 mark("guest-returned")
 if not await until(func():return marked("cleanup-ready")):
  check(false,"host prepares cleanup-pending harvest")
  return
 var cleanup_request := FileAccess.get_file_as_string(Signals+"cleanup")
 game.send_garden_action("garden:"+cleanup_request)
 if not await until(func():return crop_count()==3 and game.status.contains("Harvested") and game.status.contains(Tx.CLEANUP_NOTICE)):
  check(false,"guest receives truthful harvest success alongside host warning: "+game.status)
  return
 game.send_garden_action("garden:"+cleanup_request)
 mark("cleanup-seen")
 check(await until(func():return marked("host-done") and game.status.begins_with("Later unrelated")),"later normal host feedback arrives")
 game.toast_until=0
 game.refresh_feedback()
 check(game.feedback.text.contains(Tx.CLEANUP_NOTICE) and crop_count()==3,"later message and toast expiry preserve host warning without replay")
 record("guest_visible_host_cleanup",before,{"feedback":game.feedback.text,"guest_disk":crop_count()})
 game.leave_game("Guarded guest complete")
 check(game.online_peer==null and game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"guest leaves before world removal")
 mark("guest-offline")
