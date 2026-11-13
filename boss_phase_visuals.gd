extends RefCounted
## Each Nameless phase presents one growth and the matching combat pose.
const TINTS: Dictionary={
 "ranged":Color("#a2b4df"),"burst":Color("#d691c4"),
 "choke":Color("#ddaa83"),"kite":Color("#a1d4c9")
}

static func branch(parent: Node3D, material: Material, from: Vector3, to: Vector3, radius: float) -> void:
 var node:=MeshInstance3D.new()
 var rod:=CylinderMesh.new()
 rod.height=from.distance_to(to);rod.top_radius=radius*.27;rod.bottom_radius=radius;rod.radial_segments=8
 node.mesh=rod;node.material_override=material
 parent.add_child(node)
 node.position=(from+to)*.5
 node.basis=Basis(Quaternion(Vector3.UP,(to-from).normalized()))

static func bulb(parent: Node3D, material: Material, at: Vector3, radius: float, stretch: float) -> void:
 var node:=MeshInstance3D.new()
 var shape:=SphereMesh.new()
 shape.radius=radius;shape.height=radius*2.0*stretch;shape.radial_segments=12;shape.rings=8
 node.mesh=shape;node.material_override=material
 parent.add_child(node);node.position=at

static func growth(actor: Dictionary, id: String, phase: int) -> void:
 var key:=id+":"+str(phase)
 if actor.get("memory_key","")==key:return
 actor.memory_key=key
 var model: Node3D=actor.model
 var previous: Node3D=model.get_node_or_null("MemoryGrowth")
 if is_instance_valid(previous):
  previous.hide()
  previous.name="SpentMemory"
  previous.queue_free()
 if not TINTS.has(id):return
 var group:=Node3D.new()
 group.name="MemoryGrowth";model.add_child(group)
 var shade: Color=TINTS[id]
 var material:=StandardMaterial3D.new()
 material.albedo_color=shade.darkened(.27);material.roughness=.8
 material.emission_enabled=true;material.emission=shade;material.emission_energy_multiplier=.27
 match id:
  "ranged":
   var foot:=Vector3(.38,1.12,-.25)
   var stem:=Vector3(.98,1.72,-.05)
   branch(group,material,foot,stem,.19)
   branch(group,material,stem,Vector3(1.26,2.55,.43),.13)
   branch(group,material,stem,Vector3(.83,2.20,.54),.09)
  "burst":
   for i in 5:
    var angle:=i*TAU/5.0
    var tip:=Vector3(cos(angle)*.68,2.06+(.14 if i%2==0 else 0.0),sin(angle)*.68)
    branch(group,material,Vector3(0,1.3,0),tip,.09)
    bulb(group,material,tip,.23,1.16)
  "choke":
   for side in [-1.0,1.0]:
    var start:=Vector3(side*.38,.8,.14)
    var fork:=Vector3(side*.86,1.14,.58)
    branch(group,material,start,fork,.17)
    branch(group,material,fork,Vector3(side*1.2,1.9,.76),.13)
    branch(group,material,fork,Vector3(side*1.43,1.46,.91),.10)
  "kite":
   var tip:=Vector3(.04,2.65,.2)
   branch(group,material,Vector3(-.38,1.45,-.25),Vector3(-.22,2.1,-.02),.14)
   branch(group,material,Vector3(-.22,2.1,-.02),tip,.10)
   bulb(group,material,tip,.31,.71)

static func pose(actor: Dictionary, cue: Dictionary, brace: float) -> void:
 var model: Node3D=actor.model
 var tint: StandardMaterial3D=actor.tint
 if int(actor.kind)==23:
  growth(actor,str(cue.get("growth","")),int(cue.get("growth_phase",-1)))
 var mode: String=cue.get("mode","")
 tint.emission_enabled=mode in ["nursery_lull","memory_exposed"]
 match mode:
  "nest_shift","brood_call":
   model.rotation.z+=sin(float(cue.remaining)*7.0)*.13
   model.position.y-=.13
  "matriarch_lunge","remembered_rend":
   model.rotation.x+=brace*.24
  "memory_lance":
   model.rotation.z+=brace*.16
  "spore_constellation","memory_phase":
   model.position.y+=.18+brace*.07
  "nursery_lull","memory_exposed":
   var recovery:=clampf(float(cue.remaining)*2.0,0,1)
   model.position.y-=.20*recovery
   model.rotation.x-=.21*recovery
   tint.emission=Color("#b8d49b")
   tint.emission_energy_multiplier=.15+recovery*.40

static func draw_warning(effects: Node, mesh: ImmediateMesh, event: Dictionary, at: Vector3) -> void:
 if event.role=="nursery_rib":
  var rect:=Rect2(event.bounds[0],event.bounds[1],event.bounds[2],event.bounds[3])
  var points: Array[Vector3]=[Vector3(rect.position.x,at.y,rect.position.y),Vector3(rect.end.x,at.y,rect.position.y),
   Vector3(rect.end.x,at.y,rect.end.y),Vector3(rect.position.x,at.y,rect.end.y)]
  for i in 4:
   var start:=points[i];var finish:=points[(i+1)%4]
   for dash in 5:
    effects.ribbon(mesh,start.lerp(finish,dash/5.0),start.lerp(finish,(dash+.68)/5.0),.085)
  for i in 5:
   var x:=lerpf(rect.position.x,rect.end.x,(i+.4)/5.0)
   effects.ribbon(mesh,Vector3(x,at.y,rect.position.y+.28),Vector3(x+.28,at.y,rect.end.y-.28),.048)
  return
 effects.circle(mesh,at,float(event.radius),.068)
 for i in 6:
  var angle:=i*TAU/6.0
  var spoke:=Vector3(cos(angle),0,sin(angle))*float(event.radius)
  effects.ribbon(mesh,at+spoke*.50,at+spoke*.74,.064)


static func build_nest(stage: Node, parent: Node, field: RefCounted) -> void:
 var sinew:=StandardMaterial3D.new()
 sinew.albedo_color=Color("#665542")
 sinew.roughness=.91
 var rib_material:=StandardMaterial3D.new()
 rib_material.albedo_color=Color("#a99677").lerp(Color("#aa7d79"),float(field.boss_phase)*.24)
 rib_material.roughness=.82
 var husk_material:=StandardMaterial3D.new()
 husk_material.albedo_color=Color("#72634d")
 husk_material.roughness=.95
 for i in field.barriers.size():
  var rect: Rect2=field.barriers[i]
  var group:=Node3D.new()
  group.name="NurseryRib"+str(i)
  parent.add_child(group)
  group.position=stage.WILD_OFFSET+Vector3(rect.get_center().x,0,rect.get_center().y)
  for strand in [-1.0,0.0,1.0]:
   var z: float=strand*.35
   branch(group,sinew,Vector3(-1.32,.14,z),Vector3(-.5,.21,z+.10),.21)
   branch(group,sinew,Vector3(-.5,.21,z+.10),Vector3(.48,.19,z-.07),.26)
   branch(group,sinew,Vector3(.48,.19,z-.07),Vector3(1.34,.12,z),.20)
  for section in 3:
   var x: float=(section-1)*.91
   var bend: float=.23 if (section+i)%2==0 else -.21
   var lower:=Vector3(x,.20,-.42)
   var elbow:=Vector3(x+bend,.85,-.25)
   var crest:=Vector3(x+bend*.8,1.35,.04)
   var tip:=Vector3(x+bend*.5,.86,.37)
   branch(group,rib_material,lower,elbow,.23)
   branch(group,rib_material,elbow,crest,.16)
   branch(group,rib_material,crest,tip,.12)
 for exit in preload("res://boss_nest_layout.gd").exits(field.boss_phase,field.configured_key.z):
  var base:=Node3D.new()
  base.name="NurseryHusk"
  parent.add_child(base)
  base.position=stage.WILD_OFFSET+exit
  for i in 6:
   var angle:=i*TAU/6.0
   var side:=Vector3(cos(angle),0,sin(angle))
   branch(base,husk_material,side*.61,side*.29+Vector3.UP*.16,.12)
