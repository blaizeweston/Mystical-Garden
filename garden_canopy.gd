extends Node3D
## Complete foliage crowns in two layers, with grounded trees along the clearing.
## Owns render resources only. The Garden supplies its sampled boundary in metres.
const Catalog = preload("res://garden_canopy_catalog.gd")
const CanopyShader = preload("res://assets/garden/canopy/garden_canopy.gdshader")

class FoliageBatch extends RefCounted:
	var view: MultiMeshInstance3D
	var poses: Array[Transform3D] = []

class ForestChunk extends Node3D:
	var footprint: Rect2
	var batches: Array[FoliageBatch] = []

class EdgeTree extends Node3D:
	var sample: float
	var row: int
	var variant: int
	var width: float
	var height: float
	var yaw: float

var _materials: Array[ShaderMaterial] = []
var _meshes: Array[Mesh] = []
var _bark_materials: Array[StandardMaterial3D] = []
var _tree_bounds: Array[AABB] = []
var _chunks: Array[ForestChunk] = []
var _trees: Array[EdgeTree] = []
var _radii := PackedFloat32Array()
var _boundary_image: Image
var _reveal := 1.0
var _maximum_radius := 0.0
var _patch_count := 0

func configure(initial_outline: PackedVector2Array) -> void:
	assert(get_child_count() == 0 and initial_outline.size() >= 3)
	for point in initial_outline:
		_radii.append(point.length())
	for i in Catalog.CROWNS.size():
		var donor: Node3D = Catalog.CROWNS[i].instantiate()
		var source: MeshInstance3D = donor if donor is MeshInstance3D else donor.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes.append(source.mesh)
		donor.free()
		_material(i, 1.0)
	for i in Catalog.CROWNS.size():
		_material(i, Catalog.LOWER_LAYER_BRIGHTNESS)
	var extent := ceili(Catalog.EXTERIOR_RADIUS_METRES / Catalog.CHUNK_SIZE_METRES)
	for x in range(-extent, extent):
		for z in range(-extent, extent):
			var centre := (Vector2(x, z) + Vector2.ONE * 0.5) * Catalog.CHUNK_SIZE_METRES
			if centre.length() <= Catalog.EXTERIOR_RADIUS_METRES:
				_chunk(x, z)
	_edge_trees()
	set_reveal(1.0)
	set_process(false)

func set_boundary(image: Image, reveal: float = 1.0) -> void:
	assert(image != null and image.get_width() == _radii.size())
	_boundary_image = image
	set_reveal(reveal)

func set_reveal(amount: float) -> void:
	_reveal = clampf(amount, 0.0, 1.0)
	var touched_radius := _maximum_radius
	_maximum_radius = 0.0
	for i in _radii.size():
		if _boundary_image != null:
			var ends := _boundary_image.get_pixel(i, 0)
			_radii[i] = lerpf(ends.r, ends.g, _reveal)
		_maximum_radius = maxf(_maximum_radius, _radii[i])
	touched_radius = maxf(touched_radius, _maximum_radius) + Catalog.PATCH_WIDTH_METRES
	for chunk in _chunks:
		# Distant chunks cannot intersect this reclaim operation. Leave their
		# buffers untouched; Godot culls chunks with their actual mesh bounds.
		if chunk.footprint.get_center().length() - chunk.footprint.size.length() * 0.5 > touched_radius:
			continue
		var visible_count := 0
		for batch in chunk.batches:
			var count := 0
			for base in batch.poses:
				var at := Vector2(base.origin.x, base.origin.z)
				var inner := _radius_at(at.angle()) + Catalog.PATCH_WIDTH_METRES * Catalog.CLEARING_CROWN_SETBACK_RATIO
				var amount_visible := smoothstep(inner, inner + Catalog.RECLAIM_FADE_METRES, at.length())
				if amount_visible <= 0.001:
					continue
				var pose := base
				pose.basis = pose.basis.scaled_local(Vector3.ONE * amount_visible)
				batch.view.multimesh.set_instance_transform(count, pose)
				count += 1
			batch.view.multimesh.visible_instance_count = count
			visible_count += count
		chunk.visible = visible_count > 0
	for tree in _trees:
		tree.transform = _tree_pose(tree)

func inspection() -> Dictionary:
	return {"chunks": _chunks.size(), "foliage_instances": _patch_count,
		"hidden_chunks": _chunks.filter(func(chunk): return not chunk.visible).size(),
		"full_tree_instances": _trees.size(), "boundary_samples": _radii.size(),
		"chunk_size_metres": Catalog.CHUNK_SIZE_METRES, "reveal": _reveal}

func _radius_at(angle: float) -> float:
	var sector := wrapf(angle / TAU, 0.0, 1.0) * _radii.size()
	var index := floori(sector)
	var step := TAU / _radii.size()
	var local := (sector - index) * step
	var a := _radii[index]
	var b := _radii[(index + 1) % _radii.size()]
	# The same ray/chord intersection used by the ground and movement boundary.
	return a * b * sin(step) / maxf(b * sin(step - local) + a * sin(local), 0.001)

func _foreground(at: Vector2) -> float:
	return smoothstep(0.18, 0.9, at.normalized().dot(Vector2(0.23, 0.973).normalized()))

func _material(variant: int, brightness: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = CanopyShader
	var values := {"leaf_map": Catalog.LEAF_MAPS[variant], "leaf_shadow": Catalog.LEAF_SHADOW,
		"leaf_midtone": Catalog.LEAF_MIDTONE, "leaf_highlight": Catalog.LEAF_HIGHLIGHT,
		"brightness": brightness, "alpha_cutoff": Catalog.LEAF_ALPHA_CUTOFF}
	for key in values:
		material.set_shader_parameter(key, values[key])
	_materials.append(material)

# A whole grid-row index selects each canopy sample.
@warning_ignore_start("integer_division")
func _chunk(x: int, z: int) -> void:
	var chunk := ForestChunk.new()
	chunk.name = "ForestChunk_%d_%d" % [x, z]
	chunk.footprint = Rect2(Vector2(x, z) * Catalog.CHUNK_SIZE_METRES, Vector2.ONE * Catalog.CHUNK_SIZE_METRES)
	add_child(chunk)
	_chunks.append(chunk)
	for layer in 2:
		var variant := posmod(x * 17 + z * 31 + layer, 3)
		if chunk.footprint.get_center().length() >= Catalog.DISTANT_DETAIL_START_METRES:
			variant = 3
		var mesh := _meshes[variant]
		var bounds := mesh.get_aabb()
		var batch := FoliageBatch.new()
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		var per_axis := ceili(Catalog.CHUNK_SIZE_METRES / Catalog.PATCH_SPACING_METRES)
		instances.instance_count = per_axis * per_axis
		var all_bounds := AABB()
		for i in instances.instance_count:
			var row: int = i / per_axis
			var cell := Catalog.CHUNK_SIZE_METRES / per_axis
			var phase := float(x * 117 + z * 53 + i * 29 + layer * 73)
			var at := chunk.footprint.position + Vector2(i % per_axis + 0.5, row + 0.5) * cell
			at += Vector2(sin(phase * 1.13), cos(phase * 0.79)) * 0.45 + Vector2.ONE * layer * cell * 0.5
			var width := Catalog.PATCH_WIDTH_METRES * (0.94 + 0.12 * sin(phase * 0.59))
			var height_ratio := lerpf(1.0, Catalog.FOREGROUND_HEIGHT_RATIO, _foreground(at))
			var size := Vector3(width / maxf(bounds.size.x, bounds.size.z), Catalog.PATCH_THICKNESS_METRES * height_ratio / bounds.size.y,
				width / maxf(bounds.size.x, bounds.size.z))
			var height := (Catalog.CANOPY_HEIGHT_METRES - layer * Catalog.LOWER_LAYER_DROP_METRES) * height_ratio
			height += Catalog.HEIGHT_VARIATION_METRES * sin(phase * 0.37)
			var pose := Transform3D(Basis(Vector3.UP, phase * 0.71).scaled_local(size), Vector3(at.x, height, at.y))
			batch.poses.append(pose)
			instances.set_instance_transform(i, pose)
			var local: AABB = pose * bounds
			all_bounds = local if i == 0 else all_bounds.merge(local)
		batch.view = MultiMeshInstance3D.new()
		batch.view.name = "UpperCrowns" if layer == 0 else "LowerCrowns"
		batch.view.multimesh = instances
		batch.view.material_override = _materials[variant + layer * Catalog.CROWNS.size()]
		batch.view.custom_aabb = all_bounds
		batch.view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.add_child(batch.view)
		chunk.batches.append(batch)
		_patch_count += instances.instance_count

@warning_ignore_restore("integer_division")
func _edge_trees() -> void:
	for variant in Catalog.TREES.size():
		var bark := StandardMaterial3D.new()
		bark.albedo_texture = Catalog.BARK_MAPS[variant]
		bark.albedo_color = Catalog.BARK_TINT
		bark.roughness = 0.96
		_bark_materials.append(bark)
		var donor: Node3D = Catalog.TREES[variant].instantiate()
		var bounds := AABB()
		for mesh: MeshInstance3D in donor.find_children("*", "MeshInstance3D", true, false):
			bounds = bounds.merge(mesh.transform * mesh.mesh.get_aabb())
		_tree_bounds.append(bounds)
		donor.free()
	for row in 2:
		for i in range(0, _radii.size(), 2):
			var tree := EdgeTree.new()
			tree.name = "ForestEdgeTree_%d_%d" % [row, i]
			tree.sample = i + row * 0.8 + sin(i * 1.71 + row) * 0.22
			tree.row = row
			tree.variant = posmod(i * 7 + row, Catalog.TREES.size())
			tree.width = Catalog.TREE_WIDTH_METRES * (0.92 + 0.16 * sin(i * 0.83 + row))
			tree.height = Catalog.TREE_HEIGHT_METRES + Catalog.TREE_HEIGHT_VARIATION_METRES * sin(i * 1.39 + row)
			tree.yaw = i * 2.39 + row
			var model: Node3D = Catalog.TREES[tree.variant].instantiate()
			model.name = "TreeModel"
			tree.add_child(model)
			model.get_node("Trunk").material_override = _bark_materials[tree.variant]
			model.get_node("Crown").material_override = _materials[tree.variant]
			add_child(tree)
			_trees.append(tree)

func _tree_pose(tree: EdgeTree) -> Transform3D:
	var angle := tree.sample * TAU / _radii.size()
	var offset := Catalog.TREE_EDGE_OFFSET_METRES + tree.row * Catalog.TREE_ROW_SPACING_METRES
	var at := Vector2.from_angle(angle) * (_radius_at(angle) + offset)
	var ratio := lerpf(1.0, Catalog.FOREGROUND_HEIGHT_RATIO, _foreground(at))
	var bounds := _tree_bounds[tree.variant]
	var width := tree.width * lerpf(1.0, 0.85, _foreground(at)) / maxf(bounds.size.x, bounds.size.z)
	return Transform3D(Basis(Vector3.UP, tree.yaw).scaled_local(Vector3(width, tree.height * ratio, width)), Vector3(at.x, 0, at.y))
