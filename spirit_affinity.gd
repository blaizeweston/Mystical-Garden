extends RefCounted

const Actors = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Hurt = preload("res://enemy_hurtbox.gd")
const Journal = preload("res://diagnostic_journal.gd")
const COLOR := Color("#bdafe8")
const STRIDES := "affinity_spirit_strides"
const FORM_READY := "affinity_spirit_form_ready"
const FOLLOW := "affinity_spirit_follow"
const TRACE := "affinity_spirit_trace"
const RESIST := "affinity_spirit_resist"
const STEP_DISTANCE := 2.2
const MIN_STEP := .28
const PLAYER_RADIUS := .34
const CORE_CD := 6500
const STRIDE_MS := 2500
const FOLLOW_MS := 4400
const FORM_INTERVAL := 1900
const READY_DISTANCE := .9
const TRACE_RADIUS := 3.4
const TRACE_RESIST := 4900
const WARD_RADIUS := 2.4
const QUALITY := {
	"ordinary":{"speed":.20,"trace_ms":750,"follow_hp":13},
	"refined":{"speed":.29,"trace_ms":1100,"follow_hp":18},
}
const VERSION_DATA := [STEP_DISTANCE,MIN_STEP,CORE_CD,STRIDE_MS,FOLLOW_MS,FORM_INTERVAL,READY_DISTANCE,TRACE_RADIUS,TRACE_RESIST,WARD_RADIUS,QUALITY]


static func description(slot: String, quality: String) -> String:
	var q: Dictionary=QUALITY[quality]
	var stride := "%d%% movement for %.1f s" % [roundi(q.speed*100),STRIDE_MS/1000.0]
	match slot:
		"core": return "Phantom Step · Move up to %.1f m in the chosen direction and gain %s. Briefly misleads current uncommitted pursuers. %.1f s cooldown." % [STEP_DISTANCE,stride,CORE_CD/1000.0]
		"form": return "Flowing Strikes · Direct hits periodically grant %s. Move %.1f m voluntarily, then land a new attack for +%d HP within %.1f s. %.1f s trigger interval." % [stride,READY_DISTANCE,q.follow_hp,FOLLOW_MS/1000.0,FORM_INTERVAL/1000.0]
	return "Spirit Catalyst · Mapped offense, healing and actual blocks grant %s. Blocks and movement can leave a %.2f s trace. Strongest stride applies." % [stride,q.trace_ms/1000.0]


static func scale(p: Dictionary, elapsed: int) -> float:
	var strongest := 0.0
	for source in p.get(STRIDES,{}).values():
		if int(source.until)>elapsed:
			strongest=maxf(strongest,float(source.speed))
	return 1.0+strongest


static func grant(game: Node, event: RefCounted, id: int) -> void:
	var p: Dictionary=game.players.get(id,{})
	if not game.Life.alive(p): return
	var elapsed:=Clock.now(game)
	var sources: Dictionary=p.get(STRIDES,{})
	var key: String="%d/%s"%[event.actor,event.source]
	var speed: float=event.potency().speed
	var old: Dictionary=sources.get(key,{})
	if int(old.get("until",0))>elapsed and float(old.speed)>speed: return
	sources[key]={"actor":event.actor,"quality":event.quality,"speed":speed,"until":elapsed+STRIDE_MS}
	p[STRIDES]=sources


static func movement(game: Node, p: Dictionary, before: Vector3, after: Vector3) -> void:
	var follow: Dictionary=p.get(FOLLOW,{})
	if follow.get("phase")!="prepared" or int(follow.until)<=Clock.now(game) or int(follow.epoch)!=game.combat_epoch: return
	follow.distance += after-before
	if Vector3(follow.distance).length()>=READY_DISTANCE:
		follow.phase="ready"


static func prepare(game: Node, event: RefCounted) -> void:
	var p: Dictionary=game.players.get(event.actor,{})
	var elapsed:=Clock.now(game)
	if not game.Life.alive(p) or elapsed<int(p.get(FORM_READY,0)) or not event.take_response("spirit_form"): return
	p[FORM_READY]=elapsed+FORM_INTERVAL
	grant(game,event,event.actor)
	var existing: Dictionary=p.get(FOLLOW,{})
	if int(existing.get("until",0))<=elapsed:
		p[FOLLOW]={"phase":"prepared","distance":Vector3.ZERO,"until":elapsed+FOLLOW_MS,
			"actor":event.actor,"quality":event.quality,"damage":event.potency().follow_hp,"epoch":game.combat_epoch}


static func launch(game: Node, p: Dictionary, stats: Dictionary, lanes: int) -> void:
	var follow: Dictionary=p.get(FOLLOW,{})
	var event: RefCounted=stats.get("cr02_action")
	if event==null or event.source not in ["form","native_weapon"] or follow.get("phase")!="ready" or int(follow.until)<=Clock.now(game):
		return
	follow.phase="claimed"
	follow.attack=event.identity
	follow.lanes=lanes


static func finish(game: Node, p: Dictionary, stats: Dictionary) -> void:
	var follow: Dictionary=p.get(FOLLOW,{})
	var event: RefCounted=stats.get("cr02_action")
	if event==null or follow.get("phase")!="claimed" or int(follow.attack)!=event.identity: return
	follow.lanes-=1
	if follow.lanes<=0:
		if int(follow.until)<=Clock.now(game): p.erase(FOLLOW)
		else: follow.phase="ready"


static func contact(game: Node, event: RefCounted, target: int, now: int) -> void:
	var p: Dictionary=game.players.get(event.actor,{})
	var follow: Dictionary=p.get(FOLLOW,{})
	if follow.get("phase")!="claimed" or int(follow.attack)!=event.identity or int(follow.until)<=Clock.now(game):
		return
	p.erase(FOLLOW)
	game.emit_combat_event("link","spirit_follow",p.pos,game.enemy_position(target),.28,COLOR,0.0,event.actor)
	Actors.damage(game,follow.actor,target,follow.damage,now,COLOR)


static func tick(game: Node, elapsed: int) -> void:
	for p in game.players.values():
		var sources: Dictionary=p.get(STRIDES,{})
		for key in sources.keys():
			if int(sources[key].until)<=elapsed: sources.erase(key)
		if sources.is_empty(): p.erase(STRIDES)
		var follow: Dictionary=p.get(FOLLOW,{})
		if int(follow.get("until",0))<=elapsed: p.erase(FOLLOW)


static func clear(p: Dictionary) -> void:
	p.erase(STRIDES)
	p.erase(FORM_READY)
	p.erase(FOLLOW)


static func step(game: Node, actor: int, forward: Vector3, distance := STEP_DISTANCE) -> Vector3:
	var origin: Vector3=game.players[actor].pos
	var end: Vector3=game.battlefield.dash(origin,game.bound_position(origin+forward*distance,true))
	var stops: Array=[]
	for id in game.players:
		var p: Dictionary=game.players[id]
		if id!=actor and p.get("wild",false) and game.Life.alive(p): stops.append([p.pos,PLAYER_RADIUS*2])
	for target in range(-1,game.scouts.size()):
		if Actors.valid_target(game,target): stops.append([game.enemy_position(target),PLAYER_RADIUS+Hurt.radius(game,target)])
	var landing:=origin
	for i in 12:
		var point:=origin.lerp(end,(i+1)/12.0)
		var blocked:=false
		for stop in stops:
			var center: Vector3=stop[0]
			if point.distance_to(center)<float(stop[1]) and point.distance_squared_to(center)+.000001<landing.distance_squared_to(center):
				blocked=true
				break
		if blocked: break
		landing=point
	return landing


static func represents(game: Node, id: int) -> bool:
	var p: Dictionary=game.players.get(id,{})
	return p.get("wild",false) and game.Life.alive(p)


static func trace(game: Node, event: RefCounted, id: int, at: Vector3) -> void:
	if not represents(game,id): return
	var elapsed:=Clock.now(game)
	var duration: int=event.potency().trace_ms
	for target in range(-1,game.scouts.size()):
		if not Actors.valid_target(game,target) or (target==-1 and game.boss_kind>=0): continue
		var body: Dictionary=game.leader_brain if target==-1 else game.scouts[target]
		var committed: bool=game.enemy_winding_up if target==-1 else int(body.windup)>0
		var engaged: bool=game.enemy_engaged if target==-1 else bool(body.engaged)
		var pos: Vector3=game.enemy_position(target)
		if committed or not engaged or int(body.get("target",0))!=id or elapsed<int(body.get(RESIST,0)):
			continue
		if at.distance_to(pos)>TRACE_RADIUS or not game.battlefield.clear_line(pos,at): continue
		body[TRACE]={"actor":event.actor,"represented":id,"point":at,"until":elapsed+duration,"epoch":game.combat_epoch}
		body[RESIST]=elapsed+TRACE_RESIST
	game.emit_combat_event("ability","spirit_trace",at,at,duration/1000.0,COLOR,.85,event.actor,{"label":"Fading trace"})
	Journal.event("combat","spirit_trace",{"actor":event.actor,"represented":id,"quality":event.quality,"duration_ms":duration})


static func diversion(game: Node, body: Dictionary, target: int) -> Vector3:
	var trace_state: Dictionary=body.get(TRACE,{})
	if trace_state.is_empty(): return Vector3.INF
	if int(trace_state.until)<=Clock.now(game) or int(trace_state.epoch)!=game.combat_epoch or target!=int(trace_state.represented) or not represents(game,target):
		body.erase(TRACE)
		return Vector3.INF
	return trace_state.point


static func core_step(game: Node, cast: Dictionary, p: Dictionary, now: int) -> void:
	var before: Vector3=p.pos
	p.pos=cast.center
	p.velocity=Vector3.ZERO
	movement(game,p,before,p.pos)
	cast.affinity_action.publish(game,"core_action","step","",now,{"start":before,"center":p.pos})
	game.emit_combat_event("link","spirit_step",before,p.pos,.35,COLOR,0.0,cast.owner)


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, _now: int) -> void:
	match kind:
		"weapon_contact": prepare(game,event)
		"core_action":
			trace(game,event,event.actor,details.start)
			grant(game,event,event.actor)
		"actual_block":
			trace(game,event,details.recipient,details.center)
			for id in game.Life.living_ids(game):
				var pos: Vector3=game.players[id].pos
				if pos.distance_to(details.center)<=WARD_RADIUS and game.battlefield.clear_line(details.center,pos):
					grant(game,event,id)
		"class_contact":
			if event.take_response("spirit_offense"): grant(game,event,event.actor)
		"class_action":
			match details.response:
				"self_stride": grant(game,event,event.actor)
				"recipient_stride":
					for id in details.recipients: grant(game,event,id)
				"departure_trace_and_landing_stride":
					trace(game,event,event.actor,details.start)
					grant(game,event,event.actor)
