extends Node3D
## Five authored silhouettes built from roots, living bark and a shared fissure.
const Meshes = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const STAGES := ["Dormant Heart", "Early restoration", "Mid restoration", "Mature canopy", "Fully restored"]
const HEIGHTS := [1.67, 2.24, 3.07, 4.12, 4.75]
const ROOT_REACH := [2.1, 2.45, 2.86, 3.16, 3.40]
const CROWNS := [0, 0, 3, 7, 10]
const BARK := Color("#342720")
const GRAIN := Color("#846046")
const MOSS := Color("#666744")
const LEAF := Color("#4b5232")
const CORE := Color("#d23735")

var stage := 0
var models: Array[MeshInstance3D] = []
var pulse: OmniLight3D
var transition: Tween

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.91
	var crystal := StandardMaterial3D.new()
	crystal.vertex_color_use_as_albedo = true
	crystal.cull_mode = BaseMaterial3D.CULL_DISABLED
	crystal.roughness = 0.54
	crystal.emission_enabled = true
	crystal.emission = Color("#b81e31")
	crystal.emission_energy_multiplier = 0.29
	for index in STAGES.size():
		var model := MeshInstance3D.new()
		model.name = "HeartStage%d" % index
		model.mesh = _form(index)
		model.set_surface_override_material(0, material)
		model.set_surface_override_material(1, crystal)
		add_child(model)
		models.append(model)
	pulse = OmniLight3D.new()
	pulse.light_color = Color("#ff5938")
	pulse.omni_range = 2.4
	pulse.omni_attenuation = 1.3
	add_child(pulse)
	show_stage(0, false)

func show_stage(index: int, animated: bool = true) -> void:
	stage = clampi(index, 0, STAGES.size() - 1)
	if transition != null:
		transition.kill()
	for i in models.size():
		models[i].visible = i == stage
		models[i].position = Vector3.ZERO
		models[i].scale = Vector3.ONE
	pulse.position = Vector3(0.29, 0.96 + stage * 0.10, 0.84)
	pulse.light_energy = 0.68 + stage * 0.18
	if animated:
		models[stage].position.y = -0.16
		models[stage].scale = Vector3(1.015, 0.94, 1.015)
		transition = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
		transition.tween_property(models[stage], "position:y", 0.0, 0.36)
		transition.tween_property(models[stage], "scale", Vector3.ONE, 0.36)

func _form(index: int) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 3319
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height: float = HEIGHTS[index]
	var spread: float = ROOT_REACH[index]
	var body := Vector3(-0.40, height * 0.71, -0.33)
	var tip := Vector3(0.22 + index * 0.085, height, -0.36)
	var shoulder := Vector3(-0.75, height * 0.42, -0.23)
	Meshes._tube(bark, [Vector3(0, -0.11, -0.25), shoulder, body, tip],
		[0.70 + 0.09 * index, 0.73 + 0.06 * index, 0.54, 0.12 if index < 2 else 0.08], BARK)
	# Split bark ribs curl around the fissure and visibly pass in front of the core.
	Meshes._tube(bark, [Vector3(-0.42, 0.02, 0.34), Vector3(-0.49, 0.58, 0.90),
		Vector3(-0.45, 1.20, 0.89), Vector3(-0.23, 1.66 + index * 0.11, 0.63), body],
		[0.39, 0.32, 0.25, 0.17, 0.08], BARK.lerp(GRAIN, 0.18))
	Meshes._tube(bark, [Vector3(0.59, -0.06, 0.37), Vector3(0.69, 0.63, 0.81),
		Vector3(0.60, 1.34 + index * 0.10, 0.85), Vector3(0.19, 1.69 + index * 0.18, 0.51), tip],
		[0.38, 0.32, 0.23, 0.14, 0.025], BARK.lerp(GRAIN, 0.31))
	Meshes._tube(bark, [Vector3(-0.63, 0.45, 0.65), Vector3(-0.16, 0.43, 1.02),
		Vector3(0.32, 0.59, 1.02), Vector3(0.70, 0.85, 0.72)], [0.18, 0.14, 0.12, 0.06], BARK)
	# Twisted strands run into the main ribs and interrupt the exposed crystal edges.
	Meshes._tube(bark, [Vector3(-0.68, 0.20, 0.74), Vector3(-0.30, 0.62, 0.98),
		Vector3(-0.08, 0.88, 1.01), Vector3(-0.20, 1.22, 0.93), Vector3(-0.44, 1.41, 0.70)],
		[0.22, 0.13, 0.08, 0.055, 0.014], BARK.lerp(GRAIN, 0.32))
	Meshes._tube(bark, [Vector3(0.63, 0.39, 0.80), Vector3(0.37, 0.83, 0.98),
		Vector3(0.43, 1.13, 0.95), Vector3(0.70, 1.43 + index * 0.08, 0.68)],
		[0.16, 0.10, 0.07, 0.02], BARK.lerp(GRAIN, 0.44))
	for i in 5 + index:
		var angle := i * TAU / (5.0 + index) + random.randf_range(-0.24, 0.24)
		var ray := Vector3(cos(angle), 0, sin(angle))
		var bend := Vector3(-ray.z, 0, ray.x) * random.randf_range(-0.47, 0.47)
		var reach := spread * random.randf_range(0.60, 1.02)
		var end := ray * reach
		Meshes._tube(bark, [Vector3(0, 0.46, 0), ray * reach * 0.30 + Vector3.UP * 0.28,
			end * 0.63 + bend + Vector3.UP * 0.075, end - Vector3.UP * 0.04],
			[0.32, 0.24, 0.12, 0.021], BARK.lerp(GRAIN, random.randf_range(0.11, 0.39)))
		if index >= 1:
			Meshes._tube(bark, [end * 0.48 + Vector3.UP * 0.11, end * 0.72 - bend * 1.12,
				end * 0.89 - bend * 2.05], [0.12, 0.069, 0.012], BARK)
	var branches: int = [2, 4, 5, 8, 11][index]
	for i in branches:
		var angle := i * 2.39996 + 0.48
		var ray := Vector3(cos(angle), 0, sin(angle))
		var start := body * (0.72 + 0.065 * (i % 4))
		var reach := (0.56 + 0.31 * index) * random.randf_range(0.74, 1.16)
		var elbow := start + ray * reach * 0.65 + Vector3.UP * 0.43
		var branch := start + ray * reach + Vector3.UP * (0.41 + 0.12 * (i % 3))
		Meshes._tube(bark, [start, elbow, branch], [0.25, 0.13, 0.019], BARK.lerp(GRAIN, 0.23))
		var fork := branch + ray.cross(Vector3.UP) * (0.20 + 0.11 * index) + Vector3.UP * 0.27
		Meshes._tube(bark, [elbow, branch.lerp(fork, 0.55), fork], [0.10, 0.053, 0.011], BARK)
		if i < CROWNS[index]:
			var width := (0.30 + 0.097 * index) * random.randf_range(0.81, 1.21)
			var leaf := LEAF.lerp(MOSS, random.randf_range(0.18, 0.69))
			Meshes._crown(bark, random, branch + Vector3.UP * 0.17, Vector3(width, width * 0.58, width * 0.94), leaf)
			Meshes._crown(bark, random, fork + Vector3.UP * 0.089, Vector3(width * 0.71, width * 0.43, width * 0.69), leaf.lightened(0.09))
			Meshes._leaf_spray(bark, fork, angle, width * 0.88, leaf, MOSS)
	var mesh := bark.commit()
	var crystal := SurfaceTool.new()
	crystal.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A faceted seam is seated against the trunk, recessed between the two bark ribs.
	var bottom := Vector3(0.17, 0.54, 0.73)
	var lower := Vector3(0.23, 0.83, 0.88)
	var ridge := Vector3(0.11 + 0.04 * index, 1.16 + index * 0.09, 0.81)
	var top := Vector3(-0.04, 1.63 + index * 0.15, 0.63)
	var left := Vector3(-0.27, 1.05, 0.66)
	var notch := Vector3(0.43, 0.84, 0.67)
	var right := Vector3(0.34, 1.31 + index * 0.09, 0.69)
	Meshes._face(crystal, bottom, lower, left, CORE.darkened(0.46))
	Meshes._face(crystal, lower, ridge, left, CORE.lightened(0.16))
	Meshes._face(crystal, ridge, top, left, CORE.darkened(0.11))
	Meshes._face(crystal, top, ridge, right, CORE.darkened(0.58))
	Meshes._face(crystal, ridge, lower, right, CORE.darkened(0.36))
	Meshes._face(crystal, lower, bottom, notch, CORE.darkened(0.25))
	Meshes._face(crystal, right, lower, notch, CORE)
	crystal.commit(mesh)
	return mesh
