extends RefCounted
const SIGNATURE:="finished-floor-1-route-families-1"
## Seeded route families and whole-layout placement; shared by host and viewers.
static func shape(field: RefCounted,rng: RandomNumberGenerator,site: int) -> void:
 var family:=rng.randi_range(0,2)
 var count: int=field.main_count
 if family==1:
  # A sweeping crescent, rather than the usual north/south ribbon.
  var sweep:=rng.randf_range(PI*1.15,PI*1.55)
  for i in count:
   var t:=i/float(count-1);var a: float=-sweep*.5+t*sweep
   field.clearings[i]=Vector3(cos(a)*14-3,sin(a)*15,rng.randf_range(4.3,5.6)+(0.4 if site==1 else 0))
 elif family==2:
  # A broad branching circuit with a center crossing and optional side loop.
  var anchors: Array=[Vector2(-14,-12),Vector2(9,-11),Vector2(-8,2),Vector2(13,8),Vector2(-7,15),Vector2(7,17)]
  for i in count:
   var p: Vector2=anchors[i]+Vector2(rng.randf_range(-1.5,1.5),rng.randf_range(-1.5,1.5))
   field.clearings[i]=Vector3(p.x,p.y,rng.randf_range(4.3,5.6))
  if count>=5:field.links.append([1,count-1,2.1])
static func place(field: RefCounted,rng: RandomNumberGenerator) -> void:
 # Orientation, handedness and travel direction vary independently of family.
 var angle:=rng.randf_range(-PI,PI);var flip: float=-1 if rng.randf()<.5 else 1
 var extent:=0.0
 for clearing in field.clearings:extent=maxf(extent,Vector2(clearing.x,clearing.y).length()+clearing.z)
 var scale:=minf(1.0,24.0/maxf(1,extent))
 for i in field.clearings.size():
  var c: Vector3=field.clearings[i];var p:=Vector2(c.x*flip,c.y).rotated(angle)*scale
  field.clearings[i]=Vector3(p.x,p.y,c.z*scale)
 for link in field.links:link[2]=maxf(1.8,float(link[2])*scale)
 var start:=0;var end: int=field.main_count-1
 if rng.randf()<.5:start=end;end=0
 var first: Vector3=field.clearings[start];var last: Vector3=field.clearings[end]
 var inward: Vector2=(Vector2(field.clearings[1 if start==0 else start-1].x,field.clearings[1 if start==0 else start-1].y)-Vector2(first.x,first.y)).normalized()
 var outward: Vector2=(Vector2(last.x,last.y)-Vector2(field.clearings[end-1 if end>0 else 1].x,field.clearings[end-1 if end>0 else 1].y)).normalized()
 field.entry=Vector3(first.x+inward.x*.7,0,first.y+inward.y*.7)
 field.extraction=Vector3(first.x-inward.x*1.7,0,first.y-inward.y*1.7)
 field.advance=Vector3(last.x+outward.x*1.0,0,last.y+outward.y*1.0)
 field.leader=Vector3(last.x-outward.x*.9,0,last.y-outward.y*.9)
 var branch: Vector3=field.clearings[field.main_count];field.graft=Vector3(branch.x,0,branch.y)
 var spur: Vector3=field.clearings.back();field.cache=Vector3(spur.x,0,spur.y)
 field.spawn_points.clear()
 for i in 12:
  var node: int=i%field.clearings.size()
  if node==start:node=(node+1)%field.clearings.size()
  var c: Vector3=field.clearings[node];var a: float=i*2.39996
  field.spawn_points.append(Vector3(c.x+cos(a)*2.1,0,c.y+sin(a)*2.1))
