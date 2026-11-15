extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.extra_cores = ["plant_part_rare_cinder_vine", "part_8", "plant_part_rare_gravemoss"]
	var passed: bool = await fixture.run(self,true)
	if passed: print("PASS: Guarded four-player Frost, Fire, Water and Vital with overflow refusal")
	quit(0 if passed else 1)
