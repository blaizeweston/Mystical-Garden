extends Node3D
## Detached examples built by the same sculpt, path, station and particle factories as the Garden.
const Ambient = preload("res://assets/terrain_m02/garden_ambient.gd")
const Heart = preload("res://assets/terrain_m02/terrain_heart_preview.gd")
const Stations = preload("res://assets/terrain_m02/garden_station_art.gd")
const Links = preload("res://garden_infrastructure_view.gd")
const Roots = preload("res://assets/terrain_m02/garden_heart_roots.gd")
const GROUPS := ["heart","root","intake","spray","pollen"]
var controlled: Array[ShaderMaterial] = []
var animated: Array[ShaderMaterial] = []

func create(group: String, supplied: bool, age: int) -> void:
	if group in ["heart","root"]:
		var heart := Heart.new()
		heart.sculpt_only = true
		add_child(heart)
		heart.show_stage(age,false)
		controlled.append(heart.ambient_fissure)
		if group=="root":
			var links: Array[Dictionary] = []
			var terrain := {"layout":{"water":[]}}
			for at: Vector2 in [Vector2(7.1,.65),Vector2(6.2,3.35)]:
				var plan := Roots.plan(Links._route(at,links.size()+1),age,terrain,links,true)
				links.append(plan)
				var root := MeshInstance3D.new()
				root.mesh = Roots.mesh(plan)
				var bark := ShaderMaterial.new()
				bark.shader = Links.Bark
				bark.set_shader_parameter("living",true)
				root.material_override = bark
				controlled.append(bark)
				add_child(root)
				var bed := MeshInstance3D.new()
				bed.mesh = Stations.build("starter_bed",false)
				var soil := StandardMaterial3D.new()
				soil.vertex_color_use_as_albedo = true
				bed.material_override = soil
				bed.position = Vector3(at.x,0,at.y)
				add_child(bed)
		return

	var station := MeshInstance3D.new()
	var art := "pollination_bloom" if group=="pollen" else "sprinkler" if group=="spray" else "intake"
	station.mesh = Stations.build(art)
	if group=="pollen":
		var flower := Ambient.bloom_material()
		station.material_override = flower
		animated.append(flower)
	else:
		var pigment := StandardMaterial3D.new()
		pigment.vertex_color_use_as_albedo = true
		station.material_override = pigment
	add_child(station)
	var shore := Vector3(.38,.045,.13)
	if group=="intake":
		var surface := MeshInstance3D.new()
		var pool := CylinderMesh.new()
		pool.top_radius = .84
		pool.bottom_radius = .84
		pool.height = .035
		var water := StandardMaterial3D.new()
		water.albedo_color = Color("#37534c")
		pool.material = water
		surface.mesh = pool
		surface.position = shore + Vector3(.45,-.045,0)
		add_child(surface)
	if group!="pollen" and not supplied: return
	var particles := Ambient.batch(group)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	Ambient.emitter(tool,group,shore if group=="intake" else Vector3.ZERO,0.)
	particles.mesh = tool.commit()
	add_child(particles)
	controlled.append(particles.material_override)

## Fit the visible sculpt in camera space; the imported stages have different crowns.
func frame_heart(camera: Camera3D, age: int) -> void:
	var mesh: MeshInstance3D=get_child(0).sculpt_models[age]
	var bounds:=mesh.mesh.get_aabb()
	var points:=PackedVector2Array()
	for i in 8:
		var corner:=camera.to_local(mesh.to_global(bounds.get_endpoint(i)))
		points.append(Vector2(corner.x,corner.y))
	var rect:=Rect2(points[0],Vector2.ZERO)
	for at in points: rect=rect.expand(at)
	var mid:=rect.get_center()
	camera.translate_object_local(Vector3(mid.x,mid.y,0.))
	var size:=camera.get_viewport().get_visible_rect().size
	camera.size=maxf(rect.size.y,rect.size.x*size.y/maxf(1.,size.x))*1.08

func configure(group: String, values: Dictionary, seconds: float) -> void:
	for mat in controlled:
		var kind := "heart" if mat.shader==preload("res://assets/shaders/garden_fissure.gdshader") else group
		Ambient.configure(mat,kind,values,seconds)
	seek(seconds)

func seek(seconds: float) -> void:
	for mat in controlled: mat.set_shader_parameter("sample_time",seconds)
	for mat in animated: mat.set_shader_parameter("sample_time",seconds)
