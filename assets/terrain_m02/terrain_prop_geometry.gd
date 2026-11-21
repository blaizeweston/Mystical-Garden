extends RefCounted
## Shared visual mesh/pose definitions and cached walking footprints. No world state.
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Roots = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const Habitat = preload("res://assets/terrain_m02/wilds_habitat_mesh.gd")
const Art = preload("res://assets/terrain_m02/terrain_art_direction.gd")
const STEP_OVER_HEIGHT_M := 0.18 # Only low terrain stones; never structures or authored walls.
const TRUNK_BAND := Vector2(0.10, 0.30) # Fraction of visual height, below branches and above low roots.
static var _templates := {}

static func mesh(kind: String, variant: int, profile: Dictionary, biome: int, family: int) -> ArrayMesh:
	match kind:
		"tree", "sapling": return Roots.botanical(variant, kind, profile, biome) if family <= 0 else Habitat.tree(variant, family, profile)
		"rock": return Roots.basalt(variant, profile)
		"reed", "fungus", "fallen_timber", "root_arch": return Habitat.prop(kind, variant, profile)
		_: return Roots.understory(kind, variant, profile)

static func plant_basis(prop: Dictionary, bounds: AABB) -> Basis:
	var result := Basis(Vector3.UP, prop.yaw).scaled(Vector3.ONE * float(prop.height) / bounds.size.y)
	if prop.kind == "shrub": result = result.scaled(Vector3(1.32, 0.9, 1.32))
	return result

static func rock_basis(prop: Dictionary, bounds: AABB) -> Basis:
	var diagonal := Vector2(bounds.size.x, bounds.size.z).length()
	var result := Basis(Vector3.UP, prop.yaw).scaled(Vector3.ONE * (2.0 * float(prop.radius) / diagonal))
	if prop.get("cover_role") == Shape.LOW_RUBBLE: result = result.scaled(Vector3(1.0, 0.50, 1.0))
	return result

static func placed_pose(bounds: AABB, instance_basis: Basis, at: Vector2, elevation: float = 0.0) -> Transform3D:
	var foot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	return Transform3D(instance_basis, Vector3(at.x, elevation, at.y) - instance_basis * foot)

static func actor_shape(prop: Dictionary) -> Dictionary:
	var tree: bool = prop.kind in ["tree", "sapling"]
	# Explicit authored collision fixtures have no visual variant. Keep their
	# supplied geometry instead of guessing a model or silently discarding cover.
	if not prop.has("variant") or prop.kind not in ["tree", "sapling", "rock", "fallen_timber", "root_arch"]:
		return Shape.disk(prop.id, "trunk", prop.center, float(prop.height) * 0.105) if tree else prop.duplicate(true)
	var family: int = int(prop.get("family", -1))
	var biome: int = family + 1
	var variant: int = int(prop.variant) % (4 if prop.kind == "rock" else 3)
	var key := str([prop.kind, variant, family])
	if not _templates.has(key):
		var source := mesh(prop.kind, variant, Art.profile(biome), biome, family)
		var bounds := source.get_aabb()
		var lower := bounds.position.y + bounds.size.y * TRUNK_BAND.x if tree else -INF
		var upper := bounds.position.y + bounds.size.y * TRUNK_BAND.y if tree else INF
		_templates[key] = {"bounds":bounds,"outline":Shape.mesh_outline(source,lower,upper)}
	var template: Dictionary = _templates[key]
	var instance_basis := plant_basis(prop, template.bounds) if tree else rock_basis(prop, template.bounds)
	var pose := placed_pose(template.bounds, instance_basis, prop.center, float(prop.get("elevation",0.0)) if tree else -0.025)
	var points := PackedVector2Array()
	for point: Vector2 in template.outline:
		var world_point := pose * Vector3(point.x, 0.0, point.y)
		points.append(Vector2(world_point.x, world_point.z))
	var result := Shape.shape(prop.id, "trunk" if tree else str(prop.kind), points)
	var height_m: float = template.bounds.size.y * instance_basis.y.length() - (0.0 if tree else 0.025)
	result["visual_height_m"] = height_m
	result["step_over"] = not tree and prop.kind == "rock" and height_m <= STEP_OVER_HEIGHT_M
	return result
