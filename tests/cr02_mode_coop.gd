extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var passed: bool = await preload("res://tests/support/cr02_network_case.gd").new().run(self,false)
	if passed: print("PASS: CR02 matching development co-op")
	quit(0 if passed else 1)
