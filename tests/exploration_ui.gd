extends SceneTree
const Battlefield = preload("res://battlefield.gd")
const Exploration = preload("res://exploration.gd")
var failed := false
func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("FAIL: ", message)
func _initialize():
	call_deferred("run")
func run():
	var map = Exploration.new()
	root.add_child(map)
	var camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(80,14,14)
	camera.look_at(Vector3(80,0,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var field = Battlefield.new()
	field.configure(0,1,91247)
	map.update_floor(field,"floor1",field.entry,camera,true,field.cache,true,true,false)
	check(map.seen(field.entry), "starting clearing is revealed")
	check(not map.seen(field.advance), "distant exit is unexplored")
	var original_count: int = map.cells.size()
	map.update_floor(field,"floor1",field.cache,camera,true,field.cache,true,true,false)
	check(map.seen(field.entry) and map.seen(field.cache), "exploration remains after moving away")
	check(map.cells.size() > original_count and map.has_loot, "discovered paths and active drops appear")
	map.update_floor(field,"floor1",field.cache,camera,true,field.cache,false,false,false)
	check(not map.has_loot and not map.has_cache, "claimed drops leave the map")
	var event = InputEventKey.new()
	event.keycode = KEY_M
	event.physical_keycode = KEY_M
	event.pressed = true
	map._unhandled_key_input(event)
	check(map.expanded, "M enlarges the floor map")
	map.update_floor(field,"floor2",field.advance,camera,true,field.cache,false,false,false)
	check(not map.seen(field.entry) and map.seen(field.advance), "new floor clears previous exploration")
	map.update_floor(field,"floor2",field.entry,camera,false,field.cache,false,false,false)
	check(not map.fog.visible and not map.chart.visible, "Garden hides expedition fog and map")
	# Rotated layouts may use any edge, not only the old north/south footprint.
	for point in [Vector3(-28,0,0),Vector3(28,0,0),Vector3(0,0,-27),Vector3(0,0,27)]:
		var edge=Battlefield.new();edge.procedural=true;edge.clearings.assign([Vector3(point.x,point.z,2)]);edge.bake_surface()
		map.update_floor(edge,str(point),point,camera,true,point,false,false,false)
		check(map.seen(point),"fog memory covers the full generated region")
		var icon: Vector2=map.chart_point(point,map.chart)
		check(Rect2(Vector2(12,36),map.chart.size-Vector2(24,70)).has_point(icon),"map projects rotated-floor edge markers within its chart")
	var game = load("res://world.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var stage = game.stage
	var observer := Vector3(80, 0, 0)
	stage.foe.position = observer + Vector3(20, 0, 0)
	stage.foe.visible = true
	stage.support_models[0].position = observer + Vector3(20, 0, 0)
	stage.support_models[0].visible = true
	stage.support_rings[0].position = observer + Vector3(1, 0, 0)
	stage.support_rings[0].visible = true
	stage.apply_exploration_sight(Vector3.ZERO, true, Exploration.SIGHT)
	check(not stage.foe.visible and not stage.support_models[0].visible, "unseen enemies remain concealed on explored ground")
	check(stage.support_rings[0].visible, "incoming attack warns the player even when its attacker is hidden")
	await process_frame
	if not failed: print("PASS: fog memory, floor reset, drop markers and map controls")
	quit(1 if failed else 0)
