extends RefCounted
# Shared shape contract for damage and rendered trails. Angles are radians.
static func span(form: String) -> float:
 return maxf(.01,float(preload("res://weapon_motion.gd").profile(form).span))
static func accepts(pattern: String,origin: Vector3,aim: Vector3,point: Vector3,reach: float,form: String,primary: bool) -> bool:
 var offset:=point-origin
 if offset.length()>reach+.05: return false
 var facing: Vector3=(aim-origin).normalized()
 if offset.length()<.001: return true
 if facing.is_zero_approx(): facing=Vector3.FORWARD
 match pattern:
  "line": return offset.dot(facing)>=0 and (offset-facing*offset.dot(facing)).length()<=.9
  "sweep": return offset.normalized().dot(facing)>=cos(span(form)*.5)
  "splash": return point.distance_to(aim)<=2.1
  "chain": return point.distance_to(aim)<=3.2
 return primary

# Circle/sector intersection includes visible body edges, not only the center ray.
static func accepts_sector(origin: Vector3,aim: Vector3,center: Vector3,radius: float,reach: float,span_value: float) -> bool:
 var offset:=center-origin;offset.y=0;var distance:=offset.length()
 if distance>reach+radius:return false
 if distance<=radius:return true
 var facing: Vector3=(aim-origin).normalized()
 if facing.is_zero_approx():facing=Vector3.FORWARD
 var half:=span_value*.5;var inside:=offset.normalized().dot(facing)>=cos(half)
 if inside and distance<=reach:return true
 var first:=origin+facing.rotated(Vector3.UP,half)*reach;var second:=origin+facing.rotated(Vector3.UP,-half)*reach
 var nearest:=minf(center.distance_to(Geometry3D.get_closest_point_to_segment(center,origin,first)),center.distance_to(Geometry3D.get_closest_point_to_segment(center,origin,second)))
 if inside:nearest=minf(nearest,absf(distance-reach))
 return nearest<=radius+.01
