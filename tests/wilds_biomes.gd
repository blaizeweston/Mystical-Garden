extends SceneTree

const Climate = preload("res://assets/terrain_m02/wilds_biome.gd")
const Wilds = preload("res://assets/terrain_m02/wilds_preview_generation.gd")
const Geography = preload("res://assets/terrain_m02/wilds_geography.gd")
const Geometry = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Layout = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Mask = preload("res://assets/terrain_m02/terrain_feature_mask.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures <= 20:
			printerr("FAIL: ", message)

func run() -> void:
	_weights()
	var previous := {}
	for floor_number in range(1, 19):
		var map := Wilds.build(241, floor_number, 14, 1.75, Catalog)
		_check(not map.is_empty(), "reference floor is generated")
		if map.is_empty():
			continue
		_geometry(map, 14, 1.75)
		if not previous.is_empty():
			var changed := 0
			for cell in map.cells:
				changed += int(map.cells[cell] != previous.cells[cell])
			_check(changed < map.cells.size() * 0.34 and map.layout.water != previous.layout.water,
				"adjacent floors keep most of their terrain while varying the shoreline: %d changed %d" % [floor_number, changed])
			var center: Vector2 = map.layout.trail_network.nodes.west_bank
			_check(center.distance_to(previous.layout.trail_network.nodes.west_bank) < 3.0,
				"bridge landing shifts gradually across adjacent floors: %d moved %.2f" % [
					floor_number, center.distance_to(previous.layout.trail_network.nodes.west_bank)])
		previous = map
	_distinct()
	_corpus()
	_scene()
	if failures == 0:
		print("PASS: all Wilds climate bands, bounded repair, stable topology, habitat footprints and real preview floor selection")
	quit(0 if failures == 0 else 1)

func _weights() -> void:
	var expected := {1: Vector3(1,0,0), 5: Vector3(1,0,0), 6: Vector3(.75,.25,0),
		7: Vector3(.25,.75,0), 8: Vector3(0,1,0), 9: Vector3(0,1,0), 11: Vector3(0,1,0),
		12: Vector3(0,.75,.25), 13: Vector3(0,.25,.75), 14: Vector3(0,0,1), 18: Vector3(0,0,1)}
	for floor_number in range(1, 19):
		var weights := Climate.weights(floor_number)
		_check(weights.abs() == weights and is_equal_approx(weights.x + weights.y + weights.z, 1.0), "weights are normalized")
		_check(Climate.floor_biome(floor_number) == int((floor_number - 1) / 6.0), "six-floor gameplay bands")
		if expected.has(floor_number):
			_check(weights.is_equal_approx(expected[floor_number]), "default window follows half cosine")
		if floor_number in [6, 7, 8, 12, 13, 14]:
			var lower := Climate.climate(floor_number - 1)
			var here := Climate.climate(floor_number)
			for field in ["moisture", "width", "pools", "forest", "ground_cover", "stone_cover",
					"sun_energy", "ambient_energy", "haze"]:
				var range_value: float = absf(Climate.PROFILES[here.biome][field] - Climate.PROFILES[lower.biome][field])
				# The full interval bound applies even on a non-boundary gameplay floor.
				range_value = maxf(range_value, absf(Climate.PROFILES[0][field] - Climate.PROFILES[1][field]))
				range_value = maxf(range_value, absf(Climate.PROFILES[1][field] - Climate.PROFILES[2][field]))
				_check(absf(here[field] - lower[field]) <= range_value * 0.501, "adjacent climate step is bounded")
	var custom := [Vector2i(4, 8), Vector2i(10, 16)]
	_check(Climate.weights(6, custom).is_equal_approx(Vector3(.5,.5,0)), "configurable transition spans")
	_check(Climate.family(Vector3(.75,.25,0), .68) == 0 and Climate.family(Vector3(.25,.75,0), .68) == 1,
		"a fixed position roll follows the family weights")

func _distinct() -> void:
	var central: Array[Dictionary] = []
	for floor_number in [1, 9, 18]:
		var map := Wilds.build(241, floor_number, 14, 1.75, Catalog)
		if map.is_empty():
			_check(false, "central biomes build")
			return
		var another := Wilds.build(517, floor_number, 14, 1.75, Catalog)
		var repeated := Wilds.build(241, floor_number, 14, 1.75, Catalog)
		_check(repeated == map, "identical seed, floor and scale reproduce the entire map")
		_check(not another.is_empty() and another.layout.water != map.layout.water
			and another.layout.trail_network != map.layout.trail_network, "a different seed changes geography and trails")
		central.append(map)
		var kinds := {}
		for feature in map.layout.plants + map.layout.rocks:
			kinds[feature.kind] = kinds.get(feature.kind, 0) + 1
		print("M07_HABITAT ", floor_number, " ", kinds, " ", Layout.digest(map.layout))
		if floor_number == 9:
			_check(kinds.has("reed") and kinds.has("fallen_timber"), "Mire has reeds and fallen timber")
			_mask(map.layout, 14, 1.75)
		if floor_number == 18:
			_check(kinds.has("fungus") and kinds.has("root_arch"), "Hollow has fungi and large roots")
	_check(central[0].cells.values().count(&"forest_floor") > 2 * central[1].cells.values().count(&"forest_floor"),
		"Grove has substantially more forest")
	_check(central[1].cells.values().count(&"water") > 2 * central[0].cells.values().count(&"water"),
		"interlinked Mire basins give more than twice the Grove's water coverage")
	_check(central[2].cells.values().count(&"stone") > 3 * central[0].cells.values().count(&"stone"),
		"Hollow has substantially more stone")

func _corpus() -> void:
	var repairs := 0
	for seed_value in [0, 1, 9, 117, 241, 517, 823, 1011, 2749, 9821]:
		for radius in [14, 28]:
			for floor_number in [1, 6, 7, 9, 12, 13, 18]:
				var climate := Climate.climate(floor_number)
				for spacing in [1.50, 1.75, 2.0]:
					var layout := Geography.compose(seed_value, radius, spacing, climate)
					_check(not layout.is_empty(), "bounded geography corpus built %d/%d/%d/%.2f" % [seed_value, radius, floor_number, spacing])
					if not layout.is_empty():
						repairs += int(layout.repair > 0)
						_check(layout.repair < Geography.TRIES, "repair stays bounded")
	print("M07_CORPUS 420 cases; repaired ", repairs)

func _geometry(map: Dictionary, radius: int, spacing: float) -> void:
	var layout: Dictionary = map.layout
	var water: Dictionary = layout.water[0]
	var graph: Dictionary = layout.trail_network
	var deck: Dictionary = layout.crossings[0]
	var span: PackedVector2Array = deck.bridge
	var pending := ["arrival"]
	var reached := {"arrival": true}
	while not pending.is_empty():
		var node: String = pending.pop_back()
		for edge in graph.edges:
			var next: String = edge.to if edge.from == node else edge.from if edge.to == node else ""
			if not next.is_empty() and not reached.has(next):
				reached[next] = true
				pending.append(next)
	_check(reached.size() == graph.nodes.size(), "all clearings and both banks are connected")
	_check(span[0] == graph.nodes.west_bank and span[1] == graph.nodes.east_bank
		and not Geometry.contains(water, span[0]) and not Geometry.contains(water, span[1])
		and Geometry.contains(water, span[0].lerp(span[1], .5)), "bridge joins dry landings across wet channel")
	_check(not Geometry2D.triangulate_polygon(water.outline).is_empty(), "coherent channel is a simple polygon")
	for hole: PackedVector2Array in water.get("holes", []):
		var centre := Vector2.ZERO
		for p in hole:
			centre += p
		centre /= hole.size()
		_check(Geometry2D.is_point_in_polygon(centre, water.outline) and not Geometry.contains(water, centre),
			"enclosed island reads as dry land")
	for patch in layout.clearings:
		_check(not Geometry.in_any(layout.water, patch.center, patch.radius), "reserved clearing is dry")
		_check(Geometry.in_trails(layout, patch.center), "reserved clearing has trail access")
	for path in layout.paths:
		for point in path.outline:
			_check(Geography._inside_disk(point, radius, spacing), "trail footprint within terrain")
		if path.id != "bank_crossing":
			_check(Geometry2D.intersect_polygons(path.outline, water.outline).is_empty(), "only bridge overlaps the channel")
	for cell: Vector2i in map.cells:
		var terrain: StringName = map.cells[cell]
		var center := Grid.cell_to_world(cell, spacing)
		_check((terrain == &"water") == (Geometry.signed_distance(water, center) < 0.0), "cell water agrees with shoreline")
		for direction in Grid.NEIGHBORS:
			var next := cell + direction
			if map.cells.has(next):
				_check(Catalog.allows(terrain, map.cells[next]), "neighbor materials are compatible")
	for prop in layout.plants + layout.rocks:
		var margin: float = prop.get("clearance", prop.get("radius",0.0))
		_check(not Geometry.in_trails(layout, prop.center, margin)
			and not Geometry.in_any(layout.water + layout.clearings, prop.center, margin),
			"every plant and obstacle footprint preserves water, paths and reservations")

func _mask(layout: Dictionary, radius: int, spacing: float) -> void:
	var atlas := Mask.bake(layout, spacing, radius)
	var data: PackedByteArray = atlas.image.get_data()
	var step: Vector2 = atlas.frame.size / (Vector2(atlas.size) - Vector2.ONE)
	var largest := 0.0
	var island: int = layout.water[0].get("holes", []).size()
	_check(island == 1, "the Mire contains an island and visible shoreline")
	for y in range(0, atlas.size.y, 3):
		for x in range(0, atlas.size.x, 3):
			var at: Vector2 = atlas.frame.position + Vector2(x,y) * step
			var value: int = data[(y * atlas.size.x + x) * 3]
			var decoded := (value / 127.5 - 1.0) * Mask.MAX_DISTANCE
			var expected := Geometry.signed_distance(layout.water[0], at, Mask.MAX_DISTANCE)
			largest = maxf(largest, absf(expected - decoded))
	_check(largest < 0.007, "shore and island shader mask match signed-distance queries")

func _scene() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	var garden_hash: String = scene.metrics.digest
	var heart = scene.growing_heart
	_check(heart.sculpt_models[0].is_visible_in_tree() and scene.heart_stage.is_visible_in_tree() \
		and not scene.floor_choice.is_visible_in_tree(), "M06C Garden and Heart stay in the lab")
	scene.example.select(1)
	scene.example.item_selected.emit(1)
	for sample in [[6, 0], [7, 1], [12, 1], [13, 2]]:
		scene.floor_choice.select(sample[0] - 1)
		scene.floor_choice.item_selected.emit(sample[0] - 1)
		_check(scene.wilds.climate.biome == sample[1] and scene.terrain_seed == 241
			and scene.example.selected == sample[1] + 1 and scene.floor_choice.is_visible_in_tree(),
			"the floor control changes environment and keeps the compared seed")
		_check(scene.environment.fog_enabled and not scene.tree.visible and not scene.heart_stage.visible
			and scene.feature_view.crossings.get_child_count() == 3, "blended lighting and valid Wilds render")
	scene.render_mode.select(6)
	scene.render_mode.item_selected.emit(6)
	_check(scene.wilds.is_empty() and not scene.floor_choice.visible and not scene.environment.fog_enabled,
		"M06C remains available with its original rendering")
	scene.example.select(0)
	scene.example.item_selected.emit(0)
	_check(scene.metrics.digest == garden_hash and heart.sculpt_models[0].is_visible_in_tree(),
		"returning from deeper floors restores the original Garden")
	scene.free()
