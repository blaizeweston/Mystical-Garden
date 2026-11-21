extends Node3D
## Closed terrain-lab boundary. The displayed sections and movement query
## share the same outline while the entrance remains inside the sanctuary.

const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")
const Wood = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const Motion = preload("res://assets/terrain_m02/terrain_actor_motion.gd")
const PropGeometry = preload("res://assets/terrain_m02/terrain_prop_geometry.gd")
const CLUMP_SPACING := 0.83

var garden: Garden
var visible_outline := PackedVector2Array()
var target_outline := PackedVector2Array()
var starts := PackedVector2Array()
var finishes := PackedVector2Array()
var progress := -1.0
var sections: Array[Dictionary] = []
var parts: Array[ArrayMesh] = []
var bark: StandardMaterial3D
var buildings: Array = []
var construction: Array = []
var _prop_bodies: Array = [] # Derived walking geometry; terrain/reclamation reservations stay in Garden.
var _render_tangle := true

func bind(state: Garden, render_tangle: bool = true) -> void:
	garden = state
	_render_tangle = render_tangle
	construction = []
	_prop_bodies.clear()
	for prop: Dictionary in state.layout.rocks: _prop_bodies.append(PropGeometry.actor_shape(prop))
	for plant: Dictionary in state.layout.plants:
		if plant.kind in ["tree", "sapling"]: _prop_bodies.append(PropGeometry.actor_shape(plant))
	buildings = [Shape.disk("heart_trunk", "trunk", Vector2.ZERO, 1.0)]
	for id: String in state.landmarks:
		if id not in ["heart", "wilds_entrance"] and state.landmarks[id].get("blocks_movement",true):
			buildings.append(state.landmarks[id])
	visible_outline = state.outline
	target_outline = visible_outline
	if _render_tangle and parts.is_empty():
		bark = StandardMaterial3D.new()
		bark.vertex_color_use_as_albedo = true
		bark.cull_mode = BaseMaterial3D.CULL_DISABLED
		bark.roughness = 0.95
		for variant in 4:
			parts.append(_understory(variant))
	for child in get_children():
		child.free()
	sections.clear()
	for i in Garden.FOREST_SECTORS:
		sections.append({"clumps": [], "a": Vector2.INF, "b": Vector2.INF})
	begin_shape(state.outline, state.outline)
	update_shape(1.0)

func begin_shape(from: PackedVector2Array, to: PackedVector2Array) -> void:
	starts = _radial_vertices(from)
	finishes = _radial_vertices(to)
	# Polygon union quantizes even untouched vertices. Carry the existing
	# sampled edge forward where the radial change is sub-millimetric.
	if visible_outline.size() == starts.size():
		for i in starts.size():
			if visible_outline[i].distance_squared_to(starts[i]) <= 0.000001:
				starts[i] = visible_outline[i]
	for i in starts.size():
		if starts[i].distance_squared_to(finishes[i]) <= 0.000001:
			finishes[i] = starts[i]
	target_outline = to
	progress = -1.0
	for i in sections.size():
		var next := (i + 1) % sections.size()
		var span := maxf(starts[i].distance_to(starts[next]), finishes[i].distance_to(finishes[next]))
		var clumps: Array = sections[i].clumps
		var needed := maxi(1, ceili(span / CLUMP_SPACING))
		while _render_tangle and clumps.size() < needed:
			var mesh := MeshInstance3D.new()
			mesh.mesh = parts[(i + clumps.size() * 3) % parts.size()]
			mesh.material_override = bark
			add_child(mesh)
			clumps.append(mesh)
		if sections[i].get("count", 0) != needed:
			sections[i].count = needed
			sections[i].a = Vector2.INF

func update_shape(amount: float) -> void:
	# Longer spans spread overlapping clumps of fixed size. Unchanged spans
	# retain their transforms and the collision outline remains continuous.
	if is_equal_approx(amount, progress):
		return
	progress = amount
	var outline := PackedVector2Array()
	for i in starts.size():
		outline.append(starts[i].lerp(finishes[i], amount))
	visible_outline = outline
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		if sections[i].a.is_equal_approx(a) and sections[i].b.is_equal_approx(b):
			continue
		var section := sections[i]
		var count: int = section.count
		for j in section.clumps.size():
			var mesh: MeshInstance3D = section.clumps[j]
			mesh.visible = j < count
			if not mesh.visible:
				continue
			mesh.transform = _clump_pose(a, b, i, j, count)
		sections[i].a = a
		sections[i].b = b

func thicket_centres() -> PackedVector2Array:
	# Construction consumes the existing forest clearances as detached geometry,
	# even when the active Garden does not instantiate the old visual tangle.
	var result := PackedVector2Array()
	for i in sections.size():
		var section := sections[i]
		for j in section.count:
			var pose := _clump_pose(section.a, section.b, i, j, section.count)
			result.append(Vector2(pose.origin.x, pose.origin.z))
	return result

func _clump_pose(a: Vector2, b: Vector2, sector: int, index: int, count: int) -> Transform3D:
	var tangent := (b - a).normalized()
	var outside := Vector2(tangent.y, -tangent.x)
	var gap := a.distance_to(b) / count
	var at := a.lerp(b, (index + 0.5) / count)
	var stagger := 0.08 * sin(sector * 2.39 + index * 1.36)
	at += outside * (0.36 + stagger + 0.54 * (1.0 - minf(1.0, gap / CLUMP_SPACING)) * float(index % 2))
	var yaw := atan2(tangent.y, -tangent.x) + 0.09 * sin(sector * 1.7 + index * 2.4)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0.0, at.y))

func _radial_vertices(outline: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in Garden.FOREST_SECTORS:
		var dir := Vector2.from_angle(TAU * i / Garden.FOREST_SECTORS)
		points.append(dir * Garden.edge_distance(outline, dir))
	return points

func walkable(at: Vector2, radius: float = Motion.RADIUS_M) -> bool:
	return fixed_walkable(at, radius) and Motion.obstacles_clearance(at, construction, radius + 0.03) > radius

func fixed_walkable(at: Vector2, radius: float = Motion.RADIUS_M) -> bool:
	return _fixed_clearance(at, radius + 0.03) > radius

func _fixed_clearance(at: Vector2, limit: float) -> float:
	return minf(-Shape.polygon_distance(visible_outline, at, limit), minf(
		Motion.water_clearance(at, garden.layout.water, [], limit), minf(
		Motion.obstacles_clearance(at, _prop_bodies, limit), Motion.obstacles_clearance(at, buildings, limit))))

func motion_clearance(at: Vector2) -> float:
	var limit := Motion.RADIUS_M + 0.05
	return minf(_fixed_clearance(at, limit), Motion.obstacles_clearance(at, construction, limit))

func travel(from: Vector2, to: Vector2, radius: float = Motion.RADIUS_M) -> Vector2:
	return Motion.travel(from, to, radius, walkable)

func move(at: Vector2, delta: Vector2) -> Vector2:
	return Motion.slide(at, delta, travel, motion_clearance)

func _understory(variant: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var random := RandomNumberGenerator.new()
	random.seed = 44276 + variant * 67
	# Dark scalloped interior, behind the visible tangle, fills the low gaps
	# actors would otherwise appear able to walk through.
	var previous := Vector3(-0.5, 1.48, 1.21)
	for i in range(1, 10):
		var x := -0.5 + i / 9.0
		var upper := Vector3(x, random.randf_range(1.23, 1.99), random.randf_range(1.08, 1.66))
		var a := Vector3(previous.x, -0.08, 0.48)
		var b := Vector3(upper.x, -0.08, 0.48)
		var notch := lerpf(0.31, 0.64, random.randf())
		var mid_a := Vector3(previous.x, 0.57, notch)
		var mid_b := Vector3(upper.x, 0.57, notch + 0.15)
		var tone := Color("#101510").lerp(Color("#233022"), random.randf_range(0.07, 0.44))
		Wood._face(tool, a, mid_a, mid_b, tone.darkened(0.35))
		Wood._face(tool, a, mid_b, b, tone.darkened(0.24))
		Wood._face(tool, mid_a, previous, upper, tone)
		Wood._face(tool, mid_a, upper, mid_b, tone.darkened(0.18))
		previous = upper
	for i in 7:
		var x := random.randf_range(-0.50, 0.50)
		var direction := -1.0 if i % 2 == 0 else 1.0
		var rise := random.randf_range(0.26, 1.34)
		var points := [Vector3(x, -0.10, -0.39), Vector3(x + direction * 0.12, rise * 0.50, -0.04),
			Vector3(x - direction * 0.14, rise, 0.52), Vector3(x - direction * 0.28, rise * 0.82, 1.04)]
		Wood._tube(tool, points, [0.11, 0.12, 0.08, 0.015], Color("#30241c").lerp(Color("#574630"), random.randf() * 0.44))
		var branch := [points[1], Vector3(x - direction * 0.24, rise * 0.92, 0.28),
			Vector3(x - direction * 0.32, rise * 1.18, 0.42)]
		Wood._tube(tool, branch, [0.075, 0.046, 0.004], Color("#3c3020"))
	for i in 34:
		var x := random.randf_range(-0.49, 0.49)
		var base := Vector3(x, 0.08, random.randf_range(-0.32, 0.93))
		var tip := base + Vector3(random.randf_range(-0.20, 0.27), random.randf_range(0.30, 1.36), 0.36)
		var fold := base.lerp(tip, 0.54) - Vector3.BACK * 0.16
		var wing := Vector3(random.randf_range(0.10, 0.26), 0.06, 0)
		var leaf := Color("#24331f").lerp(Color("#526041"), random.randf() * 0.62)
		Wood._face(tool, base, fold + wing, tip, leaf)
		Wood._face(tool, base, tip, fold - wing, leaf.lightened(0.10))
	return tool.commit()
