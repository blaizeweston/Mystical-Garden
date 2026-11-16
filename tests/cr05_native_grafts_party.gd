extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.native_graft_case = true
	fixture.measure_packets = true
	var passed: bool = await fixture.run(self,true)
	if passed: print("PASS: native grafts and learned focuses in guarded affinity co-op")
	quit(int(not passed))
