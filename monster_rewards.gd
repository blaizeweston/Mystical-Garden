extends RefCounted
# Prepare each kill once; freeze rolls before saving so retries cannot reroll loot.
static func checkpoint_only(game: Node) -> bool:
 return game.has_meta(&"experimental_terrain") and game.has_meta(game.Transactions.SESSION)

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
 var deferred := checkpoint_only(game)
 var kill := {"key":key,"kind":kind,"position":position,"rewards":rewards,"epoch":game.combat_epoch}
 if deferred:
  # Drops and essence belong to the active run. Keep XP and kill counts separate
  # from the profile so unrelated saves cannot accidentally bank the tally.
  kill.run_rewards_granted = true
  var notices := {}
  for reward: Dictionary in rewards:
   var id := int(reward.id)
   _grant_run_rewards(game,kill,reward,game.players[id])
   notices[id] = {"essence":reward.essence,"xp":reward.xp,"parts":int(not str(reward.item).is_empty())}
  if not game.SaveBatch.guarded_active():
   publish_notices(game,notices,false,true)
 game.pending_kill_rewards.append(kill)
static func flush(game: Node) -> bool:
 # Active floor XP stays in memory. A guest leaving the Garden still needs
 # the existing guarded departure settlement before their identity can rejoin.
 if checkpoint_only(game) and game.expedition_active(): return true
 if game.has_meta(game.Transactions.SESSION):
  if game.pending_kill_rewards.is_empty() and game.pending_departures.is_empty(): return true
  if game.Life.living_ids(game).is_empty() and game.pending_departures.values().any(func(actor): return actor.get("wild",false)):
   return game.finish_failed_expedition()
  var result: Dictionary=game.run_guarded_action(game.HOST,game.Transactions.Scope.PAIR,func(effects):
   game.settle_expedition_rewards(effects)
   return true)
  return game.Transactions.committed(result.persistence)
 if not game.pending_kill_rewards.is_empty():
  if not game.Transactions.run(game,func():return settle(game)):return false
 if not game.SaveBatch.active:
  publish_notices(game,game.kill_reward_notices)
  game.kill_reward_notices.clear()
 return true

static func publish_notices(game: Node,notices: Dictionary, require_profile := false, xp_pending := false) -> void:
 for id in notices:
  if not game.players.has(id):continue
  var notice=notices[id]
  var message := "+%.2f essence · +%.1f class XP%s%s"%[notice.essence/float(game.Director.config().essence_sparks_per_point),notice.xp/10.0," pending" if xp_pending else ""," · Monster part nearby" if notice.parts>0 else ""]
  if require_profile: game.tell_profile_action(id,message)
  else: game.tell(id,message)

static func settle(game: Node,effects = null) -> bool:
 var notices=game.kill_reward_notices
 var actors: Dictionary={}
 for kill in game.pending_kill_rewards:
  for reward in kill.rewards:
   var id=int(reward.id)
   var p: Dictionary=game.players.get(id,game.pending_departures.get(id,{}) if effects != null else {})
   if p.is_empty() or p.get("seed_owner","")!=reward.identity:continue
   var c=int(reward["class"]);var profile=p.character
   var total=int(profile.xp_tenths[c])+int(reward.xp)
   profile.xp[c]=mini(9999,int(profile.xp[c])+total/10);profile.xp_tenths[c]=total%10
   profile.monsters[int(kill.kind)]=mini(9999,int(profile.monsters[int(kill.kind)])+1)
   if effects == null: game.publish_character(id)
   else: actors[id]=p
   if kill.get("run_rewards_granted",false):
    continue
   _grant_run_rewards(game,kill,reward,p)
   if not notices.has(id):notices[id]={"essence":0,"xp":0,"parts":0}
   notices[id].essence+=int(reward.essence);notices[id].xp+=int(reward.xp);notices[id].parts+=int(not str(reward.item).is_empty())
 game.pending_kill_rewards.clear()
 if effects != null:
  for id in actors:
   if game.players.has(id): game.save_action_profile(id,effects)
   else: game.record_character(id,actors[id])
  var committed: Dictionary=notices.duplicate(true)
  notices.clear()
  if not committed.is_empty(): effects.append(publish_notices.bind(game,committed,true))
 return true

static func _grant_run_rewards(game: Node,kill: Dictionary,reward: Dictionary,p: Dictionary) -> void:
 p.essence_sparks=int(p.get("essence_sparks",0))+int(reward.essence)
 var id := int(reward.id)
 if int(kill.epoch)!=game.combat_epoch or not game.players.has(id):
  return
 var at: Vector3=kill.position
 if not str(reward.item).is_empty():
  game.wild_item_drops.append({"id":str(kill.key)+":"+str(id),"owner":id,"stack":{"item":reward.item,"quantity":1},"position":[at.x,at.y,at.z]})
 if reward.get("boss_seed",false):
  at += Vector3(.7,0,0)
  game.wild_item_drops.append({"id":str(kill.key)+":"+str(id)+":seed","owner":id,"stack":{"item":"boss_mystery_seed","quantity":1},"position":[at.x,at.y,at.z]})
