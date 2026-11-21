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
	for scene: PackedScene in Catalog.TREES:
		var donor:=scene.instantiate()
		check(donor.has_node("Trunk") and donor.has_node("Crown"), "tree models have separate complete trunks and crowns")
		var bounds:=AABB()
		for mesh: MeshInstance3D in donor.find_children("*","MeshInstance3D",true,false):
			bounds=bounds.merge(mesh.transform*mesh.mesh.get_aabb())
		check(absf(bounds.position.y)<0.001 and is_equal_approx(bounds.end.y,1.0), "tree replacements are grounded and normalized to one metre high")
		check(donor.find_children("*","CollisionObject3D",true,false).is_empty(), "visual trees add no competing collision")
		donor.free()
	var canopy := Canopy.new()
	root.add_child(canopy)
	canopy.configure(ring(8.0))
	var initial := canopy.inspection()
	check(initial.chunks > 50 and initial.foliage_instances > initial.chunks
		and initial.full_tree_instances==72, "spatial canopy batches and two irregular rows of real edge trees exist")
	var image := Image.create(72, 1, false, Image.FORMAT_RGBAF)
	image.fill(Color(8, 11, 8, 0))
	canopy.set_boundary(image, 0.25)
	var identities: Array[int] = []
	for child in canopy.get_children():
		check(child is Canopy.ForestChunk or child is Canopy.EdgeTree, "no solid roof or vertical skirt geometry remains")
		if child is Canopy.ForestChunk:
			check(child.batches.size()==2, "staggered foliage layers cover canopy gaps with actual leaves")
			for visual in child.get_children():
				check(visual is MultiMeshInstance3D, "canopy sections contain foliage batches, never backing planes")
				identities.append(visual.get_instance_id())
				check(visual.custom_aabb.size.x>0 and visual.custom_aabb.size.y>0, "culling bounds enclose complete foliage")
		else:
			check(is_zero_approx(child.position.y) and Vector2(child.position.x,child.position.z).length()>8.75, "edge trunks stand outside the playable clearing")
	var tree: Node3D=canopy.get_node("ForestEdgeTree_0_0")
	var prior:=tree.position
	canopy.set_reveal(1.0)
	check(is_equal_approx(tree.position.x-prior.x,2.25), "complete trees follow the same interpolated boundary as movement")
	image.fill(Color(25,25,25,0))
	canopy.set_boundary(image)
	check(canopy.inspection().hidden_chunks>initial.hidden_chunks, "reclaimed sections stop drawing without cutting crowns into walls")
	var retained: Array[int] = []
	for child in canopy.get_children():
		if child is Canopy.ForestChunk:
			for visual in child.get_children():retained.append(visual.get_instance_id())
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
		print("PASS: layered foliage without flat infill, complete grounded edge trees, shared reveal, spatial culling and rounded joins")
	quit(int(errors > 0))
