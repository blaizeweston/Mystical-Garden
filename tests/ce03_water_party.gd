extends SceneTree
func _initialize():call_deferred("run")
func run():
 var fixture:=preload("res://tests/support/cr03_network_case.gd").new()
 fixture.ce03_family="water";fixture.connected_oracle_case=true;fixture.affinity_cards_case=true
 var passed: bool=await fixture.run(self,true)
 if passed:print("PASS: CE03 Water independent network tides, cards, floor cleanup and admission")
 quit(int(not passed))
