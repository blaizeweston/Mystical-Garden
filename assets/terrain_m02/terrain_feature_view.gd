extends Node3D
## One MultiMesh per repeated asset variant. Collision stays outside the preview.

const TREE := preload("res://assets/root_tree.glb")
const FERNS := preload("res://assets/garden/field/fern_02.glb")
const GRASS := preload("res://assets/garden/field/grass_medium_01.glb")
const ROCKS := preload("res://assets/garden/field/mossy_stones.glb")
const COVER := preload("res://assets/shaders/garden_ground_cover.gdshader")
const GRASS_MASK := preload("res://assets/garden/field/grass_opacity.png")
const FERN_MASK := preload("res://assets/garden/field/fern_opacity.png")

var variants := {}
var bridge_material: StandardMaterial3D
var vegetation: Node3D
var rocks: Node3D
var crossings: Node3D

func _ready() -> void:
	vegetation = _group("Vegetation")
	rocks = _group("Rocks")
	crossings = _group("Crossings")

func _group(label: String) -> Node3D:
	var group := Node3D.new()
	group.name = label
	add_child(group)
	return group

func rebuild(layout: Dictionary) -> Dictionary:
	if variants.is_empty():
		_load_variants()
	for group in [vegetation, rocks, crossings]:
		for child in group.get_children():
			child.free()
	var batches := {}
	for plant in layout.plants:
		var options: Array = variants[plant.kind]
		var asset: Dictionary = options[plant.variant % options.size()]
		var height: float = plant.height
		var basis := Basis(Vector3.UP, plant.yaw).scaled(Vector3.ONE * height / asset.bounds.size.y)
		if plant.kind == "shrub":
			basis = basis.scaled(Vector3(1.32, 0.9, 1.32))
		_append(batches, asset, basis, plant.center, plant.tint)
	for prop in layout.rocks:
		var available: Array = variants.rock
		var asset: Dictionary = available[prop.variant % available.size()]
		var size: Vector3 = asset.bounds.size
		# Half the bounding box diagonal makes the logical disk conservative at any yaw.
		var diagonal := Vector2(size.x, size.z).length()
		var basis := Basis(Vector3.UP, prop.yaw).scaled(Vector3.ONE * (2.0 * prop.radius / diagonal))
		_append(batches, asset, basis, prop.center, 0.45, -0.025)
	for key in batches:
		var parent := rocks if key.begins_with("rock_") else vegetation
		_batch(parent, batches[key])
	for crossing in layout.crossings:
		if crossing.has("bridge"):
			_bridge(crossing.bridge)
	return {"plant_instances": layout.plants.size(), "rock_instances": layout.rocks.size(),
		"instance_batches": batches.size()}

func _load_variants() -> void:
	var trees := _meshes(TREE)
	variants["tree"] = [_entry("tree_00", trees[0], null)]
	var grass := _meshes(GRASS, "tiny_")
	var ferns := _meshes(FERNS)
	var stones := _meshes(ROCKS)
	for setting in [["grass", grass, GRASS_MASK], ["fern", ferns, FERN_MASK],
			["shrub", ferns, FERN_MASK], ["rock", stones, null]]:
		var kind: String = setting[0]
		variants[kind] = []
		for i in mini(setting[1].size(), 2 if kind != "rock" else 5):
			variants[kind].append(_entry("%s_%02d" % [kind, i], setting[1][i], setting[2]))

func _meshes(scene: PackedScene, filter: String = "") -> Array[Mesh]:
	var root := scene.instantiate()
	var result: Array[Mesh] = []
	for model: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if filter.is_empty() or filter in str(model.name):
			result.append(model.mesh)
	root.free()
	return result

func _entry(key: String, mesh: Mesh, mask: Texture2D) -> Dictionary:
	var material: ShaderMaterial
	var bounds := mesh.get_aabb()
	if mask != null:
		var source := mesh.surface_get_material(0) as StandardMaterial3D
		material = ShaderMaterial.new()
		material.shader = COVER
		material.set_shader_parameter("tex", source.albedo_texture)
		material.set_shader_parameter("coverage", mask)
		material.set_shader_parameter("blade_height", bounds.size.y)
	return {"key": key, "mesh": mesh, "material": material, "bounds": bounds}

func _append(batches: Dictionary, asset: Dictionary, basis: Basis, at: Vector2, tint: float, y: float = 0.0) -> void:
	var key: String = asset.key
	if not batches.has(key):
		batches[key] = {"asset": asset, "transforms": [], "colors": []}
	var bounds: AABB = asset.bounds
	var foot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	batches[key].transforms.append(Transform3D(basis, Vector3(at.x, y, at.y) - basis * foot))
	batches[key].colors.append(Color("#a7ad84").lerp(Color("#dce0a4"), tint))

func _batch(parent: Node3D, data: Dictionary) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = data.asset.material != null
	instances.mesh = data.asset.mesh
	instances.instance_count = data.transforms.size()
	for i in instances.instance_count:
		instances.set_instance_transform(i, data.transforms[i])
		if instances.use_colors:
			instances.set_instance_color(i, data.colors[i])
	var model := MultiMeshInstance3D.new()
	model.multimesh = instances
	model.material_override = data.asset.material
	if data.asset.material != null:
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A fixed preview-wide AABB avoids per-instance culling updates on regeneration.
	model.custom_aabb = AABB(Vector3(-65, -1, -65), Vector3(130, 10, 130))
	parent.add_child(model)

func _bridge(span: PackedVector2Array) -> void:
	var delta := span[1] - span[0]
	var center := (span[0] + span[1]) * 0.5
	var basis := Basis(Vector3.UP, atan2(delta.x, delta.y))
	var planks := BoxMesh.new()
	planks.size = Vector3(1.52, 0.10, 0.24)
	if bridge_material == null:
		bridge_material = StandardMaterial3D.new()
		bridge_material.albedo_color = Color("#634d37")
		bridge_material.roughness = 0.94
	planks.material = bridge_material
	var data := MultiMesh.new()
	data.transform_format = MultiMesh.TRANSFORM_3D
	data.mesh = planks
	data.instance_count = ceili(delta.length() / 0.29)
	for i in data.instance_count:
		var at := center + delta * ((i + 0.5) / data.instance_count - 0.5)
		data.set_instance_transform(i, Transform3D(basis, Vector3(at.x, 0.105 + 0.012 * sin(i * 1.89), at.y)))
	var decking := MultiMeshInstance3D.new()
	decking.multimesh = data
	crossings.add_child(decking)
	var beams := BoxMesh.new()
	beams.material = bridge_material
	beams.size = Vector3(0.12, 0.11, delta.length())
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.mesh = beams
		var offset: Vector2 = delta.normalized().orthogonal() * (side * 0.68)
		rail.transform = Transform3D(basis, Vector3(center.x + offset.x, 0.22, center.y + offset.y))
		crossings.add_child(rail)
