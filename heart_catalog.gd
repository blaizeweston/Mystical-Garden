extends RefCounted
# Stable world-owned technology IDs. insight is the spendable Knowledge price.
const DEFINITIONS := [

	{
		"id": "heart",
		"name": "Sheltered Heart",
		"parents": [],
		"insight": 0,
		"position": [
			370,
			1020
		],
		"description": "An ancient ally shelters a fragment of its former self. Discoveries and first crafts restore Knowledge."
	},
	{
		"id": "cultivation_grounds",
		"name": "Cultivation Grounds",
		"parents": ["heart"],
		"insight": 4,
		"position": [80, 900],
		"description": "Receive one cultivation bed in Build. Construct additional beds for 12 Growth Energy each."
	},
	{
		"id": "clearing_1",
		"name": "Reaching Roots",
		"parents": [
			"heart"
		],
		"insight": 3,
		"position": [
			225,
			900
		],
		"description": "Unlock repeatable Garden expansion. Choose a frontier in Build and pay with growth energy from offerings.",
		"clearing": 1
	},
	{
		"id": "clearing_2",
		"name": "Verdant Refuge",
		"parents": [
			"clearing_1"
		],
		"insight": 5,
		"position": [
			225,
			650
		],
		"description": "Open the cultivation terrace. Future Build expansions cost 10% less growth energy than at Reaching Roots.",
		"clearing": 2
	},
	{
		"id": "clearing_3",
		"name": "Living Sanctuary",
		"parents": [
			"clearing_2"
		],
		"insight": 8,
		"position": [
			225,
			400
		],
		"description": "Future Build expansions cost 20% less growth energy than at Reaching Roots.",
		"clearing": 3
	},
	{
		"id": "irrigation",
		"name": "Living Sprinklers",
		"parents": [
			"clearing_1"
		],
		"insight": 4,
		"position": [
			370,
			775
		],
		"description": "Grants a Water Intake and a Living Sprinkler. Place the intake on a natural bank to supply sprinklers. Additional sprinklers can be constructed in Build."
	},
	{
		"id": "nursery",
		"name": "Symbiotic Nursery",
		"parents": [
			"irrigation"
		],
		"insight": 6,
		"position": [
			370,
			650
		],
		"description": "Receive a Symbiotic Nursery. Each harvest in its coverage grants two familiarity to the harvester."
	},
	{
		"id": "seed_archive",
		"name": "Reclamation Altar",
		"parents": [
			"heart"
		],
		"insight": 5,
		"position": [
			515,
			900
		],
		"description": "Build a Reclamation Altar. Trade matching plant parts for seeds of discovered species. Rarer seeds cost more."
	},
	{
		"id": "monster_studies",
		"name": "Offering Altar",
		"parents": [
			"heart"
		],
		"insight": 4,
		"position": [
			660,
			900
		],
		"description": "Build an Offering Altar. Offer a trophy for 4 Knowledge the first time its type is offered, then 1 for repeat offerings."
	},
	{
		"id": "spore_bench",
		"name": "Trophy Preservation",
		"parents": [
			"monster_studies",
			"clearing_2"
		],
		"insight": 5,
		"position": [
			660,
			650
		],
		"description": "Carry up to 8 monster parts into the Wilds, up from 6."
	},
	{
		"id": "checkpoint_deposit",
		"name": "Returning Mycelium",
		"parents": [
			"seed_archive",
			"monster_studies"
		],
		"insight": 8,
		"position": [
			515,
			650
		],
		"description": "Each player can send one seed or material home at every cleared third gate."
	},
	{
		"id": "living_archive",
		"name": "Living Archive",
		"parents": [
			"seed_archive",
			"monster_studies"
		],
		"insight": 8,
		"position": [
			515,
			400
		],
		"description": "Grow a living archive in the Garden. It decodes the memories carried home from repeated guardian expeditions."
	},
	{
		"id": "memory_grove",
		"name": "Grove Remembrance",
		"parents": [
			"living_archive"
		],
		"insight": 0,
		"position": [
			280,
			235
		],
		"description": "Restore this memory by returning from guardian expeditions in this Garden.",
		"memory": 0
	},
	{
		"id": "memory_mire",
		"name": "Mire Remembrance",
		"parents": [
			"living_archive"
		],
		"insight": 0,
		"position": [
			430,
			235
		],
		"description": "Restore this memory by returning from guardian expeditions in this Garden.",
		"memory": 1
	},
	{
		"id": "memory_hollow",
		"name": "Hollow Remembrance",
		"parents": [
			"living_archive"
		],
		"insight": 0,
		"position": [
			580,
			235
		],
		"description": "Restore this memory by returning from guardian expeditions in this Garden.",
		"memory": 2
	},
	{"id": "seed_conservation", "name": "Seed Conservation", "parents": ["heart"], "insight": 6, "position": [480, 1020], "description": "On a failed two-seed offering, retain the parent whose material was not salvaged."},
	{"id": "sprinkler_effectiveness", "name": "Living Sprinkler Effectiveness", "parents": ["irrigation"], "insight": 16, "position": [880, 500], "description": "Watering improves to 1.40x, including manual care."},
	{"id": "sprinkler_coverage", "name": "Living Sprinkler Coverage", "parents": ["irrigation"], "insight": 12, "position": [880, 365], "description": "Extend the coverage radius of every Living Sprinkler to 5 metres."},
	{"id": "pollination_bloom", "name": "Pollination Bloom", "parents": ["heart"], "insight": 8, "position": [1045, 900], "description": "Receive a Pollination Bloom. Harvest three seeds from a mature covered bed."},
	{"id": "pollination_bloom_effectiveness", "name": "Pollination Bloom Effectiveness", "parents": ["pollination_bloom"], "insight": 16, "position": [1045, 500], "description": "Receive four seeds per seed harvest."},
	{"id": "pollination_bloom_coverage", "name": "Pollination Bloom Coverage", "parents": ["pollination_bloom"], "insight": 12, "position": [1045, 365], "description": "Extend the coverage radius of every Pollination Bloom to 4.5 metres."},
	{"id": "nursery_effectiveness", "name": "Symbiotic Nursery Effectiveness", "parents": ["nursery"], "insight": 16, "position": [1210, 500], "description": "Gain three familiarity per harvest."},
	{"id": "nursery_coverage", "name": "Symbiotic Nursery Coverage", "parents": ["nursery"], "insight": 12, "position": [1210, 365], "description": "Extend the coverage radius of every Symbiotic Nursery to 4.5 metres."},
	{"id": "refinement_grove", "name": "Refinement Grove", "parents": ["heart"], "insight": 12, "position": [1375, 900], "description": "Receive a Refinement Grove. Covered material harvests gain 15 percentage points of refined chance."},
	{"id": "refinement_grove_effectiveness", "name": "Refinement Grove Effectiveness", "parents": ["refinement_grove"], "insight": 16, "position": [1375, 500], "description": "Add 25 percentage points to the material harvest refinement chance."},
	{"id": "refinement_grove_coverage", "name": "Refinement Grove Coverage", "parents": ["refinement_grove"], "insight": 12, "position": [1375, 365], "description": "Extend the coverage radius of every Refinement Grove to 4 metres."},
	{"id": "vital_roots", "name": "Vital Roots", "parents": ["heart"], "insight": 8, "position": [1540, 900], "description": "Receive Vital Roots. Covered crops grow at 1.30x speed."},
	{"id": "vital_roots_effectiveness", "name": "Vital Roots Effectiveness", "parents": ["vital_roots"], "insight": 16, "position": [1540, 500], "description": "Covered crops grow at 1.50x speed before watering and expedition bonuses."},
	{"id": "vital_roots_coverage", "name": "Vital Roots Coverage", "parents": ["vital_roots"], "insight": 12, "position": [1540, 365], "description": "Extend the coverage radius of every Vital Roots to 6 metres."},
	{"id": "bud_sanctuary", "name": "Bud Sanctuary", "parents": ["clearing_2", "irrigation"], "insight": 6, "position": [1705, 900], "description": "Receive a Bud Sanctuary. Configure it in Build to preserve eligible buds automatically."},
	{"id": "bud_sanctuary_effectiveness", "name": "Bud Sanctuary Effectiveness", "parents": ["bud_sanctuary"], "insight": 16, "position": [1705, 500], "description": "Unlock enhanced manual and automatic bud care: 40% extra work and 25 percentage points of refined chance."},
	{"id": "bud_sanctuary_coverage", "name": "Bud Sanctuary Coverage", "parents": ["bud_sanctuary"], "insight": 12, "position": [1705, 365], "description": "Extend the coverage radius of every Bud Sanctuary to 4.5 metres."}
]
static var _by_id: Dictionary = {}

static func _static_init() -> void:
	for node in DEFINITIONS: _by_id[node.id]=node

static func get_node(id: String) -> Dictionary:
	return _by_id.get(id,{})
static func required_core() -> Array:
	return ["irrigation","nursery","seed_archive","monster_studies","spore_bench","checkpoint_deposit","living_archive","clearing_1","clearing_2","clearing_3"]
static func phase_name(phase: int) -> String:
	return ["Sheltered Fragment","First Awakening","Rooted Heart","Living Nexus","Remembering Heart"][clampi(phase,0,4)]

static func enabled(id: String) -> bool:
	return _by_id.has(id)
