extends RefCounted
const WeaponActions = preload("res://player_weapon_actions.gd")
const Hurt = preload("res://enemy_hurtbox.gd")
const MAX_AGE:=250
var states: Dictionary={}
signal attack_requested(peer: int, origin: Vector3, now: int)
var next_send: int=0
var armed:=true
var local_aim:=Vector3.ZERO
var marker: MeshInstance3D
static func ground_offset(camera: Camera3D,screen: Vector2,position: Vector3) -> Vector2:
 var hit=Plane(Vector3.UP,position.y).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
 if hit==null:return Vector2.ZERO
 var offset: Vector3=hit-position
 return Vector2(offset.x,offset.z)
static func ground_direction(camera: Camera3D,screen: Vector2,position: Vector3) -> Vector2:
 var offset:=ground_offset(camera,screen,position)
 return offset.normalized() if offset.length_squared()>.01 else Vector2.ZERO
func receive(game: Node,id: int,aim: Vector2,held: bool,now: int) -> void:
 var length:=aim.length()
 if not game.players.has(id) or not aim.is_finite() or length<.1 or length>22.001:return
 var p: Dictionary=game.players[id]
 if not game.Life.alive(p):states.erase(id);return
 aim/=length
 states[id]={"aim":Vector3(aim.x,0,aim.y),"held":held,"at":now,
  "cursor_distance":length-2.0 if length>=1.999 else -1.0}
 p.mouse_aim=true;p.aim_direction=states[id].aim;p.facing=states[id].aim
func clear(game: Node) -> void:
 states.clear();armed=false;local_aim=Vector3.ZERO
 for p in game.players.values():p.mouse_aim=false
 if is_instance_valid(marker):marker.hide()
func release(game: Node) -> void:
 armed=false
 var id: int=game.multiplayer.get_unique_id()
 if states.has(id):states[id].held=false
 if game.network_session.role()=="Guest" and game.network_session.transport()!=null and id!=game.HOST and game.multiplayer.get_peers().has(game.HOST) and game.players.has(id):
  var aim: Vector3=game.players[id].get("facing",Vector3.FORWARD) if local_aim.is_zero_approx() else local_aim
  game.submit_combat.rpc_id(game.HOST,Vector2(aim.x,aim.z),false)
func frame(game: Node) -> void:
 if DisplayServer.get_name()=="headless":return
 var id: int=game.multiplayer.get_unique_id();var p: Dictionary=game.players.get(id,{})
 var focused: bool=DisplayServer.window_is_focused()
 var blocked: bool=not game.Life.alive(p) or game.ui.is_overlay_open() or game.settings_dialog.visible or not focused
 if blocked:armed=false
 elif not Input.is_action_pressed("attack"):armed=true
 var aim:=Vector2(local_aim.x,local_aim.z)
 var distance:=-1.0
 if not blocked:
  var offset:=ground_offset(game.stage.camera,game.get_viewport().get_mouse_position(),game.stage.WILD_OFFSET+p.get("pos",Vector3.ZERO))
  if offset.length_squared()>.01:
   aim=offset.normalized();distance=minf(offset.length(),20.0)
 if aim.is_zero_approx():
  var facing: Vector3=p.get("facing",Vector3.FORWARD)
  aim=Vector2(facing.x,facing.z)
 if not blocked:
  local_aim=Vector3(aim.x,0,aim.y)
 var held: bool=not blocked and armed and Input.is_action_pressed("attack")
 var hovered: Control=game.get_viewport().gui_get_hovered_control()
 if hovered is BaseButton:held=false
 var now:=preload("res://combat_clock.gd").now()
 # Unit aim remains valid for fallback inputs. Live cursor input carries distance in its magnitude.
 var cursor_aim:=aim*(distance+2.0) if distance>=0.0 else aim
 if game.multiplayer.is_server():
  receive(game,id,cursor_aim,held,now)
 elif game.network_session.role()=="Guest" and now>=next_send:
  next_send=now+50;game.submit_combat.rpc_id(game.HOST,cursor_aim,held)
  if not blocked:p.mouse_aim=true;p.facing=Vector3(aim.x,0,aim.y)
 draw_indicator(game,p,aim,not blocked and bool(game.app_settings.values.aim_indicator))
func tick(game: Node,now: int) -> void:
 for id in states.keys():
  if not game.players.has(id):states.erase(id);continue
  var p: Dictionary=game.players[id];var state: Dictionary=states[id]
  if not game.Life.alive(p) or now-int(state.at)>MAX_AGE:state.held=false;continue
  p.facing=state.aim
  if state.held and not (id==game.HOST and (game.ui.is_overlay_open() or game.settings_dialog.visible)):attack_requested.emit(id,Vector3(p.pos),preload("res://combat_clock.gd").now())
func draw_indicator(game: Node,p: Dictionary,aim: Vector2,shown: bool) -> void:
 if not is_instance_valid(marker):
  marker=MeshInstance3D.new();game.stage.add_child(marker)
  var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
  for vertex in [Vector3(-.14,.05,.72),Vector3(0,.05,1.0),Vector3(.14,.05,.72)]:mesh.surface_add_vertex(vertex)
  mesh.surface_end();marker.mesh=mesh
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("#ddcf90");material.cull_mode=BaseMaterial3D.CULL_DISABLED;marker.material_override=material;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 marker.visible=shown;marker.position=game.stage.WILD_OFFSET+p.get("pos",Vector3.ZERO);marker.rotation.y=atan2(aim.x,aim.y)
static func contact(game: Node,origin: Vector3,aim: Vector3,point: Vector3,stats: Dictionary,form: String,target: int=-2) -> bool:
 if target>=-1:return preload("res://weapon_contact.gd").accepts(game,target,origin,aim,form,stats)
 return game.AttackGeometry.accepts("line" if game.WeaponMotion.profile(form).delivery=="line" else "sweep",origin,aim,point,float(stats.reach),form,true)
static func projectile_path(field: RefCounted, origin: Vector3, direction: Vector3, profile: Dictionary, reach: float, radius: float = -1.0) -> Dictionary:
 if radius < 0.0:
  radius = float(profile.projectile_radius)
 var side := direction.cross(Vector3.UP).normalized()
 var muzzle := origin + direction * float(profile.muzzle_forward) + side * float(profile.muzzle_side)
 var blocked: float = field.projectile_block_fraction(origin, muzzle, radius)
 if blocked != INF:
  return {"from":origin, "to":origin.lerp(muzzle, blocked), "muzzle_blocked":true}
 return {"from":muzzle, "to":field.projectile_endpoint(muzzle, origin + direction * reach, radius), "muzzle_blocked":false}

static func can_shoot(field: RefCounted, origin: Vector3, center: Vector3, body_radius: float, profile: Dictionary, reach: float) -> bool:
 var path := projectile_path(field, origin, origin.direction_to(center), profile, reach)
 return not Hurt.projectile_contact(field, path.from, path.to, center, body_radius, float(profile.projectile_radius)).is_empty()
