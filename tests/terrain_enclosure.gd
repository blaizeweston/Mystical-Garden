extends SceneTree

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Layout = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Enclosure = preload("res://assets/terrain_m02/terrain_enclosure.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Garden = preload("res://assets/terrain_m02/garden_clearing.tres")
const Wilds = preload("res://assets/terrain_m02/wilds_riverwood.tres")
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
	var seen := {}
	for sample in [[117, 14, true], [241, 14, false], [517, 14, false], [241, 28, false]]:
		var seed_value: int = sample[0]
		var radius: int = sample[1]
		var garden: bool = sample[2]
		var cells := Generator.generate(seed_value, radius, Garden if garden else Wilds, Catalog)
		var base := Layout.build(cells, SPACING, radius, seed_value, garden)
		var identity := Layout.digest(base)
		var result := Enclosure.build(base, cells, SPACING, seed_value, garden)
		var digest := Enclosure.digest(result)
		check(digest == Enclosure.digest(Enclosure.build(base, cells, SPACING, seed_value, garden)), "stable enclosure identity")
		check(not seen.has(digest) and Layout.digest(base) == identity, "distinct enclosure leaves M04 input intact")
		seen[digest] = true
		for key in ["paths", "water", "crossings", "clearings"]:
			check(result[key] == base[key], "enclosure keeps shared " + key)
		_check_geometry(result, cells, garden)
		print("M05_ENCLOSURE_DIGEST ", seed_value, "/", radius, " ", digest)
	_preview()
	if not failed:
		print("PASS: deterministic enclosure, protected footprints, and M02 through M05 preview switching")
	quit(1 if failed else 0)

func _check_geometry(layout: Dictionary, cells: Dictionary, garden: bool) -> void:
	var sectors := {}
	var ids := {}
	var forward: Array[float] = []
	var rest: Array[float] = []
	for trunk in layout.enclosure:
		sectors[trunk.sector] = true
		check(not ids.has(trunk.id), "unique enclosure tree ID")
		ids[trunk.id] = true
		check(cells.has(Grid.world_to_cell(trunk.at, SPACING)), "trunks stay on the terrain")
		check(not Shape.in_any(layout.water + layout.paths + layout.clearings + layout.rocks, trunk.at, 0.58),
			"enclosure trunk preserves water, routes, clearings and stone")
		if trunk.at.normalized().dot(Vector2(0.229, 0.973)) > 0.9:
			forward.append(trunk.height)
		elif trunk.at.y < 0.0:
			rest.append(trunk.height)
	check(sectors.size() == Enclosure.SECTORS if garden else sectors.size() >= 27, "woodland covers peripheral sectors")
	check(not forward.is_empty() and not rest.is_empty(), "both foreground and far canopy")
	if not forward.is_empty() and not rest.is_empty():
		check(forward.min() < rest.min(), "lower foreground canopy preserves readability")
	for accent in layout.accents:
		check(not Shape.in_any(layout.paths + layout.water + layout.clearings, accent.at, 0.47), "root accents stay out of protected areas")
	if garden:
		var core: Dictionary = layout.protected_core
		check(Shape.contains(core, Vector2.ZERO), "Heart anchors the sanctuary core")
		for plant in layout.plants:
			check(plant.kind == "grass" or not Shape.contains(core, plant.center), "heart clearing has no intrusive tall vegetation")
		for rock in layout.rocks:
			check(not Shape.in_any([core], rock.center, rock.radius), "boulders stay outside the core")

func _preview() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	var selector := scene.get_node("%Rendering") as OptionButton
	var vegetation := scene.get_node("%VegetationLayer") as CheckButton
	var mesh := (scene.get_node("Ground") as MeshInstance3D).mesh
	var digest := Enclosure.digest(scene.enclosed_layout)
	for mode in [1, 2, 3, 0]:
		selector.select(mode)
		selector.item_selected.emit(mode)
		check(scene.enclosure_view.visible == (mode == 0), "only M05 reveals the enclosure")
		check(scene.feature_view.visible == (mode <= 1), "M04 and M05 share feature visibility controls")
		check(Enclosure.digest(scene.enclosed_layout) == digest and scene.get_node("Ground").mesh == mesh,
			"switching comparison modes preserves shared data")
	vegetation.button_pressed = false
	check(not scene.enclosure_view.visible, "vegetation toggle applies to the enclosure")
	vegetation.button_pressed = true
	check(scene.enclosure_view.visible and scene.hearth.visible, "Garden restores woodland and warm landmark")
	scene.show_example(1, 241, 1, true)
	check(not scene.hearth.visible and scene.get_node("HexDebug").visible, "Wilds lighting and hex overlay")
	scene.free()
