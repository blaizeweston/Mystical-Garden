extends RefCounted
## Select rooms from dry playable space, then connect them over the actual water polygons.

const Geo = preload("res://assets/terrain_m02/wilds_geography.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Trails = preload("res://assets/terrain_m02/terrain_trail_network.gd")
const Streams = preload("res://assets/terrain_m02/terrain_feature_layout.gd")
const Hydro = preload("res://assets/terrain_m02/wilds_route_hydrology.gd")
const ATTEMPTS := 6
const LANDING_PAD := 1.0
const WIDTH := 0.91

static func build(seed_value: int, radius: int, spacing: float, climate: Dictionary, attempt: int) -> Dictionary:
	var density := radius * spacing
	var random := Streams.random_stream(seed_value, "m09b_rooms_%d" % attempt)
	# Repair keeps the selected hydrology and instead resamples rooms and route choices.
	var hydro := Hydro.build(Streams.random_stream(seed_value, "m09b_water"), density,
		climate.weights, climate.floor_number)
	var water: Array = hydro.water
	var offers := _offers(random, water, radius, spacing)
	if offers.size() < 6:
		return {}
	var arrival: Dictionary = offers.pop_front()
	var gates: Array[Dictionary] = []
	for item in offers:
		var distance: float = arrival.center.distance_to(item.center)
		if distance > density * 0.66 and distance < density * 1.24 and item.radius >= 2.18:
			gates.append(item)
	if gates.is_empty():
		return {}
	var gate: Dictionary = gates[random.randi_range(0, gates.size() - 1)]
	offers.erase(gate)
	var rooms: Array[Dictionary] = []
	for item in offers:
		var near: float = minf(item.center.distance_to(arrival.center), item.center.distance_to(gate.center))
		var far: float = maxf(item.center.distance_to(arrival.center), item.center.distance_to(gate.center))
		if near > density * 0.29 and far < density * 1.04 and item.radius >= 2.2:
			rooms.append(item)
	if rooms.is_empty():
		return {}
	var combat: Dictionary = rooms[random.randi_range(0, rooms.size() - 1)]
	offers.erase(combat)
	var layout := {"water": water, "clearings": [], "paths": [], "crossings": [],
		"plants": [], "rocks": [], "enclosure": [], "accents": [], "formations": [],
		"repair": attempt, "hydrology": hydro.kind, "combat_rooms": ["combat", "exit_gate"]}
	var graph := {"nodes": {}, "edges": []}
	_add_room(graph, layout, arrival, "arrival", "arrival")
	_add_room(graph, layout, combat, "combat", "required")
	_add_room(graph, layout, gate, "exit_gate", "required")
	var route := random.randi_range(0, 2)
	if route == 0:
		# The encounter lies at the end of a side trail off the main Gate route.
		if not _connect(graph, water, "arrival", "exit_gate", "gate_trail", random, radius, spacing):
			return {}
		if not _connect(graph, water, "arrival", "combat", "hunt_trail", random, radius, spacing):
			return {}
	else:
		if not _connect(graph, water, "arrival", "combat", "hunt_trail", random, radius, spacing):
			return {}
		if not _connect(graph, water, "combat", "exit_gate", "gate_trail", random, radius, spacing):
			return {}
	if route == 2:
		_connect(graph, water, "arrival", "exit_gate", "shortcut", random, radius, spacing)

	# Add the actual dry saddle where the stream separates into two reaches.
	if hydro.has("dry_crossing"):
		_add_saddle(graph, layout, hydro.dry_crossing, random, radius, spacing)
	var limit := random.randi_range(0, 3)
	for i in limit:
		_optional(graph, layout, offers, i, random, radius, spacing)
	if not hydro.island.is_empty():
		_island(graph, layout, hydro.island, random, radius, spacing)
	var edges: Array[Dictionary] = []
	edges.assign(graph.edges)
	for edge in edges:
		edge.erase("footprint")
	Trails._set_graph(layout, graph.nodes, edges)
	if not _valid_layout(layout, radius, spacing):
		return {}
	layout["ground_clearings"] = layout.clearings
	return layout

static func _offers(random: RandomNumberGenerator, water: Array, radius: int, spacing: float) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var extent := radius * spacing
	for i in 85:
		var point := Vector2.from_angle(random.randf() * TAU) * extent * sqrt(random.randf_range(0.055, 0.54))
		var room_size := random.randf_range(2.12, 3.25)
		if _dry_room(point, room_size * 1.26, water, radius, spacing):
			offers.append({"center": point, "radius": room_size, "phase": random.randf() * TAU})
	return offers

static func _dry_room(at: Vector2, pad: float, water: Array, radius: int, spacing: float) -> bool:
	if Shape.in_any(water, at, pad + 0.14):
		return false
	for i in 12:
		if not Geo._inside_disk(at + Vector2.from_angle(i * TAU / 12.0) * (pad + 0.7), radius, spacing):
			return false
	return true

static func _add_room(graph: Dictionary, layout: Dictionary, room: Dictionary, id: String, kind: String) -> void:
	graph.nodes[id] = room.center
	var outline := PackedVector2Array()
	for i in 32:
		var angle := TAU * i / 32.0
		var twist := 1.0 + 0.13 * sin(angle * 3.0 + room.phase) + 0.06 * cos(angle * 5.0 - room.phase)
		var axis := Vector2(cos(angle), sin(angle) * 0.94).rotated(room.phase)
		outline.append(room.center + axis * room.radius * twist)
	var shape := Shape.shape(id, kind, outline)
	shape["center"] = room.center
	layout.clearings.append(shape)

static func _optional(graph: Dictionary, layout: Dictionary, offers: Array[Dictionary], index: int,
		random: RandomNumberGenerator, radius: int, spacing: float) -> void:
	for candidate in 12:
		var room: Dictionary = offers[random.randi_range(0, offers.size() - 1)]
		if Shape.in_any(layout.clearings, room.center, room.radius * 1.28 + 1.1):
			continue
		var at: Vector2 = room.center
		var closest := _near_rooms(at, graph, layout, 2)
		var id := "side_%d" % index
		graph.nodes[id] = at
		if not _connect(graph, layout.water, closest[0], id, id, random, radius, spacing):
			graph.nodes.erase(id)
			continue
		_add_room(graph, layout, room, id, "optional")
		if random.randf() < 0.40:
			_connect(graph, layout.water, id, closest[1], id + "_loop", random, radius, spacing)
		return

static func _near_rooms(at: Vector2, graph: Dictionary, layout: Dictionary, count: int) -> Array:
	var ids: Array = []
	for room in layout.clearings:
		ids.append(room.id)
	ids.sort_custom(func(a: String, b: String):
		return at.distance_squared_to(graph.nodes[a]) < at.distance_squared_to(graph.nodes[b]))
	return ids.slice(0, count)

static func _add_saddle(graph: Dictionary, layout: Dictionary, center: Vector2,
		random: RandomNumberGenerator, radius: int, spacing: float) -> void:
	if not _dry_room(center, 1.47, layout.water, radius, spacing) or Shape.in_any(layout.clearings, center, 2.0):
		return
	var closest := _near_rooms(center, graph, layout, 3)
	var trial := graph.duplicate(true)
	trial.nodes["dry_crossing"] = center
	var joined := 0
	for id in closest:
		# Keep only land-only approaches, so this is a genuine no-deck alternative.
		if _connect(trial, layout.water, id, "dry_crossing", "saddle_%d" % joined, random, radius, spacing, false):
			joined += 1
		if joined == 2:
			break
	if joined < 2:
		return
	graph.merge(trial, true)
	_add_room(graph, layout, {"center": center, "radius": 1.03, "phase": random.randf() * TAU}, "dry_crossing", "optional")

static func _island(graph: Dictionary, layout: Dictionary, island: Dictionary,
		random: RandomNumberGenerator, radius: int, spacing: float) -> void:
	var center: Vector2 = island.center
	if not Geo._inside_disk(center, radius, spacing) or Shape.in_any(layout.water, center, 1.02):
		return
	var trial := graph.duplicate(true)
	trial.nodes["island_room"] = center
	var joined := 0
	var first_side := Vector2.ZERO
	for node in _near_rooms(center, graph, layout, layout.clearings.size()):
		var side := (graph.nodes[node] as Vector2) - center
		if joined == 1 and first_side.normalized().dot(side.normalized()) > 0.38:
			continue
		if _connect(trial, layout.water, node, "island_room", "island_%d" % joined, random, radius, spacing):
			if joined == 0:
				first_side = side
			joined += 1
		if joined == 2:
			break
	if joined > 0:
		graph.merge(trial, true)
		var reservation := PackedVector2Array()
		for point in island.outline:
			reservation.append(center.lerp(point, 0.70))
		var room := Shape.shape(island.id, "optional", reservation)
		room["center"] = center
		layout.clearings.append(room)

static func _connect(graph: Dictionary, water: Array, from: String, to: String, id: String,
		random: RandomNumberGenerator, radius: int, spacing: float, allow_bridge: bool = true) -> bool:
	var a: Vector2 = graph.nodes[from]
	var b: Vector2 = graph.nodes[to]
	var length := a.distance_to(b)
	if length < 3.0:
		return false
	var across := (b - a).normalized().orthogonal()
	var bend := random.randf_range(-0.22, 0.22) * length
	for scale in [1.0, 0.5, -0.63, 0.0]:
		var middle: Vector2 = a.lerp(b, 0.5) + across * bend * scale
		var open_lane := water.is_empty() and id == "gate_trail" and absf(bend) < length * 0.15
		var edge := Trails._edge(id, from, to, PackedVector2Array([middle]), 1.65 if open_lane else WIDTH)
		if open_lane:
			edge["open_lane"] = true
		var path := Trails._compile(edge, PackedVector2Array([a, middle, b]))
		if _valid_path(path, water, radius, spacing) and not _overlaps_deck(graph, path):
			graph.edges.append(edge)
			return true
	if not allow_bridge:
		return false
	return _cross(graph, water, a, b, from, to, id, radius, spacing)

static func _cross(graph: Dictionary, water: Array, a: Vector2, b: Vector2, from: String,
		to: String, id: String, radius: int, spacing: float) -> bool:
	var length := a.distance_to(b)
	var steps := maxi(2, ceili(length / 0.23))
	var first := -1
	var last := -1
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if Shape.in_any(water, p, LANDING_PAD):
			if first < 0:
				first = i
			last = i
	if first < 2 or last > steps - 2:
		return false
	var n := a.lerp(b, float(first - 1) / steps)
	var m := a.lerp(b, float(last + 1) / steps)
	if not Shape.in_any(water, n.lerp(m, 0.5)) and not _spans_water(n, m, water):
		return false
	var start := id + "_bank_a"
	var end := id + "_bank_b"
	var near := Trails._edge(id + "_approach", from, start, PackedVector2Array(), WIDTH)
	var far := Trails._edge(id + "_landing", end, to, PackedVector2Array(), WIDTH)
	var bridge := Trails._edge(id + "_crossing", start, end, PackedVector2Array(), 0.76)
	bridge["bridge"] = true
	# A narrow slab ends on the actual dry landing disks, where the same polygon is traversable.
	for segment in [[near, a, n], [far, m, b], [bridge, n, m]]:
		var path := Trails._compile(segment[0], PackedVector2Array([segment[1], segment[2]]))
		var avoid := [] if segment[0].get("bridge", false) else water
		if not _valid_path(path, avoid, radius, spacing) or _overlaps_deck(graph, path):
			return false
	graph.nodes[start] = n
	graph.nodes[end] = m
	bridge["footprint"] = Trails._compile(bridge, PackedVector2Array([n, m]))
	graph.edges.append_array([near, bridge, far])
	return true

static func _overlaps_deck(graph: Dictionary, path: Dictionary) -> bool:
	for edge in graph.edges:
		if not edge.has("footprint"):
			continue
		var deck: Dictionary = edge.footprint
		if path.bounds.intersects(deck.bounds) and not Geometry2D.intersect_polygons(path.outline, deck.outline).is_empty():
			return true
	return false

static func _spans_water(a: Vector2, b: Vector2, water: Array) -> bool:
	for i in range(1, 12):
		if Shape.in_any(water, a.lerp(b, float(i) / 12.0)):
			return true
	return false

static func _valid_path(path: Dictionary, water: Array, radius: int, spacing: float) -> bool:
	for point in path.outline:
		if not Geo._inside_disk(point, radius, spacing):
			return false
	if Geometry2D.triangulate_polygon(path.outline).is_empty():
		return false
	if water.is_empty():
		return true
	for shape in water:
		if not path.bounds.intersects(shape.bounds):
			continue
		# Test continuous edges too, so corners cannot slice across a narrow wet reach.
		var previous: Vector2 = path.outline[-1]
		for point in path.outline:
			for t in [0.0, 0.5]:
				if Shape.signed_distance(shape, previous.lerp(point, t), 0.22) <= 0.14:
					return false
			previous = point
	return true

static func _valid_layout(layout: Dictionary, radius: int, spacing: float) -> bool:
	for cap in layout.path_joins:
		for point in cap.outline:
			if not Geo._inside_disk(point, radius, spacing) or Shape.in_any(layout.water, point, 0.02):
				return false
	for clearing in layout.clearings:
		for point in clearing.outline:
			if not Geo._inside_disk(point, radius, spacing) or Shape.in_any(layout.water, point):
				return false
	return true
