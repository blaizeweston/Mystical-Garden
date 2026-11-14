extends SceneTree

const Art = preload("res://assets/terrain_m02/terrain_art_direction.gd")
const RootMeshes = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const Layout = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		printerr("FAIL: ", message)

func run() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	var modes := scene.get_node("%Rendering") as OptionButton
	var baseline := scene.get_node("%Example") as OptionButton
	_check(baseline.item_count == 4 and modes.item_count == 11, "four presets and eleven comparison modes are available")
	var distinct := {}
	for biome in 4:
		scene.show_example(biome, [117, 241, 517, 823][biome], 1, false)
		var profile := Art.profile(biome)
		_check(not distinct.has(profile.leaf), "each biome has its own canopy color")
		distinct[profile.leaf] = true
		var initial := Layout.digest(scene.enclosed_layout)
		var digest := Layout.digest(scene.botanical_layout)
		_check(digest == Layout.digest(Art.placements(scene.enclosed_layout, biome)), "botanical placement is deterministic")
		for key in ["paths", "water", "clearings", "rocks", "enclosure"]:
			_check(scene.botanical_layout[key] == scene.enclosed_layout[key], "style preserves footprint: " + key)
		var styles := {}
		for item in scene.botanical_layout.plants:
			styles[item.kind] = true
		for kind in ["tree", "sapling", "fern", "shrub", "grass"]:
			_check(styles.has(kind), "preview supplies " + kind)
		_check(styles.has("wine_fern") == (biome == 3), "wine fern belongs to Hollow")
		_check(scene.hearth.visible == (biome == 0) and scene.tree.visible == (biome == 0), "Heart belongs to the Garden")
		for mode in [0, 1, 0]:
			modes.select(mode)
			modes.item_selected.emit(mode)
			var canopy: Array = scene.enclosure_view.trees if mode == 1 else scene.enclosure_view.botanical_canopies[biome]
			_check(scene.enclosure_view.get_child(0).multimesh.mesh in canopy, "mode binds the expected canopy kit")
			for node in scene.feature_view.vegetation.get_children():
				var key := str(node.get_meta("asset_key"))
				_check(key.begins_with("botanical_") == (mode == 0), "M06 replaces visible legacy vegetation")
			for node in scene.feature_view.rocks.get_children():
				_check(str(node.get_meta("asset_key")).begins_with("rock_botanical_") == (mode == 0), "M06 replaces the preview rocks")
			_check(scene.legacy_heart.visible == (mode == 1) and scene.botanical_heart.visible == (mode == 0), "Heart comparison swaps the exact model")
			_check(Layout.digest(scene.enclosed_layout) == initial and Layout.digest(scene.botanical_layout) == digest,
				"mode selection does not change placement or M05 layout")
		var medium := RootMeshes.botanical(0, "tree", profile, biome)
		var small := RootMeshes.botanical(0, "sapling", profile, biome)
		_check(medium.get_aabb().size.x > small.get_aabb().size.x and medium.get_aabb().size.z > small.get_aabb().size.z,
			"medium tree and sapling have distinct silhouettes")
		print("M06_BOTANICAL_DIGEST ", biome, " ", digest)
	scene.free()
	if not failed:
		print("PASS: preview-only botanical assets, four art profiles, distinct silhouettes and historical comparisons")
	quit(1 if failed else 0)
