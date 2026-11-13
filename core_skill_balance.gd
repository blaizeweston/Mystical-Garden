extends RefCounted
## Core numbers stay in authored points through contact. The vitals boundary converts them to HP.
const Preview = preload("res://combat_balance_preview.gd")
const EMBER_INTERVAL_MS := 850
const CHAIN_HOP_POINTS := 1.0
const SHATTER_POINTS := 2.0
const WAVE_TRAVEL_MS := 700
const THORN_REFUND_MS := 3000

const TUNING_LABELS := {
	"radius":"Radius", "half_length":"Half-length", "quake_reach":"Quake reach", "trip_pull":"Pull distance",
	"chain_range":"Jump range", "beam_range":"Beam reach", "burst_radius":"Burst radius",
	"displacement_bonus":"Extra displacement", "field_ms":"Field duration", "lifetime_ms":"Duration",
	"mark_ms":"Mark or link duration", "root_ms":"Root duration", "inner_root_ms":"Inner root duration",
	"chain_root_ms":"Root per jump", "mark_root_ms":"Mark root duration", "link_root_ms":"Link root duration",
	"root_on_damage_ms":"Root on damage", "root_on_interrupt_ms":"Root on interrupt", "root_bonus_ms":"Extra root duration",
	"stagger_ms":"Stagger", "opening_stagger_ms":"Opening stagger", "block_stagger_ms":"Stagger on block",
	"ward_ms":"Ward on cast", "ward_on_hit_ms":"Ward on contact", "contact_ward_ms":"Ward on ally contact",
	"area_guard_ms":"Ally ward in the flash", "rearm_ms":"Rearm delay",
	"beam_damage":"Beam damage", "mark_damage":"Mark or link damage", "bite_bonus":"Bonus bite damage",
	"heal_bonus":"Extra healing", "death_heal":"Corpse burst healing", "siphon_cap":"Maximum siphon targets",
	"chain_targets":"Maximum jumps",
}
const ABSOLUTE_KEYS := ["beam_damage","mark_damage","bite_bonus","heal_bonus","death_heal"]


static func enemy_points(effect: Dictionary, winding: bool) -> float:
	var result := Preview.authored_amount(float(effect.get("damage", 0)))
	if winding:
		result += Preview.authored_amount(float(effect.get("windup_damage", 0)))
	return result


static func heal_points(skill: Dictionary, effect: Dictionary) -> float:
	return Preview.authored_amount(float(effect.get("heal", 0))) + Preview.authored_amount(float(skill.get("heal_bonus", 0)))


static func siphon_contacts(skill: Dictionary, phase: Dictionary, damaged: int) -> int:
	return mini(int(skill.get("siphon_cap", phase.siphon)), damaged)


static func siphon_points(contacts: int) -> float:
	return contacts * (.6 if Preview.enabled else 1.0)


static func phases(skill: Dictionary) -> Array:
	var result: Array = skill.get("phases", []).duplicate()
	for key in ["extra_phase", "graft_phase"]:
		if skill.has(key):
			result.append(skill[key])
	result.sort_custom(func(a, b): return a.delay < b.delay)
	return result


static func hp(points: float) -> String:
	return "%d HP" % Preview.effect_hp(points)


static func seconds(ms: int) -> String:
	var value := ("%.3f" % (ms / 1000.0)).rstrip("0").trim_suffix(".")
	return value + "s"


static func effect_lines(skill: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if skill.has("damage"):
		var amount := hp(float(skill.damage)) + " damage"
		if skill.mechanic == "line_trap":
			amount += " per enemy every " + seconds(int(skill.interval_ms))
		elif skill.get("contact") == "chain":
			amount += " on first hit · " + hp(CHAIN_HOP_POINTS) + " per jump"
		else:
			amount += " per target · Up to %d targets" % int(skill.targets)
		lines.append(amount)
	if skill.has("mark_damage"):
		var label := "Linked hit" if skill.mechanic=="ground_sequence" else "Mark burst"
		lines.append(label + " · " + hp(float(skill.mark_damage)) + " damage · " + seconds(int(skill.mark_ms)) + " window")
	if skill.has("beam_damage"):
		lines.append(hp(float(skill.beam_damage)) + " beam damage per enemy")
	if skill.has("bite_bonus"):
		var bite: Dictionary = skill.phases.back().enemy
		var points := enemy_points(bite, false) + Preview.authored_amount(float(skill.bite_bonus))
		lines.append(hp(points) + " bite damage to enemies swept into the maw")
	if skill.has("death_heal"):
		lines.append("Corpse burst restores " + Preview.heal_label(heal_points(skill, {"heal":skill.death_heal})) + " per ally")
	if skill.has("ward_ms"):
		lines.append("Ward on cast · One hit for " + seconds(int(skill.ward_ms)))
	if skill.has("ward_on_hit_ms"):
		lines.append("Ward on contact · One hit for " + seconds(int(skill.ward_on_hit_ms)))
	for phase in phases(skill):
		var enemy: Dictionary = phase.get("enemy", {})
		var ally: Dictionary = phase.get("ally", {})
		var effects: Array[String] = []
		if enemy.has("damage"):
			effects.append(hp(enemy_points(enemy, false)) + " damage per target")
		if enemy.has("windup_damage"):
			effects.append(hp(enemy_points(enemy, true)) + " total against enemies winding up")
		if ally.has("heal"):
			effects.append("Restores " + Preview.heal_label(heal_points(skill, ally)) + " per ally")
		var ward := int(skill.get("contact_ward_ms", ally.get("guard_ms", 0))) if phase.has("ally") else 0
		if ward > 0:
			effects.append("Wards one hit for " + seconds(ward))
		if phase.has("siphon"):
			var cap := siphon_contacts(skill, phase, 99)
			var spread := Preview.HEAL_DRAIN_SPREAD_HP
			effects.append("Drains " + Preview.heal_label(siphon_points(1),spread) + " with one enemy hit · " + Preview.heal_label(siphon_points(cap),spread) + " at the target cap")
			effects.append("Drains from regular enemies, elites and bosses.")
		if effects.is_empty():
			continue
		var label := ""
		if skill.id == "ember_wake":
			label = "Every " + seconds(EMBER_INTERVAL_MS) + " per enemy"
		elif skill.has("death_window_ms"):
			label = "Corpse burst"
		elif skill.has("trap_ms"):
			label = "On contact" if phase == skill.phases[0] else "After " + seconds(phase.delay)
		elif skill.get("footprint") == "wave" and ally.has("heal"):
			label = "Returning wave"
		elif int(phase.delay) > 0:
			label = "After " + seconds(phase.delay)
		lines.append((label + " · " if not label.is_empty() else "") + " · ".join(effects))
	if skill.has("area_guard_ms"):
		lines.append("Wards allies in the flash against one hit for " + seconds(int(skill.area_guard_ms)))
	return lines


static func tuning_lines(values: Dictionary, skill_id: String = "") -> Array[String]:
	var lines: Array[String] = []
	for key in values:
		var value = values[key]
		if key in ["extra_phase", "graft_phase"]:
			var timing := "Returning wave · " if skill_id == "riptide" else "After " + seconds(int(value.delay)) + " · "
			for effect in value.get("enemy", {}):
				var amount: float = value.enemy[effect]
				match effect:
					"damage": lines.append(timing + hp(amount) + " damage per target")
					"windup_damage": lines.append(timing + "+" + hp(amount) + " against enemies winding up")
					"root_ms": lines.append(timing + "Roots for " + seconds(int(amount)))
					"stagger_ms": lines.append(timing + "Staggers for " + seconds(int(amount)))
					"interrupt_ms": lines.append(timing + "Interrupts for " + seconds(int(amount)))
					"brittle": lines.append(timing + "%d Brittle stack(s)" % int(amount))
					"displace": lines.append(timing + ("Pulls" if amount < 0 else "Pushes") + " idle enemies %.2f m" % absf(amount))
					_: pass
			if value.get("ally", {}).has("heal"):
				lines.append(timing + Preview.heal_label(float(value.ally.heal)) + " healing per ally before bonuses")
			if value.get("ally", {}).has("guard_ms"):
				lines.append(timing + "Wards one hit for " + seconds(int(value.ally.guard_ms)))
			continue
		if not TUNING_LABELS.has(key):
			continue
		var formatted := str(value).trim_suffix(".0")
		if key=="death_heal":
			formatted = Preview.heal_label(float(value))
		elif key in ABSOLUTE_KEYS:
			formatted = hp(float(value))
		elif key.ends_with("_ms"):
			formatted = seconds(int(value))
		elif key in ["radius","half_length","quake_reach","trip_pull","chain_range","beam_range","burst_radius","displacement_bonus"]:
			formatted += " m"
		lines.append(TUNING_LABELS[key] + " · " + formatted)
	return lines
