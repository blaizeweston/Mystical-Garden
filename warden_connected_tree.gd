extends RefCounted
## CT01 uses stable node IDs in its own profile field. Historical bits stay in upgrades[0].
const PROFILE_KEY := "warden_connected"
const Model = preload("res://connected_class_tree.gd")
const VERSION := Model.VERSION
const REQUEST_OFFSET := Model.REQUEST_OFFSET
const XP_THRESHOLDS := Model.XP_THRESHOLDS
const LANES := Model.LANES
const Q_REFUND_MS := 1250
const FAULTLINE_POINTS := 1.0
const QUAKEFRONT_RADIUS := 0.6
const AFTERSHOCK_MS := 450
const AFTERSHOCK_HP := 8
const AFTERSHOCK_RADIUS := 2.25
const RELAY_MS := 5500
const RELAY_REACH := 5.0
const HOLDFAST_MS := 2500
const HOLDFAST_RADIUS := 3.0
const HOLDFAST_REDUCTION := 0.15
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
	 ["holdfast", "Holdfast", "The first actual block from your Q grants you and living allies within 3 m and clear line 15% less direct attack damage for 2.5 s. Holdfast follows recipients. Another grant refreshes its duration. Only the stronger protection applies inside Sanctuary Ground."]],
	[["aftershock", "Aftershock", "Within 5.5 s of a qualifying Q block, your next Root Quake creates a secondary impact after 0.45 s. It deals 8 base HP within 2.25 m."],
	 ["seismic_relay", "Seismic Relay", "A qualifying Q block leaves a relay for 5.5 s. Your next Root Quake uses it when it is in clear line within 5 m."],
	 ["sanctuary_ground", "Sanctuary Ground", "A qualifying Q block creates a 3 m sanctuary for 3.5 s. Living allies inside take 25% less direct attack damage."]],
]
const VERSION_DATA := [VERSION, XP_THRESHOLDS, LANES, ROWS, Q_REFUND_MS, FAULTLINE_POINTS,
	QUAKEFRONT_RADIUS, AFTERSHOCK_MS, AFTERSHOCK_HP, AFTERSHOCK_RADIUS, RELAY_MS, RELAY_REACH,
	HOLDFAST_MS, HOLDFAST_RADIUS, HOLDFAST_REDUCTION, SANCTUARY_MS, SANCTUARY_RADIUS, SANCTUARY_REDUCTION]
static var TREE := Model.new(0,"warden","Warden",PROFILE_KEY,ROWS)
static var NODES: Array[Dictionary] = TREE.nodes


static func eligible(profile: Dictionary) -> bool:
	return TREE.eligible(profile)


static func level(profile: Dictionary) -> int:
	return TREE.level(profile)


static func node(id: Variant) -> Dictionary:
	return TREE.node(id)


static func valid(profile: Dictionary) -> bool:
	return TREE.valid(profile)


static func path(profile: Dictionary) -> Array:
	return TREE.path(profile)


static func focus(profile: Dictionary) -> String:
	return TREE.focus(profile)


static func state(selected: Array) -> Dictionary:
	return TREE.state(selected)


static func refusal(profile: Dictionary, request: int) -> String:
	return TREE.refusal(profile,request)


static func learn(profile: Dictionary, request: int) -> String:
	return TREE.learn(profile,request)
