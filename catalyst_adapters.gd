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
# Connected focuses replace native Q; all classes retain their authored base R.
const KITS := {"warden":["self_guard","attack"],"weaver":["attack","attack"],
	"ranger":["delayed","trap"],"reaper":["delayed","attack"],"oracle":["heal","party_ward"]}
const FOCUS_Q := {
	"vanguard":"self_guard", "rootkeeper":"self_guard", "bastion":"party_ward",
	"thornbinder":"attack", "bloomcaller":"field", "silkwarden":"party_ward",
	"wildstalker":"attack", "snarekeeper":"trap", "wayfarer":"movement",
	"blood_harvester":"attack", "veilwalker":"landing_attack", "gravekeeper":"attack",
	"omenreader":"attack", "leykeeper":"attack", "lifekeeper":"heal",
}
const CONFLICTS := {
	"gravekeeper": "The native hit Ward is retained; the Catalyst responds to the sweep.",
	"wayfarer": "Movement is the single response. The native snare remains separate.",
	"silkwarden": "Only actual block consumption responds, even when the cast also binds.",
	"leykeeper": "The native pull takes priority over Catalyst displacement.",
}
static func resolve(class_id: int, slot: int, _profile: Dictionary, skill: Dictionary) -> Dictionary:
	var frame: Dictionary = Classes.DEFINITIONS[class_id]
	var focus: String = skill.get("warden_focus",skill.get("subclass_focus",""))
	var stable_id := "%s/base/%s" % [frame.id,slot]
	var adapter: String = KITS[frame.id][slot]
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
