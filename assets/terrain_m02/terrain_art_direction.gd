extends RefCounted
## Preview color scripts. The shared forms carry the identity across climates.

const PROFILES := [
	{"label": "Garden sanctuary", "note": "Honey light, olive crowns, dark walnut roots and a garnet Heart.",
		"bark": Color("#39291f"), "edge": Color("#78553a"), "leaf": Color("#263421"), "tip": Color("#575f36"),
		"stone": Color("#565348"), "accent": Color("#cc563a"), "sun": Color("#ffe1ad"),
		"ambient": Color("#b9b59b"), "ground": Color("#a19a62"), "water": Color("#8e9c72")},
	{"label": "Wilds · Outer Grove", "note": "Blue-green crowns, umber bark and weathered amber trails.",
		"bark": Color("#302921"), "edge": Color("#64503a"), "leaf": Color("#283e31"), "tip": Color("#56654b"),
		"stone": Color("#454d48"), "accent": Color("#b4814d"), "sun": Color("#e2e5be"),
		"ambient": Color("#8faaa2"), "ground": Color("#879479"), "water": Color("#779a83")},
	{"label": "Wilds · Sable Mire", "note": "Peat-black roots, sedges, muted jade water and tarnished copper.",
		"bark": Color("#292724"), "edge": Color("#585047"), "leaf": Color("#2f4032"), "tip": Color("#627357"),
		"stone": Color("#485754"), "accent": Color("#946441"), "sun": Color("#c9d5b4"),
		"ambient": Color("#829e96"), "ground": Color("#798b73"), "water": Color("#7d8d6d")},
	{"label": "Wilds · Hollow Below", "note": "Slate stone, narrow crowns, cool violet shade and sparse wine-red growth.",
		"bark": Color("#2b2630"), "edge": Color("#61505e"), "leaf": Color("#2a3038"), "tip": Color("#565368"),
		"stone": Color("#535564"), "accent": Color("#a74c62"), "sun": Color("#cfd4ef"),
		"ambient": Color("#8b93ad"), "ground": Color("#827c8e"), "water": Color("#7891a8")},
]

static func profile(index: int) -> Dictionary:
	return PROFILES[index]

static func placements(base: Dictionary, biome: int) -> Dictionary:
	var result := base.duplicate()
	result.plants = []
	var stride: int = [5, 4, 3, 4][biome]
	var tree_count := 0
	var placement_index := 0
	for plant in base.plants:
		var prop: Dictionary = plant.duplicate()
		if plant.kind == "tree":
			if tree_count % stride == 0:
				prop.kind = "sapling"
				prop.height *= 0.66
			elif biome == 0:
				prop.height *= 0.91
			tree_count += 1
		elif plant.kind == "grass" and biome == 2:
			prop.height *= 1.35
		elif plant.kind == "fern" and biome == 3 and placement_index % 11 == 0:
			prop.kind = "wine_fern"
		result.plants.append(prop)
		placement_index += 1
	return result
