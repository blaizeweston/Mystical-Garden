extends RefCounted
# Prepare each kill once; freeze rolls before saving so retries cannot reroll loot.
static func queue(game: Node,key: String,kind: int,mask: int,position: Vector3,leader: bool) -> void:
 if game.kill_receipts.has(key): return
 game.kill_receipts[key]=true
 var config=game.Director.config()
 var rewards=[]
 for id in game.players:
  var p=game.players[id]
  if not p.get("profile_ready",false) or not p.wild or p.fallen: continue
  var chance=game.Director.trophy_chance(game.encounter_number,leader and game.depth==game.ROUTE_ROOMS,mask!=0)
  var item=game.roll_kill_trophy(kind,mask,leader)
  rewards.append({"id":id,"class":int(p.frame),"identity":p.get("seed_owner",""),"item":item,"essence":int(config.leader_essence_sparks if leader else config.kill_essence_sparks)*(6 if game.Enemies.get_kind(kind).get("boss",false) else 1),"boss_seed":bool(game.Enemies.get_kind(kind).get("boss",false)) and game.rng.randf()<float(game.Enemies.get_kind(kind).get("seed_drop_chance",1.0)),"xp":int(config.leader_xp_tenths if leader else config.kill_xp_tenths)*(8 if game.Enemies.get_kind(kind).get("boss",false) else 1)})
 game.pending_kill_rewards.append({"key":key,"kind":kind,"position":position,"rewards":rewards,"epoch":game.combat_epoch})
static func flush(game: Node) -> bool:
 if not game.pending_kill_rewards.is_empty():
  if not game.Transactions.run(game,func():return settle(game)):return false
 if not game.SaveBatch.active:
  for id in game.kill_reward_notices:
   if not game.players.has(id):continue
   var notice=game.kill_reward_notices[id]
   game.tell(id,"+%.2f essence · +%.1f class XP%s"%[notice.essence/float(game.Director.config().essence_sparks_per_point),notice.xp/10.0," · Monster part nearby" if notice.parts>0 else ""])
  game.kill_reward_notices.clear()
 return true
static func settle(game: Node) -> bool:
 var notices=game.kill_reward_notices
 for kill in game.pending_kill_rewards:
  for reward in kill.rewards:
   var id=int(reward.id)
   if not game.players.has(id):continue
   var p=game.players[id]
   if p.get("seed_owner","")!=reward.identity:continue
   p.essence_sparks=int(p.get("essence_sparks",0))+int(reward.essence)
   var c=int(reward["class"]);var profile=p.character
   var total=int(profile.xp_tenths[c])+int(reward.xp)
   profile.xp[c]=mini(9999,int(profile.xp[c])+total/10);profile.xp_tenths[c]=total%10
   profile.monsters[int(kill.kind)]=mini(9999,int(profile.monsters[int(kill.kind)])+1)
   game.publish_character(id)
   if not str(reward.item).is_empty() and int(kill.epoch)==game.combat_epoch:
    var at: Vector3=kill.position
    game.wild_item_drops.append({"id":str(kill.key)+":"+str(id),"owner":id,"stack":{"item":reward.item,"quantity":1},"position":[at.x,at.y,at.z]})
   if reward.get("boss_seed",false) and int(kill.epoch)==game.combat_epoch:
    var at: Vector3=kill.position+Vector3(.7,0,0)
    game.wild_item_drops.append({"id":str(kill.key)+":"+str(id)+":seed","owner":id,"stack":{"item":"boss_mystery_seed","quantity":1},"position":[at.x,at.y,at.z]})
   if not notices.has(id):notices[id]={"essence":0,"xp":0,"parts":0}
   notices[id].essence+=int(reward.essence);notices[id].xp+=int(reward.xp);notices[id].parts+=int(not str(reward.item).is_empty())
 game.pending_kill_rewards.clear()
 return true
