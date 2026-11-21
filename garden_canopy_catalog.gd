extends RefCounted
## Garden forest presentation only. Distances/heights are metres; colours are albedo.
## Original CC0 foliage and rebuild instructions: assets/garden/canopy/sources.json.

const CROWNS := [
	preload("res://assets/garden/canopy/maple_crown_01.glb"),
	preload("res://assets/garden/canopy/maple_crown_02.glb"),
	preload("res://assets/garden/canopy/birch_crown_01.glb"),
	preload("res://assets/garden/canopy/bush_crown.glb"),
]
const LEAF_MAPS := [
	preload("res://assets/garden/canopy/maple_leaves.png"),
	preload("res://assets/garden/canopy/maple_leaves.png"),
	preload("res://assets/garden/canopy/birch_leaves.png"),
	preload("res://assets/garden/canopy/bush_leaves.png"),
]
const LEAF_SHADOW := Color("#293b2b")
const LEAF_MIDTONE := Color("#344831")
const LEAF_HIGHLIGHT := Color("#465b3c")
const UNDERGROWTH := Color("#263528")
const BARK_SHADOW := Color("#312b20")

const CHUNK_SIZE_METRES := 10.0
const EXTERIOR_RADIUS_METRES := 65.0
const PATCH_SPACING_METRES := 3.6
const PATCH_WIDTH_METRES := 6.4
const PATCH_THICKNESS_METRES := 1.6
const CANOPY_HEIGHT_METRES := 2.6
const FOREGROUND_HEIGHT_RATIO := 0.64
const HEIGHT_VARIATION_METRES := 0.23
const LEAF_LIFT_METRES := 0.1
const EDGE_INSET_METRES := 0.13
const LEAF_OVERHANG_METRES := 0.65
const EDGE_CROWN_WIDTH_METRES := 3.6
const EDGE_CROWN_OFFSET_METRES := 0.8
const DISTANT_DETAIL_START_METRES := 30.0
const LEAF_ALPHA_CUTOFF := 0.5
