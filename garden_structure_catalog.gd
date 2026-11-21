extends RefCounted
## Footprint half-extents are metres. The starting altar is relocatable, not purchasable.
const DEFINITIONS := {
	"bed": {"name": "Cultivation bed", "art": "starter_bed", "half": Vector2(1.00, 0.73), "buildable": true},
	"altar": {"name": "Garden Altar", "art": "altar", "half": Vector2(0.88, 0.88), "buildable": false},
	"study": {"name": "Field study", "art": "monster_studies", "half": Vector2(0.97, 0.98), "buildable": true},
	"archive": {"name": "Seed cache", "art": "seed_archive", "half": Vector2(0.97, 0.98), "buildable": true},
}
