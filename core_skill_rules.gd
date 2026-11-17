extends RefCounted
## Authoritative native weapon delivery for affinity Core placement and projectiles.
const Classes = preload("res://class_catalog.gd")
const WEAPON_DELIVERY := {
	"blade":    {"kind": "ground", "range": 2.6, "lance_range": 5.6},
	"spear":    {"kind": "ground", "range": 3.3, "lance_range": 6.2},
	"hammer":   {"kind": "ground", "range": 2.2, "lance_range": 4.8},
	"staff":    {"kind": "seed",   "range": 5.2, "lance_range": 6.6},
	"wand":     {"kind": "seed",   "range": 4.4, "lance_range": 5.5},
	"orb":      {"kind": "seed",   "range": 5.7, "lance_range": 7.0},
	"bow":      {"kind": "arrow",  "range": 5.8, "lance_range": 7.6},
	"crossbow": {"kind": "bolt",   "range": 5.4, "lance_range": 7.0},
	"ring":     {"kind": "seed",   "range": 4.2, "lance_range": 5.8},
	"knives":   {"kind": "ground", "range": 2.1, "lance_range": 4.5},
	"scythe":   {"kind": "ground", "range": 2.9, "lance_range": 5.6},
	"whip":     {"kind": "ground", "range": 3.6, "lance_range": 6.0},
	"bell":     {"kind": "ground", "range": 2.6, "lance_range": 5.2},
	"censer":   {"kind": "ground", "range": 2.9, "lance_range": 5.5},
	"fan":      {"kind": "seed",   "range": 4.4, "lance_range": 5.8},
}
const DELIVERY_SHAPES := {"ground": "", "arrow": "arrow", "bolt": "bolt", "seed": "orb"}

static var WEAPON_FORMS := weapon_forms(Classes.DEFINITIONS)


static func weapon_forms(classes: Array) -> Dictionary:
	var result := {}
	for definition in classes:
		for weapon in definition.weapons:
			result[weapon.id] = weapon.visual
	return result
