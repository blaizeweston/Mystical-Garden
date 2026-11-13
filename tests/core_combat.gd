extends SceneTree

const Core = preload("res://core_combat.gd")
const Rules = preload("res://core_skill_rules.gd")
const Settings = preload("res://app_settings.gd")
var failed := false


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL core combat: ", message)


func _initialize() -> void:
	call_deferred("run")


func legal_aim(game: Node, player: Dictionary, skill: Dictionary) -> Vector3:
	for i in 36:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 36.0).normalized()
		var line := Core.placement(game.battlefield, player.pos, direction, skill)
		if line.is_empty():
			continue
		var center: Vector3 = line.center
		var margin := direction * (float(skill.radius) + .22)
		if game.battlefield.clear_line(center - margin, center + margin):
			return direction
	return Vector3.ZERO


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/core-solo-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary = game.players[1]
	var thorn: int = game.Parts.THORN
	var moss: int = game.Parts.MOSS
	var build := Rules.resolve("0_0", [thorn, moss, 0], game.Parts.HOOK)
	check(build.primary == "thorn" and build.secondary == ["piercing"] and build.graft == ["grasp", "thorn"], "Core secondary and graft tags retain provenance")
	check(build.form == Rules.tags(moss) and build.catalyst.is_empty() and build.skill.delivery == "ground", "support provenance and Warden delivery")
	check(build == Rules.resolve("0_0", [thorn, moss, 0], game.Parts.HOOK), "resolver is deterministic")
	var swapped := Rules.resolve("0_0", [thorn, 0, moss], game.Parts.HOOK)
	check(swapped.skill == build.skill and swapped.form.is_empty() and swapped.catalyst == Rules.tags(moss), "support swaps preserve Core identity")
	check(Rules.resolve("0_0", [0, thorn, 0], 0).skill.is_empty(), "support-only weapons keep old actions")
	var migrated := Settings.normalize({"bindings": {"attack": [{"kind": "key", "code": KEY_B}]}})
	check(migrated.bindings.attack[0].code == KEY_B and migrated.bindings.core_skill[0].code == KEY_X, "old custom bindings keep their key")
	check(Settings.KEYS.core_skill == [KEY_B] and Settings.LEGACY.craft == [KEY_C], "default Core key leaves Garden crafting alone")

	p.pos = game.Stage.GATE
	game.progress.parts.fill(0)
	game.progress.parts[0] = 1
	game.progress.parts[1] = 1
	game.handle_loadout_action(1, p, "loadpart_0_1")
	game.handle_loadout_action(1, p, "loadpart_1_2")
	game.loadout_view.refresh()
	var preview: String = game.loadout_view.description.text
	check(preview.contains("Thorn Line") and preview.contains("Primary tag · Thorn") and preview.contains("Secondary tags · piercing"), "bench previews the exact prepared skill")
	check(game.progress.parts[0] == 1 and game.progress.parts[1] == 1, "selection reserves without consuming")
	game.enter_wilds(1, p)
	check(p.wild and p.weapon == thorn and p.secondary == moss and game.encounter_number == 1, "real departure crafts the selected weapon")
	check(game.progress.parts[0] == 0 and game.progress.parts[1] == 0, "departure consumes both materials once")
	check(game.weapon_stats(p).core_build.skill == Rules.resolve("0_0", [thorn, moss, 0], 0).skill, "live build matches prepared skill")
	var direction := legal_aim(game, p, build.skill)
	if direction == Vector3.ZERO:
		p.pos = game.battlefield.leader
		direction = legal_aim(game, p, build.skill)
	if direction == Vector3.ZERO:
		check(false, "generated floor has legal Warden ground")
		finish(game)
		return
	var aim := Vector2(direction.x, direction.z)
	var request := Core.request(game, p, aim)
	game.garden_action(1, request.get_slice(":", 0) + ":stale:0:1")
	game.garden_action(1, Core.request(game, p, Vector2(10, 0)))
	check(int(p.core_ready_at) == 0, "stale and invalid aim spend no cooldown")
	var saved_barriers: Array = game.battlefield.barriers.duplicate()
	game.battlefield.barriers = [Rect2(p.pos.x - 1, p.pos.z - 1, 2, 2)]
	game.garden_action(1, request)
	check(int(p.core_ready_at) == 0 and Core.hints(game).is_empty(), "blocked placement spends no cooldown")
	game.battlefield.barriers.assign(saved_barriers)

	p.facing = direction
	var press := InputEventKey.new()
	press.physical_keycode = KEY_B
	press.pressed = true
	press.echo = true
	game._unhandled_key_input(press)
	check(int(p.core_ready_at) == 0, "key echo cannot recast")
	press.echo = false
	game._unhandled_key_input(press)
	var preview_node = preload("res://ability_aim.gd").active(game)
	check(preview_node != null and preview_node.drawing.get_surface_count() == 1 and int(p.core_ready_at) == 0, "hold draws the Core footprint without spending cooldown")
	press.pressed = false
	game._input(press)
	check(preview_node.drawing.get_surface_count() == 0, "release clears the footprint")
	if not game.has_meta(Core.STATE):
		check(false, "release dispatches an authoritative cast")
		finish(game)
		return
	var line: Dictionary = game.get_meta(Core.STATE)[1]
	var cooldown: int = p.core_ready_at
	check(cooldown > Time.get_ticks_msec() and p.skill_at == 0 and p.skill_two_at == 0 and game.attack_animation_snapshot(p).form == "cast", "cast plays Warden animation with independent cooldown")
	game.garden_action(1, request)
	check(p.core_ready_at == cooldown and game.get_meta(Core.STATE).size() == 1, "one live line and repeat cannot refresh cooldown")
	check(game.battlefield.clear_line(line.from, line.to, line.skill.radius), "whole footprint lies on legal floor")
	var safe: Vector3 = line.center + direction * (line.skill.radius + .22)
	var cross: Vector3 = line.center - direction * (line.skill.radius + .22)
	game.enemy_pos = safe
	game.scouts.clear()
	Core.tick(game, line.armed - 1)
	check(Core.hints(game).is_empty(), "contact unavailable before animation release")
	Core.tick(game, line.armed)
	var hints := Core.hints(game)
	check(hints.size() == 1 and hints[0].radius == line.skill.radius, "presentation shares radius with contact")
	check(Core.contact(game.battlefield, line, safe, safe) == Vector3.INF, "outside visible radius is safe")
	check(Core.contact(game.battlefield, line, safe, cross).distance_to(line.center) < .001, "swept contact detects crossing between frames")
	game._process(.016)
	check(game.combat_visuals.hints.has(line.id), "host renders committed thorn footprint")
	check(Core.owner_state(p, Time.get_ticks_msec()).remaining > 0 and game.player_hud.state.core.name == "Thorn Line", "owner HUD shows independent cooldown")
	var scout: Dictionary = game.make_scout(0, cross, 1)
	game.scouts.assign([scout])
	game.enemy_pos = cross
	Core.tick(game, line.armed + 1)
	var struck: int = game.enemy_hp
	check(game.rooted_until == 0 and int(scout.rooted_until) == 0 and Core.hints(game).size() == 1, "thorn contact leaves a damaging line active without rooting")
	game.enemy_pos = line.center
	Core.tick(game, line.armed + 801)
	check(game.enemy_hp < struck and Core.hints(game).size() == 1, "a foe remaining in the line takes another tick")
	Core.tick(game, line.expires)
	check(Core.hints(game).is_empty(), "line disappears on expiry")
	check(game.combat_events.any(func(event): return event.kind == "proc" and event.shape == "Thorns tripped"), "trip emits feedback")
	game.enemy_hp = 0
	game.scouts.clear()
	p.pos = game.battlefield.advance
	game.use_checkpoint(1, true)
	check(game.encounter_number == 2 and p.core_ready_at == cooldown, "ordinary floor gate preserves cooldown")
	p.core_ready_at = 0
	p.core_cast_until = 0
	p.cast_until = 0
	game.garden_action(1, request)
	check(int(p.core_ready_at) == 0 and Core.hints(game).is_empty(), "old floor request is rejected")
	game._garden_action(1, "abandon_run")
	check(not p.wild and Core.owner_state(p, Time.get_ticks_msec()).is_empty(), "Garden hides the Core combat action")
	finish(game)


func finish(game: Node) -> void:
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: slot provenance, old bindings, crafting, legal placement, swept trip, cooldown and floor lifecycle")
	quit(1 if failed else 0)
