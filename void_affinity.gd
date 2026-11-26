extends RefCounted
const Frost = preload("res://frost_combat.gd")
const Effects = preload("res://enemy_affinity_effects.gd")
const OutgoingHits = preload("res://outgoing_hits.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Clock=preload("res://affinity_time.gd")
const Hurt=preload("res://enemy_hurtbox.gd")
const Contact=preload("res://weapon_contact.gd")
const Sources=preload("res://affinity_status_source.gd")
const Catalog=preload("res://affinity_card_catalog.gd")
const CLASS_PULL_CAPABILITY := "unopposed_compression"
const PREP := "void_card_compression"
const CARD_FIELDS := [PREP]
const CONTROL := "affinity_void_control"
const SUSTAINED := "affinity_void_sustained"
const SHEAR := "affinity_void_shear"
const CARD_GRANTS := {"shear_hp":{"method":"admit_core","capability":{"producer":"card","id":"rift_shear","slot":"core","recipient":"enemy"}}}
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


static func description(slot: String, quality: String, resolved: Dictionary = {}) -> String:
	var q: Dictionary=QUALITY[quality] if resolved.is_empty() else resolved
	match slot:
		"core": return "Gravity Well Â· Gather for %.1f s, then deal %d HP once to enemies still within %.1f m. %.1f s cooldown." % [GATHER_MS/1000.0,q.collapse,field_radius(q),CORE_CD/1000.0]
		"form": return "Drawing Strikes Â· First eligible direct hit adds %d HP and draws up to %.2f m toward you. %.2f s interval. Native displacement takes priority." % [q.form_hp,q.form_force,maxi(1,FORM_INTERVAL-int(q.get("interval_reduction_ms",0)))/1000.0]
	return "Void Catalyst Â· Mapped offense draws inward. An actual block, heal or pure movement repels for %d HP within %.2f m. Resistance and clearance can stop motion while damage still applies." % [q.pulse+int(q.get("catalyst_damage_hp",0)),area_radius(q)]


static func resisted(game: Node, target: int, now: int) -> bool:
	if target==-1:
		return game.tactics.boss_kind>=0 or game.tactics.winding_up or now<int(game.tactics.rooted_until) or Frost.rooted(game.tactics.memory,now)
	var scout: Dictionary=game.encounter.scout(target)
	return int(scout.windup)>0 or now<int(scout.rooted_until) or Frost.rooted(scout,now)


static func queue_motion(game: Node, event: RefCounted, target: int, center: Vector3, inward: bool, strength: float, cast := {}) -> void:
	if strength<=0.0 or not game.encounter.alive(target): return
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
	intents.append({"token":token,"spawn":game.encounter.spawn_identity(target),"binding":event.connection_binding,"epoch":event.epoch,"scope":SCOPES[event.source],"actor":event.actor,"source_life":event.life_generation,
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
		if other!=target and game.encounter.alive(other):
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
	if game.persistence_session.is_blocked():return
	tick_fields(game,elapsed,now)
	if not game.has_meta(PENDING):return
	# This is the displacement queue, distinct from pending save transactions.
	var pending: Dictionary=game.get_meta(PENDING)
	game.remove_meta(PENDING)
	var targets:=pending.keys()
	targets.sort()
	for target in targets:
		if not game.encounter.alive(target) or resisted(game,target,now): continue
		var token:=Contact.token(game,target)
		var options: Array = pending[target].filter(func(row):
			return row.token==token and game.encounter.alive(target,int(row.spawn)) and game.network_session.matches(int(row.actor),int(row.binding)) and int(row.epoch)==game.participation.epoch() \
				and PlayerLifecycle.matches(game.players.get(row.actor,{}),int(row.source_life)))
		if options.is_empty(): continue
		options.sort_custom(precedes)
		var intent: Dictionary=options[0]
		var body:=Effects.edit(game,target)
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
		else: game.encounter.scout(target).pos=end
		moves.append({"at":elapsed,"amount":distance,"direction":intent.direction})
		body[ALLOWANCE_STATE]=moves
		body[CONTROL]={"epoch":intent.epoch,"token":game.encounter.spawn_identity(target),"until":elapsed+DURATION}
		var cast: Dictionary=intent.cast
		if not cast.is_empty():
			cast.moved[token]=float(cast.moved.get(token,0.0))+distance
			if cast.get("kind")=="void_field":game.effect_timeline.update_native(cast)


static func pulse(game: Node, event: RefCounted, center: Vector3, inward: bool, now: int, targets: Array, preserve_native := false) -> bool:
	var q: Dictionary=event.potency()
	game.emit_combat_event("ability","void_pulse",center,center,.46,COLOR,area_radius(q),event.actor,{"label":"Compression" if inward else "Void repulsion","form":"compression" if inward else "repulsion"})
	var accepted:=false
	for target in targets:
		if game.persistence_session.is_blocked():break
		if not game.encounter.alive(target) or not game.battlefield.clear_line(center,game.enemy_position(target)):continue
		accepted=true
		if not preserve_native:queue_motion(game,event,target,center,inward,q.pulse_force+(int(q.get("class_pull_cm",0))/100.0 if inward else 0.0))
		var hp:=int(q.pulse)+int(q.get("catalyst_damage_hp",0))+claim_compression(game,event,now)+sustained_bonus(game,target,q)
		OutgoingHits.affinity_and_clear(game,event.actor,target,hp,now,COLOR)
	return accepted


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
		for target in game.skill_area_targets(center,field_radius(q),center):
			var remaining: float=float(q.gather_total)*(1.0+int(q.get("gather_strength_percent",0))/100.0)-float(cast.moved.get(Contact.token(game,target),0.0))
			queue_motion(game,source,target,center,true,minf(float(q.gather_step)*(1.0+int(q.get("gather_strength_percent",0))/100.0),remaining),cast)
	return false


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	var q: Dictionary=event.potency()
	match kind:
		"core_action":
			var center: Vector3=details.center
			game.emit_combat_event("ability","void_collapse",center,center,.55,COLOR,float(details.get("radius",field_radius(q))),event.actor,{"label":"Gravity Well collapse","form":"singularity" if details.get("secondary",false) else "collapse"})
			for target in game.skill_area_targets(center,float(details.get("radius",field_radius(q))),center):
				if game.persistence_session.is_blocked(): break
				OutgoingHits.affinity_and_clear(game,event.actor,target,int(details.get("damage_hp",q.collapse))+claim_compression(game,event,now)+sustained_bonus(game,target,q),now,COLOR,bool(details.get("secondary",false)))
		"weapon_contact":
			var p: Dictionary=game.players.get(event.actor,{})
			var elapsed:=Clock.now(game)
			if not game.Life.alive(p) or elapsed<int(p.get(FORM_READY,0)) or not event.take_response("void_form"): return
			p[FORM_READY]=elapsed+maxi(1,FORM_INTERVAL-int(q.get("interval_reduction_ms",0)))
			if not details.get("native_displacement",false):
				queue_motion(game,event,details.enemy,p.pos,true,q.form_force)
			var point:Vector3=details.get("point",game.enemy_position(details.enemy))
			game.emit_combat_event("ability","void_grip",point,point,.25,COLOR,.40,event.actor,{"label":""})
			OutgoingHits.affinity_and_clear(game,event.actor,details.enemy,q.form_hp+claim_compression(game,event,now)+sustained_bonus(game,details.enemy,q),now,COLOR)
		"actual_block":
			if pulse(game,event,details.center,false,now,game.skill_area_targets(details.center,area_radius(q),details.center)):prepare_compression(game,event,now)
		"class_contact":
			if not event.take_response("void_offense"): return
			var center: Vector3=details.get("point",game.enemy_position(details.enemy))
			if pulse(game,event,center,true,now,[details.enemy],details.get("native_displacement",false)):prepare_compression(game,event,now)
		"class_action":
			var center: Vector3=details.center
			match details.response:
				"compression":
					var targets: Array=details.enemies
					if targets.is_empty() and details.get("target_scope")=="designated_area":
						targets=game.skill_area_targets(center,float(details.radius),center)
					if pulse(game,event,center,true,now,targets,details.get("native_displacement",false)):prepare_compression(game,event,now)
				"healing_repulsion","landing_repulsion":
					if pulse(game,event,center,false,now,game.skill_area_targets(center,area_radius(q),center)):prepare_compression(game,event,now)


static func field_radius(q: Dictionary) -> float:
	return CORE_RADIUS+(int(q.get("well_radius_cm",0))+int(q.get("control_radius_cm",0)))/100.0
static func area_radius(q: Dictionary) -> float:
	return AREA_RADIUS+int(q.get("control_radius_cm",0))/100.0

static func prepare_compression(game: Node,event: RefCounted,now: int) -> void:
	var hp:=int(event.potency().get("prepared_compression_hp",0))
	if hp<=0 or not event.take_response("dark_echo_grant"):return
	game.players[event.actor][PREP]={"source":Sources.capture(event),"until":now+int(Catalog.DEFINITIONS.dark_echo.tuning.duration_ms),"hp":hp}

static func claim_compression(game: Node,event: RefCounted,now: int) -> int:
	if event.replica:return 0
	var player: Dictionary=game.players.get(event.actor,{})
	var prep: Dictionary=player.get(PREP,{})
	if int(prep.get("until",0))<=now or not Sources.current(game,prep.source) or not event.take_response("dark_echo_spend"):return 0
	player.erase(PREP)
	return int(prep.hp)

static func controlled(game: Node,target: int) -> bool:
	var elapsed:=Clock.now(game)
	if field_views(game,elapsed).any(func(row):return covers(game,row,target)):return true
	var record: Dictionary=Effects.read(game,target).get(CONTROL,{})
	return Sources.target_current(game,target,record) and int(record.get("until",0))>elapsed

static func ordinary_bonus(game: Node,event: RefCounted,target: int) -> int:
	var q: Dictionary=event.potency()
	if int(q.get("controlled_hit_hp",0))<=0 or not controlled(game,target) or not event.take_response("condensed_edge"):return 0
	return int(q.controlled_hit_hp)

static func sustained_bonus(game: Node,target: int,q: Dictionary) -> int:
	var record: Dictionary=Effects.read(game,target).get(SUSTAINED,{})
	if not Sources.target_current(game,target,record) or Clock.now(game)-int(record.get("since",Clock.now(game)))<int(Catalog.DEFINITIONS.crushing_pressure.tuning.duration_ms):return 0
	if not field_views(game,Clock.now(game)).any(func(row):return covers(game,row,target)):return 0
	return int(q.get("sustained_hp",0))

## Existing native timeline owns concurrent fields. This admission replaces only
## an acquired Rift Shear Core cast; ordinary Gravity Well keeps its native path.
static func admit_core(game: Node,cast: Dictionary,now: int) -> bool:
	var event: RefCounted=cast.affinity_action
	var q: Dictionary=event.potency()
	return not create_field(game,event,cast.center,int(cast.armed),int(Catalog.DEFINITIONS.rift_shear.tuning.field_ms),GATHER_MS,field_radius(q),q.collapse,q.gather_step*(1.0+int(q.get("gather_strength_percent",0))/100.0),q.gather_total*(1.0+int(q.get("gather_strength_percent",0))/100.0),false,str(cast.id),now).is_empty()

static func create_field(game: Node,event: RefCounted,center: Vector3,start: int,lifetime: int,collapse_ms: int,radius: float,hp: int,step: float,total: float,secondary: bool,cast_id: String,now: int) -> Dictionary:
	var row: Dictionary=game.effect_timeline.schedule_native({"kind":"void_field","owner":event.actor,"life":event.life_generation,"binding":event.connection_binding,"epoch":event.epoch,
		"event":event,"position":center,"radius":radius,"start":start,"until":start+lifetime+1,"collapse_at":start+collapse_ms,"next":start,"collapsed":false,
		"damage_hp":hp,"step":step,"total":total,"moved":{},"window":start,"secondary":secondary,"cast_id":cast_id})
	if row.is_empty():
		game.tell(event.actor,"Too many active combat effects. Wait for an effect to finish.")
		return {}
	game.emit_combat_event("field","gravity_well",center,center,maxf(.05,(start+lifetime-now)/1000.0),COLOR,radius,event.actor,{"label":"Singularity" if secondary else "Lingering Gravity Well"})
	row.visual_id=game.combat_event_serial
	game.effect_timeline.update_native(row)
	Journal.event("combat","void_field_admitted",{"actor":event.actor,"activation":event.identity,"secondary":secondary,"radius_m":radius,"lifetime_ms":lifetime})
	return row

static func advance_field(game: Node,field: Dictionary,now: int) -> void:
	if now<int(field.start):return
	var event: RefCounted=field.event
	if not field.collapsed and now>=int(field.collapse_at):
		field.collapsed=true # Claim before damage/death callbacks.
		event.publish(game,"core_action","collapse","",now,{"center":field.position,"radius":field.radius,"damage_hp":field.damage_hp,"secondary":field.secondary})
	if now>=int(field.until):return
	if now-int(field.window)>=DURATION:field.window=now;field.moved={}
	field.next=now+PULSE_MS
	for target in game.skill_area_targets(field.position,float(field.radius),field.position):
		var remaining: float=float(field.total)-float(field.moved.get(Contact.token(game,target),0.0))
		queue_motion(game,event,target,field.position,true,minf(float(field.step),remaining),field)

## Detached query records only; no second field collection or authority.
static func field_views(game: Node,elapsed: int) -> Array:
	var result:=[]
	var now: int=load("res://combat_clock.gd").now()
	for field: Dictionary in game.effect_timeline.native_records():
		if field.kind!="void_field" or now<int(field.start) or now>=int(field.until):continue
		var event: RefCounted=field.event
		if not Sources.current(game,Sources.capture(event)) or not game.Life.alive(game.players.get(event.actor,{})):continue
		result.append({"center":field.position,"radius":field.radius,"source":Sources.capture(event),"potency":event.potency(),"id":field.cast_id})
	for cast: Dictionary in game.effect_timeline.core_records().values():
		if cast.skill.get("affinity_family")!="void" or not cast.grown or elapsed>=int(cast.get("well_until",0)):continue
		var event: RefCounted=cast.affinity_action
		if Sources.current(game,Sources.capture(event)):result.append({"center":cast.center,"radius":field_radius(event.potency()),"source":Sources.capture(event),"potency":event.potency(),"id":cast.id})
	return result

static func covers(game: Node,field: Dictionary,target: int) -> bool:
	return game.encounter.alive(target) and Vector3(field.center).distance_to(game.enemy_position(target))<=float(field.radius) and game.battlefield.clear_line(field.center,game.enemy_position(target))

static func tick_fields(game: Node,elapsed: int,now: int) -> void:
	var fields:=field_views(game,elapsed)
	for target in range(-1,game.encounter.scout_count()):
		if not game.encounter.alive(target):continue
		var touching: Array=fields.filter(func(field):return covers(game,field,target))
		if touching.is_empty():
			Effects.read(game,target).erase(SUSTAINED)
			continue
		var body:=Effects.edit(game,target)
		var control: Dictionary=body.get(SUSTAINED,{})
		if not Sources.target_current(game,target,control):body[SUSTAINED]={"epoch":game.participation.epoch(),"token":game.encounter.spawn_identity(target),"since":elapsed}
		if touching.size()<2:continue
		var owners: Array=touching.filter(func(field):return int(field.potency.get("shear_hp",0))>0)
		if owners.is_empty():continue
		owners.sort_custom(func(a,b):return int(a.potency.shear_hp)>int(b.potency.shear_hp) or (int(a.potency.shear_hp)==int(b.potency.shear_hp) and int(a.source.actor)<int(b.source.actor)))
		var last: Dictionary=body.get(SHEAR,{})
		if Sources.target_current(game,target,last) and now<int(last.until):continue
		var chosen: Dictionary=owners[0]
		body[SHEAR]={"epoch":game.participation.epoch(),"token":game.encounter.spawn_identity(target),"until":now+int(Catalog.DEFINITIONS.rift_shear.tuning.interval_ms)}
		var point:Vector3=game.enemy_position(target)
		OutgoingHits.affinity_and_clear(game,int(chosen.source.actor),target,int(chosen.potency.shear_hp),now,COLOR,true)
		game.emit_combat_event("ability","rift_shear",point,point,.25,COLOR,.7,int(chosen.source.actor),{"label":"Rift Shear"})

static func hints(game: Node) -> Array:
	var result:=[]
	var now: int=load("res://combat_clock.gd").now()
	for field: Dictionary in game.effect_timeline.native_records():
		if field.kind!="void_field" or now<int(field.start) or now>=int(field.until):continue
		var point: Vector3=field.position
		var at:=[point.x,0,point.z]
		result.append({"id":field.cast_id,"role":"core_field","from":at,"to":at,"radius":field.radius,"remaining":(int(field.until)-now)/1000.0,"color":"#ad8bcb","skill":"gravity_well","form":"singularity" if field.secondary else "lingering","core_phase":maxi(0,now-int(field.start)),"decoy":false})
	return result

static func singularity(game: Node,peer: int,center: Vector3,now: int) -> bool:
	var player: Dictionary=game.players.get(peer,{})
	var build: Dictionary=game.combat_build(player).affinity_build()
	for slot: String in ["core","form","catalyst"]:
		var part: Dictionary=build.get(slot,{})
		if part.get("state")!="ready" or part.get("primary_affinity")!="void":continue
		var event: RefCounted=load("res://combat_action_events.gd").begin(game,peer,slot,part,part.potency_profile.values,["core_action"],0x7fffffffffffffff)
		var q: Dictionary=event.potency()
		var tuning: Dictionary=Catalog.DEFINITIONS.singularity.tuning
		return not create_field(game,event,center,now,int(tuning.duration_ms),int(tuning.duration_ms),float(tuning.radius_m)+int(q.get("control_radius_cm",0))/100.0,int(tuning.damage_hp),float(tuning.gather_step_m),float(tuning.gather_total_m),true,"singularity/"+str(event.identity),now).is_empty()
	return false


static func class_pull_supported(adapter: Dictionary) -> bool:
	var native: Dictionary=adapter.get("native_displacement",{})
	return adapter.get("response")=="compression" and float(native.get("push",0))==0.0 and float(native.get("pull",0))==0.0
