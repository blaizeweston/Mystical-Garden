extends RefCounted

const MaterialField = preload("res://assets/terrain_m02/terrain_material_field.gd")
const FeatureMask = preload("res://assets/terrain_m02/terrain_feature_mask.gd")
const Features = preload("res://assets/terrain_m02/terrain_feature_view.gd")
const Boundary = preload("res://assets/terrain_m02/wilds_boundary.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")

static func material(cells: Dictionary, layout: Dictionary, seed_value: int, radius: int, spacing: float) -> ShaderMaterial:
	var result := MaterialField.material(MaterialField.bake(cells), spacing, seed_value, Catalog)
	FeatureMask.bind(result, FeatureMask.bake(layout, spacing, radius))
	for flag: String in ["show_ground", "show_water", "show_paths", "feature_mode", "continuity_mode", "botanical_mode", "scenic_exterior"]:
		result.set_shader_parameter(flag, true)
	return result

static func plane(parent: Node3D, surface: ShaderMaterial, extent: float) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	var ground := PlaneMesh.new()
	ground.size = Vector2.ONE * extent * 2.0
	model.mesh = ground
	model.material_override = surface
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(model)
	return model

static func draw_wilds(parent: Node3D, offset: Vector3, data: Dictionary, seed_value: int) -> void:
	var wild := Node3D.new()
	wild.position = offset
	parent.add_child(wild)
	var shade := material(data.substrate, data.layout, seed_value, 14, 1.75)
	var climate: Dictionary = data.climate
	var weights: Vector3 = climate.weights
	shade.set_shader_parameter("wilds_mode", true)
	shade.set_shader_parameter("wilds_moisture", climate.moisture)
	shade.set_shader_parameter("wilds_floor", climate.floor)
	shade.set_shader_parameter("wilds_water", climate.wet)
	shade.set_shader_parameter("botanical_ground", climate.ground)
	shade.set_shader_parameter("botanical_water", climate.water)
	shade.set_shader_parameter("scenic_cover", Vector3(0.2, 0.7, 0.1) * weights.x
		+ Vector3(0.74, 0.22, 0.04) * weights.y + Vector3(0.20, 0.14, 0.66) * weights.z)
	plane(wild, shade, Boundary.exterior_extent(14, 1.75, parent.get_viewport().get_visible_rect().size))
	var features := Features.new()
	wild.add_child(features)
	features.rebuild(data.layout, {}, 0, true)
