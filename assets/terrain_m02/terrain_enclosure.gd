extends RefCounted
## Visual enclosure rings use their own seeded stream and preserve M04 layouts.
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Layout = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")

const SECTORS := 32

static func build(base: Dictionary, cells: Dictionary, spacing: float, seed_value: int, garden: bool) -> Dictionary:
	var layout := base.duplicate()
	layout.plants = []
	layout.rocks = []
	layout["enclosure"] = []
	layout["accents"] = []
	var core := Shape.disk("heart_light", "protected_core", Vector2.ZERO, 5.9)
	for plant in base.plants:
		if not garden or not Shape.contains(core, plant.center) or plant.kind == "grass":
			layout.plants.append(plant)
	for rock in base.rocks:
		if not garden or not Shape.in_any([core], rock.center, rock.radius):
			layout.rocks.append(rock)
	layout["protected_core"] = core if garden else {}
	var unused_sectors := {}
	for ring in 2:
		for i in SECTORS:
			var random := Layout.random_stream(seed_value, "enclosure_%d_%d" % [ring, i])
			var angle := TAU * i / SECTORS + random.randf_range(-0.028, 0.028)
			var direction := Vector2.from_angle(angle)
			var offset := 0.52 * sin(3.0 * angle + float(seed_value % 73)) + 0.35 * cos(5.0 * angle)
			var inner := 8.45 if garden else 11.65
			# Bulge eastward around the pond while enclosing its outer bank.
			if garden:
				inner += 4.6 * pow(maxf(0.0, direction.dot(Vector2(0.91, -0.41))), 4.0)
			var foreground := smoothstep(0.25, 0.95, direction.dot(Vector2(0.229, 0.973)))
			var at := direction * (inner + offset + ring * 2.75 + foreground * (2.85 if garden else 2.75))
			at.y *= 0.94
			at += direction.orthogonal() * random.randf_range(-0.48, 0.48)
			for attempt in 5:
				if _allows(layout, cells, spacing, at):
					break
				at += direction * 0.62 + direction.orthogonal() * (0.31 if i % 2 == 0 else -0.31)
			if not _allows(layout, cells, spacing, at):
				unused_sectors[i] = angle
				continue
			var height := random.randf_range(4.1, 6.5) + ring * 0.8
			var crown := random.randf_range(2.0, 2.6)
			# Low crowns in the foreground frame the approach and the bridge.
			height *= lerpf(1.0, 0.57 if garden else 0.54, foreground)
			crown *= lerpf(1.0, 0.74, foreground)
			layout.enclosure.append({"id": "rim_%d_%d" % [ring, i], "ring": ring, "sector": i,
				"at": at, "height": height, "crown": crown, "variant": random.randi_range(0, 3),
				"yaw": random.randf_range(0.0, TAU)})
	if garden:
		_fill_garden_gaps(layout, cells, spacing, seed_value, unused_sectors)
	for path in base.paths:
		var spine: PackedVector2Array = path.spine
		for i in range(3, spine.size() - 2, 5):
			var random := Layout.random_stream(seed_value, "%s_accent_%d" % [path.id, i])
			var side := -1.0 if (i / 5) % 2 == 0 else 1.0
			var tangent := (spine[i + 1] - spine[i - 1]).normalized()
			var at := spine[i] + side * tangent.orthogonal() * random.randf_range(0.96, 1.52)
			if not _allows(layout, cells, spacing, at, 0.47) or random.randf() < (0.1 if garden else 0.33):
				continue
			layout.accents.append({"id": "%s_accent_%d" % [path.id, i], "at": at,
				"yaw": atan2(tangent.y, tangent.x) + random.randf_range(-0.8, 0.8), "size": random.randf_range(0.67, 1.04)})
	return layout

static func _fill_garden_gaps(layout: Dictionary, cells: Dictionary, spacing: float,
		seed_value: int, unused: Dictionary) -> void:
	var covered := {}
	for trunk in layout.enclosure:
		covered[trunk.sector] = true
	for sector: int in unused:
		if covered.has(sector):
			continue
		var random := Layout.random_stream(seed_value, "rim_gap_%d" % sector)
		var direction := Vector2.from_angle(unused[sector])
		for distance in [12.0, 13.2, 14.4, 15.6, 16.8]:
			var at: Vector2 = direction * distance
			if not _allows(layout, cells, spacing, at):
				continue
			layout.enclosure.append({"id": "rim_gap_%d" % sector, "ring": 1, "sector": sector,
				"at": at, "height": 3.6, "crown": 1.8, "variant": random.randi_range(0, 3),
				"yaw": random.randf_range(0.0, TAU)})
			break

static func _allows(layout: Dictionary, cells: Dictionary, spacing: float, at: Vector2, pad: float = 0.58) -> bool:
	return cells.has(Grid.world_to_cell(at, spacing)) \
		and not Shape.in_any(layout.clearings, at, pad) \
		and not Shape.in_any(layout.paths, at, pad) \
		and not Shape.in_any(layout.water, at, pad) \
		and not Shape.in_any(layout.rocks, at, pad)

static func digest(layout: Dictionary) -> String:
	return Layout.digest({"enclosure": layout.enclosure, "accents": layout.accents,
		"plants": layout.plants, "rocks": layout.rocks, "protected_core": layout.protected_core})
