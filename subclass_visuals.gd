extends RefCounted

static func release(fx: Node3D, mesh: ImmediateMesh, event: Dictionary, origin: Vector3, endpoint: Vector3, t: float) -> void:
	var style: String = event.shape
	var radius: float = event.reach
	var pattern: String = event.pattern
	var center := endpoint if pattern in ["ground","target","dash"] else origin
	var advance := ease(t,.32)
	var width := .02+.055*(1.0-t)
	if pattern in ["line","dash","retreat"]:
		var direction := (endpoint-origin).normalized()
		var side := direction.cross(Vector3.UP)
		var travel := origin.lerp(endpoint,advance)
		if style == "salvo":
			for lane in [-.7,0.0,.7]:
				var offset := side*float(event.width)*float(lane)+Vector3.UP*(.64+absf(lane)*.2)
				fx.ribbon(mesh,origin.lerp(travel,.55)+offset,travel+offset,width)
				for wing in [-1.0,1.0]:
					fx.ribbon(mesh,travel+offset,travel+offset-direction*.23+side*.14*wing,width*.6)
			return
		for strand in [-1.0,1.0]:
			fx.ribbon(mesh,origin+side*.25*strand+Vector3.UP*.42,travel+side*.07*strand+Vector3.UP*.18,width)
	if style == "weave":
		for strand in [-1.0,1.0]:
			var previous := origin+Vector3.UP*.2
			for i in 13:
				var u := (i+1.0)/13.0*advance
				var side := (endpoint-origin).normalized().cross(Vector3.UP)
				var at: Vector3 = origin.lerp(endpoint,u)+side*sin(u*TAU*2.0)*strand*.22+Vector3.UP*(.2+sin(u*PI)*.45)
				fx.ribbon(mesh,previous,at,width)
				previous = at
	if style in ["grave","harvest"]:
		var start := atan2(endpoint.z-origin.z,endpoint.x-origin.x)
		var span := float(event.span) if style == "grave" else TAU
		for band in range(2):
			var depth := radius*(.72+band*.28)
			for i in range(24):
				var first := start+span*((i/24.0)*advance-.5)
				var second := start+span*(((i+1)/24.0)*advance-.5)
				var lift := Vector3.UP*(.32+band*.17)
				fx.ribbon(mesh,origin+radial(first)*depth+lift,origin+radial(second)*depth+lift,width)
		return
	if radius <= 0.0:
		return
	center += Vector3.UP*.11
	fx.circle(mesh,center,radius*advance,width)
	match style:
		"bloom", "sanctuary":
			var petals := 7 if style == "bloom" else 9
			for i in range(petals):
				var a := i*TAU/petals+t*.35
				var stem := center+radial(a)*radius*.24*advance
				var tip := center+radial(a)*radius*.94*advance+Vector3.UP*sin(t*PI)*(.68 if style=="bloom" else .34)
				for wing in [-1.0,1.0]:
					var edge := center+radial(a+.22*wing)*radius*.67*advance
					fx.ribbon(mesh,stem,edge,width)
					fx.ribbon(mesh,edge,tip,width)
		"silk":
			for i in range(6):
				var edge := center+radial(i*TAU/6)*radius*advance
				var next := center+radial((i+2)*TAU/6)*radius*advance
				fx.ribbon(mesh,edge,next,width*.58)
			fx.circle(mesh,center+Vector3.UP*sin(t*PI)*.55,radius*.53*advance,width)
		"weave", "snare", "retreat":
			for i in range(8):
				var a := i*TAU/8
				var foot := center+radial(a)*radius*.93*advance
				var elbow := center+radial(a-.16)*radius*.73*advance+Vector3.UP*.17
				var tip := center+radial(a+.23)*radius*.52*advance+Vector3.UP*sin(t*PI)*.62
				fx.ribbon(mesh,foot,elbow,width)
				fx.ribbon(mesh,elbow,tip,width)
		"omen":
			for i in range(5):
				var base := center+radial(i*TAU/5)*radius*.72
				var cut := base.lerp(center,.27)+Vector3.UP*(1.3*(1.0-advance))
				fx.ribbon(mesh,cut,base+Vector3.UP*.08,width)
		"bell":
			for i in range(1,4):
				var wave := fposmod(1.0-t+i*.22,1.0)
				fx.circle(mesh,center+Vector3.UP*.12*i,radius*maxf(.09,wave),width*.65)
		"veil":
			var angle := atan2(endpoint.z-origin.z,endpoint.x-origin.x)
			for i in range(2):
				fx.ribbon(mesh,center+radial(angle+.7+i*1.74)*radius*advance,center-radial(angle+.7+i*1.74)*radius*advance+Vector3.UP*.72,width)


static func radial(angle: float) -> Vector3:
	return Vector3(cos(angle),0,sin(angle))
