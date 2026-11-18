extends SceneTree
const Protection = preload("res://player_protection.gd")
const Balance = preload("res://class_skill_balance.gd")
var failed := false

class Response extends RefCounted:
	var recipients: Array[int] = []
	var spent := false
	func accept_grant(id: int) -> bool:
		if id <= 0 or id in recipients: return false
		recipients.append(id)
		return true
	func block_available(_id: int, _adapter: Dictionary, _now: int) -> bool:
		return not spent

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL player protection: ",message)

func run() -> void:
	var empty := Protection.State.new()
	check(empty.charge_count()==0 and empty.claim_count()==0 and not empty.allows_block(Vector3.ZERO,Vector3.INF,0),"new life has no protection")
	var native := empty.grant(1500,1,1000,7)
	var source := Response.new()
	var adapter := {"id":"fixture","trigger":"block","limit":"recipient"}
	var overlap := native.grant(1500,2,1000,7,source,adapter,2)
	check(empty.guard_until_ms()==0 and native.charge_count()==1 and overlap.charge_count()==2 and overlap.claim_count()==2,
		"grants create immutable successors and max-merge rather than adding charges")
	var ordinary_block := overlap.consume_block(1100,7,2)
	check(ordinary_block.response==null and ordinary_block.next_state.charge_count()==1 and ordinary_block.next_state.claim_count()==1,
		"an ordinary claim wins equal-expiry host order without a Catalyst response")
	var enhanced_block := ordinary_block.next_state.consume_block(1101,7,2)
	check(enhanced_block.response==source and enhanced_block.next_state.charge_count()==0 and enhanced_block.next_state.claim_count()==0
		and enhanced_block.next_state.guard_until_ms()==0,"next actual block selects just the originating event and exhausts protection")
	check(overlap.charge_count()==2 and overlap.claim_count()==2,"block leaves rollback state intact")
	adapter.id="changed"
	check(enhanced_block.adapter.id=="fixture","response definition is detached from the grant caller")
	var duplicate := overlap.grant(1900,2,1000,7,source,adapter,2)
	check(duplicate.guard_until_ms()==1900 and duplicate.claim_count()==2,"same activation can refresh native protection but cannot renew its response claim")
	var expired := duplicate.consume_block(1600,7,2)
	check(expired.response==null and expired.next_state.charge_count()==1 and expired.next_state.claim_count()==0,"expired claim cannot activate through a longer native refresh")
	check(duplicate.expire_claims(1900).claim_count()==0 and duplicate.claim_count()==2,"status expiry prunes only the successor")
	var short := Response.new()
	var long := Response.new()
	var mixed := empty.grant(1900,1,1000,7,long,adapter,2).grant(1300,2,1000,7,short,adapter,2)
	check(mixed.consume_block(1100,7,2).response==short,"earliest expiry wins even when accepted later")
	check(mixed.consume_block(1100,8,2).response==null,"old floor claims never publish on a new floor")
	short.spent=true
	check(mixed.consume_block(1100,7,2).response==long,"already-used source budget cannot take another block")
	var capped := empty.grant(4000,20,1000,7)
	check(capped.charge_count()==Balance.guard_charges(20),"existing authored charge bound remains authoritative")
	var directional := native.with_front_guard(1800,Vector3.FORWARD).with_counter_guard(1600)
	check(directional.allows_block(Vector3.ZERO,Vector3.FORWARD,1100) and not directional.allows_block(Vector3.ZERO,Vector3.BACK,1100)
		and directional.allows_block(Vector3.ZERO,Vector3.INF,1100),"directional footprint and unspecified-origin policy are unchanged")
	check(directional.movement_scale(1799)==Balance.FRONT_GUARD_SPEED_SCALE and directional.movement_scale(1800)==1.0,
		"directional movement window has the existing independent deadline")
	var counter := directional.prepare_counter(4500,2.0).extend_ready_counter(1100,1250)
	check(counter.counter_until_ms()==5750 and counter.counter_points()==2 and counter.counter_guard_active(1599)
		and not counter.counter_guard_active(1600),"native counter readiness, power and learned extension have explicit units")
	check(counter.spend_counter().counter_until_ms()==0 and counter.counter_until_ms()==5750,"one hit consumes readiness without mutating the prior value")
	var fallen := counter.clear_guard()
	check(fallen.guard_until_ms()==0 and fallen.claim_count()==0 and fallen.charge_count()==counter.charge_count()
		and fallen.counter_until_ms()==5750,"fall/revival preserves the existing native windows while clearing protection")
	var returned := counter.clear_expedition()
	check(returned.guard_until_ms()==0 and returned.charge_count()==0 and returned.claim_count()==0
		and returned.counter_until_ms()==0 and not returned.counter_guard_active(1100) and returned.movement_scale(1100)==1,
		"entry/return clears expedition protection without sharing mutable claims")
	if not failed: print("PASS: owned protection, immutable rollback, Ward source priority, charge limits, native counters and lifecycle")
	quit(1 if failed else 0)
