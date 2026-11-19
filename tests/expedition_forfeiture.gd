extends "res://tests/guarded_expedition.gd"
## Whole-run forfeiture uses disposable guarded saves and actual reward receipts.

func owner_contract() -> void:
 var rewards = preload("res://monster_rewards.gd").new()
 var xp := [10,20,30,40,50]
 var known := [3,4]
 check(rewards.begin_expedition("one",11,xp,known),"entry captures all classes and familiarity")
 xp[0]=999
 known[0]=999
 check(not rewards.begin_expedition("one",11,xp,known),"duplicate entry cannot replace a run baseline")
 var candidates: Array[Dictionary] = [
  {"id":1,"class":0,"identity":"one","profile_ready":true,"wild":true,"fallen":false},
  {"id":2,"class":1,"identity":"two","profile_ready":true,"wild":true,"fallen":false}]
 var key: String = rewards.admit_kill(3,"enemy",{"summoned":false,"kind":0,"leader":false,"position":Vector3.ZERO},candidates,func():return "",func():return 1.0)
 var before: Dictionary = rewards.savepoint()
 check(rewards.forfeit_expedition("one",10).is_empty() and rewards.forfeit_expedition("other",11).is_empty(),"stale run and character cannot claim forfeiture")
 var prior: Dictionary = rewards.forfeit_expedition("one",11)
 check(prior.xp==[10,20,30,40,50] and prior.monsters==[3,4],"baseline does not alias the supplied arrays")
 check(rewards.pending_receipts()[0].rewards.map(func(row):return row.identity)==["two"],"only the forfeiter's pending permanent awards are removed")
 check(rewards.forfeit_expedition("one",11).is_empty(),"forfeiture is claimed once")
 rewards.restore_savepoint(before)
 check(rewards.pending_receipts()[0].rewards.size()==2 and not rewards.forfeit_expedition("one",11).is_empty(),"rollback restores receipts and the claim for a safe retry")
 rewards.stage_pending()
 rewards.finish_settlement(rewards.Result.COMMITTED)
 rewards.retire_completed()
 check(rewards.status(key)==rewards.Phase.ABSENT and rewards.begin_expedition("one",12,[1,2,3,4,5],[7]),"new run can follow completed forfeiture and floor retirement")
 rewards.retire_completed()
 check(rewards.forfeit_expedition("one",12).xp==[1,2,3,4,5],"floor receipt cleanup does not erase the run baseline")

func enter_run(actor: Dictionary) -> void:
 actor.pos=world.stage.gate_position()
 ExpeditionCase.Transitions.enter(world,1,actor)
 check(ExpeditionCase.is_wild(actor),"actual guarded expedition admission")

func bank_floor(actor: Dictionary) -> void:
 world.encounter.set_hp(-1,0)
 world.record_enemy_death(-1,world.tactics.position,Vector3.ZERO)
 world.encounter.clear_scouts()
 world.finish_combat(1,world.tactics.position)
 check(world.encounter_rewarded and actor.character.xp[actor.frame]>50,"real floor kill banks Class XP")

func verify_disk(expected: Array) -> void:
 var profile=world.Character.new()
 profile.path=C
 check(profile.load_profile(false)==OK and profile.data.xp==expected,"canonical profile stores corrected all-class XP")

func run() -> void:
 owner_contract()
 if not start_save_set():
  quit(1)
  return
 var actor: Dictionary=world.players[1]
 actor.character.xp=[50,60,70,80,90]
 actor.character.monsters.fill(2)
 actor.character.plants[0]=7
 var before_profile: Dictionary=actor.character.duplicate(true)
 var baseline_xp: Array=before_profile.xp
 var baseline_known: Array=before_profile.monsters
 check(Tx.committed(world.run_guarded_action(1,Tx.Scope.PAIR,func(_effects):return true).persistence),"save pre-entry progression")
 enter_run(actor)
 bank_floor(actor)
 actor.pos=world.battlefield.advance
 ExpeditionCase.Transitions.checkpoint(world,1,true)
 check(world.participation.floor()==2,"normal advancement preserves the run boundary")
 world._queue_monster_reward("later-unbanked",0,0,actor.pos,false)
 check(world.monster_rewards.pending_count()==1,"later floor still has a pending award")
 # Use the real one-item checkpoint delivery. It remains a protected exception.
 clear_floor(actor,3)
 world.progress.heart.unlocked.append("checkpoint_deposit")
 actor.carried_seeds=[0,1]
 var stored_before: int=world.progress.unknown.size()
 world.bank_checkpoint_item(1,actor,"deposit_seed_0")
 check(world.progress.unknown.size()==stored_before+1 and actor.last_deposit==3,"courier delivery commits before abandonment")
 actor.safe_items=[{"item":"unidentified_seed","quantity":1,"seeds":[1]}]
 actor.carried_parts[1]=2
 actor.carried_items={"fixture":1}
 var banked_xp: Array=actor.character.xp.duplicate()
 var frozen: Array=world.monster_rewards.pending_receipts()
 var before:=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_stage)
 ExpeditionCase.Transitions.abandon(world,1,actor)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(ExpeditionCase.is_wild(actor) and actor.character.xp==banked_xp and disk()==before
  and world.monster_rewards.pending_receipts()==frozen and actor.safe_items.size()==1,"verified abort restores XP, receipts, cargo and the forfeiture claim")
 ExpeditionCase.Transitions.abandon(world,1,actor)
 check(not ExpeditionCase.is_wild(actor) and actor.character.xp==baseline_xp and actor.character.monsters==baseline_known,"abandonment revokes banked and pending rewards across floors")
 var tree_key: String=world.Classes.connected_tree(int(actor.frame)).profile_key
 check(actor.character.plants==before_profile.plants and actor.character[tree_key]==before_profile[tree_key],"pre-entry plants and learned investments are not rewound")
 check(world.progress.unknown.size()==stored_before+1 and actor.safe_items.is_empty() and actor.carried_seeds.is_empty()
  and actor.carried_items.is_empty() and actor.carried_parts.all(func(n):return n==0) and world.run_wallet(actor)==0,"courier is retained; carried loot, safe pouch and wallet are discarded")
 verify_disk(baseline_xp)
 before=disk()
 ExpeditionCase.Transitions.abandon(world,1,actor)
 check(disk()==before and world.monster_rewards.pending_count()==0,"repeated abandonment cannot resettle rewards")
 record("forfeit_abort_retry_and_courier",before)
 # Death/wipe remains a non-voluntary end, and keeps its existing XP behavior.
 enter_run(actor)
 bank_floor(actor)
 var retained: Array=actor.character.xp.duplicate()
 IncomingPlayerHit.apply_health_loss(world,1,PlayerLifecycle.generation(actor),999)
 check(not ExpeditionCase.is_wild(actor) and actor.character.xp==retained,"normal wipe still banks XP")
 # Title return and window-close preparation use the same voluntary settlement.
 enter_run(actor)
 bank_floor(actor)
 check(world.prepare_guarded_exit() and actor.character.xp==retained and not world.participation.active(),"window-close preparation forfeits only this run")
 verify_disk(retained)
 enter_run(actor)
 bank_floor(actor)
 world.return_to_main_menu()
 check(current_scene!=world and actor.character.xp==retained,"real Return to Title forfeits the run")
 await process_frame
 if not open_world():
  quit(1)
  return
 actor=world.players[1]
 check(actor.character.xp==retained,"title reopen does not restore forfeited XP")
 enter_run(actor)
 bank_floor(actor)
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_receipt)
 ExpeditionCase.Transitions.abandon(world,1,actor)
 world.remove_meta(&"guarded_gameplay_test_fault")
 check(not ExpeditionCase.is_wild(actor) and actor.character.xp==retained and world.persistence_session.pending_notice()==Tx.CLEANUP_NOTICE,"cleanup-pending is a committed forfeiture, not a retry")
 var committed:=disk()
 ExpeditionCase.Transitions.abandon(world,1,actor)
 check(disk()==committed,"cleanup-pending cannot replay")
 check(Ops.recover(PackedStringArray([G])).value.verified,"disposable cleanup recovery")
 close_world()
 await process_frame
 if not open_world():
  quit(1)
  return
 actor=world.players[1]
 enter_run(actor)
 bank_floor(actor)
 before=disk()
 world.set_meta(&"guarded_gameplay_test_fault",fail_restore)
 ExpeditionCase.Transitions.abandon(world,1,actor)
 world.remove_meta(&"guarded_gameplay_test_fault")
 var split:=disk()
 check(actor.character.xp==retained and world.persistence_session.pending_notice().contains("uncertain")
  and not world.status.contains("Expedition abandoned."),"uncertain forfeiture holds tentative state without reporting success")
 ExpeditionCase.Transitions.abandon(world,1,actor)
 check(disk()==split,"uncertainty blocks unsafe replay")
 close_world()
 await process_frame
 check(current_scene.recovery_notice.visible,"uncertainty remains visible at title")
 current_scene.garden_recovery_button.pressed.emit()
 current_scene.recovery_confirmation.confirmed.emit()
 if not open_world():
  quit(1)
  return
 actor=world.players[1]
 var before_close: Array=actor.character.xp.duplicate()
 enter_run(actor)
 bank_floor(actor)
 # quit() is requested at the end of this frame, so the fixture can verify
 # canonical bytes and write its verdict after delivering the actual callback.
 world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 check(actor.character.xp==before_close and not world.participation.active()
  and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"actual window-close notification forfeits and detaches safely")
 verify_disk(before_close)
 if not failed: print("PASS: whole-run forfeiture, courier exception, rollback, wipe, title, close, cleanup and uncertainty")
 quit(1 if failed else 0)
