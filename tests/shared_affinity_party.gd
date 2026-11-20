extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.shared_status_case=true
	var passed: bool=await fixture.run(self,true)
	if passed: print("PASS: shared affinity four-client native casts, contributions, snapshots, floor travel, extraction and overflow refusal")
	quit(int(not passed))
