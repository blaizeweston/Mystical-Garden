extends RefCounted
## Oracle's affinity path owns its own profile data. Historical masks keep their meanings.
const Model = preload("res://connected_class_tree.gd")
const PROFILE_KEY := "oracle_connected"
const CLASS_ID := 4

const VERDICT_HP := 10
const BARBED_HP := 10
const BARBED_RADIUS := 2.6
const QUICK_MS := 1700
const SHELTER_MS := 2000
const RITUAL_HP := 10
const RITUAL_RADIUS := 3.0
const RITUAL_MS := 4000
const RESONANCE_MS := 1500
const MERCIFUL_HP := 6
const SENTENCE_RADIUS := 3.0
const SENTENCE_HP := 15
const SENTENCE_CURSE_HP := 10

const FOREBODING := "oracle_foreboding"
const GUIDED_STRIKE := "oracle_guided_strike"
const SECOND_BREATH := "oracle_second_breath"
const QUIET_GROUND := "oracle_quiet_ground"
const MERCY := "oracle_mercy"
const FOCUS_OMENS := {"omenreader": FOREBODING, "leykeeper": GUIDED_STRIKE, "lifekeeper": SECOND_BREATH}
const OMENS := {
	FOREBODING: {"label":"Foreboding","type":"Curse","trigger":"attack_start","ms":3000,"value":350,"description":"Surviving enemies in the circle gain Foreboding. Their next committed attack begins with 0.35 s of extra recovery after it ends."},
	GUIDED_STRIKE: {"label":"Guided Strike","type":"Portent","trigger":"ordinary_contact","ms":4000,"value":300,"description":"Eligible living allies gain Guided Strike. Their next ordinary weapon hit that damages a surviving enemy extends its attack recovery by 0.3 s, once per enemy recovery."},
	SECOND_BREATH: {"label":"Second Breath","type":"Blessing","trigger":"direct_damage","ms":3000,"value":6,"description":"Opening-heal recipients gain Second Breath. After surviving their next unblocked direct enemy hit, restore up to 6 HP."},
	QUIET_GROUND: {"label":"Quiet Ground","type":"Blessing","trigger":"ordinary_slow","ms":3000,"value":1,"description":"Prevents one new or extended ordinary Slow."},
	MERCY: {"label":"Portent of Mercy","type":"Portent","trigger":"direct_damage","ms":4000,"value":8,"description":"After surviving an unblocked direct enemy hit, restore up to 8 HP. The strongest conditional heal applies to each hit."},
}

const ROWS := [
	[["omenreader","Omenreader","Learn Foretell and the Foreboding Curse."],
	 ["leykeeper","Leykeeper","Learn Guiding Bell and the Guided Strike Portent."],
	 ["lifekeeper","Lifekeeper","Learn Living Sanctuary and the Second Breath Blessing."]],
	[["wide_omen","Wide Omen","Increases {focus}'s radius by 0.55 m."],
	 ["long_resonance","Long Resonance","Increases {focus}'s placement range by 1.25 m."],
	 ["kindled_ward","Kindled Ward","{focus} grants one 1.4 s Ward to the visible living recipient with the lowest HP ratio in its area. You can qualify."]],
	[["verdicts_toll","Verdict’s Toll","{focus} deals +10 damage to the enemy nearest its effect center within its area. This also works with otherwise nondamaging abilities."],
	 ["anchored_ley","Anchored Ley","{focus} roots surviving enemies it affects for 0.65 s. A longer existing root takes priority."],
	 ["quiet_ground","Quiet Ground","{focus} removes ordinary Slow from living allies in its area and protects them against their next ordinary Slow for up to 3 s."]],
	[["barbed_chime","Barbed Chime","After {focus}, your next Warding Chime deals 10 secondary damage to one enemy within 2.6 m and in clear line."],
	 ["quick_chime","Quick Chime","After {focus}, your next valid Warding Chime starts a cooldown 1.7 s shorter, with a 1.8 s minimum."],
	 ["shared_shelter","Shared Shelter","After {focus}, your next Warding Chime grants its Ward for 2 s instead of 1.5 s."]],
	[["ritual_verdict","Ritual Verdict","A damaging basic attack hit within 3 m prepares {focus} for 4 s. The next cast deals +10 damage to the enemy nearest its effect center within its area."],
	 ["omen_resonance","Omen Resonance","Extends the duration of {focus}'s Omen by 1.5 s."],
	 ["merciful_chime","Merciful Chime","When a Warding Chime Ward blocks an enemy attack, heal the protected ally for up to 6 HP, once per recipient per cast."]],
	[["sentence_of_dawn","Sentence of Dawn","Warding Chime deals 15 damage to enemies within 3 m and in clear line. Enemies carrying your Foreboding take +10 damage on that same hit."],
	 ["fates_refrain","Fate’s Refrain","After {focus}, your next Warding Chime also bestows {focus}'s Omen in its own area."],
	 ["mercys_chorus","Mercy’s Chorus","Warding Chime also grants a 4 s Portent of Mercy. Restore up to 8 HP after surviving your next unblocked direct enemy hit. Only the strongest conditional recovery responds per hit."]],
]
const VERSION_DATA := [Model.VERSION,Model.XP_THRESHOLDS,ROWS,OMENS,FOCUS_OMENS,VERDICT_HP,BARBED_HP,BARBED_RADIUS,
	QUICK_MS,SHELTER_MS,RITUAL_HP,RITUAL_RADIUS,RITUAL_MS,RESONANCE_MS,MERCIFUL_HP,SENTENCE_RADIUS,SENTENCE_HP,SENTENCE_CURSE_HP]

static var TREE := Model.new(CLASS_ID,"oracle","Oracle",PROFILE_KEY,ROWS)


static func omen_duration(omen: String, path: Array) -> int:
	return int(OMENS[omen].ms) + (RESONANCE_MS if path.has("omen_resonance") else 0)


static func configure_skill(skill: Dictionary, selected: Array, slot: int, ability: String) -> void:
	skill.oracle_nodes = selected
	var omen: String = FOCUS_OMENS[selected[0]]
	if slot == 0:
		skill.description += "\n%s · %.1f s. %s" % [OMENS[omen].label,omen_duration(omen,selected)/1000.0,OMENS[omen].description]
	for tier in range(1,selected.size()):
		var node := TREE.node(selected[tier])
		var q_node: bool = tier <= 2 or node.id in ["ritual_verdict","omen_resonance"]
		if q_node == (slot == 0):
			skill.description += "\n" + node.name + " · " + Model.focus_text(node.description, ability)
