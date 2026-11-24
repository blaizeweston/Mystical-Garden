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
	if not await until(func():return read("full")=="yes","four players connected"): return
	menu.request_create_character()
	menu.create_character("Flora overflow",0,Appearance.DEFAULT)
	var old_menu:=menu.get_instance_id()
	join(menu)
	if await until(func():return tree.current_scene.get_instance_id()!=old_menu and tree.current_scene.get("return_message") is String,"fifth peer refused at title"):
		mark("refused")

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
	for peer in game.players: game.players[peer].pos=game.stage.gate_position()
	game.garden_action(1,"learn_0_66")
	mark("gate")
	if not await until(func():return game.players.values().all(func(actor):return Build.departure_refusal(actor).is_empty()),"all players chose a working starting focus"): return
	if party: mark("full")
	game.map_rng.seed=16
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
	check(game.players.values().all(func(actor):return actor.carried_seeds.is_empty()),"distant or invalid requests awarded no seeds")
	game.players[1].pos=plant.position
	game.send_action(false)
	check(game.wild_flora_view(1).claimed and game.players[1].carried_seeds==[plant.species],"host interaction harvested exact shared species")
	for peer in peers:
		check(not game.wild_flora_view(peer).claimed,"host harvesting left guest claim available")
		game.players[peer].pos=plant.position
	mark("claim")
	if not await until(func():return peers.all(func(peer):return read("claimed-"+str(peer))=="yes"),"guests received private claimed projections"): return
	for peer in peers:
		check(game.players[peer].carried_seeds==[plant.species],"exactly one seed with immutable species for "+str(peer))
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
	for peer in peers: check(not game.wild_flora_view(peer).claimed and game.players[peer].carried_seeds==[plant.species],"old identity and old action stamp rejected")
	mark("verified")
	if not party:
		if not await until(func():return game.players.size()==1,"guest detached during expedition"): return
		mark("detached")
		if not await until(func():return read("blocked")=="yes","active run bars old character readmission"): return
	check(game.expedition_transitions.finish_failed(),"wipe finishes through settlement")
	mark("garden")
	if not await until(func():return read("rejoined")=="yes" if not party else peers.all(func(peer):return read("garden-"+str(peer))=="yes"),"Garden state recovered"): return
	if not party:
		check(game.players.size()==2,"same character rejoined once")
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
	if not await until(func():return game.wild_flora_view(peer).get("claimed",false) and game.guest_replication.carried_count()==1,"normal guest interaction acquires one seed"): return
	game.send_wild_flora_harvest(plant.identity)
	mark("claimed-"+str(peer))
	if not await until(func():return not read("next").is_empty() and game.wild_flora_view(peer).get("identity","")==read("next"),"next floor replaces old projection"): return
	game.request_wild_flora.rpc_id(1,read("next"),stamp)
	game.send_wild_flora_harvest(plant.identity)
	mark("stale-"+str(peer))
	if not await until(func():return read("verified")=="yes","host verifies stale rejections"): return
	if not party:
		game.return_to_main_menu()
		if not await until(func():return read("detached")=="yes" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"returned to title during active run"): return
		var old_menu:=tree.current_scene.get_instance_id()
		join(tree.current_scene)
		if not await until(func():return tree.current_scene.get_instance_id()!=old_menu and tree.current_scene.get("return_message") is String,"old character rejected while floor is live"): return
		check("host is in the Wilds" in tree.current_scene.return_message,"specific active-expedition refusal")
		mark("blocked")
	if not await until(func():return read("garden")=="yes","host returned to Garden"): return
	if not party:
		join(tree.current_scene)
		if not await until(func():return joined(tree.current_scene),"same profile reconnects at Garden"): return
		game=tree.current_scene
		check(game.guest_character.identity==character and game.wild_flora_view(game.local_player_id()).is_empty(),"reconnected character does not recover stale flora")
		game.request_wild_flora.rpc_id(1,plant.identity,stamp)
		mark("rejoined")
	else:
		if not await until(func():return game.wild_flora_view(peer).is_empty() and game.participation.floor()==1,"discard old flora after wipe"): return
		mark("garden-"+str(peer))
	await until(func():return read("offline")=="yes" and tree.root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer,"guest observed normal teardown")
