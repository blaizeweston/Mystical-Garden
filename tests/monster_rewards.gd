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
 for player in game.players.values():player.wild=true;player.pos=Vector3(0,0,4);player.character.xp.fill(0);player.character.xp_tenths.fill(0)
 game.battlefield.configure(0,1);game.battlefield.barriers=[];game.enemy_hp=10;game.enemy_pos=Vector3(0,0,10)
 var config=game.Director.config();var saved=config.duplicate(true);config.trophy_chance=1.0;config.trophy_cap=1.0
 var scout=game.make_scout(10,Vector3(0,0,5),1);scout.hp=1;game.scouts.assign([scout])
 game.apply_weapon_hit(p,0,p.pos,{"damage":1},1000)
 check(game.pending_kill_rewards.size()==1 and not game.encounter_cleared(),"a non-final individual kill queues rewards")
 game.record_enemy_death(0,scout.pos,p.pos)
 check(game.pending_kill_rewards.size()==1,"duplicate death cannot reroll or duplicate rewards")
 check(game.MonsterRewards.flush(game),"individual rewards save before encounter clear")
 check(p.essence_sparks==1 and friend.essence_sparks==1 and p.character.xp_tenths[0]==1 and friend.character.xp_tenths[0]==1,"support and attacker get equal essence and class XP")
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
 var before=p.essence_sparks;game.MonsterRewards.queue(game,"failure-fixture",11,0,p.pos,false)
 var frozen=game.pending_kill_rewards.duplicate(true);var path=game.progress.path
 game.progress.path="res://.godot/missing-kill-rewards-directory/fail.cfg"
 check(not game.MonsterRewards.flush(game),"failed persistence rejects reward settlement")
 check(p.essence_sparks==before and game.pending_kill_rewards==frozen,"rollback preserves rolls and restores both wallets")
 game.progress.path=path;check(game.MonsterRewards.flush(game),"same reward can be retried without reroll")
 for i in 8:game.MonsterRewards.queue(game,"xp-fixture-"+str(i),0,0,p.pos,false)
 game.MonsterRewards.flush(game)
 check(p.character.xp[0]==1 and p.character.xp_tenths[0]==0,"ten tenths become one existing class XP unit")
 var profile=game.Character.new();profile.path=game.local_character.path;profile.load_profile()
 check(profile.data.xp[0]==1 and profile.data.xp_tenths[0]==0,"kill XP persists independently of extraction")
 game.award_combat_progress();check(p.character.xp[0]==1,"floor clear cannot duplicate kill XP")
 config.clear();config.merge(saved,true)
 var rolls=0;game.rng.seed=1271
 for i in 4000:rolls+=int(not game.roll_kill_trophy(12).is_empty())
 check(rolls>100 and rolls<260,"ordinary kills keep uncommon, non-guaranteed parts")
 check(game.Director.trophy_chance(100,true,true)<=.15,"adapted guardian chance stays capped")
 game.queue_free();await process_frame
 if not failed:print("PASS: individual kills, equal party rewards, owner-only drops, summon exclusion, XP, rollback and bounded drop odds")
 quit(1 if failed else 0)
