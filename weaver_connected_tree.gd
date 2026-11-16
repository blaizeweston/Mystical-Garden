extends RefCounted
## Affinity Weaver uses stable selections separate from legacy Weaver investments.
const Model = preload("res://connected_class_tree.gd")
const PROFILE_KEY := "weaver_connected"

const GIFT_EXTENSION_MS := 600
const BRANCHING_HP := 10
const BARBED_HP := 10
const PRESSURE_HP := 5
const CYCLE_MS := 1250
const FILAMENTS_MS := 2000
const FILAMENTS_REDUCTION := 0.12
const BURST_DELAY_MS := 450
const BURST_RADIUS := 1.6
const BURST_HP := 10
const SYMBIOTIC_MS := 8000
const SYMBIOTIC_REACH := 6.0
const SYMBIOTIC_RADIUS := 2.0
const CANOPY_RADIUS := 3.0
const CANOPY_MS := 3000
const CANOPY_WARD_MS := 2500

const SILK_GIFT := "Silk Shelter extends the Ward it grants to the ally with the lowest HP ratio in its circle by 0.6 s."
const ROWS := [
	[["thornbinder", "Thornbinder", "Learn Interwoven Bind."],
	 ["bloomcaller", "Bloomcaller", "Learn Cultivate Bloom."],
	 ["silkwarden", "Silkwarden", "Learn Silk Shelter."]],
	[["twining_reach", "Twining Reach", "Your focus Q gains 0.55 m of impact radius. Its target limit stays the same."],
	 ["patient_spore", "Patient Spore", "Your focus Q gains 1.25 m of targeting or placement range."],
	 ["silken_gift", "Silken Gift", "Your focus Q grants one 1.4 s Ward to the living ally with the lowest HP ratio in its circle."]],
	[["branching_spores", "Branching Spores", "When Q affects an enemy on release, it deals 10 base HP to one other enemy in clear line within 2.6 m of the impact."],
	 ["holding_threads", "Holding Threads", "Q roots on release last 0.65 s longer. Cultivate Bloom roots enemies in its circle on release for 0.65 s."],
	 ["clean_weave", "Clean Weave", "Casting Q removes ordinary Slow from living allies in its circle."]],
	[["barbed_nova", "Barbed Nova", "Q prepares your next Spore Nova that hits to deal 10 extra base HP to one enemy it hits."],
	 ["threaded_nova", "Threaded Nova", "Q prepares your next Spore Nova to recover 1.7 s sooner, down to a 1.8 s cooldown."],
	 ["sheltering_nova", "Sheltering Nova", "Q prepares your next Spore Nova to grant living allies within 3 m of you one 1.4 s Ward."]],
	[["spore_pressure", "Spore Pressure", "The first damage or root from each Q prepares your next Spore Nova to deal 5 extra base HP to every enemy it hits."],
	 ["spore_cycle", "Spore Cycle", "When Spore Nova hits at least one enemy, recover 1.25 s of Q cooldown once per cast."],
	 ["protective_filaments", "Protective Filaments", "Casting Q grants living allies in its circle 12% less direct attack damage for 2 s. The protection follows them. Another grant refreshes it. Only the strongest class protection applies."]],
	[["bursting_spores", "Bursting Spores", "A successful Spore Nova leaves one burst at an enemy's impact position. After 0.45 s it deals 10 base HP to each enemy within 1.6 m and clear line."],
	 ["symbiotic_nova", "Symbiotic Nova", "For 8 s after Q, the next Spore Nova also erupts within 2 m of Q's impact point if it is visible and within 6 m. Enemies can be hit once by the cast."],
	 ["silken_canopy", "Silken Canopy", "Spore Nova leaves a canopy within 3 m of you for 3 s. Each living ally inside and in clear line receives one 2.5 s Ward the first time they qualify."]],
]
const VERSION_DATA := [Model.VERSION,Model.XP_THRESHOLDS,ROWS,SILK_GIFT,GIFT_EXTENSION_MS,BRANCHING_HP,BARBED_HP,
	PRESSURE_HP,CYCLE_MS,FILAMENTS_MS,FILAMENTS_REDUCTION,BURST_DELAY_MS,BURST_RADIUS,BURST_HP,
	SYMBIOTIC_MS,SYMBIOTIC_REACH,SYMBIOTIC_RADIUS,CANOPY_RADIUS,CANOPY_MS,CANOPY_WARD_MS]

static var TREE := Model.new(1,"weaver","Weaver",PROFILE_KEY,ROWS)


static func description(node: Dictionary, focus: String) -> String:
	if node.id == "silken_gift":
		if focus == "silkwarden":
			return SILK_GIFT
		if focus.is_empty():
			return node.description + " " + SILK_GIFT
	return node.description
