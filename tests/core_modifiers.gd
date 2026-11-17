extends SceneTree

const Cooldowns = preload("res://player_cooldowns.gd")

const Core = preload("res://core_combat.gd")
const Rules = preload("res://core_skill_rules.gd")
const Hurt = preload("res://enemy_hurtbox.gd")
var failed := false


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL core modifiers: ", message)


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func cast(game: Node, player: Dictionary) -> Dictionary:
	player.core_ready_at = 0
	player.core_cast_until = 0
	player.cast_until = 0
	game.garden_action(1, Core.request(game, player, Vector2(0, -1)))
	return game.get_meta(Core.STATE, {}).get(1, {})


func scout(game: Node, position: Vector3, route: int) -> Dictionary:
	var enemy: Dictionary = game.make_scout(0, position, route)
	enemy.hp = 20
	return enemy


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/core-modifiers-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var player: Dictionary = game.players[1]
	var cinder: int = game.Parts.index_of("plant:cinder_vine")
	var thorn: int = game.Parts.THORN
	var storm: int = game.Parts.index_of("plant:storm_reed")
	var fire := Rules.resolve("0_0", [cinder, cinder, cinder], 0)
	check(fire.primary == "piercing" and fire.secondary == ["fire"] and fire.skill.id == "seed_lance", "Cinder Vine keeps the piercing signature")
	check(is_equal_approx(float(fire.skill.radius),.32), "fire changes the projectile footprint")
	check(fire.skill.modifiers.size() == 1 and fire.skill == Rules.resolve("0_0", [cinder], 0).skill, "copies in the other slots do not repeat the Core modifier")
	var baseline: Dictionary = Rules.resolve("0_0", [thorn], 0).skill
	var extended: Dictionary = Rules.resolve("0_0", [thorn, cinder, storm], 0).skill
	check(extended.id == baseline.id and extended.half_length > baseline.half_length and extended.quake_reach == 1.2, "Form and Catalyst modify the same Thorn Line")
	check(Rules.resolve("0_0", [thorn, storm, cinder], 0).skill == baseline, "the same tags in the wrong slots do not apply")
	check(not Rules.resolve("2_0", [thorn, cinder, storm], 0).skill.has("quake_reach"), "Ranger does not inherit a Root Quake modifier")

	player.pos = game.Stage.GATE
	game.progress.parts.fill(0)
	game.progress.parts[game.Parts.plant_source(cinder)] = 1
	game.handle_loadout_action(1, player, "loadpart_0_%d" % cinder)
	game.loadout_view.refresh()
	check(game.loadout_view.description.text.contains("Seed Lance") and game.loadout_view.description.text.contains("Embers widen"), "Cinder preview shows both the active and its modifier")
	game.enter_wilds(1, player)
	check(player.wild and player.weapon == cinder, "Cinder loadout crafts into a playable expedition")
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	player.pos = Vector3.ZERO
	player.power = 9
	player.prepared_mark_until = Time.get_ticks_msec() + 5000
	var prepared_mark: int = player.prepared_mark_until
	game.enemy_kind = 0
	game.enemy_mutations = 0
	game.enemy_growth = 0
	game.encounter.set_hp(-1, 20)
	game.enemy_pos = Vector3(0, 0, -2.2)
	game.encounter.clear_scouts();game.encounter.register_scout(scout(game, Vector3.ZERO, 1));game.encounter.register_scout(scout(game, Vector3(0, 0, -3.5), 2));game.encounter.register_scout(scout(game, Vector3(0, 0, -4.8), 3))
	game.encounter.scout(0).pos = Vector3(Hurt.radius(game, 0) + .24, 0, -1.15)
	var lance := cast(game, player)
	if lance.is_empty():
		check(false, "Seed Lance casts on legal floor")
		await finish(game)
		return
	Core.tick(game, lance.release - 1)
	check(game.enemy_health() == 20 and int(game.encounter.hp(0)) == 20, "cast does not hit before projectile release")
	Core.tick(game, lance.release + 55)
	check(int(game.encounter.hp(0)) == 17 and game.enemy_health() == 20, "wide ember projectile hits its flank while its distant targets are untouched")
	Core.tick(game, lance.armed)
	check(game.enemy_health() == 17 and int(game.encounter.hp(1)) == 17 and int(game.encounter.hp(2)) == 20, "the lance stops damaging after three distinct targets")
	check(int(game.encounter.hp(0)) == 17 and player.prepared_mark_until == prepared_mark and game.enemy_traits.is_empty(), "a target is hit once and Core damage does not consume weapon procs")
	check(game.combat_events.any(func(event): return event.shape == "needle" and is_equal_approx(float(event.projectile_radius), .32)), "visual projectile uses actual ember radius")
	check(not game.has_meta(Core.STATE) and game.combat_events.any(func(event): return event.kind == "projectile_end" and event.shape == str(lance.flight_event)), "projectile dissipates after its last valid hit")

	game.battlefield.barriers = [Rect2(-2, -3.2, 4, .5)]
	game.enemy_pos = Vector3(0, 0, -3.8)
	game.encounter.set_hp(-1, 20)
	game.encounter.clear_scouts()
	lance = cast(game, player)
	check(not lance.is_empty() and lance.to.z > -2.7, "lance terminates before blocking terrain")
	if not lance.is_empty():
		Core.tick(game, lance.armed)
	check(game.enemy_health() == 20, "no damage through cover")
	game.battlefield.barriers.clear()

	player.weapon = thorn
	player.secondary = cinder
	player.catalyst = storm
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	game.rooted_until = 0
	game.enemy_pos = Vector3(0, 0, -3.25)
	game.encounter.set_hp(-1, 20)
	var trap := cast(game, player)
	if trap.is_empty():
		check(false, "modified thorn line casts")
		await finish(game)
		return
	check(is_equal_approx(trap.from.distance_to(trap.to), 4.3), "piercing Form lengthens the actual footprint")
	var now := Time.get_ticks_msec()
	trap.release = now - 100
	trap.armed = now - 100
	Core.tick(game, now)
	check(Core.hints(game).size() == 1 and game.rooted_until == 0, "enemy beyond the line does not trigger it by proximity alone")
	player.core_cast_until = 0
	player.cast_until = 0
	game.send_garden_action("class_skill_two")
	check(game.rooted_until > now and game.enemy_health() == 20 and Core.hints(game).size() == 1, "Root Quake lashes at an enemy outside the quake and preserves the line")
	check(game.combat_events.any(func(event): return event.shape == "Thorn lash"), "Root Quake lash is visible")
	await finish(game)


func finish(game: Node) -> void:
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Seed Lance, visible secondary modifiers, capped swept damage, terrain, Form and Root Quake Catalyst")
	quit(1 if failed else 0)
