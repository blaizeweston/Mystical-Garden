extends RefCounted

const Sources = preload("res://affinity_status_source.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Actors = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Contact = preload("res://weapon_contact.gd")
const RETALIATION := "wood_card_retaliation"
const Catalog=preload("res://affinity_card_catalog.gd")
const GRANTS := "affinity_bark_grants"
const BURST_READY := "affinity_bark_burst_ready"
const FORM_READY := "affinity_wood_form_ready"
const GRANT_ORDER := &"affinity_bark_order"
const COLOR := Color("#e1b778")
const ABSORPTION := .40
const CORE_RADIUS := 2.65
const WARD_RADIUS := 2.4
const CORE_MS := 6000
const CATALYST_MS := 4200
const COOLDOWN_MS := 8000
const BURST_INTERVAL_MS := 1350
const FORM_INTERVAL_MS := 1900
const FAN_RADIUS := 2.35
const FAN_MIN_DOT := .72
const FRAGMENT_LIMIT := 2
const QUALITY := {
	"ordinary":{"core_capacity":30,"catalyst_capacity":12,"break_hp":10,"ward_hp":8,"impact_hp":8,"fragment_hp":5},
	"refined":{"core_capacity":40,"catalyst_capacity":18,"break_hp":16,"ward_hp":12,"impact_hp":12,"fragment_hp":8},
}
const VERSION_DATA := [ABSORPTION, CORE_RADIUS, WARD_RADIUS, CORE_MS, CATALYST_MS,
	COOLDOWN_MS, BURST_INTERVAL_MS, FORM_INTERVAL_MS, FAN_RADIUS, FAN_MIN_DOT, FRAGMENT_LIMIT, QUALITY]


static func description(slot: String, quality: String, resolved: Dictionary = {}) -> String:
	var q: Dictionary=QUALITY[quality] if resolved.is_empty() else resolved
	if slot=="form":
		return "Splintering Strikes · First direct hit deals %d extra HP. Up to %d targets in the clear forward fan take %d HP. %.1f s interval. No armor from hits." % [
			q.impact_hp,FRAGMENT_LIMIT,q.fragment_hp,FORM_INTERVAL_MS/1000.0]
	var line: String={
		"core":"Ironbark · Grants %d Bark to you and living allies within %.2f m for %.1f s. %.1f s cooldown." % [q.core_capacity,CORE_RADIUS,(CORE_MS+int(q.get("duration_bonus_ms",0)))/1000.0,COOLDOWN_MS/1000.0],
		"catalyst":"Wood Catalyst · Mapped offense, healing and movement can grant %d Bark for %.1f s. Actual blocks grant Bark and can burst for %d HP within %.1f m." % [q.catalyst_capacity,(CATALYST_MS+int(q.get("duration_bonus_ms",0)))/1000.0,q.ward_hp,WARD_RADIUS],
	}[slot]
	return line + "\nBark absorbs up to %d%% of an unblocked hostile hit using the remaining capacity of independently expiring grants. Compatible grants add their full capacity; no shared pool ceiling. Full depletion can burst (this source contributes %d HP). Defensive and break bursts share a %.2f s recipient interval." % [
		roundi(ABSORPTION*100),q.break_hp,BURST_INTERVAL_MS/1000.0]


static func live_grants(player: Dictionary, elapsed: int) -> Array:
	return player.get(GRANTS,[]).filter(func(grant):return int(grant.until)>elapsed and int(grant.remaining)>0)


static func capacity(grants: Array) -> int:
	var total:=0
	for grant in grants: total+=int(grant.remaining)
	return total


static func grant(game: Node, event: RefCounted, id: int, response: String) -> int:
	var player: Dictionary=game.players.get(id,{})
	if not game.multiplayer.is_server() or not Sources.current(game,Sources.capture(event)) or not game.Life.alive(player) or not event.take_response("wood/%s/%d" % [response,id]):
		return 0
	var elapsed:=Clock.now(game)
	var grants:=live_grants(player,elapsed)
	var q: Dictionary=event.potency()
	var is_core: bool=event.source=="core"
	var offered: int=q.core_capacity if is_core else q.catalyst_capacity
	var admitted:=offered
	if not Sources.sum_fits(capacity(grants),admitted):
		Journal.event("combat","affinity_application_rejected",{"family":"wood","actor":event.actor,"reason":"integer_representation"})
		return 0
	if admitted<=0:
		return 0
	var order:=int(game.get_meta(GRANT_ORDER,0))+1
	game.set_meta(GRANT_ORDER,order)
	grants.append({"actor":event.actor,"source_life":event.life_generation,"slot":event.source,"item":event.material_id,"quality":event.quality,
		"activation":event.identity,"order":order,"remaining":admitted,"admitted":admitted,"break_hp":q.break_hp,
		"origin_source":Sources.capture(event),"card_potency":q.duplicate(true),
		"until":elapsed+(CORE_MS if is_core else CATALYST_MS)+int(q.get("duration_bonus_ms",0))})
	player[GRANTS]=grants
	Journal.event("combat","affinity_bark_granted",{"actor":event.actor,"recipient":id,
		"activation":event.identity,"offered":offered,"admitted":admitted,"quality":event.quality,"grant":order})
	return admitted


static func absorption_plan(player: Dictionary, hp: int, elapsed: int) -> Dictionary:
	if not player.has(GRANTS):
		return {}
	var grants:=live_grants(player,elapsed).duplicate(true)
	var total:=capacity(grants)
	var absorbed:=mini(total,floori(hp*ABSORPTION))
	if absorbed<=0:
		return {}
	grants.sort_custom(func(a,b):return int(a.until)<int(b.until) or (a.until==b.until and int(a.order)<int(b.order)))
	var amount_left:=absorbed
	var shares:=[]
	var owner: Dictionary={}
	var weighted:=0
	var ceiling:=0
	for entry in grants:
		if amount_left==0: break
		var take:=mini(amount_left,int(entry.remaining))
		entry.remaining-=take
		amount_left-=take
		var share:={"actor":entry.actor,"source_life":entry.get("source_life",-1),"slot":entry.slot,"item":entry.item,"quality":entry.quality,
			"activation":entry.activation,"order":entry.order,"hp":take,"burst_hp":entry.break_hp,
			"origin_source":entry.get("origin_source",{}).duplicate(true),"card_potency":entry.get("card_potency",{}).duplicate(true)}
		shares.append(share)
		if owner.is_empty() or int(owner.hp)<take or (int(owner.hp)==take and int(share.order)<int(owner.order)):
			owner=share
		weighted+=take*int(entry.break_hp)
		ceiling=maxi(ceiling,int(entry.break_hp))
	var depleted:=absorbed==total
	var damage:=0
	if depleted and elapsed>=int(player.get(BURST_READY,0)):
		damage=clampi(roundi(float(weighted)/absorbed),0,ceiling)
	return {"grants":grants.filter(func(entry):return int(entry.remaining)>0),"absorbed":absorbed,"depleted":depleted,
		"elapsed":elapsed,"center":player.pos,"owner":owner.actor,"owner_life":owner.source_life,"damage":damage,"shares":shares}


static func consume(player: Dictionary, plan: Dictionary) -> void:
	if plan.is_empty():
		return
	if plan.grants.is_empty(): player.erase(GRANTS)
	else: player[GRANTS]=plan.grants
	if int(plan.damage)>0:
		player[BURST_READY]=int(plan.elapsed)+BURST_INTERVAL_MS


static func after_hit(game: Node, id: int, epoch: int, plan: Dictionary, now: int) -> void:
	if plan.is_empty():
		return
	Journal.event("combat","affinity_bark_absorbed",{"recipient":id,"absorbed":plan.absorbed,"depleted":plan.depleted,
		"damage":plan.damage,"shares":plan.shares,"owner":plan.owner})
	if epoch==game.participation.epoch():retaliate(game,id,plan,now)
	if int(plan.damage)>0 and epoch==game.participation.epoch() and game.participation.active() and not game.persistence_session.is_blocked() \
			and PlayerLifecycle.matches(game.players.get(plan.owner,{}),int(plan.owner_life)):
		burst(game,plan.owner,plan.center,plan.damage,now,"Bark break")


static func clear(player: Dictionary) -> void:
	player.erase(GRANTS)
	player.erase(BURST_READY)
	player.erase(FORM_READY)
	player.erase(RETALIATION)


static func tick(game: Node, elapsed: int) -> void:
	for player in game.players.values():
		if not player.has(GRANTS):
			continue
		var grants:=live_grants(player,elapsed)
		if grants.size()==player[GRANTS].size():
			continue
		if grants.is_empty(): player.erase(GRANTS)
		else: player[GRANTS]=grants


static func nearby(game: Node, center: Vector3, radius: float) -> Array[int]:
	return game.Life.living_ids(game).filter(func(id):
		var pos: Vector3=game.players[id].pos
		return center.distance_to(pos)<=radius and game.battlefield.clear_line(center,pos))


static func burst(game: Node, owner: int, center: Vector3, damage: int, now: int, label: String, radius: float=WARD_RADIUS, secondary := false) -> void:
	game.emit_combat_event("ability","wood_burst",center,center,.55,COLOR,radius,owner,{"label":label})
	for target in game.skill_area_targets(center,radius,center):
		if game.persistence_session.is_blocked(): break
		Actors.damage(game,owner,target,damage,now,COLOR,secondary)


static func splinters(game: Node, event: RefCounted, details: Dictionary, now: int) -> void:
	var player: Dictionary=game.players.get(event.actor,{})
	var elapsed:=Clock.now(game)
	if not game.Life.alive(player) or elapsed<int(player.get(FORM_READY,0)) or not event.take_response("wood_form"):
		return
	var target: int=details.enemy
	var at: Vector3=details.get("point",game.enemy_position(target))
	at.y=0.0
	var forward: Vector3=details.get("forward",player.facing)
	forward.y=0.0
	if forward.length_squared()<.01:forward=player.facing
	forward=forward.normalized()
	var q: Dictionary=event.potency()
	player[FORM_READY]=elapsed+FORM_INTERVAL_MS
	Actors.damage(game,event.actor,target,q.impact_hp+int(q.get("concentrated_hp",0)),now,COLOR)
	game.emit_combat_event("ability","wood_splinters",at,at+forward*FAN_RADIUS,.36,COLOR,FAN_RADIUS,event.actor,{"label":"Splintering strike"})
	volley(game,Sources.capture(event),q,at,forward,FRAGMENT_LIMIT+int(q.get("extra_fragments",0)),now,target)


static func bloom(game: Node, cast: Dictionary, player: Dictionary, now: int) -> void:
	cast.affinity_action.publish(game,"core_action","bark","",now,{"center":player.pos})


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			var center: Vector3=details.center
			for id in nearby(game,center,CORE_RADIUS):
				grant(game,event,id,"core")
			game.emit_combat_event("ability","ironbark",center,center,.55,COLOR,CORE_RADIUS,event.actor,{"label":"Ironbark armor"})
			if int(event.potency().get("activation_fragments",0))>0 and event.take_response("wood_activation_volley"):
				volley(game,Sources.capture(event),event.potency(),center,Vector3.FORWARD,int(event.potency().activation_fragments),now,-2,true)
		"weapon_contact":
			splinters(game,event,details,now)
		"actual_block":
			var id: int=details.recipient
			var protected: Dictionary=game.players.get(id,{})
			var center: Vector3=details.center
			for other in nearby(game,center,WARD_RADIUS):
				grant(game,event,other,"ward-%d"%id)
			var elapsed:=Clock.now(game)
			if game.Life.alive(protected) and elapsed>=int(protected.get(BURST_READY,0)):
				protected[BURST_READY]=elapsed+BURST_INTERVAL_MS
				burst(game,event.actor,center,event.potency().ward_hp,now,"Wood Ward")
		"class_contact", "class_field_contact":
			grant(game,event,event.actor,"offense")
			offensive_volley(game,event,game.enemy_position(int(details.enemy)),now)
		"class_action":
			match details.get("response",""):
				"self_bark":
					if not details.enemies.is_empty():
						grant(game,event,event.actor,"offense")
						offensive_volley(game,event,details.center,now)
				"recipient_bark":
					for id in details.recipients: grant(game,event,id,"heal")
				"landing_bark":
					grant(game,event,event.actor,"landing")


static func spend_all(player: Dictionary, elapsed: int) -> int:
	var spent:=capacity(live_grants(player,elapsed))
	player.erase(GRANTS) # Resource expenditure, not absorption: no break/retaliation.
	return spent

static func source_living(game: Node, source: Dictionary) -> bool:
	return not source.is_empty() and Sources.current(game,source) and game.Life.alive(game.players.get(int(source.actor),{}))

static func volley(game: Node, source: Dictionary, potency: Dictionary, origin: Vector3, forward: Vector3, fragments: int, now: int, excluded: int=-2, radial := false) -> void:
	if fragments<=0 or not source_living(game,source):return
	var held:=capacity(live_grants(game.players[source.actor],Clock.now(game)))
	var hp:=int(potency.fragment_hp)+roundi(held*int(potency.get("held_bark_percent",0))/100.0)
	var used:={}
	used[excluded]=true
	var candidates: Array=Contact.candidates(game,origin)
	for target: int in candidates:
		if fragments<=0 or game.persistence_session.is_blocked() or not source_living(game,source):break
		if used.has(target):continue
		var at: Vector3=game.enemy_position(target)
		var offset:=at-origin
		if offset.length()>FAN_RADIUS or (not radial and not offset.is_zero_approx() and offset.normalized().dot(forward)<FAN_MIN_DOT) or not game.battlefield.clear_line(origin,at):continue
		fragments-=1
		var hits: Array=[target]
		var penetration:=int(potency.get("fragment_penetrations",0))
		if penetration>0 and not offset.is_zero_approx():
			var tuning: Dictionary=Catalog.DEFINITIONS.hardwood_tips.tuning
			var end: Vector3=game.battlefield.projectile_endpoint(origin,at+offset.normalized()*float(tuning.extra_reach_m),float(tuning.lane_radius_m))
			var piercing:=[]
			for other: int in candidates:
				if used.has(other) or other==target:continue
				var collision: Dictionary=load("res://enemy_hurtbox.gd").sweep(game,other,origin,end,float(tuning.lane_radius_m))
				if collision.is_empty() or not game.battlefield.combat_sight(origin,game.enemy_position(other)):continue
				if origin.distance_to(game.enemy_position(other))<offset.length():continue
				piercing.append({"target":other,"fraction":collision.fraction})
			piercing.sort_custom(func(a,b):return a.fraction<b.fraction or (a.fraction==b.fraction and a.target<b.target))
			for contact in piercing.slice(0,penetration):hits.append(int(contact.target))
		for other: int in hits:
			if used.has(other) or not Actors.valid_target(game,other):continue
			used[other]=true
			var end: Vector3=game.enemy_position(other)
			game.emit_combat_event("link","wood_fragment",origin,end,.32,COLOR,0.0,source.actor)
			Actors.damage(game,int(source.actor),other,hp,now,COLOR,true)

static func offensive_volley(game: Node,event: RefCounted,center: Vector3,now: int) -> void:
	var q: Dictionary=event.potency()
	var count:=int(q.get("offense_fragments",0))
	if count<=0 or not event.take_response("wood_offensive_volley"):return
	volley(game,Sources.capture(event),q,center,game.players[event.actor].facing,count,now,-2,true)

static func retaliate(game: Node,recipient: int,plan: Dictionary,now: int) -> void:
	if int(game.get_meta(Actors.ATTACKER,-2))< -1:return
	var owners:={}
	for share: Dictionary in plan.shares:
		var source: Dictionary=share.get("origin_source",{})
		var q: Dictionary=share.get("card_potency",{})
		if not source_living(game,source):continue
		var count:=int(q.get("guard_fragments",0))+int(q.get("retaliation_fragments",0))
		if count<=0:continue
		var key:=Sources.key(source)
		if not owners.has(key) or count>int(owners[key].count):owners[key]={"source":source,"potency":q,"count":count}
	for row: Dictionary in owners.values():
		var player: Dictionary=game.players[row.source.actor]
		var timers: Dictionary=player.get(RETALIATION,{})
		var key:=str([game.participation.epoch(),row.source.life,recipient,PlayerLifecycle.generation(game.players[recipient])])
		if now<int(timers.get(key,0)):continue
		timers[key]=now+int(Catalog.DEFINITIONS.splinterback.tuning.interval_ms)
		player[RETALIATION]=timers
		volley(game,row.source,row.potency,plan.center,Vector3.FORWARD,row.count,now,-2,true)
