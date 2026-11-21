extends SceneTree
func _initialize():call_deferred("run")
func run():
 var fixture:=preload("res://tests/support/cr03_network_case.gd").new()
 fixture.ce02_family="thorn";fixture.connected_oracle_case=true;fixture.affinity_cards_case=true
 var passed: bool=await fixture.run(self,false)
 if passed:print("PASS: CE02 Thorn independent network card actions, shared status, floor cleanup and admission")
 quit(int(not passed))
