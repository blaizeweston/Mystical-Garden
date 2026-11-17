extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Core = preload("res://core_combat.gd")
const Rules = preload("res://core_skill_rules.gd")
var failed := false


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL starter Core: ", message)


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func run() -> void:
	var game: Node = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/starter-core-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary = game.players[1]
	var classes: Array = game.Classes.DEFINITIONS
	var thorn: int = game.Parts.THORN
	var moss: int = game.Parts.MOSS
	var families := {thorn: "thorn_line", moss: "lantern_burst", game.Parts.index_of("plant:cinder_vine"): "seed_lance", game.Parts.index_of("plant:star_orchid"): "constellation", game.Parts.index_of("plant:whispervine"): "whisper_mark"}
	for definition in classes:
		for weapon in definition.weapons:
			for part in families:
				var skill: Dictionary = Rules.resolve(weapon.id, [part], 0).skill
				check(skill.get("id") == families[part] and skill.get("weapon_form") == weapon.visual, "profile for "+str(weapon.name))
				check((skill.get("delivery") != "ground") == game.WeaponMotion.is_projectile(weapon.visual), "delivery fits existing motion for "+str(weapon.name))
			check(Rules.resolve(weapon.id, [0], 0).skill.is_empty(), "empty old builds retain regular actions")
	check(game.progress.parts[0] == 0 and game.progress.parts[1] == 0, "fresh Garden starts with existing stock rules")
	p.pos = game.Stage.GATE
	ExpeditionCase.Transitions.enter(game, 1, p)
	var reserve: Dictionary = game.seed_reserve(p)
	var seeds: Array = []
	for index in 2:
		seeds.append(game.progress.roll_seed(reserve, seeds, [], game.participation.route(), .6, index+1))
	check(seeds == [0,1], "both starter species are available in the first two encounters")
	p.carried_seeds.assign(seeds)
	ExpeditionCase.set_world(game, {"encounter_number": 6})
	game.deepest_milestone = 6
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	p.pos = game.battlefield.advance
	ExpeditionCase.Transitions.checkpoint(game, 1, false)
	check(not ExpeditionCase.is_wild(p) and reserve.unknown == seeds, "starter seeds return through extraction")
	p.pos = game.Stage.ALTAR
	game.send_altar_action("identify_all", [], 1)
	check(reserve.stock[0] == 1 and reserve.stock[1] == 1, "starter seeds identify at the existing altar")
	for index in 2:
		p.seed_choice = index
		p.pos = game.Stage.PLOTS[index]
		game.plant_seed(1, index)
	game.progress.advance_growth(300.0)
	for index in 2:
		p.pos = game.Stage.PLOTS[index]
		game.send_action(false)
	check(game.progress.parts[0] == 1 and game.progress.parts[1] == 1, "both starter parts come from ordinary harvests")

	# A prepared older profile still stores only weapon and part references.
	var prior: Dictionary = p.character.duplicate(true)
	prior.active_class = 1
	prior.loadouts[1] = {"weapon":1,"parts":[moss,0,0]}
	p.character = game.Character.normalize(prior)
	game.restore_class_loadout(p)
	p.pos = game.Stage.GATE
	game.loadout_view.refresh()
	var view: Control = game.inventory_view
	view.refresh()
	check(p.prepared == moss and p.weapon_kind == 1 and p.character.loadouts[1].parts == [moss,0,0], "existing references restore without migration")
	check(game.loadout_view.description.text.contains("Lantern Burst") and view.core_skill.text.contains("Lantern Burst"), "bench and Garden inventory show the same active")
	var equipped: Control = view.equipment.get_child(0)
	view.select_entry(equipped.entry)
	check(view.details.text.contains("Lantern Burst") and not view.transfer_button.visible, "equipped Core inspection uses its own read-only details")
	ExpeditionCase.Transitions.enter(game, 1, p)
	check(ExpeditionCase.is_wild(p) and p.weapon == moss and game.progress.parts[1] == 0, "normal crafting spends only the prepared part")
	game.battlefield.configure(0, 1, 0)
	game.battlefield.barriers.clear()
	p.pos = Vector3.ZERO
	p.cast_until = 0
	game.enemy_kind = 0
	game.encounter.set_hp(-1, 20)
	game.tactics.winding_up = true
	game.tactics.stagger_until = 0
	game.encounter.clear_scouts()
	game.garden_action(1, Core.request(game, p, Vector2(0,-1)))
	var cast: Dictionary = game.get_meta(Core.STATE, {}).get(1,{})
	if not cast.is_empty():
		check(game.attack_animation_snapshot(p).clip == "Attack_wand", "Weaver plays the equipped wand's authored animation")
		var at: Vector3 = cast.center
		check(Core.aim_cast(game.battlefield,p.pos,Vector3.FORWARD,cast.skill,1.15).center.is_equal_approx(p.pos+Vector3.FORWARD*1.15), "Lantern Burst follows a near cursor")
		game.tactics.position = at
		for offset in [Vector3(.45,0,0),Vector3(0,0,.62),Vector3(-.75,0,0),Vector3(0,0,-1.35),Vector3(0,0,2.0)]:
			game.encounter.register_scout(game.make_scout(0,at+offset,1))
		Core.tick(game, cast.release)
		check(game.combat_events.any(func(event): return event.kind=="projectile" and event.shape=="orb"), "Weaver launches a visible seed")
		check(int(game.encounter.scout(0).stagger_until) == 0, "no stagger before landing")
		Core.tick(game, cast.armed)
		check(game.tactics.stagger_until == 0 and game.tactics.winding_up and game.enemy_health() == 20, "committed attacks stay readable and the burst deals no damage")
		check(game.encounter.scout_tactics().slice(0,3).all(func(scout): return int(scout.stagger_until)>cast.armed) and int(game.encounter.scout(3).stagger_until)==0 and int(game.encounter.scout(4).stagger_until)==0, "only three nearest eligible targets in the footprint stagger")
		check(game.combat_events.any(func(event): return event.shape=="lantern_burst" and float(event.reach)==1.75), "visible burst carries the actual footprint")
		check(Core.owner_state(p,Time.get_ticks_msec()).remaining>0 and not game.has_meta(Core.STATE), "burst ends while independent cooldown stays visible")
	else:
		check(false, "Lantern Burst casts with the cultivated and crafted starter part")

	p.run_upgrades={"quickroot":1}
	IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(p), 99)
	check(not ExpeditionCase.is_wild(p) and p.run_upgrades.is_empty() and Core.owner_state(p,Time.get_ticks_msec()).is_empty(), "wipe clears expedition upgrades and hides the Core action")
	p.pos=game.Stage.GATE
	game.select_class(1,p,3)
	game.handle_loadout_action(1,p,"loadpart_0_%d"%thorn)
	ExpeditionCase.Transitions.enter(game, 1,p)
	check(ExpeditionCase.is_wild(p) and p.weapon==thorn and Core.owner_state(p,Time.get_ticks_msec()).remaining==0, "fresh expedition with the Reaper starts the other starter Core ready")
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: all weapon profiles, starter extraction and harvest, prior loadouts, inventory details, wand delivery, burst, wipe and fresh Core cooldown")
	quit(1 if failed else 0)
