extends SceneTree

const Wilds = preload("res://assets/terrain_m02/wilds_preview_generation.gd")
const Biomes = preload("res://assets/terrain_m02/wilds_biome.gd")
const Catalog = preload("res://assets/terrain_m02/terrain_catalog.tres")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Nav = preload("res://assets/terrain_m02/wilds_combat_navigation.gd")
const Combat = preload("res://assets/terrain_m02/wilds_combat_simulation.gd")
const Preview = preload("res://assets/terrain_m02/terrain_preview.tscn")
const DT := 1.0 / 60.0

var errors := 0
var generation_failures := 0
var navigation_failures := 0
var completed := 0
var crossings := 0
var dry_crossings := 0
var queries := 0
var route_usec := 0
var route_peak_usec := 0
var route_failures := 0
var movement_usec := 0
var frames := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		errors += 1
		if errors <= 35:
			printerr("FAIL: ", message)

func run() -> void:
	for floor_number in [1, 5, 6, 7, 8, 9, 11, 12, 13, 14, 18]:
		for seed_value in [241, 823]:
			_floor(seed_value, floor_number, 14)
	_floor(517, 18, 28)
	_floor(823, 9, 28)
	_obstacles_and_attacks()
	_preview()
	check(generation_failures == 0 and navigation_failures == 0 and completed == 24,
		"all generated floors were cleared via moving combat")
	check(crossings >= 12 and dry_crossings > 0, "actual decks and natural dry routes were exercised")
	print("M10_METRICS ", JSON.stringify({"generation_failures": generation_failures,
		"navigation_failures": navigation_failures, "completed": completed, "decks_both_directions": crossings,
		"dry_crossings": dry_crossings, "path_queries": queries, "route_failures": route_failures,
		"mean_path_us": float(route_usec) / maxi(1, queries), "peak_path_us": route_peak_usec, "mean_update_us_excluding_path":
		float(movement_usec - route_usec) / maxi(1, frames), "physics_updates": frames}))
	if errors == 0:
		print("PASS: moving Wilds enemies, swept combat, tactical metadata and Gate-clear loops")
	quit(int(errors > 0))

func _layout(seed_value: int, floor_number: int, radius: int) -> Dictionary:
	return Wilds.build(seed_value, floor_number, radius, 1.75, Catalog, Biomes.WINDOWS, true, true, true, true)

func _floor(seed_value: int, floor_number: int, radius: int) -> void:
	var label := "%d/%d/%d" % [seed_value, floor_number, radius]
	var data := _layout(seed_value, floor_number, radius)
	if data.is_empty():
		generation_failures += 1
		check(false, "generation failed " + label)
		return
	var sim := Combat.new(Surface.new(data.cells, data.layout, 1.75))
	if not sim.ready:
		navigation_failures += 1
		check(false, "navigation rejected a generated floor " + label)
		return
	if floor_number in [1, 9, 18]:
		check(data == _layout(seed_value, floor_number, radius), "same input yields identical terrain " + label)
	check(sim.remaining() == 3 and not sim.gate_discovered and not sim.use_gate(), "arrival obscures sealed Gate " + label)
	var terrain: Dictionary = data.layout
	var notes := sim.navigation.tactical_metadata()
	check(notes.encounter_regions.size() == 2 and not notes.cover.is_empty(), "read-only regions and cover")
	notes.encounter_regions.clear()
	check(sim.navigation.tactical_metadata().encounter_regions.size() == 2, "returned metadata cannot mutate its owner")
	if terrain.trail_network.nodes.has("dry_crossing"):
		check(sim.navigation.room_reachable("arrival", "dry_crossing"), "natural dry crossing admits enemy clearance")
		dry_crossings += 1
	for deck in terrain.crossings:
		var span: PackedVector2Array = deck.bridge
		check(sim.navigation.traversable(span[0], span[1]) and sim.navigation.traversable(span[1], span[0]),
			"full clearance end to end on the actual bridge " + label + "/" + deck.id)
		crossings += 1
	if radius == 28:
		check(sim.navigation.tactical_metadata().crossings.size() >= terrain.crossings.size(),
			"tactical metadata includes certified large-map crossings")
	var arrival: Vector2 = terrain.trail_network.nodes.arrival
	var fight: Vector2 = terrain.trail_network.nodes.combat
	var floor_ok := _walk(sim, arrival, fight) and _wait_for_clears(sim, 1)
	check(floor_ok and not sim.gate_active(), "first moving encounter clears with Gate still sealed " + label)
	floor_ok = floor_ok and _walk(sim, sim.position, sim.gate) and _wait_for_clears(sim, 0)
	check(floor_ok and sim.gate_active() and sim.gate_discovered and sim.use_gate(), "finish through reached Gate " + label)
	completed += int(sim.finished)
	queries += sim.route_queries
	route_failures += sim.route_failures
	route_usec += sim.route_usec
	route_peak_usec = maxi(route_peak_usec, sim.route_peak_usec)
	movement_usec += sim.update_usec
	frames += sim.update_count
	if sim.route_failures > 0:
		print("M10_PURSUE_RETRY ", label, " no-route queries ", sim.route_failures, " cleared ", sim.finished)

func _walk(sim: Combat, start: Vector2, target: Vector2) -> bool:
	var route := sim.navigation.route(start, target)
	if route.is_empty():
		return false
	for at in route:
		for i in 60:
			if sim.health == 0:
				return false
			if sim.position.distance_to(at) < 0.025:
				break
			sim.move((at - sim.position).limit_length(4.6 * DT))
			sim.strike()
			sim.tick(DT)
			for actor in sim.encounters:
				if not sim.surface.walkable(actor.position, Nav.RADIUS):
					return false
		if sim.position.distance_to(at) >= 0.025:
			return false
	return true

func _wait_for_clears(sim: Combat, count: int) -> bool:
	for i in 300:
		if sim.health <= 0:
			return false
		if sim.remaining() <= count:
			return true
		var enemy := {}
		var best := INF
		for actor in sim.encounters:
			var distance := sim.position.distance_to(actor.position)
			if not actor.cleared and distance < best:
				best = distance
				enemy = actor
		if best > Combat.STRIKE - 0.15:
			sim.move((enemy.position - sim.position).limit_length(4.6 * DT))
		sim.strike()
		sim.tick(DT)
	return false

func _obstacles_and_attacks() -> void:
	var data := _layout(823, 9, 14)
	var sim := Combat.new(Surface.new(data.cells, data.layout, 1.75))
	var bridge: Dictionary = data.layout.crossings[0]
	var wet := Vector2.INF
	var water: Dictionary = data.layout.water[0]
	var bounds: Rect2 = water.bounds
	for i in 34:
		for j in 34:
			var sample := bounds.position + bounds.size * Vector2(i, j) / 34.0
			if (Shape.contains(water, sample) and Shape.contains(sim.surface.arena, sample)
					and not Shape.in_any(data.layout.crossings, sample, Nav.RADIUS)):
				wet = sample
				break
		if wet.is_finite():
			break
	check(wet.is_finite() and not sim.surface.walkable(wet, Nav.RADIUS), "water outside a deck blocks pursuit")
	for reverse in [false, true]:
		_bridge_pursuit(sim, bridge, reverse)
	var center := Vector2(0, 0)
	var a := Vector2(-5.0, 0.0)
	var b := Vector2(5.0, 0.0)
	var shape := Shape.disk("root", "root", center, 1.0)
	var graph := {"nodes": {"arrival": a, "combat": b, "exit_gate": b + Vector2.DOWN * 2.5}, "edges": []}
	var layout := {"masses": [shape], "rocks": [], "water": [], "crossings": [], "plants": [],
		"paths": [], "trail_network": graph, "combat_rooms": ["combat", "exit_gate"]}
	var grid: Dictionary = {}
	for cell in Surface.Grid.disk(9):
		grid[cell] = &"meadow"
	var surface := Surface.new(grid, layout, 1.75)
	sim.surface = surface
	sim.navigation = Nav.new(surface)
	sim.position = Vector2(2.0, 0.0)
	for actor in sim.encounters:
		actor.cleared = true
	sim.health = 100
	sim.projectiles = []
	var source := Vector2(-2.0, 0.0)
	var ranged := {"position": source, "role": "ranged", "state": "idle", "attack": 0.0, "retry": 0.0}
	sim._enemy_tick(ranged, DT)
	check(ranged.state == "idle", "roots block detection and ranged windup")
	# A shot already aiming before the obstruction appears uses swept collision at impact.
	ranged["aim"] = sim.position
	sim._resolve_attack(ranged)
	for i in 30:
		sim._projectile_tick(DT)
	check(sim.shots_blocked == 1 and sim.health == 100 and sim.projectiles.is_empty(), "a launched bolt cannot pass through the root")
	sim.position = Vector2(-4.0, 0)
	ranged.state = "idle"
	ranged.attack = 0.0
	sim._enemy_tick(ranged, DT)
	check(ranged.state == "windup", "a ranged enemy winds up with clear sight")
	sim._enemy_tick(ranged, Combat.SHOT_WINDUP + DT)
	for i in 16:
		sim._projectile_tick(DT)
	check(sim.health == 91, "the unobstructed windup and bolt deal damage")
	sim.health = 100
	sim.position = Vector2(-3.4, 0)
	var melee := {"position": source, "role": "melee"}
	sim._resolve_attack(melee)
	check(sim.health == 100, "melee outside range misses")
	sim.position = Vector2(-3.0, 0)
	sim._resolve_attack(melee)
	check(sim.health == 88, "melee attack resolves in range")
	sim.position = Vector2(-2.0, 0)
	sim.dodge_recovery = 0.0
	check(sim.dodge(Vector2.RIGHT), "dodge starts")
	for i in 18:
		sim.tick(DT)
	check(sim.position.x < -1.34 and sim.position.x > -1.65 and sim.surface.walkable(sim.position),
		"dodge sweeps the player's full footprint against the root")
	var slide := surface.slide(Vector2(-1.6, -0.1), Vector2(0.5, -0.65))
	check(slide.y < -0.5 and surface.walkable(slide), "sliding preserves movement along an obstruction")
	_recovery(sim, surface)

func _bridge_pursuit(sim: Combat, bridge: Dictionary, reverse: bool) -> void:
	var span: PackedVector2Array = bridge.bridge
	var start := span[1] if reverse else span[0]
	var far := span[0] if reverse else span[1]
	var axis := (far - start).normalized()
	var enemy := sim.encounters[0]
	sim.health = 100
	sim.projectiles.clear()
	for actor in sim.encounters:
		actor.cleared = actor != enemy
	enemy.position = start
	enemy.state = "idle"
	enemy.attack = 0.0
	enemy.retry = 0.0
	enemy.route = PackedVector2Array()
	enemy.index = 0
	sim.position = start + axis * 1.9
	if not sim.surface.walkable(sim.position):
		sim.position = start + axis * 1.5
	sim.tick(DT)
	check(enemy.state != "idle", "enemy detects a player at a bridge approach")
	sim.position = far + axis * 1.12
	if not sim.surface.walkable(sim.position):
		sim.position = far
	for i in 390:
		sim.tick(DT)
		if (enemy.position - far).dot(axis) >= -0.75:
			break
	check((enemy.position - far).dot(axis) >= -0.75 and sim.surface.walkable(enemy.position, Nav.RADIUS),
		"moving pursuit follows the bridge toward its far landing " + str(reverse))

func _recovery(sim: Combat, surface: Surface) -> void:
	# A broad approach admits a detour while an ally is paused mid-windup.
	var graph: Dictionary = surface.layout.trail_network
	var start := Vector2(-4.0, 3.0)
	var end := Vector2(4.0, 3.0)
	graph.nodes.arrival = start
	graph.nodes.combat = end
	graph.edges.append({"id": "approach", "from": "arrival", "to": "combat", "width": 1.4})
	surface.layout.paths.append({"spine": PackedVector2Array([start, Vector2(0, 3), end])})
	sim.navigation = Nav.new(surface)
	var path := sim.navigation.route(start, end, [{"center": Vector2(0, 3), "radius": 1.28}])
	var at := start
	var found_detour := false
	for next in path:
		check(sim.navigation.traversable(at, next, [{"center": Vector2(0, 3), "radius": 1.28}]),
			"every detour segment preserves clearance")
		found_detour = found_detour or absf(next.y - 3.0) > 0.35
		at = next
	check(found_detour and at == end, "route recovers around a blocking body")
	var narrow := Shape.disk("narrow", "root", Vector2(-1.05, 0), 0.35)
	var opposite := Shape.disk("opposite", "stone", Vector2(1.05, 0), 0.35)
	surface.blockers.append_array([narrow, opposite])
	check(not surface.travel(Vector2(0, -2), Vector2(0, 2)).is_equal_approx(Vector2(0, 2)),
		"root center still blocks the shortcut")
	surface.blockers.pop_front()
	check(surface.travel(Vector2(0, -2), Vector2(0, 2)).is_equal_approx(Vector2(0, 2))
		and sim.navigation.traversable(Vector2(0, -2), Vector2(0, 2)), "a 1.4-unit gap fits the enemy disk")
	surface.blockers[-1] = Shape.disk("opposite", "stone", Vector2(0.87, 0), 0.35)
	check(surface.travel(Vector2(0, -2), Vector2(0, 2)).is_equal_approx(Vector2(0, 2))
		and not sim.navigation.traversable(Vector2(0, -2), Vector2(0, 2)), "enemy radius rejects a player-only shortcut")
	sim.position = end
	var actor := sim.encounters[0]
	var ally := sim.encounters[1]
	actor.merge({"cleared": false, "position": start, "state": "pursuit", "route": PackedVector2Array(),
		"index": 0, "retry": 0.0, "stall": 0.0}, true)
	ally.merge({"cleared": false, "position": Vector2(0, 3), "state": "windup", "windup": 3.0}, true)
	for i in 265:
		sim.tick(DT)
		if actor.position.x > 0.9 and sim.route_recoveries > 0:
			break
	print("M10_RECOVERY ", actor.position, " recoveries=", sim.route_recoveries, " route=", actor.route,
		" index=", actor.index, " stall=", actor.stall, " ally=", ally.position, " health=", sim.health)
	check(actor.position.x > 0.9 and sim.route_recoveries > 0 and surface.walkable(actor.position, Nav.RADIUS),
		"stalled actor replans around a temporary obstruction without teleporting")

func _preview() -> void:
	var scene := Preview.instantiate()
	root.add_child(scene)
	scene.example.select(1)
	scene.example.item_selected.emit(1)
	check(scene.render_mode.selected == 11, "selecting Wilds defaults to M10")
	scene.get_node("%PlayFloor").button_pressed = true
	var run_view = scene.walk_preview
	check(run_view.run is Combat and run_view.fog.visible and not run_view.deck_gate.visible,
		"actual preview starts live combat behind fog")
	scene.render_mode.select(10)
	scene.render_mode.item_selected.emit(10)
	check(run_view.run != null and not run_view.run is Combat, "historical M09B comparator retains practice targets")
	scene.free()
