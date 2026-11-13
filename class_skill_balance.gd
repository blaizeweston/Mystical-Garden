extends RefCounted
## Class effects are authored in points. Only absolute amounts convert to HP.
const Preview = preload("res://combat_balance_preview.gd")
const RENEWAL_INTERVAL_MS := 1000
const COUNTER_WINDOW_MS := 3500
const WARD_MS := 1400
const FOLLOWUP_POINTS := 1
const MARK_POINTS := 1
const LEGACY_DRAIN_CAP := 3.0


static func cooldown(skill: Dictionary, stats: Dictionary) -> int:
	return maxi(1800, int(skill.cooldown) - int(stats.get("skill_cooldown", 0)))


static func burst_points(skill: Dictionary) -> int:
	return 1 + int(skill.get("power", 0))


static func guard_charges(charges: int) -> int:
	return clampi(charges, 1, 4)


static func counter_points(stats: Dictionary) -> float:
	return Preview.proc_amount(1.0 + float(stats.get("counter_damage", 0)), 1, 4)


static func healing_bonus(stats: Dictionary) -> float:
	return Preview.authored_amount(float(stats.get("skill_heal", 0)))


static func direct_heal(skill: Dictionary, stats: Dictionary) -> float:
	return Preview.authored_amount(float(skill.get("heal", 0))) + healing_bonus(stats)


static func drain_per_target(skill: Dictionary) -> float:
	if skill.get("leech", false):
		return .6 if Preview.enabled else 1.0
	return minf(LEGACY_DRAIN_CAP, Preview.authored_amount(float(skill.get("heal", 0))))


static func drain_amount(skill: Dictionary, contacts: int) -> float:
	var points := drain_per_target(skill)
	if skill.get("leech", false):
		return (mini(3, contacts) + int(skill.get("first", -1) == 1 and contacts >= 2)) * points
	return minf(LEGACY_DRAIN_CAP, points * contacts)


static func field_power(skill: Dictionary) -> float:
	var kind := str(skill.get("field", ""))
	var points := float(skill.get("field_power", 1.0 if kind == "growth" or skill.mode != "subclass" else 0.0))
	if Preview.enabled and kind == "tide":
		return preload("res://expedition_sustain.gd").pool_points(points)
	return Preview.authored_amount(points)


static func bind_ms(skill: Dictionary, stats: Dictionary) -> int:
	var base := int(skill.get("bind", skill.get("duration", 0) if skill.mode in ["bind", "strangle"] else 0))
	return base + int(stats.get("skill_duration", 0)) if base > 0 else 0


static func subclass_bind(skill: Dictionary, card: Dictionary) -> int:
	return int(skill.get("bind", 0)) + int(card.get("bind", 0)) + (650 if int(skill.get("second", -1)) == 1 else 0)


static func duration(skill: Dictionary, stats: Dictionary, key: String = "duration", fallback: int = 0) -> int:
	return int(skill.get(key, fallback)) + int(stats.get("skill_duration", 0))


static func trap_duration(skill: Dictionary, stats: Dictionary) -> int:
	var base := int(skill.get("trap_ms", skill.get("duration", 3800) if skill.mode == "subclass" else 3800))
	return base + int(stats.get("skill_duration", 0)) if Preview.enabled else base


static func seconds(ms: int) -> String:
	return "%.2fs" % (ms / 1000.0) if ms % 100 != 0 else "%.1fs" % (ms / 1000.0)


static func hp_text(points: float) -> String:
	var amount := Preview.effect_hp(points)
	return "%d HP" % amount if Preview.enabled else str(amount)
