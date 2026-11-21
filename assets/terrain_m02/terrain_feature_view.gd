extends Node3D
## One MultiMesh per repeated asset variant. Collision stays outside the preview.

const CoverShape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const RootMeshes = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const Art = preload("res://assets/terrain_m02/terrain_art_direction.gd")
const Habitat = preload("res://assets/terrain_m02/wilds_habitat_mesh.gd")
const BoundaryMesh = preload("res://assets/terrain_m02/wilds_boundary_mesh.gd")
const MassMesh = preload("res://assets/terrain_m02/wilds_massing_mesh.gd")
const TREE := preload("res://assets/root_tree.glb")
const FERNS := preload("res://assets/garden/field/fern_02.glb")
const GRASS := preload("res://assets/garden/field/grass_medium_01.glb")
const ROCKS := preload("res://assets/garden/field/mossy_stones.glb")
const COVER := preload("res://assets/shaders/garden_ground_cover.gdshader")
const GRASS_MASK := preload("res://assets/garden/field/grass_opacity.png")
const FERN_MASK := preload("res://assets/garden/field/fern_opacity.png")

var variants := {}
var botanical_variants := {}
var botanical_material: StandardMaterial3D
var bridge_material: StandardMaterial3D
var vegetation: Node3D
var rocks: Node3D
var crossings: Node3D
var massing: Node3D
var boundary_view: Node3D
var landmark_material: StandardMaterial3D

func _ready() -> void:
	vegetation = _group("Vegetation")
	rocks = _group("Rocks")
	crossings = _group("Crossings")
	massing = _group("Massing")
	boundary_view = _group("Boundary")

func _group(label: String) -> Node3D:
	var group := Node3D.new()
	group.name = label
	add_child(group)
	return group

func rebuild(layout: Dictionary, profile: Dictionary = {}, biome: int = 0, wilds: bool = false,
		integrated_wilds: bool = false) -> Dictionary:
	_ensure_botanical_material()
	var assets := variants
	if not wilds:
		if profile.is_empty():
			if variants.is_empty():
				_load_variants()
		else:
			if not botanical_variants.has(biome):
				botanical_variants[biome] = _make_botanicals(profile, biome)
			assets = botanical_variants[biome]
	for group in [vegetation, rocks, crossings, massing, boundary_view]:
		for child in group.get_children():
			child.free()
	var batches := {}
	for plant in layout.plants:
		var variant_set := _wilds_assets(plant.family) if wilds else assets
		var options: Array = variant_set[plant.kind]
		var asset: Dictionary = options[plant.variant % options.size()]
		var height: float = plant.height
		var instance_basis := Basis(Vector3.UP, plant.yaw).scaled(Vector3.ONE * height / asset.bounds.size.y)
		if plant.kind == "shrub":
			instance_basis = instance_basis.scaled(Vector3(1.32, 0.9, 1.32))
		_append(batches, asset, instance_basis, plant.center, plant.tint, plant.get("elevation", 0.0))
	for prop in layout.rocks:
		var variant_set := _wilds_assets(prop.family) if wilds else assets
		var available: Array = variant_set[prop.kind] if wilds else variant_set.rock
		var asset: Dictionary = available[prop.variant % available.size()]
		var size: Vector3 = asset.bounds.size
		# Half the bounding box diagonal makes the logical disk conservative at any yaw.
		var diagonal := Vector2(size.x, size.z).length()
		var instance_basis := Basis(Vector3.UP, prop.yaw).scaled(Vector3.ONE * (2.0 * prop.radius / diagonal))
		if prop.get("cover_role") == CoverShape.LOW_RUBBLE:
			instance_basis = instance_basis.scaled(Vector3(1.0, 0.50, 1.0))
		_append(batches, asset, instance_basis, prop.center, 0.45, -0.025)
	for key in batches:
		var parent := rocks if key.begins_with("rock_") else vegetation
		_batch(parent, batches[key])
	for crossing in layout.crossings:
		if crossing.has("bridge"):
			_bridge(crossing.bridge, wilds)
	if layout.has("masses"):
		for wall in layout.masses:
			var view := MeshInstance3D.new()
			view.mesh = MassMesh.mesh(wall, layout.seed)
			view.material_override = botanical_material
			massing.add_child(view)
		var gate_position: Vector2 = layout.trail_network.nodes.exit_gate
		var gate_yaw := 0.0
		if layout.has("hydrology"):
			for i in layout.paths.size():
				var edge: Dictionary = layout.trail_network.edges[i]
				if edge.to != "exit_gate" and edge.from != "exit_gate":
					continue
				var spine: PackedVector2Array = layout.paths[i].spine
				var approach := spine[-3] if edge.to == "exit_gate" else spine[2]
				var heading := (approach - gate_position).normalized()
				gate_yaw = atan2(heading.x, heading.y)
				break
		_gate(gate_position, gate_yaw)
	if layout.has("boundary"):
		_build_boundary(layout.boundary, layout.seed, integrated_wilds)
	return {"plant_instances": layout.plants.size(), "rock_instances": layout.rocks.size(),
		"instance_batches": batches.size()}

func _build_boundary(border: Dictionary, seed_value: int, integrated_wilds: bool) -> void:
	var verge := MeshInstance3D.new()
	verge.mesh = BoundaryMesh.build(border, seed_value, integrated_wilds)
	verge.material_override = botanical_material
	boundary_view.add_child(verge)
	var batches := {}
	for prop in border.exterior_props:
		var variant_set := _wilds_assets(prop.family)
		var assets: Array = variant_set[prop.kind]
		var asset: Dictionary = assets[prop.variant % assets.size()]
		if integrated_wilds and prop.family == 0 and prop.kind == "tree":
			asset = _scenic_grove_tree(prop.variant)
		var bounds: AABB = asset.bounds
		var effect_scale: float = prop.height / bounds.size.y
		if prop.kind == "root_arch":
			effect_scale *= 0.66
		var instance_basis := Basis(Vector3.UP, prop.yaw).scaled(Vector3.ONE * effect_scale)
		_append(batches, asset, instance_basis, prop.center, prop.tint)
	for key in batches:
		_batch(boundary_view, batches[key])
		var view := boundary_view.get_child(-1) as MultiMeshInstance3D
		view.custom_aabb = AABB()
		if integrated_wilds:
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _scenic_grove_tree(variant: int) -> Dictionary:
	var key := "scenic_grove_%d" % variant
	if not botanical_variants.has(key):
		var mesh := RootMeshes.botanical(variant, "tree", Art.profile(1), 1, true)
		mesh.surface_set_material(0, botanical_material)
		botanical_variants[key] = _entry(key, mesh, null)
	return botanical_variants[key]

func _gate(at: Vector2, yaw: float) -> void:
	if landmark_material == null:
		landmark_material = StandardMaterial3D.new()
		landmark_material.vertex_color_use_as_albedo = true
		landmark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		landmark_material.roughness = 0.82
	var view := MeshInstance3D.new()
	view.mesh = MassMesh.gate()
	view.material_override = landmark_material
	view.position = Vector3(at.x, 0.0, at.y)
	view.rotation.y = yaw
	view.name = "ExitGate"
	massing.add_child(view)

func _wilds_assets(family: int) -> Dictionary:
	var key := family + 4
	if not botanical_variants.has(key):
		botanical_variants[key] = _make_botanicals(Art.profile(family + 1), family + 1, family)
	return botanical_variants[key]

func _make_botanicals(profile: Dictionary, biome: int, family: int = -1) -> Dictionary:
	_ensure_botanical_material()
	var result := {}
	var kinds := ["tree", "sapling", "shrub", "fern", "grass", "rock"]
	if biome == 3:
		kinds.append("wine_fern")
	if family == 1:
		kinds.append_array(["reed", "fallen_timber"])
	elif family == 2:
		kinds.append_array(["fungus", "root_arch"])
	for kind in kinds:
		var options: Array[Dictionary] = []
		for i in (4 if kind == "rock" else 3):
			var mesh: ArrayMesh
			match kind:
				"tree", "sapling":
					mesh = RootMeshes.botanical(i, kind, profile, biome) if family <= 0 else Habitat.tree(i, family, profile)
				"rock": mesh = RootMeshes.basalt(i, profile)
				"reed", "fungus", "fallen_timber", "root_arch": mesh = Habitat.prop(kind, i, profile)
				_: mesh = RootMeshes.understory(kind, i, profile)
			mesh.surface_set_material(0, botanical_material)
			if kind == "fungus":
				var luminous := botanical_material.duplicate() as StandardMaterial3D
				luminous.emission_enabled = true
				luminous.emission = Color("#54426d")
				luminous.emission_energy_multiplier = 0.22
				mesh.surface_set_material(0, luminous)
			var stone: bool = kind in ["rock", "fallen_timber", "root_arch"]
			var key: String = ("rock_botanical_" if kind == "rock" else "botanical_" + kind + "_") + str(i)
			if stone and kind != "rock":
				key = "rock_" + key
			if family >= 0:
				key += "_family_" + str(family)
			var entry := _entry(key, mesh, null)
			entry["ground_cover"] = kind in ["shrub", "fern", "wine_fern", "grass", "fungus", "reed"]
			options.append(entry)
		result[kind] = options
	return result

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

func _append(batches: Dictionary, asset: Dictionary, instance_basis: Basis, at: Vector2, tint: float, y: float = 0.0) -> void:
	var key: String = asset.key
	if not batches.has(key):
		batches[key] = {"asset": asset, "transforms": [], "colors": []}
	var bounds: AABB = asset.bounds
	var foot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	batches[key].transforms.append(Transform3D(instance_basis, Vector3(at.x, y, at.y) - instance_basis * foot))
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
	model.set_meta("asset_key", data.asset.key)
	model.multimesh = instances
	model.material_override = data.asset.material
	if data.asset.material != null or data.asset.get("ground_cover", false):
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A fixed preview-wide AABB avoids per-instance culling updates on regeneration.
	model.custom_aabb = AABB(Vector3(-65, -1, -65), Vector3(130, 10, 130))
	parent.add_child(model)

func _bridge(span: PackedVector2Array, full_deck: bool) -> void:
	var delta := span[1] - span[0]
	var center := (span[0] + span[1]) * 0.5
	var instance_basis := Basis(Vector3.UP, atan2(delta.x, delta.y))
	var planks := BoxMesh.new()
	var count := ceili(delta.length() / 0.29)
	var pitch := delta.length() / count
	planks.size = Vector3(1.52, 0.10, pitch if full_deck else 0.24)
	if bridge_material == null:
		bridge_material = StandardMaterial3D.new()
		bridge_material.albedo_color = Color("#634d37")
		bridge_material.roughness = 0.94
	planks.material = bridge_material
	var data := MultiMesh.new()
	data.transform_format = MultiMesh.TRANSFORM_3D
	data.mesh = planks
	data.instance_count = count
	for i in data.instance_count:
		var at := center + delta * ((i + 0.5) / data.instance_count - 0.5)
		data.set_instance_transform(i, Transform3D(instance_basis, Vector3(at.x, 0.105 + 0.012 * sin(i * 1.89), at.y)))
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
		rail.transform = Transform3D(instance_basis, Vector3(center.x + offset.x, 0.22, center.y + offset.y))
		crossings.add_child(rail)

func _ensure_botanical_material() -> void:
	if botanical_material == null:
		botanical_material = StandardMaterial3D.new()
		botanical_material.vertex_color_use_as_albedo = true
		botanical_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		botanical_material.roughness = 0.96
