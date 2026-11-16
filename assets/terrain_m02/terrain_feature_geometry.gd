extends RefCounted
## Ground-plane queries in world units. Negative distance is inside.

const SOLID_COVER := &"solid_cover"
const LOW_RUBBLE := &"low_rubble"
const TRACE_EPSILON := 0.00001

static func disk(id: String, kind: String, at: Vector2, radius: float) -> Dictionary:
	return {"id": id, "kind": kind, "center": at, "radius": radius,
		"bounds": Rect2(at - Vector2.ONE * radius, Vector2.ONE * (2.0 * radius))}

static func shape(id: String, kind: String, points: PackedVector2Array) -> Dictionary:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return {"id": id, "kind": kind, "outline": points, "bounds": bounds}

static func ribbon(id: String, kind: String, spine: PackedVector2Array, widths: PackedFloat32Array) -> Dictionary:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in spine.size():
		var tangent := (spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var offset := tangent.orthogonal() * widths[i]
		left.append(spine[i] + offset)
		right.append(spine[i] - offset)
	right.reverse()
	left.append_array(right)
	var result := shape(id, kind, left)
	result["spine"] = spine
	result["half_widths"] = widths
	return result

static func contains(feature: Dictionary, point: Vector2) -> bool:
	return signed_distance(feature, point) <= 0.0

static func boundary(feature: Dictionary) -> PackedVector2Array:
	if feature.has("outline"):
		return feature.outline
	var points := PackedVector2Array()
	for i in 24:
		points.append(feature.center + Vector2.from_angle(TAU * i / 24.0) * feature.radius)
	return points

static func signed_distance(feature: Dictionary, point: Vector2, limit: float = INF) -> float:
	if feature.has("radius"):
		return point.distance_to(feature.center) - feature.radius
	var bounds: Rect2 = feature.bounds
	if limit != INF and not bounds.grow(limit).has_point(point):
		return limit
	var distance := polygon_distance(feature.outline, point, limit)
	for hole in feature.get("holes", []):
		distance = maxf(distance, -polygon_distance(hole, point, limit))
	return distance

static func polygon_distance(points: PackedVector2Array, point: Vector2, limit: float = INF) -> float:
	var inside := false
	var nearest := limit * limit
	var previous := points[points.size() - 1]
	for current in points:
		var direction := current - previous
		var offset := point - previous
		var t := clampf(offset.dot(direction) / maxf(direction.length_squared(), 0.000001), 0.0, 1.0)
		nearest = minf(nearest, (offset - direction * t).length_squared())
		if (previous.y > point.y) != (current.y > point.y):
			var cross_x := previous.x + direction.x * (point.y - previous.y) / direction.y
			if point.x < cross_x:
				inside = not inside
		previous = current
	return sqrt(nearest) * (-1.0 if inside else 1.0)

# Earliest normalized contact on a closed segment. INF means no contact.
static func circle_entry(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var offset := from - center
	var squared_radius := radius * radius
	if offset.length_squared() <= squared_radius:
		return 0.0
	var motion := to - from
	var length := motion.length_squared()
	var approach := offset.dot(motion)
	if length == 0.0 or approach >= 0.0:
		return INF
	var lateral := offset.cross(motion)
	var discriminant := length * squared_radius - lateral * lateral
	if discriminant < 0.0:
		return INF
	var fraction := (-approach - sqrt(discriminant)) / length
	return clampf(fraction, 0.0, 1.0) if fraction <= 1.0 + TRACE_EPSILON else INF

static func edge_entry(from: Vector2, to: Vector2, start: Vector2, end: Vector2, radius: float) -> float:
	var edge := end - start
	var length := edge.length()
	if length <= TRACE_EPSILON:
		return circle_entry(from, to, start, radius)
	var axis := edge / length
	var normal := axis.orthogonal()
	var offset := from - start
	var cross := offset.dot(normal)
	var along := offset.dot(axis)
	# The swept circle first reaches either the edge strip or an end cap.
	if absf(cross) <= radius:
		if along >= 0.0 and along <= length:
			return 0.0
	else:
		var motion := to - from
		var transverse := motion.dot(normal)
		if cross * transverse < 0.0:
			var fraction := (signf(cross) * radius - cross) / transverse
			var foot := along + motion.dot(axis) * fraction
			if fraction <= 1.0 + TRACE_EPSILON and foot >= 0.0 and foot <= length:
				return minf(1.0, fraction)
	return minf(circle_entry(from, to, start, radius), circle_entry(from, to, end, radius))

static func outline_entry(points: PackedVector2Array, from: Vector2, to: Vector2, radius: float) -> float:
	var bounds := Rect2(from.min(to), (to - from).abs()).grow(radius + TRACE_EPSILON)
	var first := INF
	var previous := points[-1]
	for point in points:
		if bounds.intersects(Rect2(previous.min(point), (point - previous).abs()), true):
			first = minf(first, edge_entry(from, to, previous, point, radius))
		previous = point
	return first

static func cover_entry(feature: Dictionary, from: Vector2, to: Vector2, radius: float) -> float:
	if feature.has("radius"):
		return circle_entry(from, to, feature.center, float(feature.radius) + radius)
	if contains(feature, from):
		return 0.0
	var first := outline_entry(feature.outline, from, to, radius)
	for hole in feature.get("holes", []):
		first = minf(first, outline_entry(hole, from, to, radius))
	return first

static func in_trails(layout: Dictionary, point: Vector2, margin: float = 0.0) -> bool:
	return in_any(layout.paths, point, margin) or in_any(layout.get("path_joins", []), point, margin)

static func in_any(features: Array, point: Vector2, margin: float = 0.0) -> bool:
	for feature in features:
		var bounds: Rect2 = feature.bounds
		if bounds.grow(margin + 0.001).has_point(point) and signed_distance(feature, point) <= margin:
			return true
	return false
