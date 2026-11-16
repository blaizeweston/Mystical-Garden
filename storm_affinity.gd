extends RefCounted

const Actors = preload("res://frost_combat.gd")
const Hurt = preload("res://enemy_hurtbox.gd")
const Contact = preload("res://weapon_contact.gd")
const Clock = preload("res://affinity_time.gd")
const Journal = preload("res://diagnostic_journal.gd")
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


static func description(slot: String, quality: String) -> String:
	var q: Dictionary = QUALITY[quality]
	match slot:
		"core": return "Chain Spark · %d HP on weapon contact, up to two more targets within %.1f m per jump. Each jump retains %d%% damage. %.1f s cooldown." % [q.initial,JUMP_RANGE,roundi(FALLOFF*100),CORE_CD/1000.0]
		"form": return "Arcing Strikes · First eligible weapon hit adds %d HP and arcs to one target within %.1f m. %.1f s interval." % [q.arc,JUMP_RANGE,FORM_INTERVAL/1000.0]
	return "Storm Catalyst · Mapped offense starts a %d HP discharge. Actual blocks and landing actions burst for %d HP. Healing grants one %.1f s charge worth %d HP on the next direct hit." % [q.offense,q.burst,CHARGE_MS/1000.0,q.charge]


static func nearest(game: Node, center: Vector3, radius: float, visited: Dictionary, candidates: Array = []) -> int:
	var best := -2
	var distance := INF
	var pool: Array = candidates if not candidates.is_empty() else range(-1,game.scouts.size())
	for target in pool:
		if not Actors.valid_target(game,target) or visited.has(Contact.token(game,target)):
			continue
		var edge := Hurt.contact(game,target,center,true)
		var reach := center.distance_to(edge)
		if reach <= radius and (reach < distance or (is_equal_approx(reach,distance) and target < best)) and game.battlefield.projectile_clear(center,edge):
			best = target
			distance = reach
	return best


static func discharge(game: Node, actor: int, first: int, origin: Vector3, impact: Vector3, hp: int, jumps: int, now: int) -> void:
	var visited := {}
	var target := first
	var center := impact
	for step in jumps+1:
		if target < -1 or target >= game.scouts.size() or game.get_meta(game.Transactions.PENDING,false):
			break
		visited[Contact.token(game,target)] = true
		game.emit_combat_event("link","storm_arc",origin,center,.25,COLOR,0.0,actor)
		if Actors.valid_target(game,target):
			Actors.damage(game,actor,target,maxi(1,roundi(hp*pow(FALLOFF,step))),now,COLOR)
		origin = center
		if step < jumps:
			target = nearest(game,center,JUMP_RANGE,visited)
			if target != -2: center = Hurt.contact(game,target,origin,true)


static func burst(game: Node, event: RefCounted, center: Vector3, now: int) -> void:
	game.emit_combat_event("ability","storm_burst",center,center,.42,COLOR,BURST_RADIUS,event.actor,{"label":"Storm burst"})
	for target in game.skill_area_targets(center,BURST_RADIUS,center):
		if game.get_meta(game.Transactions.PENDING,false): break
		Actors.damage(game,event.actor,target,event.potency().burst,now,COLOR)


static func grant(game: Node, event: RefCounted, id: int) -> void:
	var p: Dictionary = game.players.get(id,{})
	if not game.Life.alive(p): return
	var elapsed := Clock.now(game)
	var previous: Dictionary = p.get(CHARGE,{})
	var damage: int = event.potency().charge
	if int(previous.get("until",0))>elapsed and int(previous.hp)>damage: return
	p[CHARGE] = {"actor":event.actor,"quality":event.quality,"hp":damage,"until":elapsed+CHARGE_MS,"epoch":game.combat_epoch}
	Journal.event("combat","storm_charge_granted",{"actor":event.actor,"recipient":id,"quality":event.quality,"hp":damage})


static func use_charge(game: Node, event: RefCounted, target: int, point: Vector3, now: int) -> void:
	var p: Dictionary = game.players.get(event.actor,{})
	var charge: Dictionary = p.get(CHARGE,{})
	if charge.is_empty(): return
	if int(charge.until)<=Clock.now(game) or int(charge.epoch)!=game.combat_epoch:
		p.erase(CHARGE)
		return
	if not event.take_response("storm_charge"): return
	p.erase(CHARGE)
	game.emit_combat_event("link","storm_charge",p.pos,point,.32,COLOR,0.0,charge.actor)
	Journal.event("combat","storm_charge_consumed",{"actor":charge.actor,"recipient":event.actor,"quality":charge.quality,"hp":charge.hp})
	Actors.damage(game,charge.actor,target,charge.hp,now,COLOR)


static func clear(p: Dictionary) -> void:
	p.erase(CHARGE)
	p.erase(FORM_READY)


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	var q: Dictionary = event.potency()
	match kind:
		"core_action":
			discharge(game,event.actor,details.enemy,details.origin,details.point,q.initial,2,now)
		"weapon_contact":
			var p: Dictionary = game.players.get(event.actor,{})
			var elapsed := Clock.now(game)
			if not game.Life.alive(p) or elapsed<int(p.get(FORM_READY,0)) or not event.take_response("storm_form"): return
			p[FORM_READY]=elapsed+FORM_INTERVAL-int(q.get("interval_reduction_ms",0))
			var point: Vector3=details.get("point",game.enemy_position(details.enemy))
			discharge(game,event.actor,details.enemy,p.pos,point,q.arc,1,now)
		"actual_block":
			burst(game,event,details.center,now)
		"class_contact":
			if not event.take_response("storm_offense"): return
			var point: Vector3=details.get("point",game.enemy_position(details.enemy))
			discharge(game,event.actor,details.enemy,point,point,q.offense,1,now)
		"class_action":
			match details.response:
				"discharge":
					var center: Vector3=details.center
					var authored: Array=details.enemies
					if authored.is_empty() and details.get("target_scope")!="designated_area": return
					var reach := INF if not authored.is_empty() else maxf(.85,float(details.radius))
					var target:=nearest(game,center,reach,{},authored)
					if target!=-2:
						discharge(game,event.actor,target,center,Hurt.contact(game,target,center,true),q.offense,1,now)
				"recipient_charge":
					for id in details.recipients: grant(game,event,id)
				"landing_discharge":
					burst(game,event,details.center,now)


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
