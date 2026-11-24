extends RefCounted
## Owns live structure placement. Crop contents stay in Progress, keyed by plot slot.

const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Forest = preload("res://assets/terrain_m02/garden_forest_barrier.gd")
const Knowledge = preload("res://assets/terrain_m02/garden_knowledge.gd")
const Heart = preload("res://assets/terrain_m02/terrain_heart_preview.gd")
const Stations = preload("res://assets/terrain_m02/garden_station_art.gd")
const Motion = preload("res://assets/terrain_m02/terrain_actor_motion.gd")
static var _walking_outlines := {}
const WALK_RADIUS := Motion.RADIUS_M
const STEP := 0.47
const MARGIN := 0.045
const THICKET_RADIUS := 0.60
const CATALOG := preload("res://garden_structure_catalog.gd").DEFINITIONS
const CARDINAL := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var forest: Forest
var knowledge: Knowledge
var records := {}
var next_id := 1
var _heart_reservation: Dictionary
var _grid := {}
var _revision := -1
var _marks := {}
var _fixed_goals: Array = []
var _terrain_links := {} # Only stationary doors and essential approach points are cached.
var _door_sites := {}
var _thickets: Array = []

func _init(barrier: Forest) -> void:
	forest = barrier
	_heart_reservation = Shape.shape("heart", "heart_base", Heart.maximum_base_outline())

func footprint(kind: String, at: Vector2, yaw: float) -> Dictionary:
	var half: Vector2 = CATALOG[kind].half
	var corners := PackedVector2Array()
	for sign_pair in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		corners.append(at + (half * sign_pair).rotated(yaw))
	return Shape.shape("construction", kind, corners)

func validate(kind: String, at: Vector2, yaw: float, pawn: Vector2, moving: int = 0) -> String:
	return placement_issue(kind, at, yaw, pawn, moving).get("message", "")

func placement_issue(kind: String, at: Vector2, yaw: float, pawn: Vector2, moving: int = 0) -> Dictionary:
	if not CATALOG.has(kind) or not at.is_finite() or not is_finite(yaw):
		return _issue("Choose a Garden structure.")
	if knowledge != null and moving == 0 and not CATALOG[kind].buildable:
		return _issue("The starting Garden Altar can only be moved.")
	if moving != 0 and (not records.has(moving) or records[moving].kind != kind):
		return _issue("Select a placed structure to move.")
	if knowledge != null and kind in ["archive","study"] and moving == 0:
		for entry: Dictionary in records.values():
			if entry.kind == kind:
				return _issue("The %s is already placed. Relocate it in Move mode." % CATALOG[kind].name, entry.footprint)
	if moving == 0 and knowledge != null:
		var refusal := knowledge.construction_refusal(kind, records)
		if not refusal.is_empty():
			return _issue(refusal)
	var area := footprint(kind, at, yaw)
	var garden = forest.garden
	if kind == "intake" and not preload("res://garden_water.gd").intake_shore(garden.layout.water, at).is_finite():
		return _issue("Place the Water Intake on dry ground beside a natural water edge.")
	if not _inside(area.outline, forest.visible_outline):
		return _issue("Keep the full footprint inside the reclaimed forest edge.")
	if Shape.signed_distance(area, pawn, WALK_RADIUS + 0.01) <= WALK_RADIUS:
		return _issue("Move the player clear of the footprint.", Shape.disk("player", "player", pawn, WALK_RADIUS))
	for feature: Dictionary in garden.layout.water:
		if _overlaps(area, feature):
			return _issue("The footprint crosses water.", feature)
	for landmark: Dictionary in garden.landmarks.values():
		if not landmark.get("blocks_construction",true): continue
		var restriction: Dictionary = _heart_reservation if landmark.id == "heart" else landmark
		if _overlaps(area, restriction):
			var name: String = landmark.id.replace("_", " ")
			if landmark.id == "heart": name = "fully grown Heart's base"
			return _issue("Keep clear of the %s. Its reserved area is outlined." % name, restriction)
	for feature: Dictionary in garden.layout.paths + garden.layout.get("path_joins", []):
		if _overlaps(area, feature, MARGIN):
			return _issue("Keep the permanent Wilds approach clear.", feature, WALK_RADIUS)
	for obstacle: Dictionary in garden.occupied:
		if _overlaps(area, obstacle):
			return _issue("A trunk or rock crosses the footprint.", obstacle)
	for id: int in records:
		if id != moving and _overlaps(area, records[id].footprint):
			return _issue("The footprint overlaps another structure.", records[id].footprint)
	var land := _check_ownership(area)
	if not land.is_empty():
		return land
	if _revision != garden.revision:
		_build_grid()
	for thicket: Dictionary in _thickets:
		if _overlaps(area, thicket):
			return _issue("Give the blocking forest thicket more room.", thicket)
	var candidate := {"kind": kind, "at": at, "yaw": yaw, "footprint": area}
	if not _access(candidate, pawn, moving):
		return _issue("Leave a walkable approach to doors, essential stations, and the player.")
	return {}

func _issue(message: String, blocker: Dictionary = {}, padding: float = MARGIN) -> Dictionary:
	return {"message": message, "blocker": blocker, "padding": padding}

func commit(kind: String, at: Vector2, yaw: float, pawn: Vector2, moving: int = 0) -> int:
	if not validate(kind, at, yaw, pawn, moving).is_empty():
		return 0
	var id := moving if moving != 0 else next_id
	if moving == 0:
		records[id] = {"id": id, "kind": kind, "state": {"crop": "", "growth": 0.0}}
		next_id += 1
	records[id].merge({"at": at, "yaw": yaw, "footprint": footprint(kind, at, yaw)}, true)
	_sync_obstacles()
	return id

func interaction_at(at: Vector2) -> Dictionary:
	var nearest := {}
	var reach := 0.72
	for entry: Dictionary in records.values():
		var door := _door_position(entry)
		var distance := at.distance_to(door)
		if distance < reach and forest.walkable(at.lerp(door, 0.5), WALK_RADIUS + distance * 0.5):
			nearest = entry
			reach = distance
	return nearest

func _sync_obstacles() -> void:
	var shapes: Array = []
	var reservations: Array = []
	for entry: Dictionary in records.values():
		shapes.append(walking_footprint(entry.kind, entry.at, entry.yaw))
		reservations.append(entry.footprint)
	forest.construction = shapes
	forest.garden.construction_clearance = reservations
	for id: int in records:
		var entry: Dictionary = records[id]
		forest.garden.construction_clearance.append(Shape.disk("access_%d" % id, "approach", _door_position(entry), WALK_RADIUS))
	_marks.clear()
	var current_doors := {}
	for id: int in records:
		_marks[id] = _nearby(records[id].footprint)
		current_doors[_door_position(records[id])] = true
	for point: Vector2 in _door_sites:
		if not current_doors.has(point): _terrain_links.erase(point)
	_door_sites = current_doors

func walking_footprint(kind: String, at: Vector2, yaw: float) -> Dictionary:
	if not _walking_outlines.has(kind):
		_walking_outlines[kind] = Shape.mesh_outline(Stations.build(CATALOG[kind].art, false))
	var points := PackedVector2Array()
	for point: Vector2 in _walking_outlines[kind]: points.append(at + point.rotated(yaw))
	return Shape.shape("construction", kind, points)

func _inside(inner: PackedVector2Array, outer: PackedVector2Array) -> bool:
	for point in inner:
		if Shape.polygon_distance(outer, point, MARGIN + 0.01) >= -MARGIN:
			return false
	# Clip catches a concave forest edge entering between two inside corners.
	return Geometry2D.clip_polygons(inner, outer).is_empty()

func _overlaps(area: Dictionary, feature: Dictionary, padding: float = MARGIN) -> bool:
	if not area.bounds.grow(padding).intersects(feature.bounds):
		return false
	if feature.has("radius"):
		return Shape.polygon_distance(area.outline, feature.center, feature.radius + padding + 0.01) <= feature.radius + padding
	if not Geometry2D.intersect_polygons(area.outline, feature.outline).is_empty():
		return true
	for point in area.outline:
		if Shape.signed_distance(feature, point, padding + 0.01) <= padding:
			return true
	for point in feature.outline:
		if Shape.polygon_distance(area.outline, point, padding + 0.01) <= padding:
			return true
	return false

func _check_ownership(area: Dictionary) -> Dictionary:
	var garden = forest.garden
	var spacing: float = garden.spacing
	var bounds: Rect2 = area.bounds
	var q_min := Grid.world_to_cell(Vector2(bounds.position.x, bounds.end.y), spacing).x - 2
	var q_max := Grid.world_to_cell(Vector2(bounds.end.x, bounds.position.y), spacing).x + 2
	var r_min := Grid.world_to_cell(bounds.position, spacing).y - 2
	var r_max := Grid.world_to_cell(bounds.end, spacing).y + 2
	for q in range(q_min, q_max + 1):
		for r in range(r_min, r_max + 1):
			var cell := Vector2i(q, r)
			if garden.owned.has(cell):
				continue
			if not bounds.grow(spacing).has_point(Grid.cell_to_world(cell, spacing)):
				continue
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(Grid.key_to_world(Grid.corner_key(cell, i), spacing))
			if not Geometry2D.intersect_polygons(area.outline, hex).is_empty():
				return _issue("The footprint touches an unclaimed hex.", Shape.shape("unclaimed", "hex", hex), 0.0)
	return {}

func _grid_key(at: Vector2) -> Vector2i:
	return Vector2i((at / STEP).round())

func _build_grid() -> void:
	_terrain_links.clear()
	_grid.clear()
	_thickets.clear()
	for at in forest.thicket_centres():
		_thickets.append(Shape.disk("forest", "thicket", at, THICKET_RADIUS))
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	for point in forest.visible_outline:
		bounds = bounds.expand(point)
	var first := _grid_key(bounds.position) - Vector2i.ONE
	var last := _grid_key(bounds.end) + Vector2i.ONE
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var cell := Vector2i(x, y)
			if forest.fixed_walkable(Vector2(cell) * STEP, WALK_RADIUS + STEP * 0.5):
				_grid[cell] = true
	_revision = forest.garden.revision
	_fixed_goals.clear()
	for water: Dictionary in forest.garden.layout.water:
		var banks: Array[Vector2] = []
		var shore := Shape.boundary(water)
		for index in range(0,shore.size(),3):
			var at: Vector2 = shore[index] + (shore[index]-water.bounds.get_center()).normalized()*0.65
			if forest.fixed_walkable(at,WALK_RADIUS): banks.append(at)
		if not banks.is_empty(): _fixed_goals.append(banks)
	for feature: Dictionary in forest.garden.landmarks.values():
		var physical_service: bool = feature.id == "native_station_living_archive" or (str(feature.id).begins_with("interaction_") and feature.get("blocks_construction",true))
		if feature.id == "wilds_entrance" or (not physical_service and not feature.get("requires_access",true)):
			continue
		var targets: Array[Vector2] = []
		for angle in 16:
			var center: Vector2 = feature.center
			var distance: float = (1.0 if feature.id == "heart" else feature.radius) + 0.64
			var at := center + Vector2.from_angle(TAU * angle / 16.0) * distance
			if forest.fixed_walkable(at, WALK_RADIUS):
				targets.append(at)
		# An authored point outside an older clearing becomes a goal once its approach is reclaimed.
		if not targets.is_empty() or not physical_service: _fixed_goals.append(targets)

func _nearby(area: Dictionary) -> Dictionary:
	var result := {}
	var reach := WALK_RADIUS + STEP * 0.5
	var bounds: Rect2 = area.bounds.grow(reach)
	var first := _grid_key(bounds.position) - Vector2i.ONE
	var last := _grid_key(bounds.end) + Vector2i.ONE
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var id := Vector2i(x, y)
			if Shape.signed_distance(area, Vector2(id) * STEP, reach + 0.01) <= reach:
				result[id] = true
	return result

func _access(candidate: Dictionary, pawn: Vector2, moving: int) -> bool:
	var shapes: Array = [candidate.footprint]
	var blocked := _nearby(candidate.footprint)
	for id: int in records:
		if id != moving:
			shapes.append(records[id].footprint)
			blocked.merge(_marks[id])
	var origin: Vector2 = forest.garden.landmarks.wilds_entrance.center
	var source := _connections(origin, shapes, blocked,true)
	if source.is_empty():
		return false
	var goals: Array = [_connections(pawn, shapes, blocked), _connections(_door_position(candidate), shapes, blocked)]
	for id: int in records:
		if id != moving:
			goals.append(_connections(_door_position(records[id]), shapes, blocked,true))
	for fixed: Array[Vector2] in _fixed_goals:
		var targets := {}
		for point in fixed:
			targets.merge(_connections(point, shapes, blocked,true))
		goals.append(targets)
	for goal: Dictionary in goals:
		if goal.is_empty():
			return false
	var seen: Dictionary = source.duplicate()
	var queue: Array = source.keys()
	var lookup := {}
	for i in goals.size():
		for id in goals[i]:
			if not lookup.has(id):
				lookup[id] = []
			lookup[id].append(i)
	var reached := {}
	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		if lookup.has(current):
			for i in lookup[current]:
				reached[i] = true
			if reached.size() == goals.size():
				return true
		for direction: Vector2i in CARDINAL:
			var next := current + direction
			if _grid.has(next) and not blocked.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return false

func _door_position(entry: Dictionary) -> Vector2:
	var front := Vector2(0, CATALOG[entry.kind].half.y + 0.70)
	return entry.at + front.rotated(entry.yaw)

func _fixed_connections(at: Vector2, stationary: bool) -> Array:
	if stationary and _terrain_links.has(at): return _terrain_links[at]
	var links := []
	if forest.fixed_walkable(at, WALK_RADIUS):
		var center := _grid_key(at)
		for x in range(-1, 2):
			for y in range(-1, 2):
				var id := center + Vector2i(x,y)
				if not _grid.has(id): continue
				var mid := at.lerp(Vector2(id)*STEP,0.5)
				var clearance := WALK_RADIUS + at.distance_to(Vector2(id)*STEP)*0.5
				if forest.fixed_walkable(mid,clearance): links.append([id,mid,clearance])
	if stationary: _terrain_links[at] = links
	return links

func _connections(at: Vector2, shapes: Array, blocked: Dictionary, stationary := false) -> Dictionary:
	var result := {}
	var nearby := []
	for obstacle: Dictionary in shapes:
		if obstacle.bounds.grow(1.5).has_point(at): nearby.append(obstacle)
	if Shape.in_any(nearby,at,WALK_RADIUS): return result
	for link: Array in _fixed_connections(at,stationary):
		if not blocked.has(link[0]) and not Shape.in_any(nearby,link[1],link[2]):
			result[link[0]] = true
	return result

func adopt_owned(kind: String, at: Vector2) -> int:
	# Adopt an already owned structure, without a purchase or crop-content copy.
	assert(CATALOG.has(kind) and at.is_finite())
	var id := next_id
	next_id += 1
	records[id] = {"id": id, "kind": kind, "at": at, "yaw": 0.0,
		"footprint": footprint(kind, at, 0.0)}
	_sync_obstacles()
	_revision = -1
	return id

