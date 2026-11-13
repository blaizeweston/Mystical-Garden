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
func text_at(text: String,at: Vector3,color: Color,id: int,ability: bool=false,height: float=-1.0) -> void:
 if labels.size()>=MAX_LABELS:var old: Dictionary=labels.pop_front();old.node.queue_free()
 var label:=Label3D.new();add_child(label);label.text=text;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size=42 if ability else 64;label.pixel_size=.008;label.outline_size=12;label.outline_modulate=Color("#10171e");label.modulate=color
 label.no_depth_test=true;label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var offset:=Vector3(((id%5)-2)*.13,height if height>=0.0 else (2.65 if not ability else 2.35),0)
 label.position=stage.WILD_OFFSET+at+offset
 labels.append({"node":label,"start":label.position,"color":color,"age":0.0,"life":.85 if not ability else 1.0})
func confirmed(event: Dictionary,at: Vector3) -> void:
 var amount:=int(event.get("amount",0))
 if event.shape=="block":
  text_at("BLOCK",at,Color("#f1d989"),int(event.id),true);return
 if amount<=0:return
 if event.shape=="heal":
  text_at("+%d"%amount,at,Color(event.color),int(event.id),false,3.15)
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
 flash(root,tint)
func flash(root: Node3D,tint: Color) -> void:
 var key:=root.get_instance_id()
 if flashes.has(key):flashes[key].age=0.0;return
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("tint",tint);material.set_shader_parameter("strength",1.0)
 var meshes: Array=[]
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  meshes.append({"node":mesh,"previous":mesh.material_overlay});mesh.material_overlay=material
 flashes[key]={"age":0.0,"material":material,"meshes":meshes}
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
 for key in flashes.keys():
  var entry: Dictionary=flashes[key];entry.age+=delta
  if entry.age>=.16:restore(key)
  else:entry.material.set_shader_parameter("strength",1.0-float(entry.age)/.16)
func _exit_tree() -> void:
 clear()
