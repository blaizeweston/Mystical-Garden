extends RefCounted
## Cosmetic shapes and status cues use the positions and sizes already resolved by the host.

const HAZARDS := {
	"web": {"label": "Web", "warning": "#ceadf1", "active": "#bf75f3"},
	"spores": {"label": "Spores", "warning": "#e1d78d", "active": "#c8df67"},
	"ember": {"label": "Embers", "warning": "#f6ae69", "active": "#ff633b"},
}
const THREAT := Color("#ffbd83")
const SUPPORT := Color("#abd98e")


static func release(game: Node, shape: String, from: Vector3, to: Vector3, radius: float,
		color: Color = THREAT, width: float = 0.0, span: float = 0.0) -> void:
	game.emit_combat_event("enemy_release", shape, from, to, .42, color, radius, 0,
		{"width": width, "span": span})


static func movement(game: Node, attack: Dictionary, padding: float) -> void:
	if attack.role == "charge":
		var width := float(attack.width) + padding
		var via: Vector3 = attack.via
		if via.is_finite():
			release(game, "lane", attack.from, via, width, THREAT, width)
			release(game, "lane", via, attack.to, float(attack.radius) + padding, THREAT, width)
		else:
			release(game, "lane", attack.from, attack.to, float(attack.radius) + padding, THREAT, width)
	else:
		release(game, "burst", attack.from, attack.to, attack.radius)


static func stopped(game: Node, point: Vector3) -> void:
	game.emit_combat_event("proc", "stopped", point, point, .5, Color("#bce0bd"), 0, -2)


static func paint_release(fx: Node, mesh: ImmediateMesh, event: Dictionary, from: Vector3, to: Vector3, phase: float) -> void:
	var reach := float(event.reach)
	var height := Vector3.UP * .09
	match str(event.shape):
		"orchard_cage":
			var lift := sin(clampf(phase, 0, 1) * PI) * .7
			preload("res://boss_lair_visuals.gd").cage(fx, mesh, from + height, (to - from).normalized(),
				reach, float(event.width), float(event.span), lift)
		"orchard_sweep":
			var forward := (to - from).normalized()
			var inner := float(event.width)
			var half := float(event.span) * .5
			var sweep := lerpf(inner, reach, smoothstep(0, .65, phase))
			for i in 32:
				var a := forward.rotated(Vector3.UP, lerpf(-half, half, i / 32.0))
				var b := forward.rotated(Vector3.UP, lerpf(-half, half, (i + 1) / 32.0))
				fx.ribbon(mesh, from + height + a * sweep, from + height + b * sweep, .18)
		"sector":
			var forward := (to - from).normalized()
			var half := float(event.span) * .5
			var sweep := reach * smoothstep(0, .65, phase)
			for i in 20:
				var a := forward.rotated(Vector3.UP, lerpf(-half, half, i / 20.0))
				var b := forward.rotated(Vector3.UP, lerpf(-half, half, (i + 1) / 20.0))
				fx.ribbon(mesh, from + height + a * sweep, from + height + b * sweep, .16)
		"lane", "pulled", "restored", "trophy":
			var center := from.lerp(to, smoothstep(0, .65, phase))
			var tail := from.lerp(to, maxf(0, phase - .28))
			var depth := Vector3.UP * (.7 if event.shape in ["pulled", "restored", "trophy"] else .16)
			fx.ribbon(mesh, tail + depth, center + depth, maxf(.07, float(event.width) * .34))
			if event.shape == "lane":
				fx.circle(mesh, to + height, reach, .085)
			else:
				fx.circle(mesh, to + height, .18 + .36 * phase, .065)
		_:
			fx.circle(mesh, to + height, maxf(.03, reach * smoothstep(0, .60, phase)), .13)
			fx.circle(mesh, to + height, maxf(.03, reach * phase * .68), .045)


static func paint_hazard(fx: Node, mesh: ImmediateMesh, kind: String, at: Vector3, radius: float, active: bool) -> void:
	fx.circle(mesh, at, radius, .105 if active else .055)
	if not active:
		return
	match kind:
		"web":
			for i in 6:
				var ray := Vector3.RIGHT.rotated(Vector3.UP, i * TAU / 6.0) * radius
				fx.ribbon(mesh, at, at + ray, .04)
			fx.circle(mesh, at, radius * .52, .04)
		"spores":
			for i in 5:
				var ray := Vector3.RIGHT.rotated(Vector3.UP, i * TAU / 5.0) * radius * .58
				fx.circle(mesh, at + ray, radius * .15, .04)
		"ember":
			for i in 6:
				var ray := Vector3.RIGHT.rotated(Vector3.UP, i * TAU / 6.0) * radius
				fx.ribbon(mesh, at + ray * .26, at + ray * .85, .075)
