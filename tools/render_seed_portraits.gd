extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/portrait-fixture.cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world:=Node3D.new()
	viewport.add_child(world)
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(1.5,1.3,2.6)
	camera.look_at(Vector3(0,0.56,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.46
	var env:=WorldEnvironment.new()
	world.add_child(env)
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("#c7d7c3")
	env.environment.ambient_light_energy=0.8
	var sun:=DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees=Vector3(-38,-30,0)
	sun.light_color=Color("#fff0ce")
	sun.light_energy=1.2
	for i in game.Seeds.DEFINITIONS.size():
		if not OS.get_cmdline_user_args().is_empty() and not OS.get_cmdline_user_args().has(str(game.Seeds.DEFINITIONS[i].id)): continue
		var crop: Node3D=game.stage.build_crop(i,3,false)
		crop.reparent(world,false)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var path: String="res://assets/ui/seeds/"+game.Seeds.DEFINITIONS[i].id+".png"
		var result:=viewport.get_texture().get_image().save_png(path)
		if result!=OK: printerr("Portrait failed: ",path);quit(1);return
		crop.free()
	print("PASS: selected transparent species portraits rendered")
	quit()
