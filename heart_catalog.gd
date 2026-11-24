extends RefCounted
# Stable world-owned technology IDs. Materials are shared plant parts; Knowledge is lifetime XP.
const DEFINITIONS := [

	{
		"id": "heart",
		"name": "Sheltered Heart",
		"parents": [],
		"knowledge": 0,
		"insight": 0,
		"materials": 0,
		"research": 0,
		"position": [
			370,
			1020
		],
		"description": "An ancient ally shelters a fragment of its former self. Discoveries and first crafts restore Knowledge."
	},
	{
		"id": "plot_4",
		"name": "Garden Bed 4",
		"parents": [
			"heart"
		],
		"knowledge": 4,
		"insight": 2,
		"materials": 4,
		"research": 0,
		"position": [
			80,
			900
		],
		"description": "Unlock a total of 4 planting beds. Place the additional bed through Build.",
		"plots": 4
	},
	{
		"id": "plot_5",
		"name": "Garden Bed 5",
		"parents": [
			"plot_4"
		],
		"knowledge": 16,
		"insight": 3,
		"materials": 6,
		"research": 0,
		"position": [
			80,
			775
		],
		"description": "Unlock a total of 5 planting beds. Place the additional bed through Build.",
		"plots": 5
	},
	{
		"id": "plot_6",
		"name": "Garden Bed 6",
		"parents": [
			"plot_5"
		],
		"knowledge": 28,
		"insight": 4,
		"materials": 8,
		"research": 0,
		"position": [
			80,
			650
		],
		"description": "Unlock a total of 6 planting beds. Place the additional bed through Build.",
		"plots": 6
	},
	{
		"id": "plot_7",
		"name": "Garden Bed 7",
		"parents": [
			"plot_6"
		],
		"knowledge": 40,
		"insight": 5,
		"materials": 10,
		"research": 0,
		"position": [
			80,
			525
		],
		"description": "Unlock a total of 7 planting beds. Place the additional bed through Build.",
		"plots": 7
	},
	{
		"id": "plot_8",
		"name": "Garden Bed 8",
		"parents": [
			"plot_7"
		],
		"knowledge": 52,
		"insight": 6,
		"materials": 12,
		"research": 0,
		"position": [
			80,
			400
		],
		"description": "Unlock a total of 8 planting beds. Place the additional bed through Build.",
		"plots": 8
	},
	{
		"id": "plot_9",
		"name": "Garden Bed 9",
		"parents": [
			"plot_8"
		],
		"knowledge": 64,
		"insight": 7,
		"materials": 14,
		"research": 0,
		"position": [
			80,
			275
		],
		"description": "Unlock a total of 9 planting beds. Place the additional bed through Build.",
		"plots": 9
	},
	{
		"id": "clearing_1",
		"name": "Reaching Roots",
		"parents": [
			"heart"
		],
		"knowledge": 8,
		"insight": 3,
		"materials": 3,
		"research": 0,
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
		"knowledge": 28,
		"insight": 5,
		"materials": 8,
		"research": 0,
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
		"knowledge": 60,
		"insight": 8,
		"materials": 14,
		"research": 0,
		"position": [
			225,
			400
		],
		"description": "Future Build expansions cost 20% less growth energy than at Reaching Roots.",
		"clearing": 3
	},
	{
		"id": "flowering",
		"name": "Flowering",
		"parents": [
			"heart"
		],
		"knowledge": 0,
		"insight": 0,
		"materials": 0,
		"research": 3,
		"position": [
			370,
			900
		],
		"description": "Harvest two seeds from a mature plant instead of parts. Empties the bed."
	},
	{
		"id": "irrigation",
		"name": "Root Irrigation",
		"parents": [
			"flowering",
			"clearing_1"
		],
		"knowledge": 16,
		"insight": 4,
		"materials": 5,
		"research": 5,
		"position": [
			370,
			775
		],
		"description": "Plants grow 20% faster. Fill your watering vessel at Garden water features; no basin construction is required."
	},
	{
		"id": "nursery",
		"name": "Symbiotic Nursery",
		"parents": [
			"irrigation"
		],
		"knowledge": 38,
		"insight": 6,
		"materials": 10,
		"research": 8,
		"position": [
			370,
			650
		],
		"description": "Crops grow at 140% of their original speed. Harvesting grants 1 extra familiarity."
	},
	{
		"id": "seed_archive",
		"name": "Reclamation Altar",
		"parents": [
			"flowering"
		],
		"knowledge": 24,
		"insight": 5,
		"materials": 8,
		"research": 6,
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
		"knowledge": 12,
		"insight": 4,
		"materials": 4,
		"research": 4,
		"position": [
			660,
			900
		],
		"description": "Build an Offering Altar. Offer a trophy for 4 Knowledge the first time its type is offered, then 1 for repeat offerings."
	},
	{
		"id": "infusion",
		"name": "Research Infusion",
		"parents": [
			"flowering",
			"monster_studies"
		],
		"knowledge": 20,
		"insight": 5,
		"materials": 6,
		"research": 6,
		"position": [
			660,
			775
		],
		"description": "Plant offerings speed research by two minutes instead of one."
	},
	{
		"id": "spore_bench",
		"name": "Trophy Preservation",
		"parents": [
			"monster_studies",
			"clearing_2"
		],
		"knowledge": 40,
		"insight": 5,
		"materials": 8,
		"research": 6,
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
		"knowledge": 45,
		"insight": 8,
		"materials": 10,
		"research": 10,
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
			"infusion",
			"seed_archive",
			"monster_studies"
		],
		"knowledge": 60,
		"insight": 8,
		"materials": 12,
		"research": 12,
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
		"knowledge": 0,
		"insight": 0,
		"materials": 0,
		"research": 0,
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
		"knowledge": 0,
		"insight": 0,
		"materials": 0,
		"research": 0,
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
		"knowledge": 0,
		"insight": 0,
		"materials": 0,
		"research": 0,
		"position": [
			580,
			235
		],
		"description": "Restore this memory by returning from guardian expeditions in this Garden.",
		"memory": 2
	},
 {"id":"living_conduit","name":"Living Water Conduit","parents":["clearing_2","irrigation","plot_4"],
 "knowledge":40,"insight":6,"materials":0,"research":6,"position":[805,650],
 "description":"Unlock the terrace conduit. The host chooses the bud type for new plantings in Bed 4. Preserving a deep bud takes longer and improves rare harvest chances."}
]
static var _by_id: Dictionary = {}

static func _static_init() -> void:
	for node in DEFINITIONS: _by_id[node.id]=node

static func get_node(id: String) -> Dictionary:
	return _by_id.get(id,{})
static func required_core() -> Array:
	return ["flowering","irrigation","nursery","seed_archive","monster_studies","infusion","spore_bench","checkpoint_deposit","living_archive","clearing_1","clearing_2","clearing_3"]
static func phase_name(phase: int) -> String:
	return ["Sheltered Fragment","First Awakening","Rooted Heart","Living Nexus","Remembering Heart"][clampi(phase,0,4)]

static func enabled(id: String) -> bool:
	return _by_id.has(id)
