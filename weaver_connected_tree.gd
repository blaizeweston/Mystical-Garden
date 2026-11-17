extends RefCounted
## Affinity Weaver uses stable selections separate from legacy Weaver investments.
const Model = preload("res://connected_class_tree.gd")
const PROFILE_KEY := "weaver_connected"

const GIFT_EXTENSION_MS := 600
const BRANCHING_HP := 10
const BARBED_HP := 10
const PRESSURE_HP := 5
const THREAD_REFUND_MS := 1700
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

const SILK_GIFT := "Extends the duration of Silk Shelter's Ward by 0.6 s for the ally with the lowest HP ratio in its area."
const ROWS := [
	[["thornbinder", "Thornbinder", "Learn Interwoven Bind."],
	 ["bloomcaller", "Bloomcaller", "Learn Cultivate Bloom."],
	 ["silkwarden", "Silkwarden", "Learn Silk Shelter."]],
	[["twining_reach", "Twining Reach", "Increases {focus}'s impact radius by 0.55 m. Its target limit stays the same."],
	 ["patient_spore", "Patient Spore", "Increases {focus}'s targeting or placement range by 1.25 m."],
	 ["silken_gift", "Silken Gift", "{focus} grants one 1.4 s Ward to the living ally with the lowest HP ratio in its area."]],
	[["branching_spores", "Branching Spores", "When {focus} affects an enemy on release, it deals 10 secondary damage to one other enemy within 2.6 m of the impact and in clear line."],
	 ["holding_threads", "Holding Threads", "Extends {focus}'s opening roots by 0.65 s. Cultivate Bloom instead roots enemies in its area for 0.65 s when placed."],
	 ["clean_weave", "Clean Weave", "{focus} removes ordinary Slow from living allies in its area."]],
	[["barbed_nova", "Barbed Nova", "{focus} prepares your next Spore Nova to deal +10 damage to one enemy it hits."],
	 ["threaded_nova", "Threaded Nova", "Activating {focus} reduces Spore Nova's remaining cooldown by 1.7 seconds."],
	 ["sheltering_nova", "Sheltering Nova", "{focus} prepares your next Spore Nova to grant living allies within 3 m of you one 1.4 s Ward."]],
	[["spore_pressure", "Spore Pressure", "The first damage or root from {focus} prepares your next Spore Nova to deal +5 damage to every enemy it hits."],
	 ["spore_cycle", "Spore Cycle", "When Spore Nova hits an enemy, reduce {focus}'s remaining cooldown by 1.25 s once per cast."],
	 ["protective_filaments", "Protective Filaments", "{focus} protects living allies in its area for 2 s. Recipients take 12% less direct attack damage, even after moving away. Reapplying refreshes the duration. The strongest class protection applies."]],
	[["bursting_spores", "Bursting Spores", "If Spore Nova hits an enemy, it leaves one burst at an impact point. After 0.45 s, it deals 10 secondary damage to each enemy within 1.6 m and in clear line."],
	 ["symbiotic_nova", "Symbiotic Nova", "For 8 s after {focus}, your next Spore Nova also erupts within 2 m of that cast's impact point, if it is within 6 m and in clear line. Each enemy can be hit once per cast."],
	 ["silken_canopy", "Silken Canopy", "Spore Nova leaves a 3 m canopy for 3 s. Each living ally inside and in clear line receives one 2.5 s Ward the first time they qualify."]],
]
const VERSION_DATA := [Model.VERSION,Model.XP_THRESHOLDS,ROWS,SILK_GIFT,GIFT_EXTENSION_MS,BRANCHING_HP,BARBED_HP,
	PRESSURE_HP,THREAD_REFUND_MS,CYCLE_MS,FILAMENTS_MS,FILAMENTS_REDUCTION,BURST_DELAY_MS,BURST_RADIUS,BURST_HP,
	SYMBIOTIC_MS,SYMBIOTIC_REACH,SYMBIOTIC_RADIUS,CANOPY_RADIUS,CANOPY_MS,CANOPY_WARD_MS]

static var TREE := Model.new(1,"weaver","Weaver",PROFILE_KEY,ROWS)


static func description(node: Dictionary, focus: String, ability: String) -> String:
	var text := Model.focus_text(node.description, ability)
	if node.id == "silken_gift":
		if focus == "silkwarden":
			return SILK_GIFT
		if focus.is_empty():
			return text + " " + SILK_GIFT
	elif node.id == "holding_threads" and not focus.is_empty():
		if focus == "bloomcaller":
			return "Cultivate Bloom roots enemies in its area for 0.65 s when placed."
		return "Extends the duration of %s's opening roots by 0.65 s." % ability
	return text
