extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.native_graft_case = true
	fixture.measure_packets = false
	var passed: bool = await fixture.run(self,false)
	if passed: print("PASS: GA01A host-owned graft purchases and native combat in guarded affinity co-op")
	quit(int(not passed))
