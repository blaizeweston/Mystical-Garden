extends RefCounted
## The shared native Q/R sequence. Per-cast values are local to this module;
## ClassCaster bridges one captured player life to existing state/effect owners.
## Focus Q effects stay in subclass_combat.gd; outgoing_hits.gd resolves contacts.

const Caster = preload("res://class_caster.gd")
const Balance = preload("res://class_skill_balance.gd")
const Build = preload("res://affinity_build.gd")
const Events = preload("res://combat_action_events.gd")
const Clock = preload("res://combat_clock.gd")


static func cast_world(world: Node, peer: int, slot: int = 0) -> void:
	cast(Caster.new(world, peer), slot)


static func cast(caster: Caster, slot: int = 0) -> void:
	caster.record_request(slot)
	if slot < 0 or slot > 1: return
	var now := Clock.now()
	var facts := caster.observe(slot, now)
	if facts.is_empty() or not facts.alive or facts.cleared or not facts.ready or now < int(facts.core_cast_until): return
	var stats := caster.resolved_stats()
	var skill: Dictionary
	var event: RefCounted
	var adapter := {}
	var build: Dictionary = stats.get("affinity_build", {})
	if not build.is_empty():
		stats.erase("affinity_build")
		var refusal := Build.refusal(build, "catalyst")
		if not refusal.is_empty():
			caster.tell(refusal)
			return
		adapter = build.class_skills[slot]
		if adapter.is_empty():
			caster.tell("This class ability has no affinity contract.")
			return
		skill = adapter.native_skill.duplicate()
		caster.tune_class(skill, build)
		event = caster.begin_event(adapter, now, build.catalyst)
		if adapter.trigger == "contact" or (event != null and event.affinity in ["vital", "wood"] and adapter.recipients == "designated_area"):
			stats[Events.CONTEXT] = event
		if skill.mode == "subclass":
			stats.cr02_adapter = adapter
			stats[Events.CONTEXT] = event
	else:
		skill = caster.native_skill(slot)
	skill = skill.duplicate(true)
	if skill.mode == "subclass":
		caster.cast_focus(skill, stats, now)
		return
	var duration := int(stats.get("skill_duration", 0))
	var bonus_heal := Balance.healing_bonus(stats)
	var reach := Balance.range_limit(skill, stats, facts.weapon_reach)
	var radius := float(skill.get("radius", 0))
	var origin: Vector3 = facts.position
	var center := origin
	var targets: Array[int] = []
	var recipients: Array[int] = []
	var mode := str(skill.mode)
	var plan := caster.target_plan(skill, stats, reach)
	if not plan.valid:
		caster.tell("%s: no enemy within clear range." % skill.name)
		return
	var target: int = plan.target
	var point: Vector3 = plan.point
	reach = plan.reach
	if not facts.aimed and mode == "siphon":
		var extra := float(skill.get("travel", 0)) if not skill.has("range") else 0.0
		if target == -2 or origin.distance_to(point) > reach + extra:
			caster.tell("%s: no enemy within clear range." % skill.name)
			return
	var chime := caster.begin_chime(skill, event, now) if slot == 1 and skill.has("oracle_nodes") else {}
	var ranger_snare := false
	var reaper_siphon := false
	match mode:
		"front_guard", "counter_guard", "guard", "ward":
			var ward_ms := int(chime.get("duration", skill.duration)) + duration + int(skill.get("ward_ms", 0)) if mode == "ward" else int(skill.duration) + duration
			_protect(caster, mode, origin, plan.forward, radius, now + ward_ms, int(skill.charges), event, adapter, now)
		"snare":
			center = plan.center if facts.aimed else caster.ground_endpoint(point if target != -2 else origin + Vector3(plan.forward) * reach)
			if skill.has("ranger_nodes") and caster.ground_occupied(center):
				caster.tell("Bramble Snare needs supported ground.")
				return
			var placed := caster.place_snare(center, skill, stats, now)
			if skill.has("ranger_nodes"):
				if not placed:
					caster.tell("Bramble Snare could not be set. Wait for an active effect to expire.")
					return
				ranger_snare = true
		"quake", "nova":
			if mode == "quake" and skill.has("warden_focus"):
				center = plan.center if facts.aimed else caster.quake_center(skill, now)
				skill.effect_origin = center
			targets = caster.area_targets(center, radius)
		"siphon":
			targets.assign([target])
			center = point
			if skill.has("reaper_nodes"):
				reaper_siphon = caster.begin_siphon(skill, target, point, now)
	caster.notify_movement(origin)
	var native_nova := mode == "nova" and skill.has("weaver_nodes")
	# Symbiotic Nova extends native hits, never the captured Catalyst footprint.
	var catalyst_targets := targets.duplicate() if native_nova else targets
	var weaver_impact := caster.prepare_nova(skill, targets, center, now) if native_nova else Vector3.INF
	if not targets.is_empty(): caster.prepare_impact(skill, now)
	var hits := caster.apply_targets(targets, skill, stats, now)
	var siphon_damaged := reaper_siphon and caster.siphon_damaged(target)
	if skill.has("warden_focus") and slot == 0: caster.warden_cast(skill, now + int(skill.duration) + duration, now, event)
	if mode == "quake" and skill.has("warden_focus"): caster.quake_hit(center, targets, radius, now)
	if mode == "siphon" and hits > 0: caster.drain(Balance.drain_amount(skill, hits), mode)
	caster.commit_cooldown(slot, now, Balance.cooldown(skill, stats), bonus_heal)
	var feedback := caster.finish_snare(origin, now) if ranger_snare else ""
	caster.complete_event(event, adapter, origin, center, catalyst_targets, recipients, now, float(skill.get("warden_catalyst_radius", radius)))
	if reaper_siphon:
		caster.finish_siphon(skill, target, center, siphon_damaged, now)
	elif not chime.is_empty():
		caster.finish_chime(skill, now)
	elif slot == 1 and skill.has("subclass_focus") and not skill.has("ranger_nodes") and (not native_nova or skill.subclass_follow_lane != 0):
		caster.follow_through(skill, center, targets, now)
	if native_nova: caster.complete_nova(skill.weaver_nodes, center, weaver_impact, now)
	caster.publish(skill, origin, center, radius, now, feedback)
	caster.finish_if_cleared(targets, center)


static func _protect(caster: Caster, mode: String, origin: Vector3, facing: Vector3, radius: float,
		until: int, charges: int, event: RefCounted, adapter: Dictionary, now: int) -> void:
	if mode != "ward":
		caster.grant_ward(caster.peer_id(), until, charges, event, adapter, now)
		if mode in ["front_guard", "counter_guard"]: caster.set_guard(mode, until, facing)
	if mode not in ["front_guard", "ward"]: return
	for ally in caster.ally_facts():
		var offset: Vector3 = ally.position - origin
		if not ally.alive or offset.length() > radius: continue
		if mode == "front_guard" and (ally.is_self or (offset.length_squared() >= Balance.FRONT_GUARD_POINT_EPSILON_SQ and offset.normalized().dot(facing.normalized()) < Balance.FRONT_GUARD_MIN_DOT)): continue
		if caster.clear_line(origin, ally.position):
			caster.grant_ward(ally.id, until, 1 if mode == "front_guard" else charges, event, adapter, now)
