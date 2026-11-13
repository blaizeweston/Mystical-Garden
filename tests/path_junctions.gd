extends SceneTree
const Field=preload("res://battlefield.gd")
func _initialize(): call_deferred("run")
func run():
	var field=Field.new()
	field.procedural=true
	# Dirt shoulders almost meet along two parallel routes. Crossing anywhere
	# along this seam must work, rather than requiring the distant junction.
	field.clearings.assign([Vector3(-8,-2.5,0.1),Vector3(8,-2.5,0.1),Vector3(-8,2.5,0.1),Vector3(8,2.5,0.1)])
	field.links=[[0,1,2.0],[2,3,2.0]]
	for x in range(-6,7):
		for sign_value in [-1.0,1.0]:
			var start=Vector3(x,0,-1.4*sign_value)
			var finish=Vector3(x,0,1.4*sign_value)
			assert(field.dash(start,finish).distance_to(finish)<0.01,"Parallel shoulder crossing is pinched")
			var pos=start
			for step in 35: pos=field.slide(pos,pos.move_toward(finish,0.1))
			assert(pos.distance_to(finish)<0.01,"Walking cannot cross the junction")
	# Separate routes must still have a real forest gap.
	field.clearings.assign([Vector3(-8,-5,0.1),Vector3(8,-5,0.1),Vector3(-8,5,0.1),Vector3(8,5,0.1)])
	assert(not field.inside_floor(Vector3.ZERO),"Separated routes were joined")
	field.barriers=[Rect2(-0.5,-7,1,4)]
	assert(not field.clear_line(Vector3(-2,0,-5),Vector3(2,0,-5),Field.CLEARANCE),"Cover became traversable")
	print("PASS: 26 bidirectional shoulder crossings by walking and dash; separate forest and solid cover preserved")
	quit()
