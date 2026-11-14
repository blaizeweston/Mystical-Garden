extends RefCounted
## Rasterize the same polygons used by the feature queries. Land stays on one mesh.

const Geometry = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const MAX_DISTANCE := 1.5
const SAMPLES_PER_UNIT := 5.0

static func bake(layout: Dictionary, spacing: float, radius: int) -> Dictionary:
	var extent := Vector2((radius + 0.65) * spacing,
		(radius * sqrt(3.0) * 0.5 + 0.65) * spacing)
	var frame := Rect2(-extent, extent * 2.0)
	var size := Vector2i((frame.size * SAMPLES_PER_UNIT).ceil()) + Vector2i.ONE
	var pixels := PackedByteArray()
	pixels.resize(size.x * size.y * 3)
	pixels.fill(255)
	_stamp(layout.water, 0, frame, size, pixels)
	_stamp(layout.paths + layout.get("path_joins", []), 1, frame, size, pixels)
	var clearings: Array[Dictionary] = []
	for clearing in layout.get("ground_clearings", layout.clearings):
		clearings.append(Geometry.shape(clearing.id, "clearing", Geometry.boundary(clearing)))
	_stamp(clearings, 2, frame, size, pixels)
	return {"image": Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGB8, pixels),
		"frame": frame, "size": size}

static func bind(material: ShaderMaterial, atlas: Dictionary) -> void:
	material.set_shader_parameter("feature_distances", ImageTexture.create_from_image(atlas.image))
	material.set_shader_parameter("feature_origin", atlas.frame.position)
	material.set_shader_parameter("feature_extent", atlas.frame.size)
	material.set_shader_parameter("feature_size", Vector2(atlas.size))
	material.set_shader_parameter("feature_range", MAX_DISTANCE)

static func _stamp(features: Array, channel: int, frame: Rect2, size: Vector2i, pixels: PackedByteArray) -> void:
	var step := frame.size / (Vector2(size) - Vector2.ONE)
	for feature in features:
		var bounds: Rect2 = feature.bounds
		var band := bounds.grow(MAX_DISTANCE)
		var lo := Vector2i(((band.position - frame.position) / step).floor()).clamp(Vector2i.ZERO, size)
		var hi := Vector2i(((band.end - frame.position) / step).ceil()).clamp(Vector2i.ZERO, size - Vector2i.ONE)
		var nearest := PackedFloat32Array()
		nearest.resize(size.x * size.y)
		nearest.fill(MAX_DISTANCE * MAX_DISTANCE)
		var crossings: Array[PackedFloat32Array] = []
		crossings.resize(size.y)
		var contours: Array = [feature.outline] + feature.get("holes", [])
		for outline: PackedVector2Array in contours:
			var previous := outline[-1]
			for point in outline:
				var edge := point - previous
				var length_inv := 1.0 / maxf(edge.length_squared(), 0.000001)
				var edge_band := Rect2(previous, Vector2.ZERO).expand(point).grow(MAX_DISTANCE)
				var start := Vector2i(((edge_band.position - frame.position) / step).floor()).max(lo)
				var end := Vector2i(((edge_band.end - frame.position) / step).ceil()).min(hi)
				for y in range(start.y, end.y + 1):
					var world_y := frame.position.y + y * step.y
					if (previous.y > world_y) != (point.y > world_y):
						crossings[y].append(previous.x + edge.x * (world_y - previous.y) / edge.y)
					for x in range(start.x, end.x + 1):
						var at := frame.position + Vector2(x, y) * step - previous
						var t := clampf(at.dot(edge) * length_inv, 0.0, 1.0)
						var index := y * size.x + x
						nearest[index] = minf(nearest[index], (at - edge * t).length_squared())
				previous = point
		for y in range(lo.y, hi.y + 1):
			var intersections := crossings[y]
			intersections.sort()
			var passed := 0
			for x in range(lo.x, hi.x + 1):
				var world_x := frame.position.x + x * step.x
				while passed < intersections.size() and intersections[passed] <= world_x:
					passed += 1
				var index := y * size.x + x
				var distance := sqrt(nearest[index]) * (-1.0 if passed % 2 == 1 else 1.0)
				var encoded := roundi(127.5 * (1.0 + distance / MAX_DISTANCE))
				var texel := index * 3 + channel
				pixels[texel] = mini(pixels[texel], encoded)
