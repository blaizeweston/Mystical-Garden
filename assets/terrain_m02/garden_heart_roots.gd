extends RefCounted
## Sockets are the third and fourth controls of the authored M06C buttresses,
## in Godot's X/Y/Z axes. The authored stage multiplier applies to X and Z.

const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const SOCKETS := [
	[Vector3(-1.69, 0.22, 0.98), Vector3(-2.12, 0.10, 1.55), 0.35],
	[Vector3(1.37, 0.16, 1.28), Vector3(1.78, 0.09, 1.72), 0.34],
	[Vector3(1.83, 0.16, -0.35), Vector3(2.30, 0.10, -0.89), 0.32],
	[Vector3(-1.84, 0.14, -0.40), Vector3(-2.34, 0.02, -0.77), 0.28],
	[Vector3(-1.04, 0.11, -1.89), Vector3(-1.64, 0.04, -2.02), 0.23],
	[Vector3(0.36, 0.12, -1.89), Vector3(0.61, -0.10, -2.57), 0.21],
]

static func plan(path: PackedVector2Array, stage: int, garden) -> Dictionary:
	var aim := path[mini(11, path.size() - 1)].normalized()
	var socket := 0
	var alignment := -INF
	for i in SOCKETS.size():
		var base: Vector3 = SOCKETS[i][0]
		var score := Vector2(base.x, base.z).normalized().dot(aim)
		if score > alignment:
			socket = i
			alignment = score
	var size := 0.77 + stage * 0.112
	var radial := Vector3(size, 1.0, size)
	var socket_origin: Vector3 = SOCKETS[socket][0] * radial
	var handle: Vector3 = SOCKETS[socket][1] * radial
	var start := socket_origin.lerp(handle, 0.30)
	var root_radius: float = SOCKETS[socket][2] * (0.91 + stage * 0.07)
	var junction := mini(path.size() - 3, 10 + stage)
	var meet := Vector3(path[junction].x, -0.04, path[junction].y)
	var arrival := (path[junction + 1] - path[junction]).normalized()
	var points: Array[Vector3] = [start]
	for i in range(1, 13):
		var t := i / 12.0
		var at := start.bezier_interpolate(handle, meet - Vector3(arrival.x, 0, arrival.y) * 0.72, meet, t)
		points.append(_bury(at, garden, root_radius * lerpf(1.20, 0.64, t)))
	for i in range(junction + 1, path.size()):
		var t := float(i) / (path.size() - 1)
		var depth := -0.045 + 0.15 * sin(i * 0.71) - 0.24 * pow(maxf(0, sin(i * 0.32)), 5)
		points.append(Vector3(path[i].x, depth if t < 0.97 else -0.03, path[i].y))
	var branches: Array = []
	for i in range(junction + 6, points.size() - 5, 8):
		var origin := points[i]
		var tangent := (points[i + 1] - origin).normalized()
		var side := Vector3(-tangent.z, 0, tangent.x) * (-1.0 if i % 3 == 0 else 1.0)
		var branch: Array[Vector3] = [origin]
		for j in range(1, 7):
			var t := j / 6.0
			var at := origin + tangent * (0.86 * t) + side * (t * t * (0.68 + stage * 0.11))
			at.y = lerpf(origin.y, -0.15, t) + 0.12 * sin(t * PI)
			branch.append(_bury(at, garden, 0.16))
		var fork: Array[Vector3] = [branch[3]]
		for j in range(1, 5):
			var at := branch[3] + tangent * (0.21 * j) + side * (0.10 * j)
			at.y -= 0.034 * j
			fork.append(_bury(at, garden, 0.12))
		branches.append({"points": branch, "join": i, "radius": root_radius * 0.33})
		branches.append({"points": fork, "join": i + 4, "radius": root_radius * 0.15})
	return {"socket": socket, "main": points, "branches": branches, "radius": root_radius}

static func _bury(at: Vector3, garden, width: float) -> Vector3:
	var ground := Vector2(at.x, at.z)
	var separation := width + 0.68
	for feature: Dictionary in garden.root_exclusions + garden.occupied + garden.layout.water:
		if (feature.bounds as Rect2).grow(width + 0.68).has_point(ground):
			separation = minf(separation, Shape.signed_distance(feature, ground))
	var blend := smoothstep(width * 0.75, width + 0.61, separation)
	at.y = lerpf(minf(at.y, -width * 1.43), at.y, blend)
	return at

static func mesh(plan: Dictionary) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	var main: Array[Vector3] = plan.main
	_sweep(tool, main, plan.radius, 0.0, 0.89, 15)
	for branch: Dictionary in plan.branches:
		var start: float = branch.join * 0.89 / (main.size() - 1)
		_sweep(tool, branch.points, branch.radius, start, minf(start + 0.095, 1.0), 8)
	return tool.commit()

static func _sweep(tool: SurfaceTool, path: Array[Vector3], width: float, from: float, to: float, sides: int) -> void:
	var length := 0.0
	var grain := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
		grain.append(length)
	var rings: Array[PackedVector3Array] = []
	for i in path.size():
		var t := float(i) / (path.size() - 1)
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(0, i - 1)]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var up := side.cross(tangent).normalized()
		var ring := PackedVector3Array()
		for j in sides:
			var angle := TAU * j / sides
			var rib := 1.0 + 0.14 * cos(angle * 5.0 + t * 8.0) + 0.06 * sin(angle * 7.0 - t * 5.0)
			var radius := width * maxf(0.025, pow(1.0 - t, 0.86)) * rib
			ring.append(path[i] + (side * cos(angle) + up * sin(angle) * 0.76) * radius)
		rings.append(ring)
	for i in path.size() - 1:
		for j in sides:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var row := i + corner.y
				var around := float(j + corner.x) / sides
				var shade := 0.26 + 0.17 * sin(around * TAU * 5.0 + grain[row] * 0.9)
				var pigment := Color("#382923").lerp(Color("#77543e"), shade).srgb_to_linear()
				pigment.a = lerpf(from, to, float(row) / (path.size() - 1))
				tool.set_color(pigment)
				tool.set_uv(Vector2(around, grain[row]))
				var vertex := rings[row][(j + corner.x) % sides]
				tool.set_normal((vertex - path[row]).normalized())
				tool.add_vertex(vertex)
