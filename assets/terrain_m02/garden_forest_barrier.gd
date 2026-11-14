extends Node3D
## Closed terrain-lab boundary. The displayed sections and movement query
## share the same outline while the entrance remains inside the sanctuary.

const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Garden = preload("res://assets/terrain_m02/garden_expansion.gd")
const Wood = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const SAMPLE := 0.17

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

func bind(state: Garden) -> void:
	garden = state
	buildings = [Shape.disk("heart_trunk", "trunk", Vector2.ZERO, 1.0)]
	for id: String in state.landmarks:
		if id not in ["heart", "wilds_entrance"]:
			buildings.append(state.landmarks[id])
	visible_outline = state.outline
	target_outline = visible_outline
	if parts.is_empty():
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
		var mesh := MeshInstance3D.new()
		mesh.mesh = parts[i % parts.size()]
		mesh.material_override = bark
		add_child(mesh)
		sections.append({"mesh": mesh, "a": Vector2.INF, "b": Vector2.INF})
	begin_shape(state.outline, state.outline)
	update_shape(1.0)

func begin_shape(from: PackedVector2Array, to: PackedVector2Array) -> void:
	starts = _radial_vertices(from)
	finishes = _radial_vertices(to)
	target_outline = to
	progress = -1.0

func update_shape(amount: float) -> void:
	# Each radial section keeps an identity. Only moved spans change their
	# transform. Ground thickets overlap their neighbors at both ends.
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
		var tangent := (b - a).normalized()
		var outside := Vector2(tangent.y, -tangent.x)
		var center := (a + b) * 0.5 + outside * 0.41
		var width := a.distance_to(b)
		var basis := Basis(Vector3(tangent.x, 0, tangent.y) * (width + 0.48), Vector3.UP,
			Vector3(outside.x, 0, outside.y))
		var mesh: MeshInstance3D = sections[i].mesh
		mesh.transform = Transform3D(basis, Vector3(center.x, 0, center.y))
		sections[i].a = a
		sections[i].b = b

func _radial_vertices(outline: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in Garden.FOREST_SECTORS:
		var dir := Vector2.from_angle(TAU * i / Garden.FOREST_SECTORS)
		points.append(dir * Garden.edge_distance(outline, dir))
	return points

func walkable(at: Vector2, radius: float = 0.34) -> bool:
	return (Shape.polygon_distance(visible_outline, at, radius + 0.03) < -radius
		and not Shape.in_any(garden.layout.water, at, radius)
		and not Shape.in_any(garden.occupied, at, radius)
		and not Shape.in_any(buildings, at, radius))

func move(at: Vector2, delta: Vector2) -> Vector2:
	var steps := maxi(1, ceili(delta.length() / SAMPLE))
	var position := at
	for i in range(1, steps + 1):
		var next := at + delta * (float(i) / steps)
		if not walkable(next):
			break
		position = next
	return position

func _understory(variant: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var random := RandomNumberGenerator.new()
	random.seed = 44276 + variant * 67
	# Dark scalloped interior, behind the visible tangle, fills the low gaps
	# actors would otherwise appear able to walk through.
	var previous := Vector3(-0.5, 1.65, 1.36)
	for i in range(1, 10):
		var x := -0.5 + i / 9.0
		var upper := Vector3(x, random.randf_range(1.42, 2.58), random.randf_range(1.05, 1.74))
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
	for i in 9:
		var x := random.randf_range(-0.50, 0.50)
		var direction := -1.0 if i % 2 == 0 else 1.0
		var rise := random.randf_range(0.35, 1.65)
		var points := [Vector3(x, -0.10, -0.39), Vector3(x + direction * 0.12, rise * 0.50, -0.04),
			Vector3(x - direction * 0.14, rise, 0.52), Vector3(x - direction * 0.28, rise * 0.82, 1.04)]
		Wood._tube(tool, points, [0.14, 0.15, 0.10, 0.015], Color("#39291f").lerp(Color("#65503a"), random.randf() * 0.5))
		var branch := [points[1], Vector3(x - direction * 0.24, rise * 0.92, 0.28),
			Vector3(x - direction * 0.32, rise * 1.18, 0.42)]
		Wood._tube(tool, branch, [0.086, 0.049, 0.004], Color("#513625"))
	for i in 21:
		var x := random.randf_range(-0.49, 0.49)
		var base := Vector3(x, 0.08, random.randf_range(-0.32, 0.93))
		var tip := base + Vector3(random.randf_range(-0.15, 0.23), random.randf_range(0.42, 1.28), 0.30)
		var fold := base.lerp(tip, 0.54) - Vector3.BACK * 0.16
		var wing := Vector3(random.randf_range(0.07, 0.16), 0.06, 0)
		var leaf := Color("#24331f").lerp(Color("#526041"), random.randf() * 0.68)
		Wood._face(tool, base, fold + wing, tip, leaf)
		Wood._face(tool, base, tip, fold - wing, leaf.lightened(0.10))
	return tool.commit()
