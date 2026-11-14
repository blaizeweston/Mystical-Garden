extends Node3D

const Meshes = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
var trees: Array[ArrayMesh] = []
var snag: ArrayMesh
var forest_material: StandardMaterial3D
var amber_material: StandardMaterial3D
var botanical_canopies := {}

func rebuild(layout: Dictionary, garden: bool, profile: Dictionary = {}, biome: int = 0) -> void:
	for child in get_children():
		child.free()
	if trees.is_empty():
		forest_material = StandardMaterial3D.new()
		forest_material.vertex_color_use_as_albedo = true
		forest_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		forest_material.roughness = 0.96
		for variant in 4:
			var tree := Meshes.tree(variant)
			tree.surface_set_material(0, forest_material)
			trees.append(tree)
		snag = Meshes.snag()
		snag.surface_set_material(0, forest_material)
		amber_material = StandardMaterial3D.new()
		amber_material.albedo_color = Color("#ad452b")
		amber_material.emission_enabled = true
		amber_material.emission = Color("#d45231")
		amber_material.emission_energy_multiplier = 0.55
	var enclosing := trees
	if not profile.is_empty():
		if not botanical_canopies.has(biome):
			var choices: Array[ArrayMesh] = []
			for variant in 4:
				var mesh := Meshes.botanical(variant, "canopy", profile, biome)
				mesh.surface_set_material(0, forest_material)
				choices.append(mesh)
			botanical_canopies[biome] = choices
		enclosing = botanical_canopies[biome]
	for variant in enclosing.size():
		var transforms: Array[Transform3D] = []
		for trunk in layout.enclosure:
			if trunk.variant != variant:
				continue
			var scale := Vector3(trunk.crown * 2.4, trunk.height, trunk.crown * 2.4)
			transforms.append(_pose(trunk.at, trunk.yaw, scale))
		_batch(enclosing[variant], transforms)
	var deadwood: Array[Transform3D] = []
	var sparks: Array[Transform3D] = []
	for accent in layout.accents:
		deadwood.append(_pose(accent.at, accent.yaw, Vector3.ONE * accent.size))
		if garden:
			sparks.append(_pose(accent.at, accent.yaw, Vector3(0.18, 0.26, 0.18), 0.33 * accent.size))
	if garden:
		for i in (4 if not profile.is_empty() else 7):
			var angle := TAU * i / 7.0
			var offset := Vector2.from_angle(angle) * (1.24 + 0.32 * sin(i * 4.0))
			deadwood.append(_pose(offset, -angle, Vector3(1.0, 0.45, 1.0)))
		sparks.append(_pose(Vector2(0.27, 0.74), 0.0, Vector3(0.34, 0.43, 0.30), 0.34))
	_batch(snag, deadwood)
	if not garden and not profile.is_empty():
		var accent_material := StandardMaterial3D.new()
		accent_material.albedo_color = profile.accent
		accent_material.roughness = 0.76
		var seedpod := SphereMesh.new()
		seedpod.radius = 0.5
		seedpod.height = 1.0
		seedpod.radial_segments = 5
		seedpod.rings = 3
		seedpod.material = accent_material
		var pods: Array[Transform3D] = []
		for accent in layout.accents:
			if biome != 2 and pods.size() > 0:
				break
			pods.append(_pose(accent.at, accent.yaw, Vector3(0.18, 0.28, 0.18), 0.29 * accent.size))
		_batch(seedpod, pods)
	if not sparks.is_empty():
		var ember := SphereMesh.new()
		ember.radius = 0.5
		ember.height = 1.0
		ember.radial_segments = 7
		ember.rings = 4
		ember.material = amber_material
		_batch(ember, sparks)

func _pose(at: Vector2, yaw: float, scale: Vector3, y: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled_local(scale), Vector3(at.x, y, at.y))

func _batch(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	add_child(node)
