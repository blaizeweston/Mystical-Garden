extends RefCounted
# 2.5D body footprints: decorative tendrils/antlers are excluded. Height is cosmetic.
const Enemies=preload("res://enemy_catalog.gd")
static func radius(game: Node,target: int) -> float:
 var kind: int=game.enemy_kind if target==-1 else int(game.scouts[target].get("kind",0))
 var mask: int=game.enemy_mutations if target==-1 else int(game.scouts[target].get("mutations",0))
 var growth: int=game.enemy_growth if target==-1 else int(game.scouts[target].get("growth",0))
 var definition:=Enemies.get_kind(kind)
 var body:=float(definition.get("hitbox",{}).get("radius",definition.get("hurt_radius",.48)))
 var size:=1.0
 if target==-1:
  size=float(definition.get("model_scale",1.0)) if game.boss_kind>=0 else 1.9 if game.destination==game.Campaign.HEART or game.depth==game.ROUTE_ROOMS else 1.0 if game.depth==1 else 1.22
 return body*size*(.65 if mask & Enemies.JUVENILE else 1.0)*(1.0+growth*.07)
static func contact(game: Node,target: int,origin: Vector3) -> Vector3:
 var center: Vector3=game.enemy_position(target)
 var edge:=center.move_toward(origin,minf(radius(game,target),center.distance_to(origin)))
 # If a body overlaps cover, callers must test the center rather than reach through it.
 return edge if game.battlefield.clear_line(edge,center) else center
static func sweep(game: Node,target: int,from: Vector3,to: Vector3,padding: float=-1.0) -> Dictionary:
 var center: Vector3=game.enemy_position(target)
 var a:=Vector2(from.x-center.x,from.z-center.z);var travel:=Vector2(to.x-from.x,to.z-from.z)
 if padding<0:
  var kind: int=game.enemy_kind if target==-1 else int(game.scouts[target].get("kind",0))
  padding=clampf(float(Enemies.get_kind(kind).get("hitbox",{}).get("projectile_padding",.12)),0,.3)
 var r:=radius(game,target)+padding;var fraction:=0.0
 if a.length_squared()>r*r:
  var length:=travel.length_squared()
  if length<.0000001:return {}
  var b:=a.dot(travel);var discriminant:=b*b-length*(a.length_squared()-r*r)
  if discriminant<0:return {}
  fraction=(-b-sqrt(discriminant))/length
  if fraction<0 or fraction>1:return {}
 var point:=from.lerp(to,fraction)
 if not game.battlefield.clear_line(from,point) or not game.battlefield.clear_line(point,center):return {}
 return {"point":point,"fraction":fraction}
