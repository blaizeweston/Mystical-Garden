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
	[["wide_omen","Wide Omen","Q gains 0.55 m of radius."],
	 ["long_resonance","Long Resonance","Q gains 1.25 m of placement range."],
	 ["kindled_ward","Kindled Ward","Q gives one 1.4 s Ward to the visible living recipient with the lowest health ratio in its footprint. You can qualify."]],
	[["verdicts_toll","Verdict’s Toll","Q deals 10 extra base HP to one enemy nearest its effect center, even on a normally nondamaging Q."],
	 ["anchored_ley","Anchored Ley","Root Q’s surviving victims for 0.65 s. Longer roots take priority."],
	 ["quiet_ground","Quiet Ground","Q clears ordinary Slow for living allies in its footprint and prevents their next ordinary Slow for up to 3 s."]],
	[["barbed_chime","Barbed Chime","After Q, the next Warding Chime deals a secondary 10 base HP hit to one enemy within 2.6 m and clear line."],
	 ["quick_chime","Quick Chime","After Q, the next Warding Chime recovers 1.7 s sooner, down to a 1.8 s cooldown."],
	 ["shared_shelter","Shared Shelter","After Q, the next Warding Chime grants its ordinary Ward for 2 s."]],
	[["ritual_verdict","Ritual Verdict","An ordinary weapon hit that deals damage within 3 m prepares your next Q for 4 s. That cast adds 10 base HP to one enemy nearest its effect center."],
	 ["omen_resonance","Omen Resonance","Your starting focus’s native Omen lasts 1.5 s longer."],
	 ["merciful_chime","Merciful Chime","When this Chime’s Ward blocks an enemy attack, heal the protected ally for up to 6 HP, once per recipient per cast."]],
	[["sentence_of_dawn","Sentence of Dawn","Warding Chime deals 15 base HP to enemies within 3 m and clear line. Enemies carrying your Foreboding take 10 extra base HP in the same hit."],
	 ["fates_refrain","Fate’s Refrain","After Q, the next Warding Chime bestows your focus Omen in its own area."],
	 ["mercys_chorus","Mercy’s Chorus","Warding Chime also grants a 4 s Portent of Mercy. Restore up to 8 HP after surviving your next unblocked direct enemy hit. Only the strongest conditional recovery responds per hit."]],
]
const VERSION_DATA := [Model.VERSION,Model.XP_THRESHOLDS,ROWS,OMENS,FOCUS_OMENS,VERDICT_HP,BARBED_HP,BARBED_RADIUS,
	QUICK_MS,SHELTER_MS,RITUAL_HP,RITUAL_RADIUS,RITUAL_MS,RESONANCE_MS,MERCIFUL_HP,SENTENCE_RADIUS,SENTENCE_HP,SENTENCE_CURSE_HP]

static var TREE := Model.new(CLASS_ID,"oracle","Oracle",PROFILE_KEY,ROWS)


static func omen_duration(omen: String, path: Array) -> int:
	return int(OMENS[omen].ms) + (RESONANCE_MS if path.has("omen_resonance") else 0)


static func configure_skill(skill: Dictionary, selected: Array, slot: int) -> void:
	skill.oracle_nodes = selected
	var omen: String = FOCUS_OMENS[selected[0]]
	if slot == 0:
		skill.description += "\n%s · %.1f s. %s" % [OMENS[omen].label,omen_duration(omen,selected)/1000.0,OMENS[omen].description]
	for tier in range(1,selected.size()):
		var node := TREE.node(selected[tier])
		var q_node: bool = tier <= 2 or node.id in ["ritual_verdict","omen_resonance"]
		if q_node == (slot == 0):
			skill.description += "\n" + node.name + " · " + node.description
