extends RefCounted
## Graph edges name their destinations before any trail geometry is compiled.
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")

static func garden(layout: Dictionary, arrival: Vector2, bend: float) -> void:
	var approach := Vector2(-1.36, 3.26)
	_set_graph(layout, {"arrival": arrival, "heart_threshold": approach}, [
		_edge("garden_approach", "arrival", "heart_threshold",
			PackedVector2Array([arrival * 0.72 + Vector2(bend, 0.0), Vector2(-3.2, 5.15)]), 0.82)
	])

static func wilds(layout: Dictionary, west: Vector2, east: Vector2, south: Vector2,
		west_bank: Vector2, east_bank: Vector2, bend: Vector2) -> void:
	var axis := (east_bank - west_bank).normalized()
	var a := west_bank - axis * 0.52
	var b := east_bank + axis * 0.52
	var w := _edge("west_approach", "west_glade", "west_bank",
		PackedVector2Array([west.lerp(a, 0.48) + axis.orthogonal() * 0.52]), 0.76)
	var deck := _edge("river_crossing", "west_bank", "east_bank", PackedVector2Array(), 0.76)
	deck["bridge"] = true
	var e := _edge("east_approach", "east_bank", "east_glade",
		PackedVector2Array([b.lerp(east, 0.52) - axis.orthogonal() * 0.46]), 0.76)
	var junction := _edge("hollow_trail", "fern_hollow", "west_glade", PackedVector2Array([bend]), 0.75)
	_set_graph(layout, {"west_glade": west, "east_glade": east, "fern_hollow": south,
		"west_bank": a, "east_bank": b}, [w, deck, e, junction])

static func _edge(id: String, from: String, to: String, via: PackedVector2Array, width: float) -> Dictionary:
	return {"id": id, "from": from, "to": to, "via": via, "width": width}

static func _set_graph(layout: Dictionary, nodes: Dictionary, edges: Array[Dictionary]) -> void:
	layout["trail_network"] = {"nodes": nodes, "edges": edges}
	for edge in edges:
		var points := PackedVector2Array([nodes[edge.from]])
		points.append_array(edge.via)
		points.append(nodes[edge.to])
		var path := _compile(edge, points)
		layout.paths.append(path)
		if edge.get("bridge", false):
			var crossing := path.duplicate()
			crossing.id = edge.id + "_deck"
			crossing.kind = "crossing"
			crossing["bridge"] = PackedVector2Array([points[0], points[-1]])
			layout.crossings.append(crossing)
	# Small rounded joins mask the shared endpoint at forks and dead-straight deck seams.
	var joins: Array[Dictionary] = []
	for id in nodes:
		var cap := Shape.disk(id + "_join", "trail_join", nodes[id], 0.52)
		joins.append(Shape.shape(cap.id, cap.kind, Shape.boundary(cap)))
	layout["path_joins"] = joins

static func _compile(edge: Dictionary, points: PackedVector2Array) -> Dictionary:
	var spine := PackedVector2Array()
	var widths := PackedFloat32Array()
	var bridge: bool = edge.get("bridge", false)
	for i in range(points.size() - 1):
		var a := points[maxi(i - 1, 0)]
		var b := points[i]
		var c := points[i + 1]
		var d := points[mini(i + 2, points.size() - 1)]
		var count := maxi(2, ceili(b.distance_to(c) * 3.0))
		for j in count:
			var t := float(j) / count
			spine.append(b.lerp(c, t) if bridge else b.cubic_interpolate(c, a, d, t))
			widths.append(edge.width if bridge else edge.width * (1.0 + 0.09 * sin((i + t) * TAU)))
	spine.append(points[-1])
	widths.append(edge.width)
	return Shape.ribbon(edge.id, "path", spine, widths)

static func natural_clearings(clearings: Array, seed_value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for clearing in clearings:
		var phase := float(("%d/%s" % [seed_value, clearing.id]).hash() % 360) * PI / 180.0
		var points := PackedVector2Array()
		for i in 40:
			var angle := TAU * i / 40.0
			var envelope := 0.91 + 0.17 * sin(3.0 * angle + phase) + 0.12 * cos(5.0 * angle - phase)
			var offset := Vector2(cos(angle) * 1.15, sin(angle) * 0.83).rotated(phase)
			points.append(clearing.center + offset * (envelope * clearing.radius))
		result.append(Shape.shape(clearing.id, "ground_clearing", points))
	return result
