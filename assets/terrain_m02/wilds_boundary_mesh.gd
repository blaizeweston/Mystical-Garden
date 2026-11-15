extends RefCounted
## Keep the shared inner edge at ground height so the visible stop matches the playable polygon.

const Boundary = preload("res://assets/terrain_m02/wilds_boundary.gd")
const Roots = preload("res://assets/terrain_m02/terrain_root_mesh.gd")

static func build(border: Dictionary, seed_value: int, steep_front: bool = false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strips: Array = border.rim
	for i in strips.size():
		var strip: Dictionary = strips[i]
		if strip.wet:
			continue
		_strip(tool, strip, strips[posmod(i - 1, strips.size())], strips[(i + 1) % strips.size()], seed_value, steep_front)
	return tool.commit()

static func _strip(tool: SurfaceTool, strip: Dictionary, previous: Dictionary, next: Dictionary,
		seed_value: int, steep_front: bool) -> void:
	var family: int = strip.family
	var base: Color = [Color("#3d3827"), Color("#363e2c"), Color("#3d3734")][family]
	var crest: Color = [Color("#526442"), Color("#575c40"), Color("#796351")][family]
	var sections: Array[PackedVector3Array] = []
	var profile := [Vector2(0.0, 0.0), Vector2(0.17, 0.58), Vector2(0.43, 1.0), Vector2(0.75, 0.73), Vector2(1.0, 0.0)]
	if steep_front:
		# Anchor the toe at the same line that blocks movement.
		profile[1] = Vector2(0.08, 0.71)
		profile[2] = Vector2(0.31, 1.0)
	for i in strip.inner.size():
		var a: Vector2 = strip.inner[i]
		var b: Vector2 = strip.outer[i]
		var section := PackedVector3Array()
		var phase := float(strip.start + i) / Boundary.SAMPLES * TAU
		var elevation := (1.46 + 0.40 * sin(phase * 11.0 + seed_value % 37)
			+ 0.28 * cos(phase * 17.0)) * (1.63 if family == 2 else 0.93)
		if i == 0:
			elevation = 0.0 if previous.wet else 1.48
		elif i == strip.inner.size() - 1:
			elevation = 0.0 if next.wet else 1.48
		if steep_front:
			elevation *= 1.42
		for point: Vector2 in profile:
			var at := a.lerp(b, point.x)
			section.append(Vector3(at.x, maxf(0.013, point.y * elevation), at.y))
		sections.append(section)
		if i in [2, 5] and elevation > 0.62:
			var mid := a.lerp(b, 0.29)
			var back := a.lerp(b, 0.81)
			var root := Vector3(mid.x, elevation * 0.54, mid.y)
			var peak := Vector3(back.x, elevation * (1.62 if family == 2 else 1.17), back.y)
			var tangential := (strip.inner[i + 1] as Vector2) - a
			var toe := a.lerp(b, 0.57) + tangential * 1.5
			Roots._tube(tool, [root, root.lerp(peak, 0.49) + Vector3.UP * 0.26, peak, Vector3(toe.x, elevation * 0.54, toe.y)],
				[0.14, 0.25 if family == 2 else 0.18, 0.25, 0.032], crest.darkened(0.14))
	for i in range(1, sections.size()):
		var a := sections[i - 1]
		var b := sections[i]
		for j in 4:
			var color := base.lerp(crest, 0.72 if j == 2 else 0.28 + 0.11 * sin(i * 2.71 + j))
			Roots._face(tool, a[j], b[j], b[j + 1], color)
			Roots._face(tool, a[j], b[j + 1], a[j + 1], color)
