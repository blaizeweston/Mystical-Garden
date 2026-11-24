extends RefCounted
const OutgoingHits = preload("res://outgoing_hits.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Hurt = preload("res://enemy_hurtbox.gd")
const Contact = preload("res://weapon_contact.gd")
const Clock = preload("res://affinity_time.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Sources=preload("res://affinity_status_source.gd")
const Catalog=preload("res://affinity_card_catalog.gd")
const TEMPO := "storm_card_tempo"
const PREP := "storm_card_discharge"
const CARD_FIELDS := [TEMPO, PREP]
const CARD_GRANTS := {"conductor_unlock":{"method":"discharge","capability":{"producer":"card","id":"conductor","slot":"core","recipient":"enemy"}}}
const COLOR := Color("#e3d184")
const JUMP_RANGE := 3.0
const FALLOFF := .7
const BURST_RADIUS := 2.45
const CORE_CD := 6200
const FORM_INTERVAL := 1700
const CHARGE_MS := 4800
const CHARGE := "affinity_storm_charge"
const FORM_READY := "affinity_storm_form_ready"
const QUALITY := {
	"ordinary":{"initial":22,"arc":9,"offense":13,"burst":12,"charge":10},
	"refined":{"initial":30,"arc":13,"offense":18,"burst":17,"charge":14},
}
const VERSION_DATA := [JUMP_RANGE, FALLOFF, BURST_RADIUS, CORE_CD, FORM_INTERVAL, CHARGE_MS, QUALITY]


static func description(slot: String, quality: String, resolved: Dictionary = {}) -> String:
	var q: Dictionary = QUALITY[quality] if resolved.is_empty() else resolved
	match slot:
		"core": return "Chain Spark · %d damage on weapon contact, up to %d more targets within %.2f m per jump. Each jump retains %d%% damage. %.1f s cooldown." % [q.initial,2+int(q.get("extra_jumps",0)),JUMP_RANGE+int(q.get("jump_range_cm",0))/100.0,roundi(FALLOFF*100),CORE_CD/1000.0]
		"form": return "Arcing Strikes · First eligible weapon hit adds %d HP and arcs to one target within %.1f m. %.1f s interval." % [q.arc,JUMP_RANGE+int(q.get("jump_range_cm",0))/100.0,(FORM_INTERVAL-int(q.get("interval_reduction_ms",0)))/1000.0]
	return "Storm Catalyst · Mapped offense starts a %d HP discharge. Actual blocks and landing actions burst for %d HP. Healing grants one %.1f s charge worth %d HP on the next direct hit." % [q.offense+int(q.get("catalyst_damage_hp",0)),q.burst+int(q.get("catalyst_damage_hp",0)),CHARGE_MS/1000.0,q.charge+int(q.get("catalyst_damage_hp",0))]


static func nearest(game: Node, center: Vector3, radius: float, visited: Dictionary, candidates: Array = []) -> int:
	var best := -2
	var distance := INF
	var pool: Array = candidates if not candidates.is_empty() else range(-1,game.encounter.scout_count())
	for target in pool:
		if not game.encounter.alive(target) or visited.has(Contact.token(game,target)):
			continue
		var edge := Hurt.contact(game,target,center,true)
		var reach := center.distance_to(edge)
		if reach <= radius and (reach < distance or (is_equal_approx(reach,distance) and target < best)) and game.battlefield.projectile_clear(center,edge):
			best = target
			distance = reach
	return best


static func discharge(game: Node, actor: int, first: int, origin: Vector3, impact: Vector3, hp: int, jumps: int, now: int, potency: Dictionary = {}, source: Dictionary = {}) -> void:
	if first< -1 or first>=game.encounter.scout_count():return
	var visited:={}
	var route:=[]
	var target:=first
	var previous:=origin
	var center:=impact
	var reach:=JUMP_RANGE+int(potency.get("jump_range_cm",0))/100.0
	for step in jumps+1:
		if target== -2:break
		visited[Contact.token(game,target)]=true
		route.append({"target":target,"token":game.encounter.spawn_identity(target),"origin":previous,"point":center,"step":step,"secondary":false})
		previous=center
		target=nearest(game,center,reach,visited)
		if target!= -2:center=Hurt.contact(game,target,previous,true)
	if not route.any(func(row):return game.encounter.alive(row.target,row.token)):return
	var owner: Dictionary=game.players.get(actor,{})
	var prep: Dictionary=owner.get(PREP,{})
	if not source.get("replica",false) and int(prep.get("until",0))>now and Sources.current(game,prep.source):
		hp+=int(prep.hp);owner.erase(PREP)
	var grounded:=0.0
	for step in range(route.size(),jumps+1):grounded+=hp*pow(FALLOFF,step)*int(potency.get("unused_percent",0))/100.0
	for row in route:row.hp=maxi(1,roundi(hp*pow(FALLOFF,int(row.step))))
	route[0].hp+=roundi(grounded)
	var main:=route.duplicate()
	if int(potency.get("conductor_unlock",0))>0:
		var tuning: Dictionary=Catalog.DEFINITIONS.conductor.tuning
		for node: Dictionary in main:
			for index in int(tuning.forks_per_node):
				var fork:=nearest(game,node.point,reach,visited)
				if fork== -2:break
				visited[Contact.token(game,fork)]=true
				route.append({"target":fork,"token":game.encounter.spawn_identity(fork),"origin":node.point,"point":game.enemy_position(fork),"hp":maxi(1,roundi(int(node.hp)*float(tuning.fork_percent)/100.0)),"secondary":true})
		var return_from: Vector3=main.back().point
		var return_to:=Hurt.contact(game,first,return_from,true)
		if return_from.distance_to(return_to)<=reach and game.battlefield.projectile_clear(return_from,return_to):
			route.append({"target":first,"token":main[0].token,"origin":return_from,"point":return_to,"hp":maxi(1,roundi(hp*float(tuning.return_percent)/100.0)),"secondary":true})
	var damaged:=false
	for row: Dictionary in route:
		if game.persistence_session.is_blocked() or (not source.is_empty() and not Sources.current(game,source)):break
		game.emit_combat_event("link","storm_arc",row.origin,row.point,.25,COLOR,0.0,actor)
		if not game.encounter.alive(row.target,row.token):continue
		var before: int=game.encounter.hp(row.target)
		OutgoingHits.affinity_and_clear(game,actor,row.target,int(row.hp),now,COLOR,bool(row.secondary))
		damaged=damaged or game.encounter.hp(row.target)<before
	if damaged and int(potency.get("tempo_percent",0))>0 and not source.is_empty() and Sources.current(game,source):
		owner[TEMPO]={"source":source,"until":now+int(Catalog.DEFINITIONS.ionized_rhythm.tuning.duration_ms),"percent":int(potency.tempo_percent)}

static func tempo_percent(game: Node, player: Dictionary, now: int) -> int:
	var row: Dictionary=player.get(TEMPO,{})
	return int(row.percent) if int(row.get("until",0))>now and Sources.current(game,row.source) else 0

static func prepare_discharge(game: Node,event: RefCounted,now: int) -> void:
	var amount:=int(event.potency().get("prepared_discharge_hp",0))
	if amount<=0 or not event.take_response("storm_spellcharge") or not Sources.current(game,Sources.capture(event)):return
	game.players[event.actor][PREP]={"source":Sources.capture(event),"until":now+int(Catalog.DEFINITIONS.spellcharge.tuning.duration_ms),"hp":amount}


static func burst(game: Node, event: RefCounted, center: Vector3, now: int) -> void:
	game.emit_combat_event("ability","storm_burst",center,center,.42,COLOR,BURST_RADIUS,event.actor,{"label":"Storm burst"})
	for target in game.skill_area_targets(center,BURST_RADIUS,center):
		if game.persistence_session.is_blocked(): break
		OutgoingHits.affinity_and_clear(game,event.actor,target,event.potency().burst+int(event.potency().get("catalyst_damage_hp",0)),now,COLOR)


static func grant(game: Node, event: RefCounted, id: int) -> void:
	var p: Dictionary = game.players.get(id,{})
	if not game.Life.alive(p): return
	var elapsed := Clock.now(game)
	var previous: Dictionary = p.get(CHARGE,{})
	var damage: int = event.potency().charge + int(event.potency().get("catalyst_damage_hp",0))
	if int(previous.get("until",0))>elapsed and int(previous.hp)>damage \
			and PlayerLifecycle.matches(game.players.get(previous.actor,{}),int(previous.source_life)): return
	p[CHARGE] = {"actor":event.actor,"source_life":event.life_generation,"quality":event.quality,"hp":damage,"potency":event.potency(),"origin_source":Sources.capture(event),"until":elapsed+CHARGE_MS,"epoch":game.participation.epoch()}
	Journal.event("combat","storm_charge_granted",{"actor":event.actor,"recipient":id,"quality":event.quality,"hp":damage})


static func use_charge(game: Node, event: RefCounted, target: int, point: Vector3, now: int) -> void:
	var p: Dictionary = game.players.get(event.actor,{})
	var charge: Dictionary = p.get(CHARGE,{})
	if charge.is_empty(): return
	if int(charge.until)<=Clock.now(game) or int(charge.epoch)!=game.participation.epoch() \
			or not PlayerLifecycle.matches(game.players.get(charge.actor,{}),int(charge.source_life)):
		p.erase(CHARGE)
		return
	if not event.take_response("storm_charge"): return
	p.erase(CHARGE)
	game.emit_combat_event("link","storm_charge",p.pos,point,.32,COLOR,0.0,charge.actor)
	Journal.event("combat","storm_charge_consumed",{"actor":charge.actor,"recipient":event.actor,"quality":charge.quality,"hp":charge.hp})
	discharge(game,charge.actor,target,p.pos,point,charge.hp,int(charge.get("potency",{}).get("extra_jumps",0)),now,charge.get("potency",{}),charge.get("origin_source",{}))


static func clear(p: Dictionary) -> void:
	p.erase(CHARGE)
	p.erase(FORM_READY)
	p.erase(TEMPO)
	p.erase(PREP)


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	var q: Dictionary = event.potency()
	match kind:
		"core_action":
			discharge(game,event.actor,details.enemy,details.origin,details.point,q.initial,2+int(q.get("extra_jumps",0)),now,q,Sources.capture(event))
		"weapon_contact":
			var p: Dictionary = game.players.get(event.actor,{})
			var elapsed := Clock.now(game)
			if not game.Life.alive(p) or elapsed<int(p.get(FORM_READY,0)) or not event.take_response("storm_form"): return
			p[FORM_READY]=elapsed+FORM_INTERVAL-int(q.get("interval_reduction_ms",0))
			var point: Vector3=details.get("point",game.enemy_position(details.enemy))
			discharge(game,event.actor,details.enemy,p.pos,point,q.arc,1,now,q,Sources.capture(event))
		"actual_block":
			burst(game,event,details.center,now)
			prepare_discharge(game,event,now)
		"class_contact":
			if not event.take_response("storm_offense"): return
			var point: Vector3=details.get("point",game.enemy_position(details.enemy))
			discharge(game,event.actor,details.enemy,point,point,q.offense+int(q.get("catalyst_damage_hp",0)),1+int(q.get("extra_jumps",0)),now,q,Sources.capture(event))
			prepare_discharge(game,event,now)
		"class_action":
			match details.response:
				"discharge":
					var center: Vector3=details.center
					var authored: Array=details.enemies
					if authored.is_empty() and details.get("target_scope")!="designated_area": return
					var reach := INF if not authored.is_empty() else maxf(.85,float(details.radius))
					var target:=nearest(game,center,reach,{},authored)
					if target!=-2:
						discharge(game,event.actor,target,center,Hurt.contact(game,target,center,true),q.offense+int(q.get("catalyst_damage_hp",0)),1+int(q.get("extra_jumps",0)),now,q,Sources.capture(event))
				"recipient_charge":
					if details.recipients.is_empty(): return
					for id in details.recipients: grant(game,event,id)
				"landing_discharge":
					burst(game,event,details.center,now)
			prepare_discharge(game,event,now)


static func core_contact(game: Node, cast: Dictionary, target: int, origin: Vector3, point: Vector3, now: int) -> void:
	cast.affinity_action.publish(game,"core_action","spark",Contact.token(game,target),now,{"enemy":target,"origin":origin,"point":point})


static func ground_contact(game: Node, cast: Dictionary, player: Dictionary, now: int) -> void:
	var origin: Vector3 = player.pos
	var stats: Dictionary = game.weapon_stats(player)
	stats.reach = cast.skill.range
	for target in Contact.candidates(game,origin):
		if Contact.accepts(game,target,origin,origin+Vector3(cast.forward)*float(stats.reach),cast.skill.weapon_form,stats):
			core_contact(game,cast,target,origin,Hurt.contact(game,target,origin,true),now)
			return
