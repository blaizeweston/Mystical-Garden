extends RefCounted

const Journal = preload("res://diagnostic_journal.gd")
const Preview = preload("res://combat_balance_preview.gd")
const STATE := &"core_strike_mark"


static func place(game: Node, id: int, target: int, cast: Dictionary, now: int) -> void:
	var state: Dictionary = game.Traits.target_state(game, target)
	state[STATE] = {"owner": id, "until": now + int(cast.skill.mark_ms), "life": int(cast.life),
		"damage": Preview.authored_amount(float(cast.skill.mark_damage)), "color": cast.skill.color, "cast": cast.id, "skill": cast.skill.id,
		"root_ms": int(cast.skill.get("mark_root_ms", 0)), "subclass":cast.skill.get("subclass_mark",false)}
	Journal.event("combat", "core_mark_set", {"actor": id, "target": target, "cast_id": cast.id, "skill": cast.skill.id})


static func link_pair(game: Node, id: int, targets: Array[int], cast: Dictionary, now: int) -> void:
	for index in 2:
		var target := targets[index]
		var other := targets[1 - index]
		var state: Dictionary = game.Traits.target_state(game, target)
		state[STATE] = {"owner": id, "life": int(cast.life), "cast": cast.id, "skill": cast.skill.id,
			"until": now + int(cast.skill.mark_ms), "damage": Preview.authored_amount(float(cast.skill.mark_damage)), "color": cast.skill.color,
			"partner": other, "token": -1 if other == -1 else int(game.scouts[other].spawn_token),
			"root_ms": int(cast.skill.get("link_root_ms", 0))}
	var first: Vector3 = game.enemy_position(targets[0])
	var second: Vector3 = game.enemy_position(targets[1])
	game.emit_combat_event("link", cast.skill.id, first, second, .65, Color(cast.skill.color), 0.0, 0)


static func active(game: Node, state: Dictionary, now: int) -> Dictionary:
	var mark: Dictionary = state.get(STATE, {})
	if mark.is_empty():
		return {}
	var owner: Dictionary = game.players.get(mark.owner, {})
	if now >= int(mark.until) or not game.Life.alive(owner) or int(owner.get("lost_health", 0)) != int(mark.life) or (mark.has("partner") and not partner_is_linked(game, mark)):
		state.erase(STATE)
		return {}
	return mark


static func consume(game: Node, player: Dictionary, target: int, now: int) -> float:
	if not game.Life.alive(player):
		return 0
	var state: Dictionary = game.Traits.target_state(game, target)
	var mark := active(game, state, now)
	if mark.is_empty():
		return 0
	state.erase(STATE)
	var point: Vector3 = game.enemy_position(target)
	if mark.has("partner"):
		strike_partner(game, player, mark, point, now)
		return 0
	root_contact(game, target, int(mark.get("root_ms", 0)), now)
	game.emit_combat_event("proc", "mark_break" if mark.get("subclass",false) else "core_mark_burst", point, point, .55, Color(mark.color), 0.0, target)
	Journal.event("combat", "core_mark_burst", {"actor": game.Traits.player_id(game, player), "owner": mark.owner,
		"target": target, "cast_id": mark.cast, "skill": mark.skill, "bonus_damage": mark.damage, "bonus_hp": Preview.effect_hp(float(mark.damage))})
	return float(mark.damage)


static func partner_is_linked(game: Node, mark: Dictionary) -> bool:
	return game.Traits.valid_target(game, int(mark.partner), int(mark.token)) \
		and game.Traits.target_state(game, int(mark.partner)).get(STATE, {}).get("cast") == mark.cast


static func strike_partner(game: Node, player: Dictionary, mark: Dictionary, point: Vector3, now: int) -> void:
	var partner: int = mark.partner
	game.Traits.target_state(game, partner).erase(STATE)
	var at: Vector3 = game.enemy_position(partner)
	if not game.battlefield.clear_line(point, at):
		return
	game.emit_combat_event("link", "crownlink", point, at, .55, Color(mark.color), 0.0, partner)
	game.apply_weapon_hit(player, partner, point, {"damage": mark.damage, "knockback": -.35, "trait_secondary": true, "core_hit": true}, now)
	if game.Traits.valid_target(game, partner):
		root_contact(game, partner, int(mark.root_ms), now)
	Journal.event("combat", "core_link_hit", {"cast_id": mark.cast, "target": partner, "damage": mark.damage})


static func root_contact(game: Node, target: int, duration: int, now: int) -> void:
	if duration <= 0:
		return
	var until := now + duration
	if target == -1:
		game.rooted_until = maxi(game.rooted_until, until)
	else:
		game.scouts[target].rooted_until = maxi(int(game.scouts[target].rooted_until), until)
