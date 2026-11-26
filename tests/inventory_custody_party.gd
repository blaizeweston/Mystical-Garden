extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var passed: bool=await preload("res://tests/support/inventory_custody_network_case.gd").new().run(self,true)
 if passed:print("PASS: four-player portable custody, guarded root/extraction, individual returns and fifth-client refusal")
 quit(int(not passed))
