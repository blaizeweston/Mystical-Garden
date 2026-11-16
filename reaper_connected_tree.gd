extends RefCounted
## Versioned affinity progression with independent historical Reaper masks.
const Model = preload("res://connected_class_tree.gd")
const PROFILE_KEY := "reaper_connected"

const VEIL_MS := 2700
const VEIL_HP := 10
const WARD_EXTENSION_MS := 500
const RENDING_HP := 10
const BARBED_HP := 10
const SWIFT_MS := 1700
const TEMPO_MS := 1250
const OFFERING_HP := 8
const SUPPORT_RADIUS := 3.0
const FEAST_HP := 10
const FEAST_RADIUS := 2.6
const FEAST_TARGETS := 2
const DANCE_TRAVEL := 1.5
const RITES_HP := 6
const RITES_RECIPIENTS := 2

const VEIL_DESCRIPTION := "Move along a legal path and slash at the landing. For 2.7 s, one ordinary melee hit from an attack begun after the move gains 10 base HP."
const LINGERING := {
	"blood_harvester": "Blood Harvest counts one additional contact toward its self-heal when it damages at least two eligible enemies.",
	"veilwalker": "Veil Passage gains 1.25 m of maximum legal travel.",
	"gravekeeper": "When Grave Sweep damages an enemy, its Ward lasts 0.5 s longer.",
}
const GRAVE_WARD := "Grave Sweep grants a 1.4 s Ward to the living recipient with the lowest HP ratio in its support circle and clear line. It has two charges when the sweep damages an enemy, or one otherwise."

const ROWS := [
	[["blood_harvester", "Blood Harvester", "Learn Blood Harvest."],
	 ["veilwalker", "Veilwalker", "Learn Veil Passage and Veil Momentum."],
	 ["gravekeeper", "Gravekeeper", "Learn Grave Sweep."]],
	[["long_edge", "Long Edge", "Q gains 0.55 m of native area radius."],
	 ["lingering_veil", "Lingering Veil", "Improve the native drain, travel, or Ward of your starting focus."],
	 ["grave_ward", "Grave Ward", "After a valid Q, grant one 1.4 s Ward to the living recipient with the lowest HP ratio in its support circle and clear line."]],
	[["rending_cut", "Rending Cut", "Q deals 10 extra base HP to its first directly damaged enemy."],
	 ["grave_grip", "Grave Grip", "Root Q’s surviving victims for 0.65 s. Longer roots take priority."],
	 ["clear_the_veil", "Clear the Veil", "Q clears ordinary Slow from living allies in its support circle and clear line."]],
	[["barbed_siphon", "Barbed Siphon", "After Q, your next Siphon Cut that damages an enemy deals 10 extra base HP to its primary victim."],
	 ["swift_siphon", "Swift Siphon", "After Q, your next valid Siphon Cut recovers 1.7 s sooner, down to a 1.8 s cooldown."],
	 ["wake_ward", "Wake Ward", "After Q, your next valid Siphon Cut grants living allies within 3 m of impact and in clear line one 1.4 s Ward."]],
	[["deaths_due", "Death’s Due", "A direct melee or class kill of an eligible enemy earns one Death Charge. The next direct native hit spends one for 10 base HP. You share a cap of three with Funeral Petal. Class charges spend first and survive floor changes and revival until the expedition ends."],
	 ["siphon_tempo", "Siphon Tempo", "When Siphon Cut damages an eligible nonsummoned enemy, recover 1.25 s of Q cooldown once per cast."],
	 ["grave_offering", "Grave Offering", "A damaging Q heals the living recipient with the lowest HP ratio within 3 m of its effect and in clear line for 8 HP. You can qualify."]],
	[["feast_of_thorns", "Feast of Thorns", "After Q, your next damaging Siphon Cut adds 10 base HP to its primary hit and deals 10 base HP to up to two other enemies within 2.6 m of impact and in clear line."],
	 ["veil_dance", "Veil Dance", "After Q, your next valid Siphon Cut steps up to 1.5 m along legal ground toward its target and readies dodge if the hit deals damage."],
	 ["last_rites", "Last Rites", "A damaging Siphon Cut also heals up to two living recipients with the lowest HP ratios within 3 m of impact and in clear line for 6 HP each. You can qualify."]],
]
const VERSION_DATA := [Model.VERSION,Model.XP_THRESHOLDS,ROWS,VEIL_DESCRIPTION,LINGERING,GRAVE_WARD,
	VEIL_MS,VEIL_HP,WARD_EXTENSION_MS,RENDING_HP,BARBED_HP,SWIFT_MS,TEMPO_MS,OFFERING_HP,SUPPORT_RADIUS,
	FEAST_HP,FEAST_RADIUS,FEAST_TARGETS,DANCE_TRAVEL,RITES_HP,RITES_RECIPIENTS]

static var TREE := Model.new(3,"reaper","Reaper",PROFILE_KEY,ROWS)


static func description(node: Dictionary, focus: String) -> String:
	if node.id == "lingering_veil":
		return LINGERING.get(focus,node.description)
	if node.id == "grave_ward" and focus == "gravekeeper":
		return GRAVE_WARD
	return node.description
