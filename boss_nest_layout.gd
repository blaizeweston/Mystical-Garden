extends RefCounted
## The phase preview and battlefield bake use the same rib rectangles.

static func ribs(phase: int) -> Array:
 var result: Array=[]
 for side in [-1,1]:
  for index in 3:
   var x: float=side*(7.0+phase*.98)
   var z:=float([-6.0,1.0,8.0][index])+phase*.72*(-1.0 if index%2==0 else 1.0)
   result.append(Rect2(x-1.5,z-1.0,3.0,1.4))
 return result

static func blocked(upcoming: Array, at: Vector3, clearance: float) -> bool:
 var point:=Vector2(at.x,at.z)
 for rib in upcoming:
  if rib.grow(clearance).has_point(point):return true
 return false

static func step_out(field: RefCounted, upcoming: Array, at: Vector3, clearance: float) -> Vector3:
 if not blocked(upcoming,at,clearance):return at
 for distance in [.35,.7,1.05,1.4,1.75,2.1,2.45,2.8]:
  for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
   var candidate: Vector3=at+direction*distance
   if not blocked(upcoming,candidate,clearance) and field.clear_line(at,candidate,clearance):
    return candidate
 return Vector3.INF


static func exits(phase: int, seed_value: int) -> Array[Vector3]:
 var shift: float=(posmod(seed_value,7)-3)*.14
 return [Vector3(-3.35,0,4.25+shift+phase*.25),Vector3(3.35,0,4.25-shift-phase*.25)]
