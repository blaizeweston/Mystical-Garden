extends MeshInstance3D
## Visuals are rebuilt from placed structure poses. One branched mesh and one animated spray batch.
const HeartRoots = preload("res://assets/terrain_m02/garden_heart_roots.gd")
const Bark = preload("res://assets/terrain_m02/heart_bark.gdshader")
const Water = preload("res://garden_water.gd")
const Irrigation = preload("res://garden_irrigation.gd")

var paths := {} # stable structure ID -> ground path, for inspection
const Ambient = preload("res://assets/terrain_m02/garden_ambient.gd")
var spray := Ambient.batch("spray")
var pollen := Ambient.batch("pollen")
var intake := Ambient.batch("intake")
var _supplied := false
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
	if stage == _stage and garden.revision == _terrain_revision and is_same(garden.layout.water, _water) and supplied == _supplied and sites == _sites:
		return
	_supplied = supplied
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
	for effect in [spray,pollen,intake]: add_child(effect)
	apply_ambient({})

func apply_ambient(values: Dictionary, moving := true) -> void:
	for bark: ShaderMaterial in [_bark,_growing_bark]:
		bark.set_shader_parameter("living",moving)
		Ambient.configure(bark,"root",values)
	for effect in [spray,pollen,intake]:
		effect.visible = moving
		Ambient.configure(effect.material_override,effect.name.to_lower(),values)


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
	var flowers := SurfaceTool.new()
	flowers.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ripples := SurfaceTool.new()
	ripples.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blooming := false
	var sipping := false
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
				next = HeartRoots.append_root(surface,{"main":inlet,"radius":0.15,"branches":[],
					"flow_start":plan.flow_start+HeartRoots._arc_length(main,main.size()-1)},next)
				if supplied:
					Ambient.emitter(ripples,"intake",Vector3(tip.x,.065,tip.y),entry.yaw)
					sipping = true
		elif entry.kind=="sprinkler" and supplied:
			Ambient.emitter(drops,"spray",Vector3(target.x,0,target.y),entry.yaw)
			spraying = true
		elif entry.kind=="pollination_bloom":
			Ambient.emitter(flowers,"pollen",Vector3(target.x,0,target.y),entry.yaw)
			blooming = true
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
	pollen.mesh = flowers.commit() if blooming else null
	intake.mesh = ripples.commit() if sipping else null

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

static func preview(center: Vector2, beds: Dictionary, slots: Array[int], radius := Irrigation.RADIUS_M) -> ImmediateMesh:
	var rings := ImmediateMesh.new()
	rings.surface_begin(Mesh.PRIMITIVE_LINES)
	_ring(rings,center,radius,72)
	for slot in slots: _ring(rings,beds[slot],0.83,24)
	rings.surface_end()
	return rings

static func _ring(rings: ImmediateMesh, center: Vector2, radius: float, steps: int) -> void:
	for i in steps:
		for j in [i,i+1]:
			var at := center + Vector2.from_angle(j*TAU/steps)*radius
			rings.surface_add_vertex(Vector3(at.x,0.28,at.y))
