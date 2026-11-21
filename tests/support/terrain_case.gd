extends RefCounted
## Explicit modern terrain fixture; no legacy generator or movement-mode switch.
const Field = preload("res://battlefield.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Navigation = preload("res://assets/terrain_m02/wilds_combat_navigation.gd")

static func rectangle(left: float, top: float, right: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(left,top),Vector2(right,top),Vector2(right,bottom),Vector2(left,bottom)])

static func area(field: RefCounted, outline: PackedVector2Array, solids: Array = [], water: Array = []) -> void:
	var layout := {"seed":0,"masses":[],"rocks":[],"plants":[],"solid_shapes":solids,"water":water,"crossings":[],
		"paths":[],"clearings":[],"trail_network":{"nodes":{"exit_gate":Vector2(field.advance.x,field.advance.z)},"edges":[]},"boundary":{
			"playable":Shape.shape("arena","playable",outline),"rim":[],"water":water,"exterior_props":[]}}
	field.generated=field.generated.duplicate(true)
	field.generated.layout=layout
	field.ground=Surface.new({},layout,1.75)
	field.navigation_graph=Navigation.new(field.ground)

static func walls(field: RefCounted, rectangles: Array) -> void:
	var solids: Array=[]
	for rect: Rect2 in rectangles:
		solids.append(Shape.shape("wall_%d"%solids.size(),"wall",rectangle(rect.position.x,rect.position.y,rect.end.x,rect.end.y)))
	area(field,rectangle(-29,-28,30,29),solids)

static func add_wall(field: RefCounted, rect: Rect2) -> void:
	var layout: Dictionary=field.ground.layout.duplicate(true)
	var solids: Array=layout.get("solid_shapes",[])
	solids.append(Shape.shape("fixture_wall_%d"%solids.size(),"wall",rectangle(rect.position.x,rect.position.y,rect.end.x,rect.end.y)))
	layout.solid_shapes=solids
	field.generated.layout=layout
	field.ground=Surface.new(field.generated.cells,layout,1.75)
	field.navigation_graph=Navigation.new(field.ground)

static func place_structure(world: Node, kind: String) -> bool:
	# Supply a claimed disposable world; placement still uses the real validator,
	# transaction, Knowledge requirements and current construction implementation.
	var garden=world.stage.experimental_garden
	var claimed: bool=world.slot_claimed
	world.slot_claimed=true
	var actor:Dictionary=world.players[world.HOST]
	var original:Vector3=actor.pos
	# Heart-menu fixtures may stand inside the tree; real construction requires
	# a walkable player position so its access guarantee can be checked.
	if not garden.barrier.walkable(garden.planar(actor.pos)):actor.pos=garden.return_position()
	var pawn:=Vector2(actor.pos.x,actor.pos.z)
	# Current rotated placement sites also exercised by the construction fixtures.
	var sites:Array[Vector2]=[Vector2(2.34,-4.58),Vector2(-6.67,4.44),Vector2(-3.25,-5.25),Vector2(6.44,.45),Vector2(.17,5.58),Vector2(1.31,6.72)]
	for z in range(-12,13):
		for x in range(-12,13):sites.append(Vector2(x,z))
	for position in sites:
		for yaw in [.37,0.0]:
			if garden.construction.validate(kind,position,yaw,pawn).is_empty() and garden.place(kind,position,yaw):
				world.slot_claimed=claimed;actor.pos=original
				return true
	world.slot_claimed=claimed;actor.pos=original
	return false
