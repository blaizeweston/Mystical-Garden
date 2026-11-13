extends Node3D
## Authored spring landmark. Cosmetic state comes only from researched prerequisites.
func configure(stage: Node3D,at: Vector3,awakened: bool) -> void:
 position=at
 set_meta("garden_spring_site",true);set_meta("garden_spring_awakened",awakened)
 name="ShelteredSpring" if awakened else "DormantSpringSite"
 # The locked site is a small sealed stone, with no water, flow or lily pads.
 get_node("SourceStone").scale=Vector3(.75,.85,.66) if awakened else Vector3(.78,.25,.62)
 stage.natural_materials(get_node("SourceStone"))
 get_node("DormantSeal").visible=not awakened
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for branch in 7:
  var points: Array[Vector3]=[];var angle:=branch*TAU/7
  for step in 33:
   var t:=step/32.0;var radius:=lerpf(.94,.32,t)
   points.append(Vector3(cos(angle+t*.6)*radius,.04+sin(t*PI*.5)*(.70 if awakened else .22),-.25+sin(angle+t*.6)*radius*.64))
  stage.root_tube(surface,points,.09,.014)
 var roots:=MeshInstance3D.new();roots.name="SpringRootCrown";add_child(roots);roots.mesh=surface.commit()
 var bark:=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/root_bark.gdshader");roots.material_override=bark
 if not awakened:return
 set_meta("garden_water_position",at)
 var local_rng:=RandomNumberGenerator.new();local_rng.seed=87336
 stage.build_garden_pond(at,1.05,local_rng)
 var pool: Node3D=stage.garden_edge.get_child(stage.garden_edge.get_child_count()-1)
 pool.reparent(self,false);pool.position=Vector3.ZERO;pool.name="SpringBasin"
 # A distinct raised source and falling stream separate this landmark from ambient ponds.
 var hollow:=MeshInstance3D.new();hollow.name="SpringSource";add_child(hollow)
 var mouth:=SphereMesh.new();mouth.radius=.16;mouth.height=.28;mouth.radial_segments=32;mouth.rings=16;hollow.mesh=mouth;hollow.position=Vector3(0,.46,-.06);hollow.scale.z=.3
 var dark:=StandardMaterial3D.new();dark.albedo_color=Color("#162e2b");hollow.material_override=dark
 surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for step in 32:
  for corner in [[step,-1],[step+1,-1],[step,1],[step,1],[step+1,-1],[step+1,1]]:
   var t: float=float(corner[0])/32
   surface.set_uv(Vector2((float(corner[1])+1)*.5,t));surface.set_normal(Vector3(0,.4,1).normalized())
   surface.add_vertex(Vector3(float(corner[1])*lerpf(.045,.16,t),lerpf(.46,.045,t),lerpf(-.01,.52,t)))
 var flow:=MeshInstance3D.new();flow.name="SpringCascade";add_child(flow);flow.mesh=surface.commit();flow.set_meta("garden_motion",true)
 var water:=ShaderMaterial.new();water.shader=preload("res://assets/shaders/garden_spring_flow.gdshader");flow.material_override=water;flow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
