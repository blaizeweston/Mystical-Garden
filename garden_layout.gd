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
 var result: Array=[stage.GATE,stage.ALTAR]+stage.PLOTS.slice(0,stage.active_plots)
 for id in stage.HEART_STATIONS:
  if stage.heart_unlocked.has(id):result.append(stage.HEART_STATIONS[id])
 for point in Catalog.POINTS:
  if enabled(point,stage.heart_unlocked):result.append(point.position)
 return result
static func in_water(point: Vector3,water: Dictionary,padding: float=0.0) -> bool:
 var offset: Vector3=point-water.position
 return Vector2(offset.x,offset.z/.72).length()<float(water.radius)*1.14+padding
static func ponds(stage: Node3D,radius: float) -> Array:
 var key:=str(["water-banks-1",radius,stage.heart_unlocked,stage.active_plots])
 var cached: Dictionary=stage.get_meta("garden_pond_layout",{})
 if cached.get("key","")==key:return cached.waters
 var result: Array=[]
 var size:=1.5+(radius-11.5)*.12
 var stations: Array=[stage.HEART,stage.GATE,stage.ALTAR]+stage.PLOTS
 for id in stage.HEART_STATIONS:stations.append(stage.HEART_STATIONS[id])
 for point in Catalog.POINTS:stations.append(point.position)
 var pool_index:=0
 for initial in [Vector3(-radius*.58,0,1.2),Vector3(radius*.55,0,-4)]:
  var selected:=Vector3.INF
  for attempt in 180:
   var at: Vector3=initial if attempt==0 else initial+Vector3(cos(attempt*2.4),0,sin(attempt*2.4))*(.25+attempt*.07)
   var candidate: Dictionary={"position":at,"radius":size}
   if at.length()+size>=radius-.3:continue
   var safe:=true
   for station in stations:
    if in_water(station,candidate,1.45):safe=false;break
   for destination in destinations(stage):
    var closest:=Geometry3D.get_closest_point_to_segment(at,Vector3.ZERO,destination)
    if in_water(closest,candidate,.65):safe=false;break
   for zone in Catalog.ZONES:
    if zone.has("footprint") and zone.footprint.grow(size+.5).has_point(Vector2(at.x,at.z)):safe=false
   for water in result:
    if at.distance_to(water.position)<size+float(water.radius)+.8:safe=false
   if safe:selected=at;break
  if selected!=Vector3.INF:
   var id:="garden_pool_%d"%pool_index
   result.append({"id":id,"position":selected,"radius":size,"shape":pond_shape(id,selected,size)})
  pool_index+=1
 stage.set_meta("garden_pond_layout",{"key":key,"waters":result})
 return result
static func reserved(stage: Node3D,point: Vector3,radius: float,padding: float=0.0) -> bool:
 if point.length()<1.75+padding:return true
 for zone in Catalog.ZONES:
  if zone.has("footprint") and enabled(zone,stage.heart_unlocked) and zone.footprint.grow(padding).has_point(Vector2(point.x,point.z)):return true
 for at in destinations(stage):
  if point.distance_to(at)<1.45+padding:return true
  var closest:=Geometry3D.get_closest_point_to_segment(point,Vector3.ZERO,at)
  if point.distance_to(closest)<.8+padding:return true
 for water in ponds(stage,radius):
  if in_water(point,water,.3+padding):return true
 return false
static func extent(stage: Node3D,radius: float) -> float:
 var result:=radius
 for entry in Catalog.ZONES:
  if entry.has("footprint") and enabled(entry,stage.heart_unlocked):
   var rect: Rect2=entry.footprint
   for at in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:result=maxf(result,at.length()+.5)
 return result

## The authored shoreline is shared by the existing visual fan and filling query.
static func pond_shape(id: String, at: Vector3, radius: float) -> Dictionary:
 var points:=PackedVector2Array()
 for i in 96:
  var angle:=TAU*i/96
  var rim:=radius*(1+.09*sin(angle*3)+.045*cos(angle*5))
  points.append(Vector2(at.x+cos(angle)*rim,at.z+sin(angle)*rim*.72))
 return preload("res://assets/terrain_m02/terrain_feature_geometry.gd").shape(id,"garden_pool",points)
