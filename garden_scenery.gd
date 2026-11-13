extends RefCounted

const Layout := preload("res://garden_layout.gd")
const GRASS := preload("res://assets/garden/field/grass_medium_01.glb")
const FERNS := preload("res://assets/garden/field/fern_02.glb")
const STONES := preload("res://assets/garden/field/mossy_stones.glb")
const COVER := preload("res://assets/shaders/garden_ground_cover.gdshader")
const MEADOW := preload("res://assets/shaders/garden_meadow.gdshader")
const PATH := preload("res://assets/shaders/garden_path.gdshader")
const GRASS_MASK := preload("res://assets/garden/field/grass_opacity.png")
const FERN_MASK := preload("res://assets/garden/field/fern_opacity.png")
const SOIL := preload("res://assets/garden/field/forest_soil.jpg")
const BARK := preload("res://assets/garden/field/bark.jpg")
static var plants: Dictionary = {}
static var stone_meshes: Array[Mesh] = []


static func floor_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MEADOW
	material.set_shader_parameter("leaf_color",preload("res://assets/garden/field/leafy_grass.jpg"))
	material.set_shader_parameter("leaf_normal",preload("res://assets/garden/field/leafy_grass_normal.jpg"))
	material.set_shader_parameter("soil",SOIL)
	return material


static func path_material(length: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PATH
	material.set_shader_parameter("soil",SOIL)
	material.set_shader_parameter("path_length",length)
	return material


static func root_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = BARK
	material.albedo_color = Color("#796b54")
	material.roughness = .94
	material.uv1_scale = Vector3(1.5,1,1)
	return material


static func load_plants() -> void:
	if not plants.is_empty():
		return
	plants = {"low":[],"tall":[],"fern":[]}
	for scene in [GRASS,FERNS]:
		var root: Node = scene.instantiate()
		for model: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			var name := str(model.name)
			if "tiny_" in name:
				plants.low.append({"id":name,"mesh":model.mesh,"mask":GRASS_MASK})
			elif "tall_" in name or "small_" in name:
				plants.tall.append({"id":name,"mesh":model.mesh,"mask":GRASS_MASK})
			elif name in ["fern_02_a","fern_02_d"]:
				plants.fern.append({"id":name,"mesh":model.mesh,"mask":FERN_MASK})
		root.free()


static func scatter(stage: Node3D, radius: float) -> void:
	load_plants()
	var random := RandomNumberGenerator.new()
	random.seed = 8943
	var noise := FastNoiseLite.new()
	noise.seed = 59
	noise.frequency = .44
	var batches := {}
	for i in 1350:
		var at := Vector3(random.randf_range(-radius,radius),.005,random.randf_range(-radius,radius))
		if at.length()>radius-.3 or Layout.reserved(stage,at,radius):
			continue
		var density := noise.get_noise_2d(at.x,at.z)
		if density<-.15 and random.randf()<.76:
			continue
		var tall := density>.02 and random.randf()<.25
		var choices: Array = plants.tall if tall else plants.low
		var height := random.randf_range(.23,.41) if tall else random.randf_range(.11,.24)
		add_plant(batches,choices[random.randi_range(0,choices.size()-1)],at,height,random)
	for i in 140:
		var angle := random.randf_range(0,TAU)
		var edge := i<104
		var distance := radius*random.randf_range(.68,1.11) if edge else radius*random.randf_range(.22,.68)
		var at := Vector3(cos(angle)*distance,.005,sin(angle)*distance)
		if Layout.reserved(stage,at,radius,.18):
			continue
		add_plant(batches,plants.fern[i%plants.fern.size()],at,random.randf_range(.34,.86) if edge else random.randf_range(.19,.37),random)
	var group := Node3D.new()
	group.name = "GardenGrass"
	stage.garden_edge.add_child(group)
	for key in batches:
		var entry: Dictionary = batches[key]
		var mesh: Mesh = entry.mesh
		var source := mesh.surface_get_material(0) as StandardMaterial3D
		var material := ShaderMaterial.new()
		material.shader = COVER
		material.set_shader_parameter("tex",source.albedo_texture)
		material.set_shader_parameter("coverage",entry.mask)
		material.set_shader_parameter("blade_height",mesh.get_aabb().size.y)
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.mesh = mesh
		instances.instance_count = entry.transforms.size()
		for i in instances.instance_count:
			instances.set_instance_transform(i,entry.transforms[i])
			instances.set_instance_color(i,Color("#afb69a").lerp(Color("#d9dfbd"),random.randf()))
		var model := MultiMeshInstance3D.new()
		model.multimesh = instances
		model.material_override = material
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.set_meta("garden_motion",true)
		group.add_child(model)


static func add_plant(batches: Dictionary, entry: Dictionary, at: Vector3, height: float, random: RandomNumberGenerator) -> void:
	if not batches.has(entry.id):
		batches[entry.id] = {"mesh":entry.mesh,"mask":entry.mask,"transforms":[]}
	var bounds: AABB = entry.mesh.get_aabb()
	var scale := height / maxf(.01,bounds.size.y)
	var basis := Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3.ONE*scale)
	var bottom := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	batches[entry.id].transforms.append(Transform3D(basis,at-basis*bottom))


static func bank(group: Node3D, radius: float, random: RandomNumberGenerator) -> void:
	if stone_meshes.is_empty():
		var source := STONES.instantiate()
		for model: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			stone_meshes.append(model.mesh)
		source.free()
	for index in [0,1,2,5,6,9,10,11]:
		var angle := TAU*float(index)/13.0 + random.randf_range(-.08,.08)
		var edge := radius*(1.0+.09*sin(angle*3.0)+.045*cos(angle*5.0))
		var at := Vector3(cos(angle)*edge,-.02,sin(angle)*edge*.72)
		var stone := MeshInstance3D.new()
		stone.mesh = stone_meshes[index%stone_meshes.size()]
		var original := stone.mesh.surface_get_material(0) as StandardMaterial3D
		var material := original.duplicate() as StandardMaterial3D
		material.albedo_color = Color("#a9b09a")
		stone.material_override = material
		var bounds := stone.mesh.get_aabb()
		var factor := random.randf_range(.21,.47)/maxf(bounds.size.x,bounds.size.z)
		stone.rotation.y = random.randf_range(0,TAU)
		stone.scale = Vector3.ONE*factor
		stone.position = at-stone.basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		group.add_child(stone)
