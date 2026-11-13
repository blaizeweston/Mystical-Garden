extends RefCounted
const Routes=preload("res://boss_lair_routes.gd")
# Visible lair features share the authority's walkable floor; shallow water is traversable.
static func piece(stage: Node,parent: Node,shape: Mesh,point: Vector3,color: Color) -> MeshInstance3D:
 var object: MeshInstance3D=stage.mesh(shape,stage.WILD_OFFSET+point,color)
 object.reparent(parent,true)
 return object
static func pool(stage: Node,parent: Node,point: Vector3,size: Vector2,phase: int) -> void:
 var disc=CylinderMesh.new();disc.top_radius=1;disc.bottom_radius=1;disc.height=.025;disc.radial_segments=48
 var object=piece(stage,parent,disc,point+Vector3.UP*.035,Color("#345b60"));object.scale=Vector3(size.x,1,size.y)
 var water=ShaderMaterial.new();water.shader=preload("res://assets/shaders/lair_water.gdshader")
 water.set_shader_parameter("phase_strength",phase*.28)
 object.material_override=water
static func build(stage: Node,parent: Node,field: RefCounted) -> void:
 var kind: int=field.boss_kind
 if kind==21:
  drowned(stage,parent,field)
 elif kind==22:
  preload("res://boss_phase_visuals.gd").build_nest(stage,parent,field)
 elif kind==20:
  var offset:=Routes.orchard_angle(field.configured_key.z)
  for i in 10:
   var a:=TAU*i/10.0+offset
   stage.place_asset(parent,stage.SNAG,Vector3(cos(a)*18.0,0,sin(a)*18.0),Vector3.ONE*.55,a)
 else:
  for i in 7:
   var a=TAU*i/7.0
   var growth=SphereMesh.new();growth.radius=.35;growth.height=1.25;growth.radial_segments=16;growth.rings=8
   piece(stage,parent,growth,Vector3(cos(a)*11,.4,sin(a)*11),Color("#6d567a"))


static func drowned(stage: Node, parent: Node, field: RefCounted) -> void:
 var layout:=Routes.crossings(field.configured_key.z)
 var bars: Array=layout.bars
 var center:=float(layout.center)
 var bounds: Array=[-12.0,float(bars[0])-1.1,float(bars[0])+1.1,float(bars[1])-1.1,float(bars[1])+1.1,11.8]
 for strip in [-8.1,0.0,8.1]:
  for index in range(0,bounds.size(),2):
   var start:=float(bounds[index]);var finish:=float(bounds[index+1])
   pool(stage,parent,Vector3(center+strip,0,(start+finish)*.5),Vector2(2.85,(finish-start)*.5),field.boss_phase)
 for bank_x in layout.banks:
  for side in [-1.0,1.0]:
   for z in [-9.0,-6.8,.6,2.4,8.3,10.0]:
    var at:=Vector3(float(bank_x)+side*1.48,0,z)
    if not field.inside_floor(at,.4):continue
    var cluster:=Node3D.new()
    parent.add_child(cluster)
    cluster.position=stage.WILD_OFFSET+at
    for index in 3:
     var reed:=CylinderMesh.new()
     reed.top_radius=.016;reed.bottom_radius=.045;reed.height=.57+index*.18;reed.radial_segments=6
     var stem:=piece(stage,cluster,reed,at+Vector3((index-1)*.19,reed.height*.41,.1*index),Color("#6e8263"))
     stem.rotation.z=side*(.09+index*.12+float(field.boss_phase)*.08)
  for z in bars:
   var slab:=CylinderMesh.new()
   slab.top_radius=1.0;slab.bottom_radius=1.05;slab.height=.06;slab.radial_segments=9
   var stone:=piece(stage,parent,slab,Vector3(bank_x,.016,z),Color("#514a3c"))
   (stone.material_override as StandardMaterial3D).roughness=.97
   stone.rotation.y=.20 if float(bank_x)>center else -.24
   stone.scale=Vector3(1.05,1.0,.55)

static func pose(actor: Dictionary, cue: Dictionary, brace: float) -> void:
 var model: Node3D=actor.model
 var material: StandardMaterial3D=actor.tint
 var mode: String=cue.get("mode","")
 material.emission_enabled=mode in ["uprooting","core_exposed"]
 match mode:
  "root_sweep":
   model.rotation.z-=brace*.16
   model.position.y-=brace*.22
  "orchard_march":
   model.rotation.x+=brace*.26
  "falling_fruit":
   model.position.y+=brace*.15
  "root_cage":
   model.position.y-=brace*.32
   model.rotation.x-=brace*.19
  "drowned_surge":
   model.rotation.x+=brace*.22
   model.position.y-=brace*.17
  "tidal_ring","grasping_pool":
   model.position.y+=brace*.16
   model.rotation.z+=sin(float(cue.remaining)*7.0)*brace*.095
  "uprooting","core_exposed":
   var open:=clampf(float(cue.remaining)*2.2,0.0,1.0)
   model.position.y-=open*.19
   model.rotation.x-=open*.21
   material.emission=Color("#a7ce80") if mode=="uprooting" else Color("#75c8c7")
   material.emission_energy_multiplier=.18+open*.40

static func draw_warning(effects: Node,mesh: ImmediateMesh,event: Dictionary,from: Vector3,to: Vector3) -> void:
 var role: String=event.role
 var radius: float=event.radius
 if role=="orchard_cage":
  cage(effects,mesh,from,(to-from).normalized(),radius,event.inner,event.span,0.0)
  return
 if role=="orchard_sweep":
  var face:=Vector3(event.face[0],0,event.face[2])+Vector3.UP*.055
  var forward: Vector3=(face-from).normalized()
  if forward.is_zero_approx():forward=Vector3.FORWARD
  var span: float=event.span
  var inner: float=event.inner
  for edge in [-.5,.5]:
   var end:=forward.rotated(Vector3.UP,edge*span)
   effects.ribbon(mesh,from+end*inner,from+end*radius,.092)
  for index in 36:
   var a:=forward.rotated(Vector3.UP,span*(index/36.0-.5))
   var b:=forward.rotated(Vector3.UP,span*((index+1)/36.0-.5))
   effects.ribbon(mesh,from+a*radius,from+b*radius,.106)
   effects.ribbon(mesh,from+a*inner,from+b*inner,.069)
   if index%5==0:effects.ribbon(mesh,from+a*radius*.90,from+a*radius*.96,.065)
  if event.get("interior_escape",false):
   for turn in [-.38,0.0,.38]:
    var ray:=forward.rotated(Vector3.UP,turn*span)
    var side:=ray.cross(Vector3.UP)
    var tip:=from+ray*(inner-.33)
    var tail:=from+ray*(inner+.28)
    effects.ribbon(mesh,tail+side*.24,tip,.065)
    effects.ribbon(mesh,tail-side*.24,tip,.065)
  return
 if role=="orchard_anchor":
  var growth:=1.0-clampf(float(event.remaining)/2.3,0.0,1.0)
  for index in 7:
   var angle:=TAU*index/7.0
   var root:=Vector3(cos(angle),0,sin(angle))
   var bend:=root.rotated(Vector3.UP,.26)
   var joint:=to+root*(.22+.42*growth)
   var tip:=joint+bend*(.25+.6*growth)
   effects.ribbon(mesh,to,joint,.11)
   effects.ribbon(mesh,joint,tip,.065)
   effects.ribbon(mesh,joint,joint+root.rotated(Vector3.UP,-.56)*(.13+.43*growth),.042)
  return
 if event.get("lair","")=="fruit":
  fruit(effects,mesh,event,to,radius)
  return
 effects.circle(mesh,to,radius,.095)
 if role=="lair_open":
  effects.circle(mesh,to,radius*.68,.039)
 elif role=="lair_phase":
  effects.circle(mesh,to,radius*.78,.038)
 else:
  var active: bool=event.get("active",false)
  var clock:=float(Time.get_ticks_msec())*.0034
  for band in 3:
   var t:=fposmod(clock*.36+band*.28,1.0)
   var band_radius:=radius*(.22+t*.70)
   effects.circle(mesh,to,band_radius,.052 if active else .031)


static func cage(effects: Node, mesh: ImmediateMesh, center: Vector3, axis: Vector3,
  outer: float, inner: float, gap: float, lift: float) -> void:
 var top:=center+Vector3.UP*lift
 effects.circle(mesh,top,inner,.09)
 for half in [0.0,PI]:
  var start:=float(half)+gap
  var span:=PI-gap*2.0
  for edge in [start,start+span]:
   var ray:=axis.rotated(Vector3.UP,edge)
   effects.ribbon(mesh,top+ray*inner,top+ray*outer,.11)
  for index in 24:
   var a:=axis.rotated(Vector3.UP,start+span*index/24.0)
   var b:=axis.rotated(Vector3.UP,start+span*(index+1)/24.0)
   effects.ribbon(mesh,top+a*outer,top+b*outer,.12)
   if index%4!=2:continue
   var root:=top+a*outer
   var knot:=top+a*outer*.80
   var fork:=top+a.rotated(Vector3.UP,.07)*outer*.65
   effects.ribbon(mesh,root,knot,.08)
   effects.ribbon(mesh,knot,fork,.05)
   effects.ribbon(mesh,knot,top+a.rotated(Vector3.UP,-.07)*outer*.72,.04)


static func fruit(effects: Node, mesh: ImmediateMesh, event: Dictionary, center: Vector3, radius: float) -> void:
 effects.circle(mesh,center,radius,.095)
 if event.get("active",false):
  for index in 8:
   var ray:=Vector3.RIGHT.rotated(Vector3.UP,TAU*index/8.0)
   effects.ribbon(mesh,center+ray*radius*.21,center+ray*radius*.91,.075)
  return
 var remaining:=float(event.get("remaining",0.0))
 var falling:=center+Vector3.UP*(.08+3.5*smoothstep(0.0,1.0,remaining))
 effects.circle(mesh,falling,.35,.115)
 effects.ribbon(mesh,falling+Vector3.UP*.66,falling,.11)
 for index in 4:
  var ray:=Vector3.RIGHT.rotated(Vector3.UP,TAU*index/4.0)
  var edge:=center+ray*radius
  effects.ribbon(mesh,edge+ray*.28,edge-ray*.23,.085)
