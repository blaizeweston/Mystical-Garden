extends RefCounted
## Observation decisions over detached Garden facts. No world or actor access.
const Catalog=preload("res://garden_interaction_catalog.gd")
const State=preload("res://garden_interaction_state.gd")
const Relationships=preload("res://garden_relationships.gd")

static func compatible_projection(data: Dictionary) -> bool:
 return data.get("version",0)==State.VERSION and data.get("catalog","")==Catalog.signature

static func parse(payload: String) -> Dictionary:
 var json:=JSON.new()
 if payload.length()>400 or json.parse(payload)!=OK:return {"error":"Invalid Garden request."}
 var request=json.data
 if not request is Dictionary:return {"error":"Invalid Garden request."}
 for field in ["point","action","request"]:
  if not request.get(field) is String or request[field].is_empty() or request[field].length()>64:return {"error":"Invalid Garden request."}
 if not request.get("revision") is float and not request.get("revision") is int:return {"error":"Invalid Garden revision."}
 if float(request.revision)!=int(request.revision):return {"error":"Invalid Garden revision."}
 return {"request":request}

static func allowed(definition: Dictionary, unlocked: Array, observations: Dictionary, beds: Array, developed: bool, water_available: bool) -> bool:
 for tech in Catalog.requirements(definition):
  if not unlocked.has(str(tech)):return false
 if developed:
  if definition.id=="heart_root_scar" and not unlocked.has("clearing_1"):return false
  if definition.parent=="sheltered_spring" and not water_available:return false
 if State.observed(observations,str(definition.observation)):return true
 return Relationships.matches(beds,definition)

static func observation(request: Dictionary, definition: Dictionary, state: Dictionary, identity: String, available: bool, in_reach: bool) -> Dictionary:
 if definition.is_empty() or request.action not in ["inspect","observe"]:return {"error":"Unknown Garden interaction."}
 if not available:return {"error":"This Garden detail has changed. Inspect its surroundings again."}
 if not in_reach:return {"error":"Move closer to this Garden detail."}
 if state.version!=State.VERSION:return {"error":"This Garden interaction save needs a newer game version."}
 var key: String=identity+":"+request.request
 if request.action=="observe" and (State.observed(state,definition.observation) or not State.receipt(state,key).is_empty()):
  return {"operation":"unchanged","revision":state.revision,"message":"This observation is already recorded in the Garden."}
 if int(request.revision)!=int(state.revision):return {"error":"The Garden changed. Inspect it again before recording."}
 return {"operation":"focus" if request.action=="inspect" else "record","revision":state.revision,"key":key}

static func nearest(position: Vector3, available: Array, positions: Dictionary, occupied: Array) -> String:
 var best:=INF;var found: String=""
 for point in Catalog.POINTS:
  if not available.has(point.id) or not positions.has(point.id):continue
  var distance:=position.distance_to(positions[point.id])
  if distance<=float(point.range) and distance<best:found=point.id;best=distance
 if found.is_empty():return ""
 for at: Vector3 in occupied:
  if position.distance_to(at)<best:return ""
 return found
