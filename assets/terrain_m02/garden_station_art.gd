extends RefCounted
## Mesh recipes for the terrain laboratory. Their origin is the interaction
## point and all projected geometry stays inside the supplied footprint.

const Wood = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const BED_SOIL_HEIGHT := 0.12
const BARK := Color("#3c2922")
const COPPER := Color("#956440")
const OLIVE := Color("#54613c")
const STONE := Color("#4c4840")
const SOIL := Color("#39241a")
const GARNET := Color("#672d2e")
const NAMES := {"starter_bed": "Cultivation bed", "altar": "Identification altar",
	"seed_archive": "Seed archive", "monster_studies": "Monster studies",
	"living_archive": "Living archive", "spring": "Watering spring"}

static func build(id: String, decorative_bed_shoots := true) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match id:
		"starter_bed":
			_bed(tool, decorative_bed_shoots)
		"altar":
			_basin(tool, 0.86, 0.77, STONE, GARNET)
			Wood._tube(tool, [Vector3(-0.41, 0.08, 0.42), Vector3(-0.42, 0.46, 0.19),
				Vector3(-0.11, 0.82, -0.23), Vector3(0.35, 0.91, -0.31)],
				[0.16, 0.14, 0.08, 0.02], BARK)
		"spring":
			_basin(tool, 0.89, 0.34, STONE, Color("#426a59"))
			Wood._tube(tool, [Vector3(-0.47, 0.02, -0.38), Vector3(-0.46, 0.57, -0.35),
				Vector3(-0.17, 0.64, -0.09), Vector3(-0.03, 0.61, 0.00)],
				[0.17, 0.12, 0.09, 0.058], BARK)
		_:
			_archive(tool, id)
	return tool.commit()

static func _bed(tool: SurfaceTool, decorative_shoots: bool) -> void:
	var rim := PackedVector3Array()
	for i in 30:
		var theta := TAU * i / 30.0
		var edge := 0.91 + 0.047 * sin(theta * 3.0 + 0.3) + 0.025 * cos(theta * 5.0)
		rim.append(Vector3(cos(theta) * edge, 0.09, sin(theta) * 0.68 * edge))
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		Wood._face(tool, Vector3(0, BED_SOIL_HEIGHT, 0), a * Vector3(0.99, 1.0, 0.99),
			b * Vector3(0.99, 1.0, 0.99), SOIL.lerp(Color("#674629"), 0.13 + 0.10 * sin(i * 1.7)))
	for strip in 3:
		var path: Array = []
		var widths: Array = []
		for j in 32:
			var i := (j + strip * 6) % 30
			var point := rim[i] * Vector3(0.87, 1.0, 0.90)
			point.y = 0.095 + 0.045 * strip + 0.038 * sin(i * 0.63 + strip * 2.4)
			path.append(point)
			widths.append(0.062 + 0.018 * sin(i * 1.66 + strip))
		Wood._tube(tool, path, widths, BARK.lerp(COPPER, strip * 0.12))
	for row in [-1, 0, 1]:
		Wood._tube(tool, [Vector3(-0.56, 0.094, row * 0.25), Vector3(-0.20, 0.145, row * 0.25 + 0.03),
			Vector3(0.22, 0.142, row * 0.25 - 0.02), Vector3(0.55, 0.094, row * 0.25)],
			[0.028, 0.046, 0.042, 0.025], Color("#65432b"))
	Wood._tube(tool, [Vector3(0, 0.035, 0.64), Vector3(0.01, 0.17, 0.62), Vector3(0.08, 0.19, 0.55)],
		[0.08, 0.075, 0.037], COPPER)
	if not decorative_shoots:
		return
	for i in 3:
		var at := Vector3(-0.34 + i * 0.29, 0.145, -0.21 + 0.08 * (i % 2))
		var tip := at + Vector3(0.018, 0.27 + 0.038 * i, -0.025)
		Wood._tube(tool, [at, at.lerp(tip, 0.63), tip], [0.025, 0.018, 0.004], OLIVE.darkened(0.19))
		for side in [-1.0, 1.0]:
			var stem := at.lerp(tip, 0.55 + side * 0.12)
			var leaf: Vector3 = stem + Vector3(side * 0.14, 0.065, 0.069)
			var rib := stem.lerp(leaf, 0.62) + Vector3.UP * 0.046
			Wood._face(tool, stem, rib + Vector3(0.0, 0.0, 0.045), leaf, OLIVE)
			Wood._face(tool, stem, leaf, rib - Vector3(0.0, 0.0, 0.045), OLIVE.lightened(0.22))

static func _basin(tool: SurfaceTool, radius: float, y: float, wall: Color, inside: Color) -> void:
	var bottom := PackedVector3Array()
	var lip := PackedVector3Array()
	var floor := PackedVector3Array()
	for i in 18:
		var angle := TAU * i / 18.0
		var wave := 1.0 + 0.08 * sin(i * 1.62)
		var at := Vector3(cos(angle), 0, sin(angle)) * radius * wave
		bottom.append(at * 0.69 + Vector3.UP * 0.045)
		lip.append(at * 0.97 + Vector3.UP * (y + 0.045 * sin(i * 0.91)))
		floor.append(at * 0.76 + Vector3.UP * (y - 0.11))
	for i in lip.size():
		var j := (i + 1) % lip.size()
		var tone := wall.lerp(COPPER, 0.12 + 0.07 * cos(i * 1.87))
		_quad(tool, bottom[i], bottom[j], lip[j], lip[i], tone)
		_quad(tool, lip[i], lip[j], floor[j], floor[i], tone.lightened(0.14))
		var stain := inside.lerp(wall, 0.12 + 0.17 * sin(i * 2.9) * sin(i * 2.9))
		Wood._face(tool, floor[i], floor[j], Vector3.UP * (y - 0.11), stain)

static func _archive(tool: SurfaceTool, id: String) -> void:
	var storage := id == "seed_archive"
	var low := id == "monster_studies"
	_basin(tool, 0.80, 0.47 if low else 0.62, BARK if storage else STONE, OLIVE if storage else COPPER)
	var i := 0
	for at in [Vector3(-0.55, 0, -0.40), Vector3(0.51, 0, -0.36), Vector3(0.47, 0, 0.43)]:
		var height := 0.77 if low else (1.39 if storage else 1.68)
		Wood._tube(tool, [at, at * 1.19 + Vector3.UP * (height * 0.50),
			at * 0.69 + Vector3.UP * (height * 0.88), Vector3(0.03, height + i * 0.059, -0.21)],
			[0.15, 0.12, 0.11, 0.011], BARK.lerp(COPPER, i * 0.13))
		i += 1
	if storage:
		for pod in [-1, 0, 1]:
			var x: float = pod * 0.24
			Wood._tube(tool, [Vector3(x, 0.61, 0), Vector3(x, 0.75, 0.08), Vector3(x, 0.98, 0.05)],
				[0.065, 0.13, 0.015], OLIVE.lerp(COPPER, (pod + 1) * 0.25))
	else:
		_quad(tool, Vector3(-0.44, 0.68, -0.06), Vector3(0.44, 0.69, -0.06),
			Vector3(0.42, 0.55, 0.37), Vector3(-0.42, 0.55, 0.37), Color("#a58a61"))
		Wood._tube(tool, [Vector3(0, 0.69, 0.0), Vector3(0, 0.64, 0.17), Vector3(0, 0.58, 0.37)],
			[0.021, 0.019, 0.017], GARNET)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	Wood._face(tool, a, b, c, color)
	Wood._face(tool, a, c, d, color)
