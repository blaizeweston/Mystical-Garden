extends RefCounted
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const Rules = preload("res://combat_ruleset.gd")
const Build = preload("res://affinity_build.gd")
const Core = preload("res://core_combat.gd")
const Experiment = preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const Events = preload("res://combat_action_events.gd")
const Menu = preload("res://main_menu.tscn")
const Appearance = preload("res://character_appearance.gd")

var tree: SceneTree
var signal_root: String
var port: int
var failed := false


func check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		printerr("FAIL CR02 co-op: ", message)
	return ok


func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+18000
	while not condition.call() and Time.get_ticks_msec()<deadline:
		await tree.process_frame
	return condition.call()


func mark(key: String, value := "ok") -> void:
	var file := FileAccess.open(signal_root.path_join(key),FileAccess.WRITE)
	if check(file!=null,"write marker "+key):
		file.store_string(value)


func read(key: String) -> String:
	return FileAccess.get_file_as_string(signal_root.path_join(key))


func guest_id(world: Node) -> int:
	for id in world.players:
		if id!=1 and SessionCase.Session.ready_for(world.players[id]): return id
	return 0


func run(scene_tree: SceneTree, mismatch: bool) -> bool:
	tree = scene_tree
	var role := OS.get_cmdline_user_args()[0]
	if mismatch and role == "guest":
		# Keep the modern ruleset ID and advertise incompatible definitions.
		# Each fixture process owns its own contract value.
		Rules.definition_signature = "different-definitions"
	signal_root = OS.get_environment("MYSTICAL_TERRAIN_TEST_SIGNALS")
	port = int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT"))
	var menu := Menu.instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	if not check(Experiment.verified() and Experiment.active(menu),"real title retains isolated terrain and save protection"):
		return false
	print("CASE CR02 isolation ",JSON.stringify({"peer":role,"verified":true,
		"profile":OS.get_environment(Experiment.PROFILE_ENV),"user_data":OS.get_user_data_dir()}))
	if role=="host":
		await host(menu,mismatch)
	else:
		await guest(menu,mismatch)
	return not failed


func host(menu: Node, mismatch: bool) -> void:
	menu.host_port = port
	menu.host_choice.button_pressed = true
	menu.new_game()
	menu.create_character("Affinity Host",0,Appearance.DEFAULT)
	if not check(await until(func(): return SessionCase.role(tree.current_scene)=="Host"),"host opens through guarded title"):
		return
	var world := tree.current_scene
	world.network_dialog.dismiss()
	check(Build.for_player(world.players[1]).ruleset==Rules.ID,"host uses the sole modern build contract")
	var authenticated_guests: Array[int] = []
	var record_admission := func(id: int) -> void: authenticated_guests.append(id)
	if mismatch: world.multiplayer.peer_connected.connect(record_admission)
	mark("host")
	if mismatch:
		check(await until(func(): return read("refused")=="ok"),"mismatched guest observes clear refusal")
		check(authenticated_guests.is_empty() and guest_id(world)==0 and world.players.size()==1,"mismatch never admits a guest")
		print("CASE CR02 rejection ",JSON.stringify({"authenticated_guests":authenticated_guests,
			"ready_guest":guest_id(world),"players":world.players.size()}))
		world.multiplayer.peer_connected.disconnect(record_admission)
		world.return_to_main_menu()
		return
	if not check(await until(func(): return guest_id(world)!=0 and read("admitted")=="ok"),"matching peers are admitted"):
		return
	var remote: Dictionary = world.players[guest_id(world)]
	var local: Dictionary = world.players[1]
	local.pos = world.stage.gate_position()
	remote.pos = local.pos
	world.garden_action(1,"learn_0_66")
	mark("focus-gate")
	var remote_focused := func() -> bool:
		return preload("res://warden_connected_tree.gd").focus(remote.character)=="vanguard"
	if not check(await until(remote_focused),"guest chooses a native starting focus at zero XP"):return
	# A monster material is invalid in a plant slot, before any travel or debit.
	var invalid_core: int = world.Parts.HOOK
	world.progress.add_parts(invalid_core,1)
	var before: int = world.progress.part_count(invalid_core)
	local.prepared = invalid_core
	ExpeditionCase.Transitions.enter(world, 1,local)
	check(not ExpeditionCase.is_wild(local) and world.participation.travel_kind().is_empty() and before>0
		and world.progress.part_count(invalid_core)==before and "Core material is invalid" in world.status,
		"invalid Core departure is refused before proposing travel or debiting stock")
	local.prepared=0
	world.map_rng.seed=16
	world.PartyTravel.request(world,1,"depart")
	mark("depart",str(world.participation.travel_epoch()))
	if not check(await until(func(): return ExpeditionCase.is_wild(remote) and not world.battlefield.generated.is_empty()),"native-only party enters actual generated Wilds"):
		return
	# Hold unrelated AI while this fixture injects the exact two defense contacts.
	# Keep networking, the real generated roster and authoritative health active.
	var held_until := Time.get_ticks_msec()+18000
	world.tactics.stop_attack()
	world.tactics.stagger_until=held_until
	world.tactics.ready_at=held_until
	for scout in world.encounter.scout_tactics():
		scout.windup=0
		scout.erase("attack")
		scout.stagger_until=held_until
		scout.ready=held_until
	# A real guest Q is authoritative on host, and the actual block
	# consumes the guard and reports the protected remote recipient.
	var events: Array[Dictionary] = []
	world.set_meta(Events.RECORD,func(event): events.append(event))
	mark("guard")
	if not check(await until(func(): return int(remote[Protection.STATE].charge_count())>0),"guest Q grants native Guard on host"):
		return
	print("CASE CR02 authoritative_action ",JSON.stringify({"actor":guest_id(world),"guard_charges":int(remote[Protection.STATE].charge_count())}))
	remote[Conditions.STATE] = remote[Conditions.STATE].clear_grace()
	IncomingPlayerHit.resolve_world(world, guest_id(world), PlayerLifecycle.generation(remote), Time.get_ticks_msec(), 1)
	check(events.size()==1 and events[0].kind=="actual_block"
		and events[0].source_actor==guest_id(world) and events[0].details.recipient==guest_id(world),
		"remote Guard owns the block response")
	local.pos = remote.pos
	check(preload("res://warden_connected_tree.gd").focus(local.character)=="bastion","host keeps the selected connected Bastion focus")
	world.use_class_skill(1,local,0)
	check(events.size()==1 and int(remote[Protection.STATE].charge_count())==1,"Rootshield grants one native Ward without synthesizing a block")
	IncomingPlayerHit.resolve_world(world, guest_id(world), PlayerLifecycle.generation(remote), Time.get_ticks_msec(), 1)
	check(events.size()==2 and events[1].source_actor==1 and events[1].details.recipient==guest_id(world),
		"host-granted Ward responds around its protected remote ally")
	# Both actors have native-only kits. A cleared checkpoint exercises the
	# real reliable offer UI and owner-validated command path.
	ExpeditionCase.set_world(world, {"encounter_number": 6})
	world.deepest_milestone=6
	world.encounter.set_hp(-1, 0)
	world.encounter.clear_scouts()
	world.encounter_rewarded=true
	local.pos=world.battlefield.advance
	remote.pos=local.pos
	remote[world.ExpeditionWallet.STATE] = world.ExpeditionWallet.Wallet.new()
	local[world.ExpeditionWallet.STATE] = world.ExpeditionWallet.Wallet.new(0, world.run_wallet(local))
	var host_wallet = world.wallet_for(local)
	ExpeditionCase.Transitions.checkpoint(world, 1,true)
	var cards_api = world.AffinityCards
	var host_offer: Dictionary = cards_api.ledger(local).offer()
	var initial_ledger = cards_api.ledger(remote)
	var initial: Dictionary = initial_ledger.offer()
	check(UIFixture.control(world,"checkpoint_cards").get_child_count()==3 and "free" in UIFixture.control(world,"checkpoint_notice").text
		and world.run_wallet(local)==0 and not world.has_method("buy_upgrade"),
		"new cards are offered at zero Essence and the retired purchase implementation is absent")
	world.present_checkpoint_cards(guest_id(world))
	check(cards_api.ledger(remote)==initial_ledger and initial_ledger.offer()==initial,
		"reopening the guest's offer preserves its full revision")
	world.send_garden_action(world.affinity_checkpoint_action(host_offer.revision,"0"))
	mark("cards")
	if not check(await until(func(): return read("guest-cards")=="ok" and cards_api.ledger(remote).copies().size()==1),
		"guest pays for rerolls and acquires one copy through the host"):return
	var remote_cards = cards_api.ledger(remote)
	var host_cards = cards_api.ledger(local)
	check(remote_cards.offer().rerolls==3 and world.wallet_for(remote).spent_essence()==12 and world.run_wallet(remote)==0
		and host_cards.copies().size()==1 and world.run_wallet(local)==0 and world.wallet_for(local)==host_wallet
		and not local.has("run_upgrades") and not remote.has("run_upgrades") and initial_ledger.offer()==initial,
		"host debits 2/4/6 once for the guest, both selections are free, and the prior offer stays intact")
	world.PartyTravel.request(world,1,"advance")
	mark("checkpoint",str(world.participation.travel_epoch()))
	if not check(await until(func(): return read("guest-ready")=="ok" and world.participation.floor()==7),
		"both selections preserve the actual onward Gate"):return
	check(cards_api.ledger(remote)==remote_cards and remote_cards.copies().size()==1
		and cards_api.ledger(local)==host_cards and host_cards.copies().size()==1,
		"independent receipts survive floor travel")
	mark("done")
	await until(func(): return read("guest-done")=="ok")
	world.return_to_main_menu()


func guest(menu: Node, mismatch: bool) -> void:
	menu.request_create_character()
	menu.create_character("Affinity Guest",0,Appearance.DEFAULT)
	if not check(await until(func(): return read("host")=="ok"),"host ready"):
		return
	menu.show_page(2)
	menu.join_button.pressed.emit()
	menu.network_dialog.address_field.text = "127.0.0.1:"+str(port)
	menu.network_dialog.submit.pressed.emit()
	if mismatch:
		if check(await until(func(): return tree.current_scene.get("return_message")==Rules.MISMATCH),
			"normal title displays specific incompatible gameplay refusal"):
			print("CASE CR02 refusal ",tree.current_scene.get("return_message"))
			mark("refused")
		return
	if not check(await until(func(): return SessionCase.role(tree.current_scene)=="Guest" and tree.current_scene.stage.experimental_garden.remote_revision>=0),"guest joins actual Garden"):
		return
	var world := tree.current_scene
	check(Build.for_player(world.players[world.local_player_id()]).ruleset==Rules.ID
		and not world.persistence_session.authorizes(world.progress.path),
		"guest resolves modern gameplay without host save ownership")
	mark("admitted")
	if not check(await until(func():return read("focus-gate")=="ok"),"host opens the starting focus picker"):return
	world.send_garden_action("learn_0_64")
	if not check(await until(func(): return not read("depart").is_empty()),"host proposes travel"):
		return
	world.send_garden_action("travel_ready:"+read("depart"))
	var native_action_ready := func() -> bool:
		return (read("guard")=="ok" and world.stage.has_floor()
			and not Core.cast_key(world,world.players.get(world.local_player_id(),{})).is_empty())
	if not check(await until(native_action_ready),"guest receives generated floor and current native-action identity"):
		return
	print("CASE CR02 action_ready ",JSON.stringify({"current_identity":not Core.cast_key(world,world.players[world.local_player_id()]).is_empty()}))
	world.send_garden_action("class_skill")
	var offer_received := func() -> bool:
		return read("cards")=="ok" and world.ui.checkpoint_revision()>0 and UIFixture.control(world,"checkpoint_cards").get_child_count()==3 and "12 Essence" in UIFixture.control(world,"checkpoint_notice").text
	if not check(await until(offer_received),
		"guest receives three actual options and an authoritative starting wallet"):return
	for balance in [10,6,0]:
		var revision: int = world.ui.checkpoint_revision()
		world.send_garden_action(world.affinity_checkpoint_action(revision,"reroll"))
		world.send_garden_action(world.affinity_checkpoint_action(revision,"0"))
		world.send_garden_action(world.affinity_checkpoint_action(revision,"reroll"))
		var reroll_received := func() -> bool:
			return world.ui.checkpoint_revision()>revision and "%d Essence" % balance in UIFixture.control(world,"checkpoint_notice").text
		if not check(await until(reroll_received),
			"new offer revision and exact balance after reroll; stale requests do nothing"):return
	var chosen: String = world.affinity_checkpoint_action(world.ui.checkpoint_revision(),"0")
	world.send_garden_action(chosen)
	world.send_garden_action(chosen)
	var local := func() -> Dictionary: return world.players.get(world.local_player_id(),{})
	if not check(await until(func(): return local.call().get("affinity_run_cards",[]).size()==1 and local.call().get("wallet",-1)==0),
		"guest sees one free acquired copy and the repaired wallet through normal details"):return
	mark("guest-cards")
	var gate_requested := func() -> bool:
		return not read("checkpoint").is_empty() and int(world.party_travel_state().get("epoch",-1))==int(read("checkpoint"))
	if not check(await until(gate_requested),
		"host asks for onward readiness after card acquisition"):return
	world.send_garden_action("travel_ready:"+read("checkpoint"))
	mark("guest-ready")
	if not check(await until(func(): return read("done")=="ok" and world.participation.floor()==7),"guest sees authoritative next floor"):
		return
	mark("guest-done")
