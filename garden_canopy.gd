extends Node3D
## Foliage-only forest roof. Owns render resources, never Garden gameplay state.
## Each spatial chunk has its own bounds so Godot can reject off-screen foliage.

const Catalog = preload("res://garden_canopy_catalog.gd")
const CanopyShader = preload("res://assets/garden/canopy/garden_canopy.gdshader")

class ForestChunk extends Node3D:
	var footprint: Rect2

var _materials: Array[ShaderMaterial] = []
var _meshes: Array[Mesh] = []
var _chunks: Array[ForestChunk] = []
var _patch_count := 0
var _chunk_count := 0
var _reveal := 1.0
var _boundary_samples := 0
var _boundary_image: Image
var _fringe: MultiMeshInstance3D

func configure(initial_outline: PackedVector2Array) -> void:
	assert(get_child_count() == 0 and initial_outline.size() >= 3)
	_boundary_samples = initial_outline.size()
	var mass := _material(0)
	for i in Catalog.CROWNS.size():
		var donor: Node3D = Catalog.CROWNS[i].instantiate()
		var source: MeshInstance3D = donor if donor is MeshInstance3D else donor.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes.append(source.mesh)
		donor.free()
		_material(1, Catalog.LEAF_MAPS[i])
	var extent: int = ceili(Catalog.EXTERIOR_RADIUS_METRES / Catalog.CHUNK_SIZE_METRES)
	for x in range(-extent, extent):
		for z in range(-extent, extent):
			var centre := (Vector2(x, z) + Vector2.ONE * 0.5) * Catalog.CHUNK_SIZE_METRES
			if centre.length() > Catalog.EXTERIOR_RADIUS_METRES:
				continue
			# Growth only expands. Chunks wholly inside the original clearing never
			# become forest again, so they need no geometry or instance buffers.
			var footprint := Rect2(Vector2(x, z) * Catalog.CHUNK_SIZE_METRES, Vector2.ONE * Catalog.CHUNK_SIZE_METRES)
			if _covered(footprint.grow(Catalog.PATCH_WIDTH_METRES * 0.5), initial_outline):
				continue
			_chunk(x, z, mass)
	_fringe = MultiMeshInstance3D.new()
	_fringe.name = "CanopyFringe"
	_fringe.multimesh = MultiMesh.new()
	_fringe.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_fringe.multimesh.mesh = _meshes[3]
	_fringe.multimesh.instance_count = _boundary_samples
	_fringe.material_override = _material(3, Catalog.LEAF_MAPS[3])
	_fringe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fringe.custom_aabb = AABB(Vector3(-35, 0, -35), Vector3(70, _height_range().y + 0.2, 70))
	add_child(_fringe)
	_edge(_material(2))
	set_process(false)

func set_boundary(perimeter: Texture2D, image: Image, reveal: float = 1.0) -> void:
	assert(image != null and image.get_width() == _boundary_samples)
	_boundary_image = image
	for material in _materials:
		material.set_shader_parameter("garden_perimeter", perimeter)
	set_reveal(reveal)

func set_reveal(amount: float) -> void:
	_reveal = clampf(amount, 0.0, 1.0)
	for material in _materials:
		material.set_shader_parameter("garden_reveal", _reveal)
	_update_fringe()

func set_clearing(outline: PackedVector2Array) -> void:
	# Run once at the end of reclamation or on a received layout, never per frame.
	# Shader clipping handles the brief reveal between those stable boundaries.
	for chunk in _chunks:
		chunk.visible = not _covered(chunk.footprint, outline)

func inspection() -> Dictionary:
	return {"chunks": _chunk_count, "foliage_instances": _patch_count,
		"edge_crowns": _boundary_samples,
		"hidden_chunks": _chunks.filter(func(chunk): return not chunk.visible).size(),
		"full_tree_instances": 0, "chunk_size_metres": Catalog.CHUNK_SIZE_METRES,
		"boundary_samples": _boundary_samples, "reveal": _reveal}

func _material(layer: int, texture: Texture2D = null) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CanopyShader
	var values := {"layer": layer, "leaf_shadow": Catalog.LEAF_SHADOW,
		"leaf_midtone": Catalog.LEAF_MIDTONE, "leaf_highlight": Catalog.LEAF_HIGHLIGHT,
		"undergrowth": Catalog.UNDERGROWTH, "bark_shadow": Catalog.BARK_SHADOW,
		"canopy_height": Catalog.CANOPY_HEIGHT_METRES, "foreground_ratio": Catalog.FOREGROUND_HEIGHT_RATIO,
		"height_variation": Catalog.HEIGHT_VARIATION_METRES, "edge_inset": Catalog.EDGE_INSET_METRES,
		"leaf_overhang": Catalog.LEAF_OVERHANG_METRES,
		"alpha_cutoff": Catalog.LEAF_ALPHA_CUTOFF}
	for parameter in values:
		material.set_shader_parameter(parameter, values[parameter])
	if texture != null:
		material.set_shader_parameter("leaf_map", texture)
	_materials.append(material)
	return material

func _covered(rect: Rect2, outline: PackedVector2Array) -> bool:
	var square := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])
	for corner in square:
		if not Geometry2D.is_point_in_polygon(corner, outline):
			return false
	return Geometry2D.clip_polygons(square, outline).is_empty()

func _height_range() -> Vector2:
	return Vector2(Catalog.CANOPY_HEIGHT_METRES * minf(1.0, Catalog.FOREGROUND_HEIGHT_RATIO) - absf(Catalog.HEIGHT_VARIATION_METRES),
		Catalog.CANOPY_HEIGHT_METRES * maxf(1.0, Catalog.FOREGROUND_HEIGHT_RATIO) + absf(Catalog.HEIGHT_VARIATION_METRES))

func _update_fringe() -> void:
	if _boundary_image == null:
		return
	# This small leaf-only lip hides the straight skirt. It follows the very same
	# interpolated perimeter during reclamation, with no trees or physics bodies.
	for i in _boundary_samples:
		_fringe.multimesh.set_instance_transform(i, _fringe_pose(i))

func _fringe_pose(index: int) -> Transform3D:
	var bounds := _meshes[3].get_aabb()
	var ends := _boundary_image.get_pixel(index, 0)
	var angle := TAU * index / _boundary_samples
	var radius := lerpf(ends.r, ends.g, _reveal) + Catalog.EDGE_CROWN_OFFSET_METRES
	var centre := Vector2.from_angle(angle) * radius
	var size := Vector3(Catalog.EDGE_CROWN_WIDTH_METRES / maxf(bounds.size.x, bounds.size.z),
		0.85 / bounds.size.y, Catalog.EDGE_CROWN_WIDTH_METRES / maxf(bounds.size.x, bounds.size.z))
	return Transform3D(Basis(Vector3.UP, angle * 7.0).scaled_local(size), Vector3(centre.x, 0, centre.y))

func _chunk(x: int, z: int, mass: ShaderMaterial) -> void:
	var node := ForestChunk.new()
	node.name = "ForestChunk_%d_%d" % [x, z]
	add_child(node)
	var low := Vector2(x, z) * Catalog.CHUNK_SIZE_METRES
	var top := MeshInstance3D.new()
	top.mesh = _roof(low)
	top.material_override = mass
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var heights := _height_range()
	top.custom_aabb = AABB(Vector3(low.x, heights.x, low.y), Vector3(Catalog.CHUNK_SIZE_METRES, heights.y - heights.x + 0.1, Catalog.CHUNK_SIZE_METRES))
	node.add_child(top)
	var variant := posmod(x * 17 + z * 31, 3)
	if (low + Vector2.ONE * Catalog.CHUNK_SIZE_METRES * 0.5).length() >= Catalog.DISTANT_DETAIL_START_METRES:
		variant = 3 # Background uses the 276-triangle bush crown, with no tree trunk.
	var mesh: Mesh = _meshes[variant]
	var bounds := mesh.get_aabb()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	var per_axis: int = ceili(Catalog.CHUNK_SIZE_METRES / Catalog.PATCH_SPACING_METRES)
	instances.instance_count = per_axis * per_axis
	var all_bounds := AABB()
	for i in instances.instance_count:
		var column := i % per_axis
		var row := i / per_axis
		var cell := Catalog.CHUNK_SIZE_METRES / per_axis
		var phase := float(x * 117 + z * 53 + i * 29)
		var centre := low + Vector2(column + 0.5, row + 0.5) * cell
		centre += Vector2(sin(phase * 1.13), cos(phase * 0.79)) * 0.3
		var width := Catalog.PATCH_WIDTH_METRES * (0.94 + 0.12 * sin(phase * 0.59))
		var size := Vector3(width / maxf(bounds.size.x, bounds.size.z),
			Catalog.PATCH_THICKNESS_METRES / bounds.size.y, width / maxf(bounds.size.x, bounds.size.z))
		var pose := Transform3D(Basis(Vector3.UP, phase * 0.71).scaled_local(size),
			Vector3(centre.x, Catalog.LEAF_LIFT_METRES, centre.y))
		instances.set_instance_transform(i, pose)
		var local: AABB = pose * bounds
		local.position.y += heights.x
		local.size.y += heights.y - heights.x
		all_bounds = local if i == 0 else all_bounds.merge(local)
	var leaves := MultiMeshInstance3D.new()
	leaves.multimesh = instances
	leaves.material_override = _materials[variant + 1]
	leaves.custom_aabb = all_bounds
	node.footprint = Rect2(Vector2(all_bounds.position.x, all_bounds.position.z), Vector2(all_bounds.size.x, all_bounds.size.z))
	_chunks.append(node)
	# Keep shadow work with the solid inner forest edge; overlapping leaf cards
	# don't need a second full set of shadow draws.
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(leaves)
	_patch_count += instances.instance_count
	_chunk_count += 1

func _roof(low: Vector2) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in 4:
		for z in 4:
			var a := low + Vector2(x, z) * Catalog.CHUNK_SIZE_METRES / 4.0
			var b := a + Vector2.RIGHT * Catalog.CHUNK_SIZE_METRES / 4.0
			var c := b + Vector2.DOWN * Catalog.CHUNK_SIZE_METRES / 4.0
			var d := a + Vector2.DOWN * Catalog.CHUNK_SIZE_METRES / 4.0
			for point: Vector2 in [a, b, c, a, c, d]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(point.x, 0, point.y))
	return surface.commit()

func _edge(material: ShaderMaterial) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in _boundary_samples:
		var a := float(i) / _boundary_samples
		var b := float(i + 1) / _boundary_samples
		for uv: Vector2 in [Vector2(a, 0), Vector2(b, 1), Vector2(b, 0), Vector2(a, 0), Vector2(a, 1), Vector2(b, 1)]:
			surface.set_uv(uv)
			surface.set_normal(Vector3(-cos(uv.x * TAU), 0, -sin(uv.x * TAU)))
			surface.add_vertex(Vector3.ZERO)
	var edge := MeshInstance3D.new()
	edge.name = "ContinuousForestEdge"
	edge.mesh = surface.commit()
	edge.material_override = material
	edge.custom_aabb = AABB(Vector3(-35, -0.2, -35), Vector3(70, _height_range().y + 0.4, 70))
	add_child(edge)
