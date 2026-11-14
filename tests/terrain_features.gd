extends SceneTree

const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Layout = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Geometry = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Mask = preload("res://assets/terrain_m02/terrain_feature_mask.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Garden = preload("res://assets/terrain_m02/garden_clearing.tres")
const Wilds = preload("res://assets/terrain_m02/wilds_riverwood.tres")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const SPACING := 1.75
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: ", message)

func run() -> void:
	var signatures := {}
	for setting in [[117, 14, true], [241, 14, false], [517, 14, false], [823, 14, false], [241, 28, false]]:
		var seed_value: int = setting[0]
		var radius: int = setting[1]
		var garden: bool = setting[2]
		var cells := Generator.generate(seed_value, radius, Garden if garden else Wilds, Catalog)
		var layout := Layout.build(cells, SPACING, radius, seed_value, garden)
		var reversed := {}
		var keys := cells.keys()
		keys.reverse()
		for key in keys:
			reversed[key] = cells[key]
		var identity := Layout.digest(layout)
		check(identity == Layout.digest(Layout.build(reversed, SPACING, radius, seed_value, garden)),
			"same complete layout with reversed cell storage")
		check(not signatures.has(identity), "distinct example feature layouts")
		signatures[identity] = true
		_geometry(layout, cells, garden)
		_mask(layout, radius)
		print("M04_FEATURE_DIGEST ", seed_value, "/", radius, " ", identity)
	_scene()
	if not failed:
		print("PASS: bounded feature layouts, continuous water and trail queries, protected landmarks, stable seeds and preview layers")
	quit(1 if failed else 0)

func _geometry(layout: Dictionary, cells: Dictionary, garden: bool) -> void:
	var ids := {}
	for group in [layout.water, layout.clearings, layout.paths, layout.crossings, layout.rocks,
			layout.rock_formations, layout.stands, layout.plants]:
		for feature in group:
			check(not ids.has(feature.id), "feature ID is unique")
			ids[feature.id] = true
	for group in [layout.water, layout.paths, layout.crossings]:
		for feature in group:
			var outline := Geometry.boundary(feature)
			check(outline.size() >= 3 and not Geometry2D.triangulate_polygon(outline).is_empty(),
				"simple triangulable feature outline: " + feature.id)
	check(layout.water.size() == 1, "one connected water feature")
	var water: Dictionary = layout.water[0]
	if garden:
		check(Geometry.contains(layout.clearings[0], Vector2.ZERO) and not Geometry.contains(water, Vector2.ZERO), "Heart protected")
		check(water.kind == "pond" and layout.crossings.is_empty(), "Garden has its own pond and dry approach")
	else:
		check(layout.clearings.size() == 3 and layout.paths.size() == 2, "Wilds connects three open landmarks")
		check(layout.crossings.size() == 1 and layout.crossings[0].has("bridge"), "one explicit river crossing")
		var heights: PackedFloat32Array = water.half_widths.duplicate()
		heights.sort()
		check(heights[-1] - heights[0] > 0.50 and water.spine.size() >= 40, "variable river width and long spine")
		for point in water.spine:
			check(Geometry.contains(water, point), "connected river contains its centerline")
	for clearing in layout.clearings:
		check(not Geometry.in_any(layout.water, clearing.center, clearing.radius), "clearing stays dry")
	var endpoint_ids := {}
	for path in layout.paths:
		var points: PackedVector2Array = path.spine
		for endpoint in [points[0], points[-1]]:
			for clearing in layout.clearings:
				if Geometry.contains(clearing, endpoint):
					endpoint_ids[clearing.id] = true
			check(Geometry.in_any(layout.clearings, endpoint), "trail begins and ends at openings")
		for point in points:
			if Geometry.contains(water, point):
				check(Geometry.in_any(layout.crossings, point, 0.025), "each wet path region has a defined crossing")
	check(endpoint_ids.size() == layout.clearings.size(), "each clearing participates in trail network")
	for i in layout.rocks.size():
		var rock: Dictionary = layout.rocks[i]
		check(not Geometry.in_any(layout.water + layout.paths + layout.clearings, rock.center, rock.radius),
			"rock footprint respects water, paths and clearings")
		for j in range(i):
			var other: Dictionary = layout.rocks[j]
			check(rock.center.distance_to(other.center) >= rock.radius + other.radius, "major obstacle disks do not overlap")
	for formation in layout.rock_formations:
		check(cells.get(formation.cell) == &"stone", "formation associated with stone")
	for stand in layout.stands:
		check(stand.cells.size() >= 2, "stand spans multiple hexes")
		var reached := {stand.cells[0]: true}
		var pending: Array[Vector2i] = [stand.cells[0]]
		var index := 0
		while index < pending.size():
			var cell := pending[index]
			index += 1
			check(cells.get(cell) == &"forest_floor", "stand sits on forest floor")
			for direction in Grid.NEIGHBORS:
				var neighbor := cell + direction
				if not reached.has(neighbor) and cells.get(neighbor) == &"forest_floor":
					reached[neighbor] = true
					pending.append(neighbor)
		check(reached.size() == stand.cells.size(), "stand is an entire connected forest-floor region")
	var kinds := {}
	for plant in layout.plants:
		kinds[plant.kind] = true
		check(not Geometry.in_any(layout.water + layout.clearings + layout.paths, plant.center),
			"vegetation never occupies open footprints")
		if plant.kind == "tree":
			check(not Geometry.in_any(layout.clearings + layout.paths, plant.center, plant.clearance),
				"tree crowns avoid key open areas")
	for kind in ["tree", "shrub", "fern", "grass"]:
		check(kinds.has(kind), "example contains " + kind)

func _mask(layout: Dictionary, radius: int) -> void:
	var atlas := Mask.bake(layout, SPACING, radius)
	var data: PackedByteArray = atlas.image.get_data()
	var step: Vector2 = atlas.frame.size / (Vector2(atlas.size) - Vector2.ONE)
	var stride := 3 if radius == 14 else 7
	for y in range(0, atlas.size.y, stride):
		for x in range(0, atlas.size.x, stride):
			var point: Vector2 = atlas.frame.position + Vector2(x, y) * step
			for channel in 2:
				var nearest := Mask.MAX_DISTANCE
				var group: Array = layout.water if channel == 0 else layout.paths
				for feature in group:
					nearest = minf(nearest, Geometry.signed_distance(feature, point, Mask.MAX_DISTANCE))
				var texel: int = data[(y * atlas.size.x + x) * 3 + channel]
				var decoded := (texel / 127.5 - 1.0) * Mask.MAX_DISTANCE
				check(absf(nearest - decoded) <= 0.012, "render distance matches query at texel center")

func _scene() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	var digest := Layout.digest(scene.feature_layout)
	var mesh := (scene.get_node("Ground") as MeshInstance3D).mesh
	var vegetation: CheckButton = scene.get_node("%VegetationLayer")
	var rocks: CheckButton = scene.get_node("%RockLayer")
	var water: CheckButton = scene.get_node("%WaterLayer")
	var paths: CheckButton = scene.get_node("%PathLayer")
	var ground: CheckButton = scene.get_node("%GroundLayer")
	for layer in [vegetation, rocks, water, paths, ground]:
		layer.button_pressed = false
	check(not scene.feature_view.vegetation.visible and not scene.feature_view.rocks.visible and not scene.feature_view.crossings.visible,
		"scene feature toggles hide visible batches")
	check(not scene.natural_material.get_shader_parameter("show_ground")
		and not scene.natural_material.get_shader_parameter("show_water")
		and not scene.natural_material.get_shader_parameter("show_paths"), "material layer toggles apply")
	var selector: OptionButton = scene.get_node("%Rendering")
	for mode in [2, 3, 1, 0]:
		selector.select(mode)
		selector.item_selected.emit(mode)
		check(Layout.digest(scene.feature_layout) == digest and scene.get_node("Ground").mesh == mesh,
			"comparison and toggles preserve shared geometry and logical features")
		check(scene.feature_view.visible == (mode <= 1), "older presentation hides feature instances")
	scene.free()
