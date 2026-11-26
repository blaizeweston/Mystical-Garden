extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var passed: bool=await preload("res://tests/support/inventory_custody_network_case.gd").new().run(self,false)
 if passed:print("PASS: two-player portable custody, guarded root/extraction, ownership and interrupted return recovery")
 quit(int(not passed))
