extends Node3D

const Generator = preload("res://assets/terrain_m02/terrain_generator.gd")
const Compiler = preload("res://assets/terrain_m02/terrain_mesh.gd")
const CATALOG = preload("res://assets/terrain_m02/terrain_catalog.tres")
const PALETTES := [
	preload("res://assets/terrain_m02/garden_clearing.tres"),
	preload("res://assets/terrain_m02/wilds_riverwood.tres"),
]
const TREE = preload("res://assets/root_tree.glb")
const DEFAULT_SEEDS := [117, 241]
const SPACINGS := [1.50, 1.75, 2.00]
const RADIUS := 14
const CAMERA_OFFSET := Vector3(3.3, 14.0, 14.0)
const CAMERA_SIZE := 16.5

var cells := {}
var compiled := {}
var metrics := {}
var spacing := 1.75
var debug_dirty := true

@onready var camera: Camera3D = $Camera
@onready var ground: MeshInstance3D = $Ground
@onready var debug := $HexDebug
@onready var tree: Node3D = $TreePosition
@onready var example: OptionButton = %Example
@onready var size_choice: OptionButton = %Spacing
@onready var seed_field: SpinBox = %Seed
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
	seed_field.value = DEFAULT_SEEDS[0]
	example.item_selected.connect(_select_example)
	size_choice.item_selected.connect(func(_index: int): _regenerate())
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
	cells = Generator.generate(seed_value, RADIUS, palette, CATALOG)
	var generated := Time.get_ticks_usec()
	compiled = Compiler.compile(cells, spacing, CATALOG)
	var meshed := Time.get_ticks_usec()
	ground.mesh = compiled.mesh
	tree.visible = palette.tree_at_origin
	debug_dirty = true
	_set_overlay(overlay.button_pressed)
	metrics = {"palette": palette.id, "seed": seed_value, "spacing": spacing,
		"cells": cells.size(), "terrain_meshes": 1, "vertices": compiled.vertices,
		"triangles": int(compiled.triangles), "generation_ms": (generated - started) / 1000.0,
		"mesh_ms": (meshed - generated) / 1000.0, "digest": Generator.digest(cells, palette.id, seed_value)}
	status.text = "%d cells  ·  1 ground mesh  ·  %.1f ms generate + mesh" % [
		metrics.cells, (meshed - started) / 1000.0]
	print("M02_TERRAIN ", JSON.stringify(metrics))

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
	if overlay.button_pressed and event is InputEventMouseMotion:
		_update_inspector(event.position)

func _update_inspector(screen: Vector2) -> void:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var ground_point := origin - direction * (origin.y / direction.y)
	var inspection: String = debug.inspect(cells, CATALOG, Vector2(ground_point.x, ground_point.z), spacing)
	detail.text = inspection if not inspection.is_empty() else "Hover over terrain to inspect a cell"