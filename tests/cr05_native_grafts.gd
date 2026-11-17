extends SceneTree

const Rules = preload("res://combat_ruleset.gd")
const Improvements = preload("res://expedition_grafts.gd")
const Grafts = preload("res://native_grafts.gd")
const Frost = preload("res://frost_combat.gd")
const Parts = preload("res://weapon_parts.gd")
var game: Node
var player: Dictionary
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL GA01A: ",label)


func item_part(item: String) -> int:
	return int(game.Items.get_item(item).legacy_part)


func stock(item: String, count: int) -> void:
	player.carried_parts[item_part(item)] = count


func floor_at(number: int) -> void:
	game.encounter_number = number
	player.pos = game.battlefield.graft


func action(id: String, item: String) -> String:
	return Improvements.request(Improvements.owner_details(game,player),id,item)


func buy(number: int, id: String, item: String) -> void:
	floor_at(number)
	var before: int = player.carried_parts[item_part(item)]
	var count: int = Improvements.run(player).copies.size()
	game.send_garden_action(action(id,item))
	check(Improvements.run(player).copies.size()==count+1 and player.carried_parts[item_part(item)]==before-1,
		"buy %s consumes one chosen trophy, once (%s)" % [id,game.status])


func start_expedition() -> void:
	player.pos = game.stage.gate_position()
	game.send_garden_action("depart")
	check(player.wild and not Improvements.run(player).is_empty(),"actual Gate departure creates a fresh graft ledger")
	game.battlefield = preload("res://battlefield.gd").new()
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	game.boss_kind=-1


func arena() -> void:
	game.enemy_winding_up = false
	game.enemy_mutations = 0
	game.enemy_kind = 0
	game.enemy_hp = 4000
	game.enemy_pos = Vector3(0,0,-1.15)
	game.scouts.clear()
	for point: Vector3 in [Vector3(1.65,0,-1.65),Vector3(-1.7,0,-1.55),Vector3(0.0,0,-3.05)]:
		var scout: Dictionary = game.make_scout(0,point,game.scouts.size()+1)
		scout.hp = 3000
		game.scouts.append(scout)
	player.pos = Vector3.ZERO
	player.facing = Vector3.FORWARD
	player.mouse_aim = false
	player.secondary = game.Items.get_item("plant_part_plant_frostbell").legacy_part
	game.trait_events.clear()
	game.leader_brain.clear()
	game.enemy_traits.clear()


func strike(at: int) -> void:
	player.strike_at = 0
	player.pos = Vector3.ZERO
	game.enemy_pos = Vector3(0,0,-1.15)
	game.strike_enemy(1,player,player.pos)
	game.update_projectiles(at)


func events_for(kind: String) -> Array:
	return game.trait_events.filter(func(event): return event.get("visual",event.kind)==kind and event.has("graft_source"))


func purchases() -> void:
	var rng: int = game.rng.state
	var knowledge: int = game.progress.knowledge
	var discovery: Array = game.progress.monster_crafts.duplicate()
	var wallet: int = game.run_wallet(player)
	stock("monster_0", 4)
	stock("monster_14", 2)
	stock("monster_23", 1)
	floor_at(8)
	game.show_graft_menu(1)
	var panel: Control = game.graft_view
	check(panel.tabs.get_tab_count()==2 and panel.data.remaining==6 and panel.confirm.disabled,
		"affinity shrine shows both sections with a fresh budget and explicit selection")
	panel.selected = "strike"
	panel.trophy = "monster_0"
	panel.show_selection()
	check(not panel.confirm.disabled and Parts.part_name(item_part("monster_0")) in panel.confirm.text,
		"preview names the exact trophy before confirming")
	game.toggle_overlay(null)
	check(Improvements.run(player).copies.is_empty() and player.carried_parts[item_part("monster_0")]==4,
		"browsing and closing consume no stock or opportunity")
	game.send_garden_action("graft_install_%d" % item_part("monster_14"))
	check(Improvements.run(player).copies.is_empty() and player.carried_parts[item_part("monster_14")]==2,
		"historical fourth-slot command cannot install in affinity combat")
	var mismatched := Improvements.owner_details(game,player)
	mismatched.revision += 1
	var wrong_revision := Improvements.request(mismatched,"strike","monster_0")
	mismatched.run = "invalid"
	var wrong_run := Improvements.request(mismatched,"strike","monster_0")
	var refused_requests := [action("strike","monster_23"),action("silken_link","monster_0"),
		action("nameless","monster_23"),action("reach","monster_2"),Improvements.COMMAND+"{",wrong_revision,wrong_run]
	for refused in refused_requests:
		game.send_garden_action(refused)
		check(Improvements.run(player).copies.is_empty() and player.carried_parts[item_part("monster_0")]==4
			and player.carried_parts[item_part("monster_23")]==1,"invalid cost, scope, or unavailable option preserves the opportunity")
	var request := action("strike","monster_0")
	game.send_garden_action(request)
	for retry in [request,action("silken_link","monster_14")]:
		game.send_garden_action(retry)
	check(player.carried_parts[item_part("monster_0")]==3 and player.carried_parts[item_part("monster_14")]==2
		and Improvements.run(player).copies.size()==1 and "already used" in game.status,
		"duplicate requests and a different second purchase at the same altar charge nothing")
	floor_at(16)
	game.send_garden_action(request)
	check("expired" in game.status and player.carried_parts[item_part("monster_0")]==3,"requests from a previous floor are stale")
	buy(16,"silken_link","monster_14")
	floor_at(24)
	game.send_garden_action(action("silken_link","monster_14"))
	check("Already acquired" in game.status and player.carried_parts[item_part("monster_14")]==1,"a Unique cannot be purchased again at another altar")
	stock("monster_18",1)
	stock("monster_19",1)
	stock("monster_17",1)
	stock("monster_15",1)
	buy(24,"prismatic_echo","monster_18")
	buy(32,"chorus_pulse","monster_19")
	buy(40,"cinder_field","monster_17")
	buy(48,"funeral_charges","monster_15")
	floor_at(56)
	game.send_garden_action(action("strike","monster_0"))
	check(Improvements.owner_details(game,player).remaining==0 and player.carried_parts[item_part("monster_0")]==3
		and "all graft purchases" in game.status,"six successes exhaust the shared budget on later altars")
	check(game.progress.knowledge==knowledge and game.progress.monster_crafts==discovery
		and game.rng.state==rng and game.run_wallet(player)==wallet and player.graft_part==0,
		"purchases grant no permanent discovery, change no Essence, take no RNG and use no installed slot")
	check(Improvements.resolution(player).adaptations.size()==5,"five different adaptations remain acquired and active")
	game.toggle_overlay(null)


func simultaneous_effects() -> void:
	arena()
	var first := Time.get_ticks_msec()+650
	for index in 11:
		var now := first+index*280
		strike(now)
		game.Traits.tick(game,now+250)
	check(int(Grafts.counters(player,"monster:glasscap").get("echo_charge",0))==2
		and int(Grafts.counters(player,"monster:root_choir").get("chorus_contacts",0))==3,
		"real basic attacks maintain independent third-contact and fourth-contact counters")
	game.trait_events.clear()
	for index in 24:
		game.Traits.queue_hit(game,player,0,{"damage":1.0},first,18000,false)
	var cinder: int = Grafts.counters(player,"monster:ashen_hart").ready_at
	var link: int = Grafts.counters(player,"monster:spore_widow").ready_at
	strike(first+4400)
	check(game.trait_events.size()==24 and Grafts.counters(player,"monster:glasscap").echo_charge==3
		and Grafts.counters(player,"monster:root_choir").chorus_contacts==4
		and Grafts.counters(player,"monster:ashen_hart").ready_at==cinder
		and Grafts.counters(player,"monster:spore_widow").ready_at==link,"full shared capacity retains all four ready responses")
	game.trait_events.clear()
	var now := first+4700
	strike(now)
	var hit_id := -1
	for effect in ["link","echo","chorus","cinder"]:
		var records := events_for(effect)
		check(records.size()==1 and records[0].owner==1,"%s schedules once from the same real basic contact" % effect)
		if not records.is_empty():
			if effect=="chorus":
				check(records[0].stats.affinity_hp==10,"Chorus captures the fixed 10 HP pulse")
			if hit_id < 0:
				hit_id = records[0].graft_source.attack
			check(records[0].graft_source.attack==hit_id,"%s retains its source and attack identity" % effect)
	var nearby: Dictionary = game.scouts[0]
	var before: int = nearby.hp
	var point: Vector3 = nearby.pos
	game.Traits.tick(game,now+280)
	check(nearby.hp<before and nearby.pos==point and Frost.state(nearby,now+280).is_empty(),
		"delayed damage reaches the secondary target without movement or a second Form trigger")
	check(events_for("link").is_empty() and events_for("echo").is_empty() and events_for("chorus").is_empty()
		and Grafts.counters(player,"monster:glasscap").echo_charge==0
		and Grafts.counters(player,"monster:root_choir").chorus_contacts==0,
		"resolving the three independent secondaries creates neither another hit nor new counters")


func lifecycle() -> void:
	var ledger := Improvements.run(player).duplicate(true)
	game.add_player(8)
	var ally: Dictionary = game.players[8]
	ally.wild = true
	ally.pos = player.pos
	game.Life.down(game,1,player)
	check(game.Life.revive(game,8,1) and Improvements.run(player)==ledger and not player.has(Grafts.STATE),
		"revival keeps purchases and clears transient adaptation state")
	game.players.erase(8)
	game.reset_encounter()
	check(Improvements.run(player)==ledger,"a new terrain encounter preserves all acquired improvements")
	var remainder: Array = player.carried_parts.duplicate()
	game.set_meta(&"guarded_gameplay_test_fault",func(phase, _path): return ERR_FILE_CANT_WRITE if phase=="stage" else OK)
	var rolled_back: bool = not game.finish_failed_expedition()
	game.remove_meta(&"guarded_gameplay_test_fault")
	check(rolled_back and player.wild and Improvements.run(player)==ledger and player.carried_parts==remainder,
		"a confirmed guarded rollback preserves the whole ledger and carry")
	game.finish_failed_expedition()
	check(not player.has(Improvements.STATE) and not player.has(Grafts.STATE),"actual wipe clears the ledger and combat counters")
	start_expedition()
	check(int(Improvements.run(player).run)!=int(ledger.run) and Improvements.run(player).copies.is_empty(),
		"fresh expedition starts with a different identity and no acquisitions")


func reinforcements() -> void:
	stock("monster_0",10)
	var basic: Dictionary = game.weapon_stats(player)
	var damage := float(basic.damage)
	var reach := float(basic.reach)
	player.hp=55
	var health: int = game.Life.maximum(game,player)
	buy(8,"health","monster_0")
	check(player.max_hp==health+5 and player.hp==55,"Max HP purchase leaves current HP unchanged")
	buy(16,"reach","monster_0")
	buy(24,"cooldown","monster_0")
	buy(32,"strike","monster_0")
	var ordinary: Dictionary = game.weapon_stats(player)
	var true_class: int = game.Skills.Balance.cooldown(ordinary.affinity_build.class_skills[0].native_skill,ordinary)
	check(is_equal_approx(ordinary.damage,damage) and is_equal_approx(ordinary.reach,reach)
		and true_class==game.Skills.Balance.cooldown(basic.affinity_build.class_skills[0].native_skill,basic)-250,
		"reach/damage are absent from native class stats, with only the authored cooldown change")
	arena()
	player.strike_at = 0
	game.strike_enemy(1,player,player.pos)
	var attack: Dictionary = game.projectile_queue.back()
	check(is_equal_approx(float(attack.stats.reach),reach+.2) and is_equal_approx(float(attack.stats.damage),damage+.3),
		"ordinary melee uses exactly the purchased reach and damage")
	game.garden_action(1,"abandon_run")
	check(not player.wild and not player.has(Improvements.STATE),"official abandonment clears acquired improvements")
	start_expedition()
	stock("monster_0",10)
	for floor_number in [8,16,24,32]:
		buy(floor_number,"strike","monster_0")
	floor_at(40)
	var remaining: int = player.carried_parts[item_part("monster_0")]
	game.send_garden_action(action("strike","monster_0"))
	check("effective limit" in game.status and player.carried_parts[item_part("monster_0")]==remaining
		and not Improvements.owner_details(game,player).used,"a fully capped reinforcement spends neither trophy nor altar")
	buy(40,"health","monster_0")


func rootlet() -> void:
	game.garden_action(1,"abandon_run")
	start_expedition()
	stock("monster_16",1)
	buy(8,"rootlet_attraction","monster_16")
	player.pos=Vector3.ZERO
	game.enemy_hp=0
	game.scouts.clear()
	var ours := {"position":[2.0,0,0],"owner":1}
	var someone_elses := {"position":[2.0,0,0],"owner":8}
	game.wild_item_drops = [ours,someone_elses]
	game.attract_loot(.1)
	check(float(ours.position[0])<2.0 and float(someone_elses.position[0])==2.0,
		"Grasping Rootlet draws real eligible loot and preserves private ownership")
	game.wild_item_drops.clear()


func run() -> void:
	var menu := preload("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.new_game()
	menu.create_character("GA01A Grafting",0,preload("res://character_appearance.gd").DEFAULT)
	var deadline := Time.get_ticks_msec()+6500
	while current_scene==menu and Time.get_ticks_msec()<deadline:
		await process_frame
	if current_scene==menu:
		check(false,"real isolated affinity title")
		quit(1)
		return
	game = current_scene
	game.set_process(false)
	game.set_physics_process(false)
	player = game.players[1]
	player.pos=game.stage.gate_position()
	game.send_garden_action("learn_0_64")
	check(Rules.active(game) and game.has_meta(game.Transactions.SESSION),"guarded affinity session")
	start_expedition()
	purchases()
	simultaneous_effects()
	lifecycle()
	reinforcements()
	rootlet()
	game.return_to_main_menu()
	await process_frame
	if failures==0:
		print("PASS: GA01A cumulative purchases, shared combat capacity and lifetimes (%d checks)" % checks)
	quit(int(failures>0))
