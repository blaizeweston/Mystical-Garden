extends RefCounted
## Reusable low-poly tree silhouettes, buttress roots and thorny snags.
const SAMPLES := 7
const CROWN_SAMPLES := 9

static func tree(variant: int) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 1709 + variant * 101
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color("#413127")
	var tip := Vector3(random.randf_range(-0.12, 0.12), 0.83, random.randf_range(-0.08, 0.08))
	_tube(tool, [Vector3.ZERO, Vector3(-0.035, 0.23, 0.014), tip * 0.62, tip],
		[0.135, 0.075, 0.048, 0.007], bark)
	for index in 6:
		var angle := TAU * index / 6.0 + random.randf_range(-0.28, 0.28)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var end := direction * random.randf_range(0.22, 0.36)
		_tube(tool, [Vector3.UP * 0.19, direction * 0.09 + Vector3.UP * 0.09,
			end * 0.53 + Vector3.UP * 0.025, end], [0.060, 0.044, 0.029, 0.003], bark)
	for index in 7:
		var angle := index * 2.39996 + float(variant) * 0.39
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var height := random.randf_range(0.43, 0.84)
		var spread := random.randf_range(0.20, 0.37)
		var branch := tip * height + direction * spread + Vector3.UP * 0.24
		_tube(tool, [tip * (height - 0.14), branch.lerp(tip * height, 0.51), branch],
			[0.029, 0.016, 0.003], bark.lightened(0.03))
		var green := Color("#15231c").lerp(Color("#35422a"), random.randf() * 0.8)
		_crown(tool, random, branch + Vector3.UP * 0.035,
			Vector3(random.randf_range(0.13, 0.22), random.randf_range(0.065, 0.115),
				random.randf_range(0.12, 0.20)), green)
		for tuft in 3:
			var phase := angle + tuft * 2.40
			var drift := Vector3(cos(phase), random.randf_range(-0.11, 0.08), sin(phase)) * 0.16
			_crown(tool, random, branch + drift, Vector3(0.10, 0.067, 0.095), green.darkened(0.16))
	_crown(tool, random, tip + Vector3.UP * 0.035, Vector3(0.18, 0.11, 0.17), Color("#303c27"))
	return tool.commit()

static func snag() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color("#3e2c25")
	_tube(tool, [Vector3(-0.6, 0, 0.17), Vector3(-0.22, 0.19, 0.09),
		Vector3(0.16, 0.23, -0.08), Vector3(0.52, 0.085, -0.25)],
		[0.022, 0.090, 0.103, 0.024], bark)
	_tube(tool, [Vector3(-0.17, 0.15, 0.1), Vector3(-0.07, 0.49, 0.03), Vector3(-0.24, 0.64, 0.04)],
		[0.084, 0.043, 0.002], bark)
	_tube(tool, [Vector3(0.11, 0.22, -0.06), Vector3(0.30, 0.34, -0.19), Vector3(0.41, 0.51, -0.22)],
		[0.056, 0.031, 0.002], Color("#664634"))
	return tool.commit()

static func _tube(tool: SurfaceTool, points: Array, radii: Array, color: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	for i in points.size():
		var at: Vector3 = points[i]
		var axis: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var right := axis.cross(Vector3.FORWARD).normalized() if absf(axis.z) < 0.91 else axis.cross(Vector3.RIGHT).normalized()
		var across := axis.cross(right).normalized()
		var ring := PackedVector3Array()
		for j in SAMPLES:
			var angle := TAU * j / SAMPLES
			ring.append(at + (right * cos(angle) + across * sin(angle)) * float(radii[i]))
		rings.append(ring)
	for i in range(rings.size() - 1):
		for j in SAMPLES:
			var k := (j + 1) % SAMPLES
			var a := rings[i][j]
			var b := rings[i][k]
			var c := rings[i + 1][k]
			var d := rings[i + 1][j]
			var shade := color.lerp(Color("#9c734b"), 0.05 + 0.065 * float((j * 5) % 4))
			_face(tool, a, b, c, shade)
			_face(tool, a, c, d, shade)

static func _crown(tool: SurfaceTool, random: RandomNumberGenerator, at: Vector3, size: Vector3, color: Color) -> void:
	var shoulder := PackedVector3Array()
	var skirt := PackedVector3Array()
	var top := at + Vector3(0.12, 0.95, -0.13) * size
	var bottom := at - Vector3.UP * size.y * 0.65
	for i in CROWN_SAMPLES:
		var angle := TAU * i / CROWN_SAMPLES
		var radial := Vector3(cos(angle), 0.0, sin(angle)) * size
		shoulder.append(at + radial * random.randf_range(0.51, 0.84)
			+ Vector3.UP * size.y * random.randf_range(0.27, 0.61))
		skirt.append(at + radial * random.randf_range(0.74, 1.14)
			- Vector3.UP * size.y * random.randf_range(0.05, 0.38))
	for i in CROWN_SAMPLES:
		var next := (i + 1) % CROWN_SAMPLES
		var varied := color.lerp(Color("#657050"), random.randf_range(0.02, 0.16))
		_face(tool, top, shoulder[i], shoulder[next], varied)
		_face(tool, shoulder[i], skirt[i], shoulder[next], varied.darkened(0.08))
		_face(tool, shoulder[next], skirt[i], skirt[next], varied.darkened(0.13))
		_face(tool, bottom, skirt[next], skirt[i], varied.darkened(0.26))

static func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for at in [a, b, c]:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(at)
