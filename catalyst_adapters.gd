extends RefCounted

const Classes = preload("res://class_catalog.gd")

# One deliberate Catalyst response per native cast. Positions and targets
# come from the native action, never from a second targeting pass.
const ADAPTERS := {
	"self_guard": ["block", "protected_player", "self", "activation"],
	"party_guard": ["block", "protected_player", "granted_allies", "activation"],
	"party_ward": ["block", "protected_player", "granted_allies", "recipient"],
	"attack": ["activation", "impact", "affected_enemies", "activation"],
	"landing_attack": ["activation", "landing", "affected_enemies", "activation"],
	"field": ["activation", "field_center", "designated_area", "activation"],
	"trap": ["contact", "trap_center", "actual_contact", "target"],
	"delayed": ["contact", "impact", "actual_contact", "target"],
	"movement": ["activation", "departure_and_landing", "caster", "activation"],
	"heal": ["activation", "heal_center", "living_heal_recipients", "activation"],
}
# Each row selects one response family. These IDs describe future behavior.
const RESPONSES := {
	"attack": {"frost":"brittle", "fire":"burn", "water":"drench", "vital":"self_vitality",
		"thorn":"growth", "wood":"self_bark", "storm":"discharge", "spirit":"self_stride", "void":"compression"},
	"block": {"frost":"brittle_burst", "fire":"ember_burst", "water":"radial_wash", "vital":"radial_vitality",
		"thorn":"lingering_thicket", "wood":"radial_splinters_and_bark", "storm":"radial_discharge",
		"spirit":"radial_stride_and_trace", "void":"radial_repulsion"},
	"heal": {"frost":"recipient_frost_response", "fire":"recipient_ember_response", "water":"healing_wash",
		"vital":"recipient_vitality", "thorn":"protective_growth", "wood":"recipient_bark",
		"storm":"recipient_charge", "spirit":"recipient_stride", "void":"healing_repulsion"},
	"movement": {"frost":"self_frost_response", "fire":"self_ember_response", "water":"landing_wash",
		"vital":"landing_vitality", "thorn":"departure_growth", "wood":"landing_bark",
		"storm":"landing_discharge", "spirit":"departure_trace_and_landing_stride", "void":"landing_repulsion"},
}
# Rows are Q/R at the stable class-local positions. Legacy keys are learned node IDs.
const KITS := {
	"warden": {"base": ["self_guard", "attack"], "replacement": ["party_guard", "landing_attack"],
		"legacy": {"8":"party_guard", "9":"self_guard", "10":"attack", "11":"landing_attack"}},
	"weaver": {"base": ["attack", "attack"], "replacement": ["attack", "trap"],
		"legacy": {"8":"attack", "9":"field", "10":"trap", "11":"attack"}},
	"ranger": {"base": ["delayed", "trap"], "replacement": ["attack", "movement"],
		"legacy": {"8":"attack", "9":"attack", "10":"movement", "11":"trap"}},
	"reaper": {"base": ["delayed", "attack"], "replacement": ["landing_attack", "attack"],
		"legacy": {"8":"delayed", "9":"landing_attack", "10":"attack", "11":"delayed"}},
	"oracle": {"base": ["heal", "party_ward"], "replacement": ["party_ward", "attack"],
		"legacy": {"8":"party_ward", "9":"attack", "10":"party_ward", "11":"attack"}},
}
# Focus Q replaces the base kit. Focus R modifies its native skill and keeps
# that skill's trigger, even for a legacy replacement carried on an old mask.
const FOCUS_Q := {
	"vanguard":"self_guard", "rootkeeper":"self_guard", "bastion":"party_ward",
	"thornbinder":"attack", "bloomcaller":"field", "silkwarden":"party_ward",
	"wildstalker":"attack", "snarekeeper":"trap", "wayfarer":"movement",
	"blood_harvester":"attack", "veilwalker":"landing_attack", "gravekeeper":"attack",
	"omenreader":"attack", "leykeeper":"attack", "lifekeeper":"heal",
}
const CONFLICTS := {
	"sanctuary": "Only the initial Ward is armed. Renewal and field pulses remain native.",
	"reap": "The native Ward is retained; the Catalyst responds to the attack.",
	"harvest": "The native Ward is retained; the Catalyst responds to the attack.",
	"charge": "Native displacement takes priority on the affected enemies.",
	"gravekeeper": "The native hit Ward is retained; the Catalyst responds to the sweep.",
	"wayfarer": "Movement is the single response. The native snare remains separate.",
	"silkwarden": "Only actual block consumption responds, even when the cast also binds.",
	"leykeeper": "The native pull takes priority over Catalyst displacement.",
}
# CR05 review inputs. These are the existing consumers, not new scaling rules.
const PASSIVE_CONSUMERS := {
	"native_stats": ["max_health", "graft_chance", "familiarity", "dodge_cooldown"],
	"weapon_handling": ["damage", "reach", "cooldown", "stagger", "windup_damage", "knockback", "pull", "recovery", "targets", "heal_on_kill"],
	"native_skill_parameters": ["skill_duration", "skill_cooldown", "skill_heal"],
	"legacy_trait_review": ["directional_guard", "counter_damage", "ward_on_block", "shatter_damage",
		"counter_stagger", "spread_bind", "mark_damage", "growth_field", "precision", "decoy",
		"trap_power", "veil_mark", "death_charge", "reaper_momentum", "protect_growth", "omen", "pool_ward"],
	"legacy_rank_review": ["technique", "generic_duration", "extra_targets"],
	"cr05_adaptations": {
		"power": "Native legacy nodes can modify both Q/R and several parameters. Give any affinity scaling a separate consumer.",
		"duration": "Retain native bind, Guard, and field durations. Define Catalyst durations per response.",
		"targets": "Native weapon contact remains capped by weapon geometry. Set explicit targets for any extra affinity events.",
		"focus_masks": "Keep native Q replacements and R follow-through or anchor behavior. Do not migrate learned bits into affinity ranks.",
		"native_graft_procs": "Review old proc triggers and purchased-card lifetime independently of plant requirements.",
	},
}


static func resolve(class_id: int, slot: int, profile: Dictionary, skill: Dictionary) -> Dictionary:
	var frame: Dictionary = Classes.DEFINITIONS[class_id]
	var focus: String = skill.get("warden_focus", Classes.focus_id(profile, class_id))
	var kit: Dictionary = KITS[frame.id]
	var variant: String = skill.get("variant", "base")
	var stable_id := "%s/%s/%s" % [frame.id, variant, slot]
	var adapter: String = kit[variant][slot]
	var masks: Array = profile.get("upgrades", [])
	var mask := int(masks[class_id]) if class_id < masks.size() else 0
	for index in frame.nodes.size():
		var node: Dictionary = frame.nodes[index]
		var change: Dictionary = node.get("skill_change", {})
		if mask & (1 << index) and change.get("kind") == "modify" and int(change.slot) == slot:
			adapter = kit.legacy.get(node.id, "")
			stable_id = "%s/legacy/%s" % [frame.id, node.id]
	if not focus.is_empty():
		if not FOCUS_Q.has(focus):
			return {}
		if slot == 0:
			adapter = FOCUS_Q[focus]
			stable_id = "%s/focus/%s/Q" % [frame.id, focus]
		else:
			stable_id += "/focus/" + focus
	if not ADAPTERS.has(adapter):
		return {}
	var rule: Array = ADAPTERS[adapter]
	var group: String = rule[0] if rule[0] == "block" else adapter if adapter in ["heal", "movement"] else "attack"
	var displacement := {"push": skill.get("push", 0.0), "pull": skill.get("pull", 0.0)}
	return {
		"id": stable_id, "focus": focus, "slot": slot, "native_skill": skill.duplicate(true),
		"focus_change": "" if focus.is_empty() else "replaces" if slot == 0 else "modifies",
		"trigger": rule[0], "origin": "anchor_or_impact" if slot == 1 and skill.mode == "quake" and (focus == "rootkeeper" or skill.get("warden_relay",false)) else rule[1],
		"recipients": rule[2], "limit": rule[3], "responses": RESPONSES[group].duplicate(),
		"native_displacement": displacement,
		"conflict": CONFLICTS.get(focus if slot == 0 and CONFLICTS.has(focus) else skill.mode,
			"Native displacement takes priority." if displacement.push != 0 or displacement.pull != 0 else ""),
	}
