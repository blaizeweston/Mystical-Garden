extends RefCounted
# One layout adapter feeds paths, decoration clearance, water and zone membership.
const Catalog=preload("res://garden_interaction_catalog.gd")
static func enabled(entry: Dictionary,unlocked: Array) -> bool:
 for tech in Catalog.requirements(entry):
  if not unlocked.has(tech):return false
 return true
static func zone(id: String) -> Dictionary:
 for entry in Catalog.ZONES:
  if entry.id==id:return entry
 return {}
static func zone_beds(id: String,count: int) -> Array[int]:
 var result: Array[int]=[]
 for bed_id in zone(id).get("beds",[]):
  var index:=int(str(bed_id).trim_prefix("bed_"))-1
  if index>=0 and index<count:result.append(index)
 return result
static func destinations(stage: Node3D) -> Array:
 var result: Array=[stage.gate_position(),stage.altar_position()]+stage.bed_positions().slice(0,stage.active_plots)
 for id in stage.HEART_STATIONS:
  if stage.heart_unlocked.has(id) and stage.station_position(id).is_finite():result.append(stage.station_position(id))
 for point in Catalog.POINTS:
  if enabled(point,stage.heart_unlocked):
   var at: Vector3=preload("res://garden_water.gd").anchor(stage) if point.id=="spring_water" else point.position
   if at.is_finite():result.append(at)
 return result
static func reserved(stage: Node3D,point: Vector3,_radius: float,padding: float=0.0) -> bool:
 if point.length()<1.75+padding:return true
 for garden_zone in Catalog.ZONES:
  if garden_zone.has("footprint") and enabled(garden_zone,stage.heart_unlocked) and garden_zone.footprint.grow(padding).has_point(Vector2(point.x,point.z)):return true
 for at in destinations(stage):
  if point.distance_to(at)<1.45+padding:return true
  var closest:=Geometry3D.get_closest_point_to_segment(point,Vector3.ZERO,at)
  if point.distance_to(closest)<.8+padding:return true
 var garden=stage.get("experimental_garden")
 if garden!=null and preload("res://assets/terrain_m02/terrain_feature_geometry.gd").in_any(garden.state.layout.water,Vector2(point.x,point.z),.3+padding):return true
 return false
static func extent(stage: Node3D,radius: float) -> float:
 var result:=radius
 for entry in Catalog.ZONES:
  if entry.has("footprint") and enabled(entry,stage.heart_unlocked):
   var rect: Rect2=entry.footprint
   for at in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:result=maxf(result,at.length()+.5)
 return result

