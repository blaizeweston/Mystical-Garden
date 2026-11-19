extends SceneTree
const Field = preload("res://battlefield.gd")
const TerrainCase = preload("res://tests/support/terrain_case.gd")
func _initialize() -> void:
	var field := Field.new()
	var joined := Geometry2D.merge_polygons(TerrainCase.rectangle(-10,-4.5,10,.1),TerrainCase.rectangle(-10,-.1,10,4.5))
	assert(joined.size()==1)
	TerrainCase.area(field,joined[0])
	for x in range(-6,7):
		for sign_value in [-1.0,1.0]:
			var start := Vector3(x,0,-1.4*sign_value)
			var finish := Vector3(x,0,1.4*sign_value)
			assert(field.dash(start,finish).distance_to(finish)<.01,"Merged terrain has no internal actor boundary")
			var pos := start
			for step in 35:pos=field.slide(pos,pos.move_toward(finish,.1))
			assert(pos.distance_to(finish)<.01,"Walking crosses the merged surface")
	var water := TerrainCase.Shape.shape("gap","water",TerrainCase.rectangle(-10,-1.8,10,1.8))
	TerrainCase.area(field,TerrainCase.rectangle(-10,-8,10,8),[],[water])
	assert(field.occupied(Vector3.ZERO) and not field.dash(Vector3(0,0,-4),Vector3(0,0,4)).is_equal_approx(Vector3(0,0,4)),"A genuine unsupported gap stays impassable")
	TerrainCase.walls(field,[Rect2(-.5,-7,1,4)])
	assert(not field.clear_line(Vector3(-2,0,-5),Vector3(2,0,-5),Field.CLEARANCE),"Solid cover remains impassable")
	print("PASS: 26 bidirectional modern shoulder crossings by walking and dash; unsupported gaps and solid cover preserved")
	quit()
