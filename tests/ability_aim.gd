extends SceneTree

const Cooldowns = preload("res://player_cooldowns.gd")

const Aim = preload("res://ability_aim.gd")
const Core = preload("res://core_combat.gd")
const Targeting = preload("res://class_ability_targeting.gd")

var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL ability aim: ", detail)


func input(game: Node, code: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	if pressed:
		game._unhandled_key_input(event)
	else:
		game._input(event)


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/ability-aim-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary = game.players[1]
	p.wild = true
	p.pos = Vector3.ZERO
	p.frame = game.Frames.WARDEN
	p.facing = Vector3.FORWARD
	game.enemy_pos = Vector3(0, 0, -2)
	game.enemy_hp = 40
	game.scouts.clear()
	game.battlefield.configure(0, 1)
	game.battlefield.barriers.clear()

	input(game, KEY_Q, true)
	var controller = Aim.active(game)
	check(controller != null and controller.drawing.get_surface_count() == 1 and p[Cooldowns.STATE].deadline(Cooldowns.Q) == 0, "self guard shows a preview without casting")
	input(game, KEY_R, true)
	input(game, KEY_R, false)
	input(game, KEY_Q, true, true)
	check(controller.slot == 0 and p[Cooldowns.STATE].deadline(Cooldowns.Q) == 0 and p[Cooldowns.STATE].deadline(Cooldowns.R) == 0, "other keys and repeats cannot commit the held slot")
	input(game, KEY_Q, false)
	var guard_cooldown: int = p[Cooldowns.STATE].deadline(Cooldowns.Q)
	check(guard_cooldown > 0 and p[Cooldowns.STATE].deadline(Cooldowns.R) == 0 and controller.drawing.get_surface_count() == 0, "matching release casts and clears")
	input(game, KEY_Q, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.Q) == guard_cooldown, "duplicate release does not cast again")
	input(game, KEY_R, true)
	game.toggle_overlay(game.pack_menu)
	game.toggle_overlay(null)
	input(game, KEY_R, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.R) == 0 and controller.slot == -1, "opening an overlay cancels the preview")
	input(game, KEY_R, true)
	game.encounter_number += 1
	input(game, KEY_R, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.R) == 0 and controller.slot == -1, "a release after floor travel never casts")
	input(game, KEY_R, true)
	controller.get_window().focus_exited.emit()
	input(game, KEY_R, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.R) == 0, "focus loss cancels the hold")

	p.frame = game.Frames.CASTER
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	p.facing = Vector3.BACK
	input(game, KEY_Q, true)
	check(controller.drawing.get_surface_count() == 1, "unacquired target still shows the available range")
	p.facing = Vector3.FORWARD
	controller.update_preview(p)
	input(game, KEY_Q, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.Q) > 0 and game.rooted_until > Time.get_ticks_msec(), "release uses updated direction and roots the acquired target")
	game.garden_action(1, "class_cast:stale:1:0:-1")
	check(p[Cooldowns.STATE].deadline(Cooldowns.R) == 0, "stale class commands cannot spend a cooldown")

	p.facing = Vector3.FORWARD
	check_class_footprints(game, p)
	check_core_footprints(game, p)
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: ability previews, class variants, release, aim and cancellation")
	quit(1 if failed else 0)


func check_class_footprints(game: Node, p: Dictionary) -> void:
	var field: RefCounted = game.battlefield
	for class_id in game.Classes.DEFINITIONS.size():
		p.frame = class_id
		var stats: Dictionary = game.weapon_stats(p)
		var definition: Dictionary = game.Classes.DEFINITIONS[class_id]
		var variants: Array = definition.skills.base + definition.skills.replace
		for node in definition.nodes:
			var change: Dictionary = node.get("skill_change", {})
			if change.get("kind") == "modify" and change.values.has("mode"):
				variants.append(definition.skills.base[int(change.slot)].merged(change.values, true))
		for skill in variants:
			var plan := Targeting.plan(game, p, field, skill, stats, Vector3.FORWARD)
			var shapes := Targeting.footprint(game, p, field, skill, stats, plan)
			check(not shapes.is_empty(), "geometry available for " + skill.name)
			if skill.mode == "bloom_detonate":
				check(not plan.valid, "bloom detonation requires an active growth field")
				game.Traits.zone(game, p, "growth", game.enemy_pos, 2.0, 2000, 1, Time.get_ticks_msec())
				plan = Targeting.plan(game, p, field, skill, stats, Vector3.FORWARD)
				shapes = Targeting.footprint(game, p, field, skill, stats, plan)
				check(plan.valid and shapes[0].at == game.enemy_pos and shapes[0].radius == skill.radius, "bloom detonation previews the active field")
				game.trait_events.clear()
	p.frame = game.Frames.WARDEN
	var stats: Dictionary = game.weapon_stats(p)
	var charge: Dictionary = game.Classes.DEFINITIONS[p.frame].skills.replace[1]
	game.enemy_pos = Vector3(2, 0, 1)
	field.barriers = [Rect2(-1, -2, 2, 1)]
	var plan := Targeting.plan(game, p, field, charge, stats, Vector3.FORWARD)
	check(plan.center.z < 0 and plan.center.z > -1.0, "charge preview stops before a wall")
	field.barriers.clear()


func check_core_footprints(game: Node, p: Dictionary) -> void:
	var field: RefCounted = game.battlefield
	p.frame = game.Frames.WARDEN
	p.core_ready_at = 0
	p.cast_until = 0
	p.core_cast_until = 0
	var parts := [game.Parts.THORN, game.Parts.MOSS, game.Parts.index_of("plant:cinder_vine"),
		game.Parts.index_of("plant:whispervine"), game.Parts.index_of("plant:star_orchid")]
	for part in parts:
		p.weapon = part
		var preview := Aim.footprint(game, p, field, 2, Vector3.FORWARD, 3.0)
		var skill := Core.equipped(p)
		var cast := Core.aim_cast(field, p.pos, Vector3.FORWARD, skill, 3.0)
		var shape_count := 3 if skill.mechanic == "anchor_beam" else 2
		check(preview.valid and preview.shapes.size() == shape_count and preview.shapes[0].radius == skill.range, skill.name + " shows reach and impact geometry")
		if skill.mechanic == "anchor_beam":
			check(preview.shapes[1].at == cast.center, "star previews its exact placement")
			check(preview.shapes[2].from == cast.center and preview.shapes[2].width == skill.radius, "hold previews the automatic beam from the planned star")
		elif skill.mechanic == "ground_burst":
			check(preview.shapes[1].at == cast.center and preview.shapes[1].radius == skill.radius, "burst uses its resolved placement and radius")
		else:
			check(preview.shapes[1].from == cast.from and preview.shapes[1].to == cast.to and preview.shapes[1].width == skill.radius, skill.name + " shares the cast capsule")
