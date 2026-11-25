extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture := preload("res://tests/support/cr03_network_case.gd").new()
	fixture.inspect_contact_vfx = true
	var passed: bool = await fixture.run(self,false)
	if passed: print("PASS: CR03 guarded Frost co-op")
	quit(0 if passed else 1)
