extends RefCounted
# Client positions are predicted/interpolated. A zero final prediction substep
# must not override visible travel and freeze the walking pose.
static func people(source: Dictionary,local_id: int=-1,local_aim: Vector3=Vector3.ZERO) -> Dictionary:
 var result: Dictionary={}
 for id in source:
  result[id]=source[id].duplicate();result[id].erase("velocity")
 if result.has(local_id) and not local_aim.is_zero_approx():result[local_id].aim_direction=local_aim
 return result
