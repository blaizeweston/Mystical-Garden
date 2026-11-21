extends SceneTree
## Render-resource and boundary contracts; actual Garden travel is covered by
## experimental_terrain and experimental_terrain_coop.
const Canopy = preload("res://garden_canopy.gd")
const Catalog = preload("res://garden_canopy_catalog.gd")
const Boundary = preload("res://garden_boundary.gd")

var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL: ", label)

func ring(radius: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for i in 72:
		outline.append(Vector2.from_angle(TAU * i / 72.0) * radius)
	return outline

func run() -> void:
	for scene: PackedScene in Catalog.CROWNS:
		var donor := scene.instantiate()
		check(donor.find_children("*", "CollisionObject3D", true, false).is_empty()
			and donor.find_children("*", "AnimationPlayer", true, false).is_empty(), "foliage has no physics or animation")
		var meshes := donor.find_children("*", "MeshInstance3D", true, false)
		if donor is MeshInstance3D:
			meshes.append(donor)
		check(meshes.size() == 1, "each crown is one leaf-only mesh")
		for mesh: MeshInstance3D in meshes:
			var bounds := mesh.mesh.get_aabb()
			check(is_equal_approx(maxf(bounds.size.x, bounds.size.z), 1.0), "replaceable crowns have a one-metre horizontal span")
		donor.free()
	var canopy := Canopy.new()
	root.add_child(canopy)
	canopy.configure(ring(8.0))
	var initial := canopy.inspection()
	check(initial.chunks > 50 and initial.foliage_instances > initial.chunks
		and initial.full_tree_instances == 0, "bounded spatial batches replace the complete-tree forest")
	var image := Image.create(72, 1, false, Image.FORMAT_RGBAF)
	image.fill(Color(8, 11, 8, 0))
	var perimeter := ImageTexture.create_from_image(image)
	canopy.set_boundary(perimeter, image, 0.25)
	var identities: Array[int] = []
	for chunk in canopy.get_children():
		for visual: GeometryInstance3D in chunk.get_children():
			identities.append(visual.get_instance_id())
			check(visual.material_override.get_shader_parameter("garden_perimeter") == perimeter
				and is_equal_approx(visual.material_override.get_shader_parameter("garden_reveal"), 0.25), "all batches share the exact ground boundary and reveal")
			check(visual.custom_aabb.size.x > 0 and visual.custom_aabb.size.y > 0, "finite culling bounds include shader-displaced crowns")
	var fringe: MultiMeshInstance3D = canopy.get_node("CanopyFringe")
	check(fringe.multimesh.instance_count == 72, "leaf-only fringe follows each perimeter sample")
	var prior := canopy._fringe_pose(0).origin
	canopy.set_reveal(1.0)
	var end := canopy._fringe_pose(0).origin
	check(is_equal_approx(end.x - prior.x, 2.25), "fringe follows the shared boundary interpolation: %s -> %s" % [prior, end])
	canopy.set_clearing(ring(25.0))
	check(canopy.inspection().hidden_chunks > 0 and canopy.inspection().reveal == 1.0, "fully reclaimed chunks stop drawing")
	var retained: Array[int] = []
	for chunk in canopy.get_children():
		for visual in chunk.get_children():
			retained.append(visual.get_instance_id())
	check(retained == identities, "reclamation updates presentation without rebuilding meshes")
	var detached := canopy.inspection()
	detached.chunks = -1
	check(canopy.inspection().chunks == initial.chunks, "inspection is detached")
	var join := PackedVector2Array([Vector2(-5,-5), Vector2(5,-5), Vector2(5,5),
		Vector2(1,5), Vector2(1,0), Vector2(0,0), Vector2(0,5), Vector2(-5,5)])
	var rounded := Boundary.rounded_joins(join)
	check(rounded == Boundary.rounded_joins(join), "round joins deterministically")
	check(Geometry2D.clip_polygons(join, rounded).is_empty(), "rounding never removes previously reclaimed land")
	check(not Geometry2D.is_point_in_polygon(Vector2(0.5,1), join)
		and Geometry2D.is_point_in_polygon(Vector2(0.5,1), rounded), "rounding fills the sharp narrow expansion seam")
	check(Boundary.rounded_joins(PackedVector2Array()).is_empty(), "invalid boundary is unchanged")
	canopy.free()
	if errors == 0:
		print("PASS: foliage-only canopy, spatial culling, shared reveal and preserved rounded joins")
	quit(int(errors > 0))
