extends RefCounted

const Session = preload("res://network_session.gd")

const Participation = preload("res://expedition_participation.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

static func members(game: Node,kind: String) -> Array:
 var result: Array=[]
 for id in game.players:
  var p: Dictionary=game.players[id]
  if not Session.ready_for(p,false) or Session.rejecting_for(p): continue
  if kind=="depart" or (Participation.is_wild(p) and not PlayerLifecycle.fallen(p)): result.append(id)
 result.sort();return result

static func clear(game: Node) -> void:
 game.participation.clear_travel()

static func cancel(game: Node,message: String="",effects = null) -> void:
 var pending: bool=not game.participation.travel_kind().is_empty()
 clear(game)
 if pending and not message.is_empty():
  for id in members(game,"depart"): game.action_feedback(effects,id,message)

static func signature(game: Node,p: Dictionary,kind: String) -> String:
 if kind!="depart":
  return str([game.participation.route(),game.participation.floor(),game.participation.seed(),Participation.is_wild(p),PlayerLifecycle.fallen(p)])
 var tree: RefCounted=game.Classes.connected_in_world(game,int(p.frame),p.character)
 var path: Array=[] if tree==null else tree.path(p.character)
 return str([game.participation.route(),game.participation.floor(),game.participation.seed(),p.frame,p.get("weapon_kind",0),p.prepared,p.prepared_secondary,p.prepared_catalyst,p.cargo_plan,p.character.get("upgrades",[]),path])

static func point(game: Node,kind: String) -> Vector3:
 return game.Stage.HEART if kind=="depart" and game.participation.route()==game.Campaign.HEART else game.stage.gate_position() if kind=="depart" else game.battlefield.advance

static func validate(game: Node) -> void:
 if game.participation.travel_kind().is_empty(): return
 if members(game,game.participation.travel_kind())!=game.participation.travel_members():
  cancel(game,"Party changed. Confirm readiness again at the gate.");return
 for id in game.participation.travel_members():
  if not game.participation.has_vote(id): continue
  var p: Dictionary=game.players[id]
  if game.participation.vote_signature(id)!=signature(game,p,game.participation.travel_kind()) or p.pos.distance_to(point(game,game.participation.travel_kind()))>preload("res://gate_interaction.gd").travel_range(game,game.participation.travel_kind())+preload("res://gate_interaction.gd").READY_MARGIN:
   game.participation.retract_vote(id);game.tell(id,"Readiness cleared. Return to the gate and confirm your current loadout.")

static func begin(game: Node,kind: String) -> void:
 game.participation.begin_travel(kind,members(game,kind))
 validate(game)

static func request(game: Node,id: int,kind: String) -> void:
 if not game.persistence_session.can_write() or not game.players.has(id) or not Session.ready_for(game.players[id]): return
 if kind!="depart" and game.persistence_session.is_guarded() and not game.encounter_rewarded: return
 var p: Dictionary=game.players[id]
 if kind=="depart":
  if game.participation.active() or Participation.is_wild(p): return
  for peer in game.players.values():
   if not Session.ready_for(peer) or Session.rejecting_for(peer): game.tell(id,"Waiting for the connecting player before departure.");return
  var refusal := preload("res://affinity_build.gd").departure_refusal(p)
  if not refusal.is_empty():
   game.tell(id,refusal)
   return
 else:
  if not game.Life.alive(p) or not game.encounter_cleared() or game.participation.route()==game.Campaign.HEART: return
  if kind=="extract" and not game.extraction_checkpoint_open(): game.tell(id,"Extraction opens at every sixth cleared gate.");return
 if p.pos.distance_to(point(game,kind))>preload("res://gate_interaction.gd").travel_range(game,kind): game.tell(id,"Confirm readiness at the Heart." if kind=="depart" and game.participation.route()==game.Campaign.HEART else "Confirm readiness at the party's gate.");return
 begin(game,kind)
 # Each player claims their own upgrade before casting a separate travel vote.
 if kind=="advance" and game.activate_checkpoint(id):
  return
 game.participation.set_vote(id,signature(game,p,kind))
 validate(game)
 if game.participation.vote_count()!=game.participation.travel_members().size():
  game.tell(id,"Ready. Waiting for each party member to confirm at the gate.");return
 if kind=="advance" and game.upgrade_checkpoint_open() and not game.checkpoint_all_ready(): return
 var ids: Array=game.participation.travel_members()
 var bindings: Dictionary = {}
 for peer in ids: bindings[peer] = game.network_session.binding(peer)
 if game.persistence_session.is_guarded():
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
     if not game.expedition_transitions.admit(peer_id,cost.reserved,effects,int(bindings[peer_id])):
      game.SaveBatch.reject_guarded_serializer(ERR_UNAVAILABLE,game.progress.path)
      return false
   elif not game.expedition_transitions.commit_checkpoint(id,kind=="advance",effects,int(bindings[id])):
    return false
   clear(game)
   if close_after:
    for peer_id in ids: effects.append(game.close_flow_for.bind(peer_id))
   return true)
  # After a refusal or verified abort, fresh votes are required. An uncertain
  # transaction keeps its snapshot and session write block for recovery.
  if not game.Transactions.committed(result.persistence) and game.persistence_session.can_write():
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
    game.expedition_transitions.admit(peer_id,reservation,null,int(bindings[peer_id]))
    if not Participation.is_wild(game.players[peer_id]):
     game.SaveBatch.failure=ERR_UNAVAILABLE;return false
  else: return game.expedition_transitions.commit_checkpoint(id,kind=="advance",null,int(bindings[id]))
  return true)
 if not success:
  game.battlefield.configure(game.participation.route(),game.participation.depth(),game.participation.seed())
  cancel(game,"Travel could not be saved. Nothing was consumed. Confirm readiness to retry.");return
 clear(game)
 for peer_id in ids:
  if peer_id==game.HOST: game.close_run_flow_panel()
  elif game.network_session.transport()!=null: game.close_run_flow_panel.rpc_id(peer_id)

static func departure_cost(game: Node,ids: Array) -> Dictionary:
 var available: bool=game.progress.finale_available() if game.participation.route()==game.Campaign.HEART else game.progress.campaign.available(game.participation.route())
 if not available: return {"error":"This route is still sealed."}
 var shared: Array=game.Parts.empty_counts();var reserved: Array=game.Seeds.counts()
 for id in ids:
  var p: Dictionary=game.players[id];var needed: Array=game.Parts.empty_counts()
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
 if game.participation.travel_kind().is_empty(): return {}
 var voters: Array=[]
 for peer in game.participation.travel_members():
  if game.players.has(peer): voters.append({"id":peer,"name":game.players[peer].character.get("name","Wanderer"),"ready":game.participation.has_vote(peer)})
 var goal: String=game.Campaign.NAMES[game.participation.route()]
 if game.participation.travel_kind()=="depart" and game.participation.route()!=game.Campaign.HEART and game.Campaign.SHORTCUT_COST[game.participation.route()]>0: goal+=" (%d shared parts)"%game.Campaign.SHORTCUT_COST[game.participation.route()]
 return {"goal":goal,"kind":game.participation.travel_kind(),"epoch":game.participation.travel_epoch(),"ready":game.participation.has_vote(id),"members":voters}
