extends SceneTree
const RootArt = preload("res://menu_button_roots.gd")
var failed := false
var samples: Array[Control] = []

class ObservedRoots extends "res://menu_button_roots.gd":
	var draws := 0
	func _draw() -> void:
		draws += 1
		super._draw()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; printerr("FAIL menu roots: ", message)

func run() -> void:
	var sizes := [Vector2(24,20), Vector2(36,36), Vector2(110,24), Vector2(137,52), Vector2(180,40), Vector2(500,22)]
	for index in sizes.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = true
		button.position = Vector2(30, 30 + index * 65)
		button.size = sizes[index]
		root.add_child(button)
		var art := ObservedRoots.new()
		art.button = button
		art.motion_enabled = func(): return false
		button.add_child(art)
		art.size = sizes[index]
		art.rebuild_paths()
		samples.append(art)
	await process_frame
	for tick in range(1, 101):
		for art in samples: art.set_growth(tick / 100.0)
		await process_frame
	check(samples.all(func(art): return art.draws > 80), "all sizes execute real canvas draws through partial and complete growth")
	for art in samples:
		check(art.growth == 1.0 and not art.perimeter.is_empty() and art.tendrils.size() > 0, "root borders retain their frame and tendrils")
	if not failed: print("PASS: rooted menu borders render six button sizes through 100 growth phases without canvas triangulation failures")
	quit(1 if failed else 0)
