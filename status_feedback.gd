extends Node3D
# Cosmetic host events only; icons follow rendered actors, not unsmoothed packets.
const Catalog=preload("res://combat_status.gd")
var stage: Node3D
var active: Dictionary={}
var ended: Dictionary={}
var observer:=Vector3.ZERO
var sight:=6.8
func consume(event: Dictionary) -> void:
 if event.kind=="status_end":
  var id:=int(event.shape);ended[id]=true
  if active.has(id):active[id].node.queue_free();active.erase(id)
  while ended.size()>2048:ended.erase(ended.keys()[0])
  return
 if event.kind!="status" or active.has(event.id) or ended.has(event.id):return
 var root:=Node3D.new();add_child(root)
 var label:=Label3D.new();root.add_child(label);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=32;label.pixel_size=.007;label.outline_size=10;label.no_depth_test=true;label.text=Catalog.LABELS.get(event.shape,event.shape)
 var tint:=Color(event.color);label.modulate=tint
 var enemy: bool=event.form=="enemy"
 if enemy:
  var icon:=MeshInstance3D.new();root.add_child(icon);var mesh:=ImmediateMesh.new();icon.mesh=mesh
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.no_depth_test=true;material.albedo_color=tint;icon.material_override=material;icon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
  var count:=4 if event.shape=="marked" else 6 if event.shape in ["brittle","core_strike_mark"] else 24
  for i in count:
   var a:=i*TAU/count;var b:=(i+1)*TAU/count
   for vertex in [Vector3(cos(a),sin(a),0)*.17,Vector3(cos(b),sin(b),0)*.17,Vector3(cos(a),sin(a),0)*.12,Vector3(cos(b),sin(b),0)*.17,Vector3(cos(b),sin(b),0)*.12,Vector3(cos(a),sin(a),0)*.12]:mesh.surface_add_vertex(vertex)
  for vertex in [Vector3(-.045,0,0),Vector3(0,.07,0),Vector3(.045,0,0),Vector3(-.045,0,0),Vector3(.045,0,0),Vector3(0,-.07,0)]:mesh.surface_add_vertex(vertex)
  mesh.surface_end();label.position=Vector3(.65,0,0)
  if event.shape=="brittle":label.text="Brittle %d/3"%int(event.reach)
 if event.shape in ["echo","grave"]:label.text=Catalog.LABELS[event.shape]+" %d/3"%int(event.reach)
 active[event.id]={"node":root,"label":label,"event":event,"age":float(event.get("age",0)),"enemy":enemy}
func step(delta: float) -> void:
 var slots: Dictionary={}
 for id in active.keys():
  var item: Dictionary=active[id];item.age+=delta;var event: Dictionary=item.event
  var target: Node3D
  if not item.enemy:target=stage.avatars.get(int(event.combo))
  elif int(event.combo)==-1:target=stage.foe
  elif int(event.combo)>=0 and int(event.combo)<stage.support_models.size():target=stage.support_models[int(event.combo)]
  if item.age>=float(event.duration):item.node.queue_free();active.erase(id);continue
  # Reliable status events and actor snapshots may arrive in either order.
  if not is_instance_valid(target):item.node.hide();continue
  var identity: String=event.form+":"+str(event.combo);var slot:=int(slots.get(identity,0));slots[identity]=slot+1
  var at: Vector3=target.position-stage.WILD_OFFSET;at.y=0
  var in_view: bool=target.visible and at.distance_to(observer)<=sight
  if in_view and not item.has("first_seen"):item.first_seen=item.age
  var visible_age: float=item.age-float(item.get("first_seen",item.age))
  item.node.visible=in_view and (item.enemy or visible_age<1.35)
  item.node.position=target.position+Vector3(0.0,float(event.height)+slot*(.48 if item.enemy else .30),0)
  item.label.visible=visible_age<1.35 or event.shape=="brittle"
  var text_color:=Color(event.color);text_color.a=1.0 if event.shape=="brittle" else 1-smoothstep(.95,1.35,visible_age);item.label.modulate=text_color
  item.node.scale=Vector3.ONE*(1+.07*sin(item.age*5))
func clear() -> void:
 for item in active.values():item.node.queue_free()
 active.clear();ended.clear()
