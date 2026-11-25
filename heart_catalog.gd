extends RefCounted
## Catalog order groups each structure with its independently purchasable upgrades.
const BRANCHES := ["Garden Development", "Cultivation", "Wilds Exploration"]
static var DEFINITIONS: Array = []
static var _by_id: Dictionary = {}

static func _static_init() -> void:
	DEFINITIONS.append({"id": "heart", "name": "Sheltered Heart", "parents": [], "insight": 0, "description": "An ancient ally shelters a fragment of its former self. Discoveries and first crafts restore Knowledge."})
	var branches := [garden_development(), cultivation(), wilds_exploration()]
	for i in branches.size():
		for node: Dictionary in branches[i]:
			node.branch = BRANCHES[i]
			DEFINITIONS.append(node)
	for node in DEFINITIONS: _by_id[node.id] = node

static func garden_development() -> Array:
	return [
		{"id": "clearing_1", "name": "Reaching Roots", "parents": ["heart"], "insight": 3, "description": "Unlock repeatable Garden expansion. Choose a frontier in Build and pay with growth energy from offerings.", "clearing": 1},
		{"id": "cultivation_grounds", "name": "Cultivation Grounds", "parents": ["heart"], "insight": 4, "description": "Receive one cultivation bed in Build. Construct additional beds for 12 Growth Energy each."},
	]

static func cultivation() -> Array:
	return [
		{"id": "irrigation", "name": "Living Sprinklers", "parents": ["clearing_1"], "insight": 4, "description": "Grants one Water Intake and one Living Sprinkler. A shoreline intake supplies every placed sprinkler. Covered beds within 3.5 m receive 1.25× watering."},
		{"id": "sprinkler_effectiveness", "name": "Sprinkler Effectiveness", "parents": ["irrigation"], "insight": 30, "description": "Watering improves from 1.25× to 1.40×, including manual care."},
		{"id": "sprinkler_coverage", "name": "Sprinkler Coverage", "parents": ["irrigation"], "insight": 20, "description": "Extend the coverage radius of every Living Sprinkler from 3.5 to 5 metres."},
		{"id": "pollination_bloom", "name": "Pollination Bloom", "parents": ["cultivation_grounds"], "insight": 10, "description": "Grants one Pollination Bloom. Seed harvests within 3 m yield 3 seeds instead of 2."},
		{"id": "pollination_bloom_effectiveness", "name": "Pollination Effectiveness", "parents": ["pollination_bloom"], "insight": 42, "description": "Increase the yield from three to four seeds per seed harvest."},
		{"id": "pollination_bloom_coverage", "name": "Pollination Coverage", "parents": ["pollination_bloom"], "insight": 24, "description": "Extend the coverage radius of every Pollination Bloom from 3 to 4.5 metres."},
		{"id": "nursery", "name": "Symbiotic Nursery", "parents": ["cultivation_grounds"], "insight": 8, "description": "Grants one Symbiotic Nursery. Harvests within 3 m give the harvester 2 familiarity instead of 1."},
		{"id": "nursery_effectiveness", "name": "Nursery Effectiveness", "parents": ["nursery"], "insight": 24, "description": "Increase familiarity from two to three per harvest."},
		{"id": "nursery_coverage", "name": "Nursery Coverage", "parents": ["nursery"], "insight": 16, "description": "Extend the coverage radius of every Symbiotic Nursery from 3 to 4.5 metres."},
		{"id": "refinement_grove", "name": "Refinement Grove", "parents": ["nursery"], "insight": 20, "description": "Grants one Refinement Grove. Material harvests within 2.5 m gain 15 percentage points of refined chance."},
		{"id": "refinement_grove_effectiveness", "name": "Refinement Effectiveness", "parents": ["refinement_grove"], "insight": 38, "description": "Improve the refined-part bonus from 15 to 25 percentage points."},
		{"id": "refinement_grove_coverage", "name": "Refinement Coverage", "parents": ["refinement_grove"], "insight": 22, "description": "Extend the coverage radius of every Refinement Grove from 2.5 to 4 metres."},
		{"id": "vital_roots", "name": "Vital Roots", "parents": ["cultivation_grounds"], "insight": 16, "description": "Grants one Vital Roots structure. Crops within 4 m grow at 1.30× speed."},
		{"id": "vital_roots_effectiveness", "name": "Vital Roots Effectiveness", "parents": ["vital_roots"], "insight": 44, "description": "Covered crop growth increases from 1.30× to 1.50× before watering and expedition bonuses."},
		{"id": "vital_roots_coverage", "name": "Vital Roots Coverage", "parents": ["vital_roots"], "insight": 28, "description": "Extend the coverage radius of Vital Roots from 4 to 6 metres."},
		{"id": "bud_sanctuary", "name": "Bud Sanctuary", "parents": ["nursery"], "insight": 12, "description": "Grants one Bud Sanctuary. Within 3 m it can preserve stage-two buds. Standard care adds 20% growth work and 15 points of refined chance. Automatic care starts disabled."},
		{"id": "bud_sanctuary_effectiveness", "name": "Bud Sanctuary Effectiveness", "parents": ["bud_sanctuary"], "insight": 28, "description": "Unlocks enhanced manual and automatic care: +40% growth work and +25 points of refined chance instead of +20% and +15 points."},
		{"id": "bud_sanctuary_coverage", "name": "Bud Sanctuary Coverage", "parents": ["bud_sanctuary"], "insight": 18, "description": "Extend the coverage radius of every Bud Sanctuary from 3 to 4.5 metres."},
		{"id": "seed_conservation", "name": "Seed Conservation", "parents": ["heart"], "insight": 10, "description": "On a failed two-seed offering, retain the parent whose material was not salvaged."},
		{"id": "seed_archive", "name": "Reclamation Altar", "parents": ["heart"], "insight": 6, "description": "Grants the unique Seed Cache. Reclaim a discovered seed for 3–7 matching ordinary parts, according to species tier."},
	]

static func wilds_exploration() -> Array:
	return [
		{"id": "careful_gathering", "name": "Careful Gathering", "parents": ["heart"], "insight": 8, "description": "Natural specimens have a 25% chance to yield a second seed of the same species for each explorer."},
		{"id": "wild_harvest", "name": "Wild Harvest", "parents": ["careful_gathering"], "insight": 16, "description": "Every natural specimen harvest also yields one ordinary material from that plant."},
		{"id": "refined_gathering", "name": "Refined Gathering", "parents": ["wild_harvest"], "insight": 30, "description": "Each explorer also has a 15% chance to gather one refined material from a natural specimen."},
		{"id": "botanical_awareness", "name": "Botanical Awareness", "parents": ["heart"], "insight": 6, "description": "Visible, unharvested specimens catch the light within six metres."},
		{"id": "root_resonance", "name": "Root Resonance", "parents": ["botanical_awareness"], "insight": 20, "description": "Sense when a floor holds a plant the Garden has yet to identify."},
		{"id": "checkpoint_deposit", "name": "Returning Root", "parents": ["heart"], "insight": 8, "description": "Discover living roots in the Wilds. Each explorer can send one carried seed or plant material home at each root."},
		{"id": "deep_root_network", "name": "Deep Root Network", "parents": ["checkpoint_deposit"], "insight": 30, "description": "Each explorer can deposit two individual items at each Returning Root."},
		{"id": "reaching_tendrils", "name": "Reaching Tendrils", "parents": ["checkpoint_deposit"], "insight": 20, "description": "Increase the chance of a Returning Root on eligible floors from 25% to 40%."},
		{"id": "monster_studies", "name": "Offering Altar", "parents": ["heart"], "insight": 4, "description": "Grants the unique Field Study station. Study a trophy for 4 Knowledge the first time and 1 on repeats."},
	]

static func get_node(id: String) -> Dictionary:
	return _by_id.get(id,{})
static func required_core() -> Array:
	return ["irrigation","nursery","seed_archive","monster_studies","checkpoint_deposit","clearing_1"]
static func phase_name(phase: int) -> String:
	return ["Sheltered Fragment","First Awakening","Rooted Heart","Living Nexus","Living Sanctuary"][clampi(phase,0,4)]

static func enabled(id: String) -> bool:
	return _by_id.has(id)
