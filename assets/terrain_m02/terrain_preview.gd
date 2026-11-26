extends Node3D

const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Compiler = preload("res://assets/terrain_m02/terrain_mesh.gd")
const Features = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const ArtDirection = preload("res://assets/terrain_m02/terrain_art_direction.gd")
const HeartPreview = preload("res://assets/terrain_m02/terrain_heart_preview.gd")
const RootMeshes = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const Enclosure = preload("res://assets/terrain_m02/terrain_enclosure.gd")
const FeatureMask = preload("res://assets/terrain_m02/terrain_feature_mask.gd")
const MaterialField = preload("res://assets/terrain_m02/terrain_material_field.gd")
const Wilds = preload("res://assets/terrain_m02/wilds_preview_generation.gd")
const Boundary = preload("res://assets/terrain_m02/wilds_boundary.gd")
const WalkPreview = preload("res://assets/terrain_m02/wilds_play_preview.gd")
const ExpansionPreview = preload("res://assets/terrain_m02/garden_expansion_preview.gd")
const CATALOG = preload("res://assets/terrain_m02/terrain_catalog.tres")
const PALETTES := [
	preload("res://assets/terrain_m02/garden_clearing.tres"),
	preload("res://assets/terrain_m02/wilds_riverwood.tres"),
]
const TREE = preload("res://assets/root_tree.glb")
const DEFAULT_SEEDS := [117, 241, 517, 823]
const SPACINGS := [1.50, 1.75, 2.00]
const RADII := [14, 28]
const CAMERA_OFFSET := Vector3(3.3, 14.0, 14.0)
const CAMERA_SIZE := 16.5
const CLOSE_CAMERA_SIZE := 5.0
const M06B := 5
const M06C := 6
const M07 := 7
const M07B := 8
const M09 := 9
const M09B := 10
const M10 := 11
const START_FLOORS := [1, 1, 9, 18]

var cells := {}
var compiled := {}
var metrics := {}
var spacing := 1.75
var terrain_seed := 117
var debug_dirty := true
var natural_material: ShaderMaterial
var feature_layout := {}
var enclosed_layout := {}
var scene_garden := true
var generated_mode := M06C
var wilds := {}
var walk_preview: WalkPreview
var expansion: ExpansionPreview
var expansion_ground := PlaneMesh.new()
var scenic_ground: PlaneMesh
var pan_origin := Vector2.ZERO
var pan_active := false
var botanical_layout := {}
var continuity_layout := {}
var legacy_atlas := {}
var continuity_atlas := {}
var growing_heart: Node3D
var legacy_heart: Node3D
var botanical_heart: MeshInstance3D

@onready var enclosure_view := $Enclosure
@onready var sun: DirectionalLight3D = $Sun
@onready var environment: Environment = $WorldEnvironment.environment
@onready var hearth: OmniLight3D = $Hearth

@onready var feature_view := $Features

@onready var camera: Camera3D = $Camera
@onready var ground: MeshInstance3D = $Ground
@onready var debug := $HexDebug
@onready var tree: Node3D = $TreePosition
@onready var example: OptionButton = %Example
@onready var size_choice: OptionButton = %Spacing
@onready var seed_field: SpinBox = %Seed
@onready var render_mode: OptionButton = %Rendering
@onready var map_size: OptionButton = %MapSize
@onready var overlay: CheckButton = %Overlay
@onready var status: Label = %Status
@onready var detail: Label = %Detail
@onready var art_note: Label = %ArtNote
@onready var floor_choice: OptionButton = %Floor
@onready var heart_stage: OptionButton = %HeartStage

func _ready() -> void:
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	camera.size = CAMERA_SIZE
	walk_preview = WalkPreview.new()
	add_child(walk_preview)
	walk_preview.camera = camera
	walk_preview.fog = %PlayFog
	walk_preview.readout = %EncounterStatus
	expansion = ExpansionPreview.new()
	add_child(expansion)
	expansion.bind_controls(%GardenGrowthControls, %GardenGrowthStatus, enclosure_view)
	expansion.camera_changed.connect(_expansion_camera)
	%PlayFloor.toggled.connect(_play_floor)
	walk_preview.exit_requested.connect(func(): %PlayFloor.button_pressed = false)
	%FogLayer.toggled.connect(func(enabled: bool):
		walk_preview.set_fog(enabled)
		%FogLayer.release_focus())
	%RestartFloor.pressed.connect(_start_floor)
	camera.get_viewport().size_changed.connect(func():
		_resize_exterior()
		_resize_expansion_ground()
		if walk_preview.run != null:
			walk_preview._align_fog())
	legacy_heart = TREE.instantiate() as Node3D
	tree.add_child(legacy_heart)
	legacy_heart.scale = Vector3.ONE * 0.86
	botanical_heart = MeshInstance3D.new()
	botanical_heart.mesh = RootMeshes.botanical(6, "heart", ArtDirection.profile(0), 0)
	var heart_bark := StandardMaterial3D.new()
	heart_bark.vertex_color_use_as_albedo = true
	heart_bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	heart_bark.roughness = 0.94
	botanical_heart.material_override = heart_bark
	botanical_heart.scale = Vector3(4.32, 4.65, 4.32)
	tree.add_child(botanical_heart)
	growing_heart = HeartPreview.new()
	tree.add_child(growing_heart)
	expansion.heart = growing_heart
	for label in HeartPreview.STAGES:
		heart_stage.add_item(label)
	heart_stage.item_selected.connect(func(index: int):
		growing_heart.show_stage(index)
		expansion.change_heart_stage(index))
	for profile in ArtDirection.PROFILES:
		example.add_item(profile.label)
	for size in SPACINGS:
		size_choice.add_item("%.2f u" % size)
	example.select(0)
	size_choice.select(1)
	render_mode.add_item("M06")
	render_mode.add_item("M05")
	render_mode.add_item("M04")
	render_mode.add_item("M03")
	render_mode.add_item("M02")
	render_mode.add_item("M06B")
	render_mode.add_item("M06C")
	render_mode.add_item("M07")
	render_mode.add_item("M07B")
	render_mode.add_item("M09")
	render_mode.add_item("M09B")
	render_mode.add_item("M10")
	render_mode.select(M06C)
	for number in range(1, 19):
		floor_choice.add_item("Floor %d" % number)
	floor_choice.item_selected.connect(func(_index: int): _regenerate())
	map_size.add_item("631 cells")
	map_size.add_item("2,437 cells")
	seed_field.value = DEFAULT_SEEDS[0]
	example.item_selected.connect(_select_example)
	size_choice.item_selected.connect(func(_index: int): _regenerate())
	map_size.item_selected.connect(func(_index: int): _regenerate())
	render_mode.item_selected.connect(_select_render_mode)
	%Generate.pressed.connect(_regenerate)
	%NextSeed.pressed.connect(_next_seed)
	overlay.toggled.connect(_set_overlay)
	for key in [&"GroundLayer", &"VegetationLayer", &"RockLayer", &"WaterLayer", &"PathLayer"]:
		(get_node("%" + str(key)) as CheckButton).toggled.connect(func(_enabled: bool): _sync_layers())
	_regenerate()

func show_example(index: int, seed_value: int, spacing_index: int, show_overlay: bool) -> void:
	example.select(index)
	floor_choice.select(START_FLOORS[index] - 1)
	size_choice.select(spacing_index)
	seed_field.set_value_no_signal(seed_value)
	overlay.set_pressed_no_signal(show_overlay)
	_regenerate()

func _select_example(index: int) -> void:
	seed_field.set_value_no_signal(DEFAULT_SEEDS[index])
	floor_choice.select(START_FLOORS[index] - 1)
	if render_mode.selected >= M06C:
		if index == 0:
			render_mode.select(M06C)
		elif render_mode.selected == M06C:
			render_mode.select(M10)
	_regenerate()

func _select_render_mode(index: int) -> void:
	if not scene_garden and (index >= M07 or generated_mode >= M07):
		_regenerate()
	else:
		_set_render_mode(index)

func _next_seed() -> void:
	var next := int(seed_field.value) + 1
	seed_field.set_value_no_signal(0 if next > int(seed_field.max_value) else next)
	_regenerate()

func _regenerate() -> void:
	scenic_ground = null
	pan_active = false
	if walk_preview.run != null:
		_reset_preview_camera()
	walk_preview.stop()
	expansion.clear()
	$GardenExterior.hide()
	_reset_preview_camera()
	var palette = PALETTES[0 if example.selected == 0 else 1]
	terrain_seed = int(seed_field.value)
	spacing = SPACINGS[size_choice.selected]
	scene_garden = palette.tree_at_origin
	generated_mode = render_mode.selected
	var started := Time.get_ticks_usec()
	if generated_mode >= M07 and not scene_garden:
		_rebuild_wilds(started)
		return
	wilds = {}
	_update_play_controls(false)
	cells = Generator.generate(terrain_seed, RADII[map_size.selected], palette, CATALOG)
	var generated := Time.get_ticks_usec()
	compiled = Compiler.compile(cells, spacing, CATALOG)
	var meshed := Time.get_ticks_usec()
	var field := MaterialField.bake(cells)
	natural_material = MaterialField.material(field, spacing, terrain_seed, CATALOG)
	var material_baked := Time.get_ticks_usec()
	feature_layout = Features.build(cells, spacing, RADII[map_size.selected], terrain_seed, palette.tree_at_origin)
	enclosed_layout = Enclosure.build(feature_layout, cells, spacing, terrain_seed, scene_garden)
	botanical_layout = ArtDirection.placements(enclosed_layout, example.selected)
	var features_built := Time.get_ticks_usec()
	continuity_layout = {}
	continuity_atlas = {}
	legacy_atlas = FeatureMask.bake(feature_layout, spacing, RADII[map_size.selected])
	var mask_baked := Time.get_ticks_usec()
	ground.mesh = compiled.mesh
	_set_render_mode(render_mode.selected)
	var view_built := Time.get_ticks_usec()
	tree.visible = palette.tree_at_origin
	debug_dirty = true
	_set_overlay(overlay.button_pressed)
	metrics = {"palette": palette.id, "seed": terrain_seed, "spacing": spacing,
		"cells": cells.size(), "terrain_meshes": 1, "vertices": compiled.vertices,
		"triangles": int(compiled.triangles), "generation_ms": (generated - started) / 1000.0,
		"mesh_ms": (meshed - generated) / 1000.0,
		"material_ms": (material_baked - meshed) / 1000.0,
		"features_ms": (features_built - material_baked) / 1000.0,
		"feature_mask_ms": (mask_baked - features_built) / 1000.0,
		"instance_ms": (view_built - mask_baked) / 1000.0,
		"mask_bytes": legacy_atlas.image.get_data_size(),
		"stands": feature_layout.stands.size(), "formations": feature_layout.rock_formations.size(),
		"plants": enclosed_layout.plants.size(), "rocks": enclosed_layout.rocks.size(),
		"enclosure": enclosed_layout.enclosure.size(), "accents": enclosed_layout.accents.size(),
		"digest": Generator.digest(cells, palette.id, terrain_seed)}
	status.text = "%d cells  ·  %d plants  ·  %d rocks  ·  %.1f ms rebuild" % [
		metrics.cells, metrics.plants + metrics.enclosure, metrics.rocks, (view_built - started) / 1000.0]
	print("M06_TERRAIN ", JSON.stringify(metrics))

func _rebuild_wilds(started: int) -> void:
	tree.visible = false
	growing_heart.pulse.visible = false
	heart_stage.visible = false
	floor_choice.visible = true
	wilds = Wilds.build(terrain_seed, floor_choice.selected + 1, RADII[map_size.selected], spacing, CATALOG,
		Wilds.Biomes.WINDOWS, generated_mode >= M07B, generated_mode >= M09, generated_mode >= M09B, generated_mode == M10)
	if wilds.is_empty():
		cells = {}
		ground.hide()
		feature_view.hide()
		enclosure_view.hide()
		metrics = {}
		debug.hide()
		_update_play_controls(false)
		status.text = "Terrain constraints could not be satisfied for this seed."
		art_note.text = ""
		detail.text = ""
		return
	cells = wilds.cells
	var generated := Time.get_ticks_usec()
	compiled = {"triangles": 2} if wilds.layout.has("boundary") else Compiler.compile(cells, spacing, CATALOG)
	var meshed := Time.get_ticks_usec()
	var climate: Dictionary = wilds.climate
	example.select(climate.biome + 1)
	natural_material = MaterialField.material(MaterialField.bake(wilds.substrate), spacing, terrain_seed, CATALOG)
	FeatureMask.bind(natural_material, FeatureMask.bake(wilds.layout, spacing, RADII[map_size.selected]))
	natural_material.set_shader_parameter("feature_mode", true)
	natural_material.set_shader_parameter("continuity_mode", true)
	preload("res://assets/terrain_m02/wilds_surface_art.gd").bind(natural_material, climate.weights)
	natural_material.set_shader_parameter("wilds_mode", true)
	natural_material.set_shader_parameter("wilds_moisture", climate.moisture)
	natural_material.set_shader_parameter("wilds_floor", climate.floor)
	natural_material.set_shader_parameter("wilds_water", climate.wet)
	natural_material.set_shader_parameter("botanical_mode", true)
	natural_material.set_shader_parameter("botanical_ground", climate.ground)
	natural_material.set_shader_parameter("botanical_water", climate.water)
	var baked := Time.get_ticks_usec()
	ground.material_override = natural_material
	if wilds.layout.has("boundary"):
		var weights: Vector3 = climate.weights
		natural_material.set_shader_parameter("scenic_exterior", true)
		natural_material.set_shader_parameter("scenic_cover",
			Vector3(0.2, 0.7, 0.1) * weights.x + Vector3(0.74, 0.22, 0.04) * weights.y
				+ Vector3(0.20, 0.14, 0.66) * weights.z)
		scenic_ground = PlaneMesh.new()
		ground.mesh = scenic_ground
		_resize_exterior()
	else:
		ground.mesh = compiled.mesh
	var batches: Dictionary = feature_view.rebuild(wilds.layout, {}, 0, true)
	_light(true)
	sun.light_color = climate.sun
	sun.light_energy = climate.sun_energy
	environment.ambient_light_color = climate.ambient
	environment.ambient_light_energy = climate.ambient_energy
	environment.background_color = climate.air.darkened(0.65)
	environment.fog_enabled = true
	environment.fog_light_color = climate.air.lerp(Color("#373126"), climate.weights.z * 0.66) \
		if generated_mode >= M07B else climate.air
	environment.fog_density = climate.haze
	_sync_layers()
	debug_dirty = true
	_set_overlay(overlay.button_pressed)
	var names := ["Outer Grove", "Sable Mire", "Hollow Below"]
	var weights: Vector3 = climate.weights
	art_note.text = "%s  ·  Grove %d%%   Mire %d%%   Hollow %d%%" % [
		names[climate.biome], roundi(weights.x * 100.0), roundi(weights.y * 100.0), roundi(weights.z * 100.0)]
	var total := (Time.get_ticks_usec() - started) / 1000.0
	metrics = {"floor": floor_choice.selected + 1, "seed": terrain_seed, "cells": cells.size(),
		"triangles": compiled.triangles, "plants": batches.plant_instances, "obstacles": batches.rock_instances,
		"batch_count": batches.instance_batches, "repairs": wilds.layout.repair,
		"masses": wilds.layout.get("masses", []).size(), "crossings": wilds.layout.crossings.size(),
		"scenic_instances": wilds.layout.boundary.exterior_props.size() if scenic_ground != null else 0,
		"boundary_strips": wilds.layout.boundary.rim.size() if scenic_ground != null else 0,
		"hydrology": wilds.layout.get("hydrology", "legacy"), "clearings": wilds.layout.clearings.size(),
		"generation_ms": (generated - started) / 1000.0, "mesh_ms": (meshed - generated) / 1000.0,
		"material_ms": (baked - meshed) / 1000.0, "rebuild_ms": total}
	status.text = "%d cells  ·  %d plants  ·  %d obstacles  ·  %.1f ms rebuild" % [
		cells.size(), batches.plant_instances, batches.rock_instances, total]
	if generated_mode >= M09B:
		art_note.text += "  |  %s, %d clearings, %d bridges" % [
			wilds.layout.hydrology.capitalize(), metrics.clearings, metrics.crossings]
	print("M07_TERRAIN ", JSON.stringify(metrics))
	_update_play_controls(generated_mode >= M07B)

func _resize_exterior() -> void:
	if scenic_ground == null:
		return
	var extent := Boundary.exterior_extent(RADII[map_size.selected], spacing, get_viewport().get_visible_rect().size)
	scenic_ground.size = Vector2.ONE * extent * 2.0

func _update_play_controls(available: bool) -> void:
	%PlayFloor.visible = available
	if not available:
		%PlayFloor.set_pressed_no_signal(false)
	_play_floor(%PlayFloor.button_pressed)

func _play_floor(active: bool) -> void:
	%FogLayer.visible = active
	%PlayHelp.visible = active
	%RestartFloor.visible = active
	%EncounterStatus.visible = active
	if active:
		_start_floor()
	elif walk_preview.run != null:
		walk_preview.stop()
		_reset_preview_camera()
		_set_overlay(overlay.button_pressed)

func _start_floor() -> void:
	walk_preview.deck_gate = feature_view.massing.get_node_or_null("ExitGate")
	%PlayHelp.text = ("WASD / arrows  |  Space strike  |  Shift dodge  |  E Gate  |  Esc exit" if generated_mode == M10
		else "WASD / arrows  |  Space strike  |  E Gate  |  Esc exit")
	walk_preview.start(cells, wilds.layout, spacing, generated_mode == M10)
	walk_preview.allow_camera_control = generated_mode >= M09
	_set_overlay(overlay.button_pressed)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()

func _reset_preview_camera() -> void:
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	camera.size = CAMERA_SIZE

func _set_render_mode(index: int) -> void:
	var continuity := index >= M06B
	var enclosure := index <= 1 or continuity
	var modern := index == 0 or continuity
	var garden_growth := index >= M06C and scene_garden
	if continuity and continuity_layout.is_empty():
		var radius: int = RADII[map_size.selected]
		var layout := Features.build(cells, spacing, radius, terrain_seed, scene_garden, true)
		continuity_layout = ArtDirection.placements(Enclosure.build(layout, cells, spacing, terrain_seed, scene_garden), example.selected)
		continuity_atlas = FeatureMask.bake(continuity_layout, spacing, radius)
	var biome := example.selected
	var profile := ArtDirection.profile(biome) if modern else {}
	ground.material_override = natural_material if index != 4 else null
	natural_material.set_shader_parameter("feature_mode", index <= 2 or continuity)
	natural_material.set_shader_parameter("continuity_mode", continuity)
	FeatureMask.bind(natural_material, continuity_atlas if continuity else legacy_atlas)
	natural_material.set_shader_parameter("art_mode", (1 if scene_garden else 2) if enclosure else 0)
	natural_material.set_shader_parameter("botanical_mode", modern)
	if modern:
		natural_material.set_shader_parameter("botanical_ground", profile.ground)
		natural_material.set_shader_parameter("botanical_water", profile.water)
		feature_view.rebuild(continuity_layout if continuity else botanical_layout, profile, biome)
	elif index <= 2:
		feature_view.rebuild(enclosed_layout if enclosure else feature_layout)
	expansion.show_garden(false)
	if scene_garden:
		ground.mesh = compiled.mesh
	natural_material.set_shader_parameter("scenic_exterior", garden_growth)
	natural_material.set_shader_parameter("scenic_cover", Vector3(0.10, 0.89, 0.01))
	natural_material.set_shader_parameter("garden_frontier", garden_growth)
	if garden_growth:
		if expansion.state == null:
			expansion.start(cells, continuity_layout, spacing, terrain_seed, RADII[map_size.selected])
		var forest := expansion.state.forest_layout()
		forest["scenic_woodland"] = expansion.state.scenic_woodland()
		enclosure_view.rebuild(forest, true, profile, biome, true)
		expansion.attach_material(natural_material)
		expansion.show_garden(true)
		_resize_expansion_ground()
		$GardenExterior.material_override = natural_material
	elif enclosure:
		enclosure_view.rebuild(continuity_layout if continuity else enclosed_layout, scene_garden, profile, biome, continuity)
	$GardenExterior.visible = garden_growth
	legacy_heart.visible = not modern
	botanical_heart.visible = modern and not continuity
	growing_heart.set_sculpt(index >= M06C and scene_garden)
	floor_choice.hide()
	growing_heart.visible = continuity
	growing_heart.pulse.visible = continuity and scene_garden
	heart_stage.visible = continuity and scene_garden
	_light(enclosure)
	if modern:
		sun.light_color = profile.sun
		environment.ambient_light_color = profile.ambient
		art_note.text = profile.note
	else:
		art_note.text = ""
	_sync_layers()

func _light(enclosure: bool) -> void:
	environment.fog_enabled = false
	sun.light_color = Color("#ffe2aa") if enclosure and scene_garden else Color("#d5dfbd") if enclosure else Color(1, 0.96, 0.86)
	sun.light_energy = (0.74 if scene_garden else 0.72) if enclosure else 1.12
	environment.ambient_light_color = (Color("#aab297") if scene_garden else Color("#829992")) if enclosure else Color(0.83, 0.91, 0.88)
	environment.ambient_light_energy = (0.68 if scene_garden else 0.64) if enclosure else 0.95
	environment.background_color = Color("#101711") if enclosure else Color(0.055, 0.077, 0.073)
	hearth.visible = enclosure and scene_garden and %GroundLayer.button_pressed

func _sync_layers() -> void:
	var continuity := render_mode.selected >= M06B
	var enclosure := render_mode.selected <= 1 or continuity
	var feature_mode := render_mode.selected <= 2 or continuity
	if generated_mode >= M07 and not scene_garden and wilds.is_empty():
		return
	enclosure_view.visible = enclosure and wilds.is_empty() and %VegetationLayer.button_pressed
	hearth.visible = enclosure and scene_garden and %GroundLayer.button_pressed
	ground.visible = feature_mode or %GroundLayer.button_pressed
	natural_material.set_shader_parameter("show_ground", not feature_mode or %GroundLayer.button_pressed)
	natural_material.set_shader_parameter("show_water", %WaterLayer.button_pressed)
	natural_material.set_shader_parameter("show_paths", %PathLayer.button_pressed)
	feature_view.visible = feature_mode
	feature_view.vegetation.visible = %VegetationLayer.button_pressed
	feature_view.rocks.visible = %RockLayer.button_pressed
	feature_view.massing.visible = %RockLayer.button_pressed
	feature_view.crossings.visible = %PathLayer.button_pressed
	$GardenExterior.visible = expansion.visible and scene_garden
	if $GardenExterior.visible:
		# Keep the original mesh available for historical render comparisons.
		ground.hide()

func _resize_expansion_ground() -> void:
	if expansion.state == null:
		return
	var extent := Boundary.exterior_extent(RADII[map_size.selected], spacing, get_viewport().get_visible_rect().size)
	expansion_ground.size = Vector2.ONE * 2.0 * (extent + ExpansionPreview.MAX_ZOOM)
	$GardenExterior.mesh = expansion_ground

func _expansion_camera(focus: Vector2, size: float) -> void:
	var target := Vector3(focus.x, 0, focus.y)
	camera.position = target + CAMERA_OFFSET
	camera.look_at(target)
	camera.size = size

func _set_overlay(enabled: bool) -> void:
	debug.visible = enabled and not cells.is_empty() and walk_preview.run == null
	if not debug.visible:
		detail.text = ""
		return
	if debug_dirty:
		if scenic_ground != null and not compiled.has("edge_rules"):
			var inspector := Compiler.compile(cells, spacing, CATALOG)
			compiled.merge({"edge_rules": inspector.edge_rules, "corner_rules": inspector.corner_rules})
		debug.rebuild(cells, spacing, compiled)
		debug_dirty = false
	_update_inspector(get_viewport().get_mouse_position())

func _input(event: InputEvent) -> void:
	if is_instance_valid(walk_preview) and walk_preview.run == null and is_instance_valid(overlay) and overlay.button_pressed and event is InputEventMouseMotion:
		_update_inspector(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(walk_preview) and walk_preview.run != null and walk_preview.allow_camera_control:
		_play_camera_input(event)
		return
	if expansion.visible and _expansion_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and scenic_ground != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var factor := 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
			camera.size = clampf(camera.size * factor, CLOSE_CAMERA_SIZE, Boundary.MAX_ZOOM)
			get_viewport().set_input_as_handled()
			return
	if not is_instance_valid(walk_preview) or walk_preview.run != null or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# Zoom towards the ground under the cursor without changing the gameplay angle.
		var anchored := _ground_point(event.position)
		var factor := 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
		camera.size = clampf(camera.size * factor, CLOSE_CAMERA_SIZE, CAMERA_SIZE)
		if is_equal_approx(camera.size, CAMERA_SIZE):
			camera.position = CAMERA_OFFSET
		else:
			camera.position += anchored - _ground_point(event.position)
		if overlay.button_pressed:
			_update_inspector(event.position)
		get_viewport().set_input_as_handled()

func _play_camera_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			pan_active = event.pressed
			var at := _ground_point(event.position)
			pan_origin = Vector2(at.x, at.z)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
			camera.size = clampf(camera.size * factor, CLOSE_CAMERA_SIZE, Boundary.MAX_ZOOM)
			walk_preview._align_fog()
		else:
			return
	elif event is InputEventMouseMotion and pan_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var at := _ground_point(event.position)
		walk_preview.set_pan(walk_preview.pan + pan_origin - Vector2(at.x, at.z))
		at = _ground_point(event.position)
		pan_origin = Vector2(at.x, at.z)
	else:
		return
	get_viewport().set_input_as_handled()

func _expansion_input(event: InputEvent) -> bool:
	var build := expansion.construction
	if expansion.walk.button_pressed and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E and not get_viewport().gui_get_focus_owner() is LineEdit:
		if expansion.pawn.length() <= 2.6:
			expansion.open_offerings()
		else:
			build.inspect_at(expansion.pawn)
		return true
	if build.enabled and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion):
		if event is InputEventMouseMotion and not pan_active:
			var point := _ground_point(event.position)
			build.preview(Vector2(point.x, point.z))
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point := _ground_point(event.position)
			build.press(Vector2(point.x, point.z))
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			build._cancel()
			return true
		if event is InputEventKey and event.pressed and not get_viewport().gui_get_focus_owner() is LineEdit:
			match event.physical_keycode:
				KEY_Q: build.turn_ghost(-1.0)
				KEY_E: build.turn_ghost(1.0)
				KEY_ENTER: build.confirm()
				KEY_ESCAPE: build._cancel()
				_: return false
			return true
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE and expansion.active:
		expansion.set_active(false)
		return true
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and expansion.active:
			var at := _ground_point(event.position)
			expansion.click_frontier(Vector2(at.x, at.z))
			return true
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			pan_active = event.pressed
			var at := _ground_point(event.position)
			pan_origin = Vector2(at.x, at.z)
			return true
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
			expansion.set_camera(expansion.focus, camera.size * factor)
			if build.enabled:
				var point := _ground_point(event.position)
				build.preview(Vector2(point.x, point.z))
			return true
	if event is InputEventMouseMotion and pan_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var at := _ground_point(event.position)
		expansion.set_camera(expansion.focus + pan_origin - Vector2(at.x, at.z), camera.size)
		at = _ground_point(event.position)
		pan_origin = Vector2(at.x, at.z)
		if build.enabled:
			build.preview(pan_origin)
		return true
	return false

func _ground_point(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	return origin - direction * (origin.y / direction.y)

func _update_inspector(screen: Vector2) -> void:
	var ground_point := _ground_point(screen)
	var inspection: String = debug.inspect(cells, CATALOG, Vector2(ground_point.x, ground_point.z), spacing)
	detail.text = inspection if not inspection.is_empty() else "Hover over terrain to inspect a cell"
