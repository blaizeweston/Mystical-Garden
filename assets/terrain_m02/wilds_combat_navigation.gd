extends RefCounted
## Continuous clearance certifies the trail graph and every attachment to it.

const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const RADIUS := 0.64
const ATTACH_DISTANCE := 5.5
const POINT_STRIDE := 3
const SHORTCUT_DISTANCE := 4.0
const MAX_ATTACH_CHECKS := 20

var surface: Surface
var graph := AStar2D.new()
var points := PackedVector2Array()
var room_points := {}
var edge_points := {}
var certified := {}
var _links: Array[Vector2i] = []
var _metadata := {}

func _init(play_surface: Surface) -> void:
	surface = play_surface
	var network: Dictionary = surface.layout.trail_network
	for room: String in network.nodes:
		var at: Vector2 = network.nodes[room]
		if surface.walkable(at, RADIUS):
			room_points[room] = _add(at)
	for i in network.edges.size():
		_add_trail(network.edges[i], surface.layout.paths[i].spine)
	_metadata = _describe(network)

func _add(at: Vector2) -> int:
	var id := points.size()
	points.append(at)
	graph.add_point(id, at)
	return id

func _add_trail(edge: Dictionary, spine: PackedVector2Array) -> void:
	if not room_points.has(edge.from) or not room_points.has(edge.to):
		return
	# A centerline turn may need its original dense samples to preserve clearance.
	var samples := PackedVector2Array([spine[0]])
	var anchor := 0
	for i in range(1, spine.size()):
		if not traversable(spine[i - 1], spine[i]):
			return
		if i - anchor >= POINT_STRIDE or i == spine.size() - 1:
			if not traversable(spine[anchor], spine[i]):
				for j in range(anchor + 1, i):
					samples.append(spine[j])
			samples.append(spine[i])
			anchor = i
	var ids := PackedInt32Array([room_points[edge.from]])
	for i in range(1, samples.size() - 1):
		ids.append(_add(samples[i]))
	ids.append(room_points[edge.to])
	for i in range(1, ids.size()):
		graph.connect_points(ids[i - 1], ids[i])
		_links.append(Vector2i(ids[i - 1], ids[i]))
	edge_points[edge.id] = samples
	certified[edge.id] = true

func traversable(from: Vector2, to: Vector2, exclusions: Array = []) -> bool:
	return (surface.walkable(from, RADIUS) and _outside_disks(from, to, exclusions)
		and surface.travel(from, to, RADIUS).is_equal_approx(to))

func _outside_disks(from: Vector2, to: Vector2, exclusions: Array) -> bool:
	for disk: Dictionary in exclusions:
		var at: Vector2 = disk.center
		var nearest := Geometry2D.get_closest_point_to_segment(at, from, to) if from != to else from
		# Allow retreat from a newly occupied start, without stepping farther in.
		if nearest.distance_squared_to(at) < disk.radius * disk.radius:
			if nearest != from or to.distance_squared_to(at) <= from.distance_squared_to(at):
				return false
	return true

func route(from: Vector2, to: Vector2, exclusions: Array = []) -> PackedVector2Array:
	if not surface.walkable(from, RADIUS) or not surface.walkable(to, RADIUS):
		return PackedVector2Array()
	if from.distance_squared_to(to) <= SHORTCUT_DISTANCE * SHORTCUT_DISTANCE and traversable(from, to, exclusions):
		return PackedVector2Array([to])
	var start := points.size()
	var finish := start + 1
	graph.add_point(start, from)
	graph.add_point(finish, to)
	var detached: Array[Vector2i] = []
	if not exclusions.is_empty():
		for link in _links:
			var a := points[link.x]
			var b := points[link.y]
			if not _outside_disks(a, b, exclusions) or not _outside_disks(b, a, exclusions):
				graph.disconnect_points(link.x, link.y)
				detached.append(link)
	var detours := _add_detours(start, finish, exclusions)
	_attach(start, from, exclusions, false)
	_attach(finish, to, exclusions, true)
	var ids := graph.get_id_path(start, finish)
	var result := PackedVector2Array()
	for i in range(1, ids.size()):
		result.append(graph.get_point_position(ids[i]))
	graph.remove_point(start)
	graph.remove_point(finish)
	for id in detours:
		graph.remove_point(id)
	for link in detached:
		graph.connect_points(link.x, link.y)
	return result

func _attach(id: int, at: Vector2, exclusions: Array, toward_anchor: bool) -> void:
	var options: Array[int] = []
	for i in points.size():
		if at.distance_squared_to(points[i]) <= ATTACH_DISTANCE * ATTACH_DISTANCE:
			options.append(i)
	options.sort_custom(func(a: int, b: int):
		var da := at.distance_squared_to(points[a])
		var db := at.distance_squared_to(points[b])
		return a < b if da == db else da < db)
	var connected := 0
	for other in options.slice(0, MAX_ATTACH_CHECKS):
		var from := points[other] if toward_anchor else at
		var to := at if toward_anchor else points[other]
		if traversable(from, to, exclusions):
			graph.connect_points(other if toward_anchor else id, id if toward_anchor else other, false)
			connected += 1
			if connected == 5:
				break

func _add_detours(start: int, finish: int, exclusions: Array) -> Array[int]:
	var detours: Array[int] = []
	for disk: Dictionary in exclusions:
		for i in 8:
			var at: Vector2 = disk.center + Vector2.from_angle(TAU * i / 8.0) * (disk.radius + 0.35)
			if not surface.walkable(at, RADIUS):
				continue
			var id := finish + 1 + detours.size()
			graph.add_point(id, at)
			_attach(id, at, exclusions, false)
			_attach(id, at, exclusions, true)
			var neighbors := detours.duplicate()
			neighbors.append_array([start, finish])
			for other in neighbors:
				var anchor := graph.get_point_position(other)
				if anchor.distance_squared_to(at) > 9.0:
					continue
				if other != finish and traversable(anchor, at, exclusions):
					graph.connect_points(other, id, false)
				if other != start and traversable(at, anchor, exclusions):
					graph.connect_points(id, other, false)
			detours.append(id)
	return detours

func room_reachable(from: String, to: String) -> bool:
	if not room_points.has(from) or not room_points.has(to):
		return false
	return not graph.get_id_path(room_points[from], room_points[to]).is_empty()

func _describe(network: Dictionary) -> Dictionary:
	var result := {"crossings": [], "chokepoints": [], "alternate_routes": [], "cover": [],
		"encounter_regions": [], "ambush_candidates": []}
	for edge: Dictionary in network.edges:
		if not certified.has(edge.id):
			continue
		var note := {"id": edge.id, "from": edge.from, "to": edge.to,
			"width": edge.width * 2.0, "position": edge_points[edge.id][edge_points[edge.id].size() / 2]}
		if edge.get("bridge", false) or edge.from == "dry_crossing" or edge.to == "dry_crossing":
			note["kind"] = "bridge" if edge.get("bridge", false) else "dry_crossing"
			result.crossings.append(note)
		if _alternate(network.edges, edge):
			result.alternate_routes.append(edge.id)
		elif note.width <= 2.0:
			result.chokepoints.append(note)
	for block: Dictionary in surface.blockers:
		result.cover.append({"id": block.id, "kind": block.kind, "bounds": block.bounds})
	for id: String in surface.layout.get("combat_rooms", []):
		if not room_reachable("arrival", id):
			continue
		var center: Vector2 = network.nodes[id]
		result.encounter_regions.append({"id": id, "position": center})
		for i in 12:
			var at := center + Vector2.from_angle(TAU * i / 12.0) * 1.8
			if traversable(center, at) and not surface.clear_line(network.nodes.arrival, at):
				result.ambush_candidates.append({"room": id, "position": at})
				break
	return result

func _alternate(edges: Array, skip: Dictionary) -> bool:
	var visited := {skip.from: true}
	var pending: Array = [skip.from]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		for edge: Dictionary in edges:
			if edge.id == skip.id or not certified.has(edge.id):
				continue
			var other: String = edge.to if edge.from == current else edge.from if edge.to == current else ""
			if other == skip.to:
				return true
			if not other.is_empty() and not visited.has(other):
				visited[other] = true
				pending.append(other)
	return false

func tactical_metadata() -> Dictionary:
	return _metadata.duplicate(true)
