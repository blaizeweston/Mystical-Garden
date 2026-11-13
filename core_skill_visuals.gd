extends RefCounted
## The host sends the same ground shapes it uses for contact. Details animate inside those shapes.

const Contact = preload("res://weapon_contact.gd")
const LIFT := Vector3(0, .085, 0)


static func draw(view: Node, mesh: ImmediateMesh, event: Dictionary, center: Vector3, progress: float, lingering: bool) -> void:
	var skill: String = event.get("skill", event.get("shape", ""))
	var elapsed := float(event.get("core_phase", 0)) / 1000.0
	var clock := float(Time.get_ticks_msec()) / 1000.0
	var shapes: Array = event.core_shapes
	if lingering and skill == "worldbloom" and elapsed >= .85:
		shapes = event.get("core_secondary", [])
	if lingering and skill == "eclipse_maw":
		for seam in event.get("core_secondary", []):
			outline(view, mesh, seam, .032)
	if skill == "moon_snare":
		moon(view, mesh, shapes, not lingering or bool(event.get("core_armed", false)), clock)
		return
	for index in shapes.size():
		var shape: Dictionary = shapes[index]
		var width := .036 if lingering else .065
		if skill == "spore_seal" and lingering:
			var state: int = event.get("core_seals", [])[index]
			seal(view, mesh, view.point(shape.at) + LIFT, float(shape.radius), state, bool(event.get("core_armed", false)), clock)
			continue
		if not (lingering and skill == "eclipse_maw"):
			outline(view, mesh, shape, width)
		match shape.kind:
			"strip", "capsule":
				lane_detail(view, mesh, shape, center, skill, progress, elapsed, clock, lingering)
			"cone":
				fan_detail(view, mesh, shape, skill, progress)
			"area":
				area_detail(view, mesh, view.point(shape.at) + LIFT, float(shape.radius), skill, progress, elapsed, clock, bool(event.get("core_inner", false)), lingering)


static func outline(view: Node, mesh: ImmediateMesh, shape: Dictionary, width: float) -> void:
	var points := PackedVector3Array()
	match shape.kind:
		"area":
			view.circle(mesh, view.point(shape.at) + LIFT, float(shape.radius), width)
			return
		"cone":
			var at: Vector3 = view.point(shape.at) + LIFT
			var forward: Vector3 = view.point(shape.forward)
			points.append(at)
			for i in 24:
				points.append(at + forward.rotated(Vector3.UP, (i / 23.0 - .5) * float(shape.span)) * float(shape.radius))
		"strip", "capsule":
			var from: Vector3 = view.point(shape.from) + LIFT
			var to: Vector3 = view.point(shape.to) + LIFT
			if shape.kind == "capsule":
				points = Contact.outline({"pattern": "line", "width": shape.width, "reach": from.distance_to(to)}, from, to)
			else:
				var side := (to - from).normalized().cross(Vector3.UP) * float(shape.width)
				points = PackedVector3Array([from + side, to + side, to - side, from - side])
	for i in points.size():
		view.ribbon(mesh, points[i], points[(i + 1) % points.size()], width)


static func lane_detail(view: Node, mesh: ImmediateMesh, shape: Dictionary, center: Vector3, skill: String,
		progress: float, elapsed: float, clock: float, lingering: bool) -> void:
	var from: Vector3 = view.point(shape.from) + LIFT
	var to: Vector3 = view.point(shape.to) + LIFT
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.UP) * float(shape.width)
	var growth := smoothstep(0, .4, progress)
	if lingering and skill == "worldbloom":
		growth = smoothstep(0, .30, elapsed)
	match skill:
		"ember_wake":
			view.ribbon(mesh, from, to, .12)
			for i in 16:
				var base := from.lerp(to, (i + .5) / 16.0) + side * sin(i * 4.73) * .67
				var flame := .12 + .36 * fposmod(i * .37 + clock * 1.65, 1.0)
				view.ribbon(mesh, base, base + Vector3.UP * flame + axis * .12, .05 + flame * .10)
		"eclipse_maw":
			var offset := Vector3.ZERO
			if lingering:
				var midpoint := (from + to) * .5
				offset = -side.normalized() * (midpoint - center).dot(side.normalized()) * smoothstep(0, 1.18, elapsed)
			var height := .22 + (.43 * sin(clampf(elapsed / 1.2, 0, 1) * PI) if lingering else .2)
			var lip := Vector3.UP * height
			view.ribbon(mesh, from + offset + lip, to + offset + lip, .135)
			for i in 9:
				var base := from.lerp(to, (i + .5) / 9.0) + offset + lip
				var inward := (center - base)
				inward.y = 0.0
				var tip := base + inward.normalized() * .25 - Vector3.UP * height * .8
				view.ribbon(mesh, base - axis * .11, tip, .085)
				view.ribbon(mesh, base + axis * .11, tip, .085)
		"worldbloom":
			var tip := from.lerp(to, growth)
			view.ribbon(mesh, from, tip, .14)
			for i in 5:
				var fork := from.lerp(tip, (i + 1.0) / 6.0)
				var branch := fork + axis * .22 + side * (.78 if i % 2 == 0 else -.78)
				view.ribbon(mesh, fork, branch + Vector3.UP * .15 * growth, .065)
		"sun_pillar":
			var flash := .45 + .55 * sin(PI * progress)
			view.ribbon(mesh, from, to, .045 if lingering else .25 * flash)
			for i in 7:
				var at := from.lerp(to, (i + .5) / 7.0)
				if lingering:
					view.ribbon(mesh, at - side * .65, at + side * .65, .04)
				else:
					view.ribbon(mesh, at, at + Vector3.UP * (1.1 - absf(i - 3) * .23) * flash, .08)
		"dewfall":
			for i in 14:
				var at := from.lerp(to, (i + .5) / 14.0) + side * sin(i * 3.12) * .78
				var drop := Vector3.UP * (1.55 * (1.0 - progress) + .12)
				view.ribbon(mesh, at + drop, at + drop + Vector3.UP * (.16 + .2 * (i % 3)), .055)
				view.ribbon(mesh, at - side * growth * .32, at + side * growth * .32, .055)
		"ironbark":
			for i in 6:
				var at := from.lerp(to, (i + .5) / 6.0)
				var crown := Vector3.UP * .74 * growth
				var rim := axis * from.distance_to(to) / 14.0
				view.ribbon(mesh, at - rim, at + crown - rim * .65, .14)
				view.ribbon(mesh, at + rim, at + crown + rim * .65, .14)
				view.ribbon(mesh, at + crown - rim * .65, at + crown + rim * .65, .105)
		"phantom_step":
			var front := from.lerp(to, growth)
			view.ribbon(mesh, from, front, .09)
			for i in 8:
				var at := from.lerp(front, (i + .5) / 8.0)
				view.ribbon(mesh, at - side * .8, at + Vector3.UP * .32 * sin(progress * PI), .046)
				view.ribbon(mesh, at + side * .8, at + Vector3.UP * .32 * sin(progress * PI), .046)
		"crownlink":
			for i in 7:
				var at := from.lerp(to, (i + .5) / 7.0)
				view.ribbon(mesh, at - side * .82, at + Vector3.UP * .22 * growth, .052)
				view.ribbon(mesh, at + side * .82, at + Vector3.UP * .22 * growth, .052)


static func fan_detail(view: Node, mesh: ImmediateMesh, shape: Dictionary, skill: String, progress: float) -> void:
	var at: Vector3 = view.point(shape.at) + LIFT
	var aim: Vector3 = view.point(shape.forward)
	var radius: float = shape.radius
	var span: float = shape.span
	var growth := smoothstep(0, .5, progress)
	if skill == "hush":
		for band in 3:
			var reach := radius * clampf(growth - band * .19, .10, 1.0)
			for i in 18:
				var start := aim.rotated(Vector3.UP, (i / 18.0 - .5) * span)
				var end := aim.rotated(Vector3.UP, ((i + 1.0) / 18.0 - .5) * span)
				view.ribbon(mesh, at + start * reach, at + end * reach, .095 - band * .02)
		return
	for i in 7:
		var ray := aim.rotated(Vector3.UP, (i / 6.0 - .5) * span * .91)
		var side := ray.cross(Vector3.UP)
		var tip := at + ray * radius * growth + Vector3.UP * (.36 if skill == "rime_bloom" else .11)
		var mid := at.lerp(tip, .62)
		view.ribbon(mesh, at, tip, .05)
		var spread := .22 if skill == "rime_bloom" else .11
		for direction in [-1, 1]:
			var edge: Vector3 = mid + side * spread * direction * growth
			view.ribbon(mesh, at if skill == "rime_bloom" else mid, edge, .045)
			view.ribbon(mesh, edge, tip, .07)


static func area_detail(view: Node, mesh: ImmediateMesh, at: Vector3, radius: float, skill: String, progress: float,
		elapsed: float, clock: float, inner: bool, lingering: bool) -> void:
	match skill:
		"gravity_well":
			if inner:
				view.circle(mesh, at, radius * .28, .074)
			for strand in 3:
				for i in 28:
					var a := spiral(at, radius, strand, i / 28.0, elapsed)
					var b := spiral(at, radius, strand, (i + 1.0) / 28.0, elapsed)
					view.ribbon(mesh, a, b, .052)
		"worldbloom":
			var height := .65 + .24 * sin(PI * progress)
			view.circle(mesh, at + Vector3.UP * height, radius * .86, .075)
			for i in 8:
				var ray := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 8.0)
				view.ribbon(mesh, at + ray * radius, at + ray * radius * .86 + Vector3.UP * height, .06)
		"grave_lantern":
			if lingering:
				var bob := .65 + sin(clock * 4.5) * .11
				view.circle(mesh, at + Vector3.UP * bob, .20, .11)
				view.ribbon(mesh, at, at + Vector3.UP * (bob + .23), .085)
			else:
				for i in 12:
					var ray := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 12)
					view.ribbon(mesh, at, at + ray * radius * progress + Vector3.UP * (sin(PI * progress) * .7), .075)
		"dream_lure":
			var hover := .65 + .17 * sin(clock * 6.0)
			for i in 3:
				var height := hover + i * .29
				view.circle(mesh, at + Vector3.UP * height, (.23 + .12 * sin(clock * 5.0 + i)) * (1.3 if lingering else progress + 1), .08)
			for i in 6:
				var ray := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 6.0 + clock)
				view.ribbon(mesh, at + ray * radius * .79, at + ray * radius * .62 + Vector3.UP * .2, .063)
		"rime_bloom":
			for i in 6:
				var ray := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 6.0)
				view.ribbon(mesh, at + Vector3.UP * .22, at + ray * (radius * progress + .13) + Vector3.UP * (.18 + .75 * progress), .06)
		"ironbark":
			view.circle(mesh, at, radius * maxf(.1, progress), .115)
		"spore_seal":
			view.circle(mesh, at + Vector3.UP * progress, radius * progress, .11)


static func spiral(at: Vector3, radius: float, strand: int, along: float, elapsed: float) -> Vector3:
	var angle := strand * TAU / 3.0 + along * 4.2 + elapsed * 4.6
	return at + Vector3(cos(angle), .015, sin(angle)) * (radius * (1.0 - along * .92))


static func seal(view: Node, mesh: ImmediateMesh, at: Vector3, radius: float, state: int, armed: bool, clock: float) -> void:
	view.circle(mesh, at, radius, .06 if armed and state >= 0 else .023)
	if state < 0:
		view.ribbon(mesh, at - Vector3.RIGHT * radius * .45, at + Vector3.RIGHT * radius * .45, .045)
		return
	var crown := .30 + (.13 * sin(clock * 5.0) if armed else -.14)
	for i in 5:
		var ray := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 5.0)
		view.ribbon(mesh, at + ray * radius * .7, at + Vector3.UP * crown + ray * radius * .25, .065)
		if state > 0:
			view.ribbon(mesh, at + Vector3.UP * crown + ray * radius * .25, at + Vector3.UP * (crown + .13), .055)


static func moon(view: Node, mesh: ImmediateMesh, shapes: Array, armed: bool, clock: float) -> void:
	for i in shapes.size():
		var shape: Dictionary = shapes[i]
		var from: Vector3 = view.point(shape.from) + LIFT
		var to: Vector3 = view.point(shape.to) + LIFT
		var side := (to - from).normalized().cross(Vector3.UP) * float(shape.width)
		for direction in [-1, 1]:
			view.ribbon(mesh, from + side * direction, to + side * direction, .057 if armed else .03)
		view.ribbon(mesh, from, to, .08)
		if armed and i % 2 == 0:
			view.ribbon(mesh, from, from + Vector3.UP * (.16 + .13 * sin(clock * 5.0 + i)), .075)
