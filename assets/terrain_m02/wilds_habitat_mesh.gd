extends RefCounted

const Roots = preload("res://assets/terrain_m02/terrain_root_mesh.gd")

static func tree(variant: int, family: int, profile: Dictionary) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lean := Roots._heading(variant * 2.4 + 0.8)
	var shoulder := lean * 0.11 + Vector3.UP * 0.43
	var hinge := -lean * 0.09 + Vector3.UP * 0.72
	var tip := lean * 0.29 + Vector3.UP * 1.03
	Roots._tube(tool, [Vector3.ZERO, shoulder, hinge, tip],
		[0.068, 0.052, 0.035, 0.003], profile.bark.lerp(profile.edge, 0.18))
	for i in 4:
		var v := Roots._heading(variant * 0.47 + i * 1.57)
		Roots._tube(tool, [shoulder * 0.58, v * 0.15 + Vector3.UP * 0.045, v * 0.24],
			[0.045, 0.029, 0.004], profile.bark)
	for i in 5:
		var angle := float(i) * 2.399 + variant
		var spread := Roots._heading(angle)
		var at := shoulder.lerp(hinge, 0.19 + i * 0.17)
		var tip_branch := at + spread * (0.19 + 0.044 * i) + Vector3.UP * (0.28 - 0.029 * i)
		Roots._tube(tool, [at, at.lerp(tip_branch, 0.52) + Vector3.UP * 0.09, tip_branch],
			[0.040, 0.026, 0.002], profile.edge)
		if family == 1 or i % 2 == 0:
			Roots._leaf_spray(tool, tip_branch, angle, 0.23 if family == 1 else 0.14, profile.leaf, profile.tip)
	return tool.commit()

static func prop(kind: String, variant: int, profile: Dictionary) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"reed":
			for i in 7:
				var angle := float(i) * 2.399 + variant
				var at := Roots._heading(angle) * (0.08 + 0.02 * i)
				var top := at * 1.45 + Vector3.UP * (0.60 + 0.066 * i)
				Roots._tube(tool, [at, top * 0.56, top], [0.025, 0.014, 0.013], profile.tip)
				Roots._leaf(tool, at + Vector3.UP * 0.12, top * 0.68 + Roots._heading(angle) * 0.24,
					0.045, profile.leaf.lerp(profile.tip, 0.48))
				Roots._tube(tool, [top * 0.95, top + Vector3.UP * 0.075], [0.042, 0.022], Color("#906d44"))
		"fungus":
			for i in 5:
				var at := Roots._heading(float(i) * 2.399 + variant) * (0.11 + 0.05 * i)
				var top := at * 1.18 + Vector3.UP * (0.40 + 0.135 * (i % 3))
				Roots._tube(tool, [at, at.lerp(top, 0.58), top], [0.074, 0.058, 0.036], Color("#8c7c8f"))
				for j in 8:
					var rim := Roots._heading(j * TAU / 8)
					var next := Roots._heading((j + 1) * TAU / 8)
					Roots._face(tool, top + Vector3.UP * 0.125, top + rim * 0.25, top + next * 0.25, Color("#837b9f"))
					Roots._face(tool, top - Vector3.UP * 0.050, top + next * 0.25, top + rim * 0.25, Color("#b69ca1"))
		"fallen_timber":
			Roots._tube(tool, [Vector3(-0.94, 0.03, -0.15), Vector3(-0.28, 0.22, 0.07),
				Vector3(0.31, 0.16, 0.12), Vector3(0.94, 0.02, 0.30)],
				[0.128, 0.165, 0.139, 0.063], profile.edge)
			for i in 3:
				var at := Vector3(-0.43 + i * 0.41, 0.19, 0.07)
				Roots._tube(tool, [at, at + Vector3(0.16, 0.18, -0.18), at + Vector3(0.28, 0.24, -0.25)],
					[0.077, 0.041, 0.008], profile.bark)
		"root_arch":
			for i in 3:
				var shift := Vector3(-0.21 * i, 0.0, i * 0.22 - 0.24)
				Roots._tube(tool, [Vector3(-1.55, -0.12, -0.31) + shift, Vector3(-0.74, 0.48 + i * 0.13, -0.23) + shift,
					Vector3(0.01, 0.89 - i * 0.17, 0.12) + shift, Vector3(0.63, 0.52, 0.26) + shift,
					Vector3(1.38, -0.20, 0.14) + shift], [0.13, 0.26, 0.23, 0.18, 0.044], profile.edge)
				Roots._tube(tool, [Vector3(0.12, 0.69, 0.10) + shift, Vector3(0.69, 0.35, -0.42) + shift,
					Vector3(1.02, -0.10, -0.65) + shift], [0.13, 0.11, 0.014], profile.bark)
	return tool.commit()
