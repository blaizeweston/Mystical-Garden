extends RefCounted
## Station meshes for the Garden. The Heart itself uses its imported sculpt.

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

