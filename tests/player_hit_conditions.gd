extends SceneTree
const Conditions = preload("res://player_hit_conditions.gd")
const Balance = preload("res://game_balance.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL player hit conditions: ",message)

func run() -> void:
	var empty := Conditions.State.new()
	check(not empty.grace_active(0) and not empty.slow_active(0) and empty.movement_scale(0)==1.0,"new actor has no contact conditions")
	var hit := empty.after_hit(1000,800,220,false)
	var slowed: Conditions.State = hit.next_state
	check(hit.slow_applied and slowed.slow_until_ms()==1800 and slowed.grace_until_ms()==1220,"unblocked contact applies authored Slow and grace once")
	check(empty.slow_until_ms()==0 and empty.grace_until_ms()==0 and not is_same(empty,slowed),"hit creates a successor while preserving rollback state")
	check(slowed.grace_active(1219) and not slowed.grace_active(1220),"grace uses an exclusive deadline")
	check(slowed.movement_scale(1799)==float(Balance.values.combat.player_slow_movement_scale) and slowed.movement_scale(1800)==1.0,
		"ordinary movement restriction expires independently of hit grace")
	check(not slowed.slow_needs_prevention(1100,0) and not slowed.slow_needs_prevention(1100,-10),"absent Slow cannot spend one-use prevention")
	check(not slowed.slow_needs_prevention(1100,100) and not slowed.slow_needs_prevention(1100,700),"shorter and equal Slow attempts do not spend prevention")
	check(slowed.slow_needs_prevention(1100,701),"only a longer Slow is eligible to consume prevention")
	var protected := slowed.after_hit(1100,1000,220,true)
	check(not protected.slow_applied and protected.next_state.slow_until_ms()==1800 and protected.next_state.grace_until_ms()==1320,
		"prevented Slow retains the existing deadline while the valid hit still grants grace")
	var shorter := slowed.after_hit(1100,100,220,true)
	check(shorter.slow_applied and shorter.next_state.slow_until_ms()==1200,"existing shorter-Slow replacement rule survives without hidden immunity")
	var equal := slowed.after_hit(1100,700,220,true)
	check(equal.slow_applied and equal.next_state.slow_until_ms()==1800,"equal deadline still reports the authored Slow application")
	var longer := slowed.after_hit(1100,1000,220,false)
	check(longer.slow_applied and longer.next_state.slow_until_ms()==2100,"no valid prevention means the longer Slow applies")
	var ordinary := slowed.after_hit(1100,0,220,false)
	check(not ordinary.slow_applied and ordinary.next_state.slow_until_ms()==1800,"a hit without Slow leaves the old condition intact")
	var cleansed := slowed.cleanse_slow()
	check(cleansed.slow_until_ms()==0 and cleansed.grace_until_ms()==1220 and slowed.slow_until_ms()==1800,"cleansing only removes ordinary Slow, with immutable rollback")
	var revived := slowed.with_grace_until(2500)
	check(revived.grace_active(2499) and not revived.grace_active(2500) and revived.slow_until_ms()==1800,"revival grace does not cleanse Slow")
	var entry := revived.clear_grace()
	check(entry.grace_until_ms()==0 and entry.slow_until_ms()==1800,"entry clears only grace, preserving its existing lifecycle semantics")
	var returned := revived.clear_all()
	check(returned.grace_until_ms()==0 and returned.slow_until_ms()==0 and revived.grace_until_ms()==2500,"Garden return clears both conditions without modifying the old state")
	var contract := Conditions.rules_contract()
	var configured: Dictionary = Balance.values.combat
	var original_grace := int(configured.hit_grace_ms)
	var original_revival := int(configured.revival_grace_ms)
	var original_movement := float(configured.player_slow_movement_scale)
	configured.hit_grace_ms = original_grace + 1
	configured.revival_grace_ms = original_revival + 1
	configured.player_slow_movement_scale = original_movement + .125
	var changed := Conditions.rules_contract()
	check(changed.hit_grace_ms==original_grace+1 and changed.revival_grace_ms==original_revival+1
		and changed.player_slow_movement_scale==original_movement+.125
		and slowed.movement_scale(1100)==original_movement+.125
		and JSON.stringify(changed).sha256_text()!=JSON.stringify(contract).sha256_text(),
		"movement and definition contract follow the authoritative configuration")
	configured.hit_grace_ms = original_grace
	configured.revival_grace_ms = original_revival
	configured.player_slow_movement_scale = original_movement
	contract.hit_grace_ms=original_grace+1000
	check(int(configured.hit_grace_ms)==original_grace,"compatibility projection cannot modify authoritative content")
	if not failed: print("PASS: typed hit conditions, Slow prevention/replacement, grace, cleansing, lifecycle, rollback and tuning contract")
	quit(1 if failed else 0)
