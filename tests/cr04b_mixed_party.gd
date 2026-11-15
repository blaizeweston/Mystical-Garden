extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.extra_cores = ["part_1", "part_5", "plant_part_rare_ironroot"]
	fixture.measure_packets = true
	fixture.mixed_wood_ward = true
	var passed: bool = await fixture.run(self,true)
	if passed: print("PASS: Guarded four-player overlapping Thorn, mixed Bark and mixed Ward affinities")
	quit(0 if passed else 1)
