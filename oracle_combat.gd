extends RefCounted
const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Progression = preload("res://oracle_connected_tree.gd")
const Omens = preload("res://oracle_omens.gd")
const Balance = preload("res://class_skill_balance.gd")
const Journal = preload("res://diagnostic_journal.gd")
const RITUAL := "oracle_ritual_verdict"
const CHIME := "oracle_chime_prepared"
const MERCIFUL := &"oracle_merciful_chime"


static func clear(player: Dictionary) -> void:
	player.erase(Omens.STATE)
	player.erase(RITUAL)
	player.erase(CHIME)


static func stamp(game: Node, player: Dictionary, until: int = 0) -> Dictionary:
	return {"epoch":game.combat_epoch,"life":player.get("lost_health",0),"until":until}


static func prepared_until(game: Node, player: Dictionary, key: String, now: int) -> int:
	var preparation: Dictionary = player.get(key,{})
	if preparation.is_empty():
		return 0
	var until := int(preparation.until)
	if until==0:
		until=now+60000
	if now < until and int(preparation.epoch) == game.combat_epoch \
			and int(preparation.life) == int(player.get("lost_health",0)) and game.Life.alive(player):
		return until
	return 0


static func nearest_enemy(game: Node, targets: Array[int], center: Vector3) -> int:
	var selected := -2
	var closest := INF
	for target in targets:
		var distance := center.distance_squared_to(game.enemy_position(target))
		if distance < closest or (distance == closest and target < selected):
			selected = target
			closest = distance
	return selected


static func begin_q(game: Node, player: Dictionary, skill: Dictionary, affected: Array[int],
		center: Vector3, now: int) -> Dictionary:
	var bonus := Progression.VERDICT_HP if skill.oracle_nodes.has("verdicts_toll") else 0
	if prepared_until(game,player,RITUAL,now) > 0:
		bonus += Progression.RITUAL_HP
	player.erase(RITUAL)
	return {"target":nearest_enemy(game,affected,center) if bonus > 0 else -2,"hp":bonus}


static func spell_hit(hp: int, secondary := false) -> Dictionary:
	# Native spell damage uses shared mitigation/kill resolution without creating a weapon contact.
	return {"damage":0.0,"native_bonus_hp":hp,"oracle_spell":true,"trait_secondary":secondary,
		"knockback":-.35,"audio_form":"magic"}


static func lowest_recipient(game: Node, allies: Array) -> Dictionary:
	var best := {}
	var ratio := INF
	var best_id := 0
	for ally in allies:
		var health := PlayerVitals.current_hp(ally)/float(PlayerVitals.maximum_hp(ally))
		var id: int = game.Traits.player_id(game,ally)
		if health < ratio or (health == ratio and id < best_id):
			best = ally
			ratio = health
			best_id = id
	return best


static func bestow(game: Node, source: int, skill: Dictionary, cast: int, affected: Array[int],
		allies: Array, now: int) -> void:
	var focus: String = skill.subclass_focus
	var omen: String = Progression.FOCUS_OMENS[focus]
	var duration := Progression.omen_duration(omen,skill.oracle_nodes)
	if omen == Progression.FOREBODING:
		for target in affected:
			if game.Traits.valid_target(game,target):
				Omens.grant(game,source,focus,cast,target,Omens.enemy_body(game,target),omen,duration,now)
	else:
		for ally in allies:
			var id: int = game.Traits.player_id(game,ally)
			Omens.grant(game,source,focus,cast,id,ally,omen,duration,now)


static func after_q(game: Node, id: int, player: Dictionary, skill: Dictionary, cast: int,
		affected: Array[int], allies: Array, now: int) -> void:
	bestow(game,id,skill,cast,affected,allies,now)
	var nodes: Array = skill.oracle_nodes
	if nodes.has("kindled_ward") and not allies.is_empty():
		game.grant_guard(lowest_recipient(game,allies),now+Balance.WARD_MS,1)
	if nodes.has("quiet_ground"):
		for ally in allies:
			ally.slow_until = 0
			var target: int = game.Traits.player_id(game,ally)
			var duration := int(Progression.OMENS[Progression.QUIET_GROUND].ms)
			Omens.grant(game,id,skill.subclass_focus,cast,target,ally,Progression.QUIET_GROUND,duration,now)
	if nodes.size() > 3:
		player[CHIME] = stamp(game,player)


static func begin_chime(game: Node, player: Dictionary, skill: Dictionary, event: RefCounted, now: int) -> Dictionary:
	var ready := prepared_until(game,player,CHIME,now) > 0
	player.erase(CHIME)
	if event != null and skill.oracle_nodes.has("merciful_chime"):
		event.set_meta(MERCIFUL,Progression.MERCIFUL_HP)
	var duration: int = Progression.SHELTER_MS if ready and skill.oracle_nodes.has("shared_shelter") else int(skill.duration)
	return {"prepared":ready,"duration":duration,"cast":event.identity if event != null else game.combat_event_serial}


static func finish_chime(game: Node, id: int, player: Dictionary, skill: Dictionary, chime: Dictionary, now: int) -> void:
	var nodes: Array = skill.oracle_nodes
	var center: Vector3 = player.pos
	if chime.prepared and nodes.has("quick_chime"):
		var timers: Cooldowns.Timers = player[Cooldowns.STATE]
		player[Cooldowns.STATE] = timers.refund(Cooldowns.R, now, Progression.QUICK_MS, Balance.COOLDOWN_MIN_MS)
	if chime.prepared and nodes.has("fates_refrain"):
		var targets: Array[int] = game.skill_area_targets(center,float(skill.radius),center)
		var allies: Array = game.players.values().filter(func(ally):
			return game.Life.alive(ally) and center.distance_to(ally.pos) <= float(skill.radius) \
				and game.battlefield.clear_line(center,ally.pos))
		bestow(game,id,skill,int(chime.cast),targets,allies,now)
	if nodes.has("mercys_chorus"):
		for target in game.players:
			var ally: Dictionary = game.players[target]
			if game.Life.alive(ally) and center.distance_to(ally.pos) <= float(skill.radius) \
					and game.battlefield.clear_line(center,ally.pos):
				var duration := int(Progression.OMENS[Progression.MERCY].ms)
				Omens.grant(game,id,skill.subclass_focus,int(chime.cast),target,ally,Progression.MERCY,duration,now)
	if nodes.has("sentence_of_dawn"):
		for target in game.skill_area_targets(center,Progression.SENTENCE_RADIUS,center):
			var own_curse := Omens.strongest(game,Omens.enemy_body(game,target),Progression.FOREBODING,now,id)
			var hp := Progression.SENTENCE_HP if own_curse.is_empty() else Progression.SENTENCE_HP+Progression.SENTENCE_CURSE_HP
			game.apply_weapon_hit(player,target,center,spell_hit(hp),now)
	if chime.prepared and nodes.has("barbed_chime"):
		var target := nearest_enemy(game,game.skill_area_targets(center,Progression.BARBED_RADIUS,center),center)
		if target != -2:
			var point: Vector3 = game.enemy_position(target)
			game.apply_weapon_hit(player,target,center,spell_hit(Progression.BARBED_HP,true),now)
			game.emit_combat_event("link","subclass_echo",center,point,.5,Color(skill.color),0.0,id)


static func ward_blocked(game: Node, player: Dictionary, id: int, event: RefCounted, direct_attack: bool) -> void:
	if event.has_meta(MERCIFUL) and Omens.direct_context(game,direct_attack) \
			and event.take_response("oracle_merciful_chime/%d"%id):
		var restored: float = game.Life.Sustain.restore(game,player,int(event.get_meta(MERCIFUL)),"merciful_chime")
		Journal.event("combat","oracle_chime_block",{"source":event.actor,"cast":event.identity,"recipient":id,"restored_hp":restored})


static func ordinary_contact(game: Node, player: Dictionary, target: int, at: Vector3,
		stats: Dictionary, now: int) -> void:
	var action: RefCounted = stats.get("cr02_action")
	if action == null or action.epoch != game.combat_epoch or now >= action.expires_at \
			or action.source not in ["form","native_weapon"] or stats.get("trait_secondary",false) \
			or stats.get("core_hit",false):
		return
	var target_token := "leader" if target == -1 else str(game.scouts[target].get("spawn_token",target))
	if not action.take_response("oracle_contact/"+target_token):
		return
	if int(player.frame) == Progression.CLASS_ID and player.pos.distance_to(at) <= Progression.RITUAL_RADIUS \
			and Progression.TREE.eligible(player.character) and Progression.TREE.path(player.character).has("ritual_verdict"):
		player[RITUAL] = stamp(game,player,now+Progression.RITUAL_MS)
	Omens.guide_contact(game,player,target,now)
