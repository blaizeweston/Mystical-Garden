extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

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
	ExpeditionCase.set_membership(game, p, true)
	p.pos = Vector3.ZERO
	p.frame = game.Frames.WARDEN
	p.character[game.Classes.Warden.Connected.PROFILE_KEY]=game.Classes.Warden.Connected.state(["rootkeeper"])
	p.facing = Vector3.FORWARD
	game.tactics.position = Vector3(0, 0, -2)
	game.encounter.set_hp(-1, 40)
	game.encounter.clear_scouts()
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
	game.ui.toggle_panel("pack")
	game.ui.close_panels()
	input(game, KEY_R, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.R) == 0 and controller.slot == -1, "opening an overlay cancels the preview")
	input(game, KEY_R, true)
	ExpeditionCase.set_world(game, {"encounter_number": game.participation.floor() + (1)})
	input(game, KEY_R, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.R) == 0 and controller.slot == -1, "a release after floor travel never casts")
	input(game, KEY_R, true)
	controller.get_window().focus_exited.emit()
	input(game, KEY_R, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.R) == 0, "focus loss cancels the hold")

	p.frame = game.Frames.CASTER
	p.character[game.Classes.Weaver.PROFILE_KEY]=game.Classes.Weaver.TREE.state(["thornbinder"])
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	p.facing = Vector3.BACK
	input(game, KEY_Q, true)
	check(controller.drawing.get_surface_count() == 1, "unacquired target still shows the available range")
	p.facing = Vector3.FORWARD
	controller.update_preview(p)
	input(game, KEY_Q, false)
	check(p[Cooldowns.STATE].deadline(Cooldowns.Q) > 0 and game.tactics.rooted_until > Time.get_ticks_msec(), "release uses updated direction and roots the acquired target")
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
	var field: RefCounted=game.battlefield
	for class_id in game.Classes.DEFINITIONS.size():
		p.frame=class_id
		var tree: RefCounted=game.Classes.connected_tree(class_id)
		for focus in tree.nodes.slice(0,3):
			p.character[tree.profile_key]=tree.state([focus.id])
			var stats: Dictionary=game.weapon_stats(p)
			for slot in 2:
				var skill: Dictionary=game.Skills.resolve(class_id,slot,p.character)
				var plan:=Targeting.plan(game,p,field,skill,stats,Vector3.FORWARD)
				var shapes:=Targeting.footprint(game,p,field,skill,stats,plan)
				check(not shapes.is_empty(),"current native geometry available for "+skill.name)
	# Current Veil Passage uses actor clearance for its movement preview.
	p.frame=3
	p.character[game.Classes.Reaper.PROFILE_KEY]=game.Classes.Reaper.TREE.state(["veilwalker"])
	var skill: Dictionary=game.Skills.resolve(3,0,p.character)
	var stats: Dictionary=game.weapon_stats(p)
	game.tactics.position=Vector3(2,0,1)
	field.barriers=[Rect2(-1,-2,2,1)]
	var plan:=Targeting.plan(game,p,field,skill,stats,Vector3.FORWARD)
	check(plan.endpoint.z<0 and plan.endpoint.z>-1.0,"current Veil Passage preview stops before a wall")
	field.barriers.clear()


func check_core_footprints(game: Node, p: Dictionary) -> void:
	var field: RefCounted=game.battlefield
	p.frame=0
	p.character[game.Classes.Warden.Connected.PROFILE_KEY]=game.Classes.Warden.Connected.state(["rootkeeper"])
	p.core_ready_at=0
	p.cast_until=0
	p.core_cast_until=0
	for species in ["thorn_bloom","ember_fern","dewcap","frostbell","ghost_fern","void_willow"]:
		p.weapon=game.Parts.index_of("plant:"+species)
		var skill:=Core.equipped(p)
		var preview:=Aim.footprint(game,p,field,2,Vector3.FORWARD,3.0)
		check(preview.valid and not preview.shapes.is_empty(),skill.name+" has a current Core preview")
		if skill.affinity_family=="spirit":
			check(preview.shapes[0].kind=="travel" and preview.shapes[0].to==field.dash(p.pos,p.pos+Vector3.FORWARD*float(skill.range)),"Spirit uses legal actor travel")
		else:
			var cast:=Core.aim_cast(field,p.pos,Vector3.FORWARD,skill,3.0)
			cast.skill=skill
			var geometry: Array=preload("res://core_footprint.gd").build(field,cast,p.pos)
			check(preview.shapes.filter(func(shape):return shape.kind!="range")==geometry,skill.name+" shares its host impact geometry")
