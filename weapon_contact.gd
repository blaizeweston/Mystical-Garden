extends RefCounted
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
# Resolved weapon delivery, collision and visible footprint use this same contract.
const Motion=preload("res://weapon_motion.gd")
const Hurt=preload("res://enemy_hurtbox.gd")
const Geometry=preload("res://attack_geometry.gd")
static func describe(form: String,stats: Dictionary) -> Dictionary:
 var p:=Motion.profile(form)
 var pattern: String="projectile" if p.projectile else "radial" if p.delivery=="radial" else "line" if p.delivery=="line" else "sweep"
 if not p.projectile and str(stats.pattern) in ["line","sweep"]:pattern=str(stats.pattern)
 var span: float=float(p.span) if float(p.span)>0 else 1.9
 var clip: String=str(p.get("variants",{}).get(pattern,p.clip))
 var variant:=Motion.variant_by_clip(form,str(stats.get("weapon_variant","")))
 if not variant.is_empty() and not (form=="knives" and pattern=="line") and not (form=="whip" and pattern=="sweep"):
  pattern=str(variant.get("delivery",pattern));span=float(variant.get("span",span));clip=variant.clip
 return {"form":form,"pattern":pattern,"span":span,"yaw_offset":float(variant.get("yaw_offset",0.0)),"width":p.width,"reach":float(stats.reach),"contact":float(p.release),"projectile_radius":p.projectile_radius,"height":p.height,"clip":clip}
static func outline(shape: Dictionary,origin: Vector3,aim: Vector3) -> PackedVector3Array:
 var path:=lash_path(shape,origin,aim)
 if not path.is_empty():return path_outline(path,float(shape.width))
 var result:=PackedVector3Array();var reach:=float(shape.reach)
 var direction: Vector3=(aim-origin).normalized()
 if direction.is_zero_approx():direction=Vector3.FORWARD
 direction=direction.rotated(Vector3.UP,float(shape.get("yaw_offset",0.0)))
 var side:=direction.cross(Vector3.UP).normalized()
 if str(shape.pattern)=="radial":
  for i in 48:result.append(origin+Vector3(cos(i*TAU/48.),0,sin(i*TAU/48.))*reach)
 elif str(shape.pattern) in ["line","projectile"]:
  var width:=float(shape.width)
  for i in 17:
   var angle: float=-PI*.5+i*PI/16.;result.append(origin+direction*reach+direction*cos(angle)*width+side*sin(angle)*width)
  for i in 17:
   var angle: float=PI*.5+i*PI/16.;result.append(origin+direction*cos(angle)*width+side*sin(angle)*width)
 else:
  result.append(origin)
  for i in 33:result.append(origin+direction.rotated(Vector3.UP,-float(shape.span)*.5+i*float(shape.span)/32.)*reach)
 return result

## Reviewed ground trace at impact. X is lateral metres, Y is a fraction of resolved reach.
static func lash_path(shape: Dictionary, origin: Vector3, aim: Vector3) -> PackedVector3Array:
 var path:=PackedVector3Array()
 if shape.get("form","")!="whip" or shape.get("pattern","")!="line":return path
 var samples: Array=Motion.variant_by_clip("whip",shape.get("clip","")).get("contact_path",[])
 if samples.is_empty():return path
 var forward:=Vector3(aim.x-origin.x,0,aim.z-origin.z).normalized()
 if forward.is_zero_approx():forward=Vector3.FORWARD
 var lateral:=Vector3.UP.cross(forward)
 var base_reach:=float(Motion.Classes.DEFINITIONS[3].weapons[2].reach)
 var scale:=Motion.lash_reach_scale(float(shape.reach))
 var outlet: Vector3=origin+lateral*float(samples[1][0])+forward*float(samples[1][1])*base_reach
 path.append(origin)
 for point: Array in samples.slice(1):
  var at:=origin+lateral*float(point[0])+forward*float(point[1])*base_reach
  path.append(outlet+(at-outlet)*scale)
 return path

static func path_outline(path: PackedVector3Array, width: float) -> PackedVector3Array:
 var left:=PackedVector3Array()
 var right:=PackedVector3Array()
 var first:=path[0].direction_to(path[1])
 var last:=path[-2].direction_to(path[-1])
 for i in range(1,path.size()-1):
  var incoming:=path[i-1].direction_to(path[i])
  var outgoing:=path[i].direction_to(path[i+1])
  var side: Vector3=(incoming+outgoing).normalized().cross(Vector3.UP)
  var offset:=side*width/side.dot(incoming.cross(Vector3.UP))
  var turn:=incoming.signed_angle_to(outgoing,Vector3.UP)
  if absf(turn)<.0001:
   left.append(path[i]+offset)
   right.append(path[i]-offset)
   continue
  var outside:=left if turn>0 else right
  var sign_side:=1.0 if turn>0 else -1.0
  var steps:=maxi(1,ceili(absf(turn)/(PI/16.0)))
  for step in steps+1:
   outside.append(path[i]+incoming.cross(Vector3.UP).rotated(Vector3.UP,turn*step/steps)*width*sign_side)
  if turn>0:right.append(path[i]-offset)
  else:left.append(path[i]+offset)
 for i in 17:
  var angle:=i*PI/16.0
  left.append(path[-1]+(last.cross(Vector3.UP)*cos(angle)+last*sin(angle))*width)
 right.reverse()
 left.append_array(right)
 for i in 17:
  var angle:=i*PI/16.0
  left.append(path[0]-(first.cross(Vector3.UP)*cos(angle)+first*sin(angle))*width)
 return left
static func accepts(game: Node,target: int,origin: Vector3,aim: Vector3,form: String,stats: Dictionary) -> bool:
 var profile:=describe(form,stats);var center: Vector3=game.enemy_position(target)
 var edge:=Hurt.contact(game,target,origin);var radius:=Hurt.radius(game,target)
 if not game.battlefield.clear_line(origin,edge):return false
 if profile.pattern=="radial":return center.distance_to(origin)<=float(profile.reach)+radius
 if profile.pattern=="line":
  var path:=lash_path(profile,origin,aim)
  if not path.is_empty():
   for i in range(1,path.size()):
    if center.distance_to(Geometry3D.get_closest_point_to_segment(center,path[i-1],path[i]))<=float(profile.width)+radius:return true
   return false
  var direction: Vector3=(aim-origin).normalized()
  var closest:=Geometry3D.get_closest_point_to_segment(center,origin,origin+direction*float(profile.reach))
  return closest.distance_to(center)<=float(profile.width)+radius
 var direction: Vector3=(aim-origin).rotated(Vector3.UP,float(profile.yaw_offset))
 return Geometry.accepts_sector(origin,origin+direction,center,radius,float(profile.reach),float(profile.span))
static func token(game: Node,target: int) -> String:
 return "leader" if target==-1 else str(game.encounter.token(target))
static func candidates(game: Node,origin: Vector3) -> Array:
 var result: Array=[]
 for target in range(-1,game.encounter.scout_count()):
  if game.encounter.alive(target):result.append(target)
 result.sort_custom(func(a,b):return origin.distance_squared_to(game.enemy_position(a))<origin.distance_squared_to(game.enemy_position(b)))
 return result
static func secondary(game: Node,player: Dictionary,stats: Dictionary,point: Vector3,hits: Array,remaining: int) -> int:
 if str(stats.pattern) not in ["chain","splash"]:return remaining
 var radius:=3.2 if stats.pattern=="chain" else 2.1
 if stats.pattern=="splash":game.emit_combat_event("swing","splash",point,point,.24,game.weapon_effect_color(player),radius,0,{"form":"proc","pattern":"radial","contact":0.0,"width":.05,"span":TAU})
 var chain: bool=stats.pattern=="chain"
 var cursor:=point
 # Chain and splash contacts keep native weapon damage but cannot proc the graft again.
 var hit := stats.duplicate()
 hit.erase("native_graft_contact")
 while remaining>0:
  var found:=-2
  for other in candidates(game,cursor):
   if hits.has(token(game,other)):continue
   var edge:=Hurt.contact(game,other,cursor,chain)
   if cursor.distance_to(edge)>radius:continue
   var clear: bool=game.battlefield.projectile_clear(cursor,edge) if chain else game.battlefield.clear_line(cursor,edge)
   if clear:found=other;break
  if found==-2:break
  var next: Vector3=game.enemy_position(found);hits.append(token(game,found));remaining-=1
  if stats.pattern=="chain":game.emit_combat_event("link","chain",cursor,next,.20,game.weapon_effect_color(player),0,0)
  if stats.has("cr02_action"):
   preload("res://combat_action_events.gd").contact(game,stats,found,preload("res://combat_clock.gd").now(),true)
  OutgoingHits.hit_world(game, HitSession.peer_for(player), found, cursor, hit, preload("res://combat_clock.gd").now())
  if stats.pattern=="chain":cursor=next
 return remaining
static func melee(game: Node,shot: Dictionary,now: int) -> void:
 var player: Dictionary=game.players[shot.player];var remaining:=int(shot.stats.targets);var hits: Array=[]
 var direction: Vector3=(shot.aim-shot.origin).normalized()
 if not shot.stats.get("spirit_replica",false):shot.origin=player.pos
 shot.aim=shot.origin+direction*float(shot.stats.reach)
 var epoch: int=game.participation.epoch()
 var scout_tokens: PackedInt64Array=game.encounter.scout_tokens()
 for target in candidates(game,shot.origin):
  if remaining<=0 or game.participation.epoch()!=epoch:break
  var sampled_token: int=-1 if target==-1 else scout_tokens[target]
  if not game.encounter.alive(target,sampled_token):continue
  if not accepts(game,target,shot.origin,shot.aim,str(shot.form),shot.stats):continue
  var point: Vector3=game.enemy_position(target);hits.append(token(game,target));remaining-=1
  var hit: Dictionary = shot.stats.merged({"ranger_direct_hit":true},true)
  var reaper = preload("res://reaper_combat.gd")
  if hit.has(reaper.STRIKE):
   reaper.melee_contact(game,player,hit,target,now)
  OutgoingHits.hit_world(game, HitSession.peer_for(player), target, shot.origin, hit, now)
  if shot.stats.has("cr02_action"):
   preload("res://combat_action_events.gd").contact(game,shot.stats,target,now,false,point,direction)
  if shot.stats.pattern=="chain" or (shot.stats.pattern=="splash" and Motion.profile(str(shot.form)).delivery!="radial"):
   remaining=secondary(game,player,shot.stats,point,hits,remaining);break
 if not hits.is_empty() and game.encounter_cleared() and game.pending_finale_at==0:game.finish_combat(int(shot.player),shot.origin)
