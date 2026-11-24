extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var passed: bool = await preload("res://tests/support/wild_flora_network_case.gd").new().run(self,false)
	if passed: print("PASS: wild flora independently harvested on local two-player loopback, stale requests and Garden rejoin")
	quit(int(not passed))
