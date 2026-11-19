extends SceneTree
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL monster rewards: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();var token=str(Time.get_ticks_usec())
 game.progress.path="res://.godot/kill-rewards-"+token+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p=game.players[1];game.add_player(2);var friend=game.players[2]
 SessionCase.set_ready(game, friend, true);SessionCase.set_identity(game, friend, "e".repeat(32))
 for player in game.players.values():ExpeditionCase.set_membership(game, player, true);player.pos=Vector3(0,0,4);player.character.xp.fill(0)
 game.battlefield.configure(0,1);preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[]);game.encounter.set_hp(-1, 10);game.tactics.position=Vector3(0,0,10)
 game.add_player(3)
 ExpeditionCase.set_membership(game, game.players[3], true)
 game.add_player(4)
 ExpeditionCase.set_membership(game, game.players[4], true)
 SessionCase.set_ready(game, game.players[4], true)
 game.players[4][PlayerLifecycle.STATE] = game.players[4][PlayerLifecycle.STATE].fall()
 var config=game.Director.config();var saved=config.duplicate(true);config.trophy_chance=1.0;config.trophy_cap=1.0
 var scout=game.make_scout(10,Vector3(0,0,5),1);scout.hp=1;game.encounter.clear_scouts();game.encounter.register_scout(scout)
 OutgoingHits.hit_world(game, HitSession.peer_for(p), 0, p.pos, {"damage":1}, 1000)
 check(game.monster_rewards.pending_count()==1 and not game.encounter_cleared(),"a non-final individual kill queues rewards")
 var first_receipt: Dictionary = game.monster_rewards.pending_receipts()[0]
 check(first_receipt.rewards.map(func(reward): return reward.id)==[1,2],
  "kill receipt freezes the eligible host and guest and excludes unready or fallen peers")
 first_receipt.rewards[0].xp=999
 check(game.monster_rewards.pending_receipts()[0].rewards[0].xp==1,"receipt inspection is detached from owner state")
 ExpeditionCase.remove_actor(game, 3)
 ExpeditionCase.remove_actor(game, 4)
 game.record_enemy_death(0,scout.pos,p.pos)
 check(game.monster_rewards.pending_count()==1,"duplicate death cannot reroll or duplicate rewards")
 check(game.flush_kill_rewards(),"individual rewards save before encounter clear")
 check(game.wallet_for(p).earned_sparks()==1 and game.wallet_for(friend).earned_sparks()==1
  and p.character.xp[0]==1 and friend.character.xp[0]==1,"support and attacker get equal Essence and Class XP")
 check(game.run_wallet(p)==0 and game.run_wallet(friend)==0,"one spark does not yet grant spendable Essence")
 game.record_enemy_death(0,scout.pos,p.pos)
 check(game.monster_rewards.status(first_receipt.key)==game.MonsterRewards.Phase.COMMITTED
  and game.monster_rewards.pending_count()==0 and game.wallet_for(p).earned_sparks()==1,
  "a repeated death cannot reopen a committed receipt")
 var own=game.inventory_floor_snapshot(p);var other=game.inventory_floor_snapshot(friend)
 check(own.size()==1 and other.size()==1 and own[0].id!=other[0].id,"each player sees only their own kill drop")
 check(own[0].item==game.Items.part_id(game.Parts.monster_part(10)),"part belongs to actual killed species")
 friend.pos=scout.pos;game.pickup_inventory_drop(2,friend,own[0].id)
 check(game.inventory_floor_snapshot(p).size()==1,"another player cannot steal an owned part")
 p.pos=scout.pos;game.pickup_inventory_drop(1,p,own[0].id)
 check(p.carried_parts[game.Parts.monster_part(10)]==1 and game.inventory_floor_snapshot(friend).size()==1,"pickup changes only owner inventory")
 var summoned=game.make_scout(0,Vector3(0,0,5),2);summoned.summoned=true;game.encounter.clear_scouts();game.encounter.register_scout(summoned);game.encounter.set_hp(0, 0);game.record_enemy_death(0,summoned.pos,p.pos)
 var summoned_key := "%d:%s" % [game.participation.epoch(), game.encounter.token(0)]
 var summoned_event: int = game.enemy_death_serial
 game.record_enemy_death(0,summoned.pos,p.pos)
 check(game.monster_rewards.status(summoned_key)==game.MonsterRewards.Phase.EXCLUDED
  and game.monster_rewards.pending_count()==0 and game.enemy_death_serial==summoned_event,
  "summoned deaths emit once and never farm parts, Essence or XP")
 # A failed save retains the same pre-rolled queue and restores all affected players.
 var before = game.wallet_for(p)
 var friend_before = game.wallet_for(friend)
 game._queue_monster_reward("failure-fixture",11,0,p.pos,false)
 var frozen=game.monster_rewards.pending_receipts();var path=game.progress.path
 game.progress.path="res://.godot/missing-kill-rewards-directory/fail.cfg"
 check(not game.flush_kill_rewards(),"failed persistence rejects reward settlement")
 check(game.wallet_for(p)==before and game.wallet_for(friend)==friend_before and game.monster_rewards.pending_receipts()==frozen,
  "rollback preserves rolls and restores the previous immutable wallets")
 game.progress.path=path
 var staged_inside_outer: Array[bool] = []
 var rejected_outer = game.Transactions.run(game,func():
  staged_inside_outer.append(game.flush_kill_rewards())
  staged_inside_outer.append(game.monster_rewards.status(frozen[0].key)==game.MonsterRewards.Phase.STAGED)
  game.SaveBatch.record_serializer_error(ERR_FILE_CANT_WRITE,game.progress.path)
  return true)
 check(not rejected_outer and staged_inside_outer==[true,true] and game.monster_rewards.pending_receipts()==frozen
  and game.wallet_for(p)==before and game.wallet_for(friend)==friend_before and p.character.xp[0]==1,
  "outer serializer rollback restores frozen intents after a nested reward flush")
 check(game.flush_kill_rewards(),"same reward can be retried without reroll")
 var credited = game.wallet_for(p)
 check(credited.earned_sparks()==before.earned_sparks()+1 and game.wallet_for(friend).earned_sparks()==friend_before.earned_sparks()+1
  and game.flush_kill_rewards() and game.wallet_for(p)==credited,"retry applies each eligible award exactly once")
 for i in 8:game._queue_monster_reward("xp-fixture-"+str(i),0,0,p.pos,false)
 game.flush_kill_rewards()
 check(p.character.xp[0]==10,"ten normal kills award ten whole Class XP")
 var profile=game.Character.new();profile.path=game.local_character.path;profile.load_profile()
 check(profile.data.xp[0]==10 and game.Character.Experience.current(profile.data),"kill XP persists independently of extraction")
 for save_path in [game.progress.path,game.local_character.path]:
  var saved_data := ConfigFile.new()
  check(saved_data.load(save_path)==OK and not saved_data.encode_to_text().contains(game.ExpeditionWallet.STATE)
   and not saved_data.encode_to_text().contains("essence_sparks"),"run-only wallet state is absent from canonical save bytes")
 game.award_combat_progress();check(p.character.xp[0]==10,"floor clear cannot duplicate kill XP")
 p.frame=2
 game._queue_monster_reward("leader-xp",0,0,p.pos,true)
 var boss: int=game.Enemies.all().map(func(enemy):return enemy.id).find("orchard")
 game._queue_monster_reward("boss-xp",boss,0,p.pos,true)
 var leaders: Array = game.monster_rewards.pending_receipts()
 check(leaders[0].rewards[0].xp==3 and leaders[1].rewards[0].xp==24,
  "ordinary and boss leaders queue 3 and 24 whole XP")
 p.frame=3
 friend.frame=1
 check(game.flush_kill_rewards() and p.character.xp[2]==27 and friend.character.xp[0]==37
  and p.character.xp[3]==0 and friend.character.xp[1]==0,
  "settlement awards the classes selected at the kill even if loadouts changed")
 check("+27 class XP" in game.status,"reward feedback displays whole XP")
 p.frame=2
 friend.frame=0
 p.character.xp[2]=game.Character.Experience.MAX_XP-1
 game._queue_monster_reward("xp-ceiling",0,0,p.pos,true)
 check(game.flush_kill_rewards() and p.character.xp[2]==game.Character.Experience.MAX_XP,
  "reward cap admits the full previous maximum and fractional remainder")
 config.clear();config.merge(saved,true)
 var unit = game.ExpeditionWallet.Wallet.new(7)
 var projected: Dictionary = unit.projection(2, 4)
 check(projected.balance==5 and projected.earned_sparks==7 and projected.spent_essence==0 and projected.milestone_essence==4,
  "wallet keeps fractional sparks separate from whole Essence earned by milestones")
 projected.balance=99
 projected.earned_sparks=99
 check(unit.balance(2,4)==5 and unit.earned_sparks()==7 and unit.plan_debit(6,2,4)==null and unit.plan_debit(-1,2,4)==null,
  "projection is detached and invalid debits leave the owner unchanged")
 var spent = unit.plan_debit(5,2,4)
 check(spent!=null and spent.balance(2,4)==0 and spent.spent_essence()==5 and unit.spent_essence()==0,
  "valid debit returns one successor without changing the prior wallet")
 var rolls=0;game.rng.seed=1271
 for i in 4000:rolls+=int(not game.roll_kill_trophy(12).is_empty())
 check(rolls>100 and rolls<260,"ordinary kills keep uncommon, non-guaranteed parts")
 check(game.Director.trophy_chance(100,true,true)<=.15,"adapted guardian chance stays capped")
 # The transport can reuse a peer ID before the old reward is settled.
 var former_identity: String = SessionCase.Session.inventory_owner(friend)
 var detached_profile: Dictionary = friend.character.duplicate(true)
 var former_xp: int = int(detached_profile.xp[0])
 config.merge({"trophy_chance":1.0,"trophy_cap":1.0},true)
 game._queue_monster_reward("detached-identity-one",10,0,p.pos,false)
 game._queue_monster_reward("detached-identity-two",10,0,p.pos,false)
 config.merge(saved,true)
 var frozen_departure_rewards: Array = game.monster_rewards.pending_receipts()
 check(game.monster_rewards.pending_profile_ids()==[game.local_character.identity,former_identity]
  and game.monster_rewards.pending_receipts()==frozen_departure_rewards
  and not frozen_departure_rewards[0].rewards[1].item.is_empty(),
  "pending profile identities are unique and include a frozen real trophy")
 SessionCase.set_identity(game, friend, "f".repeat(32))
 var replacement_wallet = game.wallet_for(friend)
 var replacement_drops: int = game.inventory_floor_snapshot(friend).size()
 var work: Array[Dictionary] = [{"peer_id":2,"identity":former_identity,"actor":{"character":detached_profile}}]
 var effects: Array[Callable] = []
 var settled = game.Transactions.run(game,func():
  var applied: bool = game._apply_pending_kill_rewards(effects,work)
  var repeated: bool = game._apply_pending_kill_rewards(effects,work)
  return applied and repeated)
 check(settled and int(detached_profile.xp[0])==former_xp+2
  and int(friend.character.xp[0])==former_xp and game.wallet_for(friend)==replacement_wallet
  and game.inventory_floor_snapshot(friend).size()==replacement_drops,
  "one settlement gives detached XP to the frozen identity without crediting the reused peer ID")
 check(game.monster_rewards.pending_count()==0
  and game.monster_rewards.status(frozen_departure_rewards[0].key)==game.MonsterRewards.Phase.COMMITTED
  and game.monster_rewards.status(frozen_departure_rewards[1].key)==game.MonsterRewards.Phase.COMMITTED,
  "the outer save commits the detached receipts exactly once")
 # The contained writer remains live while guarded production cutover is off.
 # Its actual abandonment must undo already saved XP, including on retry.
 p.frame=0
 var entry_xp: Array=p.character.xp.duplicate()
 var entry_monsters: Array=p.character.monsters.duplicate()
 check(game.monster_rewards.begin_expedition(game._kill_reward_identity(1,p),game.participation.run_id(),entry_xp,entry_monsters),
  "contained expedition records the entry reward boundary")
 game._queue_monster_reward("contained-forfeiture",0,0,p.pos,false)
 check(game.flush_kill_rewards() and p.character.xp[0]==int(entry_xp[0])+1,"contained route banks a real reward before forfeiture")
 var companion_xp: Array=friend.character.xp.duplicate()
 var canonical_path: String=game.progress.path
 game.progress.path="res://.godot/missing-forfeiture-directory/fail.cfg"
 ExpeditionCase.Transitions.abandon(game,1,p)
 check(ExpeditionCase.is_wild(p) and p.character.xp[0]==int(entry_xp[0])+1,
  "contained serializer failure restores participation, banked XP and the forfeiture claim")
 game.progress.path=canonical_path
 ExpeditionCase.Transitions.abandon(game,1,p)
 profile.load_profile()
 check(not ExpeditionCase.is_wild(p) and p.character.xp==entry_xp and p.character.monsters==entry_monsters
  and profile.data.xp==entry_xp and friend.character.xp==companion_xp and ExpeditionCase.is_wild(friend),
  "contained retry revokes the whole personal run without changing the teammate's rewards")
 game.queue_free();await process_frame
 if not failed:print("PASS: individual kills, equal party rewards, owner-only drops, summon exclusion, XP, rollback and bounded drop odds")
 quit(1 if failed else 0)
