extends RefCounted
## Local projection of the existing floor-scoped presentation receipts.
const DODGE_DURATION := .24
const SCUFF_TINT := Color("#c2af88")
const CONTROLS := {
	"trail.width":[1.0,.3,1.6,.05,"Edge width","×"],
	"trail.fade":[.105,.04,.20,.005,"Edge persistence","s"],
	"trail.opacity":[.68,0.,1.,.05,"Edge opacity","×"],
	"projectile.tail":[.55,0.,1.,.05,"Flight wake opacity","×"],
	"dodge.dust":[.65,0.,1.,.05,"Foot scuff opacity","×"],
	"text.detail":[0.,0.,1.,1.,"Show every repeated proc caption","off/on"],
}

static func confirmed_dodge(world: Node, owner: int, previous: Vector3, landing: Vector3) -> void:
	world.emit_combat_event("dodge","foot_scuff",previous,landing,DODGE_DURATION,SCUFF_TINT,0,owner)

static func triangle(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)

static func projectile(painter: Node, mesh: ImmediateMesh, effect: Dictionary, from: Vector3, to: Vector3, t: float, opacity: float) -> void:
	var event: Dictionary=effect.event
	var height:=Vector3.UP*float(event.get("height",1.05))
	var line:=from.direction_to(to)
	if line.is_zero_approx(): line=Vector3.FORWARD
	var side:=line.cross(Vector3.UP).normalized()
	var up:=side.cross(line).normalized()
	var release: Vector3=effect.get("visual_from",from+height)
	# The handoff frame uses the reviewed socket. Every travelling frame uses
	# the captured path and flight time. Height alone eases out of the hand.
	var head:=from.lerp(to,t)+height
	head.y+= (release.y-from.y-height.y)*(1.-smoothstep(0.,.32,t))
	if t==0.: head=release
	# Brief paired flicks at the measured release socket keep the nock / muzzle
	# legible even when a guest's first visible flight frame arrives late.
	var elapsed:=t*float(event.get("duration",.14))
	if effect.has("visual_from") and elapsed<.055:
		var release_phase:=elapsed/.055
		mesh.surface_set_color(Color(.94,.9,.71,(1.-release_phase)*.67))
		for sign_value: float in [-1.,1.]:
			var rim:=release+side*sign_value*(.04+.10*release_phase)
			triangle(mesh,rim,release-line*.10,release-line*.035+up*.034)
	var travel:=from.distance_to(to)*t
	var tail:=minf(travel,.68 if event.shape=="arrow" else .43)
	var size:=float(event.get("projectile_radius",.1))
	var far:=head-line*tail
	mesh.surface_set_color(Color(1,1,1,0))
	mesh.surface_add_vertex(far)
	mesh.surface_set_color(Color(.86,.87,.71,opacity))
	mesh.surface_add_vertex(head-side*.045)
	mesh.surface_add_vertex(head+side*.045)
	if event.shape in ["arrow","bolt"]:
		var length:=.60 if event.shape=="arrow" else .42
		mesh.surface_set_color(Color(.64,.53,.34,1))
		painter.ribbon(mesh,head-line*length,head-line*.075,.027 if event.shape=="arrow" else .047)
		mesh.surface_set_color(Color(.98,.95,.78,1))
		var base:=head-line*(.14 if event.shape=="arrow" else .17)
		var half:=minf(size,.056 if event.shape=="arrow" else .085)
		for axis: Vector3 in [side,up]:
			triangle(mesh,head,base-axis*half,base+axis*half)
		mesh.surface_set_color(Color(.84,.81,.61,1))
		for sign_value: float in [-1.,1.]:
			triangle(mesh,head-line*(length-.14),head-line*length,head-line*(length-.025)+(side*sign_value+up*.42)*half*1.35)
	elif event.shape=="petal":
		mesh.surface_set_color(Color(1,.89,.78,1))
		var spine:=head-line*.14+up*.035
		for sign_value: float in [-1.,1.]:
			var rim:=head-line*.13+side*sign_value*size*.8
			triangle(mesh,head,rim,spine)
			triangle(mesh,rim,head-line*.31,spine)
	if effect.has("glyph"):
		effect.glyph.position=head
		effect.glyph.rotation.y=t*TAU*3
	mesh.surface_set_color(Color.WHITE)

static func foot_scuff(mesh: ImmediateMesh, start: Vector3, end: Vector3, phase: float, opacity: float) -> void:
	var forward:=start.direction_to(end)
	var side:=forward.cross(Vector3.UP)
	for i in 6:
		var sign_value:=1. if i%2 else -1.
		var slide:=minf(start.distance_to(end),.48)*i/6.
		var at:=start+forward*slide+side*sign_value*(.075+.20*phase)
		at+=Vector3.UP*(.045+sin(phase*PI)*(.08+.012*i))-forward*phase*(.17+.03*i)
		var width:=.045*(1.-phase*.7)
		mesh.surface_set_color(Color(.9,.82,.67,opacity*(1.-smoothstep(.15,1.,phase))))
		triangle(mesh,at-side*width,at+side*width,at-forward*(.11+.03*i)+Vector3.UP*width)
	mesh.surface_set_color(Color.WHITE)

static func danger_marks(painter: Node, mesh: ImmediateMesh, center: Vector3, forward: Vector3, span: float, radius: float, count: int) -> void:
	# Paired dark/light teeth terminate inside the existing boundary.
	for i in count:
		var dir:=forward.rotated(Vector3.UP,span*((i+.5)/count-.5))
		var outside:=center+dir*maxf(0,radius-.045)
		var inside:=outside-dir*minf(radius*.18,.18)
		mesh.surface_set_color(Color(.16,.13,.12,1))
		painter.ribbon(mesh,inside,outside,.092)
		mesh.surface_set_color(Color.WHITE)
		painter.ribbon(mesh,inside+Vector3.UP*.007,outside+Vector3.UP*.007,.034)
