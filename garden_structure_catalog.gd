extends RefCounted
## Footprint half-extents are metres. The starting altar is relocatable, not purchasable.
const DEFINITIONS := {
	"bed": {"name": "Cultivation bed", "art": "starter_bed", "research":"cultivation_grounds", "repeatable":true, "cost":{"energy":12,"materials":{}}, "half": Vector2(1.00, 0.73), "buildable": true},
	"altar": {"name": "Garden Altar", "art": "altar", "half": Vector2(0.88, 0.88), "buildable": false},
	"study": {"name": "Field study", "art": "monster_studies", "research":"monster_studies", "repeatable":false, "half": Vector2(0.97, 0.98), "buildable": true},
	"archive": {"name": "Seed cache", "art": "seed_archive", "research":"seed_archive", "repeatable":false, "half": Vector2(0.97, 0.98), "buildable": true},
}

# Authored initial positions also restore pre-layout Gardens.
const ORIGINAL_BEDS := [Vector3(3.6, 0, -1.6), Vector3(3.6, 0, 2.6), Vector3(-3.6, 0, 2.6), Vector3(-5.0,0,-5.0), Vector3(0,0,6.4), Vector3(5.7,0,5.4), Vector3(-6,0,5.6), Vector3(7.9,0,1.7), Vector3(3.3,0,-6.8)]
const ORIGINAL_ALTAR := Vector3(-3.5,0,-2)
