extends MeshInstance3D
## Visuals are rebuilt from placed structure poses. One branched mesh and one animated spray batch.
const HeartRoots = preload("res://assets/terrain_m02/garden_heart_roots.gd")
const Bark = preload("res://assets/terrain_m02/heart_bark.gdshader")
const Water = preload("res://garden_water.gd")
const Irrigation = preload("res://garden_irrigation.gd")

var paths := {} # stable structure ID -> ground path, for inspection
var spray := MeshInstance3D.new()
var _sites := {}
var _terrain_revision := -1
var _stage := -1
var _water: Array = []
var _growth: Tween
var _bark := ShaderMaterial.new()
var _growing_bark := ShaderMaterial.new()

func sync_layout(records: Dictionary, garden, stage: int, frontiers: Array[Dictionary], supplied: bool, live: bool) -> void:
	var sites := {}
	var new_limbs := {}
	for id: int in records:
		var at: Vector2 = records[id].at
		sites[id] = Vector3(at.x, at.y, records[id].yaw)
		if live and _stage >= 0 and (not _sites.has(id) or Vector2(_sites[id].x, _sites[id].y) != at):
			new_limbs[id] = true
	if stage == _stage and garden.revision == _terrain_revision and is_same(garden.layout.water, _water) and sites == _sites:
		return
	_sites = sites
	_stage = stage
	_terrain_revision = garden.revision
	_water = garden.layout.water
	rebuild(records, garden, stage, frontiers, supplied, new_limbs)

func _init() -> void:
	name = "HeartInfrastructure"
	_bark.shader = Bark
	_growing_bark.shader = Bark
	_growing_bark.set_shader_parameter("growing_root", true)
	add_child(spray)
	var moisture := ShaderMaterial.new()
	moisture.shader = preload("res://assets/shaders/garden_sprinkler.gdshader")
	spray.material_override = moisture
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func rebuild(records: Dictionary, garden, stage: int, frontiers: Array[Dictionary], supplied: bool, new_limbs := {}) -> void:
	paths.clear()
	if _growth != null:
		_growth.kill()
		_growth = null
	var settled := SurfaceTool.new()
	settled.begin(Mesh.PRIMITIVE_TRIANGLES)
	settled.set_material(_bark)
	var growing := SurfaceTool.new()
	growing.begin(Mesh.PRIMITIVE_TRIANGLES)
	growing.set_material(_growing_bark)
	var drops := SurfaceTool.new()
	drops.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spraying := false
	var settled_vertices := 0
	var growing_vertices := 0
	var network: Array[Dictionary] = frontiers.duplicate()
	var ids := records.keys()
	ids.sort()
	for id: int in ids:
		var entry: Dictionary = records[id]
		var target: Vector2 = entry.at
		var route := _route(target, id)
		# Only physical footprints can bury a branch. A door's walkable approach stays visible.
		var corridor := Rect2(Vector2.ZERO, Vector2.ZERO).expand(target).grow(3.5)
		var footprints: Array = []
		for other: Dictionary in records.values():
			if corridor.intersects(other.footprint.bounds):
				footprints.append(other.footprint)
		var plan := HeartRoots.plan(route, stage, garden, network, true, footprints)
		var main: Array[Vector3] = plan.main
		paths[id] = PackedVector3Array(main)
		network.append(plan)
		var is_growing := new_limbs.has(id)
		var surface := growing if is_growing else settled
		var next := HeartRoots.append_root(surface, plan, growing_vertices if is_growing else settled_vertices)
		if entry.kind=="intake":
			var shore := Water.intake_shore(garden.layout.water,target)
			if shore.is_finite():
				var tip := shore + (shore-target).normalized()*0.26
				var mid := target.lerp(shore,0.54)
				var inlet: Array[Vector3] = [Vector3(target.x,0.23,target.y),Vector3(mid.x,0.13,mid.y),Vector3(shore.x,0.06,shore.y),Vector3(tip.x,-0.02,tip.y)]
				next = HeartRoots.append_root(surface,{"main":inlet,"radius":0.15,"branches":[]},next)
		elif entry.kind=="sprinkler" and supplied:
			_spray(drops,target,id)
			spraying = true
		if is_growing:
			growing_vertices = next
		else:
			settled_vertices = next
	var batch := ArrayMesh.new()
	if settled_vertices > 0:
		settled.commit(batch)
	if growing_vertices > 0:
		growing.commit(batch)
		_growing_bark.set_shader_parameter("root_progress", 0.0)
		_growth = create_tween()
		_growth.tween_property(_growing_bark, "shader_parameter/root_progress", 1.0, 0.85)
	mesh = batch if not records.is_empty() else null
	spray.mesh = drops.commit() if spraying else null

## A short route to the structure supplies the same socket and branch planner used by reclamation.
static func _route(target: Vector2, id: int) -> PackedVector2Array:
	var route := PackedVector2Array()
	var side := target.normalized().orthogonal()
	var steps := maxi(7,ceili(target.length()/0.38))
	for step in steps+1:
		var t := float(step)/steps
		var curve := sin(PI*t)*sin(id*1.73+t*3.1)*minf(0.65,target.length()*0.14)
		route.append(target*t+side*curve)
	route[-1] = target
	return route

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
