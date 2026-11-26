extends RefCounted
## Floor-local rendering parameters shared by the live Wilds and fixed-seed terrain lab.
const RELIEF = preload("res://assets/terrain_m02/wilds_relief.png")
# Production value, bounds, increment, display name and units.
const CONTROLS := {
	"wilds.sway": [1.0, 0.0, 2.0, 0.05, "Vegetation sway", "x"],
	"wilds.veil": [0.76, 0.0, 0.95, 0.01, "Foreground crown thinning", "fraction"],
	"wilds.wound": [0.80, 0.0, 1.35, 0.05, "Cambium vein contrast", "x"],
	"wilds.motes": [0.60, 0.0, 1.0, 0.02, "Airborne motes", "fraction"],
	"wilds.mist": [0.74, 0.0, 1.5, 0.02, "Mire ground mist", "x"],
	"wilds.light_patches": [0.78, 0.0, 1.5, 0.02, "Habitat light patches", "x"],
	"wilds.grain_scale": [1.0, 0.45, 2.0, 0.05, "Ground texture scale", "x"],
	"wilds.variation": [1.0, 0.0, 1.6, 0.05, "Surface variation", "x"],
	"wilds.trail_blend": [0.68, 0.18, 1.2, 0.02, "Trail fringe", "m"],
	"wilds.relief": [0.038, 0.0, 0.08, 0.002, "Surface relief", "m"],
	"wilds.water_motion": [1.0, 0.0, 2.0, 0.05, "Water motion speed", "x"],
	"wilds.water_tint": [0.79, 0.55, 0.96, 0.01, "Deep water opacity", "fraction"],
}

static func bind(surface: ShaderMaterial, weights: Vector3) -> void:
	surface.set_shader_parameter("biome_mix", weights)
	surface.set_shader_parameter("wilds_relief_tile", RELIEF)
	apply(surface, {})

static func apply(surface: ShaderMaterial, changes: Dictionary) -> void:
	for id: String in CONTROLS:
		if id in ["wilds.sway","wilds.veil","wilds.wound","wilds.motes"]: continue
		surface.set_shader_parameter(id.get_slice(".", 1), changes.get(id, CONTROLS[id][0]))

## Render colors follow the existing continuous climate weights, including transition floors.
static func sunlight(weights: Vector3) -> Color:
	return Color("#ffe2b1") * weights.x + Color("#bdcfbd") * weights.y + Color("#cbd0e8") * weights.z

static func skylight(weights: Vector3) -> Color:
	return Color("#a2af9e") * weights.x + Color("#9dbbb5") * weights.y + Color("#b4aec5") * weights.z
