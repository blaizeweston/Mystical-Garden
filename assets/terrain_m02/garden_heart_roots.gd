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

static func plan(path: PackedVector2Array, stage: int, garden, network: Array[Dictionary] = [], structure_link := false, footprints: Array = []) -> Dictionary:
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
	# Frontier roots duck beneath access reservations. Links to buildings stay visible
	# over walkable ground and pass underground at the water's edge.
	var exclusions: Array = garden.layout.water if structure_link else garden.root_exclusions + garden.occupied + garden.layout.water + garden.construction_clearance
	if structure_link:
		meet.y = 0.10
	var points: Array[Vector3] = [start]
	for i in range(1, 13):
		var t := i / 12.0
		var at := start.bezier_interpolate(handle, meet - Vector3(arrival.x, 0, arrival.y) * 0.72, meet, t)
		points.append(_bury(at, exclusions, root_radius * lerpf(1.20, 0.64, t), footprints))
	for i in range(junction + 1, path.size()):
		var t := float(i) / (path.size() - 1)
		var depth := -0.045 + 0.15 * sin(i * 0.71) - 0.24 * pow(maxf(0, sin(i * 0.32)), 5)
		var point := Vector3(path[i].x, depth if t < 0.97 else -0.03, path[i].y)
		if structure_link:
			point.y = lerpf(0.12 + 0.06 * sin(i * 0.71), 0.015, smoothstep(0.82, 1.0, t))
			point = _bury(point, exclusions, root_radius, footprints)
		points.append(point)
	var flow_start := start.length()
	var connection := _connection(points, socket, network)
	if not connection.is_empty():
		var parent: Dictionary = network[connection.parent]
		socket = parent.socket
		var inherited: Array[Vector3] = parent.main
		var index: int = connection.index
		var resume: int = connection.resume
		flow_start = parent.get("flow_start",0.0) + _arc_length(inherited,index)
		var from := inherited[index]
		var to := points[resume]
		var heading := (inherited[index] - inherited[index - 1]).normalized()
		var arrival_tangent := (points[resume + 1] - to).normalized()
		var lead := clampf(from.distance_to(to) * 0.34, 0.20, 0.95)
		var taper := pow(1.0 - float(index) / (inherited.size() - 1), 0.86)
		root_radius = clampf(parent.radius * taper * 0.78, 0.055, root_radius * 0.74)
		var splice: Array[Vector3] = [from]
		var steps := maxi(9, ceili(from.distance_to(to) / 0.25))
		for sample in range(1, steps):
			var at := from.bezier_interpolate(from + heading * lead, to - arrival_tangent * lead, to, float(sample) / steps)
			splice.append(_bury(at, exclusions, root_radius, footprints))
		splice.append_array(points.slice(resume))
		points = splice
		junction = 3
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
			branch.append(_bury(at, exclusions, 0.16, footprints))
		var fork: Array[Vector3] = [branch[3]]
		for j in range(1, 5):
			var at := branch[3] + tangent * (0.21 * j) + side * (0.10 * j)
			at.y -= 0.034 * j
			fork.append(_bury(at, exclusions, 0.12, footprints))
		branches.append({"points": branch, "join": i, "flow_start": flow_start + _arc_length(points,i), "radius": root_radius * 0.33})
		branches.append({"points": fork, "join": i + 4, "flow_start": flow_start + _arc_length(points,i) + _arc_length(branch,3), "radius": root_radius * 0.15})
	return {"socket": socket, "main": points, "branches": branches, "radius": root_radius,
		"connection": connection, "flow_start": flow_start}

static func _arc_length(path: Array[Vector3], end: int) -> float:
	var distance := 0.0
	for i in range(1,end+1): distance += path[i-1].distance_to(path[i])
	return distance

static func _connection(incoming: Array[Vector3], socket: int, network: Array[Dictionary]) -> Dictionary:
	var result := {}
	var best := -INF
	var aim := Vector2(incoming[-1].x, incoming[-1].z).normalized()
	var search_bounds := Rect2(Vector2(incoming[5].x, incoming[5].z), Vector2.ZERO)
	for resume in range(6, incoming.size() - 2):
		search_bounds = search_bounds.expand(Vector2(incoming[resume].x, incoming[resume].z))
	search_bounds = search_bounds.grow(2.66)
	for parent_index in network.size():
		var root := network[parent_index]
		var path: Array[Vector3] = root.main
		for i in range(2, path.size() - 1):
			var at := path[i]
			var along := Vector2(at.x, at.z)
			if not search_bounds.has_point(along) or along.dot(aim) < 1.35:
				continue
			var segment := Vector2(at.x - path[i - 1].x, at.z - path[i - 1].z).normalized()
			var along_score := along.length() * 0.19
			for resume in range(5, incoming.size() - 2):
				var to := incoming[resume]
				var forward := Vector2(to.x, to.z) - along
				var distance_sq := forward.length_squared()
				# Join near the point where routes diverge, keeping only the new branch.
				if distance_sq < 0.48 * 0.48 or distance_sq > 2.65 * 2.65:
					continue
				if forward.dot(aim) < 0.15:
					continue
				var distance := sqrt(distance_sq)
				if forward.dot(segment) > 0.94 * distance and i < path.size() - 4:
					continue
				var score := resume * 0.24 + along_score - absf(distance - 1.25)
				if score > best:
					best = score
					result = {"parent": parent_index, "index": i, "resume": resume}
	if not result.is_empty():
		return result
	# The same buttress is already represented. Branch near its base even
	# when the two routes peel away too quickly to share a longer run.
	for parent_index in network.size():
		var root := network[parent_index]
		if root.socket == socket:
			return {"parent": parent_index, "index": 2, "resume": 6}
	return {}

static func _bury(at: Vector3, exclusions: Array, width: float, footprints: Array) -> Vector3:
	var ground := Vector2(at.x, at.z)
	var separation := width + 0.68
	for feature: Dictionary in exclusions:
		if (feature.bounds as Rect2).grow(width + 0.68).has_point(ground):
			separation = minf(separation, Shape.signed_distance(feature, ground))
	var blend := smoothstep(width * 0.75, width + 0.61, separation)
	# Let wood reach the visible edge before sinking into a bed or station.
	for footprint: Dictionary in footprints:
		if (footprint.bounds as Rect2).has_point(ground):
			var inside := Shape.signed_distance(footprint, ground)
			blend = minf(blend, smoothstep(-0.38, -0.06, inside))
	at.y = lerpf(minf(at.y, -width * 1.43), at.y, blend)
	return at

static func mesh(root_plan: Dictionary) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	append_root(tool, root_plan)
	return tool.commit()

## The growth shader reads longitudinal bark UVs and per-vertex reveal progress.
static func append_root(tool: SurfaceTool, root_plan: Dictionary, first_vertex := 0) -> int:
	var main: Array[Vector3] = root_plan.main
	var next := _sweep(tool, main, root_plan.radius, 0.0, 0.89, 15, first_vertex, root_plan.get("flow_start",0.0))
	for branch: Dictionary in root_plan.branches:
		var start: float = branch.join * 0.89 / (main.size() - 1)
		next = _sweep(tool, branch.points, branch.radius, start, minf(start + 0.095, 1.0), 8, next, branch.get("flow_start",0.0))
	return next

static func _sweep(tool: SurfaceTool, path: Array[Vector3], width: float, from: float, to: float, sides: int, first_vertex: int, flow_start: float) -> int:
	var length := 0.0
	var stride := sides + 1 # The bark UV wraps at this seam.
	for i in path.size():
		if i > 0:
			length += path[i].distance_to(path[i - 1])
		var t := float(i) / (path.size() - 1)
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(0, i - 1)]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var up := side.cross(tangent).normalized()
		var taper := width * maxf(0.025, pow(1.0 - t, 0.86))
		for j in stride:
			var around := float(j) / sides
			var angle := TAU * (j % sides) / sides
			var rib := 1.0 + 0.14 * cos(angle * 5.0 + t * 8.0) + 0.06 * sin(angle * 7.0 - t * 5.0)
			var radial := side * cos(angle) + up * sin(angle) * 0.76
			var shade := 0.26 + 0.17 * sin(around * TAU * 5.0 + length * 0.9)
			var pigment := Color("#382923").lerp(Color("#77543e"), shade).srgb_to_linear()
			pigment.a = lerpf(from, to, t)
			tool.set_color(pigment)
			tool.set_uv(Vector2(around, length))
			tool.set_uv2(Vector2(flow_start+length,0.0))
			tool.set_normal(radial.normalized())
			tool.add_vertex(path[i] + radial * taper * rib)
			if i > 0 and j < sides:
				var prev := first_vertex + (i - 1) * stride + j
				tool.add_index(prev)
				tool.add_index(prev + 1)
				tool.add_index(prev + stride + 1)
				tool.add_index(prev)
				tool.add_index(prev + stride + 1)
				tool.add_index(prev + stride)
	return first_vertex + path.size() * stride
