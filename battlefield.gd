extends RefCounted

const CoverShape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const REGION := Rect2i(-29, -28, 59, 57)
const CLEARANCE := 0.34
const LAYOUTS := [
	[Rect2(-8.4, -3.2, 3.7, 1.15), Rect2(4.0, -1.7, 1.25, 4.7), Rect2(-3.7, 2.4, 1.15, 3.4)],
	[Rect2(-6.7, -1.3, 1.2, 5.0), Rect2(4.1, -4.7, 4.0, 1.25), Rect2(2.6, 3.3, 4.7, 1.1)],
	[Rect2(-9.3, -0.9, 4.0, 1.2), Rect2(4.1, -4.2, 1.2, 5.6), Rect2(-0.5, 6.2, 4.5, 1.1)],
]

var distance_samples: Dictionary={}
var surface: RefCounted
var configured_key:=Vector3i(-1,-1,-1)
var navigation := AStarGrid2D.new()
var barriers: Array = []
var clearings: Array[Vector3] = []
var links: Array = []
var main_count := 0
var entry := Vector3(0, 0, -11.8)
var extraction := Vector3(0, 0, -13.9)
var advance := Vector3(0, 0, 13.2)
var graft := Vector3(-4.6, 0, 2.4)
var leader := Vector3(0, 0, 5.4)
var cache := Vector3.ZERO
var spawn_points: Array[Vector3] = []
var procedural := false
var routes := {}
var boss_kind: int=-1
var boss_phase: int=0

func has_seed_cache() -> bool:
	return procedural

func clear_seed_count(depth: int) -> int:
	return 1 if depth == 1 else 2


static func layout(site: int, encounter: int, map_seed: int = 0) -> Array:
	var field := new()
	field.configure(site, encounter, map_seed)
	return field.barriers


func configure(site: int, encounter: int, map_seed: int = 0, boss: int=-1, phase: int=0) -> void:
	boss_kind=boss;boss_phase=phase
	distance_samples.clear()
	surface=null
	configured_key=Vector3i(site,encounter,map_seed)
	procedural = map_seed != 0
	clearings.clear()
	links.clear()
	spawn_points.clear()
	if procedural:
		if boss>=0: generate_lair(boss,phase,map_seed)
		else: generate(site, encounter, map_seed)
	else:
		entry = Vector3(0, 0, -11.8)
		extraction = Vector3(0, 0, -13.9)
		advance = Vector3(0, 0, 13.2)
		graft = Vector3(-4.6, 0, 2.4)
		leader = Vector3(0, 0, 5.4)
		barriers = LAYOUTS[(site + encounter - 1) % LAYOUTS.size()].duplicate()
	if procedural:bake_surface()
	rebuild()
	if procedural and not connected():
		# Corridors guarantee a connected floor. Drop optional cover if it blocks a route.
		barriers.clear()
		rebuild()


func generate(site: int, encounter: int, map_seed: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = map_seed
	barriers = []
	main_count = random.randi_range(4, 6)
	var side := -1.0 if random.randf() < 0.5 else 1.0
	for i in main_count:
		var along := i / float(main_count - 1)
		var x := random.randf_range(-3.0, 3.0) if i == 0 else (
			side * random.randf_range(5.0, 10.2) if i % 2 == 1 else -side * random.randf_range(3.0, 8.7))
		var z := lerpf(-19.0, 19.0, along) + (random.randf_range(-1.0, 1.0) if i > 0 and i < main_count - 1 else 0.0)
		var radius := random.randf_range(4.1, 5.7) + (0.4 if site == 1 else 0.0)
		clearings.append(Vector3(x, z, radius))
		if i > 0:
			links.append([i - 1, i, random.randf_range(2.0, 2.8)])
	preload("res://wilds_layout.gd").shape(self,random,site)
	# A broad flank joins two clearings, giving the party an alternate approach.
	var branch_index := 1 if main_count == 4 else 2
	var center := clearings[branch_index]
	var branch := Vector3(-side * random.randf_range(15.0, 18.3), center.y + random.randf_range(-2.5, 3.0), 4.3)
	var branch_id := clearings.size()
	clearings.append(branch)
	links.append([branch_index, branch_id, 2.05])
	links.append([branch_id, mini(main_count - 1, branch_index + 1), 2.15])
	# A short spur ends in a small ruined clearing off the main route.
	var spur_center := clearings[main_count - 2]
	var spur_id := clearings.size()
	clearings.append(Vector3(side * random.randf_range(15.0, 18.0), spur_center.y + 0.4, 3.5))
	var cache_clearing: Vector3 = clearings.back()
	cache = Vector3(cache_clearing.x, 0, cache_clearing.y)
	links.append([main_count - 2, spur_id, 1.85])
	preload("res://wilds_layout.gd").place(self,random)
	for node in range(1, clearings.size()):
		var clearing := clearings[node]
		var angle := random.randf() * TAU
		var p := Vector2(clearing.x, clearing.y) + Vector2(cos(angle), sin(angle)) * clearing.z * 0.62
		var size := Vector2(random.randf_range(1.2, 2.3), random.randf_range(0.8, 1.5))
		if random.randf() < 0.5:
			size = Vector2(size.y, size.x)
		var cover := Rect2(p - size * 0.5, size)
		var obstructs := false
		for link in links:
			var a := clearings[link[0]]
			var b := clearings[link[1]]
			if intersects(Vector2(a.x, a.y), Vector2(b.x, b.y), cover.grow(0.8)):
				obstructs = true
		if not obstructs and inside_floor(Vector3(p.x, 0, p.y), 1.2):
			barriers.append(cover)


func bake_surface() -> void:
	surface=null;distance_samples.clear()
	var finished=preload("res://walkable_surface.gd").new()
	finished.build(self);surface=finished


func floor_distance(position: Vector3) -> float:
	return surface.distance(position) if surface!=null else source_distance(position)


func source_distance(position: Vector3) -> float:
	if not procedural:
		return 100.0
	var p := Vector2(position.x, position.z)
	var distance := -INF
	for clearing in clearings:
		distance = rounded_union(distance, clearing.z - p.distance_to(Vector2(clearing.x, clearing.y)))
	for link in links:
		var a := clearings[link[0]]
		var b := clearings[link[1]]
		var closest := Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.y), Vector2(b.x, b.y))
		distance = rounded_union(distance, float(link[2]) - p.distance_to(closest))
	return distance


# Blend nearby boundaries into a rounded, traversable junction.
# Rendering, collision and navigation all sample this same field.
static func rounded_union(a: float, b: float) -> float:
	if a == -INF:
		return b
	# The blend must accommodate the player diameter, not only join the
	# visible dirt. The old 1.8 blend left pinched seams below CLEARANCE.
	const JUNCTION_BLEND := 4.0
	var blend := maxf(JUNCTION_BLEND - absf(a - b), 0.0) / JUNCTION_BLEND
	return maxf(a, b) + blend * blend * JUNCTION_BLEND * 0.25


func sample_distance(position: Vector3) -> float:
	# Collision, navigation, floor clipping and root contours share half-unit
	# samples. Cache only complete configured geometry, never ad-hoc test fields.
	if not procedural or configured_key.x<0: return floor_distance(position)
	var grid:=Vector2(position.x,position.z)*2.;var key:=Vector2i(roundi(grid.x),roundi(grid.y))
	if absf(grid.x-key.x)>.0001 or absf(grid.y-key.y)>.0001: return floor_distance(position)
	if not distance_samples.has(key): distance_samples[key]=floor_distance(position)
	return float(distance_samples[key])


func inside_floor(position: Vector3, clearance: float = 0.0) -> bool:
	if not procedural:
		return REGION.has_point(Vector2i(roundi(position.x), roundi(position.z)))
	# The smoothed union of distance fields is 1-Lipschitz. A cached nearby
	# sample proves inside/outside away from edges; ambiguous edges stay exact.
	if configured_key.x>=0:
		var cell:=Vector2i(roundi(position.x*2),roundi(position.z*2))
		var center:=Vector3(cell.x*.5,0,cell.y*.5)
		if not distance_samples.has(cell): distance_samples[cell]=floor_distance(center)
		var value: float=distance_samples[cell];var error:=position.distance_to(center)+.00001
		if value-error>=clearance: return true
		if value+error<clearance: return false
	return floor_distance(position)>=clearance


func occupied(position: Vector3, clearance: float = 0.0) -> bool:
	if not inside_floor(position, clearance):
		return true
	var p := Vector2(position.x, position.z)
	for rect in barriers:
		if rect.grow(clearance).has_point(p):
			return true
	return false


func rebuild() -> void:
	routes.clear()
	navigation.clear()
	navigation.region = Rect2i(REGION.position * 2, REGION.size * 2)
	navigation.cell_size = Vector2(0.5, 0.5)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(navigation.region.position.x, navigation.region.end.x):
		for z in range(navigation.region.position.y, navigation.region.end.y):
			if occupied(Vector3(x * 0.5, 0, z * 0.5), CLEARANCE + 0.30):
				navigation.set_point_solid(Vector2i(x, z))


func connected() -> bool:
	var start := free_cell(entry)
	for p in [extraction, advance, graft, leader, cache] + spawn_points:
		if navigation.get_id_path(start, free_cell(p)).is_empty():
			return false
	for clearing in clearings:
		if navigation.get_id_path(start, free_cell(Vector3(clearing.x, 0, clearing.y))).is_empty():
			return false
	return true


func clear_line(from: Vector3, to: Vector3, clearance: float = 0.0) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for rect in barriers:
		if intersects(a, b, rect.grow(clearance)):
			return false
	if procedural:
		var count := maxi(1, ceili(from.distance_to(to) / 0.12))
		for i in range(count + 1):
			if not inside_floor(from.lerp(to, i / float(count)), clearance):
				return false
	return true


func projectile_block_fraction(from: Vector3, to: Vector3, radius: float) -> float:
	var start := Vector2(from.x, from.z)
	var end := Vector2(to.x, to.z)
	var bounds := Rect2(start.min(end), (end - start).abs()).grow(radius + CoverShape.TRACE_EPSILON)
	var fraction := INF
	for rect: Rect2 in barriers:
		if not bounds.intersects(rect, true):
			continue
		if rect.has_point(start):
			return 0.0
		fraction = minf(fraction, CoverShape.outline_entry(_rect_outline(rect), start, end, radius))
	if not procedural:
		var arena := Rect2(Vector2(REGION.position) - Vector2.ONE * .5, Vector2(REGION.size))
		if not arena.has_point(start):
			return 0.0
		return minf(fraction, CoverShape.outline_entry(_rect_outline(arena), start, end, radius))
	# Legacy procedural floors use the existing continuous floor-distance backing.
	var count := maxi(1, ceili(from.distance_to(to) / .12))
	for i in count + 1:
		var at := float(i) / count
		if at >= fraction:
			break
		if not inside_floor(from.lerp(to, at), radius):
			return at
	return fraction


static func _rect_outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])


func projectile_clear(from: Vector3, to: Vector3, radius: float = 0.0) -> bool:
	return projectile_block_fraction(from, to, radius) == INF


func projectile_endpoint(from: Vector3, to: Vector3, radius: float) -> Vector3:
	var fraction := projectile_block_fraction(from, to, radius)
	return to if fraction == INF else from.lerp(to, fraction)


func combat_sight(from: Vector3, to: Vector3) -> bool:
	return projectile_clear(from, to)


static func intersects(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	return (
		Geometry2D.segment_intersects_segment(a, b, rect.position, top_right) != null
		or Geometry2D.segment_intersects_segment(a, b, top_right, rect.end) != null
		or Geometry2D.segment_intersects_segment(a, b, rect.end, bottom_left) != null
		or Geometry2D.segment_intersects_segment(a, b, bottom_left, rect.position) != null
	)


func slide(from: Vector3, to: Vector3) -> Vector3:
	if clear_line(from, to, CLEARANCE):
		return to
	var motion := to - from
	var best := from
	var best_progress := 0.0
	# Project onto nearby tangents rather than sticking to a single world axis.
	for angle in [0.0, -0.3, 0.3, -0.6, 0.6, -0.9, 0.9, -1.2, 1.2]:
		var direction := motion.rotated(Vector3.UP, angle)
		direction *= maxf(0.0, cos(angle))
		var candidate := from + direction
		var progress := direction.dot(motion)
		if progress > best_progress and clear_line(from, candidate, CLEARANCE):
			best = candidate
			best_progress = progress
	for candidate in [Vector3(to.x, 0, from.z), Vector3(from.x, 0, to.z)]:
		var progress: float = (candidate - from).dot(motion)
		if progress > best_progress and clear_line(from, candidate, CLEARANCE):
			best = candidate
			best_progress = progress
	return best

func dash(from: Vector3, to: Vector3) -> Vector3:
	var previous := from
	var steps := maxi(12, ceili(from.distance_to(to) / 0.18))
	for step in steps:
		var next := from.lerp(to, (step + 1) / float(steps))
		if not clear_line(previous, next, CLEARANCE):
			break
		previous = next
	return previous


func navigate(from: Vector3, to: Vector3, distance: float, route_id: int = 0) -> Vector3:
	if clear_line(from, to, CLEARANCE + 0.12):
		routes.erase(route_id)
		return dash(from, from.move_toward(to, distance))
	var route: Dictionary = routes.get(route_id, {})
	if route.is_empty() or route.target.distance_to(to) > 0.85:
		route = {"target": to, "points": navigation.get_point_path(free_cell(from), free_cell(to)), "index": 0}
		routes[route_id] = route
	var points: PackedVector2Array = route.points
	while route.index < points.size():
		var point := Vector3(points[route.index].x, 0, points[route.index].y)
		if from.distance_to(point) > 0.06:
			break
		route.index += 1
	if route.index >= points.size():
		return dash(from, from.move_toward(to, distance))
	if int(route.get("smoothed_index",-1))!=int(route.index):
		for i in range(points.size()-1,int(route.index),-1):
			var candidate:=Vector3(points[i].x,0,points[i].y)
			if clear_line(from,candidate,CLEARANCE+.10): route.index=i;break
		route.smoothed_index=route.index
	var waypoint := Vector3(points[route.index].x, 0, points[route.index].y)
	var moved := dash(from, from.move_toward(waypoint, distance))
	if moved.distance_to(from) < 0.001:
		routes.erase(route_id)
	return moved

func free_cell(position: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(position.x * 2.0), roundi(position.z * 2.0)).clamp(navigation.region.position, navigation.region.end - Vector2i.ONE)
	if not navigation.is_point_solid(cell) and clear_line(position, Vector3(cell.x * 0.5, 0, cell.y * 0.5), CLEARANCE):
		return cell
	for radius in range(1, 7):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, z)
				if navigation.region.has_point(candidate) and not navigation.is_point_solid(candidate):
					var point := Vector3(candidate.x * 0.5, 0, candidate.y * 0.5)
					if clear_line(position, point, CLEARANCE):
						return candidate
	return cell

func generate_lair(kind: int,phase: int,seed_value: int) -> void:
	barriers=[];main_count=1
	var radius:=22.0 if kind==20 else 16.5 if kind==21 else 15.0 if kind==22 else 17.5
	clearings.append(Vector3(0,0,radius))
	clearings.append(Vector3(0,-21,4.0));links.append([0,1,4.0])
	clearings.append(Vector3(0,21,4.0));links.append([0,2,4.0])
	entry=Vector3(0,0,-21);extraction=Vector3(0,0,-22);advance=Vector3(0,0,22)
	leader=Vector3(0,0,5);graft=Vector3(-radius*.6,0,-3);cache=Vector3(radius*.6,0,-3)
	for i in 12:
		var angle:=TAU*i/12.0
		spawn_points.append(Vector3(cos(angle),0,sin(angle))*radius*.6+Vector3(0,0,3))
	if kind==22:
		var nest=preload("res://boss_nest_layout.gd")
		barriers=nest.ribs(phase)
		for index in range(spawn_points.size()-1,-1,-1):
			if nest.blocked(barriers,spawn_points[index],CLEARANCE+.45):spawn_points.remove_at(index)
