extends SceneTree
var failed=false
func check(ok: bool,message: String):
 if not ok:failed=true;printerr("FAIL monster rewards: ",message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://world.tscn").instantiate();var token=str(Time.get_ticks_usec())
 game.progress.path="res://.godot/kill-rewards-"+token+".cfg";game.local_character.path=game.progress.path+".character";root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var p=game.players[1];game.add_player(2);var friend=game.players[2]
 friend.profile_ready=true;friend.seed_owner="e".repeat(32)
 for player in game.players.values():player.wild=true;player.pos=Vector3(0,0,4);player.character.xp.fill(0)
 game.battlefield.configure(0,1);game.battlefield.barriers=[];game.enemy_hp=10;game.enemy_pos=Vector3(0,0,10)
 var config=game.Director.config();var saved=config.duplicate(true);config.trophy_chance=1.0;config.trophy_cap=1.0
 var scout=game.make_scout(10,Vector3(0,0,5),1);scout.hp=1;game.scouts.assign([scout])
 game.apply_weapon_hit(p,0,p.pos,{"damage":1},1000)
 check(game.pending_kill_rewards.size()==1 and not game.encounter_cleared(),"a non-final individual kill queues rewards")
 game.record_enemy_death(0,scout.pos,p.pos)
 check(game.pending_kill_rewards.size()==1,"duplicate death cannot reroll or duplicate rewards")
 check(game.MonsterRewards.flush(game),"individual rewards save before encounter clear")
 check(game.wallet_for(p).earned_sparks()==1 and game.wallet_for(friend).earned_sparks()==1
  and p.character.xp[0]==1 and friend.character.xp[0]==1,"support and attacker get equal Essence and Class XP")
 check(game.run_wallet(p)==0 and game.run_wallet(friend)==0,"one spark does not yet grant spendable Essence")
 var own=game.inventory_floor_snapshot(p);var other=game.inventory_floor_snapshot(friend)
 check(own.size()==1 and other.size()==1 and own[0].id!=other[0].id,"each player sees only their own kill drop")
 check(own[0].item==game.Items.part_id(game.Parts.monster_part(10)),"part belongs to actual killed species")
 friend.pos=scout.pos;game.pickup_inventory_drop(2,friend,own[0].id)
 check(game.inventory_floor_snapshot(p).size()==1,"another player cannot steal an owned part")
 p.pos=scout.pos;game.pickup_inventory_drop(1,p,own[0].id)
 check(p.carried_parts[game.Parts.monster_part(10)]==1 and game.inventory_floor_snapshot(friend).size()==1,"pickup changes only owner inventory")
 var summoned=game.make_scout(0,Vector3(0,0,5),2);summoned.summoned=true;game.scouts.assign([summoned]);game.record_enemy_death(0,summoned.pos,p.pos)
 check(game.pending_kill_rewards.is_empty(),"summoned enemies cannot farm parts, essence or XP")
 # A failed save retains the same pre-rolled queue and restores all affected players.
 var before = game.wallet_for(p)
 var friend_before = game.wallet_for(friend)
 game.MonsterRewards.queue(game,"failure-fixture",11,0,p.pos,false)
 var frozen=game.pending_kill_rewards.duplicate(true);var path=game.progress.path
 game.progress.path="res://.godot/missing-kill-rewards-directory/fail.cfg"
 check(not game.MonsterRewards.flush(game),"failed persistence rejects reward settlement")
 check(game.wallet_for(p)==before and game.wallet_for(friend)==friend_before and game.pending_kill_rewards==frozen,
  "rollback preserves rolls and restores the previous immutable wallets")
 game.progress.path=path;check(game.MonsterRewards.flush(game),"same reward can be retried without reroll")
 var credited = game.wallet_for(p)
 check(credited.earned_sparks()==before.earned_sparks()+1 and game.wallet_for(friend).earned_sparks()==friend_before.earned_sparks()+1
  and game.MonsterRewards.flush(game) and game.wallet_for(p)==credited,"retry applies each eligible award exactly once")
 for i in 8:game.MonsterRewards.queue(game,"xp-fixture-"+str(i),0,0,p.pos,false)
 game.MonsterRewards.flush(game)
 check(p.character.xp[0]==10,"ten normal kills award ten whole Class XP")
 var profile=game.Character.new();profile.path=game.local_character.path;profile.load_profile()
 check(profile.data.xp[0]==10 and game.Character.Experience.current(profile.data),"kill XP persists independently of extraction")
 for save_path in [game.progress.path,game.local_character.path]:
  var saved_data := ConfigFile.new()
  check(saved_data.load(save_path)==OK and not saved_data.encode_to_text().contains(game.ExpeditionWallet.STATE)
   and not saved_data.encode_to_text().contains("essence_sparks"),"run-only wallet state is absent from canonical save bytes")
 game.award_combat_progress();check(p.character.xp[0]==10,"floor clear cannot duplicate kill XP")
 p.frame=2
 game.MonsterRewards.queue(game,"leader-xp",0,0,p.pos,true)
 var boss: int=game.Enemies.all().map(func(enemy):return enemy.id).find("orchard")
 game.MonsterRewards.queue(game,"boss-xp",boss,0,p.pos,true)
 check(game.pending_kill_rewards[0].rewards[0].xp==3 and game.pending_kill_rewards[1].rewards[0].xp==24,
  "ordinary and boss leaders queue 3 and 24 whole XP")
 check(game.MonsterRewards.flush(game) and p.character.xp[2]==27 and friend.character.xp[0]==37,
  "authoritative settlement awards each participant's selected class once")
 check("+27 class XP" in game.status,"reward feedback displays whole XP")
 p.character.xp[2]=game.Character.Experience.MAX_XP-1
 game.MonsterRewards.queue(game,"xp-ceiling",0,0,p.pos,true)
 check(game.MonsterRewards.flush(game) and p.character.xp[2]==game.Character.Experience.MAX_XP,
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
 game.queue_free();await process_frame
 if not failed:print("PASS: individual kills, equal party rewards, owner-only drops, summon exclusion, XP, rollback and bounded drop odds")
 quit(1 if failed else 0)
