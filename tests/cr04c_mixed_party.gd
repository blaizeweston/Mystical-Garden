extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fixture:=preload("res://tests/support/cr03_network_case.gd").new()
	fixture.extra_cores=["part_11","plant_part_rare_ghost_fern","plant_part_rare_void_willow"]
	fixture.measure_packets=true
	fixture.final_family_mix=true
	var passed: bool=await fixture.run(self,true)
	if passed: print("PASS: Storm, Spirit and Void in guarded four-player combat with bounded snapshots and overflow refusal")
	quit(int(not passed))
