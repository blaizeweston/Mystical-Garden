extends "res://tests/guarded_expedition_coop.gd"
## Real host/guest RPCs: a voluntary exit waits for the lowered canonical profile.

func prepare_focus(actor: Dictionary) -> void:
 var tree=world.Classes.connected_tree(int(actor.frame))
 actor.character[tree.profile_key]=tree.state([tree.nodes[0].id])

func host_run() -> void:
 var leader: Dictionary=world.players[1]
 leader.character.xp=[100,110,120,130,140]
 prepare_focus(leader)
 check(Tx.committed(world.run_guarded_action(1,Tx.Scope.PAIR,func(_effects):return true).persistence),"host pre-entry profile")
 check(SessionCase.World.host(world)==OK,"forfeiture host listens")
 mark("hosting")
 if not await until(func():return world.players.size()==2 and world.players.values().all(func(p):return SessionCase.Session.ready_for(p))):
  check(false,"guest admission")
  return
 var id: int=world.players.keys().filter(func(p):return p!=1)[0]
 var guest: Dictionary=world.players[id]
 prepare_focus(guest)
 var original: Array=guest.character.xp.duplicate()
 check(original==[200,210,220,230,240],"guest pre-entry XP is canonical")
 for actor in [leader,guest]: actor.pos=world.stage.gate_position()
 ExpeditionCase.Transitions.enter(world,1,leader)
 mark("enter",str(world.participation.travel_epoch()))
 if not await until(func():return ExpeditionCase.is_wild(guest) and ExpeditionCase.is_wild(leader)):
  check(false,"party enters")
  return
 world.send_expedition_state(0,true)
 world.encounter.set_hp(-1,0)
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 world.encounter.clear_scouts()
 world.finish_combat(1,world.tactics.position)
 if not await until(func():return marked("banked")):
  check(false,"guest banks first floor XP")
  return
 var owner: String=SessionCase.Session.inventory_owner(guest)
 var previous: Dictionary=world.progress.character_records[owner].duplicate(true)
 var obsolete: Dictionary={"profile":previous.profile,"origin":world.progress.projection_origin,"projection":previous.projection}
 for actor in [leader,guest]: actor.pos=world.battlefield.advance
 ExpeditionCase.Transitions.checkpoint(world,1,true)
 mark("advance",str(world.participation.travel_epoch()))
 if not await until(func():return world.participation.floor()==2):
  check(false,"floor two retains run identity")
  return
 world._queue_monster_reward("floor-two-pending",0,0,guest.pos,false)
 guest.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
 guest.carried_seeds=[1]
 world.send_expedition_state(0,true)
 mark("exit-ready")
 if not await until(func():return marked("save-refused")):
  check(false,"guest stays open after corrected-save abort")
  return
 check(not ExpeditionCase.is_wild(guest) and guest.character.xp==original and leader.character.xp[0]>100
  and world.monster_rewards.pending_count()==0 and world.run_wallet(guest)==0,"forfeiture clears guest rewards while keeping teammate rewards")
 var committed: Dictionary=world.progress.character_records[owner].duplicate(true)
 check(committed.profile.xp==original and committed.projection.revision>previous.projection.revision,"lower XP is a newer authoritative revision")
 # An old floor profile must not satisfy the pending exit or restore revoked XP.
 world.receive_character.rpc_id(id,obsolete)
 world.send_expedition_state(0,true)
 mark("retry-exit")
 if not await until(func():return marked("guest-offline") and world.multiplayer.get_peers().is_empty()):
  check(false,"saved guest exits to title")
  return
 check(world.progress.character_records[owner].profile.xp==original and world.players.size()==1,"disconnect does not re-credit forfeited rewards")
 record("guest_forfeiture_save_barrier","",{"guest_xp":original,"host_xp":leader.character.xp,"old_revision":previous.projection.revision,"new_revision":committed.projection.revision})
 # Host's own voluntary exit also revokes this run, without repeating guest work.
 check(world.prepare_guarded_exit() and leader.character.xp==[100,110,120,130,140],"host exit forfeits the host's run")

func guest_run() -> void:
 var local: Dictionary=world.players[1]
 local.character.xp=[200,210,220,230,240]
 prepare_focus(local)
 check(Tx.committed(world.run_guarded_action(1,Tx.Scope.PROFILE,func(_effects):return true).persistence),"guest pre-entry save")
 check(SessionCase.World.join(world,"127.0.0.1")==OK,"guest joins")
 if not await until(func():return world.network_session.role()=="Guest" and marked("enter")):
  check(false,"guest sees entry vote")
  return
 world.send_garden_action("travel_ready:"+read("enter"))
 if not await until(func():return world.guest_character.data.xp[0]>200):
  check(false,"floor profile reaches guest disk")
  return
 var before_profile: Dictionary=world.guest_character.data.duplicate(true)
 mark("banked")
 if not await until(func():return marked("advance")):
  check(false,"floor travel prompt")
  return
 world.send_garden_action("travel_ready:"+read("advance"))
 if not await until(func():return marked("exit-ready") and world.participation.floor()==2):
  check(false,"second-floor presentation")
  return
 world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_FILE_CANT_WRITE if phase=="stage" else OK)
 world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(not world.returning_to_title and world.network_session.awaiting_abandonment_save(),"window close is deferred pending authoritative save")
 if not await until(func():return world.get_meta(&"guest_projection_notice","").contains("not saved")):
  check(false,"guest save abort is visible")
  return
 check(is_instance_valid(world) and world.network_session.role()=="Guest" and world.guest_character.data==before_profile,"failed guest save cannot close or erase the local profile")
 mark("save-refused")
 if not await until(func():return marked("retry-exit")):
  check(false,"host correction remains retryable")
  return
 # The host has already sent a Garden snapshot. A repeated exit must still wait.
 world.remove_meta(&"guarded_gameplay_test_fault")
 world.return_to_main_menu()
 if not await until(func():return root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer):
  check(false,"retry saves corrected XP before offline title")
  return
 var profile=Profile.new()
 profile.path=C
 check(profile.load_profile(false)==OK and profile.data.xp==[200,210,220,230,240],"guest canonical save contains pre-entry XP after voluntary exit")
 check(current_scene==null or not SessionCase.has_guarded_session(current_scene),"guest returned to title")
 mark("guest-offline")

func run() -> void:
 host=OS.get_cmdline_user_args()[0]=="host"
 if not await start():
  quit(1)
  return
 if host: await host_run()
 else: await guest_run()
 if is_instance_valid(world) and world.network_session.transport()!=null: SessionCase.World.leave(world,"Fixture finished")
 check(await until(func():return root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"fixture network cleanup")
 if is_instance_valid(world): world.free()
 if not failed: print("PASS: expedition forfeiture co-op ","host" if host else "guest")
 quit(1 if failed else 0)
