extends RefCounted

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Actors=preload("res://frost_combat.gd")
const Clock=preload("res://affinity_time.gd")
const Hurt=preload("res://enemy_hurtbox.gd")
const Contact=preload("res://weapon_contact.gd")
const Journal=preload("res://diagnostic_journal.gd")
const COLOR:=Color("#ad8bcb")
const CORE_RADIUS:=2.6
const AREA_RADIUS:=2.45
const GATHER_MS:=1080
const PULSE_MS:=105
const CORE_CD:=7800
const FORM_INTERVAL:=1850
const DURATION:=850
const ALLOWANCE:=1.10
const STAND_OFF:=.12
const MOTION_SAMPLE:=.10
const FORM_READY:="affinity_void_form_ready"
const ALLOWANCE_STATE:="affinity_void_allowance"
const PENDING:=&"affinity_void_displacement"
const SCOPES:={"core":0,"catalyst":1,"form":2}
const QUALITY:={
	"ordinary":{"collapse":21,"form_hp":10,"pulse":12,"form_force":.56,"pulse_force":.51,"gather_step":.18,"gather_total":.92},
	"refined":{"collapse":29,"form_hp":15,"pulse":17,"form_force":.78,"pulse_force":.74,"gather_step":.24,"gather_total":1.20},
}
const VERSION_DATA:=[CORE_RADIUS,AREA_RADIUS,GATHER_MS,PULSE_MS,CORE_CD,FORM_INTERVAL,DURATION,ALLOWANCE,STAND_OFF,MOTION_SAMPLE,SCOPES,QUALITY]


static func description(slot: String, quality: String) -> String:
	var q: Dictionary=QUALITY[quality]
	match slot:
		"core": return "Gravity Well · Gather for %.1f s, then deal %d HP once to enemies still within %.1f m. %.1f s cooldown." % [GATHER_MS/1000.0,q.collapse,CORE_RADIUS,CORE_CD/1000.0]
		"form": return "Drawing Strikes · First eligible direct hit adds %d HP and draws up to %.2f m toward you. %.2f s interval. Native displacement takes priority." % [q.form_hp,q.form_force,FORM_INTERVAL/1000.0]
	return "Void Catalyst · Mapped offense draws inward. An actual block, heal or pure movement repels for %d HP within %.2f m. Resistance and clearance can stop motion while damage still applies." % [q.pulse,AREA_RADIUS]


static func resisted(game: Node, target: int, now: int) -> bool:
	if target==-1:
		return game.tactics.boss_kind>=0 or game.tactics.winding_up or now<int(game.tactics.rooted_until) or Actors.rooted(game.tactics.memory,now)
	var scout: Dictionary=game.encounter.scout(target)
	return int(scout.windup)>0 or now<int(scout.rooted_until) or Actors.rooted(scout,now)


static func queue_motion(game: Node, event: RefCounted, target: int, center: Vector3, inward: bool, strength: float, cast := {}) -> void:
	if strength<=0.0 or not Actors.valid_target(game,target): return
	var token:=Contact.token(game,target)
	var point: Vector3=game.enemy_position(target)
	var direction: Vector3=(center-point) if inward else (point-center)
	direction.y=0.0
	var distance:=direction.length()
	if distance<=.001: return
	if inward: strength=minf(strength,maxf(0.0,distance-Hurt.radius(game,target)-STAND_OFF))
	if strength<=.001: return
	var mask: int=game.enemy_mutations if target==-1 else game.encounter.scout(target).mutations
	if mask & game.Enemies.BARK: strength*=.60
	var pending: Dictionary=game.get_meta(PENDING,{})
	var intents: Array=pending.get(target,[])
	intents.append({"token":token,"epoch":event.epoch,"scope":SCOPES[event.source],"actor":event.actor,"source_life":event.life_generation,
		"direction":direction/distance,"strength":strength,"cast":cast})
	pending[target]=intents
	game.set_meta(PENDING,pending)


static func precedes(a: Dictionary, b: Dictionary) -> bool:
	if a.strength!=b.strength: return a.strength>b.strength
	if a.scope!=b.scope: return a.scope<b.scope
	if a.actor!=b.actor: return a.actor<b.actor
	if a.direction.x!=b.direction.x: return a.direction.x<b.direction.x
	return a.direction.z<b.direction.z


static func safe_motion(game: Node, target: int, point: Vector3, end: Vector3) -> Vector3:
	var radius:=Hurt.radius(game,target)
	var stops: Array=[]
	for id in game.Life.living_ids(game):
		stops.append([game.players[id].pos,radius+.34+STAND_OFF])
	for other in range(-1,game.encounter.scout_count()):
		if other!=target and Actors.valid_target(game,other):
			stops.append([game.enemy_position(other),radius+Hurt.radius(game,other)+STAND_OFF])
	var current:=point
	var clearance:=maxf(game.Battlefield.CLEARANCE,radius)
	var steps:=maxi(1,ceili(point.distance_to(end)/MOTION_SAMPLE))
	for i in steps:
		var next:=point.lerp(end,(i+1)/float(steps))
		# Visibility can cross water. Displacement also requires a walkable footprint.
		if game.battlefield.occupied(next,clearance) or not game.battlefield.clear_line(current,next,clearance):
			break
		var blocked:=false
		for stop in stops:
			var center: Vector3=stop[0]
			if next.distance_to(center)<float(stop[1]) and next.distance_squared_to(center)+.000001<current.distance_squared_to(center):
				blocked=true
				break
		if blocked: break
		current=next
	return current


static func resolve_motion(game: Node, elapsed: int, now: int) -> void:
	if not game.has_meta(PENDING): return
	var pending: Dictionary=game.get_meta(PENDING)
	game.remove_meta(PENDING)
	var targets:=pending.keys()
	targets.sort()
	for target in targets:
		if not Actors.valid_target(game,target) or resisted(game,target,now): continue
		var token:=Contact.token(game,target)
		var options: Array = pending[target].filter(func(row):
			return row.token==token and int(row.epoch)==game.participation.epoch() \
				and PlayerLifecycle.matches(game.players.get(row.actor,{}),int(row.source_life)))
		if options.is_empty(): continue
		options.sort_custom(precedes)
		var intent: Dictionary=options[0]
		var body:=Actors.body(game,target)
		var moves: Array=body.get(ALLOWANCE_STATE,[]).filter(func(move):return elapsed-int(move.at)<DURATION)
		var strength: float=intent.strength
		var used:=0.0
		for move in moves: used+=float(move.amount)
		strength=minf(strength,ALLOWANCE-used)
		if not moves.is_empty() and Vector3(moves[0].direction).dot(intent.direction)<-.10:
			strength=0.0
		if strength<=.001: continue
		var point: Vector3=game.enemy_position(target)
		var end:=safe_motion(game,target,point,game.bound_position(point+Vector3(intent.direction)*strength,true))
		var distance:=point.distance_to(end)
		if distance<=.001: continue
		if target==-1: game.tactics.position=end
		else: body.pos=end
		moves.append({"at":elapsed,"amount":distance,"direction":intent.direction})
		body[ALLOWANCE_STATE]=moves
		var cast: Dictionary=intent.cast
		if not cast.is_empty():
			cast.moved[token]=float(cast.moved.get(token,0.0))+distance


static func pulse(game: Node, event: RefCounted, center: Vector3, inward: bool, now: int, targets: Array, preserve_native := false) -> void:
	var q: Dictionary=event.potency()
	game.emit_combat_event("ability","void_pulse",center,center,.46,COLOR,AREA_RADIUS,event.actor,
		{"label":"Compression" if inward else "Void repulsion"})
	for target in targets:
		if game.get_meta(game.Transactions.PENDING,false): break
		if not Actors.valid_target(game,target) or not game.battlefield.clear_line(center,game.enemy_position(target)): continue
		if not preserve_native: queue_motion(game,event,target,center,inward,q.pulse_force)
		Actors.damage(game,event.actor,target,q.pulse,now,COLOR)


static func gather(game: Node, cast: Dictionary, now: int) -> bool:
	var elapsed:=Clock.now(game)
	var source: RefCounted=cast.affinity_action
	var q: Dictionary=source.potency()
	var center: Vector3=cast.center
	if not cast.grown:
		cast.grown=true
		cast.well_until=elapsed+GATHER_MS
		cast.next_well=elapsed
		cast.moved={}
	if elapsed>=int(cast.well_until):
		source.publish(game,"core_action","collapse","",now,{"center":center})
		return true
	if elapsed>=int(cast.next_well):
		cast.next_well=elapsed+PULSE_MS
		for target in game.skill_area_targets(center,CORE_RADIUS,center):
			var remaining: float=q.gather_total-float(cast.moved.get(Contact.token(game,target),0.0))
			queue_motion(game,source,target,center,true,minf(q.gather_step,remaining),cast)
	return false


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	var q: Dictionary=event.potency()
	match kind:
		"core_action":
			var center: Vector3=details.center
			game.emit_combat_event("ability","void_collapse",center,center,.55,COLOR,CORE_RADIUS,event.actor,{"label":"Gravity Well collapse"})
			for target in game.skill_area_targets(center,CORE_RADIUS,center):
				if game.get_meta(game.Transactions.PENDING,false): break
				Actors.damage(game,event.actor,target,q.collapse,now,COLOR)
		"weapon_contact":
			var p: Dictionary=game.players.get(event.actor,{})
			var elapsed:=Clock.now(game)
			if not game.Life.alive(p) or elapsed<int(p.get(FORM_READY,0)) or not event.take_response("void_form"): return
			p[FORM_READY]=elapsed+FORM_INTERVAL
			if not details.get("native_displacement",false):
				queue_motion(game,event,details.enemy,p.pos,true,q.form_force)
			Actors.damage(game,event.actor,details.enemy,q.form_hp,now,COLOR)
		"actual_block":
			pulse(game,event,details.center,false,now,game.skill_area_targets(details.center,AREA_RADIUS,details.center))
		"class_contact":
			if not event.take_response("void_offense"): return
			var center: Vector3=details.get("point",game.enemy_position(details.enemy))
			pulse(game,event,center,true,now,[details.enemy],details.get("native_displacement",false))
		"class_action":
			var center: Vector3=details.center
			match details.response:
				"compression":
					var targets: Array=details.enemies
					if targets.is_empty() and details.get("target_scope")=="designated_area":
						targets=game.skill_area_targets(center,float(details.radius),center)
					pulse(game,event,center,true,now,targets,details.get("native_displacement",false))
				"healing_repulsion","landing_repulsion":
					pulse(game,event,center,false,now,game.skill_area_targets(center,AREA_RADIUS,center))
