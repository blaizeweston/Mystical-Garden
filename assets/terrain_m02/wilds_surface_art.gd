extends RefCounted
## Floor-local rendering parameters shared by the live Wilds and fixed-seed terrain lab.
const RELIEF = preload("res://assets/terrain_m02/wilds_relief.png")
# Production value, bounds, increment, display name and units.
const CONTROLS := {
	"wilds.grain_scale": [1.0, 0.45, 2.0, 0.05, "Ground texture scale", "×"],
	"wilds.variation": [1.0, 0.0, 1.6, 0.05, "Surface variation", "×"],
	"wilds.trail_blend": [0.68, 0.18, 1.2, 0.02, "Trail fringe", "m"],
	"wilds.relief": [0.038, 0.0, 0.08, 0.002, "Surface relief", "m"],
	"wilds.water_motion": [1.0, 0.0, 2.0, 0.05, "Water motion speed", "×"],
	"wilds.water_tint": [0.79, 0.55, 0.96, 0.01, "Deep water opacity", "α"],
}

static func bind(surface: ShaderMaterial, weights: Vector3) -> void:
	surface.set_shader_parameter("biome_mix", weights)
	surface.set_shader_parameter("wilds_relief_tile", RELIEF)
	apply(surface, {})

static func apply(surface: ShaderMaterial, changes: Dictionary) -> void:
	for id: String in CONTROLS:
		surface.set_shader_parameter(id.get_slice(".", 1), changes.get(id, CONTROLS[id][0]))
