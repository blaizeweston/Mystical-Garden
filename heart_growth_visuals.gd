extends RefCounted
## Cosmetic growth derives from completed, enabled technologies, not the finale.
const Catalog=preload("res://heart_catalog.gd")
static func count(unlocked: Array) -> int:
 var known: Dictionary={}
 for node in Catalog.DEFINITIONS:
  if node.id!="heart" and Catalog.enabled(node.id) and unlocked.has(node.id):known[node.id]=true
 return known.size()
static func trunk_height(completed: float) -> float:return .85+minf(8.8,.9+completed*.25) if completed>=3 else 0.0
static func crown_width(completed: float) -> float:return .55+minf(completed,48)*.065
static func height(completed: float) -> float:return trunk_height(completed) if completed>=3 else 1.4+completed*.18
static func counts(event: Dictionary,pending: Array,unlocked: Array) -> Vector2i:
 var total:=count(unlocked)
 if event.has("from_growth") and event.has("to_growth"):return Vector2i(clampi(int(event.from_growth),0,total),clampi(int(event.to_growth),0,total))
 # Old queued scenes infer their place from the remaining researched unlocks.
 var after:=total
 for value in pending:
  if int(value.get("sequence",0))>int(event.get("sequence",0)) and count([value.get("technology","")])>0:after-=1
 return Vector2i(maxi(0,after-int(count([event.get("technology","")])>0)),maxi(0,after))
static func hold(stage: Node3D,value: int) -> void:
 stage.set_meta("garden_growth_heart",{"from":value,"to":value,"amount":1.0})
 sync(stage,{"unlocked":stage.heart_unlocked})
static func animate(stage: Node3D,range_value: Vector2i,amount: float) -> void:
 stage.set_meta("garden_growth_heart",{"from":range_value.x,"to":range_value.y,"amount":smoothstep(0,1,amount)})
 sync(stage,{"unlocked":stage.heart_unlocked})
static func clear(stage: Node3D) -> void:
 stage.remove_meta("garden_growth_heart");sync(stage,{"unlocked":stage.heart_unlocked})
static func sync(stage: Node3D,state: Dictionary) -> void:
 var actual:=count(state.get("unlocked",[]));var reveal: Dictionary=stage.get_meta("garden_growth_heart",{})
 var target:=clampi(int(reveal.get("to",actual)),0,actual)
 stage.set_meta("heart_visual_count",target)
 if stage.experimental_garden!=null:
  var sculpt: Node3D=stage.experimental_garden.heart
  var previous_growth:=clampi(int(reveal.get("from",target)),0,target)
  var growth_amount:=clampf(float(reveal.get("amount",1)),0,1)
  var rendered:=lerpf(previous_growth,target,growth_amount)
  sculpt.set_meta("heart_visual_count",target)
  sculpt.set_meta("rendered_growth",rendered)
  sculpt.set_research_growth(rendered)
  return
 if not is_instance_valid(stage.heart_tree):return
 if int(stage.heart_tree.get_meta("heart_visual_count",-1))!=target:
  var old: Node3D=stage.heart_tree;var shown:=old.visible;var scale_value:=old.scale
  stage.heart_tree=stage.build_heart_growth();stage.heart_tree.visible=shown;stage.heart_tree.scale=scale_value;old.free()
 var model: Node3D=stage.heart_tree
 var from:=clampi(int(reveal.get("from",target)),0,target);var amount:=clampf(float(reveal.get("amount",1)),0,1)
 var pose: Array=[from,target,amount]
 if model.get_meta("heart_visual_pose",[])==pose:return
 model.set_meta("heart_visual_pose",pose);model.set_meta("rendered_growth",lerpf(from,target,amount))
 var seed_form:=model.get_node("SeedForm") as Node3D
 var seed_amount:=1.0-smoothstep(2.0,3.0,lerpf(from,target,amount))
 seed_form.visible=seed_amount>.001
 seed_form.scale=Vector3.ONE*maxf(.001,seed_amount)
 var tree:=model.get_node_or_null("HeartTree") as Node3D
 if tree!=null:
  var ratio_y:=lerpf(trunk_height(from)/trunk_height(target),1.0,amount)
  var ratio_x:=lerpf(crown_width(from)/crown_width(target) if from>=3 else .001,1.0,amount)
  tree.visible=from>=3 or amount>.001;tree.scale=Vector3(maxf(.001,ratio_x),maxf(.001,ratio_y),maxf(.001,ratio_x))
 for branch in model.get_meta("growth_branches",[]):
  var factor:=1.0 if int(branch.get_meta("unlocked_at"))<=from else amount
  branch.visible=factor>.001;branch.scale=Vector3.ONE*maxf(.001,factor)
static func motion(stage: Node3D,enabled: bool,viewer: Vector3=Vector3(10000,0,0)) -> void:
 stage.set_meta("heart_foliage_motion",enabled)
 stage.set_meta("heart_foliage_viewer",viewer+Vector3.UP)
 if is_instance_valid(stage.heart_tree) and stage.heart_tree.has_meta("heart_foliage_material"):
  var material=stage.heart_tree.get_meta("heart_foliage_material",null)
  if material is ShaderMaterial:
   material.set_shader_parameter("motion_enabled",1.0 if enabled else 0.0)
   material.set_shader_parameter("player_world_position",viewer+Vector3.UP)
static func leaf_mesh() -> ArrayMesh:
 var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 8:
  for corner in [[i,-1],[i+1,-1],[i,1],[i,1],[i+1,-1],[i+1,1]]:
   var t: float=corner[0]/8.0;var side: float=corner[1]
   s.set_color(Color.WHITE);s.set_uv(Vector2((side+1)*.5,t));s.set_normal(Vector3.UP)
   s.add_vertex(Vector3(sin(t*PI)*.07*side,sin(t*PI)*.025,t*.30))
 return s.commit()
# Each complete group of eight samples uses one branch point.
@warning_ignore_start("integer_division")
static func leaves(parent: Node3D,points: Array[Vector3],seed_value: int,material: ShaderMaterial) -> void:
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=leaf_mesh();mm.instance_count=points.size()*8
 for i in mm.instance_count:
  var point: Vector3=points[i/8];var angle: float=(i+seed_value)*2.39996
  var basis:=Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,-.35+.18*sin(i*1.7))
  mm.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*(1.05+.3*sin(i*3.1))),point+Vector3(cos(angle),.2*sin(angle),sin(angle))*.24))
  mm.set_instance_color(i,Color("#405c3b").lerp(Color("#91a56b"),(sin(i*1.8)+1)*.35))
 var batch:=MultiMeshInstance3D.new();parent.add_child(batch);batch.name="HeartLeaves";batch.multimesh=mm;batch.material_override=material
@warning_ignore_restore("integer_division")
static func attach(stage: Node3D,model: Node3D) -> void:
 var completed: int=int(stage.get_meta("heart_visual_count",count(stage.heart_unlocked)))
 model.set_meta("heart_visual_count",completed)
 # The seed is an initial form, not a second model inside the grown tree.
 var original: Array=model.get_children()
 var seed_form:=Node3D.new();seed_form.name="SeedForm";model.add_child(seed_form)
 for child in original:child.reparent(seed_form,false)
 seed_form.visible=completed<3
 var growth_branches: Array=[]
 var bark:=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/root_bark.gdshader")
 var foliage:=ShaderMaterial.new();foliage.shader=preload("res://assets/shaders/heart_foliage.gdshader");foliage.set_shader_parameter("motion_enabled",1.0 if stage.get_meta("heart_foliage_motion",true) else 0.0);foliage.set_shader_parameter("player_world_position",stage.get_meta("heart_foliage_viewer",Vector3(10000,1,0)));model.set_meta("heart_foliage_material",foliage)
 for i in mini(2,completed):
  var bud:=Node3D.new();model.add_child(bud);bud.name="HeartBud"+str(i+1);bud.position=Vector3(-.24 if i==0 else .24,1.1,0);bud.set_meta("unlocked_at",i+1);growth_branches.append(bud)
  var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES);var points: Array[Vector3]=[]
  for j in 17:
   var t:=j/16.0;points.append(Vector3(sin(t*PI)*.13,.42*t,(i*2-1)*t*.2))
  stage.root_tube(s,points,.045,.008)
  var stem:=MeshInstance3D.new();bud.add_child(stem);stem.mesh=s.commit();stem.material_override=bark;leaves(bud,[points[8],points[16]],i,foliage)
 if completed>=3:
  var tree:=Node3D.new();tree.name="HeartTree";model.add_child(tree)
  var h:=trunk_height(completed);var width:=crown_width(completed)
  var trunk:=SurfaceTool.new();trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
  for root_index in 7:
   var root_points: Array[Vector3]=[];var angle:=root_index*TAU/7
   for j in 25:
    var t:=j/24.0;var radius:=lerpf(.12,1.35+completed*.018,t)
    root_points.append(Vector3(cos(angle+t*.18)*radius,.035+pow(1-t,2)*.40,sin(angle+t*.18)*radius))
   stage.root_tube(trunk,root_points,.12+completed*.003,.009)
  for strand in 3:
   var points: Array[Vector3]=[]
   for j in 49:
    var t:=j/48.0;var a:=strand*TAU/3+t*2.2
    points.append(Vector3(sin(t*4.2)*.16+cos(a)*.1*(1-t),t*h,cos(t*3.4)*.13+sin(a)*.1*(1-t)))
   stage.root_tube(trunk,points,.14+completed*.009,.015)
  var wood:=MeshInstance3D.new();tree.add_child(wood);wood.name="LivingTrunk";wood.mesh=trunk.commit();wood.material_override=bark
  for i in mini(40,completed-2):
   var branch:=Node3D.new();tree.add_child(branch);branch.name="HeartBranch"+str(i);branch.set_meta("unlocked_at",i+3);growth_branches.append(branch)
   var anchor: float=.30+float(i%8)*.075
   branch.position=Vector3(sin(anchor*4.2)*.16,anchor*h,cos(anchor*3.4)*.13);branch.rotation.y=i*2.39996
   var points: Array[Vector3]=[];var length_value:=width*(.8+.22*sin(i*1.7))
   for j in 25:
    var t:=j/24.0;points.append(Vector3(sin(t*PI)*.16,t*h*.16+sin(t*PI)*.23,t*length_value))
   var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES);stage.root_tube(s,points,.075+completed*.002,.005)
   var wood_branch:=MeshInstance3D.new();branch.add_child(wood_branch);wood_branch.mesh=s.commit();wood_branch.material_override=bark
   var tips: Array[Vector3]=[]
   for j in range(10,25,2):tips.append(points[j])
   leaves(branch,tips,i,foliage)
 model.set_meta("growth_branches",growth_branches)
