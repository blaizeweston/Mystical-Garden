extends Node
# Cosmetic only: local transforms/shaders, no gameplay RNG, saves or network events.
const Layout=preload("res://garden_layout.gd")
const Catalog=preload("res://garden_interaction_catalog.gd")
const Service=preload("res://garden_interaction_service.gd")
const MOTH_LIMIT:=8
var game: Node
var root: Node3D
var colonies: Dictionary={}
var elapsed:=0.0
func _ready() -> void:
 root=Node3D.new();root.name="GardenAmbientLife";game.stage.add_child(root)
func build_colony(zone: Dictionary) -> MultiMeshInstance3D:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1.0,1.0]:
  for lobe in 2:
   var center:=Vector3(side*.018,0,-.025+lobe*.065)
   for segment in 12:
    var a:=segment*PI/12;var b:=(segment+1)*PI/12
    var first:=center+Vector3(side*sin(a)*(.15-lobe*.035),0,cos(a)*(.095-lobe*.025))
    var second:=center+Vector3(side*sin(b)*(.15-lobe*.035),0,cos(b)*(.095-lobe*.025))
    for vertex in [center,first,second]:
     surface.set_normal(Vector3.UP);surface.set_uv(Vector2(vertex.x*3+.5,vertex.z*4+.5));surface.add_vertex(vertex)
 var mesh:=surface.commit();var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.use_custom_data=true;instances.mesh=mesh;instances.instance_count=clampi(int(zone.get("ambience",{}).get("count",MOTH_LIMIT)),1,MOTH_LIMIT)
 instances.custom_aabb=AABB(Vector3(-2.4,-.5,-2.4),Vector3(4.8,1.3,4.8))
 for index in instances.instance_count:
  instances.set_instance_transform(index,Transform3D.IDENTITY)
  instances.set_instance_custom_data(index,Color(fmod(index*.381966,1.0),index/float(instances.instance_count),0,1))
 var batch:=MultiMeshInstance3D.new();batch.name="SpringMoths";root.add_child(batch);batch.position=zone.water.position+Vector3.UP*.85;batch.multimesh=instances
 batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/garden_moth.gdshader");batch.material_override=material
 return batch
func _process(delta: float) -> void:
 elapsed+=delta
 if elapsed<.15:return
 elapsed=0
 var motion: bool=game.app_settings.values.get("ambient_motion",true)
 preload("res://heart_growth_visuals.gd").motion(game.stage,motion,game.players.get(game.local_player_id(),{}).get("pos",Vector3(10000,0,0)))
 var player: Dictionary=game.players.get(game.local_player_id(),{})
 var projection: Dictionary=Service.projection(game,game.local_player_id());var available: Array=projection.get("available",[])
 var zones: Array=Catalog.ZONES.duplicate()
 if preload("res://garden_return_service.gd").known(projection.get("returns",{}),"lantern_homecoming"):
  zones.append({"id":"return_moths","water":{"position":Catalog.point("heart_root_scar").position},"ambience":{"requires_point":"heart_root_scar","range":9.0,"count":6}})
 for colony in colonies.values():colony.hide()
 for zone in zones:
  if not zone.has("water") or not zone.has("ambience"):continue
  var visible: bool=not game.stage.get_meta("garden_growth_hidden_zones",[]).has(zone.id) and motion and not player.get("wild",false) and available.has(zone.ambience.requires_point) and game.stage.get_meta("garden_growth_camera",{}).get("target",player.get("pos",Vector3.INF)).distance_to(zone.water.position)<float(zone.ambience.range)
  if visible and not colonies.has(zone.id):colonies[zone.id]=build_colony(zone)
  if colonies.has(zone.id):colonies[zone.id].visible=visible
 if not is_instance_valid(game.stage.garden_edge):return
 var models: Array=game.stage.garden_edge.find_children("*","GeometryInstance3D",true,false)
 for model in models:
  if model is GeometryInstance3D and model.get_meta("garden_motion",false) and model.material_override is ShaderMaterial:
   model.material_override.set_shader_parameter("motion_enabled",1.0 if motion else 0.0)
func _exit_tree() -> void:
 if is_instance_valid(root):root.queue_free()
