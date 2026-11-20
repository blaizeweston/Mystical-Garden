extends RefCounted

const Sources = preload("res://affinity_status_source.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Actors = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Contact = preload("res://weapon_contact.gd")
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
			"activation":entry.activation,"order":entry.order,"hp":take,"burst_hp":entry.break_hp}
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
	if int(plan.damage)>0 and epoch==game.participation.epoch() and game.participation.active() and not game.persistence_session.is_blocked() \
			and PlayerLifecycle.matches(game.players.get(plan.owner,{}),int(plan.owner_life)):
		burst(game,plan.owner,plan.center,plan.damage,now,"Bark break")


static func clear(player: Dictionary) -> void:
	player.erase(GRANTS)
	player.erase(BURST_READY)
	player.erase(FORM_READY)


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


static func burst(game: Node, owner: int, center: Vector3, damage: int, now: int, label: String) -> void:
	game.emit_combat_event("ability","wood_burst",center,center,.55,COLOR,WARD_RADIUS,owner,{"label":label})
	for target in game.skill_area_targets(center,WARD_RADIUS,center):
		if game.persistence_session.is_blocked(): break
		Actors.damage(game,owner,target,damage,now,COLOR)


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
	Actors.damage(game,event.actor,target,q.impact_hp,now,COLOR)
	game.emit_combat_event("ability","wood_splinters",at,at+forward*FAN_RADIUS,.36,COLOR,FAN_RADIUS,event.actor,{"label":"Splintering strike"})
	var remaining:=FRAGMENT_LIMIT
	for other in Contact.candidates(game,at):
		if remaining==0 or game.persistence_session.is_blocked(): break
		if other==target:continue
		var pos: Vector3=game.enemy_position(other)
		var offset:=pos-at
		if offset.length()>FAN_RADIUS or offset.normalized().dot(forward)<FAN_MIN_DOT or not game.battlefield.clear_line(at,pos):
			continue
		game.emit_combat_event("link","wood_fragment",at,pos,.32,COLOR,0.0,event.actor)
		Actors.damage(game,event.actor,other,q.fragment_hp,now,COLOR)
		remaining-=1


static func bloom(game: Node, cast: Dictionary, player: Dictionary, now: int) -> void:
	cast.affinity_action.publish(game,"core_action","bark","",now,{"center":player.pos})


static func on_event(game: Node, event: RefCounted, kind: String, details: Dictionary, now: int) -> void:
	match kind:
		"core_action":
			var center: Vector3=details.center
			for id in nearby(game,center,CORE_RADIUS):
				grant(game,event,id,"core")
			game.emit_combat_event("ability","ironbark",center,center,.55,COLOR,CORE_RADIUS,event.actor,{"label":"Ironbark armor"})
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
		"class_action":
			match details.get("response",""):
				"self_bark":
					if not details.enemies.is_empty(): grant(game,event,event.actor,"offense")
				"recipient_bark":
					for id in details.recipients: grant(game,event,id,"heal")
				"landing_bark":
					grant(game,event,event.actor,"landing")
