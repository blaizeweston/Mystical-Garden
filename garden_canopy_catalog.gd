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
const TREES := [
	preload("res://assets/garden/canopy/maple_tree_01.glb"),
	preload("res://assets/garden/canopy/maple_tree_02.glb"),
	preload("res://assets/garden/canopy/birch_tree_01.glb"),
]
const BARK_MAPS := [
	preload("res://assets/garden/canopy/maple_bark.jpg"),
	preload("res://assets/garden/canopy/maple_bark.jpg"),
	preload("res://assets/garden/canopy/birch_bark.jpg"),
]
const LEAF_SHADOW := Color("#293b2b")
const LEAF_MIDTONE := Color("#344831")
const LEAF_HIGHLIGHT := Color("#465b3c")
const BARK_TINT := Color("#80725a")

const CHUNK_SIZE_METRES := 10.0
const EXTERIOR_RADIUS_METRES := 65.0
const PATCH_SPACING_METRES := 3.6
const PATCH_WIDTH_METRES := 6.4
const PATCH_THICKNESS_METRES := 2.5
const CANOPY_HEIGHT_METRES := 3.1
const LOWER_LAYER_DROP_METRES := 1.0
const LOWER_LAYER_BRIGHTNESS := 0.66
const FOREGROUND_HEIGHT_RATIO := 0.72
const HEIGHT_VARIATION_METRES := 0.35
const CLEARING_CROWN_SETBACK_RATIO := 0.44
const RECLAIM_FADE_METRES := 1.1
const TREE_HEIGHT_METRES := 4.4
const TREE_HEIGHT_VARIATION_METRES := 0.6
const TREE_WIDTH_METRES := 4.8
const TREE_EDGE_OFFSET_METRES := 1.45
const TREE_ROW_SPACING_METRES := 2.2
const DISTANT_DETAIL_START_METRES := 30.0
const LEAF_ALPHA_CUTOFF := 0.5
