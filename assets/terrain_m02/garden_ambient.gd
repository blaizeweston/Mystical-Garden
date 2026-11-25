extends RefCounted
## Artistic defaults and allowable developer ranges. All distances are decorative.
const OBJECTS := {"heart":"Heart fissure","root":"Root energy","intake":"Water Intake","spray":"Living Sprinkler","pollen":"Pollination Bloom"}
# Baseline, minimum, maximum, step, display label, units.
const CONTROLS := {
	"heart.frequency": [0.18,0.06,0.5,0.01,"Breaths per second","Hz"],
	"heart.intensity": [0.55,0,1.6,0.05,"Pulse strength","×"],
	"heart.duration": [2.2,0.5,4,0.1,"Breath duration","s"],
	"heart.hue": [4,0,360,1,"Fissure tint","°"],
	"root.frequency": [0.18,0.06,0.5,0.01,"Pulses per second","Hz"],
	"root.intensity": [0.31,0,1,0.02,"Vein strength","×"],
	"root.speed": [2.1,0.4,5,0.1,"Travel speed","m/s"],
	"root.width": [0.72,0.2,1.8,0.05,"Pulse half-width","m"],
	"root.hue": [9,0,360,1,"Sap tint","°"],
	"intake.speed": [0.46,0.15,1,0.01,"Ripple frequency","Hz"],
	"intake.opacity": [0.55,0,1,0.05,"Ripple opacity","×"],
	"spray.density": [18,3,30,1,"Droplets per plant","pieces"],
	"spray.size": [0.069,0.02,0.11,0.002,"Droplet width","m"],
	"spray.height": [0.55,0.15,1.25,0.05,"Spray crest","m"],
	"spray.spread": [1.17,0.5,1.8,0.05,"Decorative throw","m"],
	"spray.speed": [1,0.4,2,0.05,"Cycle speed","×"],
	"spray.lifetime": [0.91,0.45,1.6,0.05,"Flight duration at normal speed","s"],
	"spray.opacity": [0.82,0.1,1,0.02,"Water opacity","×"],
	"spray.hue": [190,0,360,1,"Water tint","°"],
	"spray.splash": [0.48,0,1,0.05,"Splash strength","×"],
	"pollen.density": [7,0,16,1,"Motes per flower","pieces"],
	"pollen.size": [0.075,0.025,0.14,0.002,"Mote width","m"],
	"pollen.spread": [0.46,0.1,0.85,0.02,"Drift spread","m"],
	"pollen.speed": [0.2,0.04,0.4,0.01,"Rising speed","m/s"],
	"pollen.lifetime": [2.9,1,5,0.1,"Mote lifetime","s"],
	"pollen.hue": [44,0,360,1,"Pollen tint","°"],
	"pollen.opacity": [0.8,0.1,1,0.05,"Pollen opacity","×"],
}
const MASKS = preload("res://assets/terrain_m02/garden_motes.svg")
const AIR = preload("res://assets/shaders/garden_motes.gdshader")
const FLOWER = preload("res://assets/shaders/garden_flower.gdshader")

static func configure(material: ShaderMaterial, group: String, overrides: Dictionary, clock := -1.0) -> void:
	for id: String in CONTROLS:
		if id.get_slice(".",0) != group: continue
		var key := id.get_slice(".",1)
		var value: float = overrides.get(id,CONTROLS[id][0])
		if key == "hue":
			var saturation := 0.88 if group in ["heart","root"] else 0.62 if group=="pollen" else 0.38
			material.set_shader_parameter("tint",Color.from_hsv(value/360.0,saturation,1.0))
		else:
			material.set_shader_parameter(key,value)
	material.set_shader_parameter("sample_time",clock)

static func mote_material(group: String, overrides := {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = AIR
	mat.set_shader_parameter("mask_atlas", MASKS)
	mat.set_shader_parameter("family", ["spray","pollen","intake"].find(group))
	configure(mat,group,overrides)
	return mat

## Each quad is an analytic particle. UV2 carries its ordinal and emitter orientation.
## Its anchor stays fixed while the shader samples a repeatable trajectory at any time.
static func emitter(tool: SurfaceTool, group: String, center: Vector3, yaw: float) -> void:
	var count := 35 if group=="spray" else 16 if group=="pollen" else 3
	for index in count:
		for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
			tool.set_uv(corner)
			tool.set_uv2(Vector2(index,yaw))
			tool.add_vertex(center)
	if group=="spray":
		# A broken thread near each spout makes the arc readable at gameplay scale.
		for arm in 5:
			for segment in 6:
				for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
					tool.set_uv(Vector2((segment+corner.x)/6.,corner.y))
					tool.set_uv2(Vector2(35+arm,yaw))
					tool.add_vertex(center)

static func batch(group: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = group.capitalize()
	node.material_override = mote_material(group)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 3.5 # Includes the longest permitted rise or throw from a static anchor.
	return node

static func bloom_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FLOWER
	return mat
