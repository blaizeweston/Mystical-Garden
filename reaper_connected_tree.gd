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

const VEIL_DESCRIPTION := "Move along a legal path and slash at the landing. For 2.7 s, one basic melee hit from an attack begun after the move deals +10 damage."
const LINGERING := {
	"blood_harvester": "Blood Harvest counts one additional contact toward its self-heal when it damages at least two eligible enemies.",
	"veilwalker": "Veil Passage gains 1.25 m of maximum legal travel.",
	"gravekeeper": "When Grave Sweep damages an enemy, extend the duration of its Ward by 0.5 s.",
}
const GRAVE_WARD := "Grave Sweep grants a 1.4 s Ward to the living recipient with the lowest HP ratio in its support circle and clear line. It has two charges when the sweep damages an enemy, or one otherwise."

const ROWS := [
	[["blood_harvester", "Blood Harvester", "Learn Blood Harvest."],
	 ["veilwalker", "Veilwalker", "Learn Veil Passage and Veil Momentum."],
	 ["gravekeeper", "Gravekeeper", "Learn Grave Sweep."]],
	[["long_edge", "Long Edge", "Increases {focus}'s attack radius by 0.55 m."],
	 ["lingering_veil", "Lingering Veil", "Improve the native drain, travel, or Ward of your starting focus."],
	 ["grave_ward", "Grave Ward", "After a valid cast of {focus}, grant one 1.4 s Ward to the living recipient with the lowest HP ratio in its support area and clear line."]],
	[["rending_cut", "Rending Cut", "{focus} deals +10 damage to its first directly damaged enemy."],
	 ["grave_grip", "Grave Grip", "{focus} roots surviving targets for 0.65 s. A longer existing root takes priority."],
	 ["clear_the_veil", "Clear the Veil", "{focus} removes ordinary Slow from living allies in its support area and clear line."]],
	[["barbed_siphon", "Barbed Siphon", "After {focus}, your next Siphon Cut deals +10 damage to its primary target."],
	 ["swift_siphon", "Swift Siphon", "After {focus}, your next valid Siphon Cut starts a cooldown 1.7 s shorter, with a 1.8 s minimum."],
	 ["wake_ward", "Wake Ward", "After {focus}, your next valid Siphon Cut grants living allies within 3 m of impact and in clear line one 1.4 s Ward."]],
	[["deaths_due", "Death’s Due", "Killing an eligible enemy with a direct melee attack or immediate Reaper ability earns one Death Charge. Your next eligible direct hit spends one for +10 damage. The three-charge limit is shared with Funeral Petal. Class charges spend first and last through floor changes and revival until the expedition ends."],
	 ["siphon_tempo", "Siphon Tempo", "When Siphon Cut damages a non-summoned enemy, reduce {focus}'s remaining cooldown by 1.25 s once per cast."],
	 ["grave_offering", "Grave Offering", "If {focus} damages an enemy, heal the living recipient with the lowest HP ratio within 3 m of impact and in clear line for up to 8 HP. You can qualify."]],
	[["feast_of_thorns", "Feast of Thorns", "After {focus}, your next damaging Siphon Cut deals +10 damage to its primary target and 10 secondary damage to up to two other enemies within 2.6 m of impact and in clear line."],
	 ["veil_dance", "Veil Dance", "After {focus}, your next valid Siphon Cut steps up to 1.5 m along legal ground toward its target. A damaging hit makes your dodge ready."],
	 ["last_rites", "Last Rites", "A damaging Siphon Cut also heals up to two living recipients with the lowest HP ratios within 3 m of impact and in clear line for 6 HP each. You can qualify."]],
]
const VERSION_DATA := [Model.VERSION,Model.XP_THRESHOLDS,ROWS,VEIL_DESCRIPTION,LINGERING,GRAVE_WARD,
	VEIL_MS,VEIL_HP,WARD_EXTENSION_MS,RENDING_HP,BARBED_HP,SWIFT_MS,TEMPO_MS,OFFERING_HP,SUPPORT_RADIUS,
	FEAST_HP,FEAST_RADIUS,FEAST_TARGETS,DANCE_TRAVEL,RITES_HP,RITES_RECIPIENTS]

static var TREE := Model.new(3,"reaper","Reaper",PROFILE_KEY,ROWS)


static func description(node: Dictionary, focus: String, ability: String) -> String:
	if node.id == "lingering_veil":
		return LINGERING.get(focus,node.description)
	if node.id == "grave_ward" and focus == "gravekeeper":
		return GRAVE_WARD
	return Model.focus_text(node.description, ability)
