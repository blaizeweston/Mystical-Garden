extends RefCounted

const Contact = preload("res://weapon_contact.gd")


static func area(at: Vector3, radius: float) -> Dictionary:
	return {"kind": "area", "at": at, "radius": radius}


static func lane(field: RefCounted, at: Vector3, axis: Vector3, length: float, width: float, rounded: bool = false) -> Dictionary:
	return {"kind": "capsule" if rounded else "strip", "from": field.dash(at, at - axis * length),
		"to": field.dash(at, at + axis * length), "width": width}


static func build(field: RefCounted, cast: Dictionary, origin: Vector3, _stage: int = 0) -> Array:
	var skill: Dictionary = cast.skill
	var at: Vector3 = cast.center
	var forward: Vector3 = cast.forward
	var side := forward.cross(Vector3.UP)
	var radius: float = skill.radius
	match skill.get("affinity_family", ""):
		"frost", "vital", "wood", "void":
			return [area(at,radius)]
		"fire":
			return [lane(field, at, forward, radius, skill.width, true)]
		"thorn":
			return [lane(field, at, side, radius, skill.width, true)]
		"water":
			return [{"kind":"capsule", "from":origin, "to":at, "width":radius}]

	return []


static func contains(field: RefCounted, shape: Dictionary, point: Vector3, source: Vector3) -> bool:
	point.y = 0
	var anchor := source
	match shape.kind:
		"area", "cone":
			anchor = shape.at
			var offset := point - anchor
			if offset.length_squared() > float(shape.radius) ** 2:
				return false
			if shape.kind == "cone" and not offset.is_zero_approx() and offset.normalized().dot(shape.forward) < cos(float(shape.span) * .5):
				return false
		"strip", "capsule":
			var start: Vector3 = shape.from
			var end: Vector3 = shape.to
			anchor = Geometry3D.get_closest_point_to_segment(point, start, end)
			if point.distance_squared_to(anchor) > float(shape.width) ** 2:
				return false
			if shape.kind == "strip" and ((point - start).dot(end - start) < 0 or (point - end).dot(start - end) < 0):
				return false
	return field.clear_line(source, anchor) and field.clear_line(anchor, point)


static func reaches(field: RefCounted, shapes: Array, point: Vector3, source: Vector3) -> bool:
	for shape in shapes:
		if contains(field, shape, point, source):
			return true
	return false


static func targets(game: Node, shapes: Array, source: Vector3) -> Array[int]:
	var result: Array[int] = []
	for target in Contact.candidates(game, source):
		if reaches(game.battlefield, shapes, game.enemy_position(target), source):
			result.append(target)
	return result


static func encode(shapes: Array) -> Array:
	var result := []
	for shape in shapes:
		var data: Dictionary = shape.duplicate()
		for key in ["at", "from", "to", "forward"]:
			if data.has(key):
				var point: Vector3 = data[key]
				data[key] = [point.x, point.y, point.z]
		result.append(data)
	return result
