extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.connected_weaver_case = true
	var passed: bool = await fixture.run(self)
	if passed:
		print("PASS: Weaver connected progression and native spells in guarded co-op")
	quit(int(not passed))
