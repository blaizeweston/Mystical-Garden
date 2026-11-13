extends RefCounted

const TRAIL := Color("#f9aa84")
const BORDER := Color("#231710")


static func draw_routes(canvas: Control, map: Node, routes: Array) -> void:
	for route in routes:
		var previous: Vector2 = map.chart_point(route.pos,canvas)
		var spacing := 4.0
		for waypoint in route.path:
			var at: Vector2 = map.chart_point(waypoint,canvas)
			var delta := at - previous
			var length := delta.length()
			var direction := delta.normalized()
			while spacing <= length:
				canvas.draw_circle(previous+direction*spacing,1.2,TRAIL,true,-1.0,true)
				spacing += 4.5
			spacing -= length
			previous = at
		var tunnel: Vector2 = map.chart_point(route.tunnel,canvas)
		draw_tunnel(canvas,tunnel,5.2)
		if route.burrowing:
			canvas.draw_arc(tunnel,7.4,0.0,TAU,20,TRAIL,1.0,true)
		draw_thief(canvas,map.chart_point(route.pos,canvas),4.3)
	if not routes.is_empty():
		var row := canvas.size.y-28.0
		draw_thief(canvas,Vector2(16,row-3),3.0)
		canvas.draw_string(ThemeDB.fallback_font,Vector2(23,row),"Thief",HORIZONTAL_ALIGNMENT_LEFT,-1,10,TRAIL)
		draw_tunnel(canvas,Vector2(83,row-3),3.3)
		canvas.draw_string(ThemeDB.fallback_font,Vector2(91,row),"Escape tunnel",HORIZONTAL_ALIGNMENT_LEFT,-1,10,TRAIL)


static func draw_thief(canvas: Control, at: Vector2, radius: float) -> void:
	var shape := PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius,radius*.72),
		at+Vector2(0,radius*.32),at+Vector2(-radius,radius*.72)])
	canvas.draw_colored_polygon(shape,TRAIL)
	shape.append(shape[0])
	canvas.draw_polyline(shape,BORDER,1.0,true)


static func draw_tunnel(canvas: Control, at: Vector2, radius: float) -> void:
	canvas.draw_circle(at,radius,BORDER,true,-1.0,true)
	canvas.draw_arc(at,radius,0.0,TAU,20,TRAIL,1.25,true)


static func update_tunnels(map: Node, markers: Dictionary, routes: Array, camera: Camera3D) -> void:
	var active := {}
	for route in routes:
		var key := str([map.floor_key,route.id,route.token])
		active[key] = true
		if not markers.has(key):
			markers[key] = make_tunnel()
			map.add_child(markers[key])
		var model: Node3D = markers[key]
		model.position = route.tunnel + camera.get_parent().WILD_OFFSET
		model.visible = map.player.distance_to(route.tunnel) <= map.SIGHT
		var swell := 1.0 + .08*sin(Time.get_ticks_msec()*.014) if route.burrowing else 1.0
		model.scale = Vector3(swell,1,swell)
	for key in markers.keys():
		if not active.has(key):
			markers[key].queue_free()
			markers.erase(key)


static func make_tunnel() -> Node3D:
	var model := Node3D.new()
	var rim := TorusMesh.new()
	rim.inner_radius = .33
	rim.outer_radius = .55
	rim.rings = 16
	rim.ring_segments = 9
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("#755340")
	bark.roughness = .92
	var lip := MeshInstance3D.new()
	lip.mesh = rim
	lip.material_override = bark
	lip.position.y = .08
	lip.scale = Vector3(1,.66,.82)
	model.add_child(lip)
	var hole := CylinderMesh.new()
	hole.top_radius = .405
	hole.bottom_radius = .405
	hole.height = .035
	hole.radial_segments = 18
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#16100b")
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var entrance := MeshInstance3D.new()
	entrance.mesh = hole
	entrance.material_override = dark
	entrance.position.y = .025
	entrance.scale.z = .82
	model.add_child(entrance)
	return model
