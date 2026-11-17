extends RefCounted
## Host health value. Native capacity is resolved by combat balance before
## attachment. Temporary Vitality changes effective capacity without healing.

const STATE := "player_vitals"
const Amounts = preload("res://combat_vitals.gd")

class Health extends RefCounted:
	var _hp: float
	var _native_max_hp: int
	var _temporary_hp: int

	func _init(current_hp: float, native_capacity_hp: int, temporary_capacity_hp: int = 0) -> void:
		_native_max_hp = maxi(0, native_capacity_hp)
		_temporary_hp = maxi(0, temporary_capacity_hp)
		_hp = clampf(current_hp, 0.0, float(max_hp()))

	func hp() -> float:
		return _hp

	func native_max_hp() -> int:
		return _native_max_hp

	func temporary_hp() -> int:
		return _temporary_hp

	func max_hp() -> int:
		return _native_max_hp + _temporary_hp

	func with_capacity(native_capacity_hp: int, temporary_capacity_hp: int) -> Health:
		if native_capacity_hp == _native_max_hp and temporary_capacity_hp == _temporary_hp:
			return self
		return Health.new(_hp, native_capacity_hp, temporary_capacity_hp)

	func with_native_max_hp(native_capacity_hp: int) -> Health:
		return with_capacity(native_capacity_hp, _temporary_hp)

	func with_hp(current_hp: float) -> Health:
		var bounded_hp := clampf(current_hp, 0.0, float(max_hp()))
		if bounded_hp == _hp:
			return self
		return Health.new(bounded_hp, _native_max_hp, _temporary_hp)

	func healed(amount_hp: int) -> Health:
		return with_hp(_hp + maxi(0, amount_hp))

	## Damage has always resolved in whole HP. Healing can retain fractional HP.
	func damaged(amount_hp: int) -> Health:
		return with_hp(int(_hp) - Amounts.damage_taken(int(_hp), amount_hp))

	func refilled() -> Health:
		return with_hp(float(max_hp()))

## Install the next host health value and return detached damage facts.
## The legacy path records zero damage. Preview mode keeps fractional HP intact
## when no whole HP was lost.
static func apply_damage(record: Dictionary, amount_hp: int, record_zero: bool) -> Dictionary:
	var health: Health = record.get(STATE)
	if health == null:
		return {}
	var damaged := health.damaged(amount_hp)
	var applied_hp := int(health.hp()) - int(damaged.hp())
	var recorded := record_zero or applied_hp > 0
	if recorded:
		record[STATE] = damaged
	return {"applied_hp": applied_hp, "hp": damaged.hp() if recorded else health.hp(), "recorded": recorded}

## Read either a host value or the existing detached guest/HUD projection.
## These queries never install a component or write projection fields.
static func current_hp(record: Dictionary, fallback: float = 0.0) -> float:
	var health: Health = record.get(STATE)
	return health.hp() if health != null else float(record.get("hp", fallback))

static func maximum_hp(record: Dictionary, fallback: int = 10) -> int:
	var health: Health = record.get(STATE)
	return health.max_hp() if health != null else int(record.get("max_hp", fallback))

static func temporary_hp(record: Dictionary) -> int:
	var health: Health = record.get(STATE)
	return health.temporary_hp() if health != null else 0
