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
	"living_archive": "Living archive"}

static func build(id: String, decorative_bed_shoots := true) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match id:
		"starter_bed":
			_bed(tool, decorative_bed_shoots)
		"intake", "sprinkler":
			var intake := id == "intake"
			for i in 5:
				var angle := i * TAU / 5.0
				var outward := Vector3(cos(angle),0,sin(angle))
				Wood._tube(tool,[outward*0.38+Vector3.UP*0.035,outward*0.18+Vector3.UP*0.16,Vector3.UP*0.32],[0.045,0.08,0.09],BARK)
				var height := 0.52 if intake else 0.83
				Wood._tube(tool,[Vector3.UP*0.23,outward*0.08+Vector3.UP*(height-0.18),outward*0.28+Vector3.UP*height],[0.095,0.073,0.028],OLIVE)
			Wood._crown(tool, _fixed_random(), Vector3.UP*(0.36 if intake else 0.61),Vector3(0.14,0.16,0.14),Color("#61958d"))
		"pollination_bloom":
			_pollination_flower(tool)
		"nursery":
			_basin(tool,0.38,0.20,BARK,SOIL)
			for i in 3:
				var stem := Vector3(cos(i*TAU/3)*0.15,0,sin(i*TAU/3)*0.15)
				Wood._tube(tool,[stem,stem+Vector3.UP*0.45],[0.04,0.025],OLIVE)
				Wood._crown(tool,_fixed_random(),stem+Vector3.UP*0.45,Vector3(0.16,0.2,0.14),Color("#90ba64"))
		"refinement_grove":
			_basin(tool,0.36,0.18,STONE,SOIL)
			for i in 5:
				var dir := Vector3(cos(i*TAU/5),0,sin(i*TAU/5))
				Wood._tube(tool,[dir*0.10,dir*0.18+Vector3.UP*0.38,dir*0.27+Vector3.UP*(0.63+0.12*(i%2))],[0.09,0.12,0.008],Color("#a885c6"))
		"vital_roots":
			for i in 5:
				var dir := Vector3(cos(i*TAU/5),0,sin(i*TAU/5))
				Wood._tube(tool,[dir*0.4,dir*0.24+Vector3.UP*0.15,dir*0.08+Vector3.UP*0.5,Vector3.UP*0.73],[0.035,0.1,0.08,0.02],BARK.lerp(GARNET,0.55))
			Wood._crown(tool,_fixed_random(),Vector3.UP*0.55,Vector3(0.14,0.18,0.14),Color("#dc6555"))
		"bud_sanctuary":
			_basin(tool,0.34,0.22,BARK,OLIVE)
			Wood._crown(tool,_fixed_random(),Vector3.UP*0.45,Vector3(0.16,0.25,0.16),Color("#eac7ae"))
			for i in 4:
				var dir := Vector3(cos(i*PI/2),0,sin(i*PI/2))
				Wood._tube(tool,[dir*0.14,dir*0.30+Vector3.UP*0.42,dir*0.08+Vector3.UP*0.76],[0.07,0.045,0.012],OLIVE)
		"altar":
			_basin(tool, 0.86, 0.77, STONE, GARNET)
			Wood._tube(tool, [Vector3(-0.41, 0.08, 0.42), Vector3(-0.42, 0.46, 0.19),
				Vector3(-0.11, 0.82, -0.23), Vector3(0.35, 0.91, -0.31)],
				[0.16, 0.14, 0.08, 0.02], BARK)
		_:
			_archive(tool, id)
	return tool.commit()

## A tall, reflexed corolla around an exposed pollen cone reads above the beds.
static func _pollination_flower(tool: SurfaceTool) -> void:
	var head := Vector3(0,1.09,0)
	Wood._tube(tool,[Vector3.ZERO,Vector3(-.09,.42,.04),Vector3(.07,.79,0),head],[.092,.065,.045,.05],OLIVE)
	for i in 8:
		var radial := Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
		var side := radial.cross(Vector3.UP)
		var base := head + radial*.04
		var shoulder := head + radial*.26 + Vector3.UP*.095
		var tip := head + radial*(.44+.035*(i%2)) - Vector3.UP*(.12+.055*(i%3))
		var left := shoulder - side*.095
		var right := shoulder + side*.095
		var ridge := shoulder + Vector3.UP*.035
		Wood._face(tool,base,left,ridge,Color("#dbc28e"))
		Wood._face(tool,base,ridge,right,Color("#e6d7ab"))
		Wood._face(tool,left,tip,ridge,Color("#ca9e76"))
		Wood._face(tool,ridge,tip,right,Color("#dfb988"))
		if i%2==0:
			var start := Vector3.UP*(.32+.12*(i%3))
			var middle := start + radial*.20 + Vector3.UP*.065
			_quad(tool,start,middle+side*.08,start+radial*.34+Vector3.UP*.18,middle-side*.08,OLIVE.lightened(.12))
	Wood._crown(tool,_fixed_random(),head+Vector3.UP*.13,Vector3(.125,.19,.125),Color("#ba8939"))

static func _fixed_random() -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = 117
	return random

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
	var floor_ring := PackedVector3Array()
	for i in 18:
		var angle := TAU * i / 18.0
		var wave := 1.0 + 0.08 * sin(i * 1.62)
		var at := Vector3(cos(angle), 0, sin(angle)) * radius * wave
		bottom.append(at * 0.69 + Vector3.UP * 0.045)
		lip.append(at * 0.97 + Vector3.UP * (y + 0.045 * sin(i * 0.91)))
		floor_ring.append(at * 0.76 + Vector3.UP * (y - 0.11))
	for i in lip.size():
		var j := (i + 1) % lip.size()
		var tone := wall.lerp(COPPER, 0.12 + 0.07 * cos(i * 1.87))
		_quad(tool, bottom[i], bottom[j], lip[j], lip[i], tone)
		_quad(tool, lip[i], lip[j], floor_ring[j], floor_ring[i], tone.lightened(0.14))
		var stain := inside.lerp(wall, 0.12 + 0.17 * sin(i * 2.9) * sin(i * 2.9))
		Wood._face(tool, floor_ring[i], floor_ring[j], Vector3.UP * (y - 0.11), stain)

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
