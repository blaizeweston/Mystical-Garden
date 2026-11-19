extends Node

const Participation = preload("res://expedition_participation.gd")
# Permanent presentation of committed discoveries. No loot, timers or gameplay RNG.
const Service=preload("res://garden_return_service.gd")
const Places=preload("res://garden_interaction_catalog.gd")
var game: Node
var traces: Dictionary={}
var heart: MeshInstance3D
var elapsed:=0.0
var context:=""
var visible_discoveries: Dictionary={}
var baseline:=false
func _ready() -> void:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for strand in 5:
  var points: Array[Vector3]=[]
  for index in 33:
   var t:=index/32.0;var angle:=strand*TAU/5+t*1.7;var radius:=.7-t*.28
   points.append(Vector3(cos(angle)*radius,.05+sin(t*PI)*.16,sin(angle)*radius))
  game.stage.root_tube(surface,points,.025,.003)
 heart=MeshInstance3D.new();heart.name="ListeningHeartRoots";game.stage.add_child(heart);heart.mesh=surface.commit();heart.hide()
 var material:=StandardMaterial3D.new();material.albedo_color=Color("#728466");material.emission_enabled=true;material.emission=Color("#7c9b68");material.roughness=.9;heart.material_override=material
func build(definition: Dictionary) -> Node3D:
 var root:=Node3D.new();root.name=str(definition.id);game.stage.add_child(root);root.position=Places.point(str(definition.point)).position
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for sprout in 9:
  var angle:=sprout*2.4;var radius:=.35+sin(sprout*1.7)*.16;var at:=Vector3(cos(angle)*radius,.04,sin(angle)*radius)
  var points: Array[Vector3]=[]
  for index in 17:
   var t:=index/16.0;points.append(at*t+Vector3(sin(t*PI)*.10,.03+sin(t*PI*.7)*.35,0))
  game.stage.root_tube(surface,points,.024,.004)
  var bloom:=MeshInstance3D.new();root.add_child(bloom);var shape:=SphereMesh.new();shape.radius=.065;shape.height=.11;shape.radial_segments=16;shape.rings=8;bloom.mesh=shape;bloom.position=points[-1]
  var glow:=StandardMaterial3D.new();glow.albedo_color=Color(definition.color);glow.emission_enabled=true;glow.emission=Color(definition.color);glow.emission_energy_multiplier=.45;glow.roughness=.7;bloom.material_override=glow
 var stems:=MeshInstance3D.new();root.add_child(stems);stems.mesh=surface.commit();var bark:=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/root_bark.gdshader");stems.material_override=bark
 return root
func _process(delta: float) -> void:
 elapsed+=delta
 if elapsed<.1:return
 elapsed=0
 var id: int=game.local_player_id();var player: Dictionary=game.players.get(id,{})
 var data:=Service.projection(game,id);var entries: Array=data.get("entries",[])
 var next_context:=str([game.network_session.role(),id,get_parent().projection_context])
 if next_context!=context:context=next_context;visible_discoveries.clear();baseline=false
 for entry in entries:
  if baseline and not visible_discoveries.has(entry.id):preload("res://diagnostic_journal.gd").event("garden","return_discovery_received",{"discovery":entry.id,"point":entry.point,"source":"host_world" if game.multiplayer.is_server() else "host_snapshot"})
  visible_discoveries[entry.id]=true
 if data.get("version",0)==1:baseline=true
 var growth:=preload("res://garden_growth_service.gd").projection(game,id)
 var scenes=get_parent().get_node("GrowthScenes")
 for definition in Service.Catalog.DEFINITIONS:
  var known: bool=Service.known(data,str(definition.id))
  if (game.stage.experimental_garden != null) and not get_parent().points[definition.point].visible:known=false
  if known and not traces.has(definition.id):traces[definition.id]=build(definition)
  if traces.has(definition.id):
   var amount:=1.0
   for pending in growth.get("pending",[]):
    if pending.get("discovery","")!=definition.id:continue
    amount=scenes.discovery_progress(str(definition.id))
   traces[definition.id].visible=known and not Participation.is_wild(player) and amount>.001
   traces[definition.id].scale=Vector3.ONE*maxf(.001,smoothstep(0,1,amount))
 var resonance: bool=Service.known(data,"lantern_homecoming")
 heart.visible=resonance and not Participation.is_wild(player)
 heart.material_override.emission_energy_multiplier=.18+.1*sin(Time.get_ticks_msec()/850.0-.8) if game.app_settings.values.get("ambient_motion",true) else .2
 for group in game.stage.garden_edge.get_children():
  if not group.has_meta("garden_water_position"):continue
  var spring: bool=group.get_meta("garden_water_position").distance_to(Vector3(6.6,0,-.15))<.1
  for model in group.find_children("*","MeshInstance3D",true,false):
   if model is MeshInstance3D and model.get_meta("garden_pond",false) and model.material_override is ShaderMaterial:model.material_override.set_shader_parameter("resonance",1.0 if resonance and spring else 0.0)
func _exit_tree() -> void:
 for model in traces.values():
  if is_instance_valid(model):model.queue_free()
 if is_instance_valid(heart):heart.queue_free()
