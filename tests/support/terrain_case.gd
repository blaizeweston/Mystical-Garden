extends RefCounted
## Explicit modern terrain fixture; no legacy generator or movement-mode switch.
const Field = preload("res://battlefield.gd")
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Navigation = preload("res://assets/terrain_m02/wilds_combat_navigation.gd")

static func rectangle(left: float, top: float, right: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(left,top),Vector2(right,top),Vector2(right,bottom),Vector2(left,bottom)])

static func area(field: RefCounted, outline: PackedVector2Array, solids: Array = [], water: Array = []) -> void:
	var layout := {"masses":[],"rocks":[],"plants":[],"solid_shapes":solids,"water":water,"crossings":[],
		"paths":[],"clearings":[],"trail_network":{"nodes":{},"edges":[]},"boundary":{
			"playable":Shape.shape("arena","playable",outline),"rim":[],"water":water}}
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
