extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.connected_oracle_case = true
	var passed: bool = await fixture.run(self,true)
	if passed: print("PASS: CT05 mixed four-player generated Wilds, Oracle ally support and overflow refusal")
	quit(int(not passed))
