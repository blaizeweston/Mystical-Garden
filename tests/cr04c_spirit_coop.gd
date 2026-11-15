extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.extra_cores = ["plant_part_rare_ghost_fern"]
	var passed: bool = await fixture.run(self)
	if passed: print("PASS: Spirit guest Core through guarded title, floor, drops, Gate, extraction and rejoin")
	quit(int(not passed))
