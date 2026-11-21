extends RefCounted
## Resolved enemy contacts, shared by weapons, native spells and secondary HP.
## Delivery/terrain admission stays with the weapon or spell that made contact.
## Context binds one source life, floor and roster; no actor records enter policy.

const Context = preload("res://outgoing_hit_context.gd")
const Preview = preload("res://combat_balance_preview.gd")
const Vitals = preload("res://combat_vitals.gd")
const SkillBalance = preload("res://class_skill_balance.gd")

# Existing native contact values, in metres, milliseconds and unitless scales.
const NATIVE_PUSH_METRES := .35
const PULL_STANDOFF_METRES := .9
const DIRECTION_EPSILON_METRES := .001
const BOSS_PUSH_SCALE := .2
const GUARDIAN_PUSH_SCALE := .5
const BARK_PUSH_SCALE := .6
const WINDUP_PUSH_SCALE := .4
const NATIVE_STAGGER_MS := 90
const INTERRUPT_THRESHOLD_MS := 150


static func hit_world(world: Node, source_peer: int, target: int, origin: Vector3,
		stats: Dictionary, now: int, expected_token: int = -1) -> Dictionary:
	return hit(Context.new(world, source_peer), target, origin, stats, now, expected_token)


## Previously accepted affinity HP may finish after its source has departed.
## It has no native contacts, charges, weapon roll, or recipient-side procs.
static func affinity_world(world: Node, source_peer: int, target: int, hp: int,
		now: int, color: Color, card_secondary := false) -> Dictionary:
	var source := Context.new(world, source_peer, true)
	var point := source.target_position(target)
	return hit(source, target, point, {"damage":0.0, "affinity_hp":hp, "affinity_color":color,
		"knockback":-NATIVE_PUSH_METRES, "trait_secondary":true, "core_hit":true, "card_secondary":card_secondary}, now)


static func hit(source: Context, target: int, origin: Vector3, stats: Dictionary,
		now: int, expected_token: int = -1) -> Dictionary:
	if not source.is_current() or not source.permits_contact(stats): return {}
	source.observe_contact(target)
	var token := source.capture_target(target)
	if token < 0 or (expected_token >= 0 and token != expected_token): return {}
	var contact := source.begin_contact(target, stats, now)
	stats = contact.stats
	var graft: Dictionary = contact.graft
	var facts := source.target_facts(target, stats, origin, now)
	var point: Vector3 = facts.point
	var contact_point := point
	var distance := origin.distance_to(point)
	var winding: bool = facts.winding
	var pull := float(stats.get("pull", 0))
	if pull > 0 and not winding:
		point = source.movement_endpoint(point, point.move_toward(origin, clampf(distance - PULL_STANDOFF_METRES, 0, pull)))
	var authored := Preview.authored_amount(float(stats.damage))
	if not graft.is_empty(): authored += source.graft_bonus(graft, now)
	if not stats.get("trait_secondary", false): authored += int(stats.get("preview_power", 0))
	if winding: authored += Preview.authored_amount(float(stats.get("windup_damage", 0)))
	if winding and float(stats.get("windup_damage", 0)) > 0: source.punish(origin, point, target)
	var damage := int(stats.affinity_hp) if stats.has("affinity_hp") else Preview.resolved_hit(authored, stats)
	damage += int(stats.get("native_bonus_hp", 0))
	if damage > 0 and stats.get("ranger_direct_hit", false) and not stats.get("trait_secondary", false) and not stats.get("core_hit", false):
		damage += source.consume_prey(target, now)
	var push := NATIVE_PUSH_METRES + float(stats.get("knockback", 0))
	if source.sheltered(target, point, origin, now): damage = Preview.armor(damage)
	if facts.boss: push *= BOSS_PUSH_SCALE
	elif facts.guardian: push *= GUARDIAN_PUSH_SCALE
	if facts.bark_guard:
		if facts.guards:
			push *= BARK_PUSH_SCALE
			damage = Preview.armor(damage)
	elif facts.bark:
		push *= BARK_PUSH_SCALE
		damage = Preview.armor(damage)
	if facts.exposed: damage += source.exposed_bonus(damage)
	if winding: push *= WINDUP_PUSH_SCALE
	if pull <= 0 or winding:
		var direction: Vector3 = (point - origin).normalized() if distance > DIRECTION_EPSILON_METRES else facts.facing
		point = source.movement_endpoint(point, point + direction * push)
	if not source.target_is_current(target, token): return {}
	source.alert(point, damage)
	var before := source.enemy_hp(target)
	var applied := Vitals.damage_taken(before, damage)
	source.record_pressure(point, damage, before, applied)
	point = source.install_hit(target, token, point, applied, int(stats.get("recovery", 0)),
		now + NATIVE_STAGGER_MS + int(stats.get("stagger", 0)), winding, stats, now, INTERRUPT_THRESHOLD_MS)
	source.finish_contact(target, token, origin, point, contact_point, stats, graft, now, before, applied)
	source.record_damage(applied, float(stats.get("shot_distance", distance)))
	return {"target":target, "token":token, "damage":damage, "applied_hp":applied,
		"before_hp":before, "after_hp":source.enemy_hp(target), "point":point}


static func skill_world(world: Node, source_peer: int, targets: Array[int], skill: Dictionary,
		stats: Dictionary, now: int) -> int:
	return skill_targets(Context.new(world, source_peer), targets, skill, stats, now)


static func skill_targets(source: Context, targets: Array[int], skill: Dictionary,
		stats: Dictionary, now: int) -> int:
	if not source.is_current(): return 0
	var before_primary := source.enemy_hp(-1)
	var drain_contacts := 0
	var native_hits: Dictionary = skill.get("native_hit_adjustments", {})
	var has_bloom := source.begin_bloom(skill, now)
	var echo_hit := false
	# A death hook can replace a scout slot. Later hits still name the original
	# occupant, never a summon or replacement registered while this batch runs.
	var captured := source.capture_targets(targets)
	for victim in captured:
		var target: int = victim.target
		var token: int = victim.token
		if not source.target_is_current(target, token): continue
		var adjustment: Dictionary = native_hits.get(target, {})
		var root_ms := SkillBalance.bind_ms(skill, stats)
		source.extend_control(target, now + root_ms if root_ms > 0 else 0, int(skill.get("recovery", 0)))
		var damage := Preview.authored_amount(float(skill.get("damage", 0))) + float(adjustment.get("bonus_hp", 0)) / Preview.scale()
		if damage <= 0.0: continue
		var native_hit := stats.duplicate(true)
		native_hit.damage = damage
		native_hit.audio_form = "magic"
		native_hit.stagger = int(stats.get("stagger", 0)) + int(skill.get("stagger", 0))
		native_hit.recovery = int(stats.get("recovery", 0)) + int(skill.get("recovery", 0))
		native_hit.knockback = float(skill.get("push", 0)) - NATIVE_PUSH_METRES
		if adjustment.get("isolated", false):
			native_hit = {"damage":0.0, "affinity_hp":Preview.effect_hp(damage), "trait_secondary":true,
				"core_hit":true, "knockback":-NATIVE_PUSH_METRES}
		else:
			native_hit.ranger_direct_hit = not stats.get("ranger_trap_contact", false) and skill.mode != "salvo"
			if skill.has("reaper_nodes"): source.tag_reaper_hit(native_hit, skill.reaper_nodes)
		var before := source.enemy_hp(target)
		var inside_bloom := before > 0 and has_bloom and source.inside_bloom(target)
		hit(source, target, adjustment.get("origin", skill.get("effect_origin", source.position())), native_hit, now, token)
		var after := source.enemy_hp(target)
		echo_hit = echo_hit or (inside_bloom and after < before)
		if source.drain_eligible(target): drain_contacts += int(after < before)
	if echo_hit: source.release_bloom(skill, now)
	source.heart_message(before_primary)
	return drain_contacts
