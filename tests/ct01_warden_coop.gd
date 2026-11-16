extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.connected_warden_case = true
	var passed: bool = await fixture.run(self)
	if passed:
		print("PASS: connected Warden host validation, combat and rejoin")
	quit(int(not passed))
