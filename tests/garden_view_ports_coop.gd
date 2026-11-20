extends SceneTree
const Sessions=preload("res://tests/support/session_case.gd")
const Construction=preload("res://tests/support/garden_case.gd")
const Interactions=preload("res://garden_interaction_service.gd")
const Care=preload("res://garden_crop_state.gd")
const Gate=preload("res://persistence_writer_integration.gd")
var game:Node
var role:String
var base:String
var failed:=false

func _initialize():call_deferred("run")
func check(ok:bool,message:String)->bool:
	if not ok:failed=true;printerr("FAIL Garden view ports co-op ",role,": ",message)
	return ok
func mark(key:String):
	var file=FileAccess.open(base+"-"+key,FileAccess.WRITE);file.store_string("ok")
func marked(key:String)->bool:return FileAccess.file_exists(base+"-"+key)
func until(predicate:Callable)->bool:
	var deadline:=Time.get_ticks_msec()+18000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func check_read_models():
	var peer:int=game.local_player_id()
	var complete:Dictionary=Interactions.projection(game,peer)
	var observation:Dictionary=Interactions.observation_projection(game,peer)
	for field in observation:
		check(observation[field]==complete[field],"lightweight observation agrees with the published "+str(field))
	check(Interactions.projection_epoch(game,peer)==str(complete.get("epoch","")),"scalar context agrees with the published epoch")
	check(game.cultivation.water_carried(peer)==bool(game.cultivation.projection(peer).get("spring_water",false)),"scalar water status agrees with the complete crop projection")
	var expected_available:Array=complete.get("available",[]).duplicate()
	observation.available.clear()
	check(Interactions.projection(game,peer).get("available",[])==expected_available,"lightweight observation inspection is detached")
func run():
	role=OS.get_cmdline_user_args()[0];base="res://.godot/garden-view-ports-"+OS.get_cmdline_user_args()[1]
	# Existing fixture-only guarded title route, restricted to the verified
	# disposable root. Production activation remains false.
	check(not Gate.PRODUCTION_CUTOVER_APPROVED,"production writers remain disabled")
	set_meta(Gate.VALIDATION_ROUTE,true)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await scene_changed
	var menu:Node=current_scene
	menu.request_create_character();menu.creator.name_field.text="Garden ports "+role;menu.creator.confirmed.emit()
	if role=="host":
		menu.host_port=int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT"));menu.host_choice.button_pressed=true;menu.new_button.pressed.emit()
		game=current_scene
		if not check(game!=menu and game.network_session.role()=="Host" and game.persistence_session.owns_leases(),"title creates the owned host Garden"):quit(1);return
		mark("host_ready")
	else:
		if not check(await until(func():return marked("host_ready")),"host title completes"):quit(1);return
		game=await join_title(menu)
		if game==null:quit(1);return
	if role=="host":await host_run()
	else:await guest_run()
	if not is_instance_valid(game):quit(1);return
	var port:RefCounted=game.garden_presentation
	var prior:int=game.get_instance_id();game.return_to_main_menu()
	check(await until(func():return current_scene.get_instance_id()!=prior),"guarded return finishes before world removal")
	await process_frame
	check(port.frame("crop").is_empty(),"a retained presentation port rejects a removed world")
	if not failed:print("PASS: Garden view ports co-op ",role," real observation/crop/station requests, detached guest facts, physical construction, exactly-once spending and Garden rejoin")
	quit(1 if failed else 0)

func join_title(menu:Node)->Node:
	var prior:int=menu.get_instance_id()
	menu.join_button.pressed.emit()
	if not check(menu.network_dialog.visible,"title opens Join by IP"):return null
	menu.network_dialog.address_field.text="127.0.0.1:"+OS.get_environment("MYSTICAL_GARDEN_TEST_PORT")
	menu.network_dialog.submit.pressed.emit()
	if not check(await until(func():return current_scene.get_instance_id()!=prior and Sessions.role(current_scene)=="Guest" and current_scene.guest_replication.has_details()),"title admits guest and recovers owner details"):
		var notice=current_scene.get("notice")
		print("CASE_GARDEN_JOIN ",JSON.stringify({"role":Sessions.role(current_scene),"script":current_scene.get_script().resource_path,"notice":notice.text if notice is Label else "","return_message":str(current_scene.get("return_message"))}))
		return null
	return current_scene

func host_run():
	if not check(await until(func():return game.players.size()==2 and game.players.values().all(func(actor):return Sessions.Session.ready_for(actor))),"guest registers"):return
	var guest:int=game.players.keys().filter(func(peer):return peer!=1)[0]
	var garden=game.progress
	garden.heart.unlock_direct("clearing_1")
	check_read_models()
	var point:Dictionary=Interactions.Catalog.point("heart_root_scar")
	game.players[1].pos=point.position;game.players[guest].pos=point.position
	if not check(Interactions.allowed(game,point) and Interactions.nearest(game,game.players[guest],Interactions.projection(game,guest))==point.id,"researched root scar is reachable"):return
	var parts:Array=garden.parts.duplicate();var experience:Array=game.players[guest].character.xp.duplicate()
	game.act(guest,false);mark("observe_ready")
	if not check(await until(func():return marked("observed")),"guest records through the real panel"):return
	check(garden.garden_interactions.revision==1 and garden.garden_interactions.receipts.size()==1,"repeated UI click commits exactly one observation")
	check(garden.parts==parts and game.players[guest].character.xp==experience,"an observation supplies no items or Class XP")
	var disk=game.Progress.new();disk.path=game.progress.path
	check(disk.load_garden()==OK and disk.garden_interactions.revision==1,"committed observation is saved only in the disposable world")
	game.players[1].pos=game.stage.bed_position(0);game.players[guest].pos=game.stage.bed_position(0)
	game.seed_reserve(game.players[1]).stock[0]+=1;game.players[1].seed_choice=0;game.cultivation.plant_seed(1,0);garden.advance_growth(168.75)
	if not check(int(garden.plots[0].stage)==2 and game.cultivation.focus(guest,0),"a real planted crop is ready for inspection"):return
	var crop_revision:int=garden.plots[0].care.revision
	mark("crop_ready")
	if not check(await until(func():return marked("preserved")),"guest preserves through the crop panel"):return
	check(Care.preserved(garden.plots[0]) and garden.plots[0].care.revision==crop_revision+1,"one pending UI choice produces one crop revision")
	check(garden.parts==parts and game.players[guest].character.xp==experience,"crop care supplies no hidden items or XP")
	# A real guest-owned harvest uses the new port and existing profile transaction.
	var actor:Dictionary=game.players[guest]
	actor.pos=game.stage.bed_position(1);actor.seed_choice=1;game.seed_reserve(actor).stock[1]+=1
	check(game.cultivation.plant_seed(guest,1),"guest seed plants through the host cultivation port")
	garden.advance_growth(10000)
	var familiarity:int=actor.character.plants[1];var material:int=garden.parts[1]
	check(game.cultivation.harvest(guest,1) and int(garden.plots[1].species)<0 and actor.character.plants[1]==familiarity+1 and garden.parts[1]==material+1,"one guest harvest commits the bed, native material and correct character familiarity")
	var harvest_rng:int=game.rng.state
	check(not game.cultivation.harvest(guest,1) and actor.character.plants[1]==familiarity+1 and garden.parts[1]==material+1 and game.rng.state==harvest_rng,"duplicate guest harvest cannot repeat rewards or RNG")
	mark("harvest_ready")
	if not check(await until(func():return marked("harvest_received")),"guest receives its committed harvest profile"):return
	garden.heart.unlock_direct("monster_studies")
	# This fixture owns the disposable world; construction still validates its
	# research, geometry and actual transaction rather than inventing a station.
	if not check(await until(func():return game.stage.experimental_garden._may_place()),"Garden construction becomes available after its reveal"):return
	if not check(Construction.place_researched(game,"study"),"researched Offering Altar is physically placed"):return
	game.seed_reserve(game.players[guest]).parts[game.Parts.HOOK]=1
	var knowledge:int=garden.knowledge
	game.players[guest].pos=game.stage.station_position("monster_studies")
	game.act(guest,false);mark("offering_ready")
	if not check(await until(func():return marked("offered")),"guest offers through the physical station panel"):return
	check(game.seed_reserve(game.players[guest]).parts[game.Parts.HOOK]==0 and garden.knowledge==knowledge+4,"one displayed trophy is spent once by the authoritative offering")
	var identity:String=Sessions.Session.inventory_owner(game.players[guest])
	mark("rejoin_ready")
	if not check(await until(func():return game.players.size()==1 and not game.departure_settlement.blocks_admission(identity) and not game.network_session.has_character(identity)),"host releases the prior binding and settlement before readmission"):return
	mark("readmission_ready")
	if not check(await until(func():return marked("rejoined")),"guest reconnects to the Garden"):return
	check(garden.garden_interactions.receipts.size()==1 and garden.knowledge==knowledge+4 and Care.preserved(garden.plots[0]),"rejoin cannot replay the observation, crop choice or offering")
	mark("done")
	check(await until(func():return marked("guest_done")),"guest finishes its received-state checks")
	await create_timer(.3).timeout

func guest_run():
	if not check(await until(func():return marked("observe_ready") and game.network_session.role()=="Guest" and game.guest_replication.has_details()),"Garden projection arrives"):return
	check_read_models()
	var view=game.get_node("GardenInteractions")
	if not check(await until(func():return view.panel.visible and view.selected=="heart_root_scar"),"host-authorized focus opens the real local observation panel"):return
	view.observe.pressed.emit();view.observe.pressed.emit()
	if not check(await until(func():return Interactions.projection(game,game.local_player_id()).get("revision",0)==1 and view.observe.disabled),"committed observation reaches its source view"):return
	game.ui.close_panels();mark("observed")
	if not check(await until(func():return marked("crop_ready")),"host prepares a crop"):return
	var crop=view.get_node("Crops")
	if not check(await until(func():return crop.panel.visible and crop.preserve.visible and not crop.last_bed.is_empty()),"real crop focus opens its inspector"):return
	var expected_revision:int=int(crop.last_bed.revision)+1
	crop.preserve.pressed.emit();crop.preserve.pressed.emit()
	if not check(await until(func():return game.cultivation.projection(game.local_player_id()).get("beds",[]).any(func(bed):return bed.get("preserved",false))),"one authoritative crop choice arrives"):return
	game.ui.close_panels();mark("preserved")
	if not check(await until(func():return marked("harvest_ready") and int(game.guest_character.data.plants[1])==1 and game.cultivation.projection(game.local_player_id()).get("beds",[]).any(func(bed):return bed.slot==0 and bed.stage==3)),"guest receives native harvest familiarity and matured crop state"):return
	var projection:Dictionary=game.cultivation.projection(game.local_player_id())
	expected_revision=int(projection.beds[0].revision);projection.beds[0].revision=-999
	check(int(game.cultivation.projection(game.local_player_id()).beds[0].revision)==expected_revision,"direct guest cultivation queries are detached from received state")
	mark("harvest_received")
	if not check(await until(func():return marked("offering_ready") and game.at_garden_station(game.players.get(game.local_player_id(),{}),"monster_studies")),"placed station and guest position agree"):return
	if not check(await until(func():return view.station_panel.visible and view.station_controls.station=="monster_studies" and not view.station_controls.apply.disabled),"current stored trophy enables the real Offering Altar control"):return
	view.station_controls.apply.pressed.emit()
	if not check(await until(func():return game.status.contains("Offered")),"host confirms the offering"):return
	game.ui.close_panels();mark("offered")
	if not check(await until(func():return marked("rejoin_ready")),"host permits Garden rejoin"):return
	var prior:int=game.get_instance_id();game.return_to_main_menu()
	if not check(await until(func():return current_scene.get_instance_id()!=prior and root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer),"guest returns through guarded title"):return
	await process_frame
	if not check(await until(func():return marked("readmission_ready")),"host confirms safe Garden readmission"):return
	game=await join_title(current_scene)
	if game==null:return
	if not check(await until(func():return game.network_session.role()=="Guest" and Interactions.projection(game,game.local_player_id()).get("revision",0)==1),"current Garden state is recovered"):return
	await process_frame
	view=game.get_node("GardenInteractions")
	check(view.cue_until==0 and not view.panel.visible and not view.station_panel.visible,"rejoin restores state without replaying a cue or old focus")
	var copy:Dictionary=game.garden_presentation.frame("crop")
	if check(not copy.data.beds.is_empty(),"received crop is available for detached inspection"):
		copy.data.beds[0].revision=-999
		check(int(game.cultivation.projection(game.local_player_id()).beds[0].revision)==expected_revision,"changing a display frame cannot change received authoritative state")
	mark("rejoined")
	check(await until(func():return marked("done")),"host confirms exactly-once outcomes")
	mark("guest_done")
