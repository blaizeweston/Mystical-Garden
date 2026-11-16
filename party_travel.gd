extends RefCounted

static func members(game: Node,kind: String) -> Array:
 var result: Array=[]
 for id in game.players:
  var p: Dictionary=game.players[id]
  if not p.get("profile_ready",false) or p.get("rejecting",false): continue
  if kind=="depart" or (p.wild and not p.fallen): result.append(id)
 result.sort();return result

static func clear(game: Node) -> void:
 game.travel_kind="";game.travel_votes.clear();game.travel_members.clear();game.travel_epoch+=1

static func cancel(game: Node,message: String="",effects = null) -> void:
 var pending: bool=not game.travel_kind.is_empty()
 clear(game)
 if pending and not message.is_empty():
  for id in members(game,"depart"): game.action_feedback(effects,id,message)

static func signature(game: Node,p: Dictionary,kind: String) -> String:
 if kind!="depart":
  return str([game.destination,game.encounter_number,game.map_seed,p.wild,p.fallen])
 var tree: RefCounted=game.Classes.connected_in_world(game,int(p.frame),p.character)
 var path: Array=[] if tree==null else tree.path(p.character)
 return str([game.destination,game.encounter_number,game.map_seed,p.frame,p.get("weapon_kind",0),p.prepared,p.prepared_secondary,p.prepared_catalyst,p.cargo_plan,p.character.get("upgrades",[]),path])

static func point(game: Node,kind: String) -> Vector3:
 return game.Stage.HEART if kind=="depart" and game.destination==game.Campaign.HEART else game.stage.gate_position() if kind=="depart" else game.battlefield.advance

static func validate(game: Node) -> void:
 if game.travel_kind.is_empty(): return
 if members(game,game.travel_kind)!=game.travel_members:
  cancel(game,"Party changed. Confirm readiness again at the gate.");return
 for id in game.travel_votes.keys():
  var p: Dictionary=game.players[id]
  if game.travel_votes[id]!=signature(game,p,game.travel_kind) or p.pos.distance_to(point(game,game.travel_kind))>preload("res://gate_interaction.gd").travel_range(game,game.travel_kind)+preload("res://gate_interaction.gd").READY_MARGIN:
   game.travel_votes.erase(id);game.tell(id,"Readiness cleared. Return to the gate and confirm your current loadout.")

static func begin(game: Node,kind: String) -> void:
 if game.travel_kind!=kind or game.travel_members!=members(game,kind):
  clear(game);game.travel_kind=kind;game.travel_members=members(game,kind)
 validate(game)

static func request(game: Node,id: int,kind: String) -> void:
 if not game.Transactions.session_writable(game) or not game.players.has(id) or not game.players[id].profile_ready: return
 if kind!="depart" and game.has_meta(game.Transactions.SESSION) and not game.encounter_rewarded: return
 var p: Dictionary=game.players[id]
 if kind=="depart":
  if game.expedition_active() or p.wild: return
  for peer in game.players.values():
   if not peer.profile_ready or peer.get("rejecting",false): game.tell(id,"Waiting for the connecting player before departure.");return
  if preload("res://combat_ruleset.gd").active(game):
   var refusal := preload("res://affinity_build.gd").departure_refusal(p)
   if not refusal.is_empty():
    game.tell(id,refusal)
    return
 else:
  if not game.Life.alive(p) or not game.encounter_cleared() or game.destination==game.Campaign.HEART: return
  if kind=="extract" and not game.extraction_checkpoint_open(): game.tell(id,"Extraction opens at every sixth cleared gate.");return
 if p.pos.distance_to(point(game,kind))>preload("res://gate_interaction.gd").travel_range(game,kind): game.tell(id,"Confirm readiness at the Heart." if kind=="depart" and game.destination==game.Campaign.HEART else "Confirm readiness at the party's gate.");return
 begin(game,kind)
 if kind=="advance" and game.upgrade_checkpoint_open() and int(game.checkpoint_ready.get(id,0))!=game.encounter_number:
  # Open the existing cards, without treating a card choice as travel consent.
  if game.has_meta(game.Transactions.SESSION): game.activate_checkpoint()
  else: game.Transactions.run(game,func(): game._use_checkpoint(id,true))
  return
 game.travel_votes[id]=signature(game,p,kind)
 validate(game)
 if game.travel_votes.size()!=game.travel_members.size():
  game.tell(id,"Ready. Waiting for each party member to confirm at the gate.");return
 if kind=="advance" and game.upgrade_checkpoint_open() and not game.checkpoint_all_ready(): return
 var ids: Array=game.travel_members.duplicate()
 if game.has_meta(game.Transactions.SESSION):
  var close_after: bool = kind!="advance" or not game.upgrade_checkpoint_open()
  var result: Dictionary=game.run_guarded_action(id,game.Transactions.Scope.PAIR,func(effects):
   if kind=="depart":
    var cost:=departure_cost(game,ids)
    if not cost.error.is_empty():
     for peer_id in ids: game.action_feedback(effects,peer_id,cost.error)
     clear(game)
     return false
    game.settle_expedition_rewards(effects)
    for peer_id in ids:
     if not game._enter_wilds(peer_id,game.players[peer_id],cost.reserved,effects):
      game.SaveBatch.reject_guarded_serializer(ERR_UNAVAILABLE,game.progress.path)
      return false
   elif not game._use_checkpoint(id,kind=="advance",effects):
    return false
   clear(game)
   if close_after:
    for peer_id in ids: effects.append(game.close_flow_for.bind(peer_id))
   return true)
  # After a refusal or verified abort, fresh votes are required. An uncertain
  # transaction keeps its snapshot and session write block for recovery.
  if not game.Transactions.committed(result.persistence) and game.Transactions.session_writable(game):
   cancel(game)
  return
 var reservation: Array=[]
 if kind=="depart":
  var cost:=departure_cost(game,ids)
  if not cost.error.is_empty():
   for peer_id in ids: game.tell(peer_id,cost.error)
   clear(game);return
  reservation=cost.reserved
 var success=game.Transactions.run(game,func():
  if kind=="depart":
   for peer_id in ids:
    game._enter_wilds(peer_id,game.players[peer_id],reservation)
    if not game.players[peer_id].wild:
     game.SaveBatch.failure=ERR_UNAVAILABLE;return false
  else: game._use_checkpoint(id,kind=="advance")
  return true)
 if not success:
  game.battlefield.configure(game.destination,game.depth,game.map_seed)
  cancel(game,"Travel could not be saved. Nothing was consumed. Confirm readiness to retry.");return
 clear(game)
 for peer_id in ids:
  if peer_id==game.HOST: game.close_run_flow_panel()
  elif game.online_peer!=null: game.close_run_flow_panel.rpc_id(peer_id)

static func departure_cost(game: Node,ids: Array) -> Dictionary:
 var available: bool=game.progress.finale_available() if game.destination==game.Campaign.HEART else game.progress.campaign.available(game.destination)
 if not available: return {"error":"This route is still sealed."}
 var shared: Array=game.Parts.empty_counts();var reserved: Array=game.Seeds.counts()
 for id in ids:
  var p: Dictionary=game.players[id];var needed: Array=game.Parts.empty_counts()
  if preload("res://combat_ruleset.gd").active(game):
   var refusal := preload("res://affinity_build.gd").departure_refusal(p)
   if not refusal.is_empty(): return {"error":refusal}
  for part in [p.prepared,p.prepared_secondary,p.prepared_catalyst]:
   if part==0: continue
   if not game.Parts.is_plant(part): return {"error":"Choose valid plant parts before readying."}
   needed[part]+=1
  for part in range(1,needed.size()):
   needed[part]+=int(p.cargo_plan[part])
   shared[part]+=maxi(0,int(needed[part])-int(game.seed_reserve(p).parts[part]))
 for part in range(1,shared.size()):
  if shared[part]>game.progress.part_count(part): return {"error":"The party needs more %s for these loadouts. No materials were consumed."%game.Parts.part_name(part)}
  if game.Parts.is_plant(part) and part!=game.Parts.HEARTWOOD: reserved[game.Parts.plant_source(part)]+=shared[part]
 return {"error":"","reserved":reserved}

static func snapshot(game: Node,id: int) -> Dictionary:
 if game.travel_kind.is_empty(): return {}
 var names: Array=[]
 for peer in game.travel_members:
  if game.players.has(peer): names.append({"name":game.players[peer].character.get("name","Wanderer"),"ready":game.travel_votes.has(peer)})
 var goal: String=game.Campaign.NAMES[game.destination]
 if game.travel_kind=="depart" and game.destination!=game.Campaign.HEART and game.Campaign.SHORTCUT_COST[game.destination]>0: goal+=" (%d shared parts)"%game.Campaign.SHORTCUT_COST[game.destination]
 return {"goal":goal,"kind":game.travel_kind,"epoch":game.travel_epoch,"ready":game.travel_votes.has(id),"members":names}
