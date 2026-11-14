extends RefCounted
## Ground-plane queries in world units. Negative distance is inside.

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

static func in_trails(layout: Dictionary, point: Vector2, margin: float = 0.0) -> bool:
	return in_any(layout.paths, point, margin) or in_any(layout.get("path_joins", []), point, margin)

static func in_any(features: Array, point: Vector2, margin: float = 0.0) -> bool:
	for feature in features:
		var bounds: Rect2 = feature.bounds
		if bounds.grow(margin + 0.001).has_point(point) and signed_distance(feature, point) <= margin:
			return true
	return false
