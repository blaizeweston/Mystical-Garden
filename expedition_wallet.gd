extends RefCounted
## Host-side expedition currency. A credit or debit returns a new wallet so
## guarded transactions can restore the previous reference on rollback.
const STATE := "expedition_wallet"
const ESSENCE_PER_CLEARED_FLOOR := 2


class Wallet extends RefCounted:
	var _earned_sparks: int
	var _spent_essence: int

	func _init(granted_sparks: int = 0, spent_amount: int = 0) -> void:
		_earned_sparks = granted_sparks
		_spent_essence = spent_amount

	func earned_sparks() -> int:
		return _earned_sparks

	func spent_essence() -> int:
		return _spent_essence

	func credit_sparks(sparks: int) -> Wallet:
		return Wallet.new(_earned_sparks + sparks, _spent_essence) if sparks > 0 else self

	# Kill awards accumulate as sparks. Spending and floor grants use whole
	# Essence. The clearance milestone comes from expedition progression.
	func balance(cleared_floor: int, sparks_per_essence: int) -> int:
		@warning_ignore("integer_division")
		var kill_essence := _earned_sparks / sparks_per_essence
		return maxi(0, cleared_floor * ESSENCE_PER_CLEARED_FLOOR + kill_essence - _spent_essence)

	func plan_debit(cost: int, cleared_floor: int, sparks_per_essence: int) -> Wallet:
		if cost < 0 or cost > balance(cleared_floor, sparks_per_essence):
			return null
		return Wallet.new(_earned_sparks, _spent_essence + cost) if cost > 0 else self

	func projection(cleared_floor: int, sparks_per_essence: int) -> Dictionary:
		return {"balance": balance(cleared_floor, sparks_per_essence),
			"earned_sparks": _earned_sparks, "spent_essence": _spent_essence,
			"milestone_essence": cleared_floor * ESSENCE_PER_CLEARED_FLOOR}
