extends SceneTree
const Field=preload("res://battlefield.gd")
var failed:=false
func check(ok: bool,message: String) -> void:
 if not ok:failed=true;printerr("FAIL terrain generation: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var starts: Dictionary={};var ends: Dictionary={};var directions: Dictionary={};var began:=Time.get_ticks_msec()
 for index in 24:
  var field:=Field.new();field.configure(index%3,index%6+1,91247+index)
  check(field.connected(),"all destinations and clearings have real navigable routes")
  check(field.entry.distance_to(field.advance)>=12,"entry/exit are well separated")
  starts[Vector2i(roundi(field.entry.x),roundi(field.entry.z))]=true;ends[Vector2i(roundi(field.advance.x),roundi(field.advance.z))]=true
  var delta:=field.advance-field.entry;directions[posmod(roundi(atan2(delta.z,delta.x)/(PI*.25)),8)]=true
  for point in [field.entry,field.extraction,field.advance,field.leader,field.cache,field.graft]:
   check(not field.occupied(point,.65),"landmarks have clearance in the finished terrain")
   check(absf(point.x)<26 and absf(point.z)<26,"rotated map stays inside movement/render bounds")
  # The host and renderer independently reconstruct exactly the same surface.
  if index<3:
   var peer:=Field.new();peer.configure(index%3,index%6+1,91247+index)
   check(peer.clearings==field.clearings and peer.links==field.links and peer.surface.cells==field.surface.cells and peer.entry==field.entry and peer.advance==field.advance,"seed reproduces layout, gates and final walkable mask")
 check(starts.size()>=20 and ends.size()>=20 and directions.size()>=6,"endpoints and journey directions vary across seeds")
 # Crosses, T joins, shallow-angle intersections and parallel shoulder mergers.
 for angle in [0.0,.2,.6,PI*.5]:
  var f:=Field.new();f.procedural=true
  var a:=Vector2(-9,-2.5);var b:=Vector2(9,-2.5);var c:=Vector2(-9,2.5).rotated(angle);var d:=Vector2(9,2.5).rotated(angle)
  f.clearings.assign([Vector3(a.x,a.y,.1),Vector3(b.x,b.y,.1),Vector3(c.x,c.y,.1),Vector3(d.x,d.y,.1)])
  f.links=[[0,1,2.0],[2,3,2.0]];f.bake_surface();f.rebuild()
  if angle==0:
   for x in range(-6,7):
    var start:=Vector3(x,0,-1.4);var finish:=Vector3(x,0,1.4)
    check(f.dash(start,finish).distance_to(finish)<.01 and f.dash(finish,start).distance_to(start)<.01,"baked parallel shoulder has no hidden sweep boundary")
    for pair in [[start,finish],[finish,start]]:
     var walking: Vector3=pair[0]
     for step in 35:walking=f.slide(walking,walking.move_toward(pair[1],.1))
     check(walking.distance_to(pair[1])<.01,"normal walking crosses the final merged shoulder both ways")
  else:
   var intersection=Geometry2D.segment_intersects_segment(a,b,c,d)
   if intersection!=null:
    var at:=Vector3(intersection.x,0,intersection.y)
    for direction in [Vector3.RIGHT,Vector3.FORWARD]:
     var from: Vector3=at-direction*.8;var to: Vector3=at+direction*.8
     check(f.clear_line(from,to,.34) and f.dash(from,to).distance_to(to)<.01,"intersecting paint strokes have no internal collider")
  # Finished field uses true distance to the combined boundary, not each stroke.
  check(f.surface.distance(Vector3(0,0,-2.5))>.34,"centerline stays traversable")
 var gap:=Field.new();gap.procedural=true;gap.clearings.assign([Vector3(-9,-5,.1),Vector3(9,-5,.1),Vector3(-9,5,.1),Vector3(9,5,.1)]);gap.links=[[0,1,2.0],[2,3,2.0]];gap.bake_surface()
 check(not gap.inside_floor(Vector3.ZERO) and not gap.clear_line(Vector3(0,0,-4),Vector3(0,0,4),.34),"real forest gap remains blocked")
 gap.barriers=[Rect2(-1,-7,2,4)]
 check(not gap.clear_line(Vector3(-3,0,-5),Vector3(3,0,-5),.34),"visible solid cover stays solid")
 print("Terrain generation milliseconds: ",Time.get_ticks_msec()-began)
 if not failed:print("PASS: varied seeded routes and gate endpoints, merged traversable junctions, shared finished floor, preserved forest gaps and cover")
 quit(1 if failed else 0)
