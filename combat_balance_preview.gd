extends RefCounted

const Session = preload("res://network_session.gd")
## Authoritative modern combat HP, damage rolls and healing rolls.
## The historical filename and playtest flag remain for isolated save routing.
const PlayerVitals = preload("res://player_vitals.gd")
const Vitals = preload("res://combat_vitals.gd")
const FLAG := "--combat-balance-preview"
const STORAGE_PATH := "user://combat-balance-preview"
const DEFAULT_SPREAD_HP := 2
const COMPONENT_HP_LABELS := {
	"damage":"strike damage", "windup_damage":"damage against enemies winding up",
	"heal_on_kill":"base healing on kill", "skill_heal":"class-skill healing bonus", "max_health":"maximum health",
	"shatter_damage":"Shatter damage", "mark_damage":"Mark damage", "link_damage":"linked damage",
	"counter_damage":"counter damage", "tide_pool":"base healing pool potency",
	"cinder_trail":"Cinder Trail damage", "chorus_pulse":"Chorus Pulse damage",
}
const ORCHARD_FLOOR := 10
const RENEWAL_HP := 4
const HEAL_SPREAD_HP := 2
const HEAL_TICK_SPREAD_HP := 1
const HEAL_DRAIN_SPREAD_HP := 1

static var playtest := OS.get_cmdline_user_args().has(FLAG)
static var strike_rng := make_rng()
static var heal_rng := make_rng()


static func make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng


static func scale() -> int:
	return Vitals.PROTOTYPE_HP_PER_POINT


static func hp(authored_points: int) -> int:
	return Vitals.points(authored_points, scale())


static func effect_hp(authored_points: float) -> int:
	return roundi(authored_points * scale())


static func authored_amount(value: float) -> float:
	return value


static func capped_amount(value: float, cap: int) -> Variant:
	return minf(value, cap)


static func maximum_health(base_health: int, bonus: float, lost_health: int, card_health: int) -> int:
	return Vitals.maximum(hp(base_health), effect_hp(authored_amount(bonus)) + card_health, lost_health, scale())


static func proc_amount(value: float, legacy_minimum: int, cap: int) -> float:
	return clampf(value, .1 * legacy_minimum, cap)


static func heal_band(center_hp: int, spread_hp: int = HEAL_SPREAD_HP) -> Vector2i:
	var center := maxi(0, center_hp)
	var spread := clampi(spread_hp, 0, maxi(0, center - 1))
	return Vector2i(center - spread, center + spread)


static func roll_heal_hp(center_hp: int, spread_hp: int = HEAL_SPREAD_HP) -> int:
	var band := heal_band(center_hp, spread_hp)
	return heal_rng.randi_range(band.x, band.y) if band.x != band.y else band.x


static func roll_heal(authored_points: float, spread_hp: int = HEAL_SPREAD_HP) -> int:
	return roll_heal_hp(effect_hp(authored_points), spread_hp)


static func apply_heal(actor: Dictionary, rolled_hp: int, source: String, limit_hp: int = -1) -> float:
	var health: PlayerVitals.Health = actor[PlayerVitals.STATE]
	var applied_health := health.healed(mini(rolled_hp,limit_hp) if limit_hp>=0 else rolled_hp)
	actor[PlayerVitals.STATE] = applied_health
	var applied := maxf(0.0, applied_health.hp()-health.hp())
	if rolled_hp > 0:
		var journal = preload("res://diagnostic_journal.gd")
		if is_instance_valid(journal.current) and journal.current.detail:
			journal.event("combat", "healing_applied", {"source":source,"party_slot":Session.slot_for(actor,-1),
				"rolled_hp":rolled_hp,"applied_hp":applied,"hp":applied_health.hp(),"max_hp":applied_health.max_hp()},"debug")
	return applied


static func heal(actor: Dictionary, authored_points: float, spread_hp: int = HEAL_SPREAD_HP, source: String = "heal") -> float:
	return apply_heal(actor, roll_heal(authored_points, spread_hp), source)


static func heal_label(authored_points: float, spread_hp: int = HEAL_SPREAD_HP) -> String:
	return range_label(heal_band(effect_hp(authored_points), spread_hp)) + " HP"


static func component_hp_text(values: Dictionary) -> String:
	var lines: Array[String] = []
	for key in COMPONENT_HP_LABELS:
		if values.has(key):
			var amount := effect_hp(float(values[key]))
			if amount != 0:
				lines.append("%+d HP %s" % [amount, COMPONENT_HP_LABELS[key]])
	return "\n".join(lines)


static func revive_cost() -> int:
	return hp(Vitals.REVIVE_POINTS)


static func armor(amount: int) -> int:
	var balance=load("res://enemy_balance.gd")
	return balance.armor(amount)


static func attack_speed(interval_ms: int) -> String:
	return "%.2f" % (1000.0 / interval_ms)


static func weapon_range(stats: Dictionary, power: int) -> Vector2i:
	var center := effect_hp(float(stats.damage) + power)
	var spread := int(stats.get("roll_spread_hp", DEFAULT_SPREAD_HP))
	return Vector2i(maxi(1, center - spread), maxi(1, center + spread))


static func range_label(band: Vector2i) -> String:
	return str(band.x) if band.x == band.y else "%d–%d" % [band.x, band.y]


static func lock_strike(stats: Dictionary, power: int) -> void:
	var band := weapon_range(stats, power)
	var center := effect_hp(float(stats.damage) + power)
	stats.preview_power = power
	stats.preview_strike_hp = strike_rng.randi_range(band.x, band.y) if band.x != band.y else band.x
	stats.preview_roll_delta = int(stats.preview_strike_hp) - center


static func resolved_hit(authored_damage: float, stats: Dictionary) -> int:
	var delta := 0 if stats.get("trait_secondary", false) or stats.get("core_hit", false) else int(stats.get("preview_roll_delta", 0))
	return maxi(0, effect_hp(authored_damage) + delta)


static func followup_amount(stats: Dictionary, linked: bool, pulse: bool) -> float:
	var points := float(stats.damage)
	if not pulse and stats.has("preview_strike_hp"):
		points = float(stats.preview_strike_hp) / scale()
	if pulse:
		return points
	var amount := points * .5
	if linked:
		amount += float(stats.get("link_damage", 0)) + maxf(0, float(stats.get("link", 1)) - 1.0) * .5
	return maxf(.1, amount)
