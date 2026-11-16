extends RefCounted
# 2.5D body footprints: decorative tendrils/antlers are excluded. Height is cosmetic.
const Enemies=preload("res://enemy_catalog.gd")
const Shape=preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
static func radius(game: Node,target: int) -> float:
 var kind: int=game.enemy_kind
 var mask: int=game.enemy_mutations
 var growth: int=game.enemy_growth
 if target>=0 and game.multiplayer.is_server():
  var scout: Dictionary=game.scouts[target]
  kind=int(scout.get("kind",0))
  mask=int(scout.get("mutations",0))
  growth=int(scout.get("growth",0))
 if target>=0 and not game.multiplayer.is_server():
  var code := 19 + target
  var form := Enemies.decode(game.client_campaign[code] if code < game.client_campaign.size() else 0)
  kind = form.kind
  mask = form.mask
  growth = form.tier
 var definition:=Enemies.get_kind(kind)
 var body:=float(definition.get("hitbox",{}).get("radius",definition.get("hurt_radius",.48)))
 var size:=1.0
 if target==-1:
  size=float(definition.get("model_scale",1.0)) if game.boss_kind>=0 else 1.9 if game.destination==game.Campaign.HEART or game.depth==game.ROUTE_ROOMS else 1.0 if game.depth==1 else 1.22
 return body*size*(.65 if mask & Enemies.JUVENILE else 1.0)*(1.0+growth*.07)
static func contact(game: Node,target: int,origin: Vector3,ranged: bool=false) -> Vector3:
 var center: Vector3=game.enemy_position(target)
 var edge:=center.move_toward(origin,minf(radius(game,target),center.distance_to(origin)))
 # If a body overlaps cover, callers must test the center rather than reach through it.
 var visible: bool=game.battlefield.combat_sight(edge,center) if ranged else game.battlefield.clear_line(edge,center)
 return edge if visible else center
static func sweep(game: Node,target: int,from: Vector3,to: Vector3,padding: float=-1.0) -> Dictionary:
 var center: Vector3=game.enemy_position(target)
 if padding<0:
  var kind: int=game.enemy_kind if target==-1 else int(game.scouts[target].get("kind",0))
  padding=clampf(float(Enemies.get_kind(kind).get("hitbox",{}).get("projectile_padding",.12)),0,.3)
 return projectile_contact(game.battlefield,from,to,center,radius(game,target),padding)

static func projectile_contact(field: RefCounted,from: Vector3,to: Vector3,center: Vector3,body_radius: float,padding: float) -> Dictionary:
 var fraction:=Shape.circle_entry(Vector2(from.x,from.z),Vector2(to.x,to.z),Vector2(center.x,center.z),body_radius+padding)
 if fraction==INF:return {}
 var point:=from.lerp(to,fraction)
 # An inclusive cover test at the contact point gives cover priority on a tie.
 if not field.projectile_clear(from,point,padding) or not field.combat_sight(point,center):return {}
 return {"point":point,"fraction":fraction}
