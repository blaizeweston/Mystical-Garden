extends RefCounted
## Host Garden command integration. Progress remains the only saved-state owner.
## Public requests use peer IDs; pure observation rules receive facts.
const Returns=preload("res://garden_return_service.gd")
const Rules=preload("res://garden_interaction_service.gd")
const Session=preload("res://network_session.gd")
const Participation=preload("res://expedition_participation.gd")
const PlayerLifecycle=preload("res://player_lifecycle.gd")
const Tx=preload("res://game_transaction.gd")
const Catalog=preload("res://garden_interaction_catalog.gd")
const State=preload("res://garden_interaction_state.gd")
const Water=preload("res://garden_water.gd")
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
const HeartCatalog=preload("res://heart_catalog.gd")
var _world: WeakRef
func _init(world: Node) -> void:_world=weakref(world)
func _current() -> Node:
 var world: Node=_world.get_ref()
 return world if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() else null

func allowed(definition: Dictionary) -> bool:
 var world:=_current()
 if world==null:return false
 var beds: Array=world.progress.plots.map(func(b):return {"species":b.species,"stage":b.stage})
 return Rules.allowed(definition,world.progress.heart.unlocked.duplicate(),{"observations":world.progress.garden_interactions.get("observations",{}).duplicate()},beds,world.stage.experimental_garden!=null,Water.available(world.stage))

func eligible(id: int) -> bool:
 var world:=_current()
 if world==null:return false
 return world.multiplayer.is_server() and world.players.has(id) and Session.ready_for(world.players[id],false) and not Participation.is_wild(world.players[id]) and not PlayerLifecycle.fallen(world.players[id])

func nearest(id: int, view_projection: Dictionary) -> String:
 var world:=_current()
 if world==null or not world.players.has(id):return ""
 var player: Dictionary=world.players[id]
 if Participation.is_wild(player) or view_projection.get("version",0)!=State.VERSION:return ""
 var available: Array = view_projection.get("available",[])
 if not available.has("spring_water") and not world.cultivation.water_carried(id):
  available = available.duplicate()
  available.append("spring_water")
 var positions: Dictionary={}
 for point in Catalog.POINTS:
  if not available.has(point.id):continue
  if point.id=="spring_water":
   var source:=Water.nearby(world.stage,player.pos)
   if not source.is_empty():positions[point.id]=source.position
  else:positions[point.id]=point_position(point)
 return Rules.nearest(player.pos,available,positions,[world.Stage.HEART,world.stage.altar_position(),world.stage.gate_position()]+world.stage.bed_positions())

func point_position(point: Dictionary,viewer: Vector3=Vector3.INF) -> Vector3:
 var world:=_current()
 if world==null:return Vector3.INF
 if point.id=="spring_water":
  if viewer.is_finite():
   var source:=Water.nearby(world.stage,viewer)
   if not source.is_empty():return source.position
  return Water.anchor(world.stage)
 return point.position

func projection(id: int) -> Dictionary:
 var world:=_current()
 if world==null:return {}
 if not world.multiplayer.is_server():
  var received: Dictionary=world.players.get(id,{}).get("garden_interactions",{})
  return received.duplicate(true) if Rules.compatible_projection(received) else {}
 var result:=_observation_data()
 result.merge({"returns":return_projection(id),"cultivation":world.cultivation.projection(id),"growth":preload("res://garden_growth_service.gd").projection(world,id),"focus":world.players.get(id,{}).get("garden_focus",{}).duplicate(true)})
 return result
## One observation selector serves networking and the lightweight local view.
## The latter never needs to construct every crop, and growth scene.

func _observation_data() -> Dictionary:
 var world:=_current()
 if world==null:return {}
 var state:=State.normalize(world.progress.garden_interactions);var available: Array=[];var observations: Array=[];var clues: Dictionary={}
 var beds: Array=world.progress.plots.map(func(b):return {"species":b.species,"stage":b.stage})
 var unlocked: Array=world.progress.heart.unlocked.duplicate()
 var developed: bool=world.stage.experimental_garden!=null
 var water_available:=Water.available(world.stage)
 for point in Catalog.POINTS:
  if Rules.allowed(point,unlocked,state,beds,developed,water_available):available.append(point.id)
  if State.observed(state,point.observation):
   observations.append(point.observation)
   var clue:=preload("res://garden_relationships.gd").clue(world.progress.altar_recipes,point)
   if not clue.is_empty():clues[point.observation]=clue
 return {"version":state.version,"catalog":Catalog.signature,"epoch":str(world.get_instance_id()),"revision":state.revision,"available":available,"observations":observations,"clues":clues,"latest":state.latest.duplicate(true)}

func observation_projection(id: int) -> Dictionary:
 var world:=_current()
 if world==null:return {}
 if not world.multiplayer.is_server():
  var received:=projection(id);var command_result: Dictionary={}
  for key in ["version","catalog","epoch","revision","available","observations","clues","latest","focus"]:
   if received.has(key):command_result[key]=received[key]
  return command_result.duplicate(true)
 var result:=_observation_data()
 result.focus=world.players.get(id,{}).get("garden_focus",{}).duplicate(true)
 return result

func projection_epoch(id: int) -> String:
 var world:=_current()
 if world==null:return ""
 return str(world.get_instance_id()) if world.multiplayer.is_server() else str(projection(id).get("epoch",""))

func focus(id: int,point_id: String) -> void:
 var world:=_current()
 if world==null or not world.players.has(id):return
 var previous: Dictionary=world.players[id].get("garden_focus",{})
 world.players[id].garden_focus={"point":point_id,"serial":int(previous.get("serial",0))+1}

func station_near(id: int) -> String:
 var world:=_current()
 if world==null or not world.players.has(id):return ""
 var player: Dictionary=world.players[id]
 var found: String="";var best:=INF
 for station in world.Stage.HEART_STATIONS:
  if not world.at_garden_station(player,station):continue
  var distance: float=player.pos.distance_to(world.stage.station_position(station))
  if distance<best:found=station;best=distance
 return found

func interact(id: int) -> bool:
 var world:=_current()
 if world==null:return false
 if not eligible(id):return false
 var point_id:=station_near(id)
 if point_id.is_empty():point_id=nearest(id,projection(id))
 if point_id.is_empty():return false
 if point_id=="spring_water" and not world.players[id].get("spring_water",false):
  return world.cultivation.fill_water(id)
 focus(id,point_id);return true

func reject(id: int,reason: String) -> Dictionary:
 var world:=_current()
 if world==null:return {}
 world.tell(id,reason)
 preload("res://diagnostic_journal.gd").event("garden","interaction_rejected",{"actor":id,"reason":reason})
 return {"changed":false,"error":reason}

func command(id: int,payload: String) -> Dictionary:
 var world:=_current()
 if world==null or not eligible(id):return {"changed":false,"error":"Garden interaction unavailable."}
 var parsed:=Rules.parse(payload)
 if parsed.has("error"):return reject(id,parsed.error)
 var request: Dictionary=parsed.request
 if request.point.begins_with("bed_"):return world.cultivation.command(id,request)
 var definition:=Catalog.point(request.point)
 var player: Dictionary=world.players[id]
 var in_reach: bool=not definition.is_empty() and player.pos.distance_to(point_position(definition,player.pos))<=float(definition.range)
 if definition.get("id","")=="spring_water":in_reach=in_reach and not Water.nearby(world.stage,player.pos).is_empty()
 var state:=State.normalize(world.progress.garden_interactions)
 var identity: String=world.local_character.identity if id==world.HOST else str(Session.inventory_owner(player))
 var decision:=Rules.observation(request,definition,state,identity,not definition.is_empty() and allowed(definition),in_reach)
 if decision.has("error"):return reject(id,decision.error)
 if decision.operation=="unchanged":
  world.tell(id,decision.message);return {"changed":false,"revision":decision.revision}
 if decision.operation=="focus":focus(id,definition.id);return {"changed":false,"revision":decision.revision}
 var result=Tx.run_gameplay(world,Tx.Scope.PAIR,func():return State.record(world.progress.garden_interactions,definition,decision.key))
 if not result.completed or not result.value is Dictionary:
  var notice:=Tx.feedback(result,"Could not save this observation. Please retry.")
  if world.persistence_session.is_guarded():world.tell(id,notice)
  return {"changed":false,"error":notice}
 var saved: Dictionary=result.value
 if saved.get("changed",false):
  world.tell(id,"Garden observation recorded: "+definition.name)
  preload("res://diagnostic_journal.gd").event("garden","observation_recorded",{"actor":id,"point_id":definition.id,"observation_id":definition.observation,"revision":saved.revision})
 return saved

func return_projection(id: int) -> Dictionary:
 var world:=_current()
 if world==null:return {}
 if not world.multiplayer.is_server():return world.players.get(id,{}).get("garden_interactions",{}).get("returns",{}).duplicate(true)
 return preload("res://garden_return_service.gd").projection(world.progress.garden_interactions)

func begin_returns() -> void:
 var world:=_current()
 if world!=null:preload("res://garden_return_service.gd").begin(world.progress)

func join_returns(id: int) -> void:
 var world:=_current()
 if world==null or not world.players.has(id):return
 var actor: String=world.local_character.identity if id==world.HOST else str(Session.inventory_owner(world.players[id]))
 if actor.is_empty():actor="peer:"+str(id)
 var run: String=preload("res://garden_return_service.gd").join(world.progress,actor)
 if run.is_empty():return
 world.players[id].garden_run_actor=actor;world.players[id].garden_run_id=run

func credit_return(member: Returns.Member,seeds: Array,source: String,ancient: bool=false) -> void:
 var world:=_current()
 if world!=null:Returns.bank(world.progress,member,seeds,source,ancient)

func return_outcome(member: Returns.Member,status: String) -> void:
 var world:=_current()
 if world!=null:Returns.outcome(world.progress,member,status)

func protected_return(member: Returns.Member,stacks: Array) -> void:
 var seeds: Array=[];var ancient:=false
 for stack in stacks:
  if stack.get("item","")=="unidentified_seed":seeds.append_array(stack.get("seeds",[]))
  elif stack.get("item","")=="boss_mystery_seed":ancient=true
 credit_return(member,seeds,"protected",ancient)

func extra_return(member: Returns.Member,ancient: bool) -> void:
 credit_return(member,[],"ancient_extract",ancient)

func handle(id: int, action: String) -> bool:
 var world:=_current()
 if world==null or not world.players.has(id):return false
 var player: Dictionary=world.players[id]
 if action.begins_with("care_"):
  var pieces:=action.split("_")
  if pieces.size() not in [3,4] or not pieces[2].is_valid_int(): return true
  var value:=int(pieces[2])
  if pieces[1]=="reclaim" and value>=0 and value<Seeds.NAMES.size() and world.progress.discoveries[value] and world.at_garden_station(player,"seed_archive"):
   if pieces.size()==4 and not pieces[3].is_valid_int():return true
   var personal:int=int(pieces[3]) if pieces.size()==4 else -1
   if pieces.size()==4 and personal<0:return true
   world.reclaim_seed(id,player,value,personal)
  elif pieces[1]=="offer" and Parts.is_monster(value) and world.at_garden_station(player,"monster_studies"):
   if world.stored_counts(player)[value]<=0:
    world.tell(id,"That trophy is no longer available.")
    return true
   var source: String=pieces[3] if pieces.size()==4 else ""
   if not source.is_empty() and source not in ["stash","shared"]:return true
   world.offer_monster(id,player,value,source)
  else:
   world.tell(id,"Move to the appropriate Garden station with an available ingredient.")
  return true
 if action.begins_with("plant_at_"):
  var fields:=action.split("_")
  if fields.size() not in [4,5] or not fields[2].is_valid_int() or not fields[3].is_valid_int(): return true
  var slot:=int(fields[2]);var species:=int(fields[3])
  var source: String=fields[4] if fields.size()==5 else "stash"
  if source not in ["stash","shared"]:return true
  if Participation.is_wild(player) or slot<0 or slot>=world.progress.plots.size() or species<0 or species>=Seeds.NAMES.size() or player.pos.distance_to(world.stage.bed_position(slot))>1.65: return true
  if world.progress.plots[slot].species>=0 or world.InventoryModel.reserve(world,player,source).stock[species]<=0:
   world.tell(id,"That bed or seed is no longer available.");world.show_planting_picker(id,slot);return true
  player.seed_choice=species
  if world.cultivation.plant_seed(id,slot,species,source):
   if id==world.HOST: world.ui.close_panels()
   else: world.close_planting_picker.rpc_id(id)
  return true
 if action.begins_with("heart_start_"):
  if id==world.HOST and world.at_heart(player) and not world.participation.active():
   var tech := action.trim_prefix("heart_start_")
   var refusal: String = world.progress.heart.requirements(world.progress, tech)
   world.tell(id, refusal if not refusal.is_empty() else world.run_heart_save(world.progress.heart.purchase.bind(world.progress, tech)))
  else: world.tell(id,"The host restores Garden technologies at the Heart between expeditions.")
  return true
 return false
