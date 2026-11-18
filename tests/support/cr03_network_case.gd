extends RefCounted
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")

const Mode = preload("res://combat_ruleset.gd")
const Frost = preload("res://frost_combat.gd")
const Events = preload("res://combat_action_events.gd")
const Core = preload("res://core_combat.gd")
const Menu = preload("res://main_menu.tscn")
const Appearance = preload("res://character_appearance.gd")
const ConnectedWarden = preload("res://warden_connected_tree.gd")
const CT_PATH := ["vanguard","deep_roots","ready_footing","sheltering_quake","holdfast","sanctuary_ground"]
const CT_REQUESTS := [64,68,71,75,78,81]
const Weaver = preload("res://weaver_connected_tree.gd")
const Aim = preload("res://ability_aim.gd")
const Ranger = preload("res://ranger_connected_tree.gd")
const RangerCombat = preload("res://ranger_combat.gd")
const Reaper = preload("res://reaper_connected_tree.gd")
const ReaperCombat = preload("res://reaper_combat.gd")
const Oracle = preload("res://oracle_connected_tree.gd")
const Omens = preload("res://oracle_omens.gd")
const ORACLE_PATH := ["lifekeeper","kindled_ward","quiet_ground","shared_shelter","merciful_chime","mercys_chorus"]
const REAPER_PATH := ["veilwalker","long_edge","rending_cut","barbed_siphon","deaths_due","feast_of_thorns"]
const RANGER_PATH := ["wildstalker","long_draw","splinter_ambush","quick_reset","follow_through","double_draw"]
const WEAVER_PATH := ["bloomcaller","silken_gift","holding_threads","threaded_nova","spore_cycle","symbiotic_nova"]

var tree: SceneTree
var signals: String
var port: int
var party := false
var failed := false
var extra_cores: Array = []
var measure_packets := false
var mixed_wood_ward := false
var final_family_mix := false
const Improvements = preload("res://expedition_grafts.gd")
const Grafts = preload("res://native_grafts.gd")
const UpgradeCards = preload("res://affinity_cards.gd")
const RunSummary = preload("res://run_summary_panel.gd")
const SPEED_CARD := "ordinary_weapon_interval"
var native_graft_case := false
var connected_warden_case := false
var connected_weaver_case := false
var connected_ranger_case := false
var connected_reaper_case := false
var connected_oracle_case := false
var affinity_cards_case := false


func check(ok: bool, label: String) -> bool:
	if not ok:
		failed = true
		printerr("FAIL Frost co-op: ",label)
	return ok


func until(condition: Callable, timeout := 17000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout
	while not condition.call() and Time.get_ticks_msec()<deadline:
		await tree.process_frame
	return condition.call()


func mark(key: String, text := "ok") -> void:
	var file := FileAccess.open(signals.path_join(key),FileAccess.WRITE)
	if check(file!=null,"write "+key):
		file.store_string(text)


func read(key: String) -> String:
	return FileAccess.get_file_as_string(signals.path_join(key))


func guests(game: Node) -> Array:
	return game.players.keys().filter(func(id):return id!=1 and SessionCase.Session.ready_for(game.players[id],false))


func run(scene_tree: SceneTree, four := false) -> bool:
	tree=scene_tree
	party=four
	var role := OS.get_cmdline_user_args()[0]
	signals=OS.get_environment("MYSTICAL_TERRAIN_TEST_SIGNALS")
	port=int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT"))
	var menu := Menu.instantiate()
	tree.root.add_child(menu)
	tree.current_scene=menu
	if not check(preload("res://assets/terrain_m02/experimental/experiment_mode.gd").verified() and menu.has_meta(&"experimental_terrain"),"real isolated affinity title"):
		return false
	if role=="host": await host(menu)
	elif role=="overflow":
		if check(await until(func():return read("full")=="ok"),"four players arrive"):
			menu.request_create_character()
			menu.create_character("Frost overflow",0,Appearance.DEFAULT)
			var title_id := menu.get_instance_id()
			begin_join(menu)
			check(await until(func():return tree.current_scene.get_instance_id()!=title_id and tree.current_scene.get("return_message") is String),"fifth player returns to title")
			mark("overflow")
	else: await guest(menu,role)
	return not failed


func begin_join(menu: Node) -> void:
	menu.show_page(2)
	menu.join_button.pressed.emit()
	menu.network_dialog.address_field.text="127.0.0.1:"+str(port)
	menu.network_dialog.submit.pressed.emit()


func host(menu: Node) -> void:
	menu.host_port=port
	menu.host_choice.button_pressed=true
	menu.new_game()
	menu.create_character("Frost Host",0,Appearance.DEFAULT)
	if not check(await until(func():return SessionCase.role(tree.current_scene)=="Host"),"host through guarded title"): return
	var game:=tree.current_scene
	check(game.weapon_stats(game.players[1]).affinity_build.ruleset==Mode.ID and "stocked" in Frost.stock_test_garden(game),"guarded test supplies")
	var ordinary: int=game.Items.get_item("plant_part_plant_frostbell").legacy_part
	var refined: int=game.Items.get_item("plant_part_rare_frostbell").legacy_part
	var local: Dictionary=game.players[1]
	local.pos=game.stage.gate_position()
	game.garden_action(1,"loadpart_0_%d"%ordinary)
	game.garden_action(1,"loadpart_2_%d"%refined)
	game.garden_action(1,"learn_0_%d" % (ConnectedWarden.REQUEST_OFFSET+2))
	check(ConnectedWarden.focus(local.character)=="bastion","host learns its actual Rootshield focus through guarded progression")
	mark("host")
	var count:=3 if party else 1
	if not check(await until(func():return guests(game).size()==count),"all expected guests admitted"):return
	var ids:=guests(game)
	ids.sort()
	var weaver_id := 0
	var path_id := 0
	var graph := selected_graph()
	for id in ids:
		game.players[id].pos=local.pos
		if connected_weaver_case and game.players[id].frame==1: weaver_id=id
		if graph != null and game.players[id].frame==graph.class_id: path_id=id
	var supplied := {}
	var ward_guest: int=ids[1] if mixed_wood_ward else 0
	var ordinary_wood: int=game.Items.get_item("plant_part_plant_ironroot").legacy_part
	if mixed_wood_ward: supplied[ordinary_wood]=game.progress.part_count(ordinary_wood)
	for index in ids.size():
		var part := 0
		if not extra_cores.is_empty():
			part = int(game.Items.get_item(extra_cores[index]).legacy_part)
			supplied[part] = game.progress.part_count(part)
		var wants_refined: bool = connected_warden_case or ids[index]==weaver_id or ((connected_reaper_case or connected_oracle_case) and ids[index]==path_id)
		var catalyst := refined if wants_refined else ordinary_wood if ids[index]==ward_guest else 0
		mark("select-"+str(ids[index]),"%d:%d:%d" % [refined,part,catalyst])
	var prepared := func():
		if native_graft_case and not ids.all(func(id):
			var visitor: Dictionary = game.players[id]
			return visitor.frame!=0 and visitor.weapon_kind==1 and game.Skills.resolve_in_world(game,visitor.frame,0,visitor.character).has("subclass_focus")):
			return false
		if (connected_reaper_case or connected_oracle_case) and (path_id==0 or game.players[path_id].prepared_catalyst!=refined):
			return false
		return ids.all(func(id):return game.players[id].prepared_secondary==refined) and supplied.keys().all(func(part):
			return ids.any(func(id):return game.players[id].prepared==part or game.players[id].prepared_catalyst==part))
	if not check(await until(prepared),"real guest loadout requests reach host"):return
	if connected_warden_case and not await learn_connected_host(game,ids[0],refined):
		return
	if connected_weaver_case and not await learn_weaver_host(game,weaver_id,refined):
		return
	if graph != null and not await learn_path_host(game,path_id,graph):
		return
	if not check(await until(func():
		return ids.all(func(id):return preload("res://affinity_build.gd").departure_refusal(game.players[id]).is_empty())),
		"every guest has selected a starting focus"):return
	var before_regular: int=game.progress.part_count(ordinary)
	var before_rare: int=game.progress.part_count(refined)
	if party:
		mark("full")
	game.map_rng.seed=16
	game.PartyTravel.request(game,1,"depart")
	mark("depart",str(game.participation.travel_epoch()))
	if not check(await until(func():return game.participation.active() and ids.all(func(id):return ExpeditionCase.is_wild(game.players[id])) and not game.battlefield.generated.is_empty()),"native guarded departure opens generated floor"): return
	check(game.progress.part_count(ordinary)==before_regular-1 and game.progress.part_count(refined)==before_rare-count-1-int(connected_warden_case or connected_weaver_case or connected_reaper_case or connected_oracle_case),"exact guarded departure debits")
	var paid := [game.progress.part_count(ordinary),game.progress.part_count(refined)]
	for part in supplied:
		check(game.progress.part_count(part)==supplied[part]-1,"each additional Core is debited once")
	if native_graft_case and not await install_party_grafts(game,ids):
		return
	var floor_entry: Vector3=game.battlefield.entry
	var target := floor_entry
	for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		target=game.battlefield.dash(floor_entry,floor_entry+direction*1.10)
		if floor_entry.distance_to(target)>.9:break
	check(floor_entry.distance_to(target)>.8,"usable Frost fixture area on generated floor")
	game.tactics.position=target
	game.encounter.set_hp(-1, 150)
	game.tactics.stagger_until=Time.get_ticks_msec()+18000
	var rows: Array=[]
	var ruptures: Array=[]
	game.set_meta(Events.RECORD,func(event):rows.append(event))
	game.set_meta(&"frost_rupture_witness",func(spent,hp):ruptures.append([spent,hp]))
	local.pos=floor_entry
	local.facing=(target-floor_entry).normalized()
	for id in ids:
		var remote: Dictionary=game.players[id]
		remote.pos=floor_entry
		remote.facing=local.facing
		mark("strike-"+str(id))
		if not check(await until(func():return rows.any(func(e):return e.kind=="weapon_contact" and e.target=="leader" and e.source_actor==id)),
			"guest direct hit applies refined Frost from "+str(id)):return
	if party:
		if not check(ruptures.size()==1 and ruptures[0][1]==21 and ruptures[0][0].map(func(s):return s.actor)==ids,"three distinct guests rupture once on four-player floor"):return
	local.core_ready_at=0
	local.core_cast_until=0
	local.cast_until=0
	var direction:=Vector2(local.facing.x,local.facing.z)
	game.garden_action(1,Core.request(game,local,direction,1.1))
	var wanted:=2 if party else 1
	if not check(await until(func():return ruptures.size()>=wanted),"actual Rime Bloom ruptures on generated floor"):return
	var burst: Array=ruptures[wanted-1]
	check(burst[1]==(12 if party else 15) and burst[0].any(func(stack):return stack.actor==1),
		"ordinary Core accounts for each source with refined Form when mixed")
	if not check(await until(func():return not game.get_meta(Core.STATE,{}).has(1)),"closing petals finish before another action"):return
	var protected: int=ids[0]
	var ally: Dictionary=game.players[protected]
	local[Cooldowns.STATE] = local[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	game.use_class_skill(1,local,0)
	ally[Conditions.STATE] = ally[Conditions.STATE].clear_grace()
	var before: float=PlayerVitals.current_hp(ally)
	IncomingPlayerHit.resolve_world(game, protected, PlayerLifecycle.generation(ally), Time.get_ticks_msec(), 1)
	check(PlayerVitals.current_hp(ally)==before and rows.any(func(e):return e.kind=="actual_block" and e.source_actor==1 and e.details.recipient==protected and e.quality=="refined"),"actual guest block uses host refined Catalyst")
	if connected_warden_case and not await exercise_connected_host(game,local,ally,protected,rows):
		return
	if connected_weaver_case and not await exercise_weaver_host(game,weaver_id,floor_entry,target,rows):
		return
	if connected_ranger_case and not await exercise_ranger_host(game,path_id,floor_entry,target,rows):
		return
	if connected_reaper_case and not await exercise_reaper_host(game,path_id,floor_entry,target,rows):
		return
	if connected_oracle_case and not await exercise_oracle_host(game,path_id,floor_entry):
		return
	if mixed_wood_ward:
		var warded: Dictionary=game.players[ward_guest]
		warded[Protection.STATE] = warded[Protection.STATE].clear_expedition()
		warded[Conditions.STATE] = warded[Conditions.STATE].clear_grace()
		mark("wood-guard-"+str(ward_guest))
		if not check(await until(func():return warded[Protection.STATE].charge_count()>0),"native remote Q arms Wood Ward"):return
		var hp_before: float=PlayerVitals.current_hp(warded)
		IncomingPlayerHit.resolve_world(game, ward_guest, PlayerLifecycle.generation(warded), Time.get_ticks_msec(), 2, 0, game.tactics.position)
		check(PlayerVitals.current_hp(warded)==hp_before and rows.any(func(e):return e.kind=="actual_block" and e.source_actor==ward_guest and e.primary_affinity=="wood" and e.quality=="ordinary"),
			"real Wood Ward bursts with its own provenance after the Frost Ward")
		check(warded.get("affinity_bark_grants",[]).any(func(grant):return grant.actor==ward_guest and grant.quality=="ordinary"),"Wood Ward retains ordinary source capacity")
	for index in extra_cores.size():
		var visitor: Dictionary=game.players[ids[index]]
		var source: int=ids[index]
		var primary: String=preload("res://plant_affinities.gd").for_part(visitor.weapon).primary_affinity
		if primary=="water": local[Conditions.STATE] = local[Conditions.STATE].with_slow_until(Time.get_ticks_msec()+4000)
		var native_max: int=game.Life.native_maximum(game,local)
		if not check(await until(func():
			return Time.get_ticks_msec()>=maxi(int(visitor.get("cast_until",0)),int(visitor.get("core_cast_until",0)))),
			"next remote B waits for the native cast window"):return
		var aim: Vector3=visitor.facing
		var departure: Vector3=visitor.pos
		if primary=="spirit":
			var spirit=preload("res://spirit_affinity.gd")
			var best:=0.0
			for lane in 8:
				var candidate:=Vector3.RIGHT.rotated(Vector3.UP,lane*TAU/8.0)
				var extent:=departure.distance_to(spirit.step(game,source,candidate))
				if extent>best:
					best=extent
					aim=candidate
			if not check(best>=spirit.MIN_STEP,"generated floor offers a clear direction for Phantom Step"): return
		mark("cast-"+str(source),str(Vector2(aim.x,aim.z)))
		if not check(await until(func():return rows.any(func(e):return e.kind=="core_action" and e.primary_affinity==primary and e.source_actor==source)),
			"native "+primary+" Core RPC resolves by the host"):return
		match primary:
			"spirit":
				check((Vector3(visitor.pos)-departure).dot(aim)>=.28 and visitor.has("affinity_spirit_strides"),
					"authorized guest step grants stride and moves along its chosen clear direction")
			"fire":
				check(game.tactics.memory.get("affinity_burning",{}).has("%d/core"%source),"guest trail actually ignites leader")
			"water":
				check(await until(func():return local[Conditions.STATE].slow_until_ms()==0 and game.tactics.memory.get("affinity_drenched",{}).has("%d/core"%source)),
					"guest Dewfall cleanses host and actually Drenches leader")
			"thorn":
				check(await until(func():return game.tactics.memory.get("affinity_bleed",{}).has("%d/core"%source)),
					"stationary guest Thorn Line slows and wounds a real enemy on the host")
				mark("thorn-"+str(source))
				check(await until(func():return read("thorn-seen-"+str(source))=="ok"),"guest receives the authoritative field geometry")
			"wood":
				check(local.get("affinity_bark_grants",[]).any(func(grant):return grant.actor==source and grant.quality=="refined"),"Ironbark applies the refined guest grant on the host")
				if mixed_wood_ward:
					var grants: Array=local.get("affinity_bark_grants",[])
					check(grants.any(func(grant):return grant.actor==ward_guest and grant.quality=="ordinary") and grants.any(func(grant):return grant.actor==source and grant.admitted==36),
						"separate Wood sources coexist with a capped refined grant")
					var wounds: Dictionary=game.tactics.memory.get("affinity_bleed",{})
					check(wounds.has("%d/core"%ids[0]) and wounds.has("%d/core"%ids[1]),"two real Thorn sources remain independent")
				mark("bark-"+str(source))
				check(await until(func():return read("bark-seen-"+str(source))=="ok"),"guest receives Bark presentation through authoritative details")
			"vital":
				var bonus: int=preload("res://affinity_build.gd").slot("core",visitor.weapon).potency_profile.values.bonus_hp
				check(PlayerVitals.maximum_hp(local)==native_max+bonus and local.get("affinity_vital_sources",{}).has("%d/core"%source),
					"guest Vital Bloom applies its quality to host")
				mark("vital-"+str(source),str(PlayerVitals.maximum_hp(visitor)))
				check(await until(func():return read("vital-seen-"+str(source))=="ok"),"Vital capacity reaches guest through authoritative vitals")
	if native_graft_case:
		check(game.trait_events.any(func(e):return e.get("graft_source",{}).get("component_id")=="monster:ashen_hart")
			or game.combat_events.any(func(e):return e.shape=="cinder_zone"),"real guest strike emitted acquired Cinder")
		if party and measure_packets: await sample_host_snapshots(game,ids)
	if party and not connected_weaver_case and graph==null and not native_graft_case:
		if measure_packets: await sample_host_snapshots(game,ids)
		if mixed_wood_ward and measure_packets: await verify_current_snapshot_host(game,ids,local)
		check(await until(func():return read("overflow")=="ok",22000),"overflow returns after native connection deadline")
		check(guests(game).size()==3,"four-player limit holds")
		mark("party-done")
		await until(func():return ids.all(func(id):return read("done-"+str(id))=="ok"))
		game.return_to_main_menu()
		check(await until(func():return tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"host goes offline after party")
		mark("offline")
		return

	# Controlled enemy HP leaves the actual Frost opening responsible for
	# the final kill, while the existing native death and reward code runs.
	var xp_before := [int(local.character.xp[0]),int(ally.character.xp[0])]
	var stats: Dictionary=game.weapon_stats(local)
	stats.damage=10000
	for index in game.encounter.scout_count():
		if game.encounter.hp(index)>0:
			game.apply_weapon_hit(local,index,game.encounter.scout(index).pos,stats,Time.get_ticks_msec())
	var expected_xp := []
	var selected_weaver: Dictionary=game.players.get(weaver_id,{})
	var selected_player: Dictionary=game.players.get(path_id,{})
	var path_xp_before: int=selected_player.character.xp[graph.class_id] if graph!=null else 0
	var weaver_xp_before: int=selected_weaver.character.xp[1] if connected_weaver_case else 0
	if connected_warden_case:
		var pending: Array = game.monster_rewards.pending_receipts()
		for index in [0,1]:
			var actor: int = 1 if index==0 else protected
			var prior := int(xp_before[index])
			var subtotal := 0
			for kill in pending:
				for reward in kill.rewards:
					if reward.id==actor:
						subtotal += int(reward.xp)
			check(subtotal>0,"scout rewards remain queued while the leader lives")
			expected_xp.append(prior+subtotal+3)
		check(local.character.xp[0]==xp_before[0] and ally.character.xp[0]==xp_before[1],
			"queued scout XP stays out of both profiles before floor settlement")
	game.encounter.set_hp(-1, 3)
	game.tactics.position=target
	for seed_value in range(1,40):
		game.rng.seed=seed_value
		var rng_before: int=game.rng.state
		if not game.roll_kill_trophy(game.enemy_kind,game.enemy_mutations,true).is_empty():
			game.rng.state=rng_before
			break
	local.core_ready_at=0
	local.core_cast_until=0
	local.cast_until=0
	var thorn_kill := "part_5" in extra_cores
	if not thorn_kill:
		game.garden_action(1,Core.request(game,local,direction,1.1))
	if not check(await until(func():return game.encounter_cleared() and game.encounter_rewarded),"a family kill activates Gate through guarded settlement"):return
	if thorn_kill:
		check(game.enemy_health()==0,"the maintained Thorn wound kills without an extra attack")
	check(not game.wild_item_drops.is_empty(),"actual enemy drops through native settlement")
	if connected_warden_case:
		check(await until(func():return ally.get("projection_delivery",{}).get("state")=="committed"),
			"guest acknowledges canonical floor XP")
		check([local.character.xp[0],ally.character.xp[0]]==expected_xp,
			"host and guest get each queued scout award plus one three-XP leader award")
		mark("ct-xp",str(expected_xp[1]))
	if connected_weaver_case:
		if not check(await until(func():
			return selected_weaver.character.xp[1]>weaver_xp_before and selected_weaver.get("projection_delivery",{}).get("state")=="committed"),
			"Weaver receives and acknowledges actual floor XP"):return
		mark("weaver-xp",str(selected_weaver.character.xp[1]))
	if graph != null:
		var saved := func() -> bool:
			return selected_player.character.xp[graph.class_id]>path_xp_before and selected_player.get("projection_delivery",{}).get("state")=="committed"
		if not check(await until(saved),"%s floor XP reaches the owning guest and is acknowledged" % graph.label):return
		mark("path-xp",str(selected_player.character.xp[graph.class_id]))
	local.pos=game.battlefield.advance
	for id in ids: game.players[id].pos=local.pos
	if affinity_cards_case:
		# Run the checkpoint UI on the cleared arena from the real combat
		# above. Select encounter 3 to exercise the production card cadence.
		ExpeditionCase.set_world(game, {"encounter_number": 3})
		var planned := {}
		for id in game.players:
			var fixture := plan_speed_offer(game, game.players[id], id == ids[0])
			if not check(not fixture.is_empty(),"seeded checkpoint can draw Light Grip"):return
			planned[id] = fixture
			mark("attack-speed-"+str(id), JSON.stringify(fixture))
			mark("wallet-"+str(id), str(fixture.balance))
		ExpeditionCase.Transitions.checkpoint(game, 1,true)
		check(game.checkpoint_cards.get_child_count()==3,"host receives a full offer after mixed-class combat")
		check_speed_face(game, planned[1])
		game.send_garden_action(game.affinity_checkpoint_action(game.checkpoint_offer_revision,str(planned[1].choice)))
		mark("affinity-cards")
		if not check(await until(func():return ids.all(func(id):return read("owned-"+str(id))=="ok")),
			"all four players can claim independent upgrades"):return
		for id in game.players:
			var visitor: Dictionary = game.players[id]
			var copies := UpgradeCards.ledger(visitor).copies()
			check(copies.size()==1 and copies[0].id==SPEED_CARD
				and game.wallet_for(visitor).spent_essence()==planned[id].spent
				and game.run_wallet(visitor)==planned[id].balance,
				"one guest's reroll debits its wallet once while all four claims stay free")
			check(has_attack_speed(game,visitor,game.weapon_stats(visitor),planned[id].after),
				"host's resolved attack speed matches the promised value for this peer")
	ExpeditionCase.Transitions.checkpoint(game, 1,true)
	mark("advance",str(game.participation.travel_epoch()))
	if not check(await until(func():return game.participation.depth()==2 and ids.all(func(id):return read("guest-floor-"+str(id))=="ok")),
		"party advances to next generated floor"):return
	if affinity_cards_case:
		check(game.players.keys().all(func(id): return game.run_wallet(game.players[id]) == int(read("wallet-"+str(id)))),
			"floor transition retains independently spent balances")
	if native_graft_case:
		check(ids.all(func(id):return Improvements.owner_details(game.players[id], game.participation.floor()).get("copies", []).size()==1),
			"authoritative purchases survive the real floor transition")
	if connected_reaper_case:
		check(selected_player.grave_charges==1 and not selected_player.has("native_graft_state"),
			"the guest’s native charge survives the real floor transition")
	ExpeditionCase.set_world(game, {"encounter_number": 6})
	game.deepest_milestone=6
	game.encounter.set_hp(-1, 0)
	game.encounter.clear_scouts()
	game.encounter_rewarded=true
	local.pos=game.battlefield.advance
	for id in ids: game.players[id].pos=local.pos
	ExpeditionCase.Transitions.checkpoint(game, 1,false)
	mark("extract",str(game.participation.travel_epoch()))
	if not check(await until(func():return not game.participation.active() and ids.all(func(id):return read("guest-garden-"+str(id))=="ok")),
		"party extraction restores Garden"):return
	if affinity_cards_case:
		var wallet_cleared := func(visitor: Dictionary) -> bool:
			return (not visitor.has(UpgradeCards.STATE) and game.run_wallet(visitor)==0
				and game.wallet_for(visitor).earned_sparks()==0 and game.wallet_for(visitor).spent_essence()==0)
		check(game.players.values().all(wallet_cleared), "real extraction clears all four purses and decks")
	if native_graft_case:
		check(game.players.size()==ids.size()+1 and game.players.values().all(func(visitor):
			return not visitor.has(Improvements.STATE) and not visitor.has(Grafts.STATE)),
			"real extraction clears purchased improvements and counters for all connected players")
		mark("grafts-cleared")
	if connected_reaper_case:
		check(selected_player.grave_charges==0,"normal extraction clears the authoritative native charge pool")
	if party:
		check(await until(func():return read("overflow")=="ok",22000) and guests(game).size()==3,"mixed four-player travel and fifth-peer refusal")
		mark("party-done")
		await until(func():return ids.all(func(id):return read("done-"+str(id))=="ok"))
		game.return_to_main_menu()
		check(await until(func():return tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"host goes offline after party")
		mark("offline")
		return
	check([game.progress.part_count(ordinary),game.progress.part_count(refined)]==paid,"no repeated affinity material consumption")
	if not check(await until(func():return guests(game).is_empty() and game.departure_settlement.is_empty()),"guest detached through normal teardown"):return
	mark("detached")
	check(await until(func():return read("rejoined")=="ok" and guests(game).size()==1),"guest reconnects to the existing Garden")
	if connected_warden_case:
		check(guests(game).size()==1 and ConnectedWarden.path(game.players[guests(game)[0]].character)==CT_PATH,
			"host restores the six valid choices to the same guest on rejoin")
	if connected_weaver_case and guests(game).size()==1:
		var rejoined: Dictionary=game.players[guests(game)[0]].character
		check(Weaver.TREE.path(rejoined)==WEAVER_PATH and rejoined.xp[1]==int(read("weaver-xp")),
			"host restores the committed Weaver tree and XP without replay")
	if graph != null and guests(game).size()==1:
		var visitor: Dictionary = game.players[guests(game)[0]]
		var profile: Dictionary = visitor.character
		check(graph.path(profile)==selected_path() and profile.upgrades[graph.class_id]==0
			and profile.xp[graph.class_id]==int(read("path-xp")),"host re-admits the committed path without replay")
		visitor.pos = game.Stage.HEART + Vector3.BACK
		mark("path-respec-now")
		var refunded := func() -> bool:
			return (read("path-refunded")=="ok" and graph.path(visitor.character).is_empty()
				and visitor.character.xp[graph.class_id]==int(read("path-xp"))
				and visitor.get("projection_delivery",{}).get("state")=="committed")
		if not check(await until(refunded),"guarded respec refunds choices and preserves XP"):return
	check([game.progress.part_count(ordinary),game.progress.part_count(refined)]==paid,"reconnect does not repeat departure")
	for part in supplied:
		check(game.progress.part_count(part)==supplied[part]-1,"rejoin preserves each additional Core debit")
	check(not local.has("affinity_vital_sources") and not local.has("affinity_bark_grants"),"Garden return discards temporary health and armor")
	mark("saved")
	game.return_to_main_menu()
	check(await until(func():return tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"host goes offline after rejoin")
	mark("offline")


func learn_connected_host(game: Node, id: int, catalyst: int) -> bool:
	var player: Dictionary = game.players[id]
	if not check(await until(func():return player.prepared_catalyst==catalyst),"guest Catalyst is committed before learning"):return false
	mark("ct-learn")
	if not check(await until(func():
		return (read("ct-level-one")=="ok" and ConnectedWarden.path(player.character)==["vanguard"]
			and player.get("projection_delivery",{}).get("state")=="committed")),"host validates the level-one focus and receives canonical guest acknowledgment"):
		return false
	# Seed earned XP in the disposable fixture through the guarded profile path.
	game.run_guarded_action(id,game.Transactions.Scope.GARDEN,func(effects):
		player.character.xp[0]=2600
		game.save_action_profile(id,effects))
	if not check(await until(func():
		return (read("ct-learned")=="ok" and ConnectedWarden.path(player.character)==CT_PATH
			and player.get("projection_delivery",{}).get("state")=="committed")),"host and guest both commit the six connected selections"):
		return false
	return check(player.character.upgrades[0]==0 and game.Skills.resolve_in_world(game,0,0,player.character).name=="Thorn Counter",
		"the connected guest keeps its original focus after crossing lanes")


func learn_connected_guest(game: Node) -> bool:
	if not check(await until(func():return read("ct-learn")=="ok"),"learn through the admitted host"):return false
	game.send_garden_action("learn_0_67")
	game.send_garden_action("learn_0_%d"%CT_REQUESTS[0])
	if not check(await until(func():return ConnectedWarden.path(game.guest_character.data)==["vanguard"]),
		"level-one focus received and saved by the guest"):return false
	game.send_garden_action("learn_0_68")
	if not check(await until(func():return "Reach Warden level 2" in game.status),"unearned guest request is refused by host"):return false
	mark("ct-level-one")
	if not check(await until(func():return game.guest_character.data.xp[0]==2600),"seeded XP reaches guest profile without extra choices"):return false
	game.send_garden_action("learn_0_69")
	if not check(await until(func():return "connected to your last selection" in game.status),"disconnected guest request is refused by host"):return false
	for index in range(1,CT_REQUESTS.size()):
		game.send_garden_action("learn_0_%d"%CT_REQUESTS[index])
		if not check(await until(func():return ConnectedWarden.path(game.guest_character.data)==CT_PATH.slice(0,index+1)),
			"guest commits a successive Warden profile choice"):return false
	game.send_garden_action("learn_0_79")
	if not check(await until(func():return "next tier" in game.status),"second capstone is refused by host"):return false
	var config := ConfigFile.new()
	var path: String = game.guest_character.path
	check(config.load(path)==OK and ConnectedWarden.path(config.get_value("character","progress",{}))==CT_PATH,
		"canonical guest profile contains the exact six-choice path")
	mark("ct-learned")
	return true


func exercise_connected_host(game: Node, local: Dictionary, player: Dictionary, id: int, events: Array) -> bool:
	player[Protection.STATE] = player[Protection.STATE].clear_expedition()
	player[Conditions.STATE] = player[Conditions.STATE].clear_grace()
	game.encounter.set_hp(-1, 180)
	mark("ct-q")
	if not check(await until(func():return player.get("warden_block",{}).get("focus")=="vanguard"),
		"actual remote Q casts Thorn Counter after crossing lanes"):return false
	var now := Time.get_ticks_msec()
	var hp: int = PlayerVitals.current_hp(player)
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.DODGE, now+1000)
	IncomingPlayerHit.resolve_world(game, id, PlayerLifecycle.generation(player), now, 4, 0, game.tactics.position)
	var blocks := func():return events.filter(func(e):return e.kind=="actual_block" and e.source_actor==id)
	check(PlayerVitals.current_hp(player)==hp and player[Cooldowns.STATE].deadline(Cooldowns.DODGE)==now and player.get("warden_sanctuary",{}).get("until",0)>now
		and player.get("warden_holdfast",{}).get("actor")==id and local.get("warden_holdfast",{}).get("actor")==id
		and blocks.call().size()==1 and blocks.call()[0].quality=="refined","remote Q block grants Holdfast, creates Sanctuary and runs one source-owned Catalyst")
	local[Protection.STATE] = local[Protection.STATE].clear_expedition()
	mark("ct-r")
	if not check(await until(func():return player.warden_block.quake_used and local[Protection.STATE].charge_count()>0),
		"actual remote Root Quake consumes preparation and shelters nearby host"):return false
	check(blocks.call().size()==1 and events.filter(func(e):return e.kind=="class_action" and e.source_actor==id).size()==1,
		"one remote R response with no duplicate Ward or class activation")
	return true


func selected_graph() -> RefCounted:
	if connected_oracle_case: return Oracle.TREE
	if connected_reaper_case: return Reaper.TREE
	if connected_ranger_case: return Ranger.TREE
	return null


func selected_path() -> Array:
	if connected_oracle_case: return ORACLE_PATH
	return REAPER_PATH if connected_reaper_case else RANGER_PATH


func path_request(graph: RefCounted, node: String) -> String:
	return "learn_%d_%d" % [graph.class_id,graph.REQUEST_OFFSET+graph.nodes.find(graph.node(node))]


func learn_path_host(game: Node, id: int, graph: RefCounted) -> bool:
	if not check(id!=0,"real %s guest is admitted" % graph.label):return false
	var player: Dictionary=game.players[id]
	var selected := selected_path()
	mark("path-learn")
	var first := func() -> bool:
		return (read("path-first")=="ok" and graph.path(player.character)==selected.slice(0,1)
			and player.get("projection_delivery",{}).get("state")=="committed")
	if not check(await until(first),"host commits only the earned focus at level one"):return false
	game.run_guarded_action(id,game.Transactions.Scope.GARDEN,func(effects):
		player.character.xp[graph.class_id]=2600
		game.save_action_profile(id,effects))
	var complete := func() -> bool:
		return (read("path-learned")=="ok" and graph.path(player.character)==selected
			and player.character.upgrades[graph.class_id]==0 and player.get("projection_delivery",{}).get("state")=="committed")
	return check(await until(complete),"host commits six connected choices without touching legacy masks")


func learn_path_guest(game: Node, graph: RefCounted) -> bool:
	var selected := selected_path()
	if not check(await until(func():return read("path-learn")=="ok"),"guest is at the real Garden Gate"):return false
	game.send_garden_action(path_request(graph,selected[0]))
	if not check(await until(func():return graph.path(game.guest_character.data)==selected.slice(0,1)),"guest saves its focus"):return false
	game.send_garden_action(path_request(graph,selected[1]))
	var too_early := "Reach %s level 2" % graph.label
	if not check(await until(func():return too_early in game.status),"host refuses a premature node"):return false
	mark("path-first")
	if not check(await until(func():return game.guest_character.data.xp[graph.class_id]==2600),"guest receives the test’s earned XP"):return false
	for index in range(1,selected.size()):
		if index==(2 if connected_reaper_case else 1):
			var disconnected := "wide_omen" if connected_oracle_case else "clear_the_veil" if connected_reaper_case else "trail_ward"
			game.send_garden_action(path_request(graph,disconnected))
			if not check(await until(func():return "connected to your last selection" in game.status),"host refuses a disconnected lane jump"):return false
		game.send_garden_action(path_request(graph,selected[index]))
		if not check(await until(func():return graph.path(game.guest_character.data)==selected.slice(0,index+1)),
				"guest saves the next connected choice"):return false
	var another_capstone := "fates_refrain" if connected_oracle_case else "last_rites" if connected_reaper_case else "escape_route"
	game.send_garden_action(path_request(graph,another_capstone))
	if not check(await until(func():return "next tier" in game.status),"host refuses a second capstone"):return false
	mark("path-learned")
	return true


func exercise_ranger_host(game: Node,id: int,entry: Vector3,target: Vector3,events: Array) -> bool:
	var ranger: Dictionary=game.players[id]
	var ally: Dictionary=game.players[1]
	game.encounter.set_hp(-1, 150)
	game.tactics.position=target
	game.tactics.stagger_until=Time.get_ticks_msec()+12000
	ranger.pos=entry
	ally.pos=entry
	var direction := entry.direction_to(target)
	mark("ranger-q",JSON.stringify([direction.x,direction.z]))
	var prey_ready := func() -> bool:
		return (int(game.enemy_traits.get(RangerCombat.PREY,{}).get("owner",0))==id
			and ranger.has(RangerCombat.DOUBLE) and read("ranger-prey-seen")=="ok")
	if not check(await until(prey_ready),"actual guest Salvo tracks its survivor and prepares Double Draw"):return false
	ally[WeaponActions.STATE] = ally[WeaponActions.STATE].with_ready_at(0)
	ally.mouse_aim=false
	ally.facing=direction
	game.strike_enemy(1,ally,entry)
	var prey_spent := func() -> bool:
		return (not game.enemy_traits.has(RangerCombat.PREY) and game.combat_events.any(func(e):
			return e.shape=="Tracked Prey triggered"))
	if not check(await until(prey_spent),"host’s actual direct strike consumes the guest Ranger’s prep"):return false
	var serial: int=game.combat_event_serial
	var before := events.filter(func(e):return e.source_actor==id and e.kind=="weapon_contact").size()
	ranger[WeaponActions.STATE] = ranger[WeaponActions.STATE].with_ready_at(0)
	mark("ranger-shoot")
	var arrows := func() -> bool:
		return game.combat_events.filter(func(e):return e.id>serial and e.kind=="projectile" and e.shape=="arrow").size()==2
	if not check(await until(arrows),"remote ordinary attack releases two authoritative arrows"):return false
	var contact := func() -> bool:
		return events.filter(func(e):return e.source_actor==id and e.kind=="weapon_contact").size() > before
	if not check(await until(contact),"remote main arrow hits the real enemy"):return false
	check(events.filter(func(e):return e.source_actor==id and e.kind=="weapon_contact").size()==before+1
		and not ranger.has(RangerCombat.DOUBLE) and not ranger.has(RangerCombat.FOLLOW),
		"the second arrow inherits no Form contact, follows the original aim and spends its preparation")
	return true


func exercise_ranger_guest(game: Node,id: int) -> bool:
	if not check(await until(func():return not read("ranger-q").is_empty()),"guest receives the real Salvo test position"):return false
	var aim: Array=JSON.parse_string(read("ranger-q"))
	game.send_garden_action(Aim.request(game,game.players[id],0,Vector2(float(aim[0]),float(aim[1]))))
	if not check(await until(func():return game.guest_combat_events(game.players[id]).any(func(e):return e.shape==RangerCombat.PREY)),
			"guest sees a separate Tracked Prey status"):return false
	mark("ranger-prey-seen")
	if not check(await until(func():return read("ranger-shoot")=="ok"),"host consumes the guest’s Tracked Prey"):return false
	game.send_action(true)
	return true


func exercise_reaper_host(game: Node,id: int,entry: Vector3,target: Vector3,events: Array) -> bool:
	var reaper: Dictionary = game.players[id]
	game.encounter.set_hp(-1, 150)
	game.tactics.position=target
	game.tactics.stagger_until=Time.get_ticks_msec()+14000
	reaper.pos=entry
	var direction := entry.direction_to(target)
	mark("reaper-aim",JSON.stringify([direction.x,direction.z]))
	var q_ready := func() -> bool:
		return (reaper.has(ReaperCombat.MOMENTUM) and reaper.pos.distance_to(entry)>.22
			and events.any(func(e):return e.source_actor==id and e.kind=="class_action" and e.details.adapter=="reaper/focus/veilwalker/Q")
			and read("reaper-momentum-seen")=="ok")
	if not check(await until(q_ready,3000),"guest uses live Veil Passage with offensive Catalyst and replicated Momentum"):return false
	check(not game.enemy_traits.has("core_strike_mark"),"connected Veil Passage generates no shared Mark")
	var before := events.filter(func(e):return e.source_actor==id and e.kind=="weapon_contact").size()
	reaper[WeaponActions.STATE] = reaper[WeaponActions.STATE].with_ready_at(0)
	mark("reaper-strike")
	var spent := func() -> bool:
		return not reaper.has(ReaperCombat.MOMENTUM) and events.filter(func(e):return e.source_actor==id and e.kind=="weapon_contact").size()==before+1
	if not check(await until(spent,3000),"one live melee contact spends Momentum and emits one ordinary Form contact"):return false
	if not check(game.encounter.scout_count()>0,"the generated floor has a scout for a native class kill"):return false
	reaper.pos=entry
	game.tactics.position=game.battlefield.leader
	var scout: Dictionary = game.encounter.scout(0)
	scout.pos=target
	game.encounter.set_hp(0,1)
	scout.stagger_until=Time.get_ticks_msec()+10000
	scout.windup=0
	reaper[Cooldowns.STATE] = reaper[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	mark("reaper-siphon")
	var active_charge := func() -> bool:
		return game.encounter.hp_for(scout)==0 and int(reaper.get("grave_charges",0))==1 and read("reaper-charge-seen")=="ok"
	if not check(await until(active_charge,5000),"one real Siphon Cut kill grants the guest one native Death Charge"):return false
	check(not reaper.has(ReaperCombat.SIPHON) and events.filter(func(e):return e.source_actor==id and e.kind=="class_action").size()==2,
		"the native Q/R pair emits exactly its two class actions")
	return true


func exercise_reaper_guest(game: Node,id: int) -> bool:
	if not check(await until(func():return not read("reaper-aim").is_empty()),"Reaper receives the live combat aim"):return false
	var direction: Array = JSON.parse_string(read("reaper-aim"))
	var aim := Vector2(float(direction[0]),float(direction[1]))
	game.send_garden_action(Aim.request(game,game.players[id],0,aim,.50))
	if not check(await until(func():return game.guest_combat_events(game.players[id]).any(func(e):return e.shape==ReaperCombat.MOMENTUM and e.combo==id),3000),
			"guest sees its self-owned Momentum"):return false
	mark("reaper-momentum-seen")
	if not check(await until(func():return read("reaper-strike")=="ok"),"host observes Veil Movement"):return false
	game.send_action(true)
	if not check(await until(func():return read("reaper-siphon")=="ok"),"host observes the live melee contact"):return false
	game.send_garden_action(Aim.request(game,game.players[id],1,aim))
	if not check(await until(func():return game.guest_combat_events(game.players[id]).any(func(e):return e.shape=="grave" and e.combo==id and int(e.reach)==1),5000),
			"guest sees one authority-owned Death Charge"):return false
	mark("reaper-charge-seen")
	return true


func exercise_oracle_host(game: Node,id: int,entry: Vector3) -> bool:
	var oracle: Dictionary = game.players[id]
	var host_player: Dictionary = game.players[1]
	oracle.pos=entry
	oracle[PlayerVitals.STATE] = oracle[PlayerVitals.STATE].with_hp(40)
	host_player.pos=entry
	host_player[PlayerVitals.STATE] = host_player[PlayerVitals.STATE].with_hp(60)
	host_player[Protection.STATE] = host_player[Protection.STATE].clear_expedition()
	oracle[Cooldowns.STATE] = oracle[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	oracle.core_cast_until=0
	oracle[Cooldowns.STATE] = oracle[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	game.tactics.stagger_until=Time.get_ticks_msec()+14000
	mark("oracle-q")
	var q_ready := func() -> bool:
		var now := Time.get_ticks_msec()
		var blessing := Omens.strongest(game,host_player,Oracle.SECOND_BREATH,now,id)
		return not blessing.is_empty() and PlayerVitals.current_hp(host_player)>60 and read("oracle-q-seen")=="ok"
	if not check(await until(q_ready,3200),"guest Oracle Q heals host and both observe the source-owned Blessing"):return false
	mark("oracle-r")
	var r_ready := func() -> bool:
		var now := Time.get_ticks_msec()
		return not Omens.strongest(game,host_player,Oracle.MERCY,now,id).is_empty() \
			and int(host_player[Protection.STATE].guard_until_ms())>now and read("oracle-r-seen")=="ok"
	if not check(await until(r_ready,2500),"remote Chime arms native Ward and projected Portent of Mercy"):return false
	var before := int(PlayerVitals.current_hp(host_player))
	var now := Time.get_ticks_msec()
	host_player[Conditions.STATE] = host_player[Conditions.STATE].clear_grace()
	Frost.with_attacker(game,-1,IncomingPlayerHit.resolve_world.bind(game, 1, PlayerLifecycle.generation(host_player), now, 1.0))
	check(host_player[Protection.STATE].charge_count()==0 and PlayerVitals.current_hp(host_player)==before+6
		and not Omens.strongest(game,host_player,Oracle.MERCY,now,id).is_empty(),"remote Oracle Ward blocks and heals without spending a conditional recovery")
	host_player[Conditions.STATE] = host_player[Conditions.STATE].clear_grace()
	Frost.with_attacker(game,-1,IncomingPlayerHit.resolve_world.bind(game, 1, PlayerLifecycle.generation(host_player), now+1, 1.0))
	check(PlayerVitals.current_hp(host_player)==before+4 and Omens.strongest(game,host_player,Oracle.MERCY,now+1,id).is_empty()
		and not Omens.strongest(game,host_player,Oracle.SECOND_BREATH,now+1,id).is_empty(),
		"host takes one real hit and only the stronger remote recovery responds")
	mark("oracle-damage-seen")
	return true


func exercise_oracle_guest(game: Node,id: int) -> bool:
	if not check(await until(func():return read("oracle-q")=="ok"),"guest receives the Oracle Q cue"):return false
	game.send_garden_action(Aim.request(game,game.players[id],0,Vector2.RIGHT,0.0))
	if not check(await until(func():return game.guest_combat_events(game.players[id]).any(func(e):
		return e.shape==Oracle.SECOND_BREATH and int(e.combo)==1),3200),"guest sees the host's Second Breath status"):return false
	mark("oracle-q-seen")
	if not check(await until(func():return read("oracle-r")=="ok"),"guest receives the Oracle R cue"):return false
	game.send_garden_action(Aim.request(game,game.players[id],1,Vector2.RIGHT))
	if not check(await until(func():return game.guest_combat_events(game.players[id]).any(func(e):
		return e.shape==Oracle.MERCY and int(e.combo)==1),2300),"guest sees the host's Portent of Mercy status"):return false
	mark("oracle-r-seen")
	return check(await until(func():return read("oracle-damage-seen")=="ok"),"host resolves the remote grant on contact")


func learn_weaver_host(game: Node, id: int, catalyst: int) -> bool:
	if not check(id!=0,"a real Weaver peer joined"):return false
	var player: Dictionary=game.players[id]
	if not check(await until(func():return player.prepared_catalyst==catalyst),"Weaver Catalyst committed"):return false
	mark("weaver-learn")
	if not check(await until(func():
		return (read("weaver-level-one")=="ok" and Weaver.TREE.path(player.character)==["bloomcaller"]
			and player.get("projection_delivery",{}).get("state")=="committed")),
		"host validates and guest commits Weaver focus"):return false
	game.run_guarded_action(id,game.Transactions.Scope.GARDEN,func(effects):
		player.character.xp[1]=2600
		game.save_action_profile(id,effects))
	return check(await until(func():
		return (read("weaver-learned")=="ok" and Weaver.TREE.path(player.character)==WEAVER_PATH
			and player.character.upgrades[1]==0 and player.get("projection_delivery",{}).get("state")=="committed")),
		"guarded host and guest agree on all six Weaver choices and untouched old mask")


func learn_weaver_guest(game: Node) -> bool:
	if not check(await until(func():return read("weaver-learn")=="ok"),"Weaver is at title-admitted host's Gate"):return false
	game.send_garden_action("learn_1_65")
	if not check(await until(func():return Weaver.TREE.path(game.guest_character.data)==["bloomcaller"]),"committed Weaver focus reaches owner"):return false
	game.send_garden_action("learn_1_69")
	if not check(await until(func():return "Reach Weaver level 2" in game.status),"host refuses premature Weaver node"):return false
	mark("weaver-level-one")
	if not check(await until(func():return game.guest_character.data.xp[1]==2600),"guest receives earned class XP"):return false
	for index in range(1,WEAVER_PATH.size()):
		if index==2:
			game.send_garden_action("learn_1_70")
			if not check(await until(func():return "connected to your last selection" in game.status),"host refuses disconnected choice"):return false
		var node := Weaver.TREE.node(WEAVER_PATH[index])
		game.send_garden_action("learn_1_%d"%(Weaver.TREE.REQUEST_OFFSET+Weaver.TREE.nodes.find(node)))
		if not check(await until(func():return Weaver.TREE.path(game.guest_character.data)==WEAVER_PATH.slice(0,index+1)),
			"guest saves successive Weaver node"):return false
	mark("weaver-learned")
	return true


func exercise_weaver_host(game: Node, id: int, entry: Vector3, target: Vector3, events: Array) -> bool:
	var player: Dictionary=game.players[id]
	game.encounter.set_hp(-1, 150)
	game.tactics.position=target
	game.tactics.stagger_until=Time.get_ticks_msec()+12500
	player.pos=entry
	var aim := (target-entry).normalized()
	var nova_deadline := Time.get_ticks_msec() + 1200
	player[Cooldowns.STATE] = player[Cooldowns.STATE].with_deadline(Cooldowns.R, nova_deadline)
	mark("weaver-q", str(Vector2(aim.x,aim.z)) + ":" + str(entry.distance_to(target)))
	if not check(await until(func():return player.has("weaver_nova_origin") and game.trait_events.any(func(e):
		return e.get("native_weaver_bloom",false) and e.owner==id)),"remote Cultivate Bloom records its actual placement"):return false
	if not check(int(player[Cooldowns.STATE].deadline(Cooldowns.R)) < nova_deadline and int(player[Cooldowns.STATE].deadline(Cooldowns.R)) <= Time.get_ticks_msec()
			and not player.has("subclass_follow"),"remote Cultivate Bloom immediately makes the active Nova timer ready"):return false
	var anchor: Vector3=player.weaver_nova_origin.point
	var q_timer: int=player[Cooldowns.STATE].deadline(Cooldowns.Q)
	check(anchor.distance_to(target)<.2 and game.Skills.resolve_in_world(game,1,0,player.character).name=="Cultivate Bloom",
		"crossed lane preserves remote Bloomcaller Q")
	mark("weaver-r",str(Vector2(anchor.x,anchor.z)))
	if not check(await until(func():return not player.has("weaver_nova_origin") and read("weaver-nova-seen")=="ok"),
		"remote R consumes Q location and guest sees the additional Nova"):return false
	var responses := events.filter(func(e):return e.source_actor==id and e.kind=="class_action" and e.details.adapter.begins_with("weaver/"))
	check(player[Cooldowns.STATE].deadline(Cooldowns.Q)==q_timer-1250 and responses.size()==2 and responses.all(func(e):return e.quality=="refined"),
		"actual Nova damage refunds Q and each remote cast produces one source-owned Catalyst response")
	return true


func install_party_grafts(game: Node, ids: Array) -> bool:
	var old_floor: int = game.participation.floor()
	var knowledge: int = game.progress.knowledge
	ExpeditionCase.set_world(game, {"encounter_number": 8})
	for index in ids.size():
		var id: int = ids[index]
		var visitor: Dictionary = game.players[id]
		var improvement: String = ["cinder_field","prismatic_echo","funeral_charges"][index]
		var item: String = Improvements.ADAPTATIONS[improvement].item
		var material: int = game.Items.get_item(item).legacy_part
		visitor.pos = game.battlefield.graft
		visitor.carried_parts[material] = 2
		mark("install-"+str(id),improvement+":"+item)
		if not check(await until(func():return read("graft-seen-"+str(id))=="ok"),"guest confirms the exact matching trophy and receives its ledger"): return false
		var ledger := Improvements.owner_details(visitor, game.participation.floor())
		check(ledger.copies.size()==1 and ledger.copies[0].id==improvement and ledger.copies[0].item==item
			and visitor.carried_parts[material]==1,"authority charges the selected part once")
		if not check(await until(func():return "already used" in visitor.get("graft_message",""),3000),
			"host rejects a duplicate request at the same altar"): return false
		check(visitor.carried_parts[material]==1,"the replay spends no second trophy")
	check(game.progress.knowledge==knowledge,"guest purchases give no permanent Knowledge")
	ExpeditionCase.set_world(game, {"encounter_number": old_floor})
	return true


func plan_speed_offer(game: Node, player: Dictionary, reroll: bool) -> Dictionary:
	var stats: Dictionary = game.weapon_stats(player)
	var cost: int = UpgradeCards.Catalog.PLAYTEST.reroll_costs[0] if reroll else 0
	var essence: int = game.run_wallet(player)
	if essence < cost:
		return {}
	var ledger := UpgradeCards.ledger(player)
	if ledger == null:
		ledger = UpgradeCards.Ledger.new()
	for seed_value in range(1,33):
		player.upgrade_seed = seed_value
		var floor_number: int = game.participation.floor()
		var dodge_base: int = game.DODGE_COOLDOWN_MS
		var offer := ledger.open_offer(floor_number, 1, seed_value, stats, dodge_base)
		var options: Array = offer.roll(seed_value, floor_number, stats, dodge_base, true) if reroll else offer.offer().cards
		var index := options.find_custom(func(option):return option.id==SPEED_CARD)
		if index >= 0:
			var next_ms := maxi(230, int(stats.interval) - int(options[index].amount))
			return {"choice":index, "before":"%.2f" % (1000.0 / int(stats.interval)), "after":"%.2f" % (1000.0 / next_ms),
				"spent":cost, "balance":essence-cost}
	return {}


func check_speed_face(game: Node, offer: Dictionary) -> void:
	var face: VBoxContainer = game.checkpoint_cards.get_child(int(offer.choice)).get_child(0)
	var label: String = face.get_child(2).get_child(0).text
	var preview := "Attack speed: %s → %s attacks/sec" % [offer.before, offer.after]
	check(face.get_child(0).text=="Light Grip" and preview in label,
		"Light Grip's real card face matches host-resolved attack speeds")


func has_attack_speed(game: Node, player: Dictionary, stats: Dictionary, expected: String) -> bool:
	var summary := RunSummary.project(game,player,stats)
	return summary.get("totals",[]).any(func(row):return row[0]=="Attack speed" and row[1]==expected+" attacks/sec")


func guest(menu: Node, role: String) -> void:
	menu.request_create_character()
	var starting_class: int = [1,2,4][clampi(int(role)-1,0,2)] if native_graft_case or connected_weaver_case else 0
	var graph := selected_graph()
	if graph != null:
		starting_class=([4,1,2] if connected_oracle_case else [graph.class_id,1,4])[clampi(int(role)-1,0,2)]
	menu.create_character("Frost guest "+role,starting_class,Appearance.DEFAULT)
	if not check(await until(func():return read("host")=="ok"),"host ready"):return
	begin_join(menu)
	if not check(await until(func():return SessionCase.role(tree.current_scene)=="Guest" and tree.current_scene.stage.experimental_garden.remote_revision>=0),"actual title joins isolated frost Garden"):return
	var game:=tree.current_scene
	var id: int=game.local_player_id()
	var identity: String=game.guest_character.identity
	var terrain = game.stage.experimental_garden
	var garden_outline := str(terrain.state.outline).sha256_text()
	var selection := "select-"+str(id)
	if not check(await until(func():return not read(selection).is_empty()),"host stocked and positioned party"):return
	var picks := read(selection).split(":")
	game.send_garden_action("loadpart_1_"+picks[0])
	if int(picks[1])>0:
		game.send_garden_action("loadpart_0_"+picks[1])
	if int(picks[2])>0:
		game.send_garden_action("loadpart_2_"+picks[2])
	if native_graft_case:
		game.send_garden_action("loadweapon_1")
	if not connected_warden_case and not (connected_weaver_case and starting_class==1) and (graph==null or starting_class!=graph.class_id):
		var focus_request := 66 if starting_class==0 or (starting_class==4 and not native_graft_case) else 64
		game.send_garden_action("learn_%d_%d" % [starting_class,focus_request])
	if graph != null and starting_class==graph.class_id and not await learn_path_guest(game,graph):
		return
	if connected_weaver_case and starting_class==1 and not await learn_weaver_guest(game):
		return
	if connected_warden_case and not await learn_connected_guest(game):
		return
	if not check(await until(func():return not read("depart").is_empty()),"host authorizes departure"):return
	game.send_garden_action("travel_ready:"+read("depart"))
	if native_graft_case:
		if not check(await until(func():return not read("install-"+str(id)).is_empty() and game.stage._has_experimental_floor()),
			"real guest can request its graft on the shared floor"): return
		var selection_fields := read("install-"+str(id)).split(":")
		if not check(await until(func():return game.participation.floor()==8 and game.at_graft_altar(game.players[id])),
			"guest has reached the same altar"):return
		game.send_garden_action("graft")
		if not check(await until(func():return game.graft_menu.visible and game.graft_view.data.get("floor",0)==8),
			"guest receives its authoritative altar choices"):return
		var request := Improvements.request(game.graft_view.data,selection_fields[0],selection_fields[1])
		game.send_garden_action(request)
		if not check(await until(func():
			var copies: Array = game.players[id].get("graft_improvements",{}).get("copies",[])
			return copies.size()==1 and copies[0].id==selection_fields[0] and copies[0].item==selection_fields[1]),
			"guest receives its committed purchase once in owner details"):return
		game.send_garden_action(request)
		if not check(await until(func():return "already used" in game.graft_view.data.get("status","")),
			"guest receives duplicate refusal"):return
		game.toggle_overlay(null)
		mark("graft-seen-"+str(id))
	if not check(await until(func():return read("strike-"+str(id))=="ok" and game.stage._has_experimental_floor()),"guest sees generated Frost floor"):return
	game.send_action(true)
	if connected_warden_case:
		if not check(await until(func():return read("ct-q")=="ok"),"connected Warden receives Q timing"):return
		game.send_garden_action("class_skill")
		if not check(await until(func():return read("ct-r")=="ok"),"connected Warden's actual block qualifies"):return
		if not check(await until(func():
			var effects: Array=game.guest_combat_events(game.players[id])
			return effects.any(func(event):return event.shape=="sanctuary_ground") and effects.any(func(event):return event.shape=="holdfast" and event.combo==id),2000),
			"guest sees authoritative Holdfast and Sanctuary through the existing event stream"):return
		game.send_garden_action("class_skill_two")
	elif connected_weaver_case and starting_class==1:
		if not check(await until(func():return not read("weaver-q").is_empty()),"await Weaver Q on generated floor"):return
		if not check(await until(func():return not game.players[id].get("skill_two_ready",true),900),
			"guest sees the active Nova cooldown before casting"):return
		var release := read("weaver-q").split(":")
		var vector := release[0].trim_prefix("(").trim_suffix(")").split(",")
		game.send_garden_action(Aim.request(game,game.players[id],0,Vector2(float(vector[0]),float(vector[1])),float(release[1])))
		if not check(await until(func():return not read("weaver-r").is_empty()),"await real recorded Bloom center"):return
		if not check(await until(func():return game.players[id].get("skill_two_ready",false),900),
			"guest receives the host's immediate Nova readiness"):return
		var location := read("weaver-r").trim_prefix("(").trim_suffix(")").split(",")
		var center := Vector3(float(location[0]),0,float(location[1]))
		game.send_garden_action(Aim.request(game,game.players[id],1,Vector2.DOWN))
		if not check(await until(func():return game.guest_combat_events(game.players[id]).any(func(e):
			return e.shape=="nova" and is_equal_approx(float(e.reach),2.0) and Vector3(e.to[0],e.to[1],e.to[2]).distance_to(center)<.2)),
			"authoritative secondary Nova position reaches the real guest"):return
		mark("weaver-nova-seen")
	elif graph != null and starting_class==graph.class_id:
		if connected_reaper_case:
			if not await exercise_reaper_guest(game,id): return
		elif connected_oracle_case:
			if not await exercise_oracle_guest(game,id): return
		elif not await exercise_ranger_guest(game,id): return
	elif int(picks[2])>0:
		if not check(await until(func():return read("wood-guard-"+str(id))=="ok"),"host requests actual Wood Ward"):return
		game.send_garden_action("class_skill")
	if int(picks[1])>0:
		if not check(await until(func():return not read("cast-"+str(id)).is_empty()),"host asks guest to cast at actual enemy"):return
		var raw := read("cast-"+str(id)).trim_prefix("(").trim_suffix(")").split(",")
		game.send_garden_action(Core.request(game,game.players[id],Vector2(float(raw[0]),float(raw[1])),1.1))
		var material := preload("res://plant_affinities.gd").for_part(int(picks[1]))
		if material.get("primary_affinity")=="thorn":
			if check(await until(func():
				return read("thorn-"+str(id))=="ok" and game.players[id].get("attack_hints",[]).any(func(hint):
					return hint.get("skill")=="thorn_line" and not hint.get("core_shapes",[]).is_empty())),
				"the guest sees the same stationary Thorn Line footprint"):
				mark("thorn-seen-"+str(id))
		if material.get("primary_affinity")=="wood":
			if check(await until(func():
				return read("bark-"+str(id))=="ok" and game.guest_combat_events(game.players[id]).any(func(e):return e.shape=="bark_armor")),
				"guest sees authoritative temporary Bark status"):
				mark("bark-seen-"+str(id))
		if material.get("primary_affinity")=="vital":
			var marker := "vital-"+str(id)
			check(await until(func():return not read(marker).is_empty() and int(game.players[id].max_hp)==int(read(marker))),"guest receives authoritative Vital capacity")
			mark("vital-seen-"+str(id))
	if native_graft_case and party and measure_packets: await sample_guest_snapshots(game,id)
	if party and not connected_weaver_case and graph==null and not native_graft_case:
		if measure_packets: await sample_guest_snapshots(game,id)
		if mixed_wood_ward and measure_packets: await verify_current_snapshot_guest(game,id)
		if check(await until(func():return read("party-done")=="ok",22000),"host observes mixed-source party"):
			mark("done-"+str(id))
			check(await until(func():return read("offline")=="ok" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"guest observes party shutdown")
		return
	if affinity_cards_case:
		var offer_received := func() -> bool:
			return read("affinity-cards")=="ok" and game.checkpoint_offer_revision>0 and game.checkpoint_cards.get_child_count()==3
		if not check(await until(offer_received),"mixed-class guest receives three eligible cards"):return
		var speed: Dictionary = JSON.parse_string(read("attack-speed-"+str(id)))
		if int(speed.spent) > 0:
			var revision: int = game.checkpoint_offer_revision
			var reroll: String = game.affinity_checkpoint_action(revision, "reroll")
			game.send_garden_action(reroll)
			game.send_garden_action(reroll)
			if not check(await until(func(): return game.checkpoint_offer_revision > revision),
				"one guest receives a rerolled offer after replaying the first revision"):return
		check_speed_face(game, speed)
		game.send_garden_action(game.affinity_checkpoint_action(game.checkpoint_offer_revision,str(int(speed.choice))))
		var received := func() -> bool:
			var player: Dictionary = game.players.get(id,{})
			var copies: Array = player.get("affinity_run_cards",[])
			return copies.size()==1 and copies[0].id==SPEED_CARD and int(player.get("wallet", -1))==int(speed.balance) \
				and has_attack_speed(game,player,player.get("weapon_stats",{}),speed.after)
		if not check(await until(received),"the guest's replicated copy and Tab projection match the host"):return
		mark("owned-"+str(id))
	if not check(await until(func():return not read("advance").is_empty() and game.enemy_health()==0 and int(game.party_travel_state().get("epoch",-1))==int(read("advance"))),"guest sees cleared Gate"):return
	if connected_warden_case:
		var canonical := ConfigFile.new()
		var expected := int(read("ct-xp"))
		check(expected>2600 and game.guest_character.data.xp[0]==expected and canonical.load(game.guest_character.path)==OK
			and canonical.get_value("character","progress",{}).get("xp",[])[0]==expected,"guest's displayed profile and local save agree with host whole XP")
	if graph != null and starting_class==graph.class_id:
		var canonical := ConfigFile.new()
		var expected := int(read("path-xp"))
		check(expected>2600 and canonical.load(game.guest_character.path)==OK
			and graph.path(canonical.get_value("character","progress",{}))==selected_path()
			and game.guest_character.data.xp[graph.class_id]==expected,"guest canonical file and host agree on class path and floor XP")
	if connected_weaver_case and starting_class==1:
		var canonical := ConfigFile.new()
		var expected := int(read("weaver-xp"))
		check(expected>2600 and game.guest_character.data.xp[1]==expected and canonical.load(game.guest_character.path)==OK
			and canonical.get_value("character","progress",{}).get("xp",[])[1]==expected
			and Weaver.TREE.path(canonical.get_value("character","progress",{}))==WEAVER_PATH,
			"committed guest bytes agree with host on Weaver path and XP after reward")
	game.send_travel_ready(false)
	if not check(await until(func():return game.participation.depth()==2 and game.stage.visual_field.configured_key.z==game.participation.seed()),"guest tracks next floor"):return
	if affinity_cards_case:
		check(await until(func():return game.players.get(id,{}).get("affinity_run_cards",[]).size()==1),
			"mixed-class guest still owns its copy on the next floor")
	if native_graft_case:
		check(await until(func():
			var ledger: Dictionary = game.players[id].get("graft_improvements",{})
			return ledger.get("floor",0)==2 and ledger.get("copies",[]).size()==1),
			"guest has the same acquired adaptation on the real next floor")
	mark("guest-floor-"+str(id))
	if not check(await until(func():return not read("extract").is_empty() and int(game.party_travel_state().get("epoch",-1))==int(read("extract"))),"guest receives extraction"):return
	game.send_travel_ready(false)
	if not check(await until(func():return not ExpeditionCase.is_wild(game.players[id])),"guest returns to Garden"):return
	if native_graft_case:
		check(await until(func():return game.players[id].get("graft_improvements",{}).is_empty()),
			"owner details clear the graft purchases on return")
	check(str(terrain.state.outline).sha256_text()==garden_outline,"same Garden outline after Frost play")
	mark("guest-garden-"+str(id))
	if party:
		if check(await until(func():return read("party-done")=="ok",22000),"four-player expedition returned"):
			mark("done-"+str(id))
			check(await until(func():return read("offline")=="ok" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),
				"mixed party observes normal shutdown")
		return
	if native_graft_case and not check(await until(func():return read("grafts-cleared")=="ok"),
		"host confirms extraction cleanup before the guest disconnects"):return
	game.return_to_main_menu()
	if not check(await until(func():return read("detached")=="ok" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"normal offline-before-rejoin transition"):return
	begin_join(tree.current_scene)
	if not check(await until(func():return SessionCase.role(tree.current_scene)=="Guest" and tree.current_scene.stage.experimental_garden.remote_revision>=0),"same isolated profile rejoins"):return
	check(tree.current_scene.guest_character.identity==identity,"stable character identity across rejoin")
	if native_graft_case:
		var rejoined = tree.current_scene
		var clean := func() -> bool:
			var current: Dictionary = rejoined.players.get(rejoined.local_player_id(),{})
			return not current.is_empty() and current.get("graft_improvements",{}).is_empty()
		check(await until(clean),"rejoining the same character restores no prior run's grafts")
	if connected_warden_case:
		var rejoined = tree.current_scene
		var profile: Dictionary = rejoined.guest_character.data
		check(ConnectedWarden.path(profile)==CT_PATH and rejoined.Skills.resolve_in_world(rejoined,0,0,profile).name=="Thorn Counter"
			and profile.xp[0]==int(read("ct-xp")),"same committed path, Q and XP survive rejoin without a repeated award")
	if connected_weaver_case:
		var rejoined = tree.current_scene
		var profile: Dictionary = rejoined.guest_character.data
		check(Weaver.TREE.path(profile)==WEAVER_PATH and rejoined.Skills.resolve_in_world(rejoined,1,0,profile).name=="Cultivate Bloom"
			and profile.xp[1]==int(read("weaver-xp")),"committed Weaver path, focus and earned XP survive rejoin")
	if graph != null:
		var rejoined = tree.current_scene
		var profile: Dictionary = rejoined.guest_character.data
		var q := "Living Sanctuary" if connected_oracle_case else "Veil Passage" if connected_reaper_case else "Hunter’s Salvo"
		var r := "Warding Chime" if connected_oracle_case else "Siphon Cut" if connected_reaper_case else "Bramble Snare"
		check(graph.path(profile)==selected_path() and profile.xp[graph.class_id]==int(read("path-xp"))
			and rejoined.Skills.resolve_in_world(rejoined,graph.class_id,0,profile).name==q
			and rejoined.Skills.resolve_in_world(rejoined,graph.class_id,1,profile).name==r,
			"rejoin retains all six choices, XP, focus Q and R")
		mark("rejoined")
		var at_heart := func() -> bool:
			return read("path-respec-now")=="ok" and rejoined.at_heart(rejoined.players[rejoined.local_player_id()])
		if not check(await until(at_heart),"rejoined guest is in reach of the Heart for respec"):return
		rejoined.send_garden_action("respec_%d" % graph.class_id)
		var cleared := func() -> bool:
			return graph.path(rejoined.guest_character.data).is_empty() and rejoined.guest_character.data.xp[graph.class_id]==int(read("path-xp"))
		if not check(await until(cleared),"guest acknowledges refunded choices and preserved XP"):return
		mark("path-refunded")
	mark("rejoined")
	check(await until(func():return read("saved")=="ok"),"host verifies no replay or debit")
	check(await until(func():return read("offline")=="ok" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"guest observes host shutdown")


func verify_current_snapshot_host(game: Node, ids: Array, local: Dictionary) -> void:
	var wood = preload("res://wood_affinity.gd")
	var thorn = preload("res://thorn_affinity.gd")
	var clock = preload("res://affinity_time.gd")
	var fields: Array = thorn.active_fields(game,clock.now(game))
	check(not fields.is_empty(),"at least one Thorn field is live before the expiry check")
	var statuses: Array = game.combat_events_snapshot()
	var bark: Array = statuses.filter(func(e):return e.kind=="status" and e.shape=="bark_armor" and e.combo==1)
	if not check(not bark.is_empty() and local.has(wood.GRANTS),"active Bark is advertised before depletion"): return
	mark("snapshot-full-ready",str(bark[0].id))
	if not check(await until(func():return ids.all(func(id):return read("snapshot-full-ready-"+str(id))=="ok"),2500),
		"every guest saw the existing Bark status"): return

	var limit: int = game.EncounterConfig.MAX_SCOUTS
	var before_scouts: int = game.encounter.scout_count()
	var at: Vector3 = game.encounter.scout(game.encounter.scout_count()-1).pos
	for index in range(before_scouts,limit):
		var scout: Dictionary = game.make_scout(0,at,index+1)
		scout.stagger_until=Time.get_ticks_msec()+8000
		game.encounter.register_scout(scout)
	var witnesses: Array = []
	game.set_meta(&"snapshot_witness",func(row):record_snapshot(witnesses,row))
	# Two nonlethal authority hits within one frame. There is no intervening
	# fast snapshot of the partially depleted armor or first HP value.
	local[PlayerVitals.STATE] = PlayerVitals.Health.new(250,250)
	local[Protection.STATE] = local[Protection.STATE].clear_expedition()
	var now := Time.get_ticks_msec()
	for hp in [10,120]:
		local[Conditions.STATE] = local[Conditions.STATE].clear_grace()
		IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(local), now, float(hp)/game.Life.Preview.scale(), 0, game.tactics.position)
	var burst: Array = game.combat_events.filter(func(e):return e.shape=="wood_burst" and e.get("label")=="Bark break")
	check(not local.has(wood.GRANTS) and burst.size()==1 and PlayerVitals.current_hp(local)<250 and PlayerVitals.current_hp(local)>0,"host consumes Bark once and emits one break response")
	if burst.is_empty():return
	mark("snapshot-full-state", "%d:%d" % [int(PlayerVitals.current_hp(local)),int(burst[0].id)])
	var epoch: int=game.participation.epoch()
	if not check(await until(func():return ids.all(func(id):return read("snapshot-full-seen-"+str(id))=="ok"),3500),
		"full-occupancy snapshots converge and the old Bark status is removed on each guest"): return
	game.remove_meta(&"snapshot_witness")
	var max_frame: int = preload("res://world_snapshot.gd").MAX_FRAME
	check(ids.all(func(id):return witnesses.any(func(row):return row.peer==id and row.bytes==max_frame and row.error==OK)),
		"real sends reach the full payload bound for each guest")
	print("SNAPSHOT_FULL ",JSON.stringify({"peers":ids,"application_bytes":max_frame,"scouts":limit}))
	check(await until(func():return thorn.active_fields(game,clock.now(game)).is_empty(),8500) and game.participation.epoch()==epoch,
		"Thorn expires and stops applying field contact on the same floor")
	mark("snapshot-thorn-expired")
	check(await until(func():return ids.all(func(id):return read("snapshot-thorn-expired-"+str(id))=="ok"),3000),
		"guests remove expired Thorn footprints from current presentation")


func verify_current_snapshot_guest(game: Node, id: int) -> void:
	if not check(await until(func():return not read("snapshot-full-ready").is_empty(),5000),"host starts full snapshot check"):return
	var bark := int(read("snapshot-full-ready"))
	if not check(await until(func():
		return game.combat_visuals.statuses.active.has(bark) and game.combat_visuals.hints.values().any(func(h):
			return h.event.get("skill")=="thorn_line"),2000), "Bark and Thorn presentation are present before expiry"):return
	var received: Array = []
	game.set_meta(&"snapshot_witness",func(row):record_snapshot(received,row))
	mark("snapshot-full-ready-"+str(id))
	if not check(await until(func():return not read("snapshot-full-state").is_empty(),3500),"host releases latest state marker"):return
	var expected := read("snapshot-full-state").split(":")
	var max_frame: int = preload("res://world_snapshot.gd").MAX_FRAME
	if not check(await until(func():
		return game.client_pack.size()==game.EncounterConfig.MAX_SCOUTS*game.PACK_STRIDE and int(game.players[1].hp)==int(expected[0]) \
			and game.combat_visuals.seen.has(int(expected[1])) and game.combat_visuals.statuses.ended.has(bark) \
			and not game.combat_visuals.statuses.active.has(bark) \
			and received.any(func(row):return row.phase=="receive" and row.bytes==max_frame),3500),
		"guest converges after skipped intermediate Bark and HP state, with one break event identity"):return
	game.remove_meta(&"snapshot_witness")
	mark("snapshot-full-seen-"+str(id))
	if not check(await until(func():return read("snapshot-thorn-expired")=="ok",10500),"host expires its Thorn field"):return
	if check(await until(func():
		return not game.players[id].get("attack_hints",[]).any(func(e):return e.get("skill")=="thorn_line") \
			and not game.combat_visuals.hints.values().any(func(h):return h.event.get("skill")=="thorn_line"),3500),
		"guests remove old Thorn state and rendered hints"):
		mark("snapshot-thorn-expired-"+str(id))


const PROBE_FIRST := 101
const PROBE_COUNT := 8
const PROBE_DURATION := .22


func record_snapshot(rows: Array, row: Dictionary) -> void:
	if rows.size()<420:
		rows.append(row)


func sample_host_snapshots(game: Node, ids: Array) -> void:
	var rows: Array = []
	game.set_meta(&"snapshot_witness",func(row):record_snapshot(rows,row))
	var previous: Vector3=game.drop_pos
	game.encounter.set_hp(-1, 487)
	game.tactics.stagger_until=Time.get_ticks_msec()+9000
	if native_graft_case:
		var caster: Dictionary = game.players[ids[0]]
		if not check(await until(func():return Time.get_ticks_msec()>=int(Grafts.counters(caster,"monster:ashen_hart").get("ready_at",0)),4500),
			"wait for the real Cinder response interval before sampling"): return
	mark("snapshot-arm")
	if not check(await until(func():return ids.all(func(id):return read("snapshot-ready-"+str(id))=="ok"),4000),"every guest is watching the probe"):
		return
	if final_family_mix:
		var local: Dictionary=game.players[1]
		local.frame=4
		local.character.upgrades[4]=0
		local.character[Oracle.PROFILE_KEY]=Oracle.TREE.state(["lifekeeper"])
		local.catalyst=game.Items.get_item("plant_part_rare_storm_reed").legacy_part
		local[Cooldowns.STATE] = local[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0);local.cast_until=0;local.core_cast_until=0
		for id in ids:
			if id!=ids[1]: game.players[id].pos=local.pos
		local.class_aim_distance=0.0
		game.use_class_skill(1,local,0)
		check(game.players[ids[0]].get("affinity_storm_charge",{}).get("actor")==1,
			"real Oracle healing grants an authoritative Storm Charge to a guest")
		var position: Vector3=game.encounter.scout(game.encounter.scout_count()-1).pos
		while game.encounter.scout_count()<game.EncounterConfig.MAX_SCOUTS:
			var scout: Dictionary=game.make_scout(0,position,game.encounter.scout_count()+1)
			scout.stagger_until=Time.get_ticks_msec()+6000
			game.encounter.register_scout(scout)
		var caster: Dictionary=game.players[ids[2]]
		caster.core_ready_at=0;caster.cast_until=0;caster.core_cast_until=0
		var aim: Vector3=(game.tactics.position-caster.pos).normalized()
		game.garden_action(ids[2],Core.request(game,caster,Vector2(aim.x,aim.z),1.1))
	if native_graft_case:
		var position: Vector3 = game.encounter.scout(game.encounter.scout_count()-1).pos
		while game.encounter.scout_count()<game.EncounterConfig.MAX_SCOUTS:
			var scout: Dictionary = game.make_scout(0,position,game.encounter.scout_count()+1)
			scout.stagger_until=Time.get_ticks_msec()+6000
			game.encounter.register_scout(scout)
		var caster: Dictionary = game.players[ids[0]]
		caster[WeaponActions.STATE] = caster[WeaponActions.STATE].with_ready_at(0)
		game.strike_enemy(ids[0],caster,caster.pos)
		if not check(await until(func():return game.trait_events.any(func(e):
			return e.get("graft_source",{}).get("component_id")=="monster:ashen_hart"),1300),
			"a real Cinder field is active at full scout occupancy"): return
	for index in PROBE_COUNT:
		var marker := PROBE_FIRST+index
		game.drop_pos=Vector3(marker,0,0)
		mark("snapshot-probe-"+str(marker))
		await tree.create_timer(PROBE_DURATION).timeout
	await tree.create_timer(.4).timeout
	game.drop_pos=previous
	game.remove_meta(&"snapshot_witness")
	check(await until(func():return ids.all(func(id):return read("snapshot-seen-"+str(id))=="ok"),4000),"all guests processed current authoritative state")
	if final_family_mix or native_graft_case:
		var cap: int=preload("res://world_snapshot.gd").MAX_FRAME
		check(ids.all(func(id):return rows.any(func(row):return row.phase=="send" and row.peer==id and row.bytes==cap)),
			"all peers receive a full-occupancy sized hot frame while new effects are active")
	print("SNAPSHOT_HOST ",JSON.stringify(rows))


func sample_guest_snapshots(game: Node, id: int) -> void:
	if not check(await until(func():return read("snapshot-arm")=="ok"),"snapshot probe is armed"):
		return
	var rows: Array=[]
	game.set_meta(&"snapshot_witness",func(row):record_snapshot(rows,row))
	var start_sequence: int=game.net_view.snapshot_received
	var gap_start: int=game.net_view.snapshot_gaps
	var stale_start: int=game.net_view.rejected_snapshots
	var starts: Dictionary={}
	var observed: Dictionary={}
	var max_frame_us:=0
	var saw_charge:=false
	var saw_well:=false
	var previous := Time.get_ticks_usec()
	var began := previous
	var deadline:=previous+4000000
	mark("snapshot-ready-"+str(id))
	while Time.get_ticks_usec()<deadline:
		await tree.process_frame
		var now:=Time.get_ticks_usec()
		max_frame_us=maxi(max_frame_us,now-previous)
		previous=now
		for marker in range(PROBE_FIRST,PROBE_FIRST+PROBE_COUNT):
			if not starts.has(marker) and read("snapshot-probe-"+str(marker))=="ok":
				starts[marker]=now
		if final_family_mix:
			var view: Dictionary=game.players.get(id,{})
			saw_charge=saw_charge or str(game.player_hud.state.get("affinity_feedback","")).contains("Storm Charge")
			saw_well=saw_well or view.get("attack_hints",[]).any(func(hint):return hint.get("skill")=="gravity_well")
		var marker:=int(game.drop_pos.x)
		if starts.has(marker) and not observed.has(marker) and game.players.size()==4 and game.enemy_health()>400:
			observed[marker]={"local_us":now,"first_marker_read_us":starts[marker],
				"wait_us":now-int(starts[marker]),"sequence":game.net_view.snapshot_received,
				"scouts":game.client_pack.size()/game.PACK_STRIDE}
		if observed.size()==PROBE_COUNT:
			await tree.create_timer(.4).timeout
			break
	game.remove_meta(&"snapshot_witness")
	var last_apply := began
	var max_apply_gap := 0
	for row in rows:
		if row.phase in ["apply","repair_apply"]:
			max_apply_gap = maxi(max_apply_gap, int(row.at) - last_apply)
			last_apply = int(row.at)
	max_apply_gap = maxi(max_apply_gap, Time.get_ticks_usec() - last_apply)
	var valid: bool=observed.size()>=PROBE_COUNT/2 and game.stage._has_experimental_floor() and max_apply_gap <= 500000
	check(valid,"guest sees multiple probe states and receives a fresh current snapshot within 500 ms")
	if final_family_mix:
		var cap: int=preload("res://world_snapshot.gd").MAX_FRAME
		check(saw_well and rows.any(func(row):return row.phase=="receive" and row.bytes==cap),
			"guest receives the Gravity Well footprint and 20-scout snapshot")
		if game.players[id].get("frame",-1)!=4 and not saw_charge:
			# The retreating Spirit may be outside the native healing radius.
			check(int(game.players[id].get("core_part",0))==game.Items.get_item("plant_part_rare_ghost_fern").legacy_part,
				"eligible guests see source-owned Storm Charge and its remaining lifetime")
	print("SNAPSHOT_GUEST ",JSON.stringify({"peer":id,"rows":rows,"observed":observed,
		"start_sequence":start_sequence,"gaps":game.net_view.snapshot_gaps-gap_start,
		"stale":game.net_view.rejected_snapshots-stale_start,"max_frame_us":max_frame_us,"max_apply_gap_us":max_apply_gap}))
	if valid:mark("snapshot-seen-"+str(id))
