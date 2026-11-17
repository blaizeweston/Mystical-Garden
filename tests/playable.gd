extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")

const World := preload("res://world.tscn")
const Stage := preload("res://stage.gd")
const Progress := preload("res://progress.gd")
const Parts := preload("res://weapon_parts.gd")
const Frames := preload("res://weapon_frames.gd")
const Campaign := preload("res://campaign.gd")
const Character := preload("res://character_profile.gd")
const Battlefield := preload("res://battlefield.gd")
const Enemies := preload("res://enemy_catalog.gd")

class SyncProbe extends Node:
	var received := {}
	@rpc("any_peer", "call_remote", "reliable")
	func acknowledge(marker: String) -> void:
		received[marker] = true

var probe: SyncProbe
var game: Node
var failed := false
var extraction_fixture := false


func _initialize() -> void:
	preload("res://combat_balance_preview.gd").enabled = false
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failed = true


func run() -> void:
	probe = SyncProbe.new()
	probe.name = "TestSyncProbe"
	root.add_child(probe)
	game = World.instantiate()
	game.map_rng.seed = 8461
	var mode: String = OS.get_cmdline_user_args()[0]
	game.progress.path = "res://.godot/check_%s_%s.cfg" % [mode, Crypto.new().generate_random_bytes(8).hex_encode()]
	game.local_character.path = game.progress.path + ".character"
	game.guest_character.path = game.progress.path + ".guest"
	root.add_child(game)
	match mode:
		"solo":
			await verify_loop()
		"host":
			await verify_host()
		"guest":
			await verify_guest()
		_:
			check(false, "Unexpected test mode")
	if not failed:
		print("PASS: ", mode)
	quit(1 if failed else 0)


func place(id: int, where: Vector3) -> void:
	game.players[id].hurt_until=0 # Isolate explicitly positioned mechanic fixtures from prior contacts.
	if where==Stage.GATE and not ExpeditionCase.is_wild(game.players[id]):
		var p: Dictionary=game.players[id]
		# These combat fixtures deliberately choose bare slots when a saved plan
		# lacks materials; classes_weapons tests the normal gate rejection.
		for slot in ["prepared","prepared_secondary","prepared_catalyst"]:
			var part:=int(p[slot])
			if part!=0 and (not Parts.is_plant(part) or game.available_parts(p,part)==0): p[slot]=0
	# Most mechanic fixtures use authored cover and exact positions.
	if game.participation.seed() != 0 and game.multiplayer.is_server():
		ExpeditionCase.set_world(game, {"map_seed": 0})
		game.battlefield.configure(game.participation.route(), game.participation.depth())
	if where == Stage.GATE and ExpeditionCase.is_wild(game.players[id]):
		game.players[id].pos = game.battlefield.advance
		extraction_fixture = true
	else:
		game.players[id].pos = where


func verify_loop() -> void:
	var start: Vector3 = game.players[1].pos
	Input.action_press("up")
	await create_timer(0.20).timeout
	Input.action_release("up")
	check(game.players[1].pos.z < start.z - 0.25, "normal movement input")
	for kind in 2:
		await create_timer(0.50).timeout
		place(1, Stage.GATE)
		interact()
		check(ExpeditionCase.is_wild(game.players[1]), "entry to the Wilds")
		game.encounter.clear_scouts()
		game.encounter.set_hp(-1, 3) # Fixed three-contact acquisition fixture, independent of encounter tuning.
		# Keep pickup and gate interaction separate even when the elite spawns at the exit.
		game.tactics.position=Vector3(0,0,5.4)
		place(1, game.tactics.position + Vector3(1.2, 0, 0))
		for strike in 3:
			game.players[1].strike_at = 0
			game.send_action(true)
			game.update_projectiles(Time.get_ticks_msec()+1000)
			if strike < 2:
				await create_timer(0.47).timeout
		check(game.has_drop and game.enemy_health() == 0, "three strikes drop a seed")
		place(1, game.drop_pos)
		interact()
		interact()
		check(game.progress.unknown.is_empty() and game.players[1].carried_seeds == [kind],
			"pickup occurs only once and does not bank loot")
		place(1, Stage.GATE)
		interact()
		check(not ExpeditionCase.is_wild(game.players[1]), "return to the Garden")
		place(1, Stage.PLOTS[kind])
		interact()
		check(not game.progress.planted[kind], "unidentified seed cannot be planted")
		place(1, Stage.ALTAR)
		interact()
		interact()
		check(game.progress.unknown.is_empty() and game.progress.stock[kind] == 1,
			"altar identifies exactly one seed")
		place(1, Stage.PLOTS[kind])
		interact()
		check(game.progress.planted[kind] and game.progress.stock[kind] == 0, "planting spends the seed")
	var reload := Progress.new()
	reload.path = game.progress.path
	check(reload.load_garden() == OK and reload.planted.slice(0,3) == [true, true, false]
		and reload.stock.slice(0,3) == [0, 0, 0] and reload.unknown.is_empty(), "Garden restored from disk")
	game.progress.advance_growth(86400.0)
	place(1, Stage.PLOTS[0])
	interact()
	place(1, Stage.GATE)
	game.send_garden_action("craft")
	place(1, Stage.GATE)
	interact()
	check(game.players[1].weapon == 1 and game.progress.parts[0] == 0 and game.progress.knowledge == 12,
		"departure crafts the prepared blade and spends a part")
	await create_timer(0.50).timeout
	# Isolate weapon reach from randomized encounter placement, optional cover
	# and scouts that may otherwise become the nearest eligible target.
	game.encounter.clear_scouts()
	game.battlefield.barriers.clear()
	game.tactics.position=Vector3(0,0,5.4)
	game.players[1].strike_at=0
	place(1, game.tactics.position + Vector3(2.75, 0, 0))
	game.encounter.set_hp(-1, 3)
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_health() == 2, "crafted Thorn Bloom blade extends strike range")
	game.encounter.clear_scouts()
	await verify_briar_strike()
	await verify_expedition()
	await verify_garden_growth()
	await verify_altar_experiment()
	await verify_upgrade_route()
	await verify_hook_grafting()
	verify_synergy_research()
	verify_modular_parts()
	await verify_class_frames()
	await verify_adaptation()
	verify_character_progress()
	verify_endless_route()
	await verify_spaced_pack()
	verify_seed_variety()
	ExpeditionCase.set_world(game, {"destination": Campaign.HOLLOW})
	ExpeditionCase.set_world(game, {"depth": 5})
	game.reset_encounter()
	check(game.encounter.scout_count()>=6 and game.encounter.scout_count()<=game.EncounterConfig.MAX_SCOUTS and game.enemy_health()>0, "late encounters field larger bounded packs")
	for scout in game.encounter.scout_tactics():
		check(not game.battlefield.occupied(scout.pos, Battlefield.CLEARANCE),
			"large packs spawn clear of cover")


func verify_expedition() -> void:
	var starting_health: int=game.encounter_health()
	place(1, Stage.GATE)
	interact()
	check(ExpeditionCase.is_wild(game.players[1]), "cannot extract during a live encounter")
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 1)
	await create_timer(0.50).timeout
	place(1, game.tactics.position)
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	interact()
	place(1, Stage.DEEPER_GATE)
	interact()
	check(game.participation.depth() == 2 and game.enemy_health() > starting_health and game.players[1].carried_seeds.size() == 1,
		"descending starts a tougher encounter and carries loot forward")
	game.players[1][PlayerVitals.STATE] = game.players[1][PlayerVitals.STATE].with_hp(1)
	game.players[1].hurt_until=0
	place(1, game.tactics.position)
	preload("res://leader_behavior.gd").resolve(game, Time.get_ticks_msec())
	check(not ExpeditionCase.is_wild(game.players[1]) and game.players[1].weapon == 0
		and game.players[1].carried_seeds.is_empty()
		and game.progress.unknown.is_empty() and game.participation.depth() == 1,
		"a wipe loses unbanked loot and resets the route")
	place(1, Stage.GATE)
	interact()
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	place(1, Stage.DEEPER_GATE)
	interact()
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 1)
	await create_timer(0.50).timeout
	place(1, game.tactics.position)
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	interact()
	check(game.players[1].carried_seeds.size() == 2, "deeper briar yields two seeds")
	place(1, Stage.GATE)
	interact()
	check(not ExpeditionCase.is_wild(game.players[1]) and game.progress.unknown.size() == 2
		and game.players[1].carried_seeds.is_empty(), "extracting banks all carried seeds")
	var reload := Progress.new()
	reload.path = game.progress.path
	check(reload.load_garden() == OK and reload.unknown.size() == 2, "extracted seeds persist")


func verify_garden_growth() -> void:
	place(1, Stage.HEART)
	game.send_garden_action("research")
	check(game.progress.studying_flowering, "study begins at the Heart")
	place(1, Stage.GATE)
	interact()
	ExpeditionCase.set_world(game, {"depth": 2})
	game.deepest_milestone = 2
	game.players[1].carried_seeds.assign([0, 1])
	game.send_garden_action("pouch")
	game.send_garden_action("pouch")
	game.players[1][PlayerVitals.STATE] = game.players[1][PlayerVitals.STATE].with_hp(1)
	game.players[1].hurt_until=0
	place(1, game.tactics.position)
	preload("res://leader_behavior.gd").resolve(game, Time.get_ticks_msec())
	check(game.progress.unknown.size() == 3 and game.progress.unknown[2] == 0 and not game.players[1].pouch,
		"one protected seed survives a wipe")
	check(game.progress.research_points == 2, "wipe credits deepest milestone only")
	place(1, Stage.PLOTS[1])
	interact()
	place(1, Stage.GATE)
	game.send_garden_action("craft")
	place(1, Stage.GATE)
	interact()
	check(game.players[1].weapon == 2 and game.progress.knowledge == 16,
		"Mossguard crafts from a Lantern Moss part")
	await create_timer(0.50).timeout
	place(1, game.tactics.position)
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.tactics.recovery_bonus == 700, "Mossguard strike marks the enemy")
	var now := Time.get_ticks_msec()
	preload("res://leader_behavior.gd").resolve(game, now)
	check(game.tactics.ready_at == now + game.Director.recovery(game,750) + 700 and game.tactics.recovery_bonus == 0,
		"Mossguard extends the next attack recovery")
	game.players[1][PlayerVitals.STATE] = game.players[1][PlayerVitals.STATE].with_hp(1)
	game.players[1].hurt_until=0
	preload("res://leader_behavior.gd").resolve(game, now)
	# Replant between each harvest; growth is advanced explicitly in this fixture.
	place(1, Stage.PLOTS[0])
	game.progress.stock[0] = 1
	game.players[1].seed_choice = 0
	interact()
	game.progress.advance_growth(86400.0)
	interact()
	place(1, Stage.HEART)
	game.progress.heart.unlock_direct("infusion")
	game.progress.parts[0] += 1
	game.send_garden_action("research")
	check(game.progress.parts[0] == 0, "infusion spends two crafting parts")
	check(game.progress.flowering_unlocked and not game.progress.studying_flowering,
		"qualifying milestones unlock flowering")
	place(1, Stage.PLOTS[0])
	game.progress.stock[0] = 1
	interact()
	game.progress.advance_growth(86400.0)
	interact()
	check(game.progress.parts[0] == 1 and game.progress.plots[0].species == -1,
		"ordinary harvest gives one part and clears the bed")
	game.progress.stock[0] = 1
	interact()
	game.send_garden_action("flower")
	interact()
	check(not game.progress.flowering[0] and game.progress.stock[0] == 0,
		"seed harvesting waits for crop maturity without resetting growth")
	game.progress.advance_growth(86400.0)
	game.send_garden_action("flower")
	check(game.progress.stock[0] == 2 and game.progress.parts[0] == 1
		and game.progress.plots[0].species == -1, "flowering yields a seed and clears the bed")
	var reload := Progress.new()
	reload.path = game.progress.path
	check(reload.load_garden() == OK and reload.flowering_unlocked and reload.stock[0] == 2
		and reload.parts[0] == 1 and reload.knowledge == 16, "research and harvest outcomes persist")


func verify_altar_experiment() -> void:
	place(1, Stage.ALTAR)
	game.progress.stock.assign([3, 2, 0])
	var knowledge: int = game.progress.knowledge
	game.send_garden_action("experiment")
	check(game.progress.stock.slice(0,3) == [2, 1, 1] and game.progress.veilcap_discovered
		and game.progress.knowledge == knowledge + 4, "compatible pair always discovers Veilcap")
	game.send_garden_action("experiment")
	check(game.progress.stock.slice(0,3) == [1, 0, 2] and game.progress.knowledge == knowledge + 4,
		"known recipe reproduces without repeating discovery knowledge")
	game.send_garden_action("experiment")
	check(game.progress.stock.slice(0,3) == [1, 0, 2], "insufficient seeds leave inventory untouched")
	game.send_garden_action("craft")
	var old_parts: int = game.progress.parts[0]
	game.send_garden_action("experiment")
	check(game.progress.stock[0] == 1 and game.progress.parts[0] == old_parts,
		"same-species offering requires two seeds")
	game.progress.stock[0] = 2
	game.send_garden_action("experiment")
	check(game.progress.stock.slice(0,3) == [0, 0, 2] and game.progress.parts[0] == old_parts + 1,
		"incompatible pair returns one part")
	place(1, Stage.PLOTS[2])
	game.players[1].seed_choice = 2
	interact()
	game.progress.advance_growth(86400.0)
	interact()
	var reload := Progress.new()
	reload.path = game.progress.path
	check(reload.load_garden() == OK and reload.veilcap_discovered and not reload.planted[2]
		and reload.parts[2] == 1, "recipe, Veilcap planting and harvest persist")
	place(1, Stage.GATE)
	for step in 3:
		if game.players[1].prepared == 3:
			break
		game.send_garden_action("craft")
	place(1, Stage.GATE)
	interact()
	check(game.players[1].weapon == 3 and game.progress.parts[2] == 0,
		"Veilstrike consumes a Veilcap part")
	await create_timer(0.50).timeout
	place(1, game.tactics.position)
	game.encounter.set_hp(-1, 3) # Fixed wind-up damage fixture.
	game.tactics.winding_up = true
	game.tactics.strike_at = Time.get_ticks_msec() + 650
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_health() == 0, "Veilstrike and its arcane Core exploit wind-up")


func verify_upgrade_route() -> void:
	for room in range(1, game.CHECKPOINT_INTERVAL + 1):
		check(game.participation.depth() == room, "route advances one room at a time")
		place(1, Stage.DEEPER_GATE)
		game.send_garden_action("upgrade_power")
		check(game.wallet_for(game.players[1]).spent_essence() == 0, "live encounter does not offer upgrades")
		await create_timer(0.50).timeout
		# Test the checkpoint, independently of a randomly placed enemy or its drops.
		game.encounter.clear_scouts()
		game.battlefield.barriers.clear()
		game.tactics.position = Vector3(0, 0, 5.4)
		game.encounter.set_hp(-1, 1)
		game.enemy_mutations = 0
		place(1, game.tactics.position + Vector3.RIGHT)
		game.players[1].facing = Vector3.LEFT
		game.players[1].strike_at = 0
		game.send_action(true)
		game.update_projectiles(Time.get_ticks_msec()+1000)
		check(game.encounter_cleared(), "the fixed target clears before checking the gate")
		place(1, Stage.DEEPER_GATE)
		if room < game.CHECKPOINT_INTERVAL:
			game.send_garden_action("upgrade_power")
			check(game.wallet_for(game.players[1]).spent_essence() == 0, "earlier rooms do not offer upgrades")
			ExpeditionCase.Transitions.checkpoint(game, 1,true)
	check(game.deepest_milestone == game.CHECKPOINT_INTERVAL, "clears earn run currency")
	# This fixture skips all scout rewards; fund the forced technique card separately.
	var missing:=maxi(0,int(game.RunUpgrades.get_upgrade("technique").cost)-game.run_wallet(game.players[1]))
	var funding_sparks := missing * int(game.Director.config().essence_sparks_per_point)
	game.players[1][game.ExpeditionWallet.STATE] = game.wallet_for(game.players[1]).credit_sparks(funding_sparks)
	game.players[1].offer_floor=game.participation.floor()
	game.players[1].checkpoint_offers=["power","technique","reach"]
	ExpeditionCase.Transitions.checkpoint(game, 1,true)
	game.send_garden_action("upgrade_technique")
	game.send_garden_action("upgrade_power")
	check(game.players[1].technique == 1 and game.wallet_for(game.players[1]).spent_essence() == 8
		and game.players[1].power == 0, "checkpoint allows exactly one purchase")
	ExpeditionCase.Transitions.checkpoint(game, 1,true)
	check(game.participation.depth() == game.CHECKPOINT_INTERVAL+1 and game.players[1].technique == 1,
		"upgrade carries into the next room")
	await create_timer(0.50).timeout
	place(1, game.tactics.position)
	game.tactics.winding_up = true
	game.tactics.strike_at = Time.get_ticks_msec() + 650
	game.encounter.clear_scouts();game.enemy_mutations=0;game.encounter.set_hp(-1, maxi(8,game.enemy_health()))
	var hp: int = game.enemy_health()
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_health() == hp - 4, "Veilstrike technique boosts wind-up damage")
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	place(1, Stage.GATE)
	interact()
	check(game.wallet_for(game.players[1]).spent_essence() == 0 and game.players[1].technique == 0,
		"extraction resets wallet and upgrades")


func seed_for_roll(threshold: float, succeeds: bool) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in 100:
		probe.seed = candidate
		if (probe.randf() < threshold) == succeeds:
			return candidate
	return -1


func verify_hook_grafting() -> void:
	game.leave_game("Four-slot graft fixture")
	var p: Dictionary=game.players[1]
	place(1,Stage.HEART)
	game.select_class(1,p,Frames.WARDEN)
	game.progress.parts[2]=1
	p.prepared=Parts.VEIL
	p.prepared_secondary=0
	p.prepared_catalyst=0
	game.progress.personal_parts[Parts.HOOK]=1
	place(1,Stage.GATE)
	game.handle_loadout_action(1,p,"pack_4")
	place(1,Stage.GATE)
	interact()
	check(ExpeditionCase.is_wild(p) and p.carried_parts[Parts.HOOK]==1 and p.graft_part==0,"stash trophy departs as uninstalled cargo")
	ExpeditionCase.set_world(game, {"depth": game.GRAFT_ROOM})
	ExpeditionCase.set_world(game, {"encounter_number": game.GRAFT_ROOM})
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 5)
	p.pos=game.battlefield.graft
	p.carried_parts[Parts.HOOK]=3
	p.carried_parts[Parts.THORN]=1
	p.graft_choice=Parts.HOOK
	for attempt in 2:
		game.rng.seed=seed_for_roll(game.graft_chance(p,Parts.HOOK),false)
		game.send_garden_action("graft_install_4")
	check(p.carried_parts[Parts.HOOK]==1 and p.graft_part==0,"failed grafts consume only monster cargo")
	p.technique=1
	game.rng.seed=seed_for_roll(game.graft_chance(p,Parts.HOOK),true)
	game.send_garden_action("graft_install_4")
	check(p.graft_part==Parts.HOOK and p.weapon==Parts.VEIL and p.secondary==0 and p.technique==1,"fourth-slot graft preserves plant slots and upgrades")
	game.send_garden_action("graft_install_4")
	check(p.carried_parts[Parts.THORN]==1,"filled monster slot cannot consume plant material")
	game.encounter.set_hp(-1, 0)
	ExpeditionCase.set_world(game, {"encounter_number": 12})
	ExpeditionCase.set_world(game, {"depth": 5})
	game.deepest_milestone=12
	p.pos=game.battlefield.advance
	p.offer_floor=12
	p.checkpoint_offers=["power","technique","rift_hook"]
	p.last_offer=0
	p[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(game.wallet_for(p).earned_sparks(), 0)
	game.buy_upgrade(1,p,2)
	check(p.rift_hook and game.wallet_for(p).spent_essence()==12 and game.progress.rift_hook_discovered,"Veil plant plus monster Hook can unlock Rift synergy")
	game.send_garden_action("extract")
	check(not ExpeditionCase.is_wild(p) and p.graft_part==0,"extract clears installed monster graft")


func verify_synergy_research() -> void:
	var study := Progress.new()
	study.path = game.progress.path + ".study"
	study.flowering_unlocked = true
	study.veilcap_discovered = true
	study.studying_rift_hook = true
	study.apply_milestone(3)
	check(study.rift_research_points == 3 and not study.rift_hook_discovered,
		"synergy research takes qualifying milestones")
	study.save_garden()
	var reload := Progress.new()
	reload.path = study.path
	check(reload.load_garden() == OK and reload.studying_rift_hook and reload.rift_research_points == 3,
		"partial synergy study survives reload")
	reload.apply_milestone(1)
	reload.discover_rift_hook()
	check(reload.rift_hook_discovered and not reload.studying_rift_hook and reload.knowledge == 4,
		"finishing a study records knowledge exactly once")


func verify_modular_parts() -> void:
	check(is_equal_approx(Parts.effect(Parts.MOSS, Parts.THORN, "reach", 1), 0.9)
		and Parts.effect(Parts.MOSS, Parts.THORN, "recovery", 1) == 1000.0,
		"both slots contribute effects and technique follows primary")
	check(Parts.has_rift_pair(Parts.HOOK, Parts.VEIL) and Parts.has_rift_pair(Parts.VEIL, Parts.HOOK),
		"synergy follows the installed pair in either order")
	var p: Dictionary = game.players[1]
	ExpeditionCase.set_world(game, {"depth": game.GRAFT_ROOM})
	ExpeditionCase.set_world(game, {"encounter_number": game.GRAFT_ROOM})
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	p.secondary = Parts.EMPTY
	p.graft_part = Parts.EMPTY
	ExpeditionCase.set_membership(game, p, true)
	p.carried_parts[Parts.HOOK] = 1
	p.carried_parts[Parts.THORN] = 1
	p.graft_choice = Parts.HOOK
	place(1, Stage.GRAFT_ALTAR)
	game.send_garden_action("select_graft")
	game.rng.seed = seed_for_roll(game.graft_chance(p, Parts.HOOK), true)
	game.send_garden_action("graft_install_4")
	check(p.graft_part == Parts.HOOK and p.secondary == 0 and p.carried_parts[Parts.THORN] == 1,
		"Wilds altar accepts monster parts and leaves carried plants untouched")


func verify_class_frames() -> void:
	var p: Dictionary = game.players[1]
	game.leave_game("Class test reset")
	p = game.players[1]
	place(1, Stage.GATE)
	game.send_garden_action("frame")
	check(p.frame == Frames.WARDEN, "class selection is restricted to the Heart")
	place(1, Stage.HEART)
	game.send_garden_action("frame")
	check(p.frame == Frames.CASTER, "Heart can select caster")
	game.progress.parts[0] = 1
	place(1,Stage.GATE)
	game.send_garden_action("craft")
	place(1, Stage.GATE)
	interact()
	check(p.weapon == Parts.THORN and p.frame == Frames.CASTER, "staff fits the same Thorn part")
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 3) # Skill reach fixture.
	place(1, game.tactics.position + Vector3.RIGHT * 4.5)
	var before: Vector3 = game.tactics.position
	game.send_garden_action("class_skill")
	var ready_at: int = p[Cooldowns.STATE].deadline(Cooldowns.Q)
	check(game.tactics.rooted_until > Time.get_ticks_msec(), "Rootbind applies in range")
	game.send_garden_action("class_skill")
	check(p[Cooldowns.STATE].deadline(Cooldowns.Q) == ready_at, "class cooldown prevents repeat casting")
	await physics_frame
	await physics_frame
	check(game.tactics.position.is_equal_approx(before), "Rootbind stops pursuit")
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	await wait_for_projectiles()
	check(game.enemy_health() == 2, "staff and Thorn reach combine")
	game.send_garden_action("frame")
	check(p.frame == Frames.CASTER, "frame cannot change mid-expedition")
	game.leave_game("Guard test reset")
	p = game.players[1]
	place(1,Stage.HEART)
	game.select_class(1,p,Frames.WARDEN)
	place(1, Stage.GATE)
	interact()
	place(1, game.tactics.position)
	game.send_garden_action("class_skill")
	var now := Time.get_ticks_msec()
	preload("res://leader_behavior.gd").resolve(game, now)
	check(PlayerVitals.current_hp(p) == game.MAX_HEALTH and p.guard_until == 0, "Guard blocks one hit and is spent")
	preload("res://leader_behavior.gd").resolve(game, now)
	check(PlayerVitals.current_hp(p) == game.MAX_HEALTH - 1, "Guard does not block a second hit")


func verify_adaptation() -> void:
	game.progress.wilds_memory=game.Learning.blank()
	game.progress.burst_pressure=0;game.progress.choke_pressure=0
	game.leave_game("Adaptation test reset")
	var p: Dictionary = game.players[1]
	place(1, Stage.HEART)
	game.send_garden_action("frame")
	place(1, Stage.GATE)
	interact()
	ExpeditionCase.set_world(game, {"depth": 3})
	ExpeditionCase.set_world(game, {"encounter_number": 3})
	game.reset_encounter()
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 2)
	game.ranged_clears = 1
	for i in 2:
		place(1, game.tactics.position + Vector3.RIGHT * 3.4)
		p.strike_at = 0
		game.send_action(true)
		game.update_projectiles(Time.get_ticks_msec()+1000)
		if i == 0:
			await create_timer(0.75).timeout
	await wait_for_projectiles()
	check(game.ranged_clears == 2, "distant strikes contribute to adaptive pressure")
	place(1, Stage.DEEPER_GATE)
	interact()
	check(game.participation.depth() == 4 and (game.current_mutations(0,0,0)&Enemies.REACH)!=0, "deep encounter can adapt during the run across a varied elite pool")
	game.tactics.longlimb=true # Isolate the wider-telegraph contact fixture from species-specific mutation rolls.
	var hp: int = PlayerVitals.current_hp(p)
	place(1, game.tactics.position + Vector3.RIGHT * 2.5)
	preload("res://leader_behavior.gd").resolve(game, Time.get_ticks_msec())
	check(PlayerVitals.current_hp(p) == hp - 1, "Longlimb hits within its wider telegraph")
	game.ranged_clears = 3
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	place(1, Stage.GATE)
	interact()
	var reload := Progress.new()
	reload.path = game.progress.path
	check(reload.load_garden() == OK and reload.ranged_pressure >= 3, "host world remembers the tactic")
	place(1, Stage.GATE)
	interact()
	check(not game.tactics.longlimb, "opening room stays at base difficulty")
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	place(1, Stage.DEEPER_GATE)
	interact()
	ExpeditionCase.set_world(game, {"depth": 4});ExpeditionCase.set_world(game, {"encounter_number": 4});game.reset_encounter()
	check((game.current_mutations(0,0,0)&Enemies.REACH)!=0, "later expedition can use saved adaptation after the protected opening")
	var learned: int = reload.ranged_pressure
	reload.remember_expedition(0)
	check(reload.ranged_pressure == learned, "pressure persists through one different expedition")
	reload.remember_expedition(0)
	check(reload.ranged_pressure == learned - 1, "pressure fades gradually")


func verify_character_progress() -> void:
	game.leave_game("Character test reset")
	var p: Dictionary = game.players[1]
	var profile: Dictionary = p.character
	check(profile.xp[Frames.WARDEN] > 0 and profile.xp[Frames.CASTER] > 0,
		"combat XP is tracked separately by class")
	check(profile.plants[0] > 0 and profile.monsters.reduce(func(a,b): return a+int(b),0)>0,
		"cultivation and combat award different familiarity")
	var reload := Character.new()
	reload.path = game.local_character.path
	check(reload.load_profile() == OK and reload.data == profile, "character file survives reload")
	place(1, Stage.HEART)
	game.select_class(1,p,Frames.WARDEN)
	var before: float = game.graft_chance(p, Parts.THORN)
	game.send_garden_action("trait")
	check(profile.traits[Frames.WARDEN] == 0 and is_equal_approx(game.graft_chance(p, Parts.THORN),before),
		"retired affinity cannot grant graft bonuses")
	game.send_garden_action("trait")
	place(1, Stage.GATE)
	interact()
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 1)
	place(1, game.tactics.position)
	var encountered_kind: int=game.enemy_kind
	var familiarity_before: int=profile.monsters[encountered_kind]
	p.strike_at=0
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.enemy_health()==0 and profile.monsters[encountered_kind]==familiarity_before+1, "combat builds familiarity for the actual encountered species")
	place(1, Stage.GATE)
	interact()
	place(1, Stage.PLOTS[0])
	game.progress.stock[0] += 1
	game.players[1].seed_choice = 0
	interact()
	game.progress.advance_growth(86400.0)
	var common: int = game.progress.parts[0]
	var rare: int = game.progress.heartwood_barbs
	game.rng.seed = seed_for_roll(game.rare_harvest_chance(profile.plants[0]), true)
	interact()
	check(game.progress.parts[0] == common + 1 and game.progress.heartwood_barbs == rare + 1,
		"rare harvest adds a barb alongside the guaranteed part")
	check(Parts.effect(Parts.MOSS, Parts.HEARTWOOD, "damage", 0) == 1.0,
		"rare part fits the modular secondary slot")


func restore_heart_fixture() -> void:
	# This fixture represents many completed restoration expeditions.
	for expedition in 3: game.progress.campaign.advance_growth()
	game.progress.flowering_unlocked = true
	game.progress.veilcap_discovered = true
	game.progress.rift_hook_discovered = true
	game.progress.knowledge = Campaign.FULL_KNOWLEDGE
	game.progress.campaign.memories.assign(Campaign.MEMORY_REQUIREMENTS)
	for technology in game.HeartCatalog.required_core(): game.progress.heart.unlock_direct(technology)
	for technology in ["memory_grove","memory_mire","memory_hollow","perfect_recollection"]: game.progress.heart.unlock_direct(technology)


func verify_endless_route() -> void:
	game.leave_game("Endless test reset")
	game.progress.campaign = Campaign.new()
	game.progress.parts.assign([0, 0, 0])
	var p: Dictionary = game.players[1]
	p.prepared=0
	p.prepared_secondary=0
	p.prepared_catalyst=0
	p.character.loadouts[p.frame].parts=[0,0,0]
	p.pos = Stage.GATE
	interact()
	check(ExpeditionCase.is_wild(p) and game.participation.seed() > 0, "free Grove departure generates a map")
	var original_seed: int = game.participation.seed()
	var original_layout: Array = game.battlefield.barriers.duplicate()
	var original_clearings: Array = game.battlefield.clearings.duplicate()
	var carried_before: int = p.carried_seeds.size()
	p.pos = game.battlefield.cache
	interact()
	interact()
	check(p.carried_seeds.size() == carried_before + 1 and p.cache_claimed,
		"exploring the side clearing awards one personal seed cache")
	game.send_garden_action("pouch")
	check(p.pouch, "a side-clearing discovery can be protected before fighting")
	check(Battlefield.layout(Campaign.GROVE, 1, original_seed) == original_layout,
		"host and guest can reproduce the same terrain")
	var previous_health := 0
	for site in [Campaign.GROVE, Campaign.MIRE, Campaign.HOLLOW]:
		check(game.participation.route() == site and game.participation.depth() == 1, "free route traverses biomes in order")
		for local_encounter in game.ROUTE_ROOMS:
			game.encounter.clear_scouts()
			game.encounter.set_hp(-1, 1)
			p.pos = game.tactics.position
			p.strike_at = 0
			game.send_action(true)
			game.update_projectiles(Time.get_ticks_msec()+1000)
			var floor_before: int=game.participation.floor()
			check(game.encounter_cleared(),"route fixture defeats the leader on floor %d" % floor_before)
			p.pos = game.battlefield.advance
			# A generated cache or nearby loot can receive E before the gate.
			for attempt in 6:
				interact()
				if game.participation.floor()!=floor_before:break
			check(game.participation.floor()==floor_before+1,"onward gate advances floor %d" % floor_before)
		previous_health = game.encounter_health()
	check(game.participation.route() == Campaign.GROVE and game.participation.cycle() == 1
		and game.participation.floor() == 19 and previous_health > game.ENEMY_HEALTH,
		"crossing the Hollow loops into a harder cycle")
	check(game.participation.seed() != original_seed and game.battlefield.clearings != original_clearings,
		"later encounters generate different terrain")
	# A random rare boss on floor 19 correctly disables reinforcements.
	# Exercise normal encounter pressure independently of the boss roll.
	game.tactics.boss_kind = -1
	var hp: int = PlayerVitals.current_hp(p)
	var now := Time.get_ticks_msec()
	game.pressure_at = now
	game.update_pressure(now)
	check(PlayerVitals.current_hp(p) == hp and game.pressure_at > now, "overstaying schedules avoidable reinforcements without automatic damage")
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	# Fast-forward the fixture to the next cleared extraction checkpoint.
	ExpeditionCase.set_world(game, {"encounter_number": 24})
	game.deepest_milestone = 24
	p.pos = game.battlefield.advance
	game.send_garden_action("extract")
	check(game.progress.campaign.cleared == [true, true, true], "extracting records all guardians defeated")
	var saved := Progress.new()
	saved.path = game.progress.path
	check(saved.load_garden() == OK and saved.campaign.best_clear == 24
		and saved.campaign.best_extraction == 24, "endless depth records persist")
	check(saved.campaign.memories == [1, 1, 1], "banked guardian memories persist")
	game.progress.campaign.record_guardian_memories(1 << Campaign.MIRE)
	check(game.progress.campaign.memories == [1, 2, 1], "a repeat expedition adds memory only for its guardian")
	p.pos = Stage.GATE
	game.send_garden_action("destination")
	interact()
	check(game.participation.route() == Campaign.MIRE and not ExpeditionCase.is_wild(p), "unfunded shortcuts cannot depart")
	game.progress.parts.assign([1, 1, 0])
	interact()
	check(ExpeditionCase.is_wild(p) and game.progress.parts.slice(0,3) == [0, 0, 0], "paid shortcut spends the quoted cost once")


func verify_spaced_pack() -> void:
	game.leave_game("Pack test reset")
	game.map_rng.seed = 8461
	place(1, Stage.GATE)
	interact()
	var player: Dictionary = game.players[1]
	var entry: Vector3 = player.pos
	var initial_enemy: Vector3 = game.tactics.position
	check(entry.distance_to(initial_enemy) > 12.0, "spawn leaves room to plan an approach")
	await create_timer(1.25).timeout
	check(not game.tactics.engaged and game.tactics.position == initial_enemy and PlayerVitals.current_hp(player) == game.MAX_HEALTH,
		"enemy waits outside engagement range")
	place(1, Vector3(12, 0, 8))
	game.move_player(1, Vector2.RIGHT, 0.1)
	check(player.pos.x > 12.0, "player can use the expanded Wilds bounds")
	# The director starts reserving a control slot at floor four. Partner order can vary.
	ExpeditionCase.set_world(game, {"depth": 4})
	ExpeditionCase.set_world(game, {"encounter_number": 4})
	game.reset_encounter()
	check(game.encounter.scout_count() >= 3 and game.encounter.scout_tactics().any(func(scout): return scout.ranged)
		and not game.encounter.scout(0).ranged, "floor four has a melee frontline and a ranged scout")
	game.encounter.set_hp(-1, 1)
	place(1, game.tactics.position)
	player.strike_at = 0
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(not game.encounter_cleared() and not player.loot_pending, "killing the leader leaves the scout active")
	place(1, Stage.GATE)
	interact()
	check(ExpeditionCase.is_wild(player), "checkpoint stays locked until the whole pack is defeated")
	for slot in game.encounter.scout_count(): game.encounter.set_hp(slot, 2) # This fixture verifies target selection and pack-clear gating.
	var scout: Dictionary = game.encounter.scout(0)
	place(1, scout.pos + Vector3.RIGHT * 0.8)
	player.facing=(scout.pos-player.pos).normalized()
	preload("res://scout_behavior.gd").tick(game, 0.016, Time.get_ticks_msec())
	check(scout.windup > 0, "scout independently telegraphs an attack")
	player.strike_at = 0
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.encounter.hp_for(scout) == 1, "strikes can target the scout")
	player.strike_at = 0
	game.send_action(true)
	game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.encounter.hp_for(scout) == 0 and not game.encounter_cleared(), "the rest of the pack still holds the field")
	for other in game.encounter.scout_tactics():
		if game.encounter.hp_for(other) <= 0:
			continue
		place(1, other.pos)
		for hit in 2:
			player.strike_at = 0
			game.send_action(true)
			game.update_projectiles(Time.get_ticks_msec()+1000)
	check(game.encounter_cleared() and player.loot_pending, "last enemy unlocks the encounter reward")
	verify_tactical_cover()


func verify_tactical_cover() -> void:
	var field := Battlefield.new()
	field.configure(0, 1)
	var near := Vector3(-6.5, 0, -4.5)
	var far := Vector3(-6.5, 0, -1.0)
	check(not field.clear_line(near, far), "stone cover blocks line of sight")
	check(field.dash(near, far).z < -3.2, "dodge cannot tunnel through stone")
	var step: Vector3 = field.navigate(near, far, 0.2)
	check(step != near, "enemy path steers around static cover")

func verify_seed_variety() -> void:
	var garden := Progress.new()
	garden.planted[0] = true
	garden.planted[1] = true
	var reserve := garden.reserve("")
	var first := garden.roll_seed(reserve, [], [], Campaign.GROVE, 0.99)
	var second := garden.roll_seed(reserve, [], [], Campaign.GROVE, 0.99)
	var third := garden.roll_seed(reserve, [], [], Campaign.GROVE, 0.99)
	check([first, second, third] == [0, 0, 1], "seed rolls cannot get stuck on Thorn Bloom")
	check(garden.roll_seed(reserve, [], [0], Campaign.GROVE, 0.99) == 1,
		"two-seed bundles give different species")
	var guest := garden.reserve("another-character")
	check(garden.roll_seed(guest, [], [], Campaign.MIRE, 0.60) == 1,
		"the Mire favors Lantern Moss independently of the host's history")


func verify_briar_strike() -> void:
	var start_hp: int = PlayerVitals.current_hp(game.players[1])
	var bait: Vector3 = game.tactics.position + Vector3(0.8, 0, 0)
	place(1, bait)
	var windup_deadline := Time.get_ticks_msec() + 1500
	while not game.tactics.winding_up and Time.get_ticks_msec() < windup_deadline:
		await physics_frame
	check(game.tactics.winding_up, "enemy telegraphs after its short hit reaction")
	check(PlayerVitals.current_hp(game.players[1]) == start_hp, "wind-up deals no early damage")
	game.dodge_player(1, Vector2.RIGHT)
	var dodged: Vector3 = game.players[1].pos
	check(dodged.distance_to(game.tactics.position) > preload("res://leader_behavior.gd").BRIAR_STRIKE_RADIUS,
		"dodge moves the player clear of the attack")
	game.dodge_player(1, Vector2.RIGHT)
	check(game.players[1].pos == dodged, "dodge cooldown blocks a second immediate dodge")
	await create_timer(0.75).timeout
	check(PlayerVitals.current_hp(game.players[1]) == start_hp, "dodging the ring avoids damage")
	place(1, game.tactics.position + Vector3(0.8, 0, 0))
	var deadline := Time.get_ticks_msec() + 2200
	while PlayerVitals.current_hp(game.players[1]) == start_hp and Time.get_ticks_msec() < deadline:
		await physics_frame
	check(PlayerVitals.current_hp(game.players[1]) == start_hp - 1, "standing in the ring takes one hit")


func verify_host() -> void:
	game.progress.unknown = [1]
	var seeded_guest := false
	check(game.host_game() == OK, "host starts")
	if failed:
		return
	print("HOST READY")
	for step in 180:
		await create_timer(0.05).timeout
		if game.players.size() == 2:
			var ids: Array = game.players.keys()
			var guest: int = ids[1]
			if not seeded_guest and game.players[guest].profile_ready:
				game.seed_reserve(game.players[guest]).unknown.append(0)
				game.garden_action(guest, "look_1")
				game.progress.parts[0] = 4
				check(game.progress.expand_plot() == OK, "host researches a shared Garden bed")
				game.progress.advance_research(1)
				seeded_guest = true
			var position: Vector3 = game.players[guest].pos
			if position.z < 4.65:
				place(guest, Stage.ALTAR)
				for wait in 80:
					await create_timer(0.05).timeout
					var reserve: Dictionary = game.seed_reserve(game.players[guest])
					if reserve.stock[0] == 1:
						check(reserve.unknown.is_empty() and game.progress.unknown == [1],
							"guest identification only changes the guest's reserve")
						await verify_shared_combat(guest)
						return
				break
	check(false, "host saw neither guest movement nor a valid altar request (players %d)" % game.players.size())


func verify_shared_combat(guest: int) -> void:
	ExpeditionCase.set_membership(game, game.players[1], true)
	ExpeditionCase.set_membership(game, game.players[guest], true)
	place(1, game.tactics.position + Vector3.LEFT * 0.7)
	place(guest, game.tactics.position + Vector3.RIGHT * 0.7)
	await create_timer(1.0).timeout
	check(PlayerVitals.current_hp(game.players[1]) == game.MAX_HEALTH - 1, "host inside the ring takes damage")
	check(game.players.has(guest) and PlayerVitals.current_hp(game.players[guest]) == game.MAX_HEALTH,
		"guest dodge avoids host-authoritative damage")
	if not game.players.has(guest):
		return
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	place(1, Stage.DEEPER_GATE)
	interact()
	check(game.participation.depth() == 1, "checkpoint waits for the expedition party")
	place(guest, Stage.DEEPER_GATE)
	interact()
	check(game.participation.depth() == 2, "gathered party descends together")
	await wait_for_observation("depth2")
	if not game.players.has(guest):
		return
	ExpeditionCase.set_world(game, {"depth": 3})
	game.reset_encounter()
	game.encounter.scout(0).kind = 7
	game.encounter.scout(0).mutations = Enemies.BARK
	game.encounter.scout(0).growth = 2

	await wait_for_observation("depth3")
	if not game.players.has(guest):
		return
	ExpeditionCase.set_world(game, {"depth": game.CHECKPOINT_INTERVAL})
	ExpeditionCase.set_world(game, {"encounter_number": game.CHECKPOINT_INTERVAL})
	game.encounter.clear_scouts()
	game.deepest_milestone = game.participation.depth()
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	place(1, Stage.DEEPER_GATE)
	place(guest, Stage.DEEPER_GATE)
	game.players[guest].contributed = true
	ExpeditionCase.set_membership(game, game.players[1], false)
	for kill_index in 10: game._queue_monster_reward("legacy-xp-"+str(kill_index),0,0,Vector3.ZERO,false)
	game.award_combat_progress()
	ExpeditionCase.set_membership(game, game.players[1], true)
	check(game.players[1].character.xp[0] == 0 and game.players[guest].character.xp[0] == 10,
		"combat rewards go to the participating character")
	for step in 100:
		await create_timer(0.05).timeout
		if game.players.has(guest) and game.players[guest].power == 1:
			check(game.wallet_for(game.players[1]).spent_essence() == 0, "guest purchase spends only their wallet")
			await create_timer(2.5).timeout
			if not game.players.has(guest):
				return
			await verify_personal_loot(guest)
			return
	check(false, "guest purchase reaches the host")


func verify_personal_loot(guest: int) -> void:
	game.drop_pos = Stage.DEEPER_GATE + Vector3.LEFT * 2.1
	place(guest, game.drop_pos)
	for player in game.players.values():
		player.loot_pending = true
	game.refresh_drop()
	for step in 40:
		await create_timer(0.05).timeout
		if game.players.has(guest) and game.players[guest].pouch:
			break
	if not game.players.has(guest):
		check(false, "guest remains connected through loot check")
		return
	var other: Dictionary = game.players[guest]
	var host: Dictionary = game.players[1]
	check(other.carried_seeds.size() == 2 and host.carried_seeds.is_empty()
		and host.loot_pending and other.pouch and not host.pouch,
		"each player has an independent pickup and safe pouch")
	other.carried_parts[Parts.HOOK] = 1
	place(1, Stage.GATE)
	place(guest, Stage.GATE)
	interact()
	var reserve: Dictionary = game.seed_reserve(other)
	check(reserve.parts[Parts.HOOK] == 1 and game.available_parts(host, Parts.HOOK) == 0,
		"field parts remain private after extraction")
	game.donate_part(guest, other)
	check(reserve.parts[Parts.HOOK] == 0 and game.available_parts(host, Parts.HOOK) == 1,
		"donation makes the part available to the party")
	check(reserve.unknown.size() == 2 and game.progress.unknown == [1],
		"guest extraction banks only to their own reserve")
	var reload := Progress.new()
	reload.path = game.progress.path
	check(reload.load_garden() == OK and reload.reserve(other.seed_owner).unknown == reserve.unknown,
		"guest reserve survives reloading the host Garden")
	restore_heart_fixture()
	place(1, Stage.HEART);place(guest, Stage.HEART)
	game.send_garden_action("awaken");game.garden_action(guest,"awaken")
	check(not ExpeditionCase.is_wild(host) and not ExpeditionCase.is_wild(other) and not game.progress.finale_available(),"legacy restoration stays in the Garden while ending is deferred")
	game.tell(guest,"Ending deferred fixture")
	await wait_for_observation("ending_deferred")


func verify_guest() -> void:
	check(game.join_game() == OK, "guest starts")
	for step in 100:
		await create_timer(0.05).timeout
		if game.session == "Guest" and game.players.size() == 2 and game.client_inventory[0] == 1:
			break
	check(game.players.size() == 2, "guest sees both players (session %s, players %d)" % [game.session, game.players.size()])
	var id: int = game.multiplayer.get_unique_id()
	if not game.players.has(id):
		return
	check(game.client_inventory[0] == 1, "guest sees their own inventory")
	check(game.players[id].appearance.size() == 5, "guest receives compact character appearance")
	for attempt in 80:
		if Progress.decode_plots(game.client_garden[12]).size() == 4:
			break
		await create_timer(.05).timeout
	check(Progress.decode_plots(game.client_garden[12]).size() == 4, "guest receives expanded shared plots")
	interact()
	await create_timer(0.15).timeout
	check(game.client_inventory[0] == 1, "guest cannot identify a seed from spawn")
	Input.action_press("up")
	for step in 100:
		await create_timer(0.05).timeout
		if game.players[id].pos.distance_to(Stage.ALTAR) < 0.5:
			break
	Input.action_release("up")
	check(game.players[id].pos.distance_to(Stage.ALTAR) < 1.0, "guest receives host positions")
	interact()
	interact()
	for step in 40:
		await create_timer(0.05).timeout
		if game.client_inventory[1] == 1:
			break
	check(game.client_inventory[0] == 0 and game.client_inventory[1] == 1,
		"guest sees one identified seed after repeated requests")
	for step in 100:
		await create_timer(0.05).timeout
		if game.tactics.winding_up:
			break
	check(game.tactics.winding_up, "guest sees the host's attack wind-up")
	game.request_dodge.rpc_id(1, Vector2.RIGHT)
	for step in 100:
		await create_timer(0.05).timeout
		if PlayerVitals.current_hp(game.players[1]) < game.MAX_HEALTH:
			break
	check(PlayerVitals.current_hp(game.players[1]) == game.MAX_HEALTH - 1
		and game.players[id].hp == game.MAX_HEALTH, "guest sees the resolved strike")
	for step in 25:
		await create_timer(0.05).timeout
		if game.participation.depth() == 2:
			break
	check(game.participation.depth() == 2, "guest receives the deeper encounter")
	check(game.participation.seed() > 0, "guest receives the host's generated layout seed")
	var generated := Battlefield.new()
	generated.configure(game.participation.route(), game.participation.depth(), game.participation.seed())
	check(generated.connected() and generated.clearings.size() >= 6,
		"guest's seed reconstructs the same connected exploration map")
	probe.acknowledge.rpc_id(1, "depth2")
	for step in 25:
		await create_timer(0.05).timeout
		if game.participation.depth() == 3 and not game.client_pack.is_empty():
			break
	check(game.participation.depth() == 3 and game.client_pack.size() >= 24, "guest receives the encounter pack")
	var form := Enemies.decode(game.client_campaign[19])
	check(form.kind == 7 and form.mask == Enemies.BARK and form.tier == 2, "guest receives enemy species and evolved form")
	probe.acknowledge.rpc_id(1, "depth3")
	for step in 100:
		await create_timer(0.05).timeout
		if game.participation.depth() == game.CHECKPOINT_INTERVAL and game.players[id].wallet == 10:
			break
	check(game.players[id].wallet == 10 and game.players[1].wallet == 10,
		"both players get equal currency")
	game.send_garden_action("upgrade_power")
	for step in 100:
		await create_timer(0.05).timeout
		if game.players[id].wallet == 4:
			break
	check(game.players[id].wallet == 4 and game.players[1].wallet == 10,
		"guest sees independent spending")
	var reload := Character.new()
	reload.path = game.guest_character.path
	check(reload.load_profile() == OK and reload.data.xp[0] == 10
		and game.local_character.data.xp[0] == 0, "guest saves progress separately from the local profile")
	for step in 100:
		await create_timer(0.05).timeout
		if game.has_drop:
			break
	check(game.has_drop, "guest sees their unclaimed loot")
	interact()
	interact()
	game.send_garden_action("pouch")
	for step in 100:
		await create_timer(0.05).timeout
		if game.client_inventory[0] == 2:
			break
	check(game.client_inventory[0] == 2 and not game.has_drop,
		"guest sees banked personal seeds after extraction")
	for step in 100:
		await create_timer(0.05).timeout
		if game.status.contains("Ending deferred fixture"): break
	check(not ExpeditionCase.is_wild(game.players[id]) and game.client_campaign[17]==0,"guest retains ordinary Garden progression with finale deferred")
	probe.acknowledge.rpc_id(1,"ending_deferred")


func wait_for_observation(marker: String) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while not probe.received.has(marker) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(probe.received.has(marker), "guest observed " + marker)

func interact() -> void:
	if extraction_fixture:
		extraction_fixture = false
		# These focused mechanic fixtures skip traversal to a cleared extraction gate.
		# checkpoint_extraction.gd checks the actual route restrictions separately.
		if game.encounter_cleared():
			ExpeditionCase.set_world(game, {"encounter_number": ceili(game.participation.floor() / float(game.EXTRACTION_INTERVAL)) * game.EXTRACTION_INTERVAL})
		game.send_garden_action("extract")
	else:
		if game.at_garden_altar(game.players[1]): game.send_garden_action("altar_identify")
		else:
			# A natural kill may leave both a trophy and seed loot at this point.
			# These seed-loop fixtures press through nearby trophies first; the
			# separate loot tests assert single-press component pickup behavior.
			var p: Dictionary=game.players[1]
			if ExpeditionCase.is_wild(p) and p.loot_pending and p.pos.distance_to(game.drop_pos)<=1.45:
				for attempt in 32:
					if game.nearest_inventory_drop(p).is_empty(): break
					game.send_action(false)
			game.send_action(false)
		if game.planting_menu.visible: game.send_garden_action("plant_at_%d_%d"%[game.planting_view.slot,game.selected_seed(game.players[1])])
		if game.loadout_menu.visible: game.send_garden_action("depart");game.toggle_overlay(null)
		if game.checkpoint_pending: game.send_garden_action("checkpoint_choice_-1")


func wait_for_projectiles() -> void:
	var limit:=Time.get_ticks_msec()+900
	while not game.projectile_queue.is_empty() and Time.get_ticks_msec()<limit:
		await process_frame


