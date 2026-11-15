extends RefCounted
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
 return {"form":form,"pattern":pattern,"span":span,"width":p.width,"reach":float(stats.reach),"contact":float(p.release),"projectile_radius":p.projectile_radius,"height":p.height,"clip":clip}
static func outline(shape: Dictionary,origin: Vector3,aim: Vector3) -> PackedVector3Array:
 var result:=PackedVector3Array();var reach:=float(shape.reach)
 var direction: Vector3=(aim-origin).normalized()
 if direction.is_zero_approx():direction=Vector3.FORWARD
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
static func accepts(game: Node,target: int,origin: Vector3,aim: Vector3,form: String,stats: Dictionary) -> bool:
 var profile:=describe(form,stats);var center: Vector3=game.enemy_position(target)
 var edge:=Hurt.contact(game,target,origin);var radius:=Hurt.radius(game,target)
 if not game.battlefield.clear_line(origin,edge):return false
 if profile.pattern=="radial":return center.distance_to(origin)<=float(profile.reach)+radius
 if profile.pattern=="line":
  var direction: Vector3=(aim-origin).normalized()
  var closest:=Geometry3D.get_closest_point_to_segment(center,origin,origin+direction*float(profile.reach))
  return closest.distance_to(center)<=float(profile.width)+radius
 return Geometry.accepts_sector(origin,aim,center,radius,float(profile.reach),float(profile.span))
static func token(game: Node,target: int) -> String:
 return "leader" if target==-1 else str(game.scouts[target].get("spawn_token",target))
static func candidates(game: Node,origin: Vector3) -> Array:
 var result: Array=[]
 for target in range(-1,game.scouts.size()):
  if (game.enemy_hp if target==-1 else int(game.scouts[target].hp))>0:result.append(target)
 result.sort_custom(func(a,b):return origin.distance_squared_to(game.enemy_position(a))<origin.distance_squared_to(game.enemy_position(b)))
 return result
static func secondary(game: Node,player: Dictionary,stats: Dictionary,point: Vector3,hits: Array,remaining: int) -> int:
 if str(stats.pattern) not in ["chain","splash"]:return remaining
 var radius:=3.2 if stats.pattern=="chain" else 2.1
 if stats.pattern=="splash":game.emit_combat_event("swing","splash",point,point,.24,game.weapon_effect_color(player),radius,0,{"form":"proc","pattern":"radial","contact":0.0,"width":.05,"span":TAU})
 var cursor:=point
 while remaining>0:
  var found:=-2
  for other in candidates(game,cursor):
   if hits.has(token(game,other)):continue
   var edge:=Hurt.contact(game,other,cursor)
   if cursor.distance_to(edge)<=radius and game.battlefield.clear_line(cursor,edge):found=other;break
  if found==-2:break
  var next: Vector3=game.enemy_position(found);hits.append(token(game,found));remaining-=1
  if stats.pattern=="chain":game.emit_combat_event("link","chain",cursor,next,.20,game.weapon_effect_color(player),0,0)
  if stats.has("cr02_action"):
   preload("res://combat_action_events.gd").contact(game,stats,found,Time.get_ticks_msec(),true)
  game.apply_weapon_hit(player,found,cursor,stats,Time.get_ticks_msec())
  if stats.pattern=="chain":cursor=next
 return remaining
static func melee(game: Node,shot: Dictionary,now: int) -> void:
 var player: Dictionary=game.players[shot.player];var remaining:=int(shot.stats.targets);var hits: Array=[]
 var direction: Vector3=(shot.aim-shot.origin).normalized()
 shot.origin=player.pos;shot.aim=shot.origin+direction*float(shot.stats.reach)
 for target in candidates(game,shot.origin):
  if remaining<=0:break
  if not accepts(game,target,shot.origin,shot.aim,str(shot.form),shot.stats):continue
  var point: Vector3=game.enemy_position(target);hits.append(token(game,target));remaining-=1
  if shot.stats.has("cr02_action"):
   preload("res://combat_action_events.gd").contact(game,shot.stats,target,now)
  game.apply_weapon_hit(player,target,shot.origin,shot.stats,now)
  if shot.stats.pattern=="chain" or (shot.stats.pattern=="splash" and Motion.profile(str(shot.form)).delivery!="radial"):
   remaining=secondary(game,player,shot.stats,point,hits,remaining);break
 if not hits.is_empty() and game.encounter_cleared() and game.pending_finale_at==0:game.finish_combat(int(shot.player),shot.origin)
