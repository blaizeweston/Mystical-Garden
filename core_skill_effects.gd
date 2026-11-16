extends RefCounted

const Status = preload("res://combat_status.gd")
const Mark = preload("res://core_strike_mark.gd")
const Contact = preload("res://weapon_contact.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Tactics = preload("res://wilds_skill_tactics.gd")
const Variants = preload("res://core_weapon_variants.gd")
const Balance = preload("res://core_skill_balance.gd")
const WAVE_TRAVEL_MS := Balance.WAVE_TRAVEL_MS
const Footprint = preload("res://core_footprint.gd")


static func sequence(game: Node, id: int, player: Dictionary, cast: Dictionary, now: int) -> bool:
	var skill: Dictionary = cast.skill
	if not cast.grown:
		cast.grown = true
		cast.sequence_at = now
		cast.phase_index = 0
		cast.phases = Balance.phases(skill)
		var duration := int(skill.get("field_ms", skill.get("death_window_ms", skill.get("trap_ms", cast.phases.back().delay))))
		if skill.get("footprint") == "wave":
			duration = 2 * WAVE_TRAVEL_MS
		cast.ends_at = now + duration
		cast.expires = cast.ends_at + (0 if skill.has("death_window_ms") or skill.has("trap_ms") else 1500)
		cast.death_after = game.enemy_death_serial
		if skill.has("movement"):
			var origin: Vector3 = player.pos
			cast.step_origin = origin
			var landing := Variants.travel(game.battlefield, origin, cast.center, cast.forward, skill)
			player.pos = landing
			cast.step_end = landing
			if skill.movement == "approach":
				cast.center = landing
			if not origin.is_equal_approx(landing):
				game.emit_combat_event("link", skill.id, origin, landing, .4, Color(skill.color), 0.0, id)
		if int(skill.get("ward_ms", 0)) > 0:
			game.grant_guard(player, now + int(skill.ward_ms), 1)
		cast.shapes = Footprint.build(game.battlefield, cast, cast.get("step_origin", cast.cast_origin))
		cast.phase_contacts = {}
		if skill.id in ["worldbloom", "eclipse_maw"]:
			cast.secondary_shapes = Footprint.build(game.battlefield, cast, cast.cast_origin, 1)
	if skill.has("field_ms"):
		return living_field(game, id, player, cast, now)
	if skill.id == "eclipse_maw":
		eclipse_draw(game, cast, now)
	if skill.id == "spore_seal":
		return spore_seals(game, id, player, cast, now)
	if skill.has("death_window_ms"):
		return detonate_at_death(game, id, player, cast, now)
	if skill.get("footprint") == "wave":
		return wave(game, id, player, cast, now)
	if skill.has("trap_ms"):
		if now >= int(cast.sequence_at) + int(cast.phases[0].delay):
			trap(game, id, player, cast, now)
		cast.phase_index = maxi(1, int(cast.phase_index))
	while int(cast.phase_index) < cast.phases.size():
		var phase: Dictionary = cast.phases[cast.phase_index]
		if now < int(cast.sequence_at) + int(phase.delay):
			return false
		cast.phase_index += 1
		if not phase.get("reflected", false) or cast.has("reflection"):
			var center: Vector3 = cast.reflection if phase.get("reflected", false) else cast.center
			var shapes: Array = cast.shapes
			if skill.id == "eclipse_maw":
				if int(phase.delay) == 0:
					continue
				shapes = cast.secondary_shapes
			pulse(game, id, player, cast, phase, center, float(skill.radius), now, shapes)
		if game.encounter_cleared():
			return true
	return not skill.has("trap_ms")


static func trap(game: Node, id: int, player: Dictionary, cast: Dictionary, now: int) -> void:
	var skill: Dictionary = cast.skill
	var effect: Dictionary = cast.phases[0].enemy
	for target in Footprint.targets(game, cast.shapes, cast.center):
		var token := Contact.token(game, target)
		if cast.next_hit.has(token):
			continue
		if cast.next_hit.size() >= int(skill.targets):
			break
		if not affect_enemy(game, player, target, cast.center, skill, effect, now):
			continue
		cast.next_hit[token] = now
		var point: Vector3 = game.enemy_position(target)
		game.emit_combat_event("proc", skill.name, cast.center, point, .5, Color(skill.color), 0.0, target)
		if skill.has("ward_on_hit_ms"):
			game.grant_guard(player, now + int(skill.ward_on_hit_ms), 1)
		Journal.event("combat", "core_trap_contact", {"actor": id, "skill": skill.id, "cast_id": cast.id,
			"target": target, "target_token": token})


static func wave_width(skill: Dictionary) -> float:
	return float(skill.radius) * .5


static func wave(game: Node, id: int, player: Dictionary, cast: Dictionary, now: int) -> bool:
	var elapsed := now - int(cast.sequence_at)
	var skill: Dictionary = cast.skill
	var width := wave_width(skill)
	var origin: Vector3 = cast.cast_origin
	var end: Vector3 = cast.center
	var phase_index: int = cast.phase_index
	while phase_index < 2 and elapsed >= phase_index * WAVE_TRAVEL_MS:
		var returning := phase_index == 1
		var from := end if returning else origin
		var to := origin if returning else end
		if not cast.has("wave_fraction"):
			cast.wave_fraction = 0.0
			cast.wave_foes = {}
			game.emit_combat_event("ability", "riptide_return" if returning else "riptide", from, to,
				WAVE_TRAVEL_MS / 1000.0, Color(skill.color).lightened(.23) if returning else Color(skill.color),
				width, id, {"label": "Riptide"})
		var fraction := clampf((elapsed - phase_index * WAVE_TRAVEL_MS) / float(WAVE_TRAVEL_MS), 0, 1)
		var previous := from.lerp(to, float(cast.wave_fraction))
		var crest := from.lerp(to, fraction)
		var phase: Dictionary = skill.phases[phase_index]
		var effect: Dictionary = skill.get("extra_phase", {}).get("enemy", {}) if returning else phase.enemy
		if not effect.is_empty():
			for target in Contact.candidates(game, previous):
				if cast.wave_foes.size() >= int(skill.targets):
					break
				var token := Contact.token(game, target)
				var point: Vector3 = game.enemy_position(target)
				if not cast.wave_foes.has(token) and wave_reaches(game.battlefield, origin, previous, crest, point, width):
					if affect_enemy(game, player, target, origin, skill, effect, now):
						cast.wave_foes[token] = true
						if not returning and skill.has("ward_on_hit_ms"):
							game.grant_guard(player, now + int(skill.ward_on_hit_ms), 1)
		if returning:
			if not cast.has("return_heal_hp"):
				cast.return_heal_hp = Balance.Preview.roll_heal(Balance.heal_points(skill, phase.ally))
			for peer in game.players:
				var ally: Dictionary = game.players[peer]
				if not cast.next_hit.has(peer) and game.Life.alive(ally) and wave_reaches(game.battlefield, origin, previous, crest, ally.pos, width):
					cast.next_hit[peer] = true
					var previous_health := float(ally.hp)
					affect_ally(game, ally, phase.ally, now, int(cast.return_heal_hp), skill.id)
					if float(ally.hp) > previous_health and not Balance.Preview.enabled:
						game.emit_combat_event("proc", "siphon", crest, ally.pos, .55, Color(skill.color), 0.0, peer)
		if fraction < 1.0:
			cast.wave_fraction = fraction
			return false
		Journal.event("combat", "core_wave", {"actor": id, "skill": skill.id, "cast_id": cast.id, "returning": returning,
			"targets": cast.wave_foes.keys(), "healed": cast.next_hit.keys()})
		cast.erase("wave_fraction")
		phase_index += 1
		cast.phase_index = phase_index
	return true


static func wave_reaches(field: RefCounted, origin: Vector3, previous: Vector3, crest: Vector3, point: Vector3, width: float) -> bool:
	var nearest := Geometry3D.get_closest_point_to_segment(point, previous, crest)
	return point.distance_to(nearest) <= width and field.clear_line(origin, point) and field.clear_line(nearest, point)


static func detonate_at_death(game: Node, id: int, player: Dictionary, cast: Dictionary, now: int) -> bool:
	for event in game.enemy_death_events:
		if int(event.id) <= int(cast.death_after):
			continue
		cast.death_after = event.id
		var at := Vector3(event.position[0], event.position[1], event.position[2])
		if Vector3(cast.center).distance_to(at) > float(cast.skill.radius) or not game.battlefield.clear_line(cast.center, at):
			continue
		var phase: Dictionary = cast.phases[0].duplicate(true)
		if cast.skill.has("death_heal"):
			phase.ally = {"heal": cast.skill.death_heal}
		pulse(game, id, player, cast, phase, at, float(cast.skill.burst_radius), now)
		return true
	return false


static func pulse(game: Node, id: int, player: Dictionary, cast: Dictionary, phase: Dictionary, center: Vector3, radius: float, now: int, shapes: Array = []) -> void:
	var skill: Dictionary = cast.skill
	var foes: Array[int] = []
	if phase.has("enemy") or phase.get("pair", false):
		foes = area_targets(game, center, radius) if shapes.is_empty() and skill.id in ["mirror_bloom", "grave_lantern"] else Footprint.targets(game, shapes, center)
	if skill.id == "rime_bloom" and int(phase.delay) > 0:
		foes.clear()
		for target in cast.phase_contacts:
			if game.Traits.valid_target(game, target) and Contact.token(game, target) == cast.phase_contacts[target]:
				foes.append(target)
	var affected: Array[int] = []
	if phase.get("pair", false) and foes.size() >= 2 and game.battlefield.clear_line(game.enemy_position(foes[0]), game.enemy_position(foes[1])):
		affected.assign(foes.slice(0, 2))
		Mark.link_pair(game, id, affected, cast, now)
	var effect: Dictionary = phase.get("enemy", {}).duplicate()
	if int(phase.delay) == 0 and skill.has("opening_stagger_ms"):
		effect.stagger_ms = skill.opening_stagger_ms
	var damaged: Array[int] = []
	var brood_losses := 0
	for target in foes:
		if effect.is_empty() or affected.size() >= int(skill.targets):
			break
		var before: int = game.enemy_hp if target == -1 else int(game.scouts[target].hp)
		var hit := effect.duplicate()
		if skill.id == "eclipse_maw" and effect.has("damage") and cast.phase_contacts.has(Contact.token(game, target)):
			hit.damage += Balance.Preview.authored_amount(float(skill.get("bite_bonus", 0)))
		if affect_enemy(game, player, target, center, skill, hit, now):
			affected.append(target)
			if skill.id == "rime_bloom" and int(phase.delay) == 0:
				cast.phase_contacts[target] = Contact.token(game, target)
			var after: int = game.enemy_hp if target == -1 else int(game.scouts[target].hp)
			if after < before:
				damaged.append(target)
				if target >= 0 and after <= 0 and game.scouts[target].get("broodmother_spawn", false):
					brood_losses += 1
	if damaged.size() >= 2 or brood_losses > 0:
		Tactics.record(game, Tactics.AREA_PRESSURE, {"actor": id, "skill": skill.id, "cast_id": cast.id,
			"targets": damaged, "brood_losses": brood_losses})
	if phase.has("siphon"):
		var eligible := damaged.filter(func(target):return game.Life.Sustain.eligible(game,target)) if Balance.Preview.enabled else damaged
		var restored := Balance.siphon_contacts(skill, phase, eligible.size())
		for target in eligible.slice(0, restored):
			game.emit_combat_event("link", skill.id, game.enemy_position(target), player.pos, .5, Color(skill.color), 0.0, id)
		var applied: float = game.Life.Sustain.heal(game,player,Balance.siphon_points(restored),skill.id,Balance.Preview.HEAL_DRAIN_SPREAD_HP)
		if applied>0.0 and not Balance.Preview.enabled:
			game.emit_combat_event("proc", "siphon", center, player.pos, .55, Color(skill.color), 0.0, id)
	var ward_hits := damaged if skill.id in ["blood_siphon", "eclipse_maw"] else affected
	if not ward_hits.is_empty() and skill.has("ward_on_hit_ms"):
		game.grant_guard(player, now + int(skill.ward_on_hit_ms), 1)
	var allies: Array[int] = []
	if phase.has("ally"):
		if shapes.is_empty() and skill.id in ["mirror_bloom", "grave_lantern"]:
			allies = affect_allies(game, center, radius, skill, phase.ally, now)
		else:
			allies = shaped_allies(game, cast, shapes, phase.ally, now)
	var artwork := shapes if not shapes.is_empty() else [Footprint.area(center, radius)]
	if skill.id == "rime_bloom" and int(phase.delay) > 0:
		artwork = []
		for target in affected:
			artwork.append(Footprint.area(game.enemy_position(target), .35))
	if skill.id == "mirror_bloom":
		game.emit_combat_event("ability", skill.id, center, center, .52, Color(skill.color), radius, id, {"label": skill.name if int(phase.delay) == 0 else ""})
	else:
		cast_effect(game, id, skill, center, artwork, int(phase.delay))
	Journal.event("combat", "core_pulse", {"actor": id, "skill": skill.id, "cast_id": cast.id,
		"phase_ms": phase.delay, "targets": affected, "allies": allies})


static func area_targets(game: Node, center: Vector3, radius: float, ranged: bool = false) -> Array[int]:
	var result: Array[int] = []
	for target in Contact.candidates(game, center):
		var at: Vector3 = game.enemy_position(target)
		if center.distance_to(at) > radius:
			break
		var clear: bool = game.battlefield.projectile_clear(center, at) if ranged else game.battlefield.clear_line(center, at)
		if clear:
			result.append(target)
	return result


static func affect_enemy(game: Node, player: Dictionary, target: int, center: Vector3, skill: Dictionary, effect: Dictionary, now: int) -> bool:
	var boss: bool = target == -1 and game.boss_kind >= 0
	var scout: Dictionary = game.scouts[target] if target >= 0 else game.leader_brain.get("elite", {})
	var winding: bool = game.enemy_winding_up if target == -1 else int(scout.windup) > 0
	if (effect.get("only_winding", false) and not winding) or (boss and effect.has("interrupt_ms")):
		return false
	var at: Vector3 = game.enemy_position(target)
	var amount := Balance.enemy_points(effect, winding)
	if effect.has("brittle"):
		var state: Dictionary = game.Traits.target_state(game, target)
		var stacks := int(state.get("brittle", 0)) if now < int(state.get("brittle_until", 0)) else 0
		stacks += int(effect.brittle)
		if skill.id == "rime_bloom":
			state.rime_until = now + 4000
			state.rime_root_ms = 900 + int(skill.get("root_bonus_ms", 0))
		if stacks >= 3:
			amount += Balance.SHATTER_POINTS
			stacks = 0
			Status.proc(game, "shatter", at, at, target)
			shatter_rime(game, state, target, now)
		state.brittle = stacks
		state.brittle_until = now + 4000
	if amount > 0:
		damage(game, player, target, center, amount, now)
	if not game.Traits.valid_target(game, target):
		return true
	if not boss and effect.has("interrupt_ms"):
		Tactics.interrupted(game, scout, str(skill.id))
		var ready := now + int(effect.interrupt_ms)
		if not scout.is_empty():
			scout.windup = 0
			scout.ready = ready
			scout.erase("attack")
			scout.erase("repeat")
		if target == -1:
			game.enemy_winding_up = false
			game.enemy_ready_at = ready
			game.enemy_attack_mode = ""
			game.active_radius = 0.0
		Status.proc(game, "suppress", center, at, target)
	var root_ms := int(effect.get("root_ms", 0))
	if effect.has("interrupt_ms"):
		root_ms = maxi(root_ms, int(skill.get("root_on_interrupt_ms", 0)))
	if amount > 0:
		root_ms = maxi(root_ms, int(skill.get("root_on_damage_ms", 0)))
	if root_ms > 0:
		Status.root(game, target, now + root_ms + int(skill.get("root_bonus_ms", 0)))
	if effect.has("stagger_ms") and not boss and not winding:
		var until := now + int(effect.stagger_ms)
		if target == -1:
			game.enemy_stagger_until = maxi(game.enemy_stagger_until, until)
		else:
			scout.stagger_until = maxi(int(scout.stagger_until), until)
	if effect.has("displace") and not boss and not winding:
		var travel := float(effect.displace)
		var offset: Vector3 = at - center
		var length := absf(travel) + float(skill.get("displacement_bonus", 0))
		var endpoint := at.move_toward(center, length) if travel < 0.0 else at + offset.normalized() * length
		var moved: Vector3 = game.battlefield.dash(at, endpoint)
		preload("res://enemy_support.gd").observe_shelter_break(game, target, game.enemy_position(target), moved, now)
		if target == -1:
			game.enemy_pos = moved
		else:
			scout.pos = moved
	return true


static func damage(game: Node, player: Dictionary, target: int, origin: Vector3, amount: float, now: int) -> void:
	game.apply_weapon_hit(player, target, origin, {"damage": amount, "knockback": -.35, "trait_secondary": true, "core_hit": true}, now)


static func affect_allies(game: Node, center: Vector3, radius: float, skill: Dictionary, effect: Dictionary, now: int) -> Array[int]:
	var allies: Array[int] = []
	var heal_hp := roll_ally_heal(skill, effect)
	for peer in game.players:
		var ally: Dictionary = game.players[peer]
		if game.Life.alive(ally) and center.distance_to(ally.pos) <= radius and game.battlefield.clear_line(center, ally.pos):
			affect_ally(game, ally, effect, now, heal_hp, skill.id)
			allies.append(peer)
	return allies


static func affect_ally(game: Node, ally: Dictionary, effect: Dictionary, now: int, heal_hp: int, source: String) -> void:
	if heal_hp > 0:
		game.Life.Sustain.restore(game,ally,heal_hp,source)
	if effect.get("cleanse", false):
		ally.slow_until = 0
	if effect.has("guard_ms"):
		game.grant_guard(ally, now + int(effect.guard_ms), 1)


static func roll_ally_heal(skill: Dictionary, effect: Dictionary) -> int:
	return Balance.Preview.roll_heal(Balance.heal_points(skill, effect)) if effect.has("heal") else 0


static func chain(game: Node, id: int, player: Dictionary, cast: Dictionary, first: int, now: int) -> void:
	var skill: Dictionary = cast.skill
	var visited := [first]
	var at: Vector3 = game.enemy_position(first)
	damage(game, player, first, cast.from, float(skill.damage), now)
	for hop in int(skill.chain_targets):
		var next := -2
		for candidate in area_targets(game, at, float(skill.chain_range), true):
			if not visited.has(candidate):
				next = candidate
				break
		if next == -2:
			break
		var destination: Vector3 = game.enemy_position(next)
		game.emit_combat_event("link", skill.id, at, destination, .38, Color(skill.color), 0.0, next)
		damage(game, player, next, at, Balance.CHAIN_HOP_POINTS, now)
		if skill.has("chain_root_ms") and game.Traits.valid_target(game, next):
			Status.root(game, next, now + int(skill.chain_root_ms))
		visited.append(next)
		at = destination
	Journal.event("combat", "core_chain", {"actor": id, "skill": skill.id, "cast_id": cast.id, "targets": visited})


static func hints(game: Node, cast: Dictionary, now: int) -> Array:
	var skill: Dictionary = cast.skill
	if skill.get("footprint") == "wave":
		return []
	var remaining := maxf(0.0, (int(cast.ends_at) - now) / 1000.0)
	var center: Vector3 = cast.center
	var hint := field_hint(cast.id, center, remaining, skill)
	var shapes: Array = cast.get("shapes", [])
	if skill.id in ["eclipse_maw", "worldbloom"]:
		hint.core_secondary = Footprint.encode(cast.get("secondary_shapes", []))
	if not shapes.is_empty():
		hint.core_shapes = Footprint.encode(shapes)
		hint.core_phase = maxi(0, now - int(cast.sequence_at))
		hint.core_inner = skill.has("inner_root_ms")
		if skill.has("trap_ms"):
			hint.core_armed = now >= int(cast.sequence_at) + int(skill.phases[0].delay)
		if skill.id == "spore_seal":
			hint.core_seals = seal_states(cast, now)
	var footprint := [hint]
	if cast.has("reflection"):
		footprint.append(field_hint(cast.id + ":mirror", cast.reflection, remaining, skill))
	if skill.id == "dream_lure":
		footprint.append_array(decoy_hints(game, cast))
	return footprint


static func field_hint(id: String, center: Vector3, remaining: float, skill: Dictionary) -> Dictionary:
	var point := [center.x, 0, center.z]
	return {"id": id, "role": "core_field", "from": point, "to": point, "radius": skill.radius,
		"remaining": remaining, "color": skill.color, "skill": skill.id,
		"decoy": skill.has("decoy_ms")}


static func cast_effect(game: Node, id: int, skill: Dictionary, center: Vector3, shapes: Array, phase: int) -> void:
	if shapes.is_empty():
		return
	game.emit_combat_event("ability", skill.id, center, center, .7, Color(skill.color), skill.radius, id,
		{"label": skill.name if phase == 0 else "", "core_shapes": Footprint.encode(shapes), "core_phase": phase})


static func living_field(game: Node, id: int, player: Dictionary, cast: Dictionary, now: int) -> bool:
	if now >= int(cast.ends_at):
		return true
	var skill: Dictionary = cast.skill
	var elapsed := now - int(cast.sequence_at)
	var center: Vector3 = cast.center
	match skill.id:
		"ember_wake":
			var opening: bool = cast.phase_index == 0
			var effect: Dictionary = skill.phases[0].enemy.duplicate()
			if opening:
				cast.phase_index = 1
				cast_effect(game, id, skill, center, cast.shapes, 0)
				if skill.has("opening_stagger_ms"):
					effect.stagger_ms = skill.opening_stagger_ms
			var damaged: Array[int] = []
			var brood_losses := 0
			for target in Footprint.targets(game, cast.shapes, center):
				var token := Contact.token(game, target)
				if damaged.size() >= int(skill.targets):
					break
				if now < int(cast.next_hit.get(token, 0)):
					continue
				if affect_enemy(game, player, target, center, skill, effect, now):
					cast.next_hit[token] = now + Balance.EMBER_INTERVAL_MS
					damaged.append(target)
					if target >= 0 and int(game.scouts[target].hp) <= 0 and game.scouts[target].get("broodmother_spawn", false):
						brood_losses += 1
			if not damaged.is_empty():
				Journal.event("combat", "core_pulse", {"actor": id, "skill": skill.id, "cast_id": cast.id, "phase_ms": elapsed, "targets": damaged, "allies": []})
				if skill.has("ward_on_hit_ms"):
					game.grant_guard(player, now + int(skill.ward_on_hit_ms), 1)
			if damaged.size() >= 2 or brood_losses > 0:
				Tactics.record(game, Tactics.AREA_PRESSURE, {"actor": id, "skill": skill.id, "cast_id": cast.id, "targets": damaged, "brood_losses": brood_losses})
		"gravity_well":
			var previous: int = cast.get("pull_at", now)
			cast.pull_at = now
			var cap := 2.55 + 3.0 * float(skill.get("displacement_bonus", 0))
			for target in Footprint.targets(game, cast.shapes, center):
				var token := Contact.token(game, target)
				if not cast.phase_contacts.has(token) and cast.phase_contacts.size() >= int(skill.targets):
					continue
				if not can_displace(game, target):
					continue
				var moved_before: float = cast.phase_contacts.get(token, 0.0)
				var limit := minf(cap - moved_before, (now - previous) * cap / float(skill.field_ms))
				var at: Vector3 = game.enemy_position(target)
				var moved := displace_to(game, target, at.move_toward(center, maxf(0.0, limit)), now) if limit > 0.0 else 0.0
				if moved > .001:
					cast.phase_contacts[token] = moved_before + moved
					if skill.has("ward_on_hit_ms") and not cast.get("pull_ward", false):
						cast.pull_ward = true
						game.grant_guard(player, now + int(skill.ward_on_hit_ms), 1)
				if skill.has("inner_root_ms") and not cast.next_hit.has(token) and game.enemy_position(target).distance_to(center) <= float(skill.radius) * .28:
					cast.phase_contacts[token] = moved_before + moved
					cast.next_hit[token] = true
					Status.root(game, target, now + int(skill.inner_root_ms))
		"worldbloom":
			if cast.phase_index == 0 and elapsed >= 300:
				cast.phase_index = 1
				pulse(game, id, player, cast, skill.phases[0], center, float(skill.radius), now, cast.shapes)
			var canopy: Dictionary = skill.phases[1]
			if elapsed >= int(canopy.delay):
				if cast.phase_index == 1:
					cast.phase_index = 2
					cast_effect(game, id, skill, center, cast.secondary_shapes, int(canopy.delay))
				var allies := shaped_allies(game, cast, cast.secondary_shapes, canopy.ally, now)
				for peer in allies:
					game.emit_combat_event("proc", "canopy", game.players[peer].pos, game.players[peer].pos, .55, Color(skill.color), 0.0, peer)
	return game.encounter_cleared()


static func eclipse_draw(game: Node, cast: Dictionary, now: int) -> void:
	var elapsed := now - int(cast.sequence_at)
	var previous: int = cast.get("jaw_at", int(cast.sequence_at) - 110)
	cast.jaw_at = now
	var shapes: Array = cast.shapes
	var limit := maxf(0.0, (mini(elapsed, 580) - (previous - int(cast.sequence_at))) * .0038)
	if limit <= 0.0:
		return
	var center: Vector3 = cast.center
	var forward: Vector3 = cast.forward
	for target in Footprint.targets(game, shapes, center):
		var token := Contact.token(game, target)
		if not cast.phase_contacts.has(token) and cast.phase_contacts.size() >= int(cast.skill.targets):
			continue
		if not can_displace(game, target):
			continue
		var at: Vector3 = game.enemy_position(target)
		var seam := center + forward * (at - center).dot(forward)
		if displace_to(game, target, at.move_toward(seam, limit), now) > .001:
			cast.phase_contacts[token] = true


static func can_displace(game: Node, target: int) -> bool:
	return not (game.boss_kind >= 0 or game.enemy_winding_up) if target == -1 else int(game.scouts[target].windup) <= 0


static func displace_to(game: Node, target: int, endpoint: Vector3, now: int) -> float:
	var at: Vector3 = game.enemy_position(target)
	var moved: Vector3 = game.battlefield.dash(at, endpoint)
	preload("res://enemy_support.gd").observe_shelter_break(game, target, at, moved, now)
	if target == -1:
		game.enemy_pos = moved
	else:
		game.scouts[target].pos = moved
	return at.distance_to(moved)


static func seal_states(cast: Dictionary, now: int) -> Array:
	var result := []
	for index in cast.shapes.size():
		var seal: Dictionary = cast.phase_contacts.get(index, {})
		if seal.is_empty():
			result.append(0)
		elif now < int(seal.ready):
			result.append(-1)
		else:
			result.append(1)
	return result


static func spore_seals(game: Node, id: int, player: Dictionary, cast: Dictionary, now: int) -> bool:
	var skill: Dictionary = cast.skill
	if now >= int(cast.ends_at):
		return true
	var phase: Dictionary = skill.phases[0]
	if now < int(cast.sequence_at) + int(phase.delay):
		return false
	for index in cast.shapes.size():
		var seal: Dictionary = cast.phase_contacts.get(index, {"used": 0, "ready": 0})
		if now < int(seal.ready):
			continue
		var shape: Dictionary = cast.shapes[index]
		for target in Footprint.targets(game, [shape], cast.center):
			var token := Contact.token(game, target)
			if cast.next_hit.has(token) or not affect_enemy(game, player, target, shape.at, skill, phase.enemy, now):
				continue
			cast.next_hit[token] = true
			seal.used += 1
			seal.ready = now + int(skill.rearm_ms) if skill.has("rearm_ms") and int(seal.used) == 1 else cast.ends_at
			cast.phase_contacts[index] = seal
			game.emit_combat_event("proc", "spore seal", shape.at, game.enemy_position(target), .55, Color(skill.color), 0.0, target)
			cast_effect(game, id, skill, shape.at, [shape], 1)
			if skill.has("ward_on_hit_ms"):
				game.grant_guard(player, now + int(skill.ward_on_hit_ms), 1)
			Journal.event("combat", "core_trap_contact", {"actor": id, "skill": skill.id, "cast_id": cast.id, "target": target, "target_token": token})
			break
	return false


static func shaped_allies(game: Node, cast: Dictionary, shapes: Array, effect: Dictionary, now: int) -> Array[int]:
	var result: Array[int] = []
	var skill: Dictionary = cast.skill
	var on_contact := effect.duplicate()
	if skill.has("contact_ward_ms"):
		on_contact.guard_ms = skill.contact_ward_ms
	var heal_hp := 0
	if skill.id == "worldbloom":
		if not cast.has("canopy_heal_hp"):
			cast.canopy_heal_hp = roll_ally_heal(skill, on_contact)
		heal_hp = int(cast.canopy_heal_hp)
	else:
		heal_hp = roll_ally_heal(skill, on_contact)
	for peer in game.players:
		var ally: Dictionary = game.players[peer]
		if not game.Life.alive(ally) or not Footprint.reaches(game.battlefield, shapes, ally.pos, cast.center):
			continue
		if skill.id == "worldbloom":
			if cast.next_hit.has(peer):
				continue
			cast.next_hit[peer] = true
		var can_own_ward := int(ally.get("guard_until", 0)) <= now or (int(ally.get("guard_charges", 0)) == 1 and int(ally.guard_until) < now + int(on_contact.get("guard_ms", 0)))
		affect_ally(game, ally, on_contact, now, heal_hp, skill.id)
		if skill.id == "ironbark" and skill.has("block_stagger_ms") and can_own_ward:
			ally.ironbark_ward = {"cast": cast, "until": now + int(on_contact.guard_ms), "life": int(ally.get("lost_health", 0))}
		result.append(peer)
	return result


static func ironbark_block(game: Node, id: int, player: Dictionary, now: int) -> void:
	var ward: Dictionary = player.get("ironbark_ward", {})
	player.erase("ironbark_ward")
	if ward.is_empty() or now >= int(ward.until) or int(ward.life) != int(player.get("lost_health", 0)):
		return
	var cast: Dictionary = ward.cast
	if int(cast.epoch) != game.combat_epoch or cast.get("ward_spent", false) or game.encounter_cleared():
		return
	cast.ward_spent = true
	var effect := {"stagger_ms": cast.skill.block_stagger_ms}
	for target in area_targets(game, player.pos, 1.45).slice(0, 3):
		affect_enemy(game, player, target, player.pos, cast.skill, effect, now)
	cast_effect(game, id, cast.skill, player.pos, [Footprint.area(player.pos, 1.45)], 1)


static func shatter_rime(game: Node, state: Dictionary, target: int, now: int) -> void:
	if now < int(state.get("rime_until", 0)):
		Status.root(game, target, now + int(state.rime_root_ms))
	state.erase("rime_until")
	state.erase("rime_root_ms")


static func decoy_hints(game: Node, cast: Dictionary) -> Array:
	var center: Vector3 = cast.center
	var result := []
	for target in Contact.candidates(game, center):
		if result.size() >= 4:
			break
		var actor: Dictionary = game.leader_brain if target == -1 else game.scouts[target]
		var engaged: bool = game.enemy_engaged if target == -1 else actor.engaged
		var point: Vector3 = game.enemy_position(target)
		if not engaged or int(actor.get("target", 0)) != int(cast.owner) or point.distance_to(center) > 7.0 or point.distance_to(center) < .3:
			continue
		result.append({"id": cast.id + ":lure:" + Contact.token(game, target), "role": "core_lured",
			"from": [point.x, 0, point.z], "to": [center.x, 0, center.z], "radius": 0.0, "color": cast.skill.color})
	return result
