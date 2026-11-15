extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.extra_cores = ["part_5"]
	var passed: bool = await fixture.run(self)
	if passed: print("PASS: Guarded Thorn field kill, drops, Gate, extraction and rejoin")
	quit(0 if passed else 1)
