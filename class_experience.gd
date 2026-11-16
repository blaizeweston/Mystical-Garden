extends RefCounted
## Whole Class XP uses the same unit as the old fractional reward counter.
const VERSION_KEY := "class_xp_version"
const VERSION := 1
const LEGACY_SCALE := 10
const MAX_XP := 99999


static func current(profile: Dictionary) -> bool:
	var version: Variant = profile.get(VERSION_KEY)
	return version is int and version == VERSION


static func supported(profile: Dictionary) -> bool:
	return not profile.has(VERSION_KEY) or current(profile)


static func value(profile: Dictionary, class_id: int) -> int:
	var whole := _entry(profile.get("xp"), class_id)
	if current(profile):
		return clampi(whole, 0, MAX_XP)
	var fraction := _entry(profile.get("xp_tenths"), class_id)
	return clampi(whole, 0, MAX_XP / LEGACY_SCALE) * LEGACY_SCALE + clampi(fraction, 0, LEGACY_SCALE - 1)


static func _entry(values: Variant, index: int) -> int:
	return values[index] if values is Array and index < values.size() and values[index] is int else 0


## Retain the meaning of already-issued guest projection digests.
static func projection_input(profile: Dictionary) -> Dictionary:
	var points: Variant = profile.get("xp")
	if not current(profile) or not points is Array or not points.all(func(value): return value is int):
		return profile
	var legacy := profile.duplicate()
	legacy.erase(VERSION_KEY)
	legacy.xp = points.map(func(value: int) -> int: return value / LEGACY_SCALE)
	legacy.xp_tenths = points.map(func(value: int) -> int: return value % LEGACY_SCALE)
	return legacy
