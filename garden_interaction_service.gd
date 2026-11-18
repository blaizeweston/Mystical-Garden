extends RefCounted

const Session = preload("res://network_session.gd")

const Participation = preload("res://expedition_participation.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Tx=preload("res://game_transaction.gd")
const Catalog=preload("res://garden_interaction_catalog.gd")
const State=preload("res://garden_interaction_state.gd")
static func allowed(game: Node,definition: Dictionary) -> bool:
 for tech in Catalog.requirements(definition):
  if not game.progress.heart.has(str(tech)):return false
 if game.has_meta(&"experimental_terrain"):
  if definition.id=="heart_root_scar" and not game.progress.heart.has("clearing_1"):return false
  if definition.parent=="sheltered_spring" and not game.stage.station_position("spring").is_finite():return false
 if State.observed(game.progress.garden_interactions,str(definition.observation)):return true
 return preload("res://garden_relationships.gd").matches(game,definition)
static func eligible(game: Node,id: int) -> bool:
 return game.multiplayer.is_server() and game.players.has(id) and Session.ready_for(game.players[id],false) and not Participation.is_wild(game.players[id]) and not PlayerLifecycle.fallen(game.players[id])
static func nearest(game: Node,player: Dictionary,projection: Dictionary) -> String:
 if Participation.is_wild(player) or projection.get("version",0)!=State.VERSION:return ""
 var pos: Vector3=player.get("pos",Vector3.INF);var best:=INF;var found: String=""
 for point in Catalog.POINTS:
  if not projection.get("available",[]).has(point.id):continue
  var distance:=pos.distance_to(point_position(game,point))
  if distance<=float(point.range) and distance<best:found=point.id;best=distance
 if found.is_empty():return ""
 # Existing stations/beds win when they are closer; no interaction is stolen.
 for at in [game.Stage.HEART,game.stage.altar_position(),game.stage.gate_position()] + game.stage.bed_positions():
  if pos.distance_to(at)<best:return ""
 return found
static func point_position(game: Node,point: Dictionary) -> Vector3:
 if game.has_meta(&"experimental_terrain") and point.id=="spring_water":
  return game.stage.station_position("spring")
 return point.position
static func projection(game: Node,id: int) -> Dictionary:
 if not game.multiplayer.is_server():
  var received: Dictionary=game.players.get(id,{}).get("garden_interactions",{})
  return received if compatible_projection(received) else {}
 var state:=State.normalize(game.progress.garden_interactions);var available: Array=[];var observations: Array=[];var clues: Dictionary={}
 for point in Catalog.POINTS:
  if allowed(game,point):available.append(point.id)
  if State.observed(state,point.observation):
   observations.append(point.observation)
   var clue:=preload("res://garden_relationships.gd").clue(game,point)
   if not clue.is_empty():clues[point.observation]=clue
 return {"version":state.version,"catalog":Catalog.signature,"epoch":str(game.get_instance_id()),"revision":state.revision,"available":available,"observations":observations,"clues":clues,"latest":state.latest.duplicate(true),"conduit":preload("res://garden_conduit.gd").projection(game,id),"returns":preload("res://garden_return_service.gd").projection(game,id),"cultivation":preload("res://garden_crop_service.gd").projection(game,id),"growth":preload("res://garden_growth_service.gd").projection(game,id),"focus":game.players.get(id,{}).get("garden_focus",{}).duplicate(true)}
static func compatible_projection(data: Dictionary) -> bool:
 return data.get("version",0)==State.VERSION and data.get("catalog","")==Catalog.signature
static func focus(game: Node,id: int,point_id: String) -> void:
 var previous: Dictionary=game.players[id].get("garden_focus",{})
 game.players[id].garden_focus={"point":point_id,"serial":int(previous.get("serial",0))+1}
static func station_near(game: Node,player: Dictionary) -> String:
 var found: String="";var best:=INF
 for id in game.Stage.HEART_STATIONS:
  if not game.at_garden_station(player,id):continue
  var distance: float=player.pos.distance_to(game.stage.station_position(id))
  if distance<best:found=id;best=distance
 return found
static func interact(game: Node,id: int) -> bool:
 if not eligible(game,id):return false
 var point_id:=station_near(game,game.players[id])
 if point_id.is_empty():point_id=nearest(game,game.players[id],projection(game,id))
 if point_id.is_empty():return false
 if point_id=="spring_water" and not game.players[id].get("spring_water",false):
  return preload("res://garden_crop_service.gd").fill_water(game,id)
 focus(game,id,point_id);return true
static func reject(game: Node,id: int,reason: String) -> Dictionary:
 game.tell(id,reason)
 preload("res://diagnostic_journal.gd").event("garden","interaction_rejected",{"actor":id,"reason":reason})
 return {"changed":false,"error":reason}
static func command(game: Node,id: int,payload: String) -> Dictionary:
 if not eligible(game,id):return {"changed":false,"error":"Garden interaction unavailable."}
 var request=JSON.parse_string(payload) if payload.length()<=400 else null
 if not request is Dictionary:return reject(game,id,"Invalid Garden request.")
 for field in ["point","action","request"]:
  if not request.get(field) is String or request[field].is_empty() or request[field].length()>64:return reject(game,id,"Invalid Garden request.")
 if not request.get("revision") is float and not request.get("revision") is int:return reject(game,id,"Invalid Garden revision.")
 if float(request.revision)!=int(request.revision):return reject(game,id,"Invalid Garden revision.")
 if request.action=="configure_conduit":return preload("res://garden_conduit.gd").command(game,id,request)
 if request.point.begins_with("bed_"):return preload("res://garden_crop_service.gd").command(game,id,request)
 var definition:=Catalog.point(request.point)
 if definition.is_empty() or request.action not in ["inspect","observe"]:return reject(game,id,"Unknown Garden interaction.")
 var player: Dictionary=game.players[id]
 if not allowed(game,definition):return reject(game,id,"This Garden detail has changed. Inspect its surroundings again.")
 if player.pos.distance_to(point_position(game,definition))>float(definition.range):return reject(game,id,"Move closer to this Garden detail.")
 var state:=State.normalize(game.progress.garden_interactions)
 if state.version!=State.VERSION:return reject(game,id,"This Garden interaction save needs a newer game version.")
 var identity: String=game.local_character.identity if id==game.HOST else str(Session.inventory_owner(player))
 var key: String=identity+":"+request.request
 if request.action=="observe" and (State.observed(state,definition.observation) or not State.receipt(state,key).is_empty()):
  game.tell(id,"This observation is already recorded in the Garden.");return {"changed":false,"revision":state.revision}
 if int(request.revision)!=int(state.revision):return reject(game,id,"The Garden changed. Inspect it again before recording.")
 if request.action=="inspect":focus(game,id,definition.id);return {"changed":false,"revision":state.revision}
 var result=Tx.run_gameplay(game,Tx.Scope.PAIR,func():return State.record(game.progress.garden_interactions,definition,key))
 if not result.completed or not result.value is Dictionary:
  var notice:=Tx.feedback(result,"Could not save this observation. Please retry.")
  if game.persistence_session.is_guarded():game.tell(id,notice)
  return {"changed":false,"error":notice}
 var saved: Dictionary=result.value
 if saved.get("changed",false):
  game.tell(id,"Garden observation recorded: "+definition.name)
  preload("res://diagnostic_journal.gd").event("garden","observation_recorded",{"actor":id,"point_id":definition.id,"observation_id":definition.observation,"revision":saved.revision})
 return saved
