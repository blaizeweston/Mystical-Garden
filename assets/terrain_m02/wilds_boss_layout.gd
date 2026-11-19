extends RefCounted
## Authored combat reservations use the same surface, cover and navigation as generated Wilds.
## Boss radii, arrival/exit landmarks and Nest ribs retain their existing gameplay values.
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Grid = preload("res://assets/terrain_m02/hex_grid.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const Navigation = preload("res://assets/terrain_m02/wilds_combat_navigation.gd")
const Biomes = preload("res://assets/terrain_m02/wilds_biome.gd")
const Nest = preload("res://boss_nest_layout.gd")
const SPACING := 1.75
const GRID_RADIUS := 14
const BOSS_RADII := {20:22.0,21:16.5,22:15.0}
const DEFAULT_RADIUS := 17.5
const ENTRY := Vector2(0,-21)
const EXIT := Vector2(0,22)

static func build(kind: int, phase: int, seed_value: int, floor_number: int, practice: bool = false) -> Dictionary:
	var radius: float=BOSS_RADII.get(kind,DEFAULT_RADIUS)
	var arena: Dictionary
	if practice:
		arena=Shape.shape("arena","playable",PackedVector2Array([Vector2(-29,-28),Vector2(30,-28),Vector2(30,29),Vector2(-29,29)]))
	else:
		var circle := Shape.boundary(Shape.disk("boss_room","clearing",Vector2.ZERO,radius))
		var approach := PackedVector2Array([Vector2(-4,-25),Vector2(4,-25),Vector2(4,25),Vector2(-4,25)])
		var merged := Geometry2D.merge_polygons(circle,approach)
		assert(merged.size()==1,"Boss approach must remain attached to its arena")
		arena=Shape.shape("arena","playable",merged[0])
	var ribs: Array=Nest.ribs(phase) if kind==22 else []
	var solids: Array=[]
	for index in ribs.size():
		var rect: Rect2=ribs[index]
		solids.append(Shape.shape("nest_rib_%d"%index,"root_rib",PackedVector2Array([
			rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])))
	var nodes := {"arrival":ENTRY,"exit_gate":EXIT,"center":Vector2.ZERO,
		"leader":Vector2(0,5),"graft":Vector2(-radius*.6,-3),"cache":Vector2(radius*.6,-3)}
	var rooms: Array=["leader"]
	var layout := {"seed":seed_value,"spacing":SPACING,"grid_radius":GRID_RADIUS,
		"masses":[],"rocks":[],"plants":[],"water":[],"crossings":[],"paths":[],"path_joins":[],
		"solid_shapes":solids,"clearings":[Shape.disk("boss_room","clearing",Vector2.ZERO,radius),
			Shape.disk("arrival","clearing",ENTRY,4.0),Shape.disk("exit_gate","clearing",Vector2(0,21),4.0)],
		"boundary":border(arena,1 if kind==21 else 2 if kind==22 else 0),
		"trail_network":{"nodes":nodes,"edges":[]},"combat_rooms":rooms,
		"layout_kind":"practice" if practice else "boss_lair"}
	var cells := {}
	for cell in Grid.disk(GRID_RADIUS):cells[cell]=&"soil"
	var surface := Surface.new(cells,layout,SPACING)
	for i in 12:
		var at := Vector2.from_angle(TAU*i/12.0)*radius*.6+Vector2(0,3)
		if surface.walkable(at,Navigation.RADIUS+.15):
			var id := "spawn_%d"%i
			nodes[id]=at
			rooms.append(id)
	var grid: AStarGrid2D
	if not solids.is_empty():
		grid=AStarGrid2D.new()
		grid.region=Rect2i(-60,-58,122,118)
		grid.cell_size=Vector2.ONE*.5
		grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.update()
		for x in range(grid.region.position.x,grid.region.end.x):
			for y in range(grid.region.position.y,grid.region.end.y):
				grid.set_point_solid(Vector2i(x,y),not surface.walkable(Vector2(x,y)*.5,Navigation.RADIUS+.02))
	for id: String in nodes:
		if id=="center":continue
		var start: Vector2=nodes.center
		var finish: Vector2=nodes[id]
		var spine := PackedVector2Array([start,finish])
		if not surface.clear_line(start,finish,Navigation.RADIUS):
			assert(grid!=null,"Only authored solids may obstruct a boss trail")
			var a:=nearest_cell(grid,start)
			var b:=nearest_cell(grid,finish)
			spine=PackedVector2Array([start])
			spine.append_array(grid.get_point_path(a,b))
			spine.append(finish)
		var edge_id := "center_to_"+id
		var widths := PackedFloat32Array()
		widths.resize(spine.size());widths.fill(1.2)
		layout.paths.append(Shape.ribbon(edge_id,"trail",spine,widths))
		layout.trail_network.edges.append({"id":edge_id,"from":"center","to":id,"width":1.2})
	layout["ground_clearings"]=[arena]
	var climate := Biomes.climate(floor_number,Biomes.WINDOWS)
	return {"cells":cells,"substrate":cells.duplicate(),"layout":layout,"climate":climate,
		"landmarks":{"entry":ENTRY,"extraction":Vector2(0,-22),"advance":EXIT,
			"leader":nodes.leader,"graft":nodes.graft,"cache":nodes.cache},"ribs":ribs}

static func nearest_cell(grid: AStarGrid2D, at: Vector2) -> Vector2i:
	var origin := Vector2i((at*2).round())
	for radius in 5:
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var cell := origin+Vector2i(x,y)
				if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):return cell
	assert(false,"Authored boss landmark has no legal navigation attachment")
	return origin

static func border(arena: Dictionary, family: int) -> Dictionary:
	var inner: PackedVector2Array=arena.outline.duplicate()
	inner.append(inner[0])
	var outer := PackedVector2Array()
	for point in inner:outer.append(point+point.normalized()*3.0)
	var outline := inner.duplicate()
	var reversed := outer.duplicate();reversed.reverse();outline.append_array(reversed)
	var rim := Shape.shape("lair_perimeter","rim",outline)
	rim.merge({"family":family,"inner":inner,"outer":outer,"wet":false,"start":0})
	return {"playable":arena,"rim":[rim],"water":[],"exterior_props":[]}
