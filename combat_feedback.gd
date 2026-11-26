extends Node3D
# Cosmetic only: confirmed host events drive text/flashes, never HP differences.
const MAX_LABELS:=40
var labels: Array=[]
var flashes: Dictionary={}
var stage: Node3D
var shader: Shader
var observer:=Vector3.ZERO
var sight:=6.8
func _ready() -> void:
 shader=Shader.new()
 shader.code="shader_type spatial; render_mode unshaded, blend_add, depth_draw_never; uniform float strength=0.0; uniform vec4 tint:source_color=vec4(1.0); void fragment(){ALBEDO=tint.rgb; ALPHA=strength*0.6;}"
static func family(mode: String) -> String:
 if mode in ["guard","front_guard","counter_guard","bastion","ward","aegis","rally"]:return "guard"
 if mode in ["heal","mend","renew","sanctuary","growth","tide","tide_pool","siphon","bloodmoon"]:return "restore"
 if mode in ["charge","dash","evade","veil","shadowstep","blink","windstep","reap","harvest"]:return "travel"
 if mode in ["bind","strangle","snare","snare_field","root","lure","decoy"]:return "control"
 if mode in ["salvo","volley","judgement","lance","shot"]:return "bolt"
 return "burst"
func text_at(text: String,at: Vector3,color: Color,_id: int,ability: bool=false,height: float=-1.0) -> void:
 if labels.size()>=MAX_LABELS:var old: Dictionary=labels.pop_front();old.node.queue_free()
 var label:=Label3D.new();add_child(label);label.text=text;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size=42 if ability else 64;label.pixel_size=.008;label.outline_size=12;label.outline_modulate=Color("#10171e");label.modulate=color
 label.no_depth_test=true;label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var used:=0
 for entry in labels:
  if entry.age<.48 and entry.at.distance_squared_to(at)<1.7:
   used|=1<<int(entry.lane)
 var lane:=0
 while lane<5 and used&(1<<lane):lane+=1
 var camera:=get_viewport().get_camera_3d()
 var right:=camera.global_basis.x if camera!=null else Vector3.RIGHT
 var offset:=right*float([0,-1,1,0,-1,1][lane])*.46
 offset.y+=(height if height>=0.0 else (2.55 if not ability else 2.17))+.30*float(lane%2)+.26*floori(lane/3.)
 label.position=stage.WILD_OFFSET+at+offset
 labels.append({"at":at,"lane":lane,"node":label,"start":label.position,"color":color,"age":0.0,"life":.85 if not ability else 1.0})
func proc_caption(caption: String,at: Vector3,color: Color,id: int,detailed: bool, grouping_distance_sq:=2.25) -> void:
 if not detailed:
  for item in labels:
   if item.get("caption","")==caption and item.age<.38 and at.distance_squared_to(item.at)<grouping_distance_sq:
    item.count+=1
    item.node.text="%s ×%d"%[caption,item.count]
    return
 text_at(caption,at,color,id,true)
 labels.back().caption=caption
 labels.back().count=1

const RUPTURE_LABEL_RADIUS := 6.5
func recent_rupture_near(at: Vector3) -> bool:
 for item in labels:
  if item.has("rupture_at") and item.age<0.20 and at.distance_squared_to(item.rupture_at)<=RUPTURE_LABEL_RADIUS*RUPTURE_LABEL_RADIUS:return true
 return false
func confirmed(event: Dictionary,at: Vector3,strength:=1.0) -> void:
 var amount:=int(event.get("amount",0))
 if event.shape=="block":
  text_at("BLOCK",at,Color("#f1d989"),int(event.id),true);return
 if amount<=0:return
 if event.shape=="heal":
  text_at("+%d"%amount,at,Color(event.color).lerp(Color("#e7fff0"),.72),int(event.id),false,3.15)
  labels.back().node.render_priority=4
  labels.back().node.outline_render_priority=3
  return
 var hurt: bool=event.shape=="hurt"
 var tint:=Color("#ff957d") if hurt else Color("#fff2ca")
 text_at(("−" if hurt else "")+str(amount),at,tint,int(event.id))
 var root: Node3D
 var target:=int(event.get("target_id",-2))
 if hurt:root=stage.avatars.get(target)
 elif target==-1:root=stage.foe
 elif target>=0 and target<stage.support_models.size():root=stage.support_models[target]
 if not is_instance_valid(root) or not root.visible or root.position.distance_to(stage.WILD_OFFSET+at)>2.5:return
 if strength>0:flash(root,tint,strength)
func flash(root: Node3D,tint: Color,strength:=1.0) -> void:
 var key:=root.get_instance_id()
 if flashes.has(key):
  flashes[key].age=0.0;flashes[key].strength=strength;flashes[key].material.set_shader_parameter("strength",strength);return
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("tint",tint);material.set_shader_parameter("strength",strength)
 var meshes: Array=[]
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  meshes.append({"node":mesh,"previous":mesh.material_overlay});mesh.material_overlay=material
 flashes[key]={"age":0.0,"strength":strength,"material":material,"meshes":meshes}
func clear() -> void:
 for item in labels:
  if is_instance_valid(item.node):item.node.queue_free()
 labels.clear()
 for key in flashes.keys():restore(key)
func restore(key: int) -> void:
 var entry: Dictionary=flashes[key]
 for mesh in entry.meshes:
  if is_instance_valid(mesh.node) and mesh.node.material_overlay==entry.material:mesh.node.material_overlay=mesh.previous
 flashes.erase(key)
func step(delta: float) -> void:
 for item in labels.duplicate():
  item.age+=delta;var t:=clampf(float(item.age)/float(item.life),0,1)
  if t>=1: item.node.queue_free();labels.erase(item);continue
  item.node.position=item.start+Vector3.UP*(.65*(1-pow(1-t,2)))
  var ground: Vector3=item.start-stage.WILD_OFFSET;ground.y=0
  item.node.visible=ground.distance_to(observer)<=sight
  item.node.scale=Vector3.ONE*(1.0+.18*sin(minf(1,t*5)*PI))
  var color: Color=item.color;color.a=1-smoothstep(.55,1,t);item.node.modulate=color
  item.node.outline_modulate.a=color.a
 for key in flashes.keys():
  var entry: Dictionary=flashes[key];entry.age+=delta
  if entry.age>=.16:restore(key)
  else:entry.material.set_shader_parameter("strength",entry.strength*(1.0-float(entry.age)/.16))
func _exit_tree() -> void:
 clear()
