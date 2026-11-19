extends RefCounted
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
const Protection = preload("res://player_protection.gd")
## Native Reaper preparations. Keys stay in the authoritative combat actor.
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Balance = preload("res://class_skill_balance.gd")
const Progression = preload("res://reaper_connected_tree.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Spirit = preload("res://spirit_affinity.gd")
const MOMENTUM := "reaper_veil_momentum"
const SIPHON := "reaper_siphon_prepared"
const STRIKE := "reaper_committed_melee"
const DIRECT := "reaper_native_contact"
const SIPHON_NODES := ["barbed_siphon","swift_siphon","wake_ward","feast_of_thorns","veil_dance"]
const FEAST_COLOR := Color("#be7890")


static func stamp(game: Node, actor: int, player: Dictionary, cast: int) -> Dictionary:
	return {"owner":actor, "epoch":game.participation.epoch(), "life":PlayerLifecycle.generation(player), "cast":cast}


static func ready(game: Node, player: Dictionary, key: String, now: int) -> Dictionary:
	var record: Dictionary = player.get(key,{})
	if int(record.get("epoch",-1)) != game.participation.epoch() or not game.Life.alive(player):
		return {}
	if not is_same(player,game.players.get(record.owner,{})) or not PlayerLifecycle.matches(player,int(record.life)):
		return {}
	if record.has("until") and now >= int(record.until):
		return {}
	return record


static func tag_hit(hit: Dictionary, nodes: Array) -> void:
	hit[DIRECT] = true
	if nodes.has("deaths_due"):
		hit.death_charge = 1


static func spends_class_charge(player: Dictionary, hit: Dictionary) -> bool:
	if hit.get(DIRECT,false) or int(player.get("frame",-1)) != Progression.TREE.class_id:
		return true
	return not Progression.TREE.eligible(player.get("character",{}))


static func commit_melee(game: Node, player: Dictionary, skill: Dictionary, stats: Dictionary, now: int) -> void:
	if not skill.has("reaper_nodes"):
		return
	var prep := ready(game,player,MOMENTUM,now)
	stats[STRIKE] = {"nodes":skill.reaper_nodes,"momentum_cast":int(prep.get("cast",-1))}


static func melee_contact(game: Node, player: Dictionary, hit: Dictionary, target: int, now: int) -> void:
	var committed: Dictionary = hit[STRIKE]
	tag_hit(hit,committed.nodes)
	var prep := ready(game,player,MOMENTUM,now)
	if prep.is_empty() or int(prep.cast) != int(committed.momentum_cast):
		return
	player.erase(MOMENTUM)
	hit.native_bonus_hp = int(hit.get("native_bonus_hp",0)) + Progression.VEIL_HP
	Journal.event("combat","veil_momentum_hit",{"actor":prep.owner,"cast_id":prep.cast,"target":target})


static func after_q(game: Node, actor: int, player: Dictionary, skill: Dictionary, center: Vector3,
		nearby: Array, damaged: bool, cast: int, now: int) -> void:
	var nodes: Array = skill.reaper_nodes
	var record := stamp(game,actor,player,cast)
	var prepared := SIPHON_NODES.filter(func(node): return nodes.has(node))
	if not prepared.is_empty():
		# A new Q replaces the old Q's preparations for this player. Each benefit is consumed independently.
		player[SIPHON] = record.merged({"nodes":prepared})
	if skill.subclass_focus == "veilwalker":
		player[MOMENTUM] = record.merged({"until":now+Progression.VEIL_MS})
	var grave_hit: bool = skill.subclass_focus == "gravekeeper" and damaged
	var learned_ward := nodes.has("grave_ward")
	if not nearby.is_empty() and (grave_hit or learned_ward):
		var duration := Balance.WARD_MS + (Progression.WARD_EXTENSION_MS if grave_hit and nodes.has("lingering_veil") else 0)
		nearby[0][Protection.STATE] = nearby[0][Protection.STATE].grant(now+duration,2 if grave_hit and learned_ward else 1,Time.get_ticks_msec(),game.participation.epoch())
	if damaged and nodes.has("grave_offering"):
		heal_lowest(game,center,1,Progression.OFFERING_HP,"grave_offering")


static func enemy_hp(game: Node, target: int) -> int:
	return game.encounter.hp(target)


static func begin_siphon(game: Node, actor: int, player: Dictionary, skill: Dictionary,
		target: int, impact: Vector3, now: int) -> Dictionary:
	var prep := ready(game,player,SIPHON,now)
	var prepared: Array = prep.get("nodes",[])
	var bonus := (Progression.BARBED_HP if prepared.has("barbed_siphon") else 0) + (Progression.FEAST_HP if prepared.has("feast_of_thorns") else 0)
	if bonus > 0:
		skill.native_hit_adjustments = {target:{"bonus_hp":bonus}}
	if prepared.has("veil_dance"):
		var origin: Vector3 = player.pos
		var distance := minf(Progression.DANCE_TRAVEL,maxf(0.0,origin.distance_to(impact)-.60))
		if distance > .01:
			var landing := Spirit.step(game,actor,origin.direction_to(impact),distance)
			if not origin.is_equal_approx(landing) and game.battlefield.clear_line(landing,impact):
				player.pos = landing
				player.velocity = Vector3.ZERO
				game.emit_combat_event("link","veil_dance",origin,landing,.35,Color("#bf9bed"),0.0,actor)
	return {"before":enemy_hp(game,target), "preparation":prep}


static func finish_siphon(game: Node, player: Dictionary, skill: Dictionary, target: int,
		impact: Vector3, cast: Dictionary, damaged: bool, now: int) -> void:
	var prep: Dictionary = cast.preparation
	var prepared: Array = prep.get("nodes",[])
	if not prepared.is_empty() and is_same(prep,ready(game,player,SIPHON,now)):
		var remaining: Array = prepared.filter(func(node): return not damaged and node in ["barbed_siphon","feast_of_thorns"])
		if remaining.is_empty():
			player.erase(SIPHON)
		else:
			prep.nodes = remaining
		if prepared.has("swift_siphon"):
			var timers: Cooldowns.Timers = player[Cooldowns.STATE]
			player[Cooldowns.STATE] = timers.refund(Cooldowns.R, now, Progression.SWIFT_MS, Balance.COOLDOWN_MIN_MS)
		if prepared.has("wake_ward"):
			for peer in support_peers(game,impact):
				game.players[peer][Protection.STATE] = game.players[peer][Protection.STATE].grant(now+Balance.WARD_MS,1,Time.get_ticks_msec(),game.participation.epoch())
		if damaged and prepared.has("veil_dance"):
			var timers: Cooldowns.Timers = player[Cooldowns.STATE]
			player[Cooldowns.STATE] = timers.ready_by(Cooldowns.DODGE, now)
		if damaged and prepared.has("feast_of_thorns"):
			feast(game,player,target,impact,now)
	if not damaged:
		return
	if skill.reaper_nodes.has("siphon_tempo") and game.Life.Sustain.eligible(game,target):
		var timers: Cooldowns.Timers = player[Cooldowns.STATE]
		player[Cooldowns.STATE] = timers.refund(Cooldowns.Q, now, Progression.TEMPO_MS)
	if skill.reaper_nodes.has("last_rites"):
		heal_lowest(game,impact,Progression.RITES_RECIPIENTS,Progression.RITES_HP,"last_rites")


static func support_peers(game: Node, center: Vector3) -> Array:
	return game.players.keys().filter(func(id):
		var ally: Dictionary = game.players[id]
		return game.Life.alive(ally) and center.distance_to(ally.pos) <= Progression.SUPPORT_RADIUS and game.battlefield.clear_line(center,ally.pos))


static func heal_lowest(game: Node, center: Vector3, count: int, hp: int, source: String) -> void:
	var peers := support_peers(game,center)
	peers.sort_custom(func(a,b):
		var first: Dictionary = game.players[a]
		var second: Dictionary = game.players[b]
		var left := PlayerVitals.current_hp(first)*float(PlayerVitals.maximum_hp(second))
		var right := PlayerVitals.current_hp(second)*float(PlayerVitals.maximum_hp(first))
		return a < b if left == right else left < right)
	for id in peers.slice(0,count):
		game.Life.Sustain.restore(game,game.players[id],hp,source)


static func feast(game: Node, player: Dictionary, primary: int, center: Vector3, now: int) -> void:
	var nearby: Array[int] = game.skill_area_targets(center,Progression.FEAST_RADIUS,center)
	nearby.erase(primary)
	nearby.sort_custom(func(a,b):
		var left: float = center.distance_squared_to(game.enemy_position(a))
		var right: float = center.distance_squared_to(game.enemy_position(b))
		return a < b if left == right else left < right)
	for target in nearby.slice(0,Progression.FEAST_TARGETS):
		var at: Vector3 = game.enemy_position(target)
		game.emit_combat_event("link","feast_of_thorns",center,at,.42,FEAST_COLOR,0.0,game.Traits.player_id(game,player))
		OutgoingHits.hit_world(game, HitSession.peer_for(player), target, center, {"damage":0.0,"affinity_hp":Progression.FEAST_HP,
			"affinity_color":FEAST_COLOR,"knockback":-.35,"core_hit":true,"trait_secondary":true}, now)
