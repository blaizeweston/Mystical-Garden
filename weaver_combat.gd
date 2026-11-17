extends RefCounted
## Host-side connected Weaver effects. Extra areas and delayed effects are native spell damage.
const Cooldowns = preload("res://player_cooldowns.gd")
const Progression = preload("res://weaver_connected_tree.gd")
const Journal = preload("res://diagnostic_journal.gd")
const COLOR := Color("#c9a8db")


static func current(game: Node, player: Dictionary, state: Dictionary) -> bool:
	return int(state.get("epoch",-1)) == game.combat_epoch and int(state.get("life",-1)) == int(player.get("lost_health",0)) and game.Life.alive(player)


static func lifetime(game: Node, player: Dictionary) -> Dictionary:
	return {"epoch":game.combat_epoch,"life":int(player.get("lost_health",0))}


static func on_q(game: Node, actor: int, player: Dictionary, selected: Array, point: Vector3, allies: Array,
		contact: bool, field: Dictionary, activation: int, now: int) -> void:
	if selected.has("threaded_nova"):
		var prior: Dictionary = player.get("subclass_follow", {})
		if int(prior.get("lane", -1)) == 1:
			player.erase("subclass_follow")
		var timers: Cooldowns.Timers = player[Cooldowns.STATE]
		if (selected[0] != "bloomcaller" or not field.is_empty()) and not timers.ready(Cooldowns.R, now):
			player[Cooldowns.STATE] = timers.refund(Cooldowns.R, now, Progression.THREAD_REFUND_MS)
	if selected.has("spore_pressure"):
		if contact:
			player.weaver_pressure = lifetime(game,player)
		elif not field.is_empty():
			field.weaver_pressure = lifetime(game,player)
	if selected.has("symbiotic_nova"):
		player.weaver_nova_origin = lifetime(game,player)
		player.weaver_nova_origin.merge({"point":point,"until":now+Progression.SYMBIOTIC_MS})
	if selected.has("protective_filaments"):
		var until := now+Progression.FILAMENTS_MS
		for ally in allies:
			if filaments_until(game,ally,now) >= until:
				continue
			ally.weaver_filaments = lifetime(game,ally)
			ally.weaver_filaments.merge({"until":until,"actor":actor,"activation":activation})


static func field_contact(game: Node, player: Dictionary, field: Dictionary) -> void:
	var pending: Dictionary = field.get("weaver_pressure",{})
	if not pending.is_empty():
		field.erase("weaver_pressure")
		if current(game,player,pending):
			player.weaver_pressure = pending


static func filaments_until(game: Node, player: Dictionary, now: int) -> int:
	var grant: Dictionary = player.get("weaver_filaments",{})
	var until := int(grant.get("until",0))
	return until if until > now and current(game,player,grant) else 0


static func prepare_nova(game: Node, actor: int, player: Dictionary, skill: Dictionary, targets: Array[int],
		caster: Vector3, now: int) -> Vector3:
	var hits := {}
	var selected: Array = skill.weaver_nodes
	var anchor: Dictionary = player.get("weaver_nova_origin",{})
	player.erase("weaver_nova_origin")
	if int(anchor.get("until",0)) > now and current(game,player,anchor):
		var point: Vector3 = anchor.point
		if point.distance_to(caster) <= Progression.SYMBIOTIC_REACH and game.battlefield.clear_line(caster,point):
			for target in game.skill_area_targets(point,Progression.SYMBIOTIC_RADIUS,point):
				if not targets.has(target):
					targets.append(target)
					hits[target] = {"origin":point}
			game.emit_combat_event("ability","nova",point,point,.8,Color(skill.color),Progression.SYMBIOTIC_RADIUS,actor)
	var pressure: Dictionary = player.get("weaver_pressure",{})
	player.erase("weaver_pressure")
	if current(game,player,pressure):
		for target in targets:
			if not hits.has(target):
				hits[target] = {}
			hits[target].bonus_hp = Progression.PRESSURE_HP
	# The host walks the primary area in leader/scout slot order, then adds
	# relay-only targets in that order. Capture the first hit's location before damage.
	var first := Vector3.INF
	if not targets.is_empty():
		var target: int = targets[0]
		first = game.enemy_position(target)
		if selected.has("barbed_nova") and int(player.get("subclass_follow",{}).get("lane",-1)) == 0 and current(game,player,player.subclass_follow):
			player.erase("subclass_follow")
			if not hits.has(target):
				hits[target] = {}
			hits[target].bonus_hp = int(hits[target].get("bonus_hp",0)) + Progression.BARBED_HP
	skill.native_hit_adjustments = hits
	return first


static func complete_nova(game: Node, actor: int, player: Dictionary, selected: Array,
		center: Vector3, first_impact: Vector3, now: int) -> void:
	if first_impact.is_finite():
		if selected.has("spore_cycle"):
			var timers: Cooldowns.Timers = player[Cooldowns.STATE]
			if not timers.ready(Cooldowns.Q, now):
				player[Cooldowns.STATE] = timers.refund(Cooldowns.Q, now, Progression.CYCLE_MS)
		if selected.has("bursting_spores"):
			var burst := lifetime(game,player)
			burst.merge({"kind":"weaver_burst","owner":actor,"due":now+Progression.BURST_DELAY_MS,"position":first_impact})
			player.weaver_capstone = burst
	if selected.has("silken_canopy"):
		game.Traits.end_zone(game,player.get("weaver_capstone",{}))
		var canopy := lifetime(game,player)
		game.emit_combat_event("field","weaver_canopy_zone",center,center,Progression.CANOPY_MS/1000.0,
			COLOR,Progression.CANOPY_RADIUS,actor)
		canopy.merge({"kind":"weaver_canopy","owner":actor,"position":center,"radius":Progression.CANOPY_RADIUS,
			"until":now+Progression.CANOPY_MS,"visual_id":game.combat_event_serial,"recipients":{}})
		player.weaver_capstone = canopy
		canopy_contacts(game,canopy,now)


static func tick(game: Node, now: int) -> void:
	# Each Weaver owns at most one pending capstone on a floor. A native
	# Nova cooldown is longer than the burst delay. The generic trait queue
	# keeps its existing cap and cannot crowd out this class response.
	for player in game.players.values():
		var effect: Dictionary = player.get("weaver_capstone",{})
		if effect.is_empty():
			continue
		if not current(game,player,effect):
			game.Traits.end_zone(game,effect)
			player.erase("weaver_capstone")
		elif effect.kind == "weaver_burst" and now >= int(effect.due):
			player.erase("weaver_capstone")
			burst(game,player,effect,now)
			if not game.Transactions.session_writable(game):
				return
		elif effect.kind == "weaver_canopy":
			if now >= int(effect.until):
				game.Traits.end_zone(game,effect)
				player.erase("weaver_capstone")
			else:
				canopy_contacts(game,effect,now)


static func canopy_contacts(game: Node, canopy: Dictionary, now: int) -> void:
	for id in game.players:
		var ally: Dictionary = game.players[id]
		if canopy.recipients.has(id) or not game.Life.alive(ally):
			continue
		if canopy.position.distance_to(ally.pos) > Progression.CANOPY_RADIUS or not game.battlefield.clear_line(canopy.position,ally.pos):
			continue
		canopy.recipients[id] = true
		# Standard one-charge Ward with no affinity block response attached.
		game.grant_guard(ally,now+Progression.CANOPY_WARD_MS,1)
		Journal.event("combat","canopy_ward",{"actor":canopy.owner,"cast":canopy.visual_id,"recipient":id})


static func burst(game: Node, player: Dictionary, effect: Dictionary, now: int) -> void:
	if not current(game,player,effect):
		return
	var point: Vector3 = effect.position
	game.emit_combat_event("proc","Bursting Spores",point,point,.5,COLOR,Progression.BURST_RADIUS,effect.owner)
	for target in game.skill_area_targets(point,Progression.BURST_RADIUS,point):
		secondary_hit(game,player,target,point,Progression.BURST_HP,now)
	if game.encounter_cleared():
		game.finish_combat(int(effect.owner),point)


static func secondary_hit(game: Node, player: Dictionary, target: int, origin: Vector3, hp: int, now: int) -> void:
	game.apply_weapon_hit(player,target,origin,{"damage":0.0,"affinity_hp":hp,"trait_secondary":true,
		"core_hit":true,"knockback":-.35},now)
