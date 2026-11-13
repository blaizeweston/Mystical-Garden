extends RefCounted
# A closed, ribbed seed-organ with unfurling sepals: plant first, something
# stranger only on a second look. Each restoration phase adds living detail.
static func build(stage: Node3D,phase: int) -> Node3D:
	phase=clampi(phase,0,5)
	var root:=Node3D.new();stage.add_child(root);root.position=stage.HEART;root.name="HeartForm"
	var height:=1.15+phase*.17
	var core:=MeshInstance3D.new();root.add_child(core);core.name="HeartCore"
	var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=64;sphere.rings=40
	var arrays:=sphere.get_mesh_arrays();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var v:=vertices[i];var angle:=atan2(v.z,v.x)
		var ribs:=1.0+.055*cos(angle*7.0+v.y*.9)+.018*sin(angle*13.0)
		vertices[i]=Vector3(v.x*(.39+phase*.027)*ribs+.025*sin(v.y*3),v.y*height*.55+height*.69,v.z*(.35+phase*.025)*ribs)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var source:=ArrayMesh.new();source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var smooth:=SurfaceTool.new();smooth.create_from(source,0);smooth.generate_normals();core.mesh=smooth.commit()
	var skin:=StandardMaterial3D.new();skin.albedo_color=Color("#727e58").lerp(Color("#959d83"),phase/7.0);skin.roughness=.48;skin.emission_enabled=true;skin.emission=Color("#adbb84");skin.emission_energy_multiplier=.12;core.material_override=skin;stage.heart_core=core
	# Broad folded sepals conceal most of the organ, with a warm inner seam.
	for i in 7+phase:
		var angle:=TAU*i/float(7+phase)+.13*sin(i*2.4)
		var petal:=MeshInstance3D.new();root.add_child(petal);petal.name="FoldedSepal"+str(i)
		petal.mesh=sepal(angle,height,.20+phase*.008,i)
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color("#344b39").lerp(Color("#596c47"),float(i%3)/4.0);mat.roughness=.7;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;petal.material_override=mat
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9+phase:
		var a:=TAU*i/float(9+phase);var points: Array[Vector3]=[]
		for j in 29:
			var t:=j/28.0;var radius:=lerpf(1.65+phase*.09,.25,t);var angle:=a+.35*sin(t*PI)+t*.25
			points.append(Vector3(cos(angle)*radius,.02+pow(t,2.3)*height*.65,sin(angle)*radius))
		stage.root_tube(surface,points,.006,.095+phase*.005)
	# Veins trace the core asymmetrically; their muted rose tint quietly breaks
	# the Garden's green palette without resembling eyes, teeth or machinery.
	for i in 7:
		var points: Array[Vector3]=[];var a:=i*TAU/7
		for j in 33:
			var t:=j/32.0;var theta:=lerpf(.35,2.7,t);var angle:=a+.13*sin(t*PI*2)
			points.append(Vector3(cos(angle)*sin(theta)*(.405+phase*.027),cos(theta)*height*.55+height*.69,sin(angle)*sin(theta)*(.365+phase*.025)))
		stage.root_tube(surface,points,.011,.005)
	if phase>=3:
		for i in phase-1:
			var a:=i*2.4;var points: Array[Vector3]=[]
			for j in 25:
				var t:=j/24.0;var r:=.3+.30*sin(t*PI);points.append(Vector3(cos(a+t*.7)*r,height*.9+t*.6,sin(a+t*.7)*r))
			stage.root_tube(surface,points,.035,.004)
	var veins:=MeshInstance3D.new();root.add_child(veins);veins.name="LivingVeins";veins.mesh=surface.commit()
	var tissue:=StandardMaterial3D.new();tissue.albedo_color=Color("#55443e");tissue.roughness=.64;veins.material_override=tissue
	preload("res://heart_growth_visuals.gd").attach(stage,root)
	stage.marker(Vector3(0,height*1.45+.5,0),"HEART",root)
	return root

static func sepal(angle: float,height: float,width: float,seed_value: int) -> ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 32:
		for k in 8:
			for corner in [[j,k],[j+1,k],[j,k+1],[j,k+1],[j+1,k],[j+1,k+1]]:
				var t:=float(corner[0])/32;var u:=float(corner[1])/8*2-1
				var r:=lerpf(.75,.06,t)+.28*sin(t*PI);var curl:=angle+.22*sin(t*PI)
				var side:=Vector3(-sin(curl),0,cos(curl));var radial:=Vector3(cos(curl),0,sin(curl))
				var point:=radial*(r+u*u*.12*sin(t*PI))+side*u*width*pow(sin(t*PI),.7)
				point.y=.06+t*height*(1.05+.08*sin(seed_value*2.1))+.06*(1-u*u)*sin(t*PI)
				surface.set_smooth_group(0);surface.set_uv(Vector2(u,t));surface.add_vertex(point)
	surface.generate_normals();return surface.commit()

static func station(stage: Node3D,id: String,at: Vector3) -> Node3D:
	var root:=Node3D.new()
	stage.add_child(root)
	root.position=at
	var colors: Dictionary={"seed_archive":Color("#c7bb79"),"monster_studies":Color("#b092b4"),"living_archive":Color("#91c5b5")}
	var color: Color=colors[id]
	var stone:=CylinderMesh.new()
	stone.top_radius=.65
	stone.bottom_radius=.8
	stone.height=.28
	stone.radial_segments=12
	stage.mesh(stone,Vector3(0,.14,0),Color("#535b40")).reparent(root,false)
	for i in 6:
		var a:=TAU*i/6.0
		var rib: MeshInstance3D=stage.box(Vector3(cos(a)*.40,.55,sin(a)*.40),Vector3(.12,.85,.12),Color("#665135"))
		rib.reparent(root,false)
		rib.rotation=Vector3(sin(a)*.30,0,-cos(a)*.30)
	if id=="living_archive":
		for i in 3:
			var a:=i*TAU/3
			var orb: MeshInstance3D=stage.sphere(Vector3(cos(a)*.20,.95+i*.14,sin(a)*.20),.13,color)
			orb.reparent(root,false)
	else:
		var kernel: MeshInstance3D=stage.sphere(Vector3(0,.85,0),.22,color)
		kernel.reparent(root,false)
		(kernel.material_override as StandardMaterial3D).emission_enabled=true
		(kernel.material_override as StandardMaterial3D).emission=color
		(kernel.material_override as StandardMaterial3D).emission_energy_multiplier=.35
	var title: String={"seed_archive":"RECLAMATION","monster_studies":"OFFERING ALTAR","living_archive":"LIVING ARCHIVE"}[id]
	stage.marker(Vector3(0,1.65,0),title,root)
	return root

