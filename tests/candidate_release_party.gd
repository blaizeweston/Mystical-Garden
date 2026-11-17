extends SceneTree

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Gate = preload("res://persistence_writer_integration.gd")
const Tx = preload("res://game_transaction.gd")
const Network = preload("res://network_settings.gd")
const G = "user://saves/slot_1/garden.cfg"
const P = "user://saves/characters/slot_1/character.cfg"
var sync_path: String
var failed := false
var settlement_fault := OS.get_environment("MYSTICAL_F5_DISCONNECT")

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ",message)

func mark(key: String, value := "yes") -> void:
 var file := FileAccess.open(sync_path+key,FileAccess.WRITE)
 check(file!=null,"fixture signal "+key)
 if file!=null: file.store_string(value)

func read(key: String) -> String:
 return FileAccess.get_file_as_string(sync_path+key)

func until(predicate: Callable) -> bool:
 var deadline := Time.get_ticks_msec()+17000
 while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
 return predicate.call()

func title() -> Node:
 check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"load configured main scene")
 await scene_changed
 var menu: Node = current_scene
 check(menu.production_route and menu.guarded_persistence,"candidate default title")
 return menu

func run() -> void:
 var role := OS.get_cmdline_user_args()[0]
 check(not Gate.default_route(self) and not Gate.PRODUCTION_CUTOVER_APPROVED and Network.PROTOCOL==41,"normal startup stays inactive and protocol 41 is current")
 sync_path = ProjectSettings.globalize_path("user://release-fixtures/four-title-")
 set_meta(Gate.VALIDATION_ROUTE,true)
 if role!="host":
  var data := OS.get_environment("APPDATA").path_join("p2a-"+role)
  check(DirAccess.make_dir_recursive_absolute(data.path_join(OS.get_user_data_dir().get_file()))==OK,"isolated role root")
  OS.set_environment("APPDATA",data)
  check(OS.get_user_data_dir().simplify_path()==data.path_join(OS.get_user_data_dir().get_file()).replace("\\","/").simplify_path(),"guest has a separate physical data root")
 if role=="host": await host()
 else: await guest(role)
 if not failed: print("PASS: candidate default title four player ",role)
 quit(1 if failed else 0)

func host() -> void:
 var menu: Node = await title()
 create_character(menu,"Release Host")
 menu.host_choice.button_pressed = true
 menu.new_button.pressed.emit()
 var game := current_scene
 if game==menu or game.session!="Host":
  check(false,"host New Garden handoff")
  return
 mark("port",str(game.network_port))
 if not await until(func(): return game.players.size()==4 and committed_guests(game)==3):
  check(false,"all three guarded profiles acknowledged")
  return
 mark("full")
 check(await until(func():return read("overflow-done")=="yes"),"fifth player attempt completed")
 check(game.players.size()==4,"capacity refused without replacing the existing party")
 var class_id: int = player_id(game,"1")
 game.players[class_id].pos = game.Stage.HEART
 mark("class-abort-ready")
 if not await until(func(): return game.players.get(class_id,{}).get("projection_delivery",{}).get("state")=="aborted" and read("class-abort-done")=="yes"):
  check(false,"guest class save abort acknowledged")
  return
 var class_record: Dictionary = game.progress.character_records[game.players[class_id].seed_owner]
 check(class_record.profile.active_class==1,"host commits class before guest abort")
 print("CASE ",JSON.stringify({"case":"class_host_commit_guest_abort","revision":class_record.projection.revision,"garden":FileAccess.get_sha256(G)}))
 mark("reconnect-ready")
 var revisions: Array = []
 for player in game.players.values():
  if not player.has("projection_delivery"): continue
  revisions.append(player.projection_delivery.revision)
 revisions.sort()
 check(revisions==[1,1,2] and game.progress.character_records.size()>=3,"host retains the class revision through failed guest save")
 var receipts: int = game.progress.character_records.size()
 if not await until(func(): return read("reconnected")=="yes" and game.players.size()==4 and committed_guests(game)==3):
  check(false,"guest reconnect through title and acknowledges its committed profile")
  return
 check(game.progress.character_records.size()==receipts,"reconnect uses the existing identity")
 var harvest_id: int = game.players.keys().filter(func(id): return id!=1 and game.players[id].character.name=="Release Guest 2")[0]
 var harvester: Dictionary = game.players[harvest_id]
 var garden_before := FileAccess.get_sha256(G)
 var bed: Dictionary = game.progress.empty_plot().merged({"species":0,"stage":3,"age":10000.0},true)
 preload("res://garden_crop_state.gd").ensure(bed)
 game.progress.plots[0] = bed
 game.progress.sync_plot_flags()
 harvester.pos = game.Stage.PLOTS[0]
 mark("harvest-request",JSON.stringify({"point":"bed_1","action":"harvest_crop","request":"release-harvest","revision":0,"stage":3,"cycle":bed.care.cycle}))
 if not await until(func(): return read("harvest-done")=="yes" and harvester.character.plants[0]==1 and harvester.projection_delivery.get("state")=="committed"):
  check(false,"real guest harvest and committed acknowledgment")
  return
 check(game.progress.plots[0].species<0 and FileAccess.get_sha256(G)!=garden_before,"host harvest commits Garden in full party")
 print("CASE ",JSON.stringify({"case":"full_party_harvest","before":garden_before,"after":FileAccess.get_sha256(G),"delivery":harvester.projection_delivery}))
 var loadout_id: int = player_id(game,"2")
 game.players[loadout_id].pos = game.Stage.GATE
 mark("loadout-ready")
 if not await until(func(): return read("loadout-done")=="yes" and game.players[loadout_id].character.loadouts[0].weapon==1 and game.players[loadout_id].projection_delivery.get("state")=="committed"):
  check(false,"loadout projection acknowledgment")
  return
 game.send_committed_profile(loadout_id)
 mark("duplicate-loadout")
 if not await until(func(): return read("duplicate-done")=="yes"):
  check(false,"guest deduplicates loadout projection")
  return

 # Hold only host simulation so the fixture can inspect departure and a frozen
 # reward deterministically. ENet polling and the guest worlds remain live.
 game.set_physics_process(false)
 for actor in game.players.values(): actor.pos = game.Stage.GATE
 game.garden_action(1,"depart")
 mark("party-depart")
 if not await until(func(): return game.players.values().all(func(actor): return actor.wild)):
  check(false,"all four ready and departed")
  return
 var battle_before := FileAccess.get_sha256(G)
 var kind: int = game.enemy_kind
 var host_count: int = game.players[1].character.monsters[kind]
 game.encounter.set_hp(-1, 0)
 game.record_enemy_death(-1,game.tactics.position,Vector3.ZERO)
 var frozen: int = game.rng.state
 game.record_enemy_death(-1,game.tactics.position,Vector3.ZERO)
 check(game.monster_rewards.pending_count()==1 and game.rng.state==frozen,"duplicate kill cannot reroll")
 game.encounter.clear_scouts()
 game.finish_combat(1,game.tactics.position)
 if not await until(func(): return read("combat-1")=="yes" and read("combat-2")=="yes" and read("combat-3")=="yes" and committed_guests(game)==3):
  check(false,"all three guest reward profiles commit and acknowledge")
  return
 check(game.encounter_rewarded and game.monster_rewards.pending_count()==0 and game.players[1].character.monsters[kind]==host_count+1
  and FileAccess.get_sha256(G)!=battle_before,"host reward and adaptation commit")
 print("CASE ",JSON.stringify({"case":"four_player_combat","before":battle_before,"after":FileAccess.get_sha256(G),"kind":kind}))
 var remote: int = player_id(game,"2")
 var target: Dictionary = game.players[remote]
 var helper: Dictionary = game.players[1]
 game.battlefield.procedural=false
 game.battlefield.barriers.clear()
 helper.pos=Vector3.ZERO
 target.pos=Vector3(.5,0,0)
 IncomingPlayerHit.apply_health_loss(game, remote, PlayerLifecycle.generation(target), 999)
 check(PlayerLifecycle.fallen(target),"real remote ally downed")
 var revive_before := FileAccess.get_sha256(G)
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path): return ERR_FILE_CANT_WRITE if phase=="stage" else OK)
 game.garden_action(1,"revive:"+str(remote))
 game.remove_meta(&"guarded_gameplay_test_fault")
 check(PlayerLifecycle.fallen(target) and target.lost_health==0 and FileAccess.get_sha256(G)==revive_before,
  "revive abort preserves real remote ally's downed state")
 game.garden_action(1,"revive:"+str(remote))
 var cost: int = target.lost_health
 check(not PlayerLifecycle.fallen(target) and cost>0,"real remote ally revives at one cost")
 game.garden_action(1,"revive:"+str(remote))
 check(target.lost_health==cost,"repeat remote revive cannot charge twice")
 print("CASE ",JSON.stringify({"case":"remote_revive","garden":FileAccess.get_sha256(G),"cost":cost}))
 var leaving: int = player_id(game,"1")
 var identity: String = game.players[leaving].seed_owner
 var kills: int = game.players[leaving].character.monsters[kind]
 game._queue_monster_reward("pending-on-disconnect",kind,0,game.tactics.position,false)
 var disconnect_key: String = game.monster_rewards.pending_receipts()[0].key
 game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):
  if settlement_fault=="uncertain" and phase in ["publish_commit_marker","restore"]: return ERR_CANT_CREATE
  if settlement_fault=="cleanup" and phase=="publish_receipt": return ERR_CANT_CREATE
  if settlement_fault.is_empty() and phase=="stage": return ERR_FILE_CANT_WRITE
  return OK)
 var disconnect_before := FileAccess.get_sha256(G)
 mark("disconnect-pending")
 if not await until(func():return read("disconnect-ready")=="yes"):
  check(false,"guest ready for transport disconnect")
  return
 # Keep the cleanup-pending world alive long enough to deliver the
 # explicit window-close notification. The ENet tree still polls.
 if settlement_fault=="cleanup": game.set_process(false)
 var transport: ENetMultiplayerPeer=game.online_peer
 var packet := transport.get_peer(leaving)
 var callback := {}
 var snapshot_before: int=game.net_view.snapshot_sent
 var ordinary_before: String=game.status
 transport.peer_disconnected.connect(func(id: int):
  if id!=leaving: return
  callback.merge({"sequence":game.net_view.snapshot_sent,"channels":packet.get_channels() if packet.is_active() else 0,
   "state":packet.get_state(),"targets":Array(game.net_view.snapshot_targets(game))}))
 transport.disconnect_peer(leaving)
 var advertised: bool=game.multiplayer.get_peers().has(leaving)
 var eligible: PackedInt32Array=game.net_view.snapshot_targets(game)
 check(advertised and game.players[leaving].profile_ready and not eligible.has(leaving) and eligible.size()==2,
  "send boundary rejects disconnecting ENet peer while admitted roster still contains it")
 if not await until(func(): return not game.players.has(leaving) and read("offline-1")=="yes"):
  check(false,"actual peer disconnect with pending host rewards")
  return
 check(callback.get("sequence",-1)==snapshot_before and not callback.get("targets",[]).has(leaving)
  and (int(callback.get("channels",-1))==0 or callback.get("state")==ENetPacketPeer.STATE_DISCONNECTED),
  "actual callback observes inactive or zero-channel peer before any snapshot send")
 var expected_sends := 1 if settlement_fault=="cleanup" else 0
 check(await until(func():return game.net_view.snapshot_sent>=snapshot_before+expected_sends),
  "deferred committed snapshot is sent after the callback")
 check(game.net_view.snapshot_sent==snapshot_before+expected_sends
  and game.status.contains("class XP")==(settlement_fault=="cleanup"),"only verified cleanup-pending settlement sends the final snapshot and reward feedback")
 print("CASE ",JSON.stringify({"case":"disconnect_snapshot_boundary","mode":settlement_fault,"advertised":advertised,
  "callback":callback,"before":snapshot_before,"after":game.net_view.snapshot_sent,"status_before":ordinary_before,
  "status_after":game.status,"garden_before":disconnect_before,"garden_after":FileAccess.get_sha256(G)}))
 if not settlement_fault.is_empty():
  await finish_blocked_disconnect(game,identity,kills,kind,disconnect_before,disconnect_key)
  return
 check(game.departure_settlement.contains_peer(leaving) and game.monster_rewards.pending_count()==1
  and game.monster_rewards.status(disconnect_key)==game.MonsterRewards.Phase.PENDING
  and game.departure_settlement.status(identity)==game.DepartureSettlement.Phase.RETRYABLE
  and FileAccess.get_sha256(G)==disconnect_before and game.status.begins_with("Save cancelled"),
  "verified disconnect abort retains the reward, retryable departure and Garden bytes")
 check(game.admission_error(identity,game.progress.ContentIDs.manifest(),Network.PROTOCOL).contains("still being saved"),
  "admission reports the unsettled departure for this character")
 game.remove_meta(&"guarded_gameplay_test_fault")
 check(game.flush_kill_rewards() and game.departure_settlement.is_empty() and game.monster_rewards.pending_count()==0
  and game.departure_settlement.status(identity)==game.DepartureSettlement.Phase.ABSENT
  and game.monster_rewards.status(disconnect_key)==game.MonsterRewards.Phase.COMMITTED
  and not game.departure_settlement.blocks_admission(identity)
  and int(game.progress.character_records[identity].profile.monsters[kind])==kills+1,
  "committed flush credits disconnected identity once and releases its admission hold")
 var flushed := FileAccess.get_sha256(G)
 check(game.flush_kill_rewards() and FileAccess.get_sha256(G)==flushed,"empty retry does not duplicate detached reward")
 print("CASE ",JSON.stringify({"case":"pending_disconnect_reward","before":disconnect_before,"after":flushed,"identity":identity}))
 mark("expire-lease")
 var peer_id: int = player_id(game,"3")
 check(await until(func(): return read("lease-ready")=="yes" and game.players.has(peer_id)),"guest expired its local lease")
 var actor: Dictionary = game.players[peer_id]
 var projection = load("res://guest_profile_projection.gd")
 var incoming: Dictionary = actor.character.duplicate(true)
 incoming.name = "Delayed acceptance probe"
 var descriptor: Dictionary = projection.build(incoming, actor.projection_delivery.revision+1, actor.get("projection_base",{}))
 game.receive_character.rpc_id(peer_id,{"profile":incoming,"origin":game.progress.projection_origin,"projection":descriptor})
 mark("projection-sent")
 check(await until(func(): return read("lease-refused")=="yes"),"late real projection refused after lease loss")

 print("CASE ",JSON.stringify({"case":"four_guarded_admissions","revisions":revisions,"garden":FileAccess.get_sha256(G)}))
 game.return_to_main_menu()
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"host offline before detach")
 check(await until(func():return read("offline-1")=="yes" and read("offline-2")=="yes" and read("offline-3")=="yes"),"all guests return through title")

func finish_blocked_disconnect(game: Node, identity: String, kills: int, kind: int, before: String, key: String) -> void:
 var after := FileAccess.get_sha256(G)
 var evidence := FileAccess.get_sha256(G+".transaction")
 var warning := Tx.pending_notice(game)
 var cleanup := settlement_fault=="cleanup"
 check(not evidence.is_empty() and after!=before and not Tx.session_writable(game),"disconnect preserves write-blocking evidence")
 check((warning==Tx.CLEANUP_NOTICE) if cleanup else warning.contains("uncertain"),"disconnect outcome warning")
 var phase: int = game.DepartureSettlement.Phase.CLEANUP_PENDING if cleanup else game.DepartureSettlement.Phase.UNCERTAIN
 check(game.departure_settlement.status(identity)==phase and game.departure_settlement.blocks_admission(identity),
  "blocked disconnect keeps the exact settlement outcome and admission hold")
 check(int(game.progress.character_records[identity].profile.monsters[kind])==kills+1,"settlement memory retains computed reward")
 var reward_phase: int = game.MonsterRewards.Phase.CLEANUP_PENDING if cleanup else game.MonsterRewards.Phase.UNCERTAIN
 check(game.monster_rewards.status(key)==reward_phase and game.monster_rewards.pending_count()==0,
  "blocked settlement owner keeps its outcome out of the retryable queue")
 game.remove_meta(&"guarded_gameplay_test_fault")
 check(not game.flush_kill_rewards() and game.monster_rewards.status(key)==reward_phase
  and int(game.progress.character_records[identity].profile.monsters[kind])==kills+1
  and FileAccess.get_sha256(G)==after and FileAccess.get_sha256(G+".transaction")==evidence,
  "a blocked reward flush cannot replay an award or mutate recovery evidence")
 var old_id := game.get_instance_id()
 var snapshot_sequence: int=game.net_view.snapshot_sent
 var old_transport: ENetMultiplayerPeer=game.online_peer
 if cleanup:
  mark("final-snapshot",str(snapshot_sequence))
  check(await until(func():return read("snapshot-2")=="yes" and read("snapshot-3")=="yes"),
   "both surviving peers observe the final snapshot and the cleanup warning")
 mark("blocked-reconnect")
 if not await until(func(): return read("blocked-refused")=="yes"):
  check(false,"reconnect must be refused while host is blocked")
  return
 check(FileAccess.get_sha256(G)==after and FileAccess.get_sha256(G+".transaction")==evidence
  and game.departure_settlement.status(identity)==phase
  and int(game.progress.character_records[identity].profile.monsters[kind])==kills+1,
  "blocked reconnect preserves the original settlement, reward and disk evidence")
 if cleanup:
  check(game.net_view.snapshot_sent==snapshot_sequence,"blocked reconnect does not repeat the final snapshot")
  game.release_slot()
  check(not game.get_meta(Tx.SESSION).owns_leases(),"host relinquishes leases while still connected")
  game.net_view.publish_committed_cleanup(game,old_transport)
  check(game.net_view.snapshot_sent==snapshot_sequence and FileAccess.get_sha256(G)==after
   and FileAccess.get_sha256(G+".transaction")==evidence,"deferred cleanup cannot send or write after ownership is lost")
  game.go_offline()
  game.net_view.publish_committed_cleanup(game,old_transport)
  game.send_expedition_state(0.0,true)
  check(game.net_view.snapshot_sent==snapshot_sequence and game.net_view.snapshot_targets(game).is_empty(),
   "old deferred request and actual send boundary both refuse offline transport")
  game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
  check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer and not FileAccess.file_exists(G.get_base_dir().path_join("session.cfg")),"window close of blocked host releases owned lease after offline")
  check(FileAccess.get_sha256(G)==after and FileAccess.get_sha256(G+".transaction")==evidence,"window close preserves committed evidence")
  print("CASE ",JSON.stringify({"case":"host_disconnect_cleanup_window_close","before":before,"after":after,"journal":evidence,"warning":warning}))
  return
 game.return_to_main_menu()
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"blocked return goes offline before detachment")
 if not await until(func():return not is_instance_id_valid(old_id)):
  check(false,"blocked host detaches")
  return
 var menu: Node = current_scene
 check(menu.recovery_notice.visible and menu.continue_button.disabled,"title keeps uncertain host warning and blocks Continue")
 menu.garden_recovery_button.pressed.emit()
 menu.recovery_confirmation.confirmed.emit()
 check(FileAccess.get_sha256(G)==before and not FileAccess.file_exists(G+".transaction") and not menu.recovery_notice.visible,
  "B2 restores uncertain disconnect before reopening")
 print("CASE ",JSON.stringify({"case":"host_disconnect_uncertain","before":before,"split":after,"restored":FileAccess.get_sha256(G),"journal":evidence}))
 menu.host_choice.button_pressed=true
 menu.continue_button.pressed.emit()
 var reopened: Node = current_scene
 if reopened==menu or reopened.session!="Host":
  check(false,"verified recovery permits host restart")
  return
 var reopened_sequence: int=reopened.net_view.snapshot_sent
 reopened.net_view.publish_committed_cleanup(reopened,old_transport)
 check(reopened.net_view.snapshot_sent==reopened_sequence,"a prior session snapshot cannot be replayed on reopened transport")
 mark("host-reopened",str(reopened.network_port))
 check(await until(func():return read("rejoin-after-recovery")=="yes"),"guest rejoins after recovery")
 var record: Dictionary = reopened.progress.character_records[identity].profile
 check(int(record.monsters[kind])==kills and reopened.departure_settlement.is_empty(),
  "uncertain disconnected reward never replays or restores a stale hold after recovery")
 reopened.return_to_main_menu()
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"reopened host offline before detach")

func guest(role: String) -> void:
 check(await until(func():return read("port").is_valid_int()),"host listening")
 var menu: Node = await title()
 create_character(menu,"Release Guest "+role)
 var before := FileAccess.get_sha256(P)
 if role=="overflow": check(await until(func():return read("full")=="yes"),"party full")
 if role=="1":
  var legacy: Node = connect_to_host(menu)
  if legacy == null: return
  legacy.multiplayer.connected_to_server.disconnect(legacy.on_joined_world)
  legacy.multiplayer.connected_to_server.connect(func():
   var catalog: Dictionary = legacy.progress.ContentIDs.manifest()
   catalog["guest_projection_receipts"] = legacy.guest_character.projection_receipts
   legacy.register_character.rpc_id(1,legacy.guest_character.identity,legacy.guest_character.data,catalog,40),
   CONNECT_ONE_SHOT)
  var refused_id := legacy.get_instance_id()
  if not await until(func():return current_scene.get_instance_id()!=refused_id):
   check(false,"protocol 40 returned to title")
   return
  menu=current_scene
  check(menu.return_message.contains("versions") and FileAccess.get_sha256(P)==before,"protocol 40 refused without changing profile")
  print("CASE ",JSON.stringify({"case":"protocol_40_refused","profile":before,"notice":menu.return_message}))
  await process_frame
 var game: Node = connect_to_host(menu)
 if game==null: return
 if game==menu:
  check(false,"title Join starts")
  return
 if role=="overflow":
  game.connection_deadline = Time.get_ticks_msec()+4500
  var attempt := game.get_instance_id()
  check(await until(func():return current_scene.get_instance_id()!=attempt),"overflow returned to title")
  check(FileAccess.get_sha256(P)==before and not FileAccess.file_exists(G),"overflow kept profile and no Garden")
  check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"overflow offline")
  mark("overflow-done")
  return
 var game_id := game.get_instance_id()
 if not await until(func(): return admitted(game_id)):
  check(false,"guest joins")
  return
 check(FileAccess.get_sha256(P)!=before and game.guest_character.projection_receipts.size()==1 and not FileAccess.file_exists(G),"guest committed only its own receipt")
 print("CASE ",JSON.stringify({"case":"guest_receipt","role":role,"before":before,"after":FileAccess.get_sha256(P),"receipts":game.guest_character.projection_receipts}))
 if role=="1":
  if not await until(func():return read("class-abort-ready")=="yes"):
   check(false,"host prepared class change")
   return
  var class_before := FileAccess.get_sha256(P)
  game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path): return ERR_FILE_CANT_WRITE if phase=="stage" else OK)
  game.send_garden_action("class_1")
  check(await until(func(): return game.has_meta(&"guest_projection_notice")),"guest observes class profile abort")
  check(FileAccess.get_sha256(P)==class_before and game.guest_character.data.active_class==0
   and not game.status.contains("selected."),"class abort preserves canonical profile and withholds success")
  game.remove_meta(&"guarded_gameplay_test_fault")
  mark("class-abort-done")
  check(await until(func():return read("reconnect-ready")=="yes"),"host observes aborted class projection")
  game.leave_game("Reconnect acceptance")
  check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer and not FileAccess.file_exists(P.get_base_dir().path_join("session.cfg")),"guest releases lease before reconnect")
  await process_frame
  menu=current_scene
  game=connect_to_host(menu)
  if game==null: return
  game_id=game.get_instance_id()
  if not await until(func(): return admitted(game_id)):
   check(false,"real title reconnect")
   return
  check(game.guest_character.data.active_class==1 and FileAccess.get_sha256(P)!=class_before,"reconnect applies host class once")
  mark("reconnected")
 if role=="2":
  if not await until(func(): return not read("harvest-request").is_empty()):
   check(false,"host prepares party harvest")
   return
  var before_harvest := FileAccess.get_sha256(P)
  game.send_garden_action("garden:"+read("harvest-request"))
  if not await until(func(): return game.guest_character.data.plants[0]==1 and game.status.begins_with("Harvested")):
   check(false,"guest harvest profile and confirmation: "+game.status)
   return
  check(FileAccess.get_sha256(P)!=before_harvest,"guest harvest writes owned local profile")
  mark("harvest-done")
  check(await until(func(): return read("loadout-ready")=="yes"),"loadout is eligible at the gate")
  var loadout_before := FileAccess.get_sha256(P)
  game.send_garden_action("loadweapon_1")
  check(await until(func(): return game.guest_character.data.loadouts[0].weapon==1),"guest loadout committed")
  var loadout_after := FileAccess.get_sha256(P)
  check(loadout_after!=loadout_before,"loadout changes own profile bytes")
  mark("loadout-done")
  check(await until(func(): return read("duplicate-loadout")=="yes"),"duplicate loadout sent")
  await create_timer(.3).timeout
  check(FileAccess.get_sha256(P)==loadout_after,"duplicate loadout preserves bytes")
  print("CASE ",JSON.stringify({"case":"loadout_commit_duplicate","before":loadout_before,"after":loadout_after}))
  mark("duplicate-done")
 if not await until(func(): return read("party-depart")=="yes"):
  check(false,"host prepares party departure")
  return
 var reward_before := FileAccess.get_sha256(P)
 var old_monsters: Array = game.guest_character.data.monsters.duplicate()
 game.send_garden_action("depart")
 if not await until(func(): return game.guest_character.data.monsters!=old_monsters):
  check(false,"guest combat projection committed")
  return
 check(FileAccess.get_sha256(P)!=reward_before and not FileAccess.file_exists(G),"combat updates only guest-owned profile")
 print("CASE ",JSON.stringify({"case":"combat_guest_profile","role":role,"before":reward_before,"after":FileAccess.get_sha256(P)}))
 mark("combat-"+role)
 if role=="1":
  check(await until(func(): return read("disconnect-pending")=="yes"),"host queued another reward")
  var ending_world := game.get_instance_id()
  mark("disconnect-ready")
  check(await until(func():return current_scene.get_instance_id()!=ending_world),"guest observes transport disconnect")
  check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest offline before detaching with pending host rewards")
  mark("offline-1")
  await process_frame
  if not settlement_fault.is_empty(): await blocked_reconnect(current_scene)
  return
 if not settlement_fault.is_empty():
  if settlement_fault=="cleanup":
   check(await until(func():
    return (read("final-snapshot").is_valid_int()
     and game.net_view.snapshot_received==int(read("final-snapshot"))
     and game.get_meta(&"guarded_host_cleanup_notice","")==Tx.CLEANUP_NOTICE)),
    "guest receives one final deferred snapshot with persistent cleanup warning")
   print("CASE ",JSON.stringify({"case":"guest_final_disconnect_snapshot","sequence":game.net_view.snapshot_received,
    "warning":game.get_meta(&"guarded_host_cleanup_notice",""),"role":role}))
   mark("snapshot-"+role)
  var original_world := game.get_instance_id()
  check(await until(func():return current_scene.get_instance_id()!=original_world),"guest leaves on blocked host shutdown")
  check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest offline on blocked shutdown")
  return
 if role=="3":
  if not await until(func(): return read("expire-lease")=="yes"):
   check(false,"host finished settlement before lease expiry")
   return
  var marker := ConfigFile.new()
  marker.set_value("session","process_id",OS.get_process_id())
  marker.set_value("session","updated",Time.get_unix_time_from_system()-60.0)
  var lease := P.get_base_dir().path_join("session.cfg")
  check(marker.save(lease)==OK,"expire disposable profile lease")
  game.get_meta(Tx.SESSION)._heartbeat_at = Time.get_unix_time_from_system()+25.0
  var stable := FileAccess.get_sha256(P)
  var stages := {"count":0}
  game.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):
   if phase=="stage": stages.count+=1
   return OK)
  mark("lease-ready")
  check(await until(func(): return read("projection-sent")=="yes"),"host dispatches delayed projection")
  await create_timer(.4).timeout
  check(FileAccess.get_sha256(P)==stable and stages.count==0 and game.guest_character.data.name!="Delayed acceptance probe","late projection does not stage or persist")
  print("CASE ",JSON.stringify({"case":"late_projection_lease_loss","before":stable,"after":FileAccess.get_sha256(P),"stages":stages.count}))
  mark("lease-refused")
 var attempt := game.get_instance_id()
 check(await until(func():return current_scene.get_instance_id()!=attempt),"guest returned to title")
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest offline after host shutdown")
 if role!="3":
  check(not FileAccess.file_exists(P.get_base_dir().path_join("session.cfg")),"guest releases owned lease")
 mark("offline-"+role)


func blocked_reconnect(menu: Node) -> void:
 if not await until(func():return read("blocked-reconnect")=="yes"):
  check(false,"host entered unresolved state")
  return
 var before := FileAccess.get_sha256(P)
 var game := connect_to_host(menu)
 if game==null: return
 var instance := game.get_instance_id()
 check(await until(func():return current_scene.get_instance_id()!=instance),"pending host refuses actual Join")
 check(FileAccess.get_sha256(P)==before and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,
  "pending-host refusal leaves local profile and transport intact")
 mark("blocked-refused")
 if settlement_fault=="cleanup": return
 if not await until(func():return read("host-reopened").is_valid_int()):
  check(false,"host completed B2 recovery")
  return
 mark("port",read("host-reopened"))
 game=connect_to_host(current_scene)
 if game==null: return
 instance=game.get_instance_id()
 check(await until(func():return admitted(instance)),"actual guest Join after B2")
 mark("rejoin-after-recovery")
 check(await until(func():return current_scene.get_instance_id()!=instance),"reopened host disconnects normally")
 check(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"reconnected guest installs offline peer")

func player_id(game: Node, role: String) -> int:
 for id in game.players:
  if id!=1 and game.players[id].character.name=="Release Guest "+role: return id
 check(false,"missing admitted guest "+role)
 return 0


func committed_guests(game: Node) -> int:
 return game.players.values().filter(func(player): return player.get("projection_delivery",{}).get("state")=="committed").size()

func create_character(menu: Node, name: String) -> void:
 menu.request_create_character()
 check(menu.creator.visible,"title opens creator")
 menu.creator.name_field.text = name
 menu.creator.confirmed.emit()
 check(menu.character_summary(0).name==name and not menu.creator.visible,"title commits roster creation")


func connect_to_host(menu: Node) -> Node:
 menu.join_button.pressed.emit()
 check(menu.network_dialog.visible,"Join by IP opens real title dialog")
 menu.network_dialog.address_field.text = "127.0.0.1:" + read("port")
 menu.network_dialog.submit.pressed.emit()
 if current_scene==menu:
  check(false,"title Join starts: "+menu.notice.text)
  return null
 return current_scene

func admitted(instance: int) -> bool:
 return is_instance_valid(current_scene) and current_scene.get_instance_id()==instance and current_scene.session=="Guest" and not current_scene.client_details.is_empty()
