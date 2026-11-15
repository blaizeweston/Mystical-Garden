extends RefCounted

const Mode = preload("res://combat_ruleset.gd")
const Frost = preload("res://frost_combat.gd")
const Events = preload("res://combat_action_events.gd")
const Core = preload("res://core_combat.gd")
const Menu = preload("res://main_menu.tscn")
const Appearance = preload("res://character_appearance.gd")

var tree: SceneTree
var signals: String
var port: int
var party := false
var failed := false
var extra_cores: Array = []
var measure_packets := false
var mixed_wood_ward := false


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
	return game.players.keys().filter(func(id):return id!=1 and game.players[id].get("profile_ready",false))


func run(scene_tree: SceneTree, four := false) -> bool:
	tree=scene_tree
	party=four
	var role := OS.get_cmdline_user_args()[0]
	signals=OS.get_environment("MYSTICAL_TERRAIN_TEST_SIGNALS")
	port=int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT"))
	var menu := Menu.instantiate()
	tree.root.add_child(menu)
	tree.current_scene=menu
	if not check(Mode.verified() and Mode.active(menu),"real isolated affinity title"):
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
	if not check(await until(func():return tree.current_scene.get("session")=="Host"),"host through guarded title"): return
	var game:=tree.current_scene
	check(Mode.active(game) and "stocked" in Frost.stock_test_garden(game),"guarded test supplies")
	var ordinary: int=game.Items.get_item("plant_part_plant_frostbell").legacy_part
	var refined: int=game.Items.get_item("plant_part_rare_frostbell").legacy_part
	var local: Dictionary=game.players[1]
	local.pos=game.stage.gate_position()
	game.garden_action(1,"loadpart_0_%d"%ordinary)
	game.garden_action(1,"loadpart_2_%d"%refined)
	mark("host")
	var count:=3 if party else 1
	if not check(await until(func():return guests(game).size()==count),"all expected guests admitted"):return
	var ids:=guests(game)
	ids.sort()
	for id in ids: game.players[id].pos=local.pos
	var supplied := {}
	var ward_guest: int=ids[1] if mixed_wood_ward else 0
	var ordinary_wood: int=game.Items.get_item("plant_part_plant_ironroot").legacy_part
	if mixed_wood_ward: supplied[ordinary_wood]=game.progress.part_count(ordinary_wood)
	for index in ids.size():
		var part := 0
		if not extra_cores.is_empty():
			part = int(game.Items.get_item(extra_cores[index]).legacy_part)
			supplied[part] = game.progress.part_count(part)
		mark("select-"+str(ids[index]),"%d:%d:%d" % [refined,part,ordinary_wood if ids[index]==ward_guest else 0])
	var prepared := func():
		return ids.all(func(id):return game.players[id].prepared_secondary==refined) and supplied.keys().all(func(part):
			return ids.any(func(id):return game.players[id].prepared==part or game.players[id].prepared_catalyst==part))
	if not check(await until(prepared),"real guest loadout requests reach host"):return
	var before_regular: int=game.progress.part_count(ordinary)
	var before_rare: int=game.progress.part_count(refined)
	if party:
		mark("full")
	game.map_rng.seed=16
	game.PartyTravel.request(game,1,"depart")
	mark("depart",str(game.travel_epoch))
	if not check(await until(func():return game.expedition_active() and ids.all(func(id):return game.players[id].wild) and not game.battlefield.generated.is_empty()),"native guarded departure opens generated floor"): return
	check(game.progress.part_count(ordinary)==before_regular-1 and game.progress.part_count(refined)==before_rare-count-1,"exact guarded departure debits")
	var paid := [game.progress.part_count(ordinary),game.progress.part_count(refined)]
	for part in supplied:
		check(game.progress.part_count(part)==supplied[part]-1,"each additional Core is debited once")
	var floor_entry: Vector3=game.battlefield.entry
	var target := floor_entry
	for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		target=game.battlefield.dash(floor_entry,floor_entry+direction*1.10)
		if floor_entry.distance_to(target)>.9:break
	check(floor_entry.distance_to(target)>.8,"usable Frost fixture area on generated floor")
	game.enemy_pos=target
	game.enemy_hp=150
	game.enemy_stagger_until=Time.get_ticks_msec()+18000
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
	local.character.upgrades[0]=1<<1
	local.skill_at=0
	game.use_class_skill(1,local,0)
	ally.hurt_until=0
	var before: float=ally.hp
	game.apply_enemy_hit(protected,ally,Time.get_ticks_msec(),1)
	check(ally.hp==before and rows.any(func(e):return e.kind=="actual_block" and e.source_actor==1 and e.details.recipient==protected and e.quality=="refined"),"actual guest block uses host refined Catalyst")
	if mixed_wood_ward:
		var warded: Dictionary=game.players[ward_guest]
		warded.guard_until=0
		warded.guard_charges=0
		warded.hurt_until=0
		mark("wood-guard-"+str(ward_guest))
		if not check(await until(func():return warded.guard_charges>0),"native remote Q arms Wood Ward"):return
		var hp_before: float=warded.hp
		game.apply_enemy_hit(ward_guest,warded,Time.get_ticks_msec(),2,0,game.enemy_pos)
		check(warded.hp==hp_before and rows.any(func(e):return e.kind=="actual_block" and e.source_actor==ward_guest and e.primary_affinity=="wood" and e.quality=="ordinary"),
			"real Wood Ward bursts with its own provenance after the Frost Ward")
		check(warded.get("affinity_bark_grants",[]).any(func(grant):return grant.actor==ward_guest and grant.quality=="ordinary"),"Wood Ward retains ordinary source capacity")
	for index in extra_cores.size():
		var visitor: Dictionary=game.players[ids[index]]
		var source: int=ids[index]
		var primary: String=preload("res://plant_affinities.gd").for_part(visitor.weapon).primary_affinity
		if primary=="water": local.slow_until=Time.get_ticks_msec()+4000
		var native_max: int=game.Life.native_maximum(game,local)
		if not check(await until(func():
			return Time.get_ticks_msec()>=maxi(int(visitor.get("cast_until",0)),int(visitor.get("core_cast_until",0)))),
			"next remote B waits for the native cast window"):return
		mark("cast-"+str(source),str(Vector2(visitor.facing.x,visitor.facing.z)))
		if not check(await until(func():return rows.any(func(e):return e.kind=="core_action" and e.primary_affinity==primary and e.source_actor==source)),
			"native "+primary+" Core RPC resolves by the host"):return
		match primary:
			"fire":
				check(game.leader_brain.get("affinity_burning",{}).has("%d/core"%source),"guest trail actually ignites leader")
			"water":
				check(await until(func():return local.slow_until==0 and game.leader_brain.get("affinity_drenched",{}).has("%d/core"%source)),
					"guest Dewfall cleanses host and actually Drenches leader")
			"thorn":
				check(await until(func():return game.leader_brain.get("affinity_bleed",{}).has("%d/core"%source)),
					"stationary guest Thorn Line slows and wounds a real enemy on the host")
				mark("thorn-"+str(source))
				check(await until(func():return read("thorn-seen-"+str(source))=="ok"),"guest receives the authoritative field geometry")
			"wood":
				check(local.get("affinity_bark_grants",[]).any(func(grant):return grant.actor==source and grant.quality=="refined"),"Ironbark applies the refined guest grant on the host")
				if mixed_wood_ward:
					var grants: Array=local.get("affinity_bark_grants",[])
					check(grants.any(func(grant):return grant.actor==ward_guest and grant.quality=="ordinary") and grants.any(func(grant):return grant.actor==source and grant.admitted==36),
						"separate Wood sources coexist with a capped refined grant")
					var wounds: Dictionary=game.leader_brain.get("affinity_bleed",{})
					check(wounds.has("%d/core"%ids[0]) and wounds.has("%d/core"%ids[1]),"two real Thorn sources remain independent")
				mark("bark-"+str(source))
				check(await until(func():return read("bark-seen-"+str(source))=="ok"),"guest receives Bark presentation through authoritative details")
			"vital":
				var bonus: int=preload("res://affinity_build.gd").slot("core",visitor.weapon).potency_profile.values.bonus_hp
				check(local.max_hp==native_max+bonus and local.get("affinity_vital_sources",{}).has("%d/core"%source),
					"guest Vital Bloom applies its quality to host")
				mark("vital-"+str(source),str(visitor.max_hp))
				check(await until(func():return read("vital-seen-"+str(source))=="ok"),"Vital capacity reaches guest through authoritative vitals")
	if party:
		if measure_packets: await sample_host_snapshots(game,ids)
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
	var stats: Dictionary=game.weapon_stats(local)
	stats.damage=10000
	for index in game.scouts.size():
		if game.scouts[index].hp>0:
			game.apply_weapon_hit(local,index,game.scouts[index].pos,stats,Time.get_ticks_msec())
	game.enemy_hp=3
	game.enemy_pos=target
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
		check(game.enemy_hp==0,"the maintained Thorn wound kills without an extra attack")
	check(not game.wild_item_drops.is_empty(),"actual enemy drops through native settlement")
	local.pos=game.battlefield.advance
	ally.pos=local.pos
	game.use_checkpoint(1,true)
	mark("advance",str(game.travel_epoch))
	if not check(await until(func():return game.depth==2 and read("guest-floor")=="ok"),"party advances to next generated floor"):return
	game.encounter_number=6
	game.deepest_milestone=6
	game.enemy_hp=0
	game.scouts.clear()
	game.encounter_rewarded=true
	local.pos=game.battlefield.advance
	ally.pos=local.pos
	game.use_checkpoint(1,false)
	mark("extract",str(game.travel_epoch))
	if not check(await until(func():return not game.expedition_active() and read("guest-garden")=="ok"),"party extraction restores Garden"):return
	check([game.progress.part_count(ordinary),game.progress.part_count(refined)]==paid,"no repeated affinity material consumption")
	if not check(await until(func():return guests(game).is_empty() and game.pending_departures.is_empty()),"guest detached through normal teardown"):return
	mark("detached")
	check(await until(func():return read("rejoined")=="ok" and guests(game).size()==1),"guest reconnects to the existing Garden")
	check([game.progress.part_count(ordinary),game.progress.part_count(refined)]==paid,"reconnect does not repeat departure")
	for part in supplied:
		check(game.progress.part_count(part)==supplied[part]-1,"rejoin preserves each additional Core debit")
	check(not local.has("affinity_vital_sources") and not local.has("affinity_bark_grants"),"Garden return discards temporary health and armor")
	mark("saved")
	game.return_to_main_menu()
	check(await until(func():return tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"host goes offline after rejoin")
	mark("offline")


func guest(menu: Node, role: String) -> void:
	menu.request_create_character()
	menu.create_character("Frost guest "+role,0,Appearance.DEFAULT)
	if not check(await until(func():return read("host")=="ok"),"host ready"):return
	begin_join(menu)
	if not check(await until(func():return tree.current_scene.get("session")=="Guest" and tree.current_scene.stage.experimental_garden.remote_revision>=0),"actual title joins isolated frost Garden"):return
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
	if not check(await until(func():return not read("depart").is_empty()),"host authorizes departure"):return
	game.send_garden_action("travel_ready:"+read("depart"))
	if not check(await until(func():return read("strike-"+str(id))=="ok" and game.stage._has_experimental_floor()),"guest sees generated Frost floor"):return
	game.send_action(true)
	if int(picks[2])>0:
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
	if party:
		if measure_packets: await sample_guest_snapshots(game,id)
		if check(await until(func():return read("party-done")=="ok",22000),"host observes mixed-source party"):
			mark("done-"+str(id))
			check(await until(func():return read("offline")=="ok" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"guest observes party shutdown")
		return
	if not check(await until(func():return not read("advance").is_empty() and game.enemy_hp==0 and int(game.party_travel_state().get("epoch",-1))==int(read("advance"))),"guest sees cleared Gate"):return
	game.send_travel_ready(false)
	if not check(await until(func():return game.depth==2 and game.stage.visual_field.configured_key.z==game.map_seed),"guest tracks next floor"):return
	mark("guest-floor")
	if not check(await until(func():return not read("extract").is_empty() and int(game.party_travel_state().get("epoch",-1))==int(read("extract"))),"guest receives extraction"):return
	game.send_travel_ready(false)
	if not check(await until(func():return not game.players[id].wild),"guest returns to Garden"):return
	check(str(terrain.state.outline).sha256_text()==garden_outline,"same Garden outline after Frost play")
	mark("guest-garden")
	game.return_to_main_menu()
	if not check(await until(func():return read("detached")=="ok" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"normal offline-before-rejoin transition"):return
	begin_join(tree.current_scene)
	if not check(await until(func():return tree.current_scene.get("session")=="Guest" and tree.current_scene.stage.experimental_garden.remote_revision>=0),"same isolated profile rejoins"):return
	check(tree.current_scene.guest_character.identity==identity,"stable character identity across rejoin")
	mark("rejoined")
	check(await until(func():return read("saved")=="ok"),"host verifies no replay or debit")
	check(await until(func():return read("offline")=="ok" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"guest observes host shutdown")


func sample_host_snapshots(game: Node, ids: Array) -> void:
	# Offer an unmistakable authoritative state marker on the normal
	# unreliable channel. Pin it briefly so every real receiver can witness it.
	game.enemy_hp=487
	game.enemy_stagger_until=Time.get_ticks_msec()+9000
	mark("snapshot-probe",str(game.net_view.snapshot_sent))
	var max_people := 0
	var max_scouts := 0
	var micros := 0
	var samples := 0
	for step in 12:
		var now := Time.get_ticks_msec()
		for id in ids:
			var began := Time.get_ticks_usec()
			var people := var_to_bytes(game.player_snapshot(id,false)).compress(FileAccess.COMPRESSION_DEFLATE)
			var scouts: PackedByteArray = game.scout_snapshot(now).to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE)
			micros += Time.get_ticks_usec()-began
			max_people=maxi(max_people,people.size())
			max_scouts=maxi(max_scouts,scouts.size())
			samples+=1
		await tree.create_timer(.075).timeout
	check(await until(func():return ids.all(func(id):return read("snapshot-seen-"+str(id))=="ok"),4000),"all three receivers see the authoritative snapshot marker and floor")
	print("SNAPSHOT_HOST samples=",samples," people_peak=",max_people," scout_peak=",max_scouts," encode_us=",float(micros)/samples)


func sample_guest_snapshots(game: Node, id: int) -> void:
	if not check(await until(func():return not read("snapshot-probe").is_empty()),"host sends snapshot probe"):
		return
	var baseline := int(read("snapshot-probe"))
	var gaps: int = game.net_view.snapshot_gaps
	var first_seen := Time.get_ticks_msec()
	var arrived := await until(func():
		return game.net_view.snapshot_received>baseline and game.enemy_hp>400 and game.enemy_hp<=487 and game.players.size()==4 and game.stage._has_experimental_floor(),3500)
	check(arrived,"channel 4 delivers authoritative enemy HP, roster and floor")
	var delay := Time.get_ticks_msec()-first_seen
	var first: int=game.net_view.snapshot_received
	await tree.create_timer(.35).timeout
	check(game.net_view.snapshot_received>first,"snapshot sequence keeps advancing")
	print("SNAPSHOT_GUEST first_after=",first-baseline," observed_ms=",delay," more=",game.net_view.snapshot_received-first,
		" gaps=",game.net_view.snapshot_gaps-gaps)
	if arrived: mark("snapshot-seen-"+str(id))
