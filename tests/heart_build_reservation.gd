extends SceneTree
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const Heart = preload("res://assets/terrain_m02/terrain_heart_preview.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Placement = preload("res://tests/support/garden_placement_case.gd")
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; printerr("FAIL Heart reservation: ", message)
func run() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	await process_frame
	var view = scene.expansion
	view.knowledge.set_sandbox(true)
	var model = view.construction.model
	var footprint := Heart.maximum_build_outline()
	check(footprint.size() >= 3 and Geometry2D.triangulate_polygon(footprint).size() > 0, "maximum model has a valid full-canopy footprint")
	var sculpt := Heart.SCULPT.instantiate() as Node3D
	var mature := sculpt.get_node("HeartStage5") as MeshInstance3D
	var ids: Array = Heart.Research.DEFINITIONS.map(func(entry): return entry.id)
	mature.position = Vector3.ZERO
	mature.scale = Heart.research_scale(Heart.Growth.count(ids))
	var pose := sculpt.transform * mature.transform
	for surface in mature.mesh.get_surface_count():
		var vertices: PackedVector3Array = mature.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var at := pose * vertex
			if Shape.polygon_distance(footprint, Vector2(at.x, at.z)) > 0.0001:
				check(false, "all final-stage vertices at maximum research remain within the reservation")
				break
	var issue: Dictionary = model.placement_issue("bed", Vector2(4.7, -3), 0.0, view.pawn)
	check(issue.get("blocker", {}).get("id") == "heart" and issue.blocker.outline == footprint
		and not issue.blocker.has("radius"), "real placement uses the model silhouette beyond the old circular clearing")
	var outside := Placement.find(model, "bed", Vector2(3.5, 5), 0.0, view.pawn)
	check(outside.is_finite() and model.validate("bed", outside, 0.0, view.pawn).is_empty(), "usable space beyond the canopy remains buildable")
	var saved := footprint.duplicate()
	footprint[0] = Vector2.INF
	check(Heart.maximum_build_outline() == saved, "public footprint views cannot mutate the cached source")
	sculpt.free()
	scene.free()
	if not failed: print("PASS: full-canopy maximum-Heart reservation, actual geometry coverage, outside placement and detached cache")
	quit(1 if failed else 0)
