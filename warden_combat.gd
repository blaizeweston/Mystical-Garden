extends RefCounted
## Host-owned effects from a confirmed Warden block or a committed Root Quake.
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Progression = preload("res://warden_tree.gd")
const Connected = Progression.Connected
const Feedback = preload("res://enemy_move_feedback.gd")
const Journal = preload("res://diagnostic_journal.gd")
const BARK := Color("#abc989")
const THORN := Color("#ddae7e")
const ANCHOR := Color("#d4c789")
const WARD_RADIUS := 2.5
const BLOCK_RADIUS := 3.0
const PREPARED_MS := 5500


static func has_card(player: Dictionary, id: String) -> bool:
	return int(preload("res://combat_ruleset.gd").legacy_ranks(player).get(id,0)) > 0


static func live_state(game: Node, player: Dictionary, state: Dictionary) -> bool:
	return int(state.get("epoch",-1)) == game.combat_epoch and PlayerLifecycle.matches(player,int(state.get("life",-1))) and game.Life.alive(player)


static func learned(player: Dictionary, id: String) -> bool:
	var profile: Dictionary = player.character
	if player.has("combat_ruleset") and Connected.eligible(profile):
		return Connected.path(profile).has(id)
	return Progression.learned(profile,id)


static func on_cast(game: Node, player: Dictionary, skill: Dictionary, expires: int, now: int, event: RefCounted = null) -> void:
	if not skill.has("warden_focus") or int(skill.slot) != 0:
		return
	player.warden_block = {"epoch":game.combat_epoch, "life":PlayerLifecycle.generation(player),
		"until":expires, "prepared":0, "focus":skill.warden_focus, "blocked":false, "quake_used":false, "line_used":false,
		"counter_bonus":skill.get("counter_window_bonus",0)}
	if event != null and game.has_meta(&"combat_affinity_ruleset") and Connected.eligible(player.character):
		player.warden_block.merge({"activation":event.identity, "granted":event.has_grants(), "protection_used":false})
	if skill.warden_focus != "rootkeeper":
		return
	player.warden_anchor = {"epoch":game.combat_epoch, "life":PlayerLifecycle.generation(player),
		"point":player.pos, "until":now+int(skill.anchor_lifetime),
		"uses":2 if has_card(player,"rootkeeper_second_growth") else 1}
	Feedback.release(game,"burst",player.pos,player.pos,.65,ANCHOR)


static func anchor(game: Node, player: Dictionary, now: int) -> Dictionary:
	var state: Dictionary = player.get("warden_anchor",{})
	return state if int(state.get("until",0)) > now and live_state(game,player,state) else {}


static func anchor_point(game: Node, player: Dictionary, now: int) -> Vector3:
	if not game.multiplayer.is_server():
		return player.get("warden_anchor_point",Vector3.INF)
	var state := anchor(game,player,now)
	return state.get("point",Vector3.INF)


static func quake_center(game: Node, player: Dictionary, field: RefCounted, skill: Dictionary, now: int) -> Vector3:
	var origin: Vector3 = player.pos
	if skill.get("warden_relay",false):
		var relay := relay_point(game,player,now)
		if relay.is_finite() and origin.distance_to(relay) <= Connected.RELAY_REACH and field.clear_line(origin,relay):
			return relay
	if skill.get("warden_focus","") != "rootkeeper":
		return origin
	var point := anchor_point(game,player,now)
	if point.is_finite() and origin.distance_to(point) <= float(skill.anchor_range) and field.clear_line(origin,point):
		return point
	return origin


static func consume_anchor(game: Node, player: Dictionary, point: Vector3, now: int) -> void:
	var relay := relay_state(game,player,now)
	if not relay.is_empty() and Vector3(relay.point).is_equal_approx(point):
		player.erase("warden_relay")
		return
	var state := anchor(game,player,now)
	if state.is_empty() or not Vector3(state.point).is_equal_approx(point):
		return
	state.uses -= 1
	if state.uses == 0:
		player.erase("warden_anchor")
	if Vector3(player.pos).distance_squared_to(point) > .01:
		game.emit_combat_event("link","Anchor quake",player.pos,point,.45,ANCHOR,0.0,0)


static func hints(game: Node, now: int) -> Array:
	var result: Array = []
	for id in game.players:
		var relay := relay_state(game,game.players[id],now)
		if not relay.is_empty():
			var center: Vector3 = relay.point
			var position := [center.x,0,center.z]
			result.append({"id":-19000000000-int(id),"role":"core_anchor","from":position,"to":position,"radius":.62,
				"remaining":(int(relay.until)-now)/1000.0,"color":THORN.to_html()})
		var state := anchor(game,game.players[id],now)
		if state.is_empty():
			continue
		var point: Vector3 = state.point
		var at := [point.x,0,point.z]
		result.append({"id":-18000000000-int(id),"role":"core_anchor","from":at,"to":at,"radius":.62,
			"remaining":(int(state.until)-now)/1000.0,"color":ANCHOR.to_html()})
	return result


static func contacts(game: Node, origin: Vector3, radius: float, skip: Array = []) -> Array[int]:
	var result: Array[int] = []
	for target in game.skill_area_targets(origin,radius,origin):
		if target in skip or (target == -1 and game.boss_kind >= 0):
			continue
		result.append(target)
	result.sort_custom(func(a,b):return origin.distance_squared_to(game.enemy_position(a)) < origin.distance_squared_to(game.enemy_position(b)))
	return result


static func block_effects(game: Node, player: Dictionary, now: int) -> void:
	var state: Dictionary = player.get("warden_block",{})
	if state.has("activation") or not live_state(game,player,state) or int(state.get("until",0)) <= now or state.blocked:
		return
	first_block(game,player,state,now)


static func first_block(game: Node, player: Dictionary, state: Dictionary, now: int) -> void:
	state.blocked = true
	if int(player.get("counter_until",0)) > now:
		player.counter_until += int(state.counter_bonus)
	if learned(player,"briar_rebound"):
		rebound(game,player.pos)
	if learned(player,"shared_guard"):
		shared_guard(game,player,now,"Shared Guard")
	elif learned(player,"shared_bark"):
		shared_guard(game,player,now,"Shared Bark")
	if learned(player,"ready_footing"):
		var timers: Cooldowns.Timers = player[Cooldowns.STATE]
		if not timers.ready(Cooldowns.DODGE, now):
			player[Cooldowns.STATE] = timers.ready_by(Cooldowns.DODGE, now)
			cue(game,"Ready Footing",player.pos)
	if learned(player,"clear_the_way"):
		for ally in game.players.values():
			if int(ally.get("slow_until",0)) > now and in_circle(game,ally,player.pos,BLOCK_RADIUS):
				ally.slow_until = 0
				cue(game,"Cleansed",ally.pos)
	if learned(player,"cracking_roots") and not player.has("combat_ruleset"):
		var nearby := contacts(game,player.pos,BLOCK_RADIUS)
		if not nearby.is_empty():
			var traits: Dictionary = game.Traits.target_state(game,nearby[0])
			var old := int(traits.get("brittle",0)) if int(traits.get("brittle_until",0)) > now else 0
			traits.brittle = mini(2,old+1)
			traits.brittle_until = now+4000
	if needs_quake(player) or learned(player,"aftershock") or has_card(player,"bastion_thorn_shelter"):
		state.prepared = now+PREPARED_MS


static func needs_quake(player: Dictionary) -> bool:
	return learned(player,"pinning_quake") or learned(player,"living_rhythm") or learned(player,"sheltering_quake") \
		or learned(player,"faultline_impact") or has_card(player,"vanguard_briar_wake")


static func prepared_until(game: Node, player: Dictionary, now: int) -> int:
	var state: Dictionary = player.get("warden_block",{})
	var expires := int(state.get("prepared",0))
	if expires <= now or not live_state(game,player,state):
		return 0
	if (not state.quake_used and needs_quake(player)) or (not state.line_used and has_card(player,"bastion_thorn_shelter")) \
		or (not state.get("aftershock_used",false) and learned(player,"aftershock")):
		return expires
	return 0


static func rebound(game: Node, origin: Vector3) -> void:
	var moved := 0
	for target in contacts(game,origin,2.25):
		var winding: bool = game.enemy_winding_up if target == -1 else int(game.encounter.scout(target).windup) > 0
		if winding:
			continue
		var point: Vector3 = game.enemy_position(target)
		var offset := (point-origin).normalized()
		var landing: Vector3 = game.battlefield.dash(point,point+offset*.85)
		if point.is_equal_approx(landing):
			continue
		if target == -1:
			game.enemy_pos = landing
		else:
			game.encounter.scout(target).pos = landing
		game.emit_combat_event("link","Briar Rebound",point,landing,.42,THORN,0.0,target)
		moved += 1
		if moved >= 2:
			break
	if moved > 0:
		cue(game,"Briar Rebound",origin)


static func in_circle(game: Node, player: Dictionary, point: Vector3, radius: float) -> bool:
	return game.Life.alive(player) and point.distance_to(player.pos) <= radius and game.battlefield.clear_line(point,player.pos)


static func shared_guard(game: Node, player: Dictionary, now: int, label: String) -> void:
	var best: Dictionary = player
	var nearest := BLOCK_RADIUS
	for ally in game.players.values():
		if is_same(ally,player) or not in_circle(game,ally,player.pos,nearest):
			continue
		best = ally
		nearest = Vector3(player.pos).distance_to(ally.pos)
	game.grant_guard(best,now+950,1)
	cue(game,label,best.pos)


static func cue(game: Node, name: String, at: Vector3) -> void:
	game.emit_combat_event("proc",name,at,at,.55,BARK,0.0,0)


static func quake_hit(game: Node, player: Dictionary, center: Vector3, targets: Array[int], radius: float, now: int) -> void:
	if prepared_until(game,player,now) == 0:
		return
	var state: Dictionary = player.warden_block
	if learned(player,"aftershock") and not state.get("aftershock_used",false):
		state.aftershock_used = true
		player.warden_aftershock = {"point":center, "due":now+Connected.AFTERSHOCK_MS, "epoch":game.combat_epoch,
			"life":PlayerLifecycle.generation(player)}
	# Connected nodes spend their preparation on the next Quake. Historical
	# paths keep the original next-hitting-Quake behavior.
	if (targets.is_empty() and not state.has("activation")) or state.quake_used or not needs_quake(player):
		return
	state.quake_used = true
	if learned(player,"pinning_quake"):
		var count := 0
		for target in targets:
			if (target == -1 and game.boss_kind >= 0) or not game.Traits.valid_target(game,target):
				continue
			load("res://combat_status.gd").root(game,target,now+950)
			count += 1
			if count >= 2:
				break
	if not targets.is_empty() and learned(player,"living_rhythm"):
		var timers: Cooldowns.Timers = player[Cooldowns.STATE]
		if not timers.ready(Cooldowns.Q, now):
			player[Cooldowns.STATE] = timers.refund(Cooldowns.Q, now, 1250)
			cue(game,"Living Rhythm",player.pos)
	if learned(player,"sheltering_quake"):
		ward_circle(game,center,radius,now)
	if state.focus == "vanguard" and has_card(player,"vanguard_briar_wake"):
		var targets_outside := contacts(game,center,radius+1.4,targets)
		for target in targets_outside:
			var at: Vector3 = game.enemy_position(target)
			if center.distance_to(at) <= radius:
				continue
			game.emit_combat_event("link","Briar Wake",center,at,.45,THORN,0.0,target)
			game.apply_weapon_hit(player,target,center,{"damage":2,"knockback":-.35,"trait_secondary":true},now)
			break


static func thorn_tripped(game: Node, player: Dictionary, point: Vector3, now: int) -> void:
	if not has_card(player,"bastion_thorn_shelter") or prepared_until(game,player,now) == 0:
		return
	var state: Dictionary = player.warden_block
	if state.focus != "bastion" or state.line_used:
		return
	if ward_circle(game,point,WARD_RADIUS,now):
		state.line_used = true


static func connected_block(game: Node, event: RefCounted, recipient: int, now: int) -> void:
	var player: Dictionary = game.players.get(event.actor, {})
	var state: Dictionary = player.get("warden_block", {})
	if state.get("activation", -1) != event.identity or int(state.until) <= now or not live_state(game,player,state):
		return
	state.protection_used = true
	if not state.get("holdfast_granted",false) and learned(player,"holdfast"):
		state.holdfast_granted = true
		grant_holdfast(game,player,event,now)
	# Ally blocks can grant Holdfast from this Q. The other native follow-ups still use the Warden's own block.
	if recipient != event.actor or state.blocked:
		return
	first_block(game,player,state,now)
	if learned(player,"seismic_relay"):
		player.warden_relay = {"point":player.pos, "until":now+Connected.RELAY_MS, "epoch":game.combat_epoch,
			"life":PlayerLifecycle.generation(player)}
		Feedback.release(game,"burst",player.pos,player.pos,.65,ANCHOR)
	if learned(player,"sanctuary_ground"):
		player.warden_sanctuary = {"point":player.pos, "until":now+Connected.SANCTUARY_MS, "epoch":game.combat_epoch,
			"life":PlayerLifecycle.generation(player)}
		game.emit_combat_event("field","sanctuary_ground",player.pos,player.pos,
			Connected.SANCTUARY_MS/1000.0,BARK,Connected.SANCTUARY_RADIUS,recipient,{"label":"Sanctuary Ground"})


static func relay_state(game: Node, player: Dictionary, now: int) -> Dictionary:
	var state: Dictionary = player.get("warden_relay",{})
	return state if int(state.get("until",0)) > now and live_state(game,player,state) else {}


static func relay_point(game: Node, player: Dictionary, now: int) -> Vector3:
	if not game.multiplayer.is_server():
		return player.get("warden_relay_point",Vector3.INF)
	return relay_state(game,player,now).get("point",Vector3.INF)


static func prepare_quake_damage(game: Node, player: Dictionary, skill: Dictionary, now: int) -> void:
	if learned(player,"faultline_impact") and prepared_until(game,player,now)>0 and not player.warden_block.quake_used:
		skill.damage = float(skill.damage) + Connected.FAULTLINE_POINTS


static func grant_holdfast(game: Node, warden: Dictionary, event: RefCounted, now: int) -> void:
	var until := now + Connected.HOLDFAST_MS
	var recipients: Array[int] = []
	for id in game.players:
		var ally: Dictionary = game.players[id]
		if not is_same(ally,warden) and not in_circle(game,ally,warden.pos,Connected.HOLDFAST_RADIUS):
			continue
		if holdfast_until(game,ally,now) >= until:
			continue
		ally.warden_holdfast = {"actor":event.actor, "activation":event.identity, "until":until,
			"epoch":game.combat_epoch, "life":PlayerLifecycle.generation(ally)}
		recipients.append(id)
	if not recipients.is_empty():
		Journal.event("combat","holdfast_granted",{"actor":event.actor,"activation":event.identity,
			"epoch":game.combat_epoch,"recipients":recipients,"duration_ms":Connected.HOLDFAST_MS})


static func holdfast_until(game: Node, player: Dictionary, now: int) -> int:
	var grant: Dictionary = player.get("warden_holdfast",{})
	var until := int(grant.get("until",0))
	return until if until > now and live_state(game,player,grant) else 0


static func direct_damage(game: Node, player: Dictionary, hp: int, now: int) -> int:
	if hp <= 0:
		return hp
	var reduction := Connected.HOLDFAST_REDUCTION if holdfast_until(game,player,now)>0 else 0.0
	var weaver = preload("res://weaver_combat.gd")
	if weaver.filaments_until(game,player,now)>0:
		reduction = maxf(reduction,weaver.Progression.FILAMENTS_REDUCTION)
	for owner in game.players.values():
		var state: Dictionary = owner.get("warden_sanctuary",{})
		if int(state.get("until",0)) > now and live_state(game,owner,state) and in_circle(game,player,state.point,Connected.SANCTUARY_RADIUS):
			reduction = maxf(reduction,Connected.SANCTUARY_REDUCTION)
			break
	return maxi(1,roundi(float(hp)*(1.0-reduction)))


static func tick(game: Node, now: int) -> void:
	for id in game.players:
		var player: Dictionary = game.players[id]
		var guard: Dictionary = player.get("warden_block",{})
		if guard.has("activation") and not guard.get("checked_expiry",false) and int(guard.until) <= now:
			guard.checked_expiry = true
			if guard.granted and not guard.protection_used and live_state(game,player,guard) and learned(player,"measured_guard"):
				var timers: Cooldowns.Timers = player[Cooldowns.STATE]
				if not timers.ready(Cooldowns.Q, now):
					player[Cooldowns.STATE] = timers.refund(Cooldowns.Q, now, Connected.Q_REFUND_MS)
					cue(game,"Measured Guard",player.pos)
		var pending: Dictionary = player.get("warden_aftershock",{})
		if pending.is_empty() or int(pending.due) > now:
			continue
		player.erase("warden_aftershock")
		if not live_state(game,player,pending):
			continue
		var center: Vector3 = pending.point
		game.emit_combat_event("proc","Aftershock",center,center,.5,THORN,Connected.AFTERSHOCK_RADIUS,id)
		var targets: Array[int] = game.skill_area_targets(center,Connected.AFTERSHOCK_RADIUS,center)
		for target in targets:
			# The existing secondary damage path skips contact traits, Catalyst events and displacement.
			game.apply_weapon_hit(player,target,center,{"damage":0.0,"affinity_hp":Connected.AFTERSHOCK_HP,
				"trait_secondary":true,"core_hit":true,"knockback":-.35},now)
		if not targets.is_empty() and game.encounter_cleared():
			game.finish_combat(id,center)
			if not game.Transactions.session_writable(game):
				return


static func ward_circle(game: Node, point: Vector3, radius: float, now: int) -> bool:
	var warded := false
	for ally in game.players.values():
		if in_circle(game,ally,point,radius):
			game.grant_guard(ally,now+1250,1)
			warded = true
	if warded:
		Feedback.release(game,"burst",point,point,radius,BARK)
	return warded
