extends RefCounted
## Independent processes with distinct guarded save roots and actual ENet RPCs.
const Mode = preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Session = preload("res://tests/support/session_case.gd")
const Appearance = preload("res://character_appearance.gd")
const Identity = preload("res://network_action_identity.gd")
const Build = preload("res://affinity_build.gd")

var tree: SceneTree
var signals: String
var port: int
var role: String
var party: bool
var failed := false

func check(ok: bool, label: String) -> bool:
	if not ok:
		failed = true
		printerr("FAIL wild flora ",role,": ",label)
	return ok

func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+32000
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await tree.process_frame
	return check(predicate.call(),label)

func mark(key: String, value := "yes") -> void:
	var file := FileAccess.open(signals.path_join(key),FileAccess.WRITE)
	if check(file!=null,"write signal "+key): file.store_string(value)

func read(key: String) -> String:
	var path := signals.path_join(key)
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func joined(game: Node) -> bool:
	return Session.role(game)=="Guest" and game.guest_replication.has_details()

func join(menu: Node) -> void:
	menu.show_page(2)
	menu.join_button.pressed.emit()
	menu.network_dialog.address_field.text="127.0.0.1:"+str(port)
	menu.network_dialog.submit.pressed.emit()

func run(scene_tree: SceneTree, four_players: bool) -> bool:
	tree=scene_tree
	party=four_players
	role=OS.get_cmdline_user_args()[0]
	signals=OS.get_environment("MYSTICAL_TERRAIN_TEST_SIGNALS")
	port=int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT"))
	if not check(Mode.verified() and not signals.is_empty(),"verified isolated profile before opening title"): return false
	var menu: Node = preload("res://main_menu.tscn").instantiate()
	tree.root.add_child(menu)
	tree.current_scene=menu
	if role=="host": await host(menu)
	elif role=="overflow": await overflow(menu)
	else: await guest(menu)
	return not failed

func overflow(menu: Node) -> void:
	# Construction and altar checks run before the host admits the overflow probe.
	if not await until(func():return read("altar")=="yes","four-player Garden reached altar checks"): return
	if not await until(func():return read("full")=="yes","four players connected"): return
	menu.request_create_character()
	menu.create_character("Flora overflow",0,Appearance.DEFAULT)
	var old_menu:=menu.get_instance_id()
	join(menu)
	if await until(func():return tree.current_scene.get_instance_id()!=old_menu and tree.current_scene.get("return_message") is String,"fifth peer refused at title"):
		mark("refused")

func submit_altar(game: Node) -> void:
	game.send_altar_action("identify_all",[],1)
	var four_identified := func():
		if game.multiplayer.is_server(): return game.seed_reserve(game.players[1]).stock[3] == 4
		var inventory: Array = game.guest_replication.inventory()
		return inventory.size() > 6 and inventory[6][3] == 4
	if not await until(four_identified, "fixed boss stock identified before breeding"): return
	var pair: Array=[{"source":"stash","item":"seed_ember_fern"},{"source":"stash","item":"seed_ember_fern"}]
	game.send_altar_action("combine",pair,2)
	game.send_altar_action("combine",pair,2)

func host(menu: Node) -> void:
	menu.host_port=port
	menu.host_choice.button_pressed=true
	menu.new_game()
	menu.create_character("Flora host",0,Appearance.DEFAULT)
	if not await until(func():return Session.role(tree.current_scene)=="Host","guarded host started"): return
	var game:=tree.current_scene
	mark("host")
	var expected:=4 if party else 2
	if not await until(func():return game.players.size()==expected and game.players.values().all(func(actor):return Session.ready(actor)),"party registration"): return
	var peers: Array=game.players.keys()
	peers.erase(1)
	# Check the same Garden research and contribution on every registered peer
	# before using that Garden for the botanical expedition and rejoin checks.
	game.players[1].pos = game.Stage.HEART
	var garden = game.stage.experimental_garden
	var item: String = game.Items.part_id(game.Parts.THORN)
	game.progress.add_parts(game.Parts.THORN, 5)
	garden._refresh_parts()
	var quote: Dictionary = garden.funds.quote({item: 4})
	if not check(garden.contribute(quote) and not garden.contribute(quote), "four contributed parts consumed once"): return
	game.garden_action(1,"heart_start_cultivation_grounds")
	game.garden_action(1,"heart_start_cultivation_grounds")
	if not check(game.progress.knowledge == 4 and game.progress.heart.spent == 4 and garden.funds.energy == 8, "one host purchase and contribution"): return
	if not await until(func(): return peers.all(func(peer): return read("heart-"+str(peer))=="yes"), "every guest sees both currencies and unlock"): return
	# Keep waiting guests at the reserved gate approach while the host builds.
	for peer in peers: game.players[peer].pos=game.stage.gate_position()
	# Use the same real Garden with more than nine beds before travelling.
	game.players[1].pos=Vector3(0,0,1.5)
	game.run_heart_save(func():
		game.progress.knowledge+=200
		game.progress.add_parts(game.Parts.THORN,200)
		return "")
	garden._refresh_parts()
	if not check(garden.contribute(garden.funds.quote({item:150})), "fund additional construction"): return
	game.garden_action(1,"heart_start_clearing_1")
	game.garden_action(1,"heart_start_irrigation")
	var placement = preload("res://tests/support/garden_placement_case.gd")
	if not check(placement.deploy_irrigation(garden,"intake",garden.planar(preload("res://garden_water.gd").anchor(game.stage)))>0,"deploy shoreline intake: "+game.status): return
	if not check(preload("res://tests/support/garden_placement_case.gd").develop(garden,10), "host develops ten placed beds"): return
	var tenth: int = garden.bed_ids[9]
	var site := preload("res://tests/support/garden_placement_case.gd").find(garden.construction,"bed",garden.construction.records[tenth].at,0.2,Vector2(0,1.5),tenth)
	if not check(garden.place("bed",site,0.2,tenth) and garden.construct("bed",game.progress.structures.revision),"relocate tenth and buy one stored bed"): return
	for tech in ["sprinkler_effectiveness","pollination_bloom","pollination_bloom_effectiveness","nursery","bud_sanctuary","bud_sanctuary_effectiveness"]: game.garden_action(1,"heart_start_"+tech)
	var sprinkler: int=placement.deploy_irrigation(garden,"sprinkler",site)
	if not check(sprinkler>0 and game.progress.irrigation.watered_slots.has(9),"host waters relocated tenth bed"): return
	if not check(placement.deploy_irrigation(garden,"pollination_bloom",site)>0,"host deploys pollinator"): return
	var sanctuary: int = placement.deploy_irrigation(garden,"bud_sanctuary",site)
	if not check(sanctuary>0 and garden.configure_sanctuary(sanctuary,"enhanced",game.progress.structures.revision),"host selects enhanced care"): return
	game.players[1].pos = game.stage.bed_position(9)
	game.players[1].seed_choice = 0
	game.seed_reserve(game.players[1]).stock[0] += 1
	if not check(game.cultivation.plant_seed(1,9),"plant a real crop in the tenth bed"): return
	mark("root-shape",var_to_bytes(garden.infrastructure.paths).hex_encode().sha256_text())
	mark("bed-position",var_to_str(site))
	mark("built",str(garden.funds.energy))
	if not await until(func():return peers.all(func(peer):return read("built-"+str(peer))=="yes"),"all guests see placed and stored beds"): return
	game.players[1].pos=Vector3(0,0,1.5)
	var original: Vector2=garden.construction.records[sprinkler].at
	var distant := Vector2.INF
	for x in range(-20,21):
		for y in range(-20,21):
			var candidate := Vector2(x,y)*0.5
			if candidate.distance_to(site)>garden.game.progress.irrigation.RADIUS_M and garden._build_refusal("sprinkler",candidate,0,sprinkler).is_empty():
				distant=candidate
				break
		if distant.is_finite(): break
	if not check(distant.is_finite() and garden.place("sprinkler",distant,0,sprinkler),"move sprinkler to an accessible uncovered site clear of every peer: "+game.status): return
	mark("sprinkler-moved",var_to_str(distant))
	if not await until(func():return peers.all(func(peer):return read("dry-"+str(peer))=="yes"),"each guest observes loss of coverage"): return
	if not check(garden.place("sprinkler",original,0,sprinkler) and game.progress.irrigation.watered_slots.has(9),"restore the same sprinkler"): return
	# Each participant identifies concealed boss stock and combines at the shared altar.
	for index in game.players.size():
		var actor: Dictionary=game.players[game.players.keys()[index]]
		var angle: float = TAU * index / game.players.size()
		actor.pos=game.stage.altar_position() + Vector3(cos(angle), 0.0, sin(angle)) * 0.9
		game.InventoryModel.put(game,actor,"stash",{"item":"boss_mystery_seed","quantity":4,"lineages":{"ember_fern":4}})
	mark("altar")
	await submit_altar(game)
	if not await until(func():return game.players.values().all(func(actor):return game.seed_reserve(actor).stock[16]==1),"all altar combinations committed once"): return
	for actor in game.players.values():
		check(game.seed_reserve(actor).stock[3]==2 and game.Altar.ancient_count(game,actor)==0,"private fixed contents and one consumption per peer")
	if not await until(func():return peers.all(func(peer):return read("altar-"+str(peer))=="yes"),"private results and shared recipe replicated"): return
	game.players[1].pos=game.Stage.HEART
	for tech in ["careful_gathering","wild_harvest","refined_gathering","botanical_awareness","root_resonance","checkpoint_deposit","deep_root_network","reaching_tendrils"]:
		game.garden_action(1,"heart_start_"+tech)
		check(game.progress.heart.has(tech),"host purchased shared "+tech)
	for peer in game.players: game.players[peer].pos=game.stage.gate_position()
	game.garden_action(1,"learn_0_66")
	mark("gate")
	if not await until(func():return game.players.values().all(func(actor):return Build.departure_refusal(actor).is_empty()),"all players chose a working starting focus"): return
	if party: mark("full")
	# Pick an ordinary first floor that passes the real independent generation roll.
	var probe:=RandomNumberGenerator.new()
	for seed_value in range(16,128):
		probe.seed=seed_value
		var key:=Vector3i(game.participation.route(),1,probe.randi_range(1,2147483647))
		if game.battlefield.root_random(key,1).randf()<0.40:
			game.map_rng.seed=seed_value
			break
	game.PartyTravel.request(game,1,"depart")
	mark("depart",str(game.participation.travel_epoch()))
	if not await until(func():return game.participation.participants().size()==expected,"party departed through actual gate"): return
	var plant: Dictionary=game.wild_flora_view(1)
	if not check(not plant.is_empty() and not game.encounter_cleared(),"guaranteed specimen accessible during combat"): return
	game.tactics.stagger_until=Time.get_ticks_msec()+90000
	game.encounter.clear_scouts()
	mark("species",str(plant.species))
	mark("first",plant.identity)
	if not await until(func():return peers.all(func(peer):return read("distant-"+str(peer))=="yes"),"guests tried out-of-range and malformed requests"): return
	await tree.create_timer(0.5).timeout
	var seed_item: String=game.Items.seed_id(plant.species)
	check(game.players.values().all(func(actor):return not actor.carried_items.has(seed_item) and actor.carried_seeds.is_empty()),"distant or invalid requests awarded no seeds")
	game.players[1].pos=plant.position
	game.send_action(false)
	check(game.wild_flora_view(1).claimed and game.players[1].carried_items.get(seed_item,0)>=1,"host interaction harvested exact shared species")
	for peer in peers:
		check(not game.wild_flora_view(peer).claimed,"host harvesting left guest claim available")
		game.players[peer].pos=plant.position
	mark("claim")
	if not await until(func():return peers.all(func(peer):return read("claimed-"+str(peer))=="yes"),"guests received private claimed projections"): return
	var carried_after: Dictionary={}
	for peer: int in game.players:
		var actor: Dictionary=game.players[peer]
		var returning: Dictionary=game.ReturningRoot.view(game,peer,actor)
		if not check(not returning.is_empty() and returning.remaining==2,"one generated root with two allowances per explorer"): return
		var character: String=game._kill_reward_identity(peer,actor)
		var quantity:=1+int(game.WildFlora.bonus_roll(plant.identity,character,"seed")<0.25)
		check(actor.carried_seeds.is_empty() and actor.carried_items.get(seed_item,0)==quantity and actor.carried_parts[game.Seeds.DEFINITIONS[plant.species].part]==1,"authoritative personal bundle")
		actor.pos=returning.position
		carried_after[peer]=quantity-1
	mark("root-deposit")
	await deposit_pair(game,1,plant)
	if not await until(func():return peers.all(func(peer):return read("secured-"+str(peer))=="yes"),"every client used both personal deposits"): return
	for peer: int in game.players:
		var actor: Dictionary=game.players[peer]
		check(game.seed_reserve(actor).stock[plant.species]==1 and game.seed_reserve(actor).unknown.is_empty() and actor.carried_items.get(seed_item,0)==carried_after[peer] and actor.carried_parts[game.Seeds.DEFINITIONS[plant.species].part]==0,"one seed and one plant part secured per character")
	if party and not await until(func():return read("refused")=="yes","fifth client refused"): return
	if not check(game.participation.advance(game.participation.epoch(),6),"advance authoritative floor"): return
	game.start_encounter()
	game.tactics.stagger_until=Time.get_ticks_msec()+90000
	game.encounter.clear_scouts()
	var next: Dictionary=game.wild_flora_view(1)
	if not check(not next.is_empty() and next.identity!=plant.identity,"new floor has independent introductory specimen"): return
	for peer in peers: game.players[peer].pos=next.position
	mark("next",next.identity)
	if not await until(func():return peers.all(func(peer):return read("stale-"+str(peer))=="yes"),"all guests tried previous-floor requests"): return
	await tree.create_timer(0.5).timeout
	for peer in peers: check(not game.wild_flora_view(peer).claimed and game.players[peer].carried_items.get(seed_item,0)==carried_after[peer],"old identity and old action stamp rejected")
	# Set up an acquired upgrade through the ordinary card ledger and a known
	# carried item so the restored build and cargo comparisons cannot pass empty.
	for peer in peers:
		var actor: Dictionary = game.players[peer]
		game.checkpoint_card_data(actor)
		var ledger = game.AffinityCards.ledger(actor)
		var plan: Dictionary = ledger.plan_choice(game.participation.floor(),int(ledger.offer().revision),"0",999,
			int(actor.upgrade_seed),0,game.combat_build(actor).weapon_base_stats(),game.DODGE_COOLDOWN_MS)
		if not check(plan.has("copy"),"acquired a real upgrade for rejoin"): return
		actor[game.AffinityCards.STATE] = plan.ledger
		actor.carried_items[seed_item] = 3
	mark("verified")
	if not party:
		if not await until(func():return game.players.size()==1,"guest detached during expedition"): return
		var absent_id: String = game.parked_explorers.keys()[0]
		var held: Dictionary = game.parked_explorers[absent_id]
		var held_loot: Dictionary = held.actor.carried_items.duplicate(true)
		var graft_id: int = held.actor.expedition_grafts.identity()
		var copies: Array = held.actor[game.AffinityCards.STATE].copies()
		var edited: Dictionary = held.actor.character.duplicate(true)
		edited.xp[0] += 30
		if not check(not game.Continuation.profile_matches(held.actor,edited,game.progress.character_records[absent_id],{}),"divergent character progress stays protected"): return
		if not check(not game.Continuation.authorized(game,absent_id,"a".repeat(64)),"a character id alone cannot claim the reserved seat"): return
		if not check(game.participation.advance(game.participation.epoch(),6),"host advances while guest is absent"): return
		game.start_encounter()
		game.tactics.stagger_until=game.CombatClock.now()+90000
		game.encounter.set_hp(-1,2)
		game.save_and_quit(false)
		var title := tree.current_scene
		if not check(title!=game and title.continue_button.text=="Continue Expedition","co-op host suspended the current floor"): return
		await tree.process_frame
		title.continue_button.pressed.emit()
		game=tree.current_scene
		if not check(game!=title and game.network_session.role()=="Host" and game.encounter.hp(-1)==2,"host restored the fight and reopened the session"): return
		mark("detached",str(game.participation.floor()))
		if not await until(func():return read("back-in-wilds")=="yes","guest returned to current floor"): return
		var restored: Dictionary = {}
		for member in game.players.values():
			if Session.identity(member)==absent_id: restored=member
		if not check(not restored.is_empty() and restored.carried_items==held_loot and game.AffinityCards.ledger(restored).copies()==copies and restored.expedition_grafts.identity()==graft_id and game.participation.participants().size()==2,"guest retained exact loot, build and a single seat"): return
	else:
		if not await until(func():return peers.all(func(peer):return read("await-host-"+str(peer))=="yes"),"all three guests are still online"): return
		var cargo := {}
		for peer in peers:
			var actor: Dictionary = game.players[peer]
			cargo[Session.identity(actor)] = [actor.carried_items.duplicate(true),game.AffinityCards.ledger(actor).copies(),actor.expedition_grafts.identity()]
		game.encounter.set_hp(-1,2)
		game.save_and_quit(false)
		var title := tree.current_scene
		if not check(title!=game and title.continue_button.text=="Continue Expedition","host saved all connected participants"): return
		await tree.process_frame
		title.continue_button.pressed.emit()
		game=tree.current_scene
		if not check(game!=title and game.parked_explorers.size()==3 and game.encounter.hp(-1)==2,"three reserved seats and same wounded enemy"): return
		mark("host-restored",str(game.participation.floor()))
		if not await until(func():return peers.all(func(peer):return read("rejoined-wild-"+str(peer))=="yes"),"three guests rejoin the restored fight"): return
		if not check(game.parked_explorers.is_empty() and game.participation.participants().size()==4,"all four participants restored exactly once"): return
		for actor: Dictionary in game.players.values():
			var identity := Session.identity(actor)
			if cargo.has(identity):
				if not check(cargo[identity]==[actor.carried_items,game.AffinityCards.ledger(actor).copies(),actor.expedition_grafts.identity()],"correct build and loot per rejoined guest"): return
	check(game.expedition_transitions.finish_failed(),"wipe finishes through settlement")
	mark("garden")
	if not await until(func():return read("rejoined")=="yes" if not party else peers.all(func(peer):return read("garden-"+str(peer))=="yes"),"Garden state recovered"): return
	if not party:
		check(game.players.size()==2,"same character rejoined once")
		for actor: Dictionary in game.players.values():
			check(game.seed_reserve(actor).stock[plant.species]==1 and game.seed_reserve(actor).unknown.is_empty() and game.seed_reserve(actor).parts[game.Seeds.DEFINITIONS[plant.species].part]>=1,"deposits survive disconnect, wipe and Garden rejoin")
		for peer in game.players: check(game.wild_flora_view(peer).is_empty(),"no collectible survives expedition cleanup")
	game.return_to_main_menu()
	if await until(func():return tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"host shut down"): mark("offline")

func guest(menu: Node) -> void:
	menu.request_create_character()
	menu.create_character("Flora guest "+role,0,Appearance.DEFAULT)
	if not await until(func():return read("host")=="yes","host started"): return
	join(menu)
	if not await until(func():return joined(tree.current_scene),"registered guest"): return
	var game:=tree.current_scene
	var peer: int=game.local_player_id()
	var character: String=game.guest_character.identity
	if not await until(func(): return game.heart_state().unlocked.has("cultivation_grounds") and game.stage.experimental_garden.remote_development.get("energy")==8, "Garden purchase and contribution replicated"): return
	check(game.heart_state().insight==0 and game.guest_replication.garden_progress()[6]==4, "host Knowledge balances agree")
	mark("heart-"+str(peer))
	var garden = game.stage.experimental_garden
	if not await until(func():return not read("built").is_empty() and garden.bed_ids.size()==10 and garden.remote_development.energy==int(read("built")) and game.guest_replication.garden_progress()[12].size()>=30 and game.Progress.decode_plots(game.guest_replication.garden_progress()[12])[9].species==0, "ten beds and current Energy replicated"): return
	var inventory: Dictionary=garden.remote_development.layout.inventory
	check(inventory.instances.values().filter(func(e): return not e.placed and e.kind=="bed").size()==1 and game.Progress.decode_plots(game.guest_replication.garden_progress()[12]).size()==10 and garden.construction.records[garden.bed_ids[9]].at.is_equal_approx(str_to_var(read("bed-position"))),"read-only inventory, extended crops and exact moved position")
	check(not garden.construct("bed",inventory.revision) and not garden.retire_structure(garden.bed_ids[9],inventory.revision,true),"guest cannot buy or refund")
	if not await until(func(): return game.cultivation.projection(peer).get("beds",[]).any(func(b):return b.slot==9 and b.sprinkler and not b.watered and is_equal_approx(b.growth_rate,1.40) and b.seeds==4), "host watering result received for the newly planted tenth bed"): return
	check(garden.remote_irrigation.watered_slots.has(9) and garden.infrastructure.paths.size()==garden.construction.records.size(),"host and guest reproduce the infrastructure")
	check(var_to_bytes(garden.infrastructure.paths).hex_encode().sha256_text()==read("root-shape"),"guest derived identical root paths")
	mark("built-"+str(peer))
	if not await until(func():return not read("sprinkler-moved").is_empty() and not garden.remote_irrigation.watered_slots.has(9) and game.cultivation.projection(peer).get("beds",[]).any(func(b):return b.slot==9 and not b.sprinkler and is_equal_approx(b.growth_rate,1.0)), "relocated sprinkler and dry crop agree on guest"): return
	mark("dry-"+str(peer))
	if not await until(func():return read("altar")=="yes" and game.players[peer].pos.distance_to(game.stage.altar_position())<1.65,"guest reached altar"): return
	await submit_altar(game)
	if not await until(func():return game.guest_replication.inventory().size()>6 and game.guest_replication.inventory()[6][16]==1 and game.players[peer].get("recorded_seed_recipes",[]).has(16),"identified stock and tested recipe arrive"): return
	mark("altar-"+str(peer))
	if not await until(func():return read("gate")=="yes","host positioned guest"): return
	game.send_garden_action("learn_0_66")
	if not await until(func():return not read("depart").is_empty(),"departure vote opened"): return
	game.send_garden_action("travel_ready:"+read("depart"))
	if not await until(func():return not read("first").is_empty() and game.wild_flora_view(peer).get("identity","")==read("first"),"reliable specimen projection"): return
	var plant: Dictionary=game.wild_flora_view(peer)
	var stamp:=Identity.current_stamp(game,game.players[peer])
	check(not stamp.is_empty() and not plant.claimed,"current binding, life and unclaimed view")
	check(str(plant.species)==read("species"),"every recipient sees the same actual species")
	game.send_wild_flora_harvest(plant.identity)
	game.request_wild_flora.rpc_id(1,plant.identity,"invalid")
	mark("distant-"+str(peer))
	if not await until(func():return read("claim")=="yes" and game.players[peer].pos.distance_to(plant.position)<0.6,"guest in interaction range"): return
	check(not game.wild_flora_view(peer).claimed,"host's claim is private")
	game.send_action(false)
	if not await until(func():return game.wild_flora_view(peer).get("claimed",false) and game.guest_replication.carried_count()>=1,"normal guest interaction acquires one seed"): return
	game.send_wild_flora_harvest(plant.identity)
	mark("claimed-"+str(peer))
	if not await until(func():return read("root-deposit")=="yes" and game.can_use_returning_root(game.players[peer]),"within reach of authoritative root"): return
	await deposit_pair(game,peer,plant)
	if failed: return
	mark("secured-"+str(peer))
	if not await until(func():return not read("next").is_empty() and game.wild_flora_view(peer).get("identity","")==read("next"),"next floor replaces old projection"): return
	game.request_wild_flora.rpc_id(1,read("next"),stamp)
	game.send_wild_flora_harvest(plant.identity)
	mark("stale-"+str(peer))
	if not await until(func():return read("verified")=="yes","host verifies stale rejections"): return
	if not party:
		game.save_and_quit(false)
		if not await until(func():return not read("detached").is_empty() and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"saved guest can rejoin"): return
		join(tree.current_scene)
		if not await until(func():return joined(tree.current_scene),"same profile reconnects during the fight"): return
		game=tree.current_scene
		if not await until(func():return game.participation.floor()==int(read("detached")) and game.participation.contains(game.local_player_id()),"joined the party's later floor"): return
		check(game.guest_character.identity==character,"same persistent character")
		mark("back-in-wilds")
	else:
		mark("await-host-"+str(peer))
		if not await until(func():return not read("host-restored").is_empty() and tree.current_scene.has_method("continue_game"),"host closure returns the guest to title"): return
		join(tree.current_scene)
		if not await until(func():return joined(tree.current_scene),"connected guest can rejoin after host suspension"): return
		game=tree.current_scene
		if not await until(func():return game.participation.floor()==int(read("host-restored")) and game.participation.contains(game.local_player_id()),"rejoined the original party"): return
		if not check(game.guest_character.identity==character,"rejoined the original character"): return
		mark("rejoined-wild-"+str(peer))
	if not await until(func():return read("garden")=="yes","host returned to Garden"): return
	if not party:
		game.request_wild_flora.rpc_id(1,plant.identity,stamp)
		if not await until(func(): return game.heart_state().unlocked.has("cultivation_grounds") and game.stage.experimental_garden.remote_development.get("energy")==int(read("built")) and game.stage.experimental_garden.bed_ids.size()==10, "rejoined client receives committed Heart and Energy"): return
		if not await until(func(): return game.stage.experimental_garden.remote_irrigation.watered_slots.has(9) and game.cultivation.projection(game.local_player_id()).get("beds",[]).any(func(b):return b.slot==9 and b.sprinkler),"rejoined guest recovers authoritative watering"): return
		mark("rejoined")
	else:
		if not await until(func():return game.wild_flora_view(game.local_player_id()).is_empty() and game.participation.floor()==1,"discard old flora after wipe"): return
		mark("garden-"+str(peer))
	await until(func():return read("offline")=="yes" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest observed normal teardown")

func deposit_pair(game: Node, peer: int, plant: Dictionary) -> void:
	var actor: Dictionary=game.players[peer]
	var part: String=game.Items.part_id(game.Seeds.DEFINITIONS[plant.species].part)
	var stamp:=Identity.current_stamp(game,actor)
	var unit:=0
	for item: String in [game.Items.seed_id(plant.species),part]:
		var returning: Dictionary=game.ReturningRoot.view(game,peer,game.players[peer])
		var command: String=game.ReturningRoot.request(returning,stamp,item)
		if item == part: game.send_garden_action(game.ReturningRoot.request(returning,stamp,game.Items.Ancient.ITEM))
		game.send_action(false)
		var picker: OptionButton=game.ui.get_node("%DepositPick")
		var option: int=-1
		for i in picker.item_count:
			if picker.get_item_metadata(i)==command: option=i
		if not check(game.ui.panel_is_open("deposit") and option>=0,"interact opens reviewed choice with live allowance"): return
		picker.select(option)
		game.ui.get_node("%DepositButton").pressed.emit()
		game.send_garden_action(command)
		unit+=1
		if not await until(func():return game.ReturningRoot.view(game,peer,game.players[peer]).get("used",0)==unit,"receipt for exactly one reviewed unit"): return
	check(not game.can_use_returning_root(game.players[peer]),"personal capacity exhausted")
