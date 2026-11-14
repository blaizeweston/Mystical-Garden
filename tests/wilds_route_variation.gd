extends SceneTree

const W = preload("res://assets/terrain_m02/wilds_preview_generation.gd")
const B = preload("res://assets/terrain_m02/wilds_biome.gd")
const C = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const V = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const S = preload("res://assets/terrain_m02/wilds_play_simulation.gd")
const Routes = preload("res://assets/terrain_m02/wilds_route_layout.gd")
const P = preload("res://assets/terrain_m02/terrain_preview.tscn")

var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		if errors < 32:
			printerr("FAIL: ", message)

func run() -> void:
	var stats := {"position_bins": {}, "gate_bins": {}, "directions": {}, "signatures": {}, "water_modes": {},
		"main_shapes": {}, "optional_counts": {}, "bridge_counts": {}, "clearing_min": INF, "clearing_max": 0.0,
		"length_min": INF, "length_max": 0.0, "repairs": 0, "repair_max": 0, "count": 0, "dry_saddle": 0,
		"wetland_alternatives": 0, "dry_hollow": 0, "open_lane": 0}
	for floor_number in [1, 6, 7, 9, 12, 13, 18]:
		for seed_value in [0, 1, 17, 117, 241, 517, 823, 3411, 9821]:
			_case(seed_value, floor_number, 14, 1.75, stats)
	for spec in [[1, 17, 28, 1.50], [9, 517, 28, 1.75], [18, 823, 28, 2.0],
			[9, 241, 14, 1.50], [13, 517, 14, 2.0], [7, 9821, 28, 1.50]]:
		_case(spec[1], spec[0], spec[2], spec[3], stats)
	_preview()
	check(stats.count == 69, "all representative floors are admitted")
	check(stats.position_bins.size() >= 10 and stats.gate_bins.size() >= 10 and stats.directions.size() == 8,
		"arrival and exit are distributed in space and direction")
	check(stats.main_shapes.size() >= 3 and stats.optional_counts.size() >= 4 and stats.signatures.size() >= 22,
		"graph shapes vary independently of heading, offsets and cosmetic dressing")
	var most := 0
	for count in stats.signatures.values():
		most = maxi(most, count)
	check(most < stats.count * 0.33, "no functionally identical route signature dominates")
	check(stats.length_max > stats.length_min * 2.0 and stats.clearing_max > stats.clearing_min * 2.0,
		"route lengths and clearing areas vary")
	check(stats.water_modes.size() >= 4 and stats.bridge_counts.has(0) and stats.bridge_counts.size() >= 3
		and stats.dry_saddle > 0 and stats.wetland_alternatives > 0 and stats.dry_hollow > 0
		and stats.open_lane > 0, "preview includes dry, open, bridged, ford and island layouts")
	check(stats.repairs < stats.count * 0.35 and stats.repair_max < Routes.ATTEMPTS, "repair stays bounded")
	for field in ["position_bins", "gate_bins", "directions", "signatures"]:
		stats[field + "_count"] = stats[field].size()
		stats.erase(field)
	stats["most_repeated_signature"] = most
	print("M09B_METRICS ", JSON.stringify(stats))
	if errors == 0:
		print("PASS: deterministic seeded landmarks, structure, water crossing and full Gate-clear sequences")
	quit(int(errors > 0))

func _case(seed_value: int, floor_number: int, radius: int, spacing: float, stats: Dictionary) -> void:
	var map := W.build(seed_value, floor_number, radius, spacing, C, B.WINDOWS, true, true, true)
	var label := "%d/%d/%d/%.2f" % [seed_value, floor_number, radius, spacing]
	check(not map.is_empty(), "valid floor " + label)
	if map.is_empty():
		return
	var layout: Dictionary = map.layout
	var sim := S.new(V.new(map.cells, layout, spacing))
	var graph: Dictionary = layout.trail_network
	check(sim.ready and sim.reachable.size() == graph.nodes.size(), "continuous reachability " + label)
	if not sim.ready:
		return
	if seed_value == 241 or radius == 28:
		check(map == W.build(seed_value, floor_number, radius, spacing, C, B.WINDOWS, true, true, true),
			"deterministic exact inputs " + label)
	var a: Vector2 = graph.nodes.arrival
	var gate: Vector2 = graph.nodes.exit_gate
	var length := _length(layout, "arrival", "exit_gate")
	var band := posmod(floori((gate - a).angle() / TAU * 8.0), 8)
	check(a.distance_to(gate) > radius * spacing * 0.65 and length >= a.distance_to(gate) - 0.01,
		"Gate separated from arrival " + label)
	stats.position_bins[Vector2i((a / (spacing * 3.0)).floor())] = true
	stats.gate_bins[Vector2i((gate / (spacing * 3.0)).floor())] = true
	stats.directions[band] = true
	stats.length_min = minf(stats.length_min, length)
	stats.length_max = maxf(stats.length_max, length)
	stats.repairs += int(layout.repair > 0)
	stats.repair_max = maxi(stats.repair_max, layout.repair)
	stats.count += 1
	stats.water_modes[layout.hydrology] = stats.water_modes.get(layout.hydrology, 0) + 1
	stats.dry_hollow += int(floor_number == 18 and layout.water.is_empty())
	stats.open_lane += int(graph.edges.any(func(edge: Dictionary): return edge.get("open_lane", false)))
	stats.dry_saddle += int(graph.nodes.has("dry_crossing"))
	stats.bridge_counts[layout.crossings.size()] = stats.bridge_counts.get(layout.crossings.size(), 0) + 1
	var island_bridges := 0
	for i in layout.crossings.size():
		var crossing: Dictionary = layout.crossings[i]
		var span: PackedVector2Array = crossing.bridge
		var wet := false
		for point in crossing.spine:
			wet = wet or Shape.in_any(layout.water, point)
		check(wet and not Shape.in_any(layout.water, span[0], 0.75) and not Shape.in_any(layout.water, span[1], 0.75),
			"visible deck spans wet ground with dry landings " + label)
		for j in i:
			var other: Dictionary = layout.crossings[j]
			check(Geometry2D.intersect_polygons(crossing.outline, other.outline).is_empty(), "bridge decks do not intersect")
		island_bridges += int(crossing.id.begins_with("island_"))
	stats.wetland_alternatives += int(island_bridges == 2 and graph.edges.size() >= graph.nodes.size())
	var degrees := {}
	for id in graph.nodes:
		degrees[id] = 0
	for edge in graph.edges:
		degrees[edge.from] += 1
		degrees[edge.to] += 1
	var branches := []
	var optional := 0
	for room in layout.clearings:
		var area := 0.0
		for i in room.outline.size():
			area += room.outline[i].cross(room.outline[(i + 1) % room.outline.size()])
		area = absf(area * 0.5)
		stats.clearing_min = minf(stats.clearing_min, area)
		stats.clearing_max = maxf(stats.clearing_max, area)
		if room.kind == "optional":
			optional += 1
			branches.append(degrees[room.id])
	var loops: int = graph.edges.size() - graph.nodes.size() + 1
	var main := str([degrees.arrival, degrees.combat, degrees.exit_gate, loops > 0])
	stats.main_shapes[main] = true
	branches.sort()
	var signature := str([main, loops, branches, layout.crossings.size(), layout.hydrology])
	stats.signatures[signature] = stats.signatures.get(signature, 0) + 1
	stats.optional_counts[optional] = stats.optional_counts.get(optional, 0) + 1
	_play(sim, layout, label)

func _route(layout: Dictionary, start: String, goal: String, main_only: bool) -> Array:
	var graph: Dictionary = layout.trail_network
	var reached := {start: []}
	var pending := [start]
	while not pending.is_empty():
		var id: String = pending.pop_front()
		if id == goal:
			return reached[id]
		for i in graph.edges.size():
			var edge: Dictionary = graph.edges[i]
			if main_only and not (edge.id.begins_with("gate_trail") or edge.id.begins_with("hunt_trail") or edge.id.begins_with("shortcut")):
				continue
			var next: String = edge.to if edge.from == id else edge.from if edge.to == id else ""
			if not next.is_empty() and not reached.has(next):
				reached[next] = reached[id] + [[i, edge.to == id]]
				pending.append(next)
	return []

func _length(layout: Dictionary, start: String, goal: String) -> float:
	var total := 0.0
	for step in _route(layout, start, goal, false):
		var spine: PackedVector2Array = layout.paths[step[0]].spine
		for i in range(1, spine.size()):
			total += spine[i - 1].distance_to(spine[i])
	return total

func _walk(sim: S, layout: Dictionary, start: String, goal: String) -> bool:
	var route := _route(layout, start, goal, true)
	if route.is_empty():
		return false
	for item in route:
		var spine: PackedVector2Array = layout.paths[item[0]].spine.duplicate()
		if item[1]:
			spine.reverse()
		for at in spine:
			sim.move(at - sim.position)
			if not sim.position.is_equal_approx(at):
				return false
	return true

func _play(sim: S, layout: Dictionary, label: String) -> void:
	check(not sim.gate_discovered and not sim.gate_active(), "starts with a hidden sealed Gate " + label)
	check(_walk(sim, layout, "arrival", "exit_gate"), "walk to Gate before optional areas " + label)
	check(sim.gate_discovered and not sim.use_gate(), "discovered Gate is still sealed")
	check(not sim.strike().is_empty() and sim.remaining() == 2, "clear Gate marker")
	check(_walk(sim, layout, "exit_gate", "combat"), "walk to required combat space")
	check(not sim.strike().is_empty() and not sim.gate_active(), "one uncleared marker keeps Gate sealed")
	check(not sim.strike().is_empty() and sim.gate_active(), "last marker activates Gate")
	check(_walk(sim, layout, "combat", "exit_gate") and sim.use_gate(), "finish without optional exploration " + label)

func _preview() -> void:
	var scene := P.instantiate()
	root.add_child(scene)
	scene.example.select(3)
	scene.example.item_selected.emit(3)
	check(scene.render_mode.selected == 10 and scene.scenic_ground != null, "M09B is default for Wilds")
	scene.get_node("%PlayFloor").button_pressed = true
	check(scene.walk_preview.run != null and scene.walk_preview.fog.visible and not scene.walk_preview.deck_gate.visible,
		"real preview begins with fog and unknown Gate")
	scene.render_mode.select(9)
	scene.render_mode.item_selected.emit(9)
	check(not scene.wilds.layout.has("hydrology"), "M09 remains available for comparison")
	scene.free()
