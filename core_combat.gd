extends RefCounted

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const Rules = preload("res://core_skill_rules.gd")
const Effects = preload("res://core_skill_effects.gd")
const Footprint = preload("res://core_footprint.gd")
const Variants = preload("res://core_weapon_variants.gd")
const Lance = preload("res://core_lance.gd")
const Anchor = preload("res://core_anchor_beam.gd")
const Upgrades = preload("res://run_upgrade_catalog.gd")
const Status = preload("res://combat_status.gd")
const Mouse = preload("res://mouse_combat.gd")
const Journal = preload("res://diagnostic_journal.gd")
const THORN_COLOR := Color("#baf187")
const Thorn = preload("res://thorn_adaptation.gd")
const STATE := Thorn.CORE_STATE
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
	return PREFIX + "%s:%s:%s:%s" % [cast_key(game, player), aim.x, aim.y, distance]


static func cast_key(game: Node, player: Dictionary) -> String:
	# Preserve the injury HP suffix in the host and guest request key.
	return "%s/%d" % [game.net_motion.world_key(game, player), int(player.get("lost_health", 0))]


static func command(game: Node, id: int, player: Dictionary, action: String) -> void:
	if not game.multiplayer.is_server() or not game.Life.alive(player) or not player.get("profile_ready", false):
		return
	if preload("res://combat_ruleset.gd").active(game):
		var builds = preload("res://affinity_build.gd")
		var refusal := builds.refusal(builds.for_player(player),"core")
		if not refusal.is_empty():
			game.tell(id,refusal)
			return
	var args := action.split(":", true, 5)
	if args.size() != 5 or args[1] != cast_key(game, player) or not args[2].is_valid_float() or not args[3].is_valid_float() or not args[4].is_valid_float():
		return
	var aim := Vector2(float(args[2]), float(args[3]))
	if not aim.is_finite() or absf(aim.x) > 1.001 or absf(aim.y) > 1.001 or aim.length_squared() < .01:
		return
	var distance := float(args[4])
	if not is_finite(distance) or distance < 0.0 or distance > 20.001:
		return
	var now := Time.get_ticks_msec()
	var forward := Vector3(aim.x, 0, aim.y).normalized()
	var lines: Dictionary = game.get_meta(STATE, {})
	if lines.has(id):
		return
	if now < int(player.get("core_ready_at", 0)) or now < int(player.get("cast_until", 0)) or now < int(player.get("core_cast_until", 0)):
		return
	var skill := equipped(player)
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
		"id": "core:" + str(game.combat_event_serial), "epoch": game.combat_epoch,
		"skill": skill, "owner": id, "life": PlayerLifecycle.generation(player), "release": now + release_ms,
		"armed": now + release_ms + flight_ms, "expires": now + release_ms + flight_ms + lifetime,
		"flight_ms": flight_ms, "released": false, "grown": false, "next_hit": {},
		"origin": origin, "cast_origin": player.pos, "previous": {}, "behaviors": Upgrades.core_behaviors(player, skill.id),
	})
	if skill.has("affinity_family"):
		line.affinity_action = preload("res://combat_action_events.gd").begin(game,id,"core",skill.material,
			skill.material.potency_profile.values,["core_action"],0x7fffffffffffffff)
	if not step:
		lines[id] = line
		game.set_meta(STATE, lines)
	player.core_ready_at = now + int(skill.cooldown_ms)
	player.core_cast_until = now + duration
	player.facing = forward
	player.attack_direction = forward
	player.attack_reach = line.center.distance_to(player.pos)
	player.attack_span = float(weapon.span)
	player.attack_delivery = weapon.delivery
	player.attack_combo = int(player.get("attack_combo", 0)) + 1
	player.skill_fx_seq = int(player.get("skill_fx_seq", 0)) + 1
	player.attack_clip = weapon.clip
	player.attack_duration = duration
	player.attack_until = 0 if blade_cast else now + duration
	player.cast_until = now + duration if blade_cast else 0
	player.strike_at = maxi(int(player.get("strike_at", 0)), int(player.core_cast_until))
	if step:
		preload("res://spirit_affinity.gd").core_step(game,line,player,now)
	var modifiers: Array = skill.modifiers.map(func(modifier): return modifier.id)
	Journal.event("combat", "core_cast", {"actor": id, "skill": skill.id, "cast_id": line.id, "delivery": skill.delivery,
		"weapon": skill.weapon_form, "variant": skill.get("variant_name", ""), "floor": game.encounter_number, "modifiers": modifiers, "behaviors": line.behaviors})


static func equipped(player: Dictionary) -> Dictionary:
	if preload("res://combat_ruleset.gd").uses_affinities(player):
		var builds = preload("res://affinity_build.gd")
		return builds.core_skill(builds.for_player(player))
	var skill: Dictionary = Rules.player_build(player).skill
	Upgrades.tune_core(player, skill)
	return skill


static func owner_state(player: Dictionary, now: int, _cast: Dictionary = {}) -> Dictionary:
	if not player.get("wild", false):
		return {}
	var skill := equipped(player)
	if skill.is_empty():
		return {}
	return {
		"name": skill.name, "icon": skill.icon, "tooltip": skill.tooltip if skill.has("affinity_family") else Rules.describe(skill, Upgrades.core_card_lines(player, skill.id)),
		"remaining": maxf(0, (int(player.get("core_ready_at", 0)) - now) / 1000.0),
	}


static func hud_state(game: Node, player: Dictionary) -> Dictionary:
	if not player.get("wild", false):
		return {}
	var now := Time.get_ticks_msec()
	if game.multiplayer.is_server():
		return owner_state(player, now, game.get_meta(STATE, {}).get(game.HOST, {}))
	if game.client_details_key != str([game.destination, game.encounter_number, game.map_seed]):
		return {}
	var state: Dictionary = player.get("core_state", {}).duplicate()
	if not state.is_empty():
		var elapsed := (now - int(game.get_meta("core_details_at", now))) / 1000.0
		state.remaining = maxf(0, float(state.remaining) - elapsed)
	return state


static func preview(game: Node, player: Dictionary, field: RefCounted, forward: Vector3, distance: float) -> Dictionary:
	var skill := equipped(player) if game.multiplayer.is_server() else Dictionary(player.get("weapon_stats", {})).get("core_build", {}).get("skill", {}) as Dictionary
	if not game.multiplayer.is_server() and preload("res://combat_ruleset.gd").active(game):
		skill = preload("res://affinity_build.gd").core_skill(player.get("weapon_stats",{}).get("affinity_build",{}))
	if skill.is_empty():
		return {}
	var origin: Vector3 = player.pos
	var state := hud_state(game, player)
	var reach: float = skill.range
	var shapes: Array = []
	if reach > 0.0:
		shapes.append({"kind": "range", "at": origin, "radius": reach})
	var cast := aim_cast(field, origin, forward, skill, distance)
	var valid := not cast.is_empty() and float(state.get("remaining", INF)) <= 0.0
	if skill.get("affinity_family")=="spirit":
		var end: Vector3 = field.dash(origin,origin+forward*float(skill.range))
		var can_step := origin.distance_to(end)>=preload("res://spirit_affinity.gd").MIN_STEP
		return {"shapes":[{"kind":"travel","from":origin,"to":end}],"color":skill.color,
			"valid":can_step and float(state.get("remaining",INF))<=0.0}
	if not cast.is_empty():
		match skill.mechanic:
			"ground_sequence":
				if skill.get("footprint") == "wave":
					shapes.append({"kind": "capsule", "from": origin, "to": cast.center, "width": Effects.wave_width(skill)})
				else:
					cast.skill = skill
					var contact_shapes := Footprint.build(field, cast, origin)
					if contact_shapes.is_empty() and skill.get("footprint") == "reflection":
						contact_shapes.append(Footprint.area(cast.center, skill.radius))
						if cast.has("reflection"):
							contact_shapes.append(Footprint.area(cast.reflection, skill.radius))
					shapes.append_array(contact_shapes)
					if skill.id in ["eclipse_maw", "worldbloom"]:
						shapes.append_array(Footprint.build(field, cast, origin, 1))
					if skill.id == "gravity_well" and skill.has("inner_root_ms"):
						shapes.append({"kind": "range", "at": cast.center, "radius": float(skill.radius) * .28})
					if skill.id == "grave_lantern":
						shapes.append({"kind": "range", "at": cast.center, "radius": skill.burst_radius})
					if skill.id == "moon_snare":
						shapes = shapes.filter(func(shape): return shape.kind != "capsule")
						shapes.append({"kind": "crescent_guide", "segments": contact_shapes})
					if skill.id == "crownlink":
						shapes.append_array(crown_preview(game, field, contact_shapes, cast.center))
				var landing := Variants.travel(field, origin, cast.center, forward, skill)
				if not origin.is_equal_approx(landing):
					shapes.append({"kind": "travel", "from": origin, "to": landing})
			"line_trap", "swept_projectile":
				shapes.append({"kind": "capsule", "from": cast.from, "to": cast.to, "width": skill.radius})
			"ground_burst":
				shapes.append({"kind": "area", "at": cast.center, "radius": skill.radius})
			"anchor_beam":
				shapes.append({"kind": "point", "at": cast.center, "radius": .45})
				shapes.append({"kind": "capsule", "from": cast.center, "to": Anchor.endpoint(field, {"center": cast.center, "skill": skill}, forward), "width": skill.radius})
	return {"shapes": shapes, "color": skill.color, "valid": valid}


static func aim_cast(field: RefCounted, origin: Vector3, forward: Vector3, skill: Dictionary, distance: float = 0.0) -> Dictionary:
	match skill.mechanic:
		"line_trap":
			return placement(field, origin, forward, skill, distance)
		"swept_projectile":
			return Lance.placement(field, origin, forward, skill)
		"ground_burst", "anchor_beam", "ground_sequence":
			if skill.get("targeting") == "self":
				return {"center": origin, "forward": forward} if not field.occupied(origin) else {}
			var minimum := .85 if skill.mechanic == "anchor_beam" or skill.get("movement") == "approach" else .01
			var reach := clampf(distance, minimum, float(skill.range)) if distance > 0.0 else float(skill.range)
			var center: Vector3 = field.dash(origin, origin + forward * reach)
			if origin.distance_to(center) + .0001 < minimum:
				return {}
			var cast := {"center": center, "forward": forward}
			if skill.get("footprint") == "reflection":
				var mirror := origin * 2.0 - center
				if field.clear_line(origin, mirror) and not field.occupied(mirror):
					cast.reflection = mirror
			return cast
	return {}


static func placement(field: RefCounted, origin: Vector3, forward: Vector3, skill: Dictionary, distance: float = 0.0) -> Dictionary:
	var side := forward.cross(Vector3.UP)
	var radius: float = skill.radius
	var reach := minf(distance, float(skill.range)) if distance > 0.0 else float(skill.range)
	var center: Vector3 = field.dash(origin, origin + forward * reach)
	while (center - origin).dot(forward) >= -.0001:
		var from := center - side * float(skill.half_length)
		var to := center + side * float(skill.half_length)
		if field.clear_line(from, to, radius):
			return {"from": from, "to": to, "center": center}
		center -= forward * .25
	return {}


static func reset(game: Node) -> void:
	if game.has_meta(STATE):
		game.remove_meta(STATE)


static func tick(game: Node, now: int) -> void:
	if not game.has_meta(STATE):
		return
	var lines: Dictionary = game.get_meta(STATE)
	if game.encounter_cleared():
		for id in lines.keys():
			var line: Dictionary = lines[id]
			if line.skill.get("affinity_family") == "vital":
				continue
			var owner: Dictionary = game.players.get(id, {})
			if line.grown and line.skill.has("death_window_ms") and int(line.epoch) == game.combat_epoch and game.Life.alive(owner) and PlayerLifecycle.matches(owner,int(line.life)) and now < int(line.expires):
				Effects.detonate_at_death(game, id, owner, line, now)
			lines.erase(id)
		if lines.is_empty():
			reset(game)
			return
	for id in lines.keys():
		var line: Dictionary = lines[id]
		var player: Dictionary = game.players.get(id, {})
		if int(line.epoch) != game.combat_epoch or not game.Life.alive(player) or not PlayerLifecycle.matches(player,int(line.life)) or (now >= int(line.expires) and not (line.grown and line.skill.get("affinity_family") in ["fire","water","void"])):
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
		if line.skill.mechanic == "ground_sequence":
			if Effects.sequence(game, id, player, line, now):
				lines.erase(id)
			continue
		if line.skill.mechanic == "ground_burst":
			lantern_burst(game, id, line, now)
			lines.erase(id)
			continue
		if line.skill.mechanic == "anchor_beam":
			if not line.grown:
				line.grown = true
				line.fires_at = now + int(line.skill.lifetime_ms)
				line.expires = int(line.fires_at) + 1500
				game.emit_combat_event("ability", line.skill.id, line.center, line.center, .5, Color(line.skill.color), .8, id)
			if now >= int(line.fires_at):
				var end := Anchor.endpoint(game.battlefield, line, Anchor.direction(game, id, line, now))
				Anchor.fire(game, id, line, end, now)
				lines.erase(id)
			continue
		if not line.grown:
			if not game.battlefield.clear_line(line.from, line.to, line.skill.radius):
				lines.erase(id)
				continue
			line.grown = true
			line.grown_at = now
			Thorn.armed(game, id, line)
			game.emit_combat_event("ability", line.skill.id, line.center, line.center, .5, THORN_COLOR, 1.0, id)
		var current := targets(game)
		for target in current:
			var actor: Dictionary = current[target]
			var previous: Dictionary = line.previous.get(target, {})
			var point: Vector3 = actor.pos
			var before: Vector3 = previous.get("pos", point) if previous.get("token", -1) == actor.token else point
			var trip := contact(game.battlefield, line, before, point)
			if trip == Vector3.INF:
				continue
			var token: String = preload("res://weapon_contact.gd").token(game, target)
			if now >= int(line.next_hit.get(token, 0)):
				if not line.next_hit.has(token):
					Thorn.tripped(game, id, line, target, before, point)
				line.next_hit[token] = now + int(line.skill.interval_ms)
				trigger_thorn(game, id, target, trip, now, "crossing")
			if game.encounter_cleared():
				break
		line.previous = current
	if lines.is_empty():
		reset(game)


static func lantern_burst(game: Node, id: int, cast: Dictionary, now: int) -> void:
	var center: Vector3 = cast.center
	var radius: float = cast.skill.radius
	var targets_hit: Array[int] = []
	if cast.skill.has("area_guard_ms"):
		Effects.affect_allies(game, center, radius, cast.skill, {"guard_ms": cast.skill.area_guard_ms}, now)
	var until := now + int(cast.skill.stagger_ms)
	var candidates := preload("res://weapon_contact.gd").candidates(game, center)
	for target in candidates:
		if game.enemy_position(target).distance_to(center) > radius:
			break
		if winding_or_boss(game, target) or not game.battlefield.clear_line(center, game.enemy_position(target)):
			continue
		if target == -1:
			game.enemy_stagger_until = maxi(game.enemy_stagger_until, until)
		else:
			game.scouts[target].stagger_until = maxi(int(game.scouts[target].stagger_until), until)
		targets_hit.append(target)
		if targets_hit.size() >= int(cast.skill.targets):
			break
	game.emit_combat_event("ability", cast.skill.id, center, center, .55, Color(cast.skill.color), radius, id)
	Journal.event("combat", "core_burst", {"actor": id, "skill": cast.skill.id, "cast_id": cast.id, "targets": targets_hit})


static func winding_or_boss(game: Node, target: int) -> bool:
	return game.boss_kind >= 0 or game.enemy_winding_up if target == -1 else int(game.scouts[target].get("windup", 0)) > 0


static func quake(game: Node, id: int, origin: Vector3, radius: float, now: int) -> void:
	var line: Dictionary = game.get_meta(STATE, {}).get(id, {})
	if line.is_empty() or line.skill.mechanic != "line_trap" or not line.grown or int(line.epoch) != game.combat_epoch or now >= int(line.expires):
		return
	if not PlayerLifecycle.matches(game.players[id],int(line.life)) or line.get("quake_used", false):
		return
	var reach := float(line.skill.get("quake_reach", 0.0))
	if reach <= 0:
		return
	var anchor := Geometry3D.get_closest_point_to_segment(origin, line.from, line.to)
	if origin.distance_to(anchor) > radius or not game.battlefield.clear_line(origin, anchor):
		return
	var best := -2
	var at := Vector3.ZERO
	var nearest := reach
	for target in targets(game):
		var point: Vector3 = game.enemy_position(target)
		var base := Geometry3D.get_closest_point_to_segment(point, line.from, line.to)
		var distance := point.distance_to(base)
		if distance <= nearest and game.battlefield.clear_line(base, point):
			best = target
			at = base
			nearest = distance
	if best != -2:
		trigger_thorn(game, id, best, at, now, "quake")


static func trigger_thorn(game: Node, id: int, target: int, trip: Vector3, now: int, trigger: String) -> void:
	var line: Dictionary = game.get_meta(STATE, {})[id]
	var player: Dictionary = game.players[id]
	var first: bool = trigger == "crossing" and not line.get("first_contact", false)
	if first:
		line.first_contact = true
	var point: Vector3 = game.enemy_position(target)
	if first or trigger == "quake":
		point = pull_to_line(game, target, line)
	if trigger == "quake":
		Status.root(game, target, now + int(line.skill.root_ms))
	else:
		Effects.damage(game, player, target, trip, float(line.skill.damage), now)
	var fork := -2
	if first and "thorn_fork" in line.behaviors:
		var other: int = game.Traits.other_target(game, target, point)
		if other != -2 and point.distance_to(game.enemy_position(other)) <= 2.2:
			fork = other
			Status.root(game, fork, now + int(line.skill.root_ms))
			game.emit_combat_event("link", "Forking Roots", point, game.enemy_position(fork), .5, THORN_COLOR, 0.0, fork)
			game.emit_combat_event("proc", "Forking Roots", point, game.enemy_position(fork), .55, THORN_COLOR, 0.0, fork)
	var refunded := 0
	if first and "thorn_rebate" in line.behaviors and now - int(line.grown_at) <= 2000:
		var ready := int(player.core_ready_at)
		player.core_ready_at = maxi(now, ready - Effects.Balance.THORN_REFUND_MS)
		refunded = ready - int(player.core_ready_at)
		game.emit_combat_event("proc", "Quickroot", point, player.pos, .55, THORN_COLOR, 0.0, id)
	if trigger == "quake":
		line.quake_used = true
		line.next_hit[preload("res://weapon_contact.gd").token(game, target)] = now + int(line.skill.interval_ms)
		game.emit_combat_event("link", "Thorn lash", trip, point, .45, THORN_COLOR, 0.0, target)
		preload("res://warden_combat.gd").thorn_tripped(game,game.players[id],trip,now)
	if first or trigger == "quake":
		game.emit_combat_event("proc", "Thorns tripped", trip, point, .55, THORN_COLOR, 0.0, target)
	Journal.event("combat", "core_trip", {"actor": id, "skill": line.skill.id, "cast_id": line.id,
		"target": target, "target_token": 0 if target == -1 else game.scouts[target].get("spawn_token", 0), "trigger": trigger, "fork_target": fork, "refund_ms": refunded})


static func pull_to_line(game: Node, target: int, line: Dictionary) -> Vector3:
	var point: Vector3 = game.enemy_position(target)
	var pull := float(line.skill.get("trip_pull", 0))
	if pull <= 0.0 or winding_or_boss(game, target):
		return point
	var drawn: Vector3 = game.battlefield.dash(point, point.move_toward(line.center, pull))
	if point.distance_squared_to(drawn) < .0025:
		return point
	if target == -1:
		game.enemy_pos = drawn
	else:
		game.scouts[target].pos = drawn
	game.emit_combat_event("link", "Hooked Thorns", point, drawn, .4, THORN_COLOR, 0.0, target)
	game.emit_combat_event("proc", "Hooked Thorns", point, drawn, .45, THORN_COLOR, 0.0, target)
	Journal.event("combat", "core_graft_pull", {"cast_id": line.id, "target": target, "distance": point.distance_to(drawn)})
	return drawn


static func targets(game: Node) -> Dictionary:
	var result := {}
	if game.enemy_hp > 0:
		result[-1] = {"pos": game.enemy_pos, "token": 0}
	for index in game.scouts.size():
		var scout: Dictionary = game.scouts[index]
		if scout.hp > 0:
			result[index] = {"pos": scout.pos, "token": scout.get("spawn_token", 0)}
	return result


static func contact(field: RefCounted, line: Dictionary, before: Vector3, point: Vector3) -> Vector3:
	var limit := float(line.skill.radius)
	var endpoint := Geometry3D.get_closest_point_to_segment(point, line.from, line.to)
	if point.distance_to(endpoint) <= limit:
		return endpoint
	if before.is_equal_approx(point) or not field.clear_line(before, point):
		return Vector3.INF
	var closest := Geometry3D.get_closest_points_between_segments(before, point, line.from, line.to)
	return closest[1] if closest[0].distance_to(closest[1]) <= limit else Vector3.INF


static func hints(game: Node) -> Array:
	var result := []
	for line in game.get_meta(STATE, {}).values():
		if not line.grown:
			continue
		if line.skill.get("affinity_family") == "fire":
			var elapsed: int = preload("res://affinity_time.gd").now(game)
			var hint := Effects.field_hint(line.id,line.center,maxf(0.0,(int(line.field_until)-elapsed)/1000.0),line.skill)
			hint.core_shapes = Footprint.encode(line.shapes)
			hint.core_phase = preload("res://fire_combat.gd").FIELD_MS - maxi(0,int(line.field_until)-elapsed)
			result.append(hint)
		elif line.skill.get("affinity_family")=="void":
			var elapsed:=preload("res://affinity_time.gd").now(game)
			result.append(Effects.field_hint(line.id,line.center,maxf(0.0,(int(line.well_until)-elapsed)/1000.0),line.skill))
		elif not line.skill.has("affinity_family") and line.skill.mechanic == "ground_sequence":
			result.append_array(Effects.hints(game, line, Time.get_ticks_msec()))
		elif line.skill.has("affinity_family"):
			continue
		elif line.skill.mechanic == "anchor_beam":
			var center: Vector3 = line.center
			var at := [center.x, 0, center.z]
			var owner: int = int(line.get("owner", 0))
			var now := Time.get_ticks_msec()
			var end := Anchor.endpoint(game.battlefield, line, Anchor.direction(game, owner, line, now))
			result.append({"id": line.id, "role": "core_anchor", "from": at, "to": [end.x, 0, end.z],
				"radius": .36, "width": line.skill.radius, "color": line.skill.color})
		else:
			var from: Vector3 = line.from
			var to: Vector3 = line.to
			result.append({"id": line.id, "role": "core_thorns", "from": [from.x, 0, from.z], "to": [to.x, 0, to.z], "radius": line.skill.radius})
	return result


static func crown_preview(game: Node, field: RefCounted, shapes: Array, center: Vector3) -> Array:
	var points: Array = []
	if game.multiplayer.is_server():
		for target in Footprint.targets(game, shapes, center).slice(0, 2):
			points.append(game.enemy_position(target))
	else:
		points = guest_crown_points(game, field, shapes, center)
	if points.size() < 2 or not field.clear_line(points[0], points[1]):
		return []
	return [{"kind": "point", "at": points[0], "radius": .34}, {"kind": "point", "at": points[1], "radius": .34},
		{"kind": "link_guide", "from": points[0], "to": points[1]}]


static func guest_crown_points(game: Node, field: RefCounted, shapes: Array, center: Vector3) -> Array:
	var points: Array = []
	var enemies: Array[Vector3] = []
	if game.enemy_hp > 0:
		enemies.append(game.enemy_pos)
	var pack: PackedFloat32Array = game.client_pack
	for index in range(0, pack.size(), game.PACK_STRIDE):
		if pack[index + 2] > 0:
			enemies.append(Vector3(pack[index], 0, pack[index + 1]))
	for point in enemies:
		if Footprint.reaches(field, shapes, point, center):
			points.append(point)
	points.sort_custom(func(a, b): return center.distance_squared_to(a) < center.distance_squared_to(b))
	return points.slice(0, 2)
