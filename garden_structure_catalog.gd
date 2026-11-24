extends RefCounted
## Footprint half-extents are metres. The starting altar is relocatable, not purchasable.
const DEFINITIONS := {
	"bed": {"name": "Cultivation bed", "art": "starter_bed", "research":"cultivation_grounds", "repeatable":true, "cost":{"energy":12,"materials":{}}, "half": Vector2(1.00, 0.73), "buildable": true},
	"intake": {"name":"Water Intake", "art":"intake", "research":"irrigation", "repeatable":false, "bank_reach_m":1.65, "half":Vector2(0.40,0.40), "buildable":true},
	"sprinkler": {"name":"Living Sprinkler", "art":"sprinkler", "research":"irrigation", "repeatable":true,
		"cost":{"energy":24, "materials":{}}, "half":Vector2(0.41,0.41), "buildable":true,
		"effect":"watering", "radius_m":3.5, "extended_m":5.0, "base":1.25, "improved":1.4},
	"pollination_bloom": {"name":"Pollination Bloom", "art":"pollination_bloom", "research":"pollination_bloom", "repeatable":true,
		"cost":{"energy":32, "materials":{}}, "half":Vector2(0.41,0.41), "buildable":true,
		"effect":"seeds", "radius_m":3.0, "extended_m":4.5, "base":3, "improved":4},
	"nursery": {"name":"Symbiotic Nursery", "art":"nursery", "research":"nursery", "repeatable":true,
		"cost":{"energy":28, "materials":{}}, "half":Vector2(0.41,0.41), "buildable":true,
		"effect":"familiarity", "radius_m":3.0, "extended_m":4.5, "base":2, "improved":3},
	"refinement_grove": {"name":"Refinement Grove", "art":"refinement_grove", "research":"refinement_grove", "repeatable":true,
		"cost":{"energy":40, "materials":{"plant_part_rare_ironroot": 1}}, "half":Vector2(0.41,0.41), "buildable":true,
		"effect":"refinement", "radius_m":2.5, "extended_m":4.0, "base":0.15, "improved":0.25},
	"vital_roots": {"name":"Vital Roots", "art":"vital_roots", "research":"vital_roots", "repeatable":true,
		"cost":{"energy":32, "materials":{}}, "half":Vector2(0.41,0.41), "buildable":true,
		"effect":"growth", "radius_m":4.0, "extended_m":6.0, "base":1.3, "improved":1.5},
	"bud_sanctuary": {"name":"Bud Sanctuary", "art":"bud_sanctuary", "research":"bud_sanctuary", "repeatable":true,
		"cost":{"energy":36, "materials":{"plant_part_rare_dewcap": 1}}, "half":Vector2(0.41,0.41), "buildable":true,
		"effect":"care", "radius_m":3.0, "extended_m":4.5, "base":1, "improved":2},
	"altar": {"name": "Garden Altar", "art": "altar", "half": Vector2(0.88, 0.88), "buildable": false},
	"study": {"name": "Field study", "art": "monster_studies", "research":"monster_studies", "repeatable":false, "half": Vector2(0.97, 0.98), "buildable": true},
	"archive": {"name": "Seed cache", "art": "seed_archive", "research":"seed_archive", "repeatable":false, "half": Vector2(0.97, 0.98), "buildable": true},
}

# Authored initial positions also restore pre-layout Gardens.
const ORIGINAL_BEDS := [Vector3(3.6, 0, -1.6), Vector3(3.6, 0, 2.6), Vector3(-3.6, 0, 2.6), Vector3(-5.0,0,-5.0), Vector3(0,0,6.4), Vector3(5.7,0,5.4), Vector3(-6,0,5.6), Vector3(7.9,0,1.7), Vector3(3.3,0,-6.8)]
const ORIGINAL_ALTAR := Vector3(-3.5,0,-2)
