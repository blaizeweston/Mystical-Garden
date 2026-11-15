extends RefCounted
const MAX_AGE:=250
var states: Dictionary={}
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
 if game.session=="Guest" and game.online_peer!=null and id!=game.HOST and game.multiplayer.get_peers().has(game.HOST) and game.players.has(id):
  var aim: Vector3=game.players[id].get("facing",Vector3.FORWARD) if local_aim.is_zero_approx() else local_aim
  game.submit_combat.rpc_id(game.HOST,Vector2(aim.x,aim.z),false)
func frame(game: Node) -> void:
 if DisplayServer.get_name()=="headless":return
 var id: int=game.multiplayer.get_unique_id();var p: Dictionary=game.players.get(id,{})
 var focused: bool=DisplayServer.window_is_focused()
 var blocked: bool=not game.Life.alive(p) or game.overlay.visible or game.settings_dialog.visible or not focused
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
 var now:=Time.get_ticks_msec()
 # Unit aim remains valid for fallback inputs. Live cursor input carries distance in its magnitude.
 var cursor_aim:=aim*(distance+2.0) if distance>=0.0 else aim
 if game.multiplayer.is_server():
  receive(game,id,cursor_aim,held,now)
 elif game.session=="Guest" and now>=next_send:
  next_send=now+50;game.submit_combat.rpc_id(game.HOST,cursor_aim,held)
  if not blocked:p.mouse_aim=true;p.facing=Vector3(aim.x,0,aim.y)
 draw_indicator(game,p,aim,not blocked and bool(game.app_settings.values.aim_indicator))
func tick(game: Node,now: int) -> void:
 for id in states.keys():
  if not game.players.has(id):states.erase(id);continue
  var p: Dictionary=game.players[id];var state: Dictionary=states[id]
  if not game.Life.alive(p) or now-int(state.at)>MAX_AGE:state.held=false;continue
  p.facing=state.aim
  if state.held and not (id==game.HOST and (game.overlay.visible or game.settings_dialog.visible)):game.strike_enemy(id,p,p.pos)
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
static func projectile_path(field: RefCounted, origin: Vector3, direction: Vector3, profile: Dictionary, reach: float) -> Dictionary:
 var side:=direction.cross(Vector3.UP).normalized()
 var muzzle: Vector3=field.dash(origin,origin+direction*float(profile.muzzle_forward)+side*float(profile.muzzle_side))
 return {"from":muzzle,"to":field.dash(muzzle,origin+direction*reach)}
static func queue_attack(game: Node,id: int,p: Dictionary,pos: Vector3,stats: Dictionary,now: int,form: String,duration: int,lock_target: int=-2) -> void:
 var direction: Vector3=(p.get("aim_direction",p.facing) if p.get("mouse_aim",false) else p.facing).normalized();p.facing=direction
 p.attack_direction=direction
 var description:=preload("res://weapon_contact.gd").describe(form,stats)
 p.attack_clip=description.clip;p.attack_delivery=description.pattern;p.attack_span=description.span
 var end: Vector3=pos+direction*float(stats.reach)
 var profile: Dictionary=game.WeaponMotion.profile(form)
 var release:=now+roundi(duration*float(profile.release))
 if game.WeaponMotion.is_projectile(form):
  var path:=projectile_path(game.battlefield,pos,direction,profile,float(stats.reach))
  var muzzle: Vector3=path.from
  end=path.to
  var flight:=maxi(30,roundi(muzzle.distance_to(end)/float(profile.speed)*1000))
  game.projectile_queue.append({"direction":direction,"mouse_ray":true,"player":id,"epoch":game.combat_epoch,"release":release,"due":release+flight,"emitted":false,"projectile":true,"form":form,"origin":muzzle,"aim":end,"previous":muzzle,"stats":stats.duplicate(true),"hits":[],"remaining":int(stats.targets)})
  if p.get("mouse_aim",false):
   var combo:=int(p.get("attack_combo",0))
   p.ranged_windup={"combo":combo,"release":release}
   game.projectile_queue.back().aim_combo=combo
  if lock_target>=-1:
   game.projectile_queue.back().locked_target=lock_target;game.projectile_queue.back().locked_token=token(game,lock_target)
  return
 game.emit_weapon_attack(p,pos,end,stats,now)
 game.projectile_queue.append({"melee_shape":true,"player":id,"epoch":game.combat_epoch,"release":release,"due":release,"emitted":true,"projectile":false,"form":form,"origin":pos,"aim":end,"stats":stats.duplicate(true)})
static func aim_is_live(player: Dictionary,now: int) -> bool:
 var windup: Dictionary=player.get("ranged_windup",{})
 return player.get("mouse_aim",false) and int(windup.get("combo",-1))==int(player.get("attack_combo",0)) and now<int(windup.get("release",0))

static func attack_direction(player: Dictionary,now: int) -> Vector3:
 var committed: Vector3=player.get("attack_direction",player.get("facing",Vector3.FORWARD))
 return player.get("aim_direction",committed) if aim_is_live(player,now) else committed

static func launch(game: Node,shot: Dictionary) -> void:
 var caster: Dictionary=game.players[shot.player]
 var direction: Vector3=shot.direction
 # Aim is sampled once on the release tick. Flight and collision share this path.
 if shot.has("aim_combo") and caster.get("mouse_aim",false):
  direction=caster.get("aim_direction",direction)
  if int(shot.aim_combo)==int(caster.get("attack_combo",0)):
   caster.attack_direction=direction
 var profile: Dictionary=game.WeaponMotion.profile(str(shot.form))
 var start: Vector3=caster.pos
 var path:=projectile_path(game.battlefield,start,direction,profile,float(shot.stats.reach))
 shot.emitted=true
 shot.direction=direction
 shot.launch_position=start
 shot.origin=path.from
 shot.previous=path.from
 shot.aim=path.to
 shot.due=int(shot.release)+maxi(30,roundi(Vector3(shot.origin).distance_to(shot.aim)/float(profile.speed)*1000))

static func volley(game: Node, shot: Dictionary, field: RefCounted = null) -> Array:
 var profile: Dictionary=game.WeaponMotion.profile(str(shot.form))
 var count:=int(profile.get("projectiles",1))
 if count==1:return [shot]
 count=mini(5,count+maxi(0,int(shot.stats.targets)-2))
 # The petals share a set of hit tokens, so overlapping rays cannot hit a foe twice.
 var shots: Array=[shot]
 if field==null:field=game.battlefield
 var spread:=float(profile.spread)
 var center: Vector3=shot.direction
 var muzzle: Vector3=shot.origin
 for index in range(1,count):
  var fraction: float=ceilf(index*.5)/ceilf((count-1)*.5)
  var direction:=center.rotated(Vector3.UP,spread*fraction*(1.0 if index%2==1 else -1.0))
  var end: Vector3=field.dash(muzzle,Vector3(shot.launch_position)+direction*float(shot.stats.reach))
  var petal:=shot.duplicate()
  petal.aim=end
  petal.due=int(shot.release)+maxi(30,roundi(muzzle.distance_to(end)/float(profile.speed)*1000))
  shots.append(petal)
 for petal in shots:
  petal.remaining=1
 return shots

static func token(game: Node,target: int) -> String:
 return "leader" if target==-1 else str(game.scouts[target].get("spawn_token",target))
static func ray_tick(game: Node,shot: Dictionary,now: int) -> bool:
 if now<int(shot.release):return false
 var t:=clampf((now-int(shot.release))/float(maxi(1,int(shot.due)-int(shot.release))),0,1)
 var at: Vector3=Vector3(shot.origin).lerp(shot.aim,t);var previous: Vector3=shot.previous
 var contacts: Array=[]
 for target in range(-1,game.scouts.size()):
  if not game.Traits.valid_target(game,target) or shot.hits.has(token(game,target)):continue
  if target==int(shot.get("locked_target",-3)) and token(game,target)!=str(shot.get("locked_token","")):continue
  var collision: Dictionary=preload("res://enemy_hurtbox.gd").sweep(game,target,previous,at,float(game.WeaponMotion.profile(str(shot.form)).projectile_radius))
  if not collision.is_empty():contacts.append({"id":target,"distance":float(collision.fraction),"point":collision.point})
 contacts.sort_custom(func(a,b):return a.distance<b.distance)
 for entry in contacts:
  if int(shot.remaining)<=0:break
  var target: int=entry.id;var point: Vector3=entry.point
  if not game.Traits.valid_target(game,target) or shot.hits.has(token(game,target)):continue
  shot.visual_stop=point
  if not shot.hits.is_empty() and str(shot.form)!="fan":preload("res://combat_status.gd").proc(game,"pierce",previous,point,target)
  shot.hits.append(token(game,target));shot.remaining-=1
  var hit: Dictionary=shot.stats.duplicate(true);hit.shot_distance=Vector3(shot.get("launch_position",shot.origin)).distance_to(game.enemy_position(target))
  game.apply_weapon_hit(game.players[int(shot.player)],target,shot.origin,hit,now)
  if hit.has("cr02_action"):
   preload("res://combat_action_events.gd").contact(game,hit,target,now,false,point,(Vector3(shot.aim)-Vector3(shot.origin)).normalized())
  if shot.stats.pattern in ["chain","splash"]:
   var budget:=maxi(0,int(shot.stats.targets)-shot.hits.size()) if str(shot.form)=="fan" else int(shot.remaining)
   shot.remaining=preload("res://weapon_contact.gd").secondary(game,game.players[int(shot.player)],shot.stats,point,shot.hits,budget)
   shot.remaining=0
  if game.encounter_cleared() and game.pending_finale_at==0:game.finish_combat(int(shot.player),point)
 shot.previous=at
 return now>=int(shot.due) or int(shot.remaining)<=0
