extends RefCounted
## Host-owned effects from a confirmed Warden block or a committed Root Quake.
const Progression = preload("res://warden_tree.gd")
const Feedback = preload("res://enemy_move_feedback.gd")
const BARK := Color("#abc989")
const THORN := Color("#ddae7e")
const ANCHOR := Color("#d4c789")
const WARD_RADIUS := 2.5
const BLOCK_RADIUS := 3.0
const PREPARED_MS := 5500


static func has_card(player: Dictionary, id: String) -> bool:
	return int(player.get("run_upgrades",{}).get(id,0)) > 0


static func live_state(game: Node, player: Dictionary, state: Dictionary) -> bool:
	return int(state.get("epoch",-1)) == game.combat_epoch and int(state.get("life",-1)) == int(player.get("lost_health",0)) and game.Life.alive(player)


static func on_cast(game: Node, player: Dictionary, skill: Dictionary, expires: int, now: int) -> void:
	if not skill.has("warden_focus") or int(skill.slot) != 0:
		return
	player.warden_block = {"epoch":game.combat_epoch, "life":int(player.get("lost_health",0)),
		"until":expires, "prepared":0, "focus":skill.warden_focus, "blocked":false, "quake_used":false, "line_used":false,
		"counter_bonus":skill.get("counter_window_bonus",0)}
	if skill.warden_focus != "rootkeeper":
		return
	player.warden_anchor = {"epoch":game.combat_epoch, "life":int(player.get("lost_health",0)),
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
	if skill.get("warden_focus","") != "rootkeeper":
		return origin
	var point := anchor_point(game,player,now)
	if point.is_finite() and origin.distance_to(point) <= float(skill.anchor_range) and field.clear_line(origin,point):
		return point
	return origin


static func consume_anchor(game: Node, player: Dictionary, point: Vector3, now: int) -> void:
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
	if not live_state(game,player,state) or int(state.get("until",0)) <= now or state.blocked:
		return
	state.blocked = true
	var profile: Dictionary = player.character
	if int(player.get("counter_until",0)) > now:
		player.counter_until += int(state.counter_bonus)
	if Progression.learned(profile,"briar_rebound"):
		rebound(game,player.pos)
	if Progression.learned(profile,"shared_bark"):
		shared_bark(game,player,now)
	if Progression.learned(profile,"ready_footing") and int(player.get("dodge_at",0)) > now:
		player.dodge_at = now
		cue(game,"Ready Footing",player.pos)
	if Progression.learned(profile,"clear_the_way"):
		for ally in game.players.values():
			if int(ally.get("slow_until",0)) > now and in_circle(game,ally,player.pos,BLOCK_RADIUS):
				ally.slow_until = 0
				cue(game,"Cleansed",ally.pos)
	if Progression.learned(profile,"cracking_roots"):
		var nearby := contacts(game,player.pos,BLOCK_RADIUS)
		if not nearby.is_empty():
			var traits: Dictionary = game.Traits.target_state(game,nearby[0])
			var old := int(traits.get("brittle",0)) if int(traits.get("brittle_until",0)) > now else 0
			traits.brittle = mini(2,old+1)
			traits.brittle_until = now+4000
	if needs_quake(profile,player) or has_card(player,"bastion_thorn_shelter"):
		state.prepared = now+PREPARED_MS


static func needs_quake(profile: Dictionary, player: Dictionary) -> bool:
	return Progression.learned(profile,"pinning_quake") or Progression.learned(profile,"living_rhythm") or Progression.learned(profile,"sheltering_quake") or has_card(player,"vanguard_briar_wake")


static func prepared_until(game: Node, player: Dictionary, now: int) -> int:
	var state: Dictionary = player.get("warden_block",{})
	var expires := int(state.get("prepared",0))
	if expires <= now or not live_state(game,player,state):
		return 0
	if (not state.quake_used and needs_quake(player.character,player)) or (not state.line_used and has_card(player,"bastion_thorn_shelter")):
		return expires
	return 0


static func rebound(game: Node, origin: Vector3) -> void:
	var moved := 0
	for target in contacts(game,origin,2.25):
		var winding: bool = game.enemy_winding_up if target == -1 else int(game.scouts[target].windup) > 0
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
			game.scouts[target].pos = landing
		game.emit_combat_event("link","Briar Rebound",point,landing,.42,THORN,0.0,target)
		moved += 1
		if moved >= 2:
			break
	if moved > 0:
		cue(game,"Briar Rebound",origin)


static func in_circle(game: Node, player: Dictionary, point: Vector3, radius: float) -> bool:
	return game.Life.alive(player) and point.distance_to(player.pos) <= radius and game.battlefield.clear_line(point,player.pos)


static func shared_bark(game: Node, player: Dictionary, now: int) -> void:
	var best: Dictionary = player
	var nearest := BLOCK_RADIUS
	for ally in game.players.values():
		if is_same(ally,player) or not in_circle(game,ally,player.pos,nearest):
			continue
		best = ally
		nearest = Vector3(player.pos).distance_to(ally.pos)
	game.grant_guard(best,now+950,1)
	cue(game,"Shared Bark",best.pos)


static func cue(game: Node, name: String, at: Vector3) -> void:
	game.emit_combat_event("proc",name,at,at,.55,BARK,0.0,0)


static func quake_hit(game: Node, player: Dictionary, center: Vector3, targets: Array[int], radius: float, now: int) -> void:
	if targets.is_empty() or prepared_until(game,player,now) == 0:
		return
	var state: Dictionary = player.warden_block
	var profile: Dictionary = player.character
	if state.quake_used or not needs_quake(profile,player):
		return
	state.quake_used = true
	if Progression.learned(profile,"pinning_quake"):
		var count := 0
		for target in targets:
			if (target == -1 and game.boss_kind >= 0) or not game.Traits.valid_target(game,target):
				continue
			load("res://combat_status.gd").root(game,target,now+950)
			count += 1
			if count >= 2:
				break
	if Progression.learned(profile,"living_rhythm"):
		var previous := int(player.get("skill_at",0))
		if previous > now:
			player.skill_at = maxi(now,previous-1250)
			cue(game,"Living Rhythm",player.pos)
	if Progression.learned(profile,"sheltering_quake"):
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


static func ward_circle(game: Node, point: Vector3, radius: float, now: int) -> bool:
	var warded := false
	for ally in game.players.values():
		if in_circle(game,ally,point,radius):
			game.grant_guard(ally,now+1250,1)
			warded = true
	if warded:
		Feedback.release(game,"burst",point,point,radius,BARK)
	return warded
