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
const DEEP_ROOTS := {
	"vanguard": "Extends Thorn Counter's counter window by 1.25 s.",
	"rootkeeper": "Increases Root Anchor's reach by 1.5 m.",
	"bastion": "Increases Rootshield's radius by 0.8 m.",
}

const ROWS := [
	[["vanguard", "Vanguard", "Learn Thorn Counter."],
	 ["rootkeeper", "Rootkeeper", "Learn Root Anchor."],
	 ["bastion", "Bastion", "Learn Rootshield."]],
	[["briar_rebound", "Briar Rebound", "{focus}'s first qualifying block pushes up to two lesser enemies within 2.25 m outward by up to 0.85 m. Enemies committed to an attack resist."],
	 ["deep_roots", "Deep Roots", "Your starting focus gains 1.25 s of Thorn Counter's counter window, 1.5 m of Root Anchor reach, or 0.8 m of Rootshield radius."],
	 ["shared_guard", "Shared Guard", "{focus}'s first qualifying block grants one 0.95 s Guard to the nearest eligible ally within 3 m, or to you if nobody qualifies."]],
	[["pinning_quake", "Pinning Quake", "After a qualifying block with {focus}, you have 5.5 s to cast Root Quake and root up to two surviving lesser enemies it hits for 0.95 s."],
	 ["ready_footing", "Ready Footing", "{focus}'s first qualifying block makes your dodge ready if it is recovering."],
	 ["clear_the_way", "Clear the Way", "{focus}'s first qualifying block removes ordinary Slow from you and living allies within 3 m and in clear line."]],
	[["faultline_impact", "Faultline Impact", "After a qualifying block with {focus}, your next Root Quake within 5.5 s deals +10 damage to each enemy it hits."],
	 ["living_rhythm", "Living Rhythm", "After a qualifying block with {focus}, your next Root Quake within 5.5 s reduces {focus}'s remaining cooldown by 1.25 s if it hits an enemy."],
	 ["sheltering_quake", "Sheltering Quake", "After a qualifying block with {focus}, your next Root Quake within 5.5 s grants allies in its area one 1.25 s Guard."]],
	[["quakefront", "Quakefront", "Increases Root Quake's impact radius by 0.6 m."],
	 ["measured_guard", "Measured Guard", "If protection from {focus} expires without blocking, reduce its remaining cooldown by 1.25 s."],
	 ["holdfast", "Holdfast", "{focus}'s first actual block grants you and living allies within 3 m and clear line 15% less direct attack damage for 2.5 s. The protection follows recipients. Reapplying refreshes the duration. The strongest protection applies inside Sanctuary Ground."]],
	[["aftershock", "Aftershock", "After a qualifying block with {focus}, Root Quake cast within 5.5 s leaves an aftershock. After 0.45 s it deals 8 secondary damage to enemies within 2.25 m."],
	 ["seismic_relay", "Seismic Relay", "A qualifying block with {focus} leaves a relay for 5.5 s. Your next Root Quake uses it if the relay is within 5 m and in clear line."],
	 ["sanctuary_ground", "Sanctuary Ground", "A qualifying block with {focus} creates a sanctuary with a 3 m radius for 3.5 s. Living allies inside take 25% less direct attack damage."]],
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


static func description(node: Dictionary, focus: String, ability: String) -> String:
	var text: String = DEEP_ROOTS.get(focus, node.description) if node.id == "deep_roots" else node.description
	return Model.focus_text(text, ability)
