extends Node3D
## Presentation lifetime is exactly one generated floor. No actor, RNG or save state.
const FOLIAGE = preload("res://assets/terrain_m02/wilds_foliage.gdshader")
const AIR = preload("res://assets/terrain_m02/wilds_air.gdshader")
const SurfaceArt = preload("res://assets/terrain_m02/wilds_surface_art.gd")
var materials := {}
var floaters: MultiMeshInstance3D
var observer_position := Vector2.INF
var observer_radius := INF

func build(features: Node3D, plants: Array, weights: Vector3, integrated: bool) -> void:
	for group: Node in [features.vegetation, features.rocks, features.boundary_view]:
		for batch: Node in group.get_children():
			var key := str(batch.get_meta("asset_key", ""))
			if not key.contains("botanical_") and not key.begins_with("scenic_grove_"): continue
			var type := "understory"
			if key.contains("tree_") or key.contains("sapling_") or key.begins_with("scenic_grove_"):
				type = "crown"
			elif key.contains("root_arch") or key.contains("fallen_timber"):
				type = "woody"
			elif key.begins_with("rock_"):
				continue
			elif key.contains("fungus"):
				type = "fungus"
			batch.material_override = foliage(type, weights)
	floaters = MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = QuadMesh.new()
	instances.instance_count = ceili(plants.size()/3.0)
	for index in instances.instance_count:
		var plant: Dictionary = plants[index*3]
		var at: Vector2 = plant.center
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY,Vector3(at.x,float(plant.get("elevation",0)),at.y)))
	floaters.multimesh = instances
	floaters.extra_cull_margin = 1.8
	floaters.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var air := ShaderMaterial.new()
	air.shader = AIR
	air.set_shader_parameter("climate", weights)
	floaters.material_override = air
	add_child(floaters)
	materials["air"] = air
	tune({})
	observe(Vector2.ZERO,0.0 if integrated else -1.0)

func foliage(type: String, weights: Vector3) -> ShaderMaterial:
	if not materials.has(type):
		var material := ShaderMaterial.new()
		material.shader = FOLIAGE
		material.set_shader_parameter("surface_tile", SurfaceArt.RELIEF)
		material.set_shader_parameter("climate", weights)
		for flag in ["crown","woody","fungus"]:
			material.set_shader_parameter(flag, type == flag)
		materials[type] = material
	return materials[type]

func tune(changes: Dictionary) -> void:
	if is_instance_valid(floaters):
		floaters.visible = changes.get("wilds.motes",SurfaceArt.CONTROLS["wilds.motes"][0]) > 0.0
	for type in materials:
		var material: ShaderMaterial = materials[type]
		var ids := ["motes"] if type == "air" else ["sway","wound","veil"]
		for property: String in ids:
			var id := "wilds." + property
			material.set_shader_parameter(property, changes.get(id, SurfaceArt.CONTROLS[id][0]))

func observe(at: Vector2, radius: float) -> void:
	if at == observer_position and radius == observer_radius: return
	observer_position = at
	observer_radius = radius
	for type in ["crown","air"]:
		if materials.has(type):
			materials[type].set_shader_parameter("observer", at)
			materials[type].set_shader_parameter("sight", radius)
