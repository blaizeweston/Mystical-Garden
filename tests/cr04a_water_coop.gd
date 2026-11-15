extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.extra_cores = ["plant_part_rare_dewcap"]
	var passed: bool = await fixture.run(self)
	if passed: print("PASS: Guarded mixed Frost and Water loopback expedition")
	quit(0 if passed else 1)
