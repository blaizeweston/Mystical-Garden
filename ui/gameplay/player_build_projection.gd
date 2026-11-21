extends RefCounted
## Pure display projection. Receives detached facts, never Game or an actor.
const Classes = preload("res://class_catalog.gd")
const Skills = preload("res://skill_catalog.gd")
const ResolvedBuild = preload("res://resolved_combat_build.gd")
const Cards = preload("res://affinity_cards.gd")
const Preview = preload("res://combat_balance_preview.gd")
const Traits = preload("res://combat_traits.gd")
const EXTRA_STATS := {
	"windup_damage": ["Wind-up damage", " hp", 1.0],
	"heal_on_kill": ["Health on kill", " hp", 1.0],
	"skill_heal": ["Class skill healing bonus", " HP", 1.0],
	"skill_duration": ["Class skill duration", " s", .001],
	"stagger": ["Hit stagger", " s", .001],
	"recovery": ["Enemy recovery", " s", .001],
	"knockback": ["Knockback", " m", 1.0],
	"pull": ["Pull", " m", 1.0],
}


static func class_profile(profile: Dictionary, class_id: int) -> Dictionary:
	return Classes.combat_profile(profile,class_id)

static func progression_profile(profile: Dictionary) -> Dictionary:
	return Classes.combat_profile(profile)

static func summary(facts: Dictionary) -> Dictionary:
	var stats: Dictionary = facts.get("stats",{}).duplicate(true)
	if stats.is_empty():
		return {}
	var rows: Array = []
	var class_id := int(facts.class_id)
	var base: Dictionary = Classes.DEFINITIONS[class_id].weapons[int(facts.weapon_kind)]
	var upgrades: Array = []
	if stats.has("affinity_build"):
		var copies: Array = facts.copies
		upgrades = Cards.owned_rows(copies)
	var resolved := ResolvedBuild.Snapshot.new(stats,Cards.applied_totals(facts.copies))
	stats = resolved.basic_stats()
	stats.interval = preload("res://fire_combat.gd").interval_with_tempo(int(stats.interval),int(facts.get("attack_speed_percent",0)))
	upgrades.sort_custom(func(a,b): return a.title.naturalnocasecmp_to(b.title) < 0)
	if stats.has("damage_min"):
		var band:=Vector2i(stats.damage_min,stats.damage_max)
		rows.append(["Damage", Preview.range_label(band)])
	else:
		rows.append(["Damage", compared(float(stats.damage), base.damage)])
	rows.append(["Reach", compared(stats.reach, base.reach, " m")])
	rows.append(["Attack speed", Preview.attack_speed(int(stats.interval)) + " attacks/sec",
		"Maximum attack speed is %s attacks/sec." % Preview.attack_speed(Cards.STRIKE_MIN_MS)])
	rows.append(["Weapon targets", compared(stats.targets, base.targets)])
	var base_hp: int=int(facts.base_hp)
	rows.append(["Max HP", compared(int(facts.max_hp), base_hp, " HP")])
	var dodge_ms := resolved.dodge_ms(int(facts.dodge_ms))
	rows.append(["Dodge cooldown", compared(dodge_ms / 1000.0, int(facts.dodge_ms) / 1000.0, " s"),
		"Minimum dodge cooldown is %s s." % decimal(Cards.DODGE_MIN_MS / 1000.0)])
	for slot in 2:
		var skill := resolved.class_skill(slot)
		if skill.is_empty(): skill = facts.skills[slot]
		var cooldown_ms := Skills.Balance.cooldown(skill,stats)
		rows.append([skill.name + " cooldown", decimal(cooldown_ms / 1000.0) + " s",
			"Minimum class ability cooldown is %s s." % decimal(Skills.Balance.COOLDOWN_MIN_MS / 1000.0)])
	for key in EXTRA_STATS:
		var value := float(stats.get(key, 0))
		if key=="heal_on_kill":
			if value>0.0:
				rows.append(["Healing on kill",Preview.heal_label(value)])
				var limit: int=int(facts.kill_heal_limit)
				rows.append(["Kill healing left this floor","%d / %d HP"%[int(stats.get("kill_heal_remaining",limit)),limit]])
			continue
		if key in ["windup_damage","heal_on_kill","skill_heal"]:
			value=float(Preview.effect_hp(value))
		if not is_zero_approx(value):
			var spec: Array = EXTRA_STATS[key]
			rows.append([spec[0], ("+" if value > 0 else "−") + decimal(absf(value)*float(spec[2])) + spec[1]])
	var unique: Array = stats.get("interactions", []).duplicate()
	if stats.has("affinity_build"):
		var grafts = preload("res://expedition_grafts.gd")
		var ledger: Dictionary = facts.grafts
		if not ledger.is_empty():
			var names: Dictionary = grafts.REINFORCEMENTS.merged(grafts.ADAPTATIONS)
			var counts := {}
			for copy: Dictionary in ledger.copies:
				counts[copy.id] = int(counts.get(copy.id,0)) + 1
			unique.append("Grafting Altar · %d purchases remaining" % int(ledger.remaining))
			for id: String in counts:
				unique.append(str(names[id].name) + (" ×%d" % counts[id] if int(counts[id])>1 else ""))
	if facts.has("recovery_band"):
		rows.append(["Next gate recovery",Preview.range_label(facts.recovery_band)+" HP"])
	if stats.pattern != base.pattern:
		unique.append("Attack pattern · " + str(stats.pattern).capitalize())
	var traits := {}
	for key in Traits.KEYS:
		if float(stats.get(key, 0)) > 0.0:
			traits[key] = snappedf(float(stats[key]), .01)
	var trait_text := Traits.describe(traits,true)
	if not trait_text.is_empty():
		unique.append(trait_text)
	return {"totals": rows, "cards": upgrades, "bonuses": "\n".join(unique) if not unique.is_empty() else "No unique bonuses active."}

static func decimal(value: float) -> String:
	return ("%.2f" % value).rstrip("0").trim_suffix(".")

static func compared(total: float, base: float, unit: String = "") -> String:
	var delta := total-base
	var formatted := decimal(total) + unit
	if not is_zero_approx(delta):
		formatted += "  (%s%s)" % ["+" if delta > 0 else "−", decimal(absf(delta)) + unit]
	return formatted
