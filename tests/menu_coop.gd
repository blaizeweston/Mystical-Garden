extends SceneTree
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")
const Slots=preload("res://save_slots.gd")
const Character=preload("res://character_profile.gd")
const Appearance=preload("res://character_appearance.gd")
const Grafts=preload("res://expedition_grafts.gd")
const Cards=preload("res://affinity_cards.gd")
const LEGACY_LOOK=[1,2,1,2,1,1,70,80,40,65,35,60,75]
var failed:=false
var game: Node
func check(ok: bool,message: String):
	if not ok:
		failed=true
		printerr("FAIL: ",message)
func _initialize():
	call_deferred("run")
func until(predicate: Callable,seconds: float=20.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await process_frame
	return predicate.call()
func run():
	var mode: String=OS.get_cmdline_user_args()[0]
	var storage:=Slots.new()
	storage.root_path="res://.godot/menu_coop_shared_"+OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size()>1 else "res://.godot/menu_coop_"+mode+"_"+Crypto.new().generate_random_bytes(8).hex_encode()
	storage.prepare(false)
	var slot:=0 if mode=="host" else 1
	if mode=="host":
		storage.new_game(slot)
	else:
		storage.ensure_character(slot)
		var profile:=Character.new()
		profile.path=storage.paths(slot).character
		profile.load_profile()
		profile.data.name="Willow"
		profile.data.xp[0]=3
		profile.data.appearance=LEGACY_LOOK.duplicate()
		profile.save_profile()
	var menu=load("res://main_menu.tscn").instantiate()
	menu.storage.root_path=storage.root_path
	menu.import_legacy=false
	menu.restore_last_selection=false
	root.add_child(menu)
	current_scene=menu
	if mode=="guest" and OS.get_cmdline_user_args().size()>1:
		menu.select_slot(0)
		check(menu.continue_button.disabled and menu.new_button.disabled and not menu.join_button.disabled,"another window cannot open the active Garden but can join with another character")
	menu.select_slot(slot)
	menu.select_character(slot)
	if mode=="host":
		menu.host_choice.button_pressed=true
		menu.continue_game()
		game=current_scene
		check(game.network_session.role()=="Host" and game.active_slot==0,"host launches from the selected Garden slot")
		check(game.network_dialog.visible and game.network_dialog.lan_choices.get_item_text(0).ends_with(":"+str(game.network_session.port())),"host sees a shareable endpoint immediately")
		print("MENU HOST READY")
		if not await until(func(): return game.players.size()==2):
			check(false,"menu guest connected");finish(mode);return
		var guest_id: int=game.players.keys()[1]
		if not await until(func(): return SessionCase.Session.ready_for(game.players[guest_id])):
			check(false,"guest profile registered");finish(mode);return
		check(game.players[guest_id].character.name=="Willow" and game.players[guest_id].character.xp[0]==3 and game.players[guest_id].character.appearance==Appearance.normalize(LEGACY_LOOK),"Join carries the selected slot character and migrated cosmetic options")
		ExpeditionCase.set_world(game, {"encounter_number": game.GRAFT_ROOM})
		ExpeditionCase.set_world(game, {"depth": 4})
		ExpeditionCase.set_world(game, {"map_seed": 91247})
		game.reset_encounter()
		game.encounter.clear_scouts()
		for player in game.players.values():
			ExpeditionCase.set_membership(game, player, true)
			player.pos=game.battlefield.graft
			var graph=game.Classes.connected_tree(int(player.frame))
			player.character[graph.profile_key]=graph.state(["rootkeeper"])
			player[Grafts.STATE]=Grafts.Ledger.new(int(SessionCase.Session.peer_for(player)))
		game.players[1].pos+=Vector3.LEFT*.5
		game.players[guest_id].carried_parts[4]=1
		game.tactics.position=game.battlefield.graft+Vector3(0,0,1.0)
		game.tactics.ready_at=Time.get_ticks_msec()+60000
		var enemy_start: Vector3=game.tactics.position
		var before_hit_hp: int=game.enemy_health()
		if not await until(func(): return game.players[guest_id].carried_parts[4]==0):
			check(false,"guest graft request reached host");finish(mode);return
		if not await until(func(): return game.enemy_health()<before_hit_hp):
			check(false,"guest strike reached host");finish(mode);return
		var after_hit_hp: int=game.enemy_health()
		var hit_receipt: Dictionary={"before_hp":before_hit_hp,"after_hp":after_hit_hp,"damage_hp":before_hit_hp-after_hit_hp}
		check(hit_receipt.damage_hp>0 and after_hit_hp>0,"a real current-scale hit damages the living enemy")
		var receipt_file:=FileAccess.open(storage.root_path.path_join("host-hit.json"),FileAccess.WRITE)
		check(receipt_file!=null,"isolated fixture records authoritative hit HP")
		if receipt_file==null:finish(mode);return
		receipt_file.store_string(JSON.stringify(hit_receipt))
		receipt_file.close()
		var receipt_ready:=FileAccess.open(storage.root_path.path_join("host-hit.ready"),FileAccess.WRITE)
		check(receipt_ready!=null,"host publishes only the completed hit receipt")
		if receipt_ready==null:finish(mode);return
		receipt_ready.store_string("complete")
		receipt_ready.close()
		check(game.tactics.position.distance_to(enemy_start)>.04,"guest hit produces authoritative knockback")
		check(await until(func():return FileAccess.file_exists(storage.root_path.path_join("guest-hit.ready"))),"guest observes the hit before the checkpoint state replaces it")
		var recipient: Dictionary=game.players[guest_id]
		ExpeditionCase.set_world(game,{"encounter_number":9})
		game.deepest_milestone=9
		game.encounter.set_hp(-1,0)
		game.encounter.clear_scouts()
		game.checkpoint_pending=true
		game.checkpoint_ready.clear()
		for actor in game.players.values():actor.pos=game.battlefield.advance
		var selected_seed: int=-1
		var stats: Dictionary=game.weapon_stats(recipient)
		for seed_value in 100:
			var candidate=Cards.Ledger.new().open_offer(9,1,seed_value,stats,game.DODGE_COOLDOWN_MS)
			if candidate.offer().cards.any(func(card):return card.id=="ordinary_weapon_damage"):
				selected_seed=seed_value
				break
		check(selected_seed>=0,"a real eligible Honed Strikes offer is reachable")
		if selected_seed<0:finish(mode);return
		recipient.upgrade_seed=selected_seed
		game.present_checkpoint_cards(guest_id)
		check(await until(func():return Cards.ledger(recipient)!=null and Cards.ledger(recipient).count()==1),"guest selects one real free card")
		check(Cards.ledger(game.players[1])==null and game.wallet_for(recipient).spent_essence()==0,"guest selection neither grants host cards nor spends Essence")
		await create_timer(2.0).timeout
	else:
		menu.select_slot(0) # Join with character 2 even while world 1 is active.
		menu.request_ip_join()
		menu.network_dialog.address_field.text="127.0.0.1:%d"%menu.network_port
		menu.network_dialog.confirm()
		check(current_scene.active_character_slot==1 and not current_scene.slot_claimed,"guest character selection is independent of the active world")
		game=current_scene
		if not await until(func(): return game.network_session.role()=="Guest" and game.participation.floor()==game.GRAFT_ROOM and game.players.has(game.multiplayer.get_unique_id()) and game.stage.graft_altar.visible):
			check(false,"Join from menu receives a visible live shrine");finish(mode);return
		var id: int=game.multiplayer.get_unique_id()
		check(Array(game.players[id].appearance)==Appearance.normalize(LEGACY_LOOK),"full legacy slider appearance and default accessories replicate to guest")
		if not await until(func(): return game.players[id].get("carried_parts",[]).size()>1 and game.players[id].carried_parts[4]==1):
			check(false,"guest receives grafting resource");finish(mode);return
		var enemy_start: Vector3=game.tactics.position
		check(game.enemy_health()>0 and game.graft_altar_open(),"shrine usable before clearing combat")
		var graft_offer: Dictionary=game.players[id].get("graft_improvements",{})
		check(not graft_offer.is_empty(),"guest receives the authoritative cumulative altar offer")
		game.send_action(false)
		check(await until(func():return game.ui.panel_is_open("graft")),"guest opens the authoritative graft view")
		var graft: Control = UIFixture.control(game,"graft_view")
		graft.selected="reach"
		graft.trophy=game.Items.part_id(4)
		graft.show_selection()
		check(not graft.confirm.disabled,"guest sees a payable trophy quote")
		graft.confirm.pressed.emit()
		if not await until(func(): return game.players[id].carried_parts[4]==0):
			check(false,"guest sees completed graft attempt");finish(mode);return
		game.ui.close_panels()
		game.send_action(true)
		WeaponCase.advance(game,Time.get_ticks_msec()+1000)
		if not await until(func():return FileAccess.file_exists(storage.root_path.path_join("host-hit.ready"))):
			check(false,"host publishes actual hit result");finish(mode);return
		var hit_receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(storage.root_path.path_join("host-hit.json")))
		check(int(hit_receipt.damage_hp)>0 and int(hit_receipt.before_hp)-int(hit_receipt.after_hp)==int(hit_receipt.damage_hp),"receipt preserves the actual host damage without a nominal roll assumption")
		if not await until(func():return game.enemy_health()==int(hit_receipt.after_hp)):
			check(false,"guest receives the exact authoritative current-scale HP result");finish(mode);return
		check(game.tactics.position.distance_to(enemy_start)>.04,"knockback position synchronizes to guest")
		check(not FileAccess.file_exists(storage.paths(slot).garden),"joining does not replace the guest's Garden slot")
		var observation:=FileAccess.open(storage.root_path.path_join("guest-hit.ready"),FileAccess.WRITE)
		check(observation!=null,"isolated fixture records the observed hit")
		if observation!=null:
			observation.store_string("observed")
			observation.close()
		check(await until(func():return UIFixture.control(game,"checkpoint_menu").visible and game.participation.floor()==9),"free checkpoint offer arrives")
		var choice: int=UIFixture.control(game,"checkpoint_cards").get_children().find_custom(func(frame):return frame.get_child(0).get_child(0).text=="Honed Strikes")
		check(choice>=0,"the real picker shows Honed Strikes")
		if choice<0:finish(mode);return
		game.send_garden_action(game.affinity_checkpoint_action(game.ui.checkpoint_revision(),str(choice)))
		check(await until(func():return game.players[id].get("affinity_run_cards",[]).size()==1),"guest receives their acquired copy")
		game.ui.close_panels()
		var tab := InputEventKey.new()
		tab.physical_keycode = KEY_TAB
		tab.pressed = true
		game._input(tab)
		var summary: PanelContainer = UIFixture.control(game,"summary_view")
		check(summary.visible and summary.grouped_cards.get_child_count()==1 and summary.shown.cards[0].id=="ordinary_weapon_damage"
			and summary.shown.cards[0].summary.contains("damage"), "guest summary shows only their actual card contribution")
	finish(mode)
func finish(mode: String):
	if not failed: print("PASS: menu "+mode+" join, selected character, live shrine and knockback")
	quit(1 if failed else 0)
