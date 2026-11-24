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
	map.update_floor(field,"floor1",field.entry,camera,true,true,false)
	check(map.seen(field.entry), "starting clearing is revealed")
	check(not map.seen(field.advance), "distant exit is unexplored")
	var original_count: int = map.cells.size()
	var drops := [{"item":"mystery_seed","position":[field.cache.x,field.cache.y,field.cache.z]}]
	map.update_floor(field,"floor1",field.cache,camera,true,true,false,false,drops)
	check(map.seen(field.entry) and map.seen(field.cache), "exploration remains after moving away")
	check(map.cells.size() > original_count and map.item_drops == drops, "discovered paths and active drops appear")
	map.update_floor(field,"floor1",field.cache,camera,true,false,false)
	check(map.item_drops.is_empty() and not map.has_cache, "claimed drops leave the map")
	var event = InputEventKey.new()
	event.keycode = KEY_M
	event.physical_keycode = KEY_M
	event.pressed = true
	map._unhandled_key_input(event)
	check(map.expanded, "M enlarges the floor map")
	map.update_floor(field,"floor2",field.advance,camera,true,false,false)
	check(not map.seen(field.entry) and map.seen(field.advance), "new floor clears previous exploration")
	map.update_floor(field,"floor2",field.entry,camera,false,false,false)
	check(not map.fog.visible and not map.chart.visible, "Garden hides expedition fog and map")
	# Rotated layouts may use any edge, not only the old north/south footprint.
	for point in [Vector3(-28,0,0),Vector3(28,0,0),Vector3(0,0,-27),Vector3(0,0,27)]:
		var edge=Battlefield.new()
		map.update_floor(edge,str(point),point,camera,true,false,false)
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
	var specimen := {"identity":"r1:f2","position":Vector3(2,0,3),"species":0,"claimed":false}
	stage.show_wild_flora(specimen,Vector3(21,0,3),true)
	check(not stage.has_node("WildSpecimen"), "distant new specimens do not allocate a model")
	stage.show_wild_flora(specimen,Vector3.ZERO,true)
	var ripe: Node3D = stage.get_node("WildSpecimen")
	check(ripe.visible and ripe.position == stage.WILD_OFFSET + specimen.position, "the mature plant is grounded at its floor position")
	var ripe_width := ripe.scale.x
	var ripe_parts := ripe.get_child_count()
	stage.show_wild_flora(specimen,Vector3(21,0,3),true)
	check(not ripe.visible, "wild plants obey exploration sight")
	stage.show_wild_flora(specimen,Vector3.ZERO,true)
	check(ripe.visible and ripe == stage.get_node("WildSpecimen"), "rediscovery reuses the same model")
	specimen.claimed=true
	stage.show_wild_flora(specimen,Vector3.ZERO,true)
	var picked: Node3D = stage.get_node("WildSpecimen")
	check(picked.visible and picked.scale.x < ripe_width and picked.get_child_count() < ripe_parts, "locally picked Thorn Bloom has a visibly shorter, spent silhouette")
	for species in preload("res://seed_catalog.gd").DEFINITIONS.size():
		specimen.merge({"species":species,"identity":"next:%d"%species,"claimed":false},true)
		stage.show_wild_flora(specimen,Vector3.ZERO,true)
		var plant: Node3D = stage.get_node("WildSpecimen")
		check(plant.find_children("*","MeshInstance3D",true,false).size() > 1,"species %d renders its assembled Garden crop"%species)
		check(plant.find_children("*","CollisionObject3D",true,false).is_empty(),"flora leaves navigation unobstructed")
	stage.show_wild_flora({},Vector3.ZERO,true)
	check(not stage.has_node("WildSpecimen"), "an empty floor clears the local specimen")
	stage.show_wild_flora(specimen,Vector3.ZERO,true)
	stage.show_wild_flora(specimen,Vector3.ZERO,false)
	check(not stage.has_node("WildSpecimen"), "returning to the Garden clears the local specimen")
	await process_frame
	if not failed: print("PASS: fog memory, floor reset, drop markers and map controls")
	quit(1 if failed else 0)
