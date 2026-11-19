extends SceneTree
## Real class execution with a captured caster: no alternate combat implementation.
const Actions = preload("res://native_class_actions.gd")
const Caster = preload("res://class_caster.gd")
const Cooldowns = preload("res://player_cooldowns.gd")
const Lifecycle = preload("res://player_lifecycle.gd")
const Protection = preload("res://player_protection.gd")
const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL native class actions: ", label)


func run() -> void:
	var world: Node = load("res://world.tscn").instantiate()
	var path := "res://.godot/native-class-actions-" + Crypto.new().generate_random_bytes(8).hex_encode()
	world.progress.path = path + ".garden"
	world.local_character.path = path + ".character"
	world.guest_character.path = path + ".guest"
	world.settings_path = path + ".settings"
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	var actor: Dictionary = world.players[1]
	actor.pos = world.stage.gate_position()
	world.handle_loadout_action(1, actor, "learn_0_64")
	world.send_action(false)
	world.send_garden_action("depart")
	check(ExpeditionCase.is_wild(actor), "a real focus selection admits the empty-plant character")
	world.battlefield.configure(0, 1, 0)
	preload("res://tests/support/terrain_case.gd").walls(world.battlefield, [])
	world.encounter.clear_scouts()
	world.encounter.set_hp(-1, 100)
	world.tactics.position = Vector3(0, 0, -1)
	actor.pos = Vector3.ZERO
	actor.facing = Vector3.FORWARD
	var caster := Caster.new(world, 1)
	var facts := caster.observe(0, Time.get_ticks_msec())
	check(facts.is_read_only() and not facts.has("character") and not facts.has("player"), "observations expose detached scalar facts")
	var allies := caster.ally_facts()
	check(allies.size() == 1 and allies[0].is_read_only(), "support observations contain detached facts, not actors")
	allies.clear()
	check(world.players.size() == 1 and caster.ally_facts().size() == 1, "mutating the returned collection cannot change membership")
	var stats := caster.resolved_stats()
	stats.reach = -1000.0
	check(caster.resolved_stats().reach > 0.0, "resolved per-cast stats are not an authoritative build cache")
	# Existing skill definitions can contain the profile's selected-node array.
	# A public caster result must detach that nested path as well as its stats.
	var original_frame: int = actor.frame
	var original_profile: Dictionary = actor.character
	actor.frame = 1
	actor.character = preload("res://character_profile.gd").blank()
	var tree = world.Classes.connected_tree(1)
	actor.character[tree.profile_key] = tree.state(["thornbinder"])
	var detached_build := caster.resolved_stats()
	detached_build.affinity_build.class_skills[0].native_skill.weaver_nodes.clear()
	check(tree.focus(actor.character) == "thornbinder", "nested resolved build data cannot edit learned class selections")
	var detached_skill := caster.native_skill(0)
	detached_skill.weaver_nodes.clear()
	check(tree.focus(actor.character) == "thornbinder", "native skill inspection cannot edit learned class selections")
	actor.character = original_profile
	actor.frame = original_frame
	Actions.cast(caster, 0)
	var deadline: int = actor[Cooldowns.STATE].deadline(Cooldowns.Q)
	var serial: int = world.get_meta(&"cr02_activation_serial", 0)
	check(deadline > 0 and actor[Protection.STATE].charge_count() == 1, "the real native Q grants protection and starts its cooldown")
	Actions.cast(caster, 0)
	Actions.cast(caster, -1)
	Actions.cast(caster, 2)
	Actions.cast_world(world, 999, 0)
	check(actor[Cooldowns.STATE].deadline(Cooldowns.Q) == deadline and world.get_meta(&"cr02_activation_serial", 0) == serial, "cooling, invalid-slot and unknown-peer requests create no new action")
	Actions.cast_world(world, 1, 1)
	check(world.enemy_health() < 100 and actor[Cooldowns.STATE].deadline(Cooldowns.R) > 0, "the same path executes actual native R damage")
	actor[Cooldowns.STATE] = Cooldowns.Timers.new()
	serial = world.get_meta(&"cr02_activation_serial", 0)
	var before: int = world.enemy_health()
	var old_floor := Caster.new(world, 1)
	ExpeditionCase.set_world(world, {"combat_epoch":world.participation.epoch() + 1})
	Actions.cast(old_floor, 1)
	check(not old_floor.is_current() and world.enemy_health() == before and actor[Cooldowns.STATE].deadline(Cooldowns.R) == 0, "a captured caster cannot execute in another floor generation")
	var old_life := Caster.new(world, 1)
	actor[Lifecycle.STATE] = Lifecycle.start_life()
	Actions.cast(old_life, 1)
	check(not old_life.is_current() and world.enemy_health() == before, "previous-life actions cannot resolve against the current life")
	var old_actor := Caster.new(world, 1)
	var replacement := actor.duplicate()
	world.players[1] = replacement
	Actions.cast(old_actor, 1)
	check(not old_actor.is_current() and replacement[Cooldowns.STATE].deadline(Cooldowns.R) == 0, "even an equal-generation replacement cannot inherit a captured actor")
	check(world.get_meta(&"cr02_activation_serial", 0) == serial, "stale identities are rejected before Catalyst activation allocation")
	world.players[1] = actor
	Actions.cast_world(world, 1, 1)
	check(world.enemy_health() < before and actor[Cooldowns.STATE].deadline(Cooldowns.R) > 0, "a newly captured current-life caster still resolves normally")
	world.free()
	await process_frame
	if not failed: print("PASS: native class-action admission, detached caster facts, real Q/R, cooldown, stale floor, life and actor rejection")
	quit(1 if failed else 0)
