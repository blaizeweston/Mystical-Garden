extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var passed: bool = await preload("res://tests/support/wild_flora_network_case.gd").new().run(self,true)
	if passed: print("PASS: one party-wide wild flora harvest on local four-player loopback, shared claim views and fifth-client refusal")
	quit(int(not passed))
