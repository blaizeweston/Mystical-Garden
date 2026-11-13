extends RefCounted
static func accents(stage: Node3D,radius: float,random: RandomNumberGenerator) -> void:
	var destinations: Array=preload("res://garden_layout.gd").destinations(stage)
	for end in destinations:
		var paths:=SurfaceTool.new();paths.begin(Mesh.PRIMITIVE_TRIANGLES)
		var direction: Vector3=end.normalized();var side:=direction.cross(Vector3.UP)
		for i in 40:
			for corner in [[i,-1],[i,1],[i+1,-1],[i,1],[i+1,1],[i+1,-1]]:
				var t:=float(corner[0])/40;var at: Vector3=end*t+side*sin(t*PI*2)*.23;at.y=.014
				paths.set_uv(Vector2(corner[1],t*end.length()));paths.set_normal(Vector3.UP);paths.add_vertex(at+side*float(corner[1])*.60)
		var walk:=MeshInstance3D.new();walk.name="MossyGardenPaths";stage.garden_edge.add_child(walk);walk.mesh=paths.commit();walk.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		walk.material_override=preload("res://garden_scenery.gd").path_material(end.length())
		walk.set_meta("garden_route_target",end)
	var flowers:=SurfaceTool.new();flowers.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 140:
		var angle:=random.randf()*TAU;var r:=random.randf_range(2.0,radius-.9);var at:=Vector3(cos(angle)*r,0,sin(angle)*r)
		if preload("res://garden_layout.gd").reserved(stage,at,radius): continue
		var center:=at+Vector3.UP*random.randf_range(.10,.21);var color: Color=[Color("#d9d8b1"),Color("#bba2a6"),Color("#c1cf9a")][i%3]
		for petal in 5:
			var a:=petal*TAU/5+i;var dir:=Vector3(cos(a),.12,sin(a));var side:=dir.cross(Vector3.UP)
			var tip:=center+dir*.06
			triangle(flowers,center,tip+side*.023,tip-side*.023,color)
	var meadow:=MeshInstance3D.new();stage.garden_edge.add_child(meadow);meadow.name="FloweringGroundcover";meadow.mesh=flowers.commit()
	var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/garden_breeze.gdshader");material.set_shader_parameter("strength",.035);meadow.set_meta("garden_motion",true);meadow.material_override=material
static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	for vertex in [a,b,c]: surface.set_color(color);surface.set_normal(Vector3.UP);surface.add_vertex(vertex)

static func altar(stage: Node3D) -> Node3D:
	var root:=Node3D.new();stage.add_child(root);root.position=stage.ALTAR;root.name="GardenOfferingBowl"
	var rock=stage.ROCK.instantiate();root.add_child(rock);stage.natural_materials(rock);rock.scale=Vector3(.82,.50,.82)
	var bowl:=SphereMesh.new();bowl.radius=.58;bowl.height=.30;bowl.radial_segments=48;bowl.rings=20
	var basin: MeshInstance3D=stage.mesh(bowl,Vector3(0,.43,0),Color("#3e4434"));basin.reparent(root,false)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var a:=i*TAU/7;var points: Array[Vector3]=[]
		for j in 25:
			var t:=j/24.0;var r:=lerpf(.85,.50,t);points.append(Vector3(cos(a+t*.35)*r,.03+sin(t*PI*.5)*.45,sin(a+t*.35)*r))
		stage.root_tube(surface,points,.075,.02)
	var roots:=MeshInstance3D.new();root.add_child(roots);roots.mesh=surface.commit();var bark:=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/root_bark.gdshader");roots.material_override=bark
	return root

