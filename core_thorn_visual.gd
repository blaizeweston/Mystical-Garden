extends RefCounted


static func draw(view: Node, hint: Dictionary, mesh: ImmediateMesh, from: Vector3, to: Vector3, radius: float) -> void:
	var forward := (to - from).normalized()
	var side := forward.cross(Vector3.UP)
	mesh.surface_set_color(Color(0.38, 0.58, 0.22, 0.48))
	view.ribbon(mesh, from, to, radius * 2.0)
	for end in [from, to]:
		var outward := forward if end == to else -forward
		for i in 12:
			var a := PI * i / 12.0
			var b := PI * (i + 1) / 12.0
			mesh.surface_add_vertex(end)
			mesh.surface_add_vertex(end + (side * cos(a) + outward * sin(a)) * radius)
			mesh.surface_add_vertex(end + (side * cos(b) + outward * sin(b)) * radius)
	mesh.surface_set_color(Color("#9dca72"))
	var stem_from := from + Vector3.UP * .045
	var stem_to := to + Vector3.UP * .045
	view.ribbon(mesh, stem_from, stem_to, .065)
	for i in range(1, 10):
		var at := stem_from.lerp(stem_to, i / 10.0)
		var offset := side * radius * .84 * (1.0 if i % 2 == 0 else -1.0)
		var tip := at + offset + Vector3.UP * (.19 + .035 * (i % 3))
		for point in [at - forward * .075, at + forward * .075, tip]:
			mesh.surface_add_vertex(point)
	var material: StandardMaterial3D = hint.mesh.material_override
	var pulse := .82 + .10 * sin(Time.get_ticks_msec() * .008)
	material.albedo_color = Color(.83, .98, .7, pulse)
	material.emission = Color(.44, .62, .25)
	hint.root.visible = Geometry3D.get_closest_point_to_segment(view.observer, from, to).distance_to(view.observer) <= view.sight + radius
