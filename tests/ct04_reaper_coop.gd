extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.connected_reaper_case = true
	var passed: bool = await fixture.run(self)
	if passed: print("PASS: CT04 guarded Reaper choices, native and affinity combat, floor XP, reconnect and Heart respec")
	quit(int(not passed))
