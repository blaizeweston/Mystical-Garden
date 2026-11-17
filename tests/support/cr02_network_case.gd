extends RefCounted

const Rules = preload("res://combat_ruleset.gd")
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
		if id!=1 and world.players[id].profile_ready: return id
	return 0


func run(scene_tree: SceneTree, mismatch: bool, definition_mismatch := false) -> bool:
	tree = scene_tree
	var role := OS.get_cmdline_user_args()[0]
	if definition_mismatch and role == "guest": Rules.definition_signature = "different-definitions"
	signal_root = OS.get_environment("MYSTICAL_TERRAIN_TEST_SIGNALS")
	port = int(OS.get_environment("MYSTICAL_GARDEN_TEST_PORT"))
	var menu := Menu.instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	if not check(Rules.active(menu)==(role=="host" or not mismatch or definition_mismatch),"real title selects requested ruleset"):
		return false
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
	if not check(await until(func(): return tree.current_scene.get("session")=="Host"),"host opens through guarded title"):
		return
	var world := tree.current_scene
	world.network_dialog.dismiss()
	check(Rules.active(world),"host hands the ruleset to the world")
	mark("host")
	if mismatch:
		check(await until(func(): return read("refused")=="ok"),"mismatched guest observes clear refusal")
		check(guest_id(world)==0 and world.players.size()==1,"mismatch never admits a guest")
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
	# Ghost Fern now supplies Spirit. Inject a stocked fourth-slot part into
	# the Core field to exercise the invalid-build departure boundary.
	var invalid_core: int = world.Parts.HOOK
	world.progress.add_parts(invalid_core,1)
	var before: int = world.progress.part_count(invalid_core)
	local.prepared = invalid_core
	world.enter_wilds(1,local)
	check(not local.wild and world.travel_kind.is_empty() and before>0
		and world.progress.part_count(invalid_core)==before and "Core material is invalid" in world.status,
		"invalid Core departure is refused before proposing travel or debiting stock")
	local.prepared=0
	world.map_rng.seed=16
	world.PartyTravel.request(world,1,"depart")
	mark("depart",str(world.travel_epoch))
	if not check(await until(func(): return remote.wild and not world.battlefield.generated.is_empty()),"native-only party enters actual generated Wilds"):
		return
	# A real guest Q is authoritative on host, and the actual block
	# consumes the guard and reports the protected remote recipient.
	var events: Array[Dictionary] = []
	world.set_meta(Events.RECORD,func(event): events.append(event))
	mark("guard")
	if not check(await until(func(): return int(remote.guard_charges)>0),"guest Q grants native Guard on host"):
		return
	remote.hurt_until=0
	world.apply_enemy_hit(guest_id(world),remote,Time.get_ticks_msec(),1)
	check(events.size()==1 and events[0].kind=="actual_block"
		and events[0].source_actor==guest_id(world) and events[0].details.recipient==guest_id(world),
		"remote Guard owns the block response")
	local.pos = remote.pos
	local.character.upgrades[0] = 1 << 1
	world.use_class_skill(1,local,0)
	check(events.size()==1 and int(remote.guard_charges)==2,"granting does not synthesize a block")
	world.apply_enemy_hit(guest_id(world),remote,Time.get_ticks_msec(),1)
	check(events.size()==2 and events[1].source_actor==1 and events[1].details.recipient==guest_id(world),
		"host-granted Ward responds around its protected remote ally")
	# Both actors have native-only kits. A cleared checkpoint exercises the
	# real reliable offer UI and owner-validated command path.
	world.encounter_number=6
	world.deepest_milestone=6
	world.enemy_hp=0
	world.scouts.clear()
	world.encounter_rewarded=true
	local.pos=world.battlefield.advance
	remote.pos=local.pos
	remote.essence_sparks=0
	local.spent=world.run_wallet(local)
	local.checkpoint_offers=["rift_hook"]
	world.use_checkpoint(1,true)
	var cards_api = world.AffinityCards
	var host_offer: Dictionary = cards_api.ledger(local).offer()
	var initial_ledger = cards_api.ledger(remote)
	var initial: Dictionary = initial_ledger.offer()
	check(world.checkpoint_cards.get_child_count()==3 and "free" in world.checkpoint_notice.text
		and world.run_wallet(local)==0 and not world.buy_upgrade(1,local,0),
		"new cards are offered at zero Essence and the legacy purchase remains refused")
	world.present_checkpoint_cards(guest_id(world))
	check(cards_api.ledger(remote)==initial_ledger and initial_ledger.offer()==initial,
		"reopening the guest's offer preserves its full revision")
	world.send_garden_action(world.affinity_checkpoint_action(host_offer.revision,"0"))
	mark("cards")
	if not check(await until(func(): return read("guest-cards")=="ok" and cards_api.ledger(remote).copies().size()==1),
		"guest pays for rerolls and acquires one copy through the host"):return
	var remote_cards = cards_api.ledger(remote)
	var host_cards = cards_api.ledger(local)
	check(remote_cards.offer().rerolls==3 and remote.spent==12 and world.run_wallet(remote)==0
		and host_cards.copies().size()==1 and world.run_wallet(local)==0 and local.run_upgrades.is_empty()
		and remote.run_upgrades.is_empty() and initial_ledger.offer()==initial,
		"host debits 2/4/6 once for the guest, both selections are free, and the prior offer stays intact")
	world.PartyTravel.request(world,1,"advance")
	mark("checkpoint",str(world.travel_epoch))
	if not check(await until(func(): return read("guest-ready")=="ok" and world.encounter_number==7),
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
			"normal title displays specific mismatched combat mode"):
			mark("refused")
		return
	if not check(await until(func(): return tree.current_scene.get("session")=="Guest" and tree.current_scene.stage.experimental_garden.remote_revision>=0),"guest joins actual Garden"):
		return
	var world := tree.current_scene
	check(Rules.active(world) and not world.get_meta(world.Transactions.SESSION).authorizes(world.progress.path),
		"guest resolves same mode with no host save ownership")
	mark("admitted")
	if not check(await until(func():return read("focus-gate")=="ok"),"host opens the starting focus picker"):return
	world.send_garden_action("learn_0_64")
	if not check(await until(func(): return not read("depart").is_empty()),"host proposes travel"):
		return
	world.send_garden_action("travel_ready:"+read("depart"))
	if not check(await until(func(): return read("guard")=="ok" and world.stage._has_experimental_floor()),"guest receives generated floor"):
		return
	world.send_garden_action("class_skill")
	var offer_received := func() -> bool:
		return read("cards")=="ok" and world.checkpoint_offer_revision>0 and world.checkpoint_cards.get_child_count()==3 and "12 Essence" in world.checkpoint_notice.text
	if not check(await until(offer_received),
		"guest receives three actual options and an authoritative starting wallet"):return
	for balance in [10,6,0]:
		var revision: int = world.checkpoint_offer_revision
		world.send_garden_action(world.affinity_checkpoint_action(revision,"reroll"))
		world.send_garden_action(world.affinity_checkpoint_action(revision,"0"))
		world.send_garden_action(world.affinity_checkpoint_action(revision,"reroll"))
		var reroll_received := func() -> bool:
			return world.checkpoint_offer_revision>revision and "%d Essence" % balance in world.checkpoint_notice.text
		if not check(await until(reroll_received),
			"new offer revision and exact balance after reroll; stale requests do nothing"):return
	var chosen: String = world.affinity_checkpoint_action(world.checkpoint_offer_revision,"0")
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
	if not check(await until(func(): return read("done")=="ok" and world.encounter_number==7),"guest sees authoritative next floor"):
		return
	mark("guest-done")
