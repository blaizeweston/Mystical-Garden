extends RefCounted

const Contact = preload("res://weapon_contact.gd")
const Variants = preload("res://core_weapon_variants.gd")


static func area(at: Vector3, radius: float) -> Dictionary:
	return {"kind": "area", "at": at, "radius": radius}


static func lane(field: RefCounted, at: Vector3, axis: Vector3, length: float, width: float, rounded: bool = false) -> Dictionary:
	return {"kind": "capsule" if rounded else "strip", "from": field.dash(at, at - axis * length),
		"to": field.dash(at, at + axis * length), "width": width}


static func build(field: RefCounted, cast: Dictionary, origin: Vector3, stage: int = 0) -> Array:
	var skill: Dictionary = cast.skill
	var at: Vector3 = cast.center
	var forward: Vector3 = cast.forward
	var side := forward.cross(Vector3.UP)
	var radius: float = skill.radius
	match skill.get("affinity_family", ""):
		"frost":
			return [area(at,radius)]
		"fire":
			return [lane(field, at, forward, radius, skill.width, true)]
		"water":
			return [{"kind":"capsule", "from":origin, "to":at, "width":radius}]
	match skill.id:
		"ember_wake":
			return [lane(field, at, forward, radius, radius * .34, true)]
		"gravity_well", "grave_lantern", "dream_lure":
			return [area(at, radius)]
		"eclipse_maw":
			if stage > 0:
				return [lane(field, at, forward, radius * .87, radius * .44)]
			var jaws := []
			for direction in [-1, 1]:
				var jaw: Vector3 = at + side * radius * .58 * direction
				if field.clear_line(at, jaw):
					jaws.append(lane(field, jaw, forward, radius * .86, radius * .43))
			return jaws
		"worldbloom":
			if stage > 0:
				return [area(at, radius * .57)]
			var branches := []
			for i in 5:
				var end: Vector3 = field.dash(at, at + forward.rotated(Vector3.UP, i * TAU / 5) * radius)
				branches.append({"kind": "capsule", "from": at, "to": end, "width": .29})
			return branches
		"spore_seal":
			var seals := []
			for i in [-1, 0, 1]:
				var seal: Vector3 = at + side * i * radius * .65
				if field.clear_line(at, seal):
					seals.append(area(seal, radius * .3))
			return seals
		"moon_snare":
			var crescent := []
			var hub := at - forward * radius * .7
			var previous := hub + forward.rotated(Vector3.UP, -1.05) * radius * .7
			for i in range(1, 13):
				var point := hub + forward.rotated(Vector3.UP, -1.05 + i * 2.1 / 12) * radius * .7
				if field.clear_line(at, previous) and field.clear_line(at, point):
					crescent.append({"kind": "capsule", "from": previous, "to": point, "width": radius * .24})
				previous = point
			return crescent
		"sun_pillar":
			return [lane(field, at, forward, radius, radius * .28), lane(field, at, side, radius, radius * .28)]
		"blood_siphon", "rime_bloom", "hush":
			var from := at - forward * radius * .48
			if skill.get("targeting") == "self" or not field.clear_line(at, from):
				from = at
			var spans := {"blood_siphon": 1.37, "rime_bloom": 1.72, "hush": 1.65}
			return [{"kind": "cone", "at": from, "forward": forward, "radius": radius * 1.35, "span": spans[skill.id]}]
		"dewfall", "ironbark", "crownlink":
			return [lane(field, at, side, radius, radius * .36)]
		"phantom_step":
			if skill.movement == "approach":
				var landing: Vector3 = cast.get("step_end", Variants.travel(field, origin, at, forward, skill))
				return [{"kind": "capsule", "from": landing.move_toward(origin, radius), "to": landing, "width": radius * .43}]
			return [lane(field, at, side, radius, radius * .43, true)]
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
