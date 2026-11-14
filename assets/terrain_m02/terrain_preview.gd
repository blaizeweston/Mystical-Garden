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
@onready var heart_stage: OptionButton = %HeartStage

func _ready() -> void:
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	camera.size = CAMERA_SIZE
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
	for label in HeartPreview.STAGES:
		heart_stage.add_item(label)
	heart_stage.item_selected.connect(func(index: int): growing_heart.show_stage(index))
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
	render_mode.select(M06C)
	map_size.add_item("631 cells")
	map_size.add_item("2,437 cells")
	seed_field.value = DEFAULT_SEEDS[0]
	example.item_selected.connect(_select_example)
	size_choice.item_selected.connect(func(_index: int): _regenerate())
	map_size.item_selected.connect(func(_index: int): _regenerate())
	render_mode.item_selected.connect(_set_render_mode)
	%Generate.pressed.connect(_regenerate)
	%NextSeed.pressed.connect(_next_seed)
	overlay.toggled.connect(_set_overlay)
	for key in [&"GroundLayer", &"VegetationLayer", &"RockLayer", &"WaterLayer", &"PathLayer"]:
		(get_node("%" + str(key)) as CheckButton).toggled.connect(func(_enabled: bool): _sync_layers())
	_regenerate()

func show_example(index: int, seed_value: int, spacing_index: int, show_overlay: bool) -> void:
	example.select(index)
	size_choice.select(spacing_index)
	seed_field.set_value_no_signal(seed_value)
	overlay.set_pressed_no_signal(show_overlay)
	_regenerate()

func _select_example(index: int) -> void:
	seed_field.set_value_no_signal(DEFAULT_SEEDS[index])
	_regenerate()

func _next_seed() -> void:
	var next := int(seed_field.value) + 1
	seed_field.set_value_no_signal(0 if next > int(seed_field.max_value) else next)
	_regenerate()

func _regenerate() -> void:
	var palette = PALETTES[0 if example.selected == 0 else 1]
	terrain_seed = int(seed_field.value)
	spacing = SPACINGS[size_choice.selected]
	var started := Time.get_ticks_usec()
	cells = Generator.generate(terrain_seed, RADII[map_size.selected], palette, CATALOG)
	var generated := Time.get_ticks_usec()
	compiled = Compiler.compile(cells, spacing, CATALOG)
	var meshed := Time.get_ticks_usec()
	var field := MaterialField.bake(cells)
	natural_material = MaterialField.material(field, spacing, terrain_seed, CATALOG)
	var material_baked := Time.get_ticks_usec()
	feature_layout = Features.build(cells, spacing, RADII[map_size.selected], terrain_seed, palette.tree_at_origin)
	scene_garden = palette.tree_at_origin
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

func _set_render_mode(index: int) -> void:
	var continuity := index >= M06B
	var enclosure := index <= 1 or continuity
	var modern := index == 0 or continuity
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
	if enclosure:
		enclosure_view.rebuild(continuity_layout if continuity else enclosed_layout, scene_garden, profile, biome, continuity)
	legacy_heart.visible = not modern
	botanical_heart.visible = modern and not continuity
	growing_heart.set_sculpt(index == M06C and scene_garden)
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
	enclosure_view.visible = enclosure and %VegetationLayer.button_pressed
	hearth.visible = enclosure and scene_garden and %GroundLayer.button_pressed
	ground.visible = feature_mode or %GroundLayer.button_pressed
	natural_material.set_shader_parameter("show_ground", not feature_mode or %GroundLayer.button_pressed)
	natural_material.set_shader_parameter("show_water", %WaterLayer.button_pressed)
	natural_material.set_shader_parameter("show_paths", %PathLayer.button_pressed)
	feature_view.visible = feature_mode
	feature_view.vegetation.visible = %VegetationLayer.button_pressed
	feature_view.rocks.visible = %RockLayer.button_pressed
	feature_view.crossings.visible = %PathLayer.button_pressed

func _set_overlay(enabled: bool) -> void:
	debug.visible = enabled
	if enabled and debug_dirty:
		debug.rebuild(cells, spacing, compiled)
		debug_dirty = false
	if enabled:
		_update_inspector(get_viewport().get_mouse_position())
	else:
		detail.text = ""

func _input(event: InputEvent) -> void:
	if is_instance_valid(overlay) and overlay.button_pressed and event is InputEventMouseMotion:
		_update_inspector(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
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

func _ground_point(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	return origin - direction * (origin.y / direction.y)

func _update_inspector(screen: Vector2) -> void:
	var ground_point := _ground_point(screen)
	var inspection: String = debug.inspect(cells, CATALOG, Vector2(ground_point.x, ground_point.z), spacing)
	detail.text = inspection if not inspection.is_empty() else "Hover over terrain to inspect a cell"