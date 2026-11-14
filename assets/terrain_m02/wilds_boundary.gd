extends RefCounted
## M09 reservations remain inside an irregular arena. The exterior never participates in play.

const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Seed = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Biome = preload("res://assets/terrain_m02/wilds_biome.gd")

const SAMPLES := 144
const MAX_ZOOM := 22.0
const MAX_PAN := 5.0

static func build(layout: Dictionary, seed_value: int, radius: int, spacing: float, climate: Dictionary) -> Dictionary:
	var random := Seed.random_stream(seed_value, "wilds_perimeter")
	var phase := random.randf() * TAU
	var extent := radius * spacing
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var water: Array = layout.water.duplicate()
	var rims: Array[Dictionary] = []
	var scenic: Array[Dictionary] = []
	var protected: Array = layout.paths + layout.path_joins + layout.clearings
	# Push the berm outward locally where a validated path or reservation approaches it.
	var front := PackedVector2Array()
	for feature in protected:
		front.append_array(Shape.boundary(feature))
	for attempt in 4:
		inner.clear()
		outer.clear()
		for i in SAMPLES:
			var theta := TAU * i / SAMPLES
			var direction := Vector2.from_angle(theta)
			var maximum := _hex_support(direction) * extent
			var shape := 0.82 + 0.037 * sin(theta * 3.0 + phase) + 0.024 * cos(theta * 7.0 - phase)
			shape += 0.011 * sin(theta * 13.0 + phase * 1.4) + 0.027 * attempt
			var verge := maximum * shape
			for point in front:
				var projection := direction.dot(point)
				if projection <= verge - 2.0 or absf(direction.cross(point)) > 3.0:
					continue
				var reach := 1.55 * sqrt(maxf(0.0, 1.0 - pow(direction.cross(point) / 3.0, 2)))
				verge = maxf(verge, projection + reach)
			inner.append(direction * verge)
			var ledge := 3.05 + 0.73 * sin(theta * 5.0 - phase) + 0.42 * cos(theta * 11.0 + phase)
			outer.append(direction * (verge + ledge))
		var arena := Shape.shape("arena", "playable", inner)
		if _contains_reservations(arena, protected):
			break
		if attempt == 3:
			return {}
	# One set of shared cross-sections makes the border watertight. Some sectors
	# are broad marsh pools. The same wet strips are baked into the visible water mask.
	for sector in 18:
		var first := sector * 8
		var out_a := PackedVector2Array()
		var out_b := PackedVector2Array()
		var channel := false
		for i in range(first, first + 9):
			var j := i % SAMPLES
			out_a.append(inner[j])
			out_b.append(outer[j])
			channel = channel or Shape.in_any(layout.water, inner[j], 0.39)
		var family := Biome.family(climate.weights, random.randf())
		var marsh := channel or (family == 1 and sin(sector * 0.84 + phase) > -0.13)
		var id := "perimeter_%d" % sector
		var outline := out_a.duplicate()
		out_b.reverse()
		outline.append_array(out_b)
		out_b.reverse()
		var sector_shape := Shape.shape(id, "marsh" if marsh else "rim", outline)
		sector_shape.merge({"family": family, "inner": out_a, "outer": out_b, "wet": marsh, "start": first})
		rims.append(sector_shape)
		if marsh:
			var shore := out_a.duplicate()
			for j in range(out_b.size() - 1, -1, -1):
				# A lobed wet edge avoids straight outer ends on adjacent pools.
				var t := float(j) / (out_b.size() - 1)
				var depth := 0.84 + 0.16 * sin(t * PI) + 0.16 * sin(sector * 2.7 + t * PI)
				shore.append(out_a[j].lerp(out_b[j], depth))
			water.append(Shape.shape(id + "_water", "marsh", shore))
		var accent_at := inner[(first + 4) % SAMPLES].lerp(outer[(first + 4) % SAMPLES], 0.76)
		if not marsh or family == 1:
			_scenic(scenic, accent_at, family, random, not marsh, 1.0)
			var flank := (first + 6) % SAMPLES
			if not marsh:
				_scenic(scenic, inner[flank].lerp(outer[flank], 0.57), family, random, true, 0.74)
	# Seeded, staggered woodland clumps continue into the camera border.
	for i in SAMPLES:
		var direction := inner[i].normalized()
		var side := direction.orthogonal()
		var family := Biome.family(climate.weights, random.randf())
		var cluster := 0.56 + 0.28 * sin(i * 0.32 + phase) + 0.13 * cos(i * 0.83)
		for depth in 3:
			if random.randf() > cluster:
				continue
			var at := outer[i] + direction * (3.0 + depth * 6.2 + random.randf_range(-0.9, 2.8))
			at += side * random.randf_range(-1.8, 1.8)
			_scenic(scenic, at, family, random, not Shape.in_any(water, at), 1.0 - 0.12 * depth)
	return {"playable": Shape.shape("arena", "playable", inner), "rim": rims,
		"exterior_props": scenic, "water": water}

static func _hex_support(direction: Vector2) -> float:
	var result := INF
	for i in 3:
		var normal := Vector2.from_angle(PI * 0.5 + i * TAU / 6.0)
		result = minf(result, sqrt(3.0) * 0.5 / maxf(absf(direction.dot(normal)), 0.0001))
	return result

static func _contains_reservations(arena: Dictionary, protected: Array) -> bool:
	var outline: PackedVector2Array = arena.outline
	for feature in protected:
		for point in Shape.boundary(feature):
			if Shape.polygon_distance(outline, point, 1.1) > -0.85:
				return false
	return true

static func _scenic(items: Array[Dictionary], at: Vector2, family: int,
		random: RandomNumberGenerator, dry: bool, scale: float) -> void:
	var tree := family == 0 or (family == 1 and random.randf() > 0.31)
	var kind := "tree" if tree else "reed"
	if family == 2:
		kind = "root_arch" if random.randf() > 0.57 else "fungus"
	if not dry and family != 1:
		return
	var height := random.randf_range(4.0, 7.6) if tree else random.randf_range(1.2, 2.9)
	if kind == "fungus":
		height *= 0.31
	items.append({"center": at, "family": family, "kind": kind, "height": height * scale,
		"yaw": random.randf() * TAU, "variant": random.randi_range(0, 2), "tint": random.randf()})

static func exterior_extent(radius: int, spacing: float, view_size: Vector2) -> float:
	var aspect := maxf(view_size.x / maxf(1.0, view_size.y), view_size.y / maxf(1.0, view_size.x))
	return radius * spacing + MAX_PAN + MAX_ZOOM * (aspect + 2.25) + 4.0
