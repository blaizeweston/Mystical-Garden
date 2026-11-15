extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var passed: bool = await preload("res://tests/support/cr03_network_case.gd").new().run(self,true)
	if passed: print("PASS: CR03 guarded Frost four-player")
	quit(0 if passed else 1)
