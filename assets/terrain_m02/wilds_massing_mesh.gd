extends RefCounted
## Three continuously connected, tapered barriers use the same width profiles as their footprints.

const Bark = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const Art = preload("res://assets/terrain_m02/terrain_art_direction.gd")

static func mesh(formation: Dictionary, seed_value: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var family: int = formation.family
	var profile := Art.profile(family + 1)
	var body := Color("#3a2e22") if family == 0 else Color("#343c2d") if family == 1 else Color("#302821")
	var crest := Color("#4c5d37") if family == 0 else Color("#53694a") if family == 1 else Color("#6c5440")
	var phase := float((str(formation.id) + str(seed_value)).hash() % 111) / 11.0
	var spine: PackedVector2Array = formation.spine
	# Keep every visible projection inside the authored footprint, including
	# the broad buttress tips where the centerline changes direction.
	var footprint: PackedVector2Array = formation.outline
	var rings: Array[PackedVector3Array] = []
	for i in spine.size():
		var at := spine[i]
		var tangent := (spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var across := tangent.orthogonal()
		var width: float = formation.half_widths[i]
		var t := float(i) / (spine.size() - 1)
		var elevation := (0.68 + 0.28 * sin(t * 9.4 + phase) + 0.10 * sin(i * 1.4)) * width
		elevation *= 2.4 if family == 2 else 0.95 if family == 1 else 0.76
		var ring := PackedVector3Array()
		for profile_point in [Vector2(-1.0, -0.12), Vector2(-0.80, 0.35),
				Vector2(-0.42, 0.84), Vector2(-0.07, 1.0), Vector2(0.32, 0.91),
				Vector2(0.69, 0.57), Vector2(1.0, -0.12)]:
			var point: Vector2 = at + across * profile_point.x * width
			ring.append(Vector3(point.x, profile_point.y * elevation, point.y))
		rings.append(ring)
		if (family == 2 and i % 5 == 2 or family != 2 and i % 4 == 2) and i + 2 < spine.size():
			_fork(tool, at, tangent, width, elevation, family, profile, phase + i)
	for i in range(rings.size() - 1):
		for j in 6:
			var tone := body.lerp(crest, 0.72 if j in [2, 3, 4] else 0.13)
			tone = tone.lerp(profile.bark, 0.08 + 0.18 * sin(i * 1.4 + j))
			Bark._face(tool, rings[i][j], rings[i + 1][j], rings[i][j + 1], tone)
			Bark._face(tool, rings[i][j + 1], rings[i + 1][j], rings[i + 1][j + 1], tone)
	if family == 2:
		_thick_roots(tool, formation, phase)
	elif family == 1:
		_deadfall(tool, formation, phase, profile.bark)
	for end in [0, rings.size() - 1]:
		# A transverse cap joins the submerged edges at each intentional opening.
		var ring := rings[end]
		for i in range(1, ring.size() - 1):
			Bark._face(tool, ring[0], ring[i], ring[i + 1], body)
	var data := tool.commit_to_arrays()
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var point := Vector2(vertices[i].x, vertices[i].z)
		if Geometry2D.is_point_in_polygon(point, footprint):
			continue
		var nearest := point
		var distance := INF
		for j in footprint.size():
			var edge := Geometry2D.get_closest_point_to_segment(point, footprint[j], footprint[(j + 1) % footprint.size()])
			var d := point.distance_squared_to(edge)
			if d < distance:
				distance = d
				nearest = edge
		vertices[i] = Vector3(nearest.x, vertices[i].y, nearest.y)
	data[Mesh.ARRAY_VERTEX] = vertices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return result

static func _deadfall(tool: SurfaceTool, formation: Dictionary, phase: float, bark: Color) -> void:
	var spine: PackedVector2Array = formation.spine
	for i in range(2, spine.size() - 3, 5):
		var span := (spine[i + 3] - spine[i - 1]).normalized()
		var across := span.orthogonal() * (0.40 if sin(phase + i) > 0.0 else -0.40)
		var start := spine[i - 1] + across
		var center := spine[i]
		var tip := spine[i + 3] - across
		Bark._tube(tool, [Vector3(start.x, 0.24, start.y), Vector3(center.x, 0.61, center.y),
			Vector3(tip.x, 0.32, tip.y)], [0.23, 0.27, 0.13], bark.lerp(Color("#6a5942"), 0.58))

static func _thick_roots(tool: SurfaceTool, formation: Dictionary, phase: float) -> void:
	var spine: PackedVector2Array = formation.spine
	for strand in 3:
		var path := []
		var widths := []
		for i in range(1, spine.size() - 1):
			var tangent := (spine[i + 1] - spine[i - 1]).normalized()
			var width: float = formation.half_widths[i]
			var t := float(i) / (spine.size() - 1)
			var drift := sin(t * TAU * 0.83 + strand * 2.1 + phase)
			var at := spine[i] + tangent.orthogonal() * width * drift * 0.52
			var rise := (0.68 + 0.28 * sin(t * 9.4 + phase) + 0.10 * sin(i * 1.4)) * width * 2.4
			path.append(Vector3(at.x, rise * (0.53 + 0.55 * pow(absf(drift), 0.7)), at.y))
			widths.append(width * (0.15 + 0.14 * sin(t * PI)))
		if path.size() >= 2:
			Bark._tube(tool, path, widths, [Color("#443024"), Color("#644c37"), Color("#76604a")][strand])

static func gate() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Color("#4d3b2d")
	var trace := Color("#b19856")
	for side in [-1.0, 1.0]:
		var points := [Vector3(side * 1.22, -0.06, 0.3), Vector3(side * 1.04, 0.69, 0.0),
			Vector3(side * 0.70, 1.63, -0.03), Vector3(side * 0.36, 2.0, 0.06),
			Vector3(-side * 0.07, 2.10, 0.02)]
		Bark._tube(tool, points, [0.33, 0.26, 0.19, 0.21, 0.07], root)
		Bark._tube(tool, [Vector3(side * 1.00, 0.22, 0.24), Vector3(side * 0.86, 1.20, 0.18),
			Vector3(side * 0.53, 1.79, 0.19), Vector3(side * 0.12, 2.03, 0.17)],
			[0.027, 0.041, 0.048, 0.013], trace)
	return tool.commit()

static func _fork(tool: SurfaceTool, at: Vector2, tangent: Vector2, width: float, elevation: float,
		family: int, profile: Dictionary, phase: float) -> void:
	var p := Vector3(at.x, elevation * 0.49, at.y)
	var forward := Vector3(tangent.x, 0.0, tangent.y)
	var across := Vector3(-tangent.y, 0.0, tangent.x)
	var sign_value := 1.0 if sin(phase) > 0.0 else -1.0
	if family == 2:
		var spine := p + Vector3.UP * (1.45 + sin(phase) * 0.54) * width
		var shoulder := p + across * width * 0.39 * sign_value + Vector3.UP * elevation * 0.62
		Bark._tube(tool, [p - Vector3.UP * 0.31, shoulder, spine, spine + forward * width * 0.52 + Vector3.UP * 0.42],
			[width * 0.36, width * 0.34, width * 0.22, 0.05], Color("#5d4636"))
		Bark._tube(tool, [spine, shoulder - across * 0.50 * sign_value + forward * 0.37, p + across * width * 0.6 + forward * width * 0.9],
			[width * 0.16, width * 0.20, 0.05], Color("#785c45"))
	else:
		var end := p + across * sign_value * width * 0.64 + forward * width * 0.51 - Vector3.UP * p.y
		Bark._tube(tool, [p - forward * 0.72, p + Vector3.UP * width * 0.33, end],
			[width * 0.24, width * 0.22, 0.035], profile.bark.lerp(profile.edge, 0.28))
