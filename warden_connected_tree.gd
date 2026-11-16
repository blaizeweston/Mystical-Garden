extends RefCounted
## CT01 uses stable node IDs in its own profile field. Historical bits stay in upgrades[0].
const PROFILE_KEY := "warden_connected"
const VERSION := 1
const REQUEST_OFFSET := 64
const XP_THRESHOLDS := [0, 5, 15, 35, 140, 260]
const LANES := ["Offensive", "Balanced", "Defensive"]
const Q_REFUND_MS := 1250
const FAULTLINE_POINTS := 1.0
const QUAKEFRONT_RADIUS := 0.6
const AFTERSHOCK_MS := 450
const AFTERSHOCK_HP := 8
const AFTERSHOCK_RADIUS := 2.25
const RELAY_MS := 5500
const RELAY_REACH := 5.0
const SANCTUARY_MS := 3500
const SANCTUARY_RADIUS := 3.0
const SANCTUARY_REDUCTION := 0.25
const ROWS := [
	[["vanguard", "Vanguard", "Learn Thorn Counter."],
	 ["rootkeeper", "Rootkeeper", "Learn Root Anchor."],
	 ["bastion", "Bastion", "Learn Rootshield."]],
	[["briar_rebound", "Briar Rebound", "Your first qualifying Q block pushes up to two lesser foes within 2.25 m outward by up to 0.85 m. Committed attacks resist."],
	 ["deep_roots", "Deep Roots", "Your starting focus gains 1.25 s of Thorn Counter's counter window, 1.5 m of Root Anchor reach, or 0.8 m of Rootshield radius."],
	 ["shared_guard", "Shared Guard", "Your first qualifying Q block grants one Guard for 0.95 s to the nearest eligible ally within 3 m, or to you when none qualifies."]],
	[["pinning_quake", "Pinning Quake", "Within 5.5 s of a qualifying Q block, your next Root Quake roots up to two surviving lesser foes it hits for 0.95 s."],
	 ["ready_footing", "Ready Footing", "Your first qualifying Q block readies your dodge if it is recovering."],
	 ["clear_the_way", "Clear the Way", "Your first qualifying Q block clears ordinary Slow from you and living allies in clear line within 3 m."]],
	[["faultline_impact", "Faultline Impact", "Within 5.5 s of a qualifying Q block, your next Root Quake deals 10 additional native HP damage per target hit."],
	 ["living_rhythm", "Living Rhythm", "Within 5.5 s of a qualifying Q block, your next Root Quake recovers 1.25 s of Q cooldown if it hits."],
	 ["sheltering_quake", "Sheltering Quake", "Within 5.5 s of a qualifying Q block, your next Root Quake grants allies in its area one Guard for 1.25 s."]],
	[["quakefront", "Quakefront", "Root Quake's native area gains 0.6 m of radius."],
	 ["measured_guard", "Measured Guard", "If Q grants protection and expires without any actual block from that cast, recover 1.25 s of its cooldown."],
	 ["holdfast", "Holdfast", "Unavailable. This node needs a player push and stagger resistance consumer."]],
	[["aftershock", "Aftershock", "Within 5.5 s of a qualifying Q block, your next Root Quake creates a secondary impact after 0.45 s. It deals 8 base HP within 2.25 m."],
	 ["seismic_relay", "Seismic Relay", "A qualifying Q block leaves a relay for 5.5 s. Your next Root Quake uses it when it is in clear line within 5 m."],
	 ["sanctuary_ground", "Sanctuary Ground", "A qualifying Q block creates a 3 m sanctuary for 3.5 s. Living allies inside take 25% less direct attack damage."]],
]
const VERSION_DATA := [VERSION, XP_THRESHOLDS, LANES, ROWS, Q_REFUND_MS, FAULTLINE_POINTS,
	QUAKEFRONT_RADIUS, AFTERSHOCK_MS, AFTERSHOCK_HP, AFTERSHOCK_RADIUS, RELAY_MS, RELAY_REACH,
	SANCTUARY_MS, SANCTUARY_RADIUS, SANCTUARY_REDUCTION]
static var NODES: Array[Dictionary] = make_nodes()


static func make_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tier in ROWS.size():
		for lane in LANES.size():
			var definition: Array = ROWS[tier][lane]
			var parents: Array[String] = []
			if tier > 0:
				for adjacent in range(maxi(0, lane - 1), mini(LANES.size(), lane + 2)):
					parents.append(ROWS[tier - 1][adjacent][0])
			result.append({"id":definition[0], "name":definition[1], "description":definition[2],
				"tier":tier, "level":tier + 1, "lane":lane, "parents":parents,
				"enabled":definition[0] != "holdfast"})
	return result


static func eligible(profile: Dictionary) -> bool:
	var upgrades: Array = profile.get("upgrades", [])
	if not upgrades.is_empty() and int(upgrades[0]) != 0:
		return false
	var preserved: Variant = profile.get("quarantine", {}).get("learned_class_masks", {})
	return not preserved is Dictionary or not preserved.has("warden")


static func in_world(game: Node, class_id: int, profile: Dictionary) -> bool:
	return class_id == 0 and game.has_meta(&"combat_affinity_ruleset") and eligible(profile)


static func level(profile: Dictionary) -> int:
	var xp: Array = profile.get("xp", [0])
	var earned := int(xp[0]) if not xp.is_empty() else 0
	var result := 1
	for index in range(1, XP_THRESHOLDS.size()):
		if earned < XP_THRESHOLDS[index]:
			break
		result += 1
	return result


static func node(id: Variant) -> Dictionary:
	for entry in NODES:
		if entry.id == id:
			return entry
	return {}


static func valid(profile: Dictionary) -> bool:
	if not profile.has(PROFILE_KEY):
		return true
	var state: Variant = profile[PROFILE_KEY]
	if not state is Dictionary or not state.get("version") is int or state.get("version") != VERSION or not state.get("path") is Array:
		return false
	var selected: Array = state.path
	if selected.size() > level(profile):
		return false
	for index in selected.size():
		var entry := node(selected[index])
		if not selected[index] is String or entry.is_empty() or not entry.enabled or int(entry.tier) != index:
			return false
		if index > 0 and not entry.parents.has(selected[index - 1]):
			return false
	return true


static func path(profile: Dictionary) -> Array:
	return profile[PROFILE_KEY].path if profile.has(PROFILE_KEY) and valid(profile) else []


static func focus(profile: Dictionary) -> String:
	var selected := path(profile)
	return "" if selected.is_empty() else str(selected[0])


static func state(selected: Array) -> Dictionary:
	return {"version": VERSION, "path": selected}


static func refusal(profile: Dictionary, request: int) -> String:
	if not eligible(profile):
		return "This Warden keeps its historical class tree."
	if not valid(profile):
		return "This character's connected Warden data needs review before it can change."
	var index := request - REQUEST_OFFSET
	if index < 0 or index >= NODES.size():
		return "Select a node in the connected Warden tree."
	var entry := NODES[index]
	if not entry.enabled:
		return str(entry.description)
	var selected := path(profile)
	if entry.tier != selected.size():
		return "Select one node in the next tier."
	if level(profile) <= selected.size():
		return "Reach Warden level %d for this selection." % entry.level
	if not selected.is_empty() and not entry.parents.has(selected.back()):
		return "Choose a node connected to your last selection."
	return ""


static func learn(profile: Dictionary, request: int) -> String:
	var reason := refusal(profile, request)
	if not reason.is_empty():
		return reason
	var selected := path(profile).duplicate()
	selected.append(NODES[request - REQUEST_OFFSET].id)
	profile[PROFILE_KEY] = state(selected)
	return ""
