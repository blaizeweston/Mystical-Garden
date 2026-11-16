extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.connected_reaper_case = true
	var passed: bool = await fixture.run(self,true)
	if passed: print("PASS: CT04 four-player mixed-class expedition with real Reaper casts and overflow refusal")
	quit(int(not passed))
