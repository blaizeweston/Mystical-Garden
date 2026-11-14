extends Node3D

const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Compiler = preload("res://assets/terrain_m02/terrain_mesh.gd")
const MaterialField = preload("res://assets/terrain_m02/terrain_material_field.gd")
const CATALOG = preload("res://assets/terrain_m02/terrain_catalog.tres")
const PALETTES := [
	preload("res://assets/terrain_m02/garden_clearing.tres"),
	preload("res://assets/terrain_m02/wilds_riverwood.tres"),
]
const TREE = preload("res://assets/root_tree.glb")
const DEFAULT_SEEDS := [117, 241]
const SPACINGS := [1.50, 1.75, 2.00]
const RADII := [14, 28]
const CAMERA_OFFSET := Vector3(3.3, 14.0, 14.0)
const CAMERA_SIZE := 16.5
const CLOSE_CAMERA_SIZE := 5.0

var cells := {}
var compiled := {}
var metrics := {}
var spacing := 1.75
var debug_dirty := true
var natural_material: ShaderMaterial

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

func _ready() -> void:
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	camera.size = CAMERA_SIZE
	var model := TREE.instantiate() as Node3D
	tree.add_child(model)
	model.scale = Vector3.ONE * 0.86
	for palette in PALETTES:
		example.add_item(palette.display_name)
	for size in SPACINGS:
		size_choice.add_item("%.2f u" % size)
	example.select(0)
	size_choice.select(1)
	render_mode.add_item("M03")
	render_mode.add_item("M02")
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
	var palette = PALETTES[example.selected]
	var seed_value := int(seed_field.value)
	spacing = SPACINGS[size_choice.selected]
	var started := Time.get_ticks_usec()
	cells = Generator.generate(seed_value, RADII[map_size.selected], palette, CATALOG)
	var generated := Time.get_ticks_usec()
	compiled = Compiler.compile(cells, spacing, CATALOG)
	var meshed := Time.get_ticks_usec()
	var field := MaterialField.bake(cells)
	natural_material = MaterialField.material(field, spacing, seed_value, CATALOG)
	var material_baked := Time.get_ticks_usec()
	ground.mesh = compiled.mesh
	_set_render_mode(render_mode.selected)
	tree.visible = palette.tree_at_origin
	debug_dirty = true
	_set_overlay(overlay.button_pressed)
	metrics = {"palette": palette.id, "seed": seed_value, "spacing": spacing,
		"cells": cells.size(), "terrain_meshes": 1, "vertices": compiled.vertices,
		"triangles": int(compiled.triangles), "generation_ms": (generated - started) / 1000.0,
		"mesh_ms": (meshed - generated) / 1000.0,
		"material_ms": (material_baked - meshed) / 1000.0, "mask_bytes": field.labels.size(),
		"digest": Generator.digest(cells, palette.id, seed_value)}
	status.text = "%d cells  ·  1 ground mesh  ·  %.1f ms build" % [
		metrics.cells, (material_baked - started) / 1000.0]
	print("M03_TERRAIN ", JSON.stringify(metrics))

func _set_render_mode(index: int) -> void:
	ground.material_override = natural_material if index == 0 else null

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