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

static func reclaiming_root(spine: PackedVector2Array, count: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 0.29
	for strand in 2:
		var points: Array = []
		var widths: Array = []
		for i in count:
			var at := spine[i]
			var t := float(i) / (spine.size() - 1)
			var axis := (spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
			var drift := (1.0 - t) * sin(float(i) * 0.44 + strand * PI)
			at += axis.orthogonal() * drift * 0.15
			points.append(Vector3(at.x, -0.065 + (1.0 - t) * 0.17 * sin(0.77 * i + strand), at.y))
			var radius := width * (1.02 + 0.19 * sin(i * 0.59)) * (1.0 - 0.92 * t)
			widths.append(radius if i < count - 1 else 0.006)
		_tube(tool, points, widths, Color("#422c23") if strand == 0 else Color("#513326"))
		width *= 0.68
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

static func _crown(tool: SurfaceTool, random: RandomNumberGenerator, at: Vector3, size: Vector3, color: Color,
		samples: int = CROWN_SAMPLES) -> void:
	var shoulder := PackedVector3Array()
	var skirt := PackedVector3Array()
	var top := at + Vector3(0.12, 0.95, -0.13) * size
	var bottom := at - Vector3.UP * size.y * 0.65
	for i in samples:
		var angle := TAU * i / samples
		var radial := Vector3(cos(angle), 0.0, sin(angle)) * size
		shoulder.append(at + radial * random.randf_range(0.51, 0.84)
			+ Vector3.UP * size.y * random.randf_range(0.27, 0.61))
		skirt.append(at + radial * random.randf_range(0.74, 1.14)
			- Vector3.UP * size.y * random.randf_range(0.05, 0.38))
	for i in samples:
		var next := (i + 1) % samples
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


## M06 botanical forms share the bent stems and tapered roots of the enclosure.
static func botanical(variant: int, form: String, profile: Dictionary, biome: int, scenic: bool = false) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 9043 + variant * 761
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark: Color = profile.bark
	var edge: Color = profile.edge
	var foliage: Color = profile.leaf
	var light: Color = profile.tip
	var boundary := form == "canopy"
	var heart := form == "heart"
	var juvenile := form == "sapling"
	var spread := (1.08 if boundary else 0.80) * float([1.0, 0.96, 1.19, 0.79][biome]) * (1.12 if heart else 1.0)
	var trunk := 0.104 if boundary or heart else 0.081 if not juvenile else 0.052
	var lean := _heading(variant * 2.1 + 0.8)
	var lower := lean * 0.035 + Vector3.UP * 0.21
	var fork := -lean * 0.027 + Vector3.UP * 0.52
	var tip := lean * random.randf_range(0.06, 0.17) + Vector3.UP * 0.91
	_tube(tool, [Vector3.ZERO, lower, fork, tip], [trunk, trunk * 0.74, trunk * 0.42, 0.004], bark)
	var root_count := 4 if juvenile or scenic else 6
	var crown_samples := 5 if scenic else CROWN_SAMPLES
	for i in root_count:
		var heading := _heading(i * TAU / root_count + random.randf_range(-0.25, 0.25))
		var reach := random.randf_range(0.19, 0.33) * spread
		var knee := heading * reach * 0.45 + Vector3.UP * 0.04
		_tube(tool, [lower * 0.48, knee, heading * reach], [trunk * 0.56, trunk * 0.31, 0.002], bark.lerp(edge, 0.13))
	for i in (4 if juvenile else 5 if scenic else 8 if heart else 7):
		var bearing := i * 2.39996 + variant * 0.55
		var heading := _heading(bearing)
		var elevation := 0.46 + (i % 4) * 0.105
		var length := random.randf_range(0.18, 0.30) * spread * (1.0 - 0.22 * elevation)
		var start := lower.lerp(fork, elevation)
		var elbow := start + heading * length * 0.53 + Vector3.UP * 0.16
		var end := heading * length + Vector3.UP * (elevation + 0.11) + lean * 0.048
		_tube(tool, [start, elbow, end], [trunk * 0.39, trunk * 0.17, 0.002], bark.lerp(edge, 0.11))
		var color := foliage.lerp(light, random.randf_range(0.09, 0.56))
		var radius := (0.18 if boundary or heart else 0.145 if not juvenile else 0.10) * spread
		_crown(tool, random, end, Vector3(radius * 1.28, radius * 0.51, radius), color, crown_samples)
		if not scenic:
			_leaf_spray(tool, end + Vector3.UP * 0.017, bearing, radius * 1.10, color, light)
		for j in (0 if scenic else 2 if boundary or heart else 1):
			var drift := _heading(bearing + 0.9 + j * 2.4) * radius * 0.80
			_crown(tool, random, end + drift * 0.8 + Vector3.UP * 0.047,
				Vector3(radius * 0.65, radius * 0.35, radius * 0.61), color.lightened(0.07))
	_crown(tool, random, tip, Vector3(0.12, 0.064, 0.14) * spread, foliage.lerp(light, 0.43), crown_samples)
	return tool.commit()

static func understory(kind: String, variant: int, profile: Dictionary) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foliage: Color = profile.leaf
	var light: Color = profile.tip
	if kind == "wine_fern":
		foliage = Color("#412733")
		light = profile.accent
	var stems := 5 if kind == "grass" else 7
	for i in stems:
		var angle := i * 2.39996 + 0.77 * variant
		var reach := 0.43 + 0.10 * sin(float(i * 3 + variant))
		var stem := _heading(angle)
		var knee := stem * reach * 0.35 + Vector3.UP * (0.49 + 0.17 * sin(i * 2.3))
		var top := stem * reach + Vector3.UP * (0.75 + 0.18 * cos(i * 2.3))
		var green := foliage.lerp(light, 0.22 + (i % 4) * 0.145)
		if kind == "grass":
			_leaf(tool, knee * 0.17, top, 0.060, green)
		else:
			_tube(tool, [Vector3.ZERO, knee, top], [0.025, 0.017, 0.001], green)
			if kind in ["fern", "wine_fern"]:
				_leaf_spray(tool, knee, angle, reach * 1.62, green, light)
			else:
				_leaf(tool, knee * 0.78, top, 0.12, green)
				_leaf(tool, knee, knee + _heading(angle + 1.2) * 0.30 + Vector3.UP * 0.17, 0.11, green.lightened(0.1))
				_leaf(tool, knee, knee + _heading(angle - 1.2) * 0.27, 0.092, green)
	return tool.commit()

static func _leaf_spray(tool: SurfaceTool, at: Vector3, angle: float, radius: float, color: Color, tip: Color) -> void:
	var heading := _heading(angle)
	for i in 4:
		var root := at + heading * (radius * i * 0.20)
		for side in [-1.0, 1.0]:
			var end := root + _heading(angle + side * (1.05 - i * 0.13)) * radius * (0.76 - i * 0.11)
			end.y += radius * (0.38 - i * 0.073)
			_leaf(tool, root, end, radius * 0.16, color.lerp(tip, 0.10 + 0.15 * i))

static func _heading(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))

static func _leaf(tool: SurfaceTool, start: Vector3, tip: Vector3, width: float, color: Color) -> void:
	var side := (tip - start).cross(Vector3.UP).normalized() * width
	var middle := start.lerp(tip, 0.48)
	var raised := middle + Vector3.UP * width * 0.32
	_face(tool, start, raised, middle - side, color.darkened(0.2))
	_face(tool, raised, tip, middle - side, color.darkened(0.13))
	_face(tool, start, middle + side, raised, color)
	_face(tool, raised, middle + side, tip, color.lightened(0.08))

static func basalt(variant: int, profile: Dictionary) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 347 + variant * 47
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color: Color = profile.stone
	var top := PackedVector3Array()
	var foot := PackedVector3Array()
	for i in SAMPLES:
		var direction := _heading(TAU * i / SAMPLES)
		var edge := random.randf_range(0.80, 1.02)
		foot.append(direction * edge)
		top.append(direction * (edge * 0.61) + Vector3(0.16, random.randf_range(0.35, 0.95), -0.08))
	for i in SAMPLES:
		var j := (i + 1) % SAMPLES
		var tone := color.lerp(Color("#92897a"), random.randf_range(0.09, 0.28))
		_face(tool, foot[i], foot[j], top[j], tone.darkened(0.16))
		_face(tool, foot[i], top[j], top[i], tone)
		_face(tool, top[i], top[j], Vector3(0.15, 0.84, -0.1), tone.lightened(0.08))
	return tool.commit()
