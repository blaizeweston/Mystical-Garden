extends RefCounted

const WeaponActions = preload("res://player_weapon_actions.gd")

const Participation = preload("res://expedition_participation.gd")

const ActionIdentity = preload("res://network_action_identity.gd")
const Session = preload("res://network_session.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Rules = preload("res://core_skill_rules.gd")
const Footprint = preload("res://core_footprint.gd")
const Lance = preload("res://core_lance.gd")
const Mouse = preload("res://mouse_combat.gd")
const Journal = preload("res://diagnostic_journal.gd")
const PREFIX := "core_cast:"


static func local_aim(game: Node, player: Dictionary) -> Dictionary:
	var offset := Mouse.ground_offset(game.stage.camera, game.get_viewport().get_mouse_position(), game.stage.WILD_OFFSET + player.pos)
	var distance := minf(20.0, offset.length())
	var aim := offset.normalized()
	if DisplayServer.get_name() == "headless" or distance < .1:
		var facing: Vector3 = player.get("facing", Vector3.FORWARD)
		aim = Vector2(facing.x, facing.z)
		distance = 0.0 if DisplayServer.get_name() == "headless" else .01
	if aim.length_squared() < .01:
		aim = Vector2(0, -1)
	return {"direction": aim, "distance": distance}


static func request(game: Node, player: Dictionary, aim: Vector2, distance: float = 0.0) -> String:
	var stamp := cast_key(game,player)
	return PREFIX + "%s:%s:%s:%s" % [stamp, aim.x, aim.y, distance] if not stamp.is_empty() else ""


static func cast_key(game: Node, player: Dictionary) -> String:
	return ActionIdentity.current_stamp(game,player)


static func command(game: Node, id: int, player: Dictionary, action: String) -> void:
	if not game.multiplayer.is_server() or not game.Life.alive(player) or not game.network_session.ready(id) or Session.peer_for(player) != id:
		return
	var resolved = game.combat_build(player)
	var refusal: String = resolved.refusal("core")
	if not refusal.is_empty():
		game.tell(id,refusal)
		return
	var args := action.split(":", true, 5)
	var stamp := cast_key(game,player)
	if stamp.is_empty() or args.size() != 5 or args[1] != stamp or not args[2].is_valid_float() or not args[3].is_valid_float() or not args[4].is_valid_float():
		return
	var aim := Vector2(float(args[2]), float(args[3]))
	if not aim.is_finite() or absf(aim.x) > 1.001 or absf(aim.y) > 1.001 or aim.length_squared() < .01:
		return
	var distance := float(args[4])
	if not is_finite(distance) or distance < 0.0 or distance > 20.001:
		return
	var now := preload("res://combat_clock.gd").now()
	var forward := Vector3(aim.x, 0, aim.y).normalized()
	var lines: Dictionary = game.effect_timeline.core_records()
	if lines.has(id):
		return
	if now < int(player.get("core_ready_at", 0)) or now < int(player.get("cast_until", 0)) or now < int(player.get("core_cast_until", 0)):
		return
	var skill: Dictionary = resolved.core_skill()
	if skill.is_empty() or (game.encounter_cleared() and skill.get("affinity_family") != "vital"):
		return
	var step: bool = skill.get("affinity_family")=="spirit"
	var line := aim_cast(game.battlefield, player.pos, forward, skill, distance)
	if step:
		var landing := preload("res://spirit_affinity.gd").step(game,id,forward)
		line = {"center":landing,"forward":forward} if landing.distance_to(player.pos)>=preload("res://spirit_affinity.gd").MIN_STEP else {}
	if line.is_empty():
		game.tell(id, "%s needs clear ground in that direction." % skill.name)
		return
	var weapon: Dictionary = game.WeaponMotion.profile(skill.weapon_form)
	var ground: bool = step or skill.delivery == "ground" or skill.get("footprint") == "wave" or skill.get("affinity_family") in ["water","vital","wood"]
	var blade_cast: bool = skill.weapon_form == "blade"
	var duration := 550 if blade_cast else roundi(float(weapon.duration) * 1000.0)
	var release_ms := 245 if blade_cast else roundi(float(weapon.release) * duration)
	var origin: Vector3 = player.pos
	if not ground:
		origin += forward * float(weapon.muzzle_forward) + forward.cross(Vector3.UP) * float(weapon.muzzle_side)
		origin.y += float(weapon.height)
	var flight_ms := 0
	if skill.mechanic == "swept_projectile":
		flight_ms = maxi(1, roundi(player.pos.distance_to(line.center) / float(skill.speed) * 1000.0))
	elif not ground:
		flight_ms = maxi(110, roundi(origin.distance_to(line.center) / 17.0 * 1000.0))
	var lifetime := int(skill.get("lifetime_ms", 1000))
	game.combat_event_serial += 1
	line.merge({
		"id": "core:" + str(game.combat_event_serial), "epoch": game.participation.epoch(),
		"skill": skill, "owner": id,"binding":game.network_session.binding(id), "life": PlayerLifecycle.generation(player), "release": now + release_ms,
		"armed": now + release_ms + flight_ms, "expires": now + release_ms + flight_ms + lifetime,
		"flight_ms": flight_ms, "released": false, "grown": false, "next_hit": {},
		"origin": origin, "cast_origin": player.pos, "previous": {},
	})
	line.affinity_action = preload("res://combat_action_events.gd").begin(game,id,"core",skill.material,
		skill.material.potency_profile.values,["core_action"],0x7fffffffffffffff)
	if not step:
		if not game.effect_timeline.begin_core(id,line):return
	player.core_ready_at = now + int(skill.cooldown_ms)
	player.core_cast_until = now + duration
	player.facing = forward
	player[WeaponActions.STATE] = player[WeaponActions.STATE].core_pose(now,duration,line.center.distance_to(player.pos),forward,weapon.clip,weapon.delivery,float(weapon.span),not blade_cast)
	player.skill_fx_seq = int(player.get("skill_fx_seq", 0)) + 1
	player.cast_until = now + duration if blade_cast else 0
	if step:
		preload("res://spirit_affinity.gd").core_step(game,line,player,now)
	var modifiers: Array = skill.modifiers.map(func(modifier): return modifier.id)
	Journal.event("combat", "core_cast", {"actor": id, "skill": skill.id, "cast_id": line.id, "delivery": skill.delivery,
		"weapon": skill.weapon_form, "variant": skill.get("variant_name", ""), "floor": game.participation.floor(), "modifiers": modifiers})


static func owner_state(player: Dictionary, now: int, skill: Dictionary) -> Dictionary:
	if not Participation.is_wild(player):
		return {}
	if skill.is_empty():
		return {}
	return {
		"name": skill.name, "icon": skill.icon, "tooltip": skill.tooltip,
		"remaining": maxf(0, (int(player.get("core_ready_at", 0)) - now) / 1000.0),
	}


static func hud_state(game: Node, player: Dictionary) -> Dictionary:
	if not Participation.is_wild(player):
		return {}
	var now := preload("res://combat_clock.gd").now()
	if game.multiplayer.is_server():
		return owner_state(player, now, game.combat_build(player).core_skill())
	if game.guest_replication.details_key() != str([game.participation.route(), game.participation.floor(), game.participation.seed()]):
		return {}
	var state: Dictionary = player.get("core_state", {}).duplicate()
	if not state.is_empty():
		var elapsed: float = game.guest_replication.details_age_ms(now) / 1000.0
		state.remaining = maxf(0, float(state.remaining) - elapsed)
	return state


static func preview(game: Node, player: Dictionary, field: RefCounted, forward: Vector3, distance: float) -> Dictionary:
	var skill: Dictionary = game.combat_build(player).core_skill()
	if skill.is_empty():
		return {}
	var origin: Vector3 = player.pos
	var state := hud_state(game, player)
	var shapes: Array = []
	if float(skill.range) > 0.0:
		shapes.append({"kind":"range", "at":origin, "radius":skill.range})
	if skill.affinity_family == "spirit":
		var end: Vector3 = field.dash(origin,origin+forward*float(skill.range))
		var can_step := origin.distance_to(end)>=preload("res://spirit_affinity.gd").MIN_STEP
		return {"shapes":[{"kind":"travel","from":origin,"to":end}],"color":skill.color,
			"valid":can_step and float(state.get("remaining",INF))<=0.0}
	var cast := aim_cast(field, origin, forward, skill, distance)
	if not cast.is_empty():
		if skill.mechanic == "swept_projectile":
			shapes.append({"kind":"capsule", "from":cast.from, "to":cast.to, "width":skill.radius})
		else:
			cast.skill = skill
			shapes.append_array(Footprint.build(field,cast,origin))
	return {"shapes":shapes, "color":skill.color,
		"valid":not cast.is_empty() and float(state.get("remaining",INF))<=0.0}


static func aim_cast(field: RefCounted, origin: Vector3, forward: Vector3, skill: Dictionary, distance: float = 0.0) -> Dictionary:
	if skill.mechanic == "swept_projectile":
		return Lance.placement(field,origin,forward,skill)
	if skill.get("targeting") == "self":
		return {"center":origin,"forward":forward} if not field.occupied(origin) else {}
	var reach := clampf(distance,.01,float(skill.range)) if distance>0.0 else float(skill.range)
	var center: Vector3 = field.dash(origin,origin+forward*reach)
	return {"center":center,"forward":forward} if origin.distance_to(center)+.0001>=.01 else {}


static func reset(game: Node) -> void:
	game.effect_timeline.clear_cores()


static func tick(game: Node, now: int) -> void:
	if game.effect_timeline.core_records().is_empty():
		return
	var lines: Dictionary = game.effect_timeline.core_records()
	var before:=lines.duplicate(true)
	if game.encounter_cleared():
		for id in lines.keys():
			var line: Dictionary = lines[id]
			if line.skill.get("affinity_family") == "vital":
				continue
			lines.erase(id)
		if lines.is_empty():
			reset(game)
			return
	for id in lines.keys():
		var line: Dictionary = lines[id]
		var player: Dictionary = game.players.get(id, {})
		if int(line.epoch) != game.participation.epoch() or (line.has("binding") and not game.network_session.matches(int(id),int(line.binding))) or not game.Life.alive(player) or not PlayerLifecycle.matches(player,int(line.life)) or (now >= int(line.expires) and not (line.grown and line.skill.get("affinity_family") in ["fire","water","void"])):
			if line.has("flight_event") and now < int(line.armed):
				game.emit_combat_event("projectile_end", str(line.flight_event), line.origin, line.origin, .15, Color.WHITE, 0.0, 0)
			lines.erase(id)
			continue
		if now >= int(line.release) and not line.released:
			line.released = true
			preload("res://event_audio.gd").emit(game,"combat_cast",player.pos)
			if line.skill.mechanic == "swept_projectile":
				Lance.release(game, line)
			elif int(line.flight_ms) > 0:
				var from: Vector3 = line.origin
				var to: Vector3 = line.center + Vector3.UP * .08
				var radius := .14 if line.skill.delivery == "seed" else .09
				game.emit_combat_event("projectile", line.skill.projectile, from, to, line.flight_ms / 1000.0, Color(line.skill.color),
					from.distance_to(to), 0, {"projectile_radius": radius, "height": 0.0})
			if int(line.flight_ms) > 0:
				line.flight_event = game.combat_event_serial
			if line.skill.get("footprint") == "wave":
				var launch: Vector3 = player.pos
				var reach: float = line.cast_origin.distance_to(line.center)
				line.cast_origin = launch
				line.center = game.battlefield.dash(launch, launch + Vector3(line.forward) * reach)
		if line.skill.mechanic == "swept_projectile":
			if Lance.advance(game, id, player, line, now):
				lines.erase(id)
			continue
		if now < int(line.armed):
			continue
		if not line.grown and not game.battlefield.clear_line(line.cast_origin, line.center):
			lines.erase(id)
			continue
		match line.skill.get("affinity_family", ""):
			"frost":
				if preload("res://frost_combat.gd").bloom(game,line,now): lines.erase(id)
				continue
			"fire":
				if preload("res://fire_combat.gd").field(game,line,now): lines.erase(id)
				continue
			"water":
				if preload("res://water_combat.gd").wave(game,line,player,now): lines.erase(id)
				continue
			"thorn":
				preload("res://thorn_affinity.gd").release(game,line,now)
				lines.erase(id)
				continue
			"void":
				if preload("res://void_affinity.gd").gather(game,line,now): lines.erase(id)
				continue
			"storm":
				preload("res://storm_affinity.gd").ground_contact(game,line,player,now)
				lines.erase(id)
				continue
			"wood":
				preload("res://wood_affinity.gd").bloom(game,line,player,now)
				lines.erase(id)
				continue
			"vital":
				preload("res://vital_combat.gd").bloom(game,line,player,now)
				lines.erase(id)
				continue
		# All admitted casts have an explicit implemented affinity family.
		lines.erase(id)
	if lines.is_empty():
		reset(game)
	game.effect_timeline.commit_cores(before,lines)


static func hints(game: Node) -> Array:
	var result := []
	for line in game.effect_timeline.core_records().values():
		if not line.grown:
			continue
		var elapsed: int = preload("res://affinity_time.gd").now(game)
		if line.skill.affinity_family == "fire":
			var hint := field_hint(line.id,line.center,maxf(0.0,(int(line.field_until)-elapsed)/1000.0),line.skill)
			hint.core_shapes = Footprint.encode(line.shapes)
			hint.core_phase = preload("res://fire_combat.gd").FIELD_MS - maxi(0,int(line.field_until)-elapsed)
			result.append(hint)
		elif line.skill.affinity_family == "void":
			result.append(field_hint(line.id,line.center,maxf(0.0,(int(line.well_until)-elapsed)/1000.0),line.skill))
	return result


static func field_hint(id: String, center: Vector3, remaining: float, skill: Dictionary) -> Dictionary:
	var point := [center.x,0,center.z]
	return {"id":id,"role":"core_field","from":point,"to":point,"radius":skill.radius,
		"remaining":remaining,"color":skill.color,"skill":skill.id,"decoy":false}
