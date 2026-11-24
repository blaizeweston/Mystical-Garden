extends MeshInstance3D
## Visuals are rebuilt from placed structure poses. One branched mesh and one animated spray batch.
const Wood = preload("res://assets/terrain_m02/terrain_root_mesh.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Water = preload("res://garden_water.gd")
const Irrigation = preload("res://garden_irrigation.gd")

var paths := {} # stable structure ID -> ground path, for inspection
var spray := MeshInstance3D.new()
var _sites := {}
var _terrain_revision := -1
var _water: Array = []

# Purchases and refunds can change inventory without changing anything in the world.
func sync_layout(records: Dictionary, heart: Vector2, water: Array, territory: int, supplied: bool) -> void:
	var sites := {}
	for id: int in records: sites[id] = records[id].at
	if territory == _terrain_revision and is_same(water,_water) and sites == _sites: return
	_sites = sites
	_water = water
	_terrain_revision = territory
	rebuild(records,heart,water,supplied)

func _init() -> void:
	name = "HeartInfrastructure"
	var bark := StandardMaterial3D.new()
	bark.vertex_color_use_as_albedo = true
	material_override = bark
	add_child(spray)
	var moisture := ShaderMaterial.new()
	moisture.shader = preload("res://assets/shaders/garden_sprinkler.gdshader")
	spray.material_override = moisture
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func rebuild(records: Dictionary, heart: Vector2, water: Array, supplied: bool) -> void:
	paths.clear()
	var knots: Array[Vector2] = [heart]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drops := SurfaceTool.new()
	drops.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spraying := false
	var ids := records.keys()
	ids.sort()
	for id: int in ids:
		var entry: Dictionary = records[id]
		var target: Vector2 = entry.at
		var join := heart
		var shortest := INF
		for knot in knots:
			var cost := knot.distance_squared_to(target)
			if cost < shortest:
				shortest = cost
				join = knot
		var direction := target - join
		if direction.is_zero_approx(): continue
		var side := direction.orthogonal().normalized()
		var path: Array = []
		var widths: Array = []
		var steps := maxi(4,ceili(direction.length()/0.55))
		for step in steps + 1:
			var t := float(step)/steps
			var at := join.lerp(target,t) + side * sin(PI*t)*sin(id*1.73+t*3.1)*minf(0.46,direction.length()*0.14)
			# The Garden floor is level. Dip underground through ponds instead of bridging their surface.
			var height := -0.30 if Shape.in_any(water,at) else 0.047
			path.append(Vector3(at.x,height,at.y))
			widths.append(lerpf(0.16 if join==heart else 0.09,0.046,t))
			if step>0 and (step==steps or step*2 in [steps,steps-1]) and height>0: knots.append(at)
		paths[id] = PackedVector3Array(path)
		Wood._tube(tool,path,widths,Color("#70513d"))
		if entry.kind=="intake":
			var shore := Water.intake_shore(water,target)
			if shore.is_finite():
				var tip := shore + (shore-target).normalized()*0.26
				var mid := target.lerp(shore,0.54)
				Wood._tube(tool,[path.back()+Vector3.UP*0.22,Vector3(mid.x,0.20,mid.y),Vector3(tip.x,0.018,tip.y)],[0.11,0.082,0.045],Color("#496b61"))
		elif entry.kind=="sprinkler" and supplied:
			_spray(drops,target,id)
			spraying = true
	mesh = tool.commit() if not paths.is_empty() else null
	spray.mesh = drops.commit() if spraying else null

static func _spray(tool: SurfaceTool, at: Vector2, id: int) -> void:
	for arm in 5:
		var dir := Vector3(cos(arm*TAU/5),0,sin(arm*TAU/5))
		var side := dir.cross(Vector3.UP) * 0.019
		for segment in 10:
			for vertex: Vector2i in [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(0,1)]:
				var t := (segment+vertex.x)/10.0
				var p := Vector3(at.x,0,at.y)+dir*(0.28+t*1.15)+Vector3.UP*(0.82+1.3*t-2.06*t*t)
				tool.set_uv(Vector2(t,fmod(id*0.19+arm*0.10,1.0)))
				tool.add_vertex(p+side*vertex.y)

static func preview(center: Vector2, beds: Dictionary, slots: Array[int]) -> ImmediateMesh:
	var rings := ImmediateMesh.new()
	rings.surface_begin(Mesh.PRIMITIVE_LINES)
	_ring(rings,center,Irrigation.RADIUS_M,72)
	for slot in slots: _ring(rings,beds[slot],0.83,24)
	rings.surface_end()
	return rings

static func _ring(rings: ImmediateMesh, center: Vector2, radius: float, steps: int) -> void:
	for i in steps:
		for j in [i,i+1]:
			var at := center + Vector2.from_angle(j*TAU/steps)*radius
			rings.surface_add_vertex(Vector3(at.x,0.28,at.y))
