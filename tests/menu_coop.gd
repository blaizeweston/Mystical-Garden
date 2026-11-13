extends SceneTree
const Slots=preload("res://save_slots.gd")
const Character=preload("res://character_profile.gd")
var failed:=false
var game: Node
func check(ok: bool,message: String):
	if not ok:
		failed=true
		printerr("FAIL: ",message)
func _initialize():
	preload("res://combat_balance_preview.gd").enabled = false
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
		profile.data.appearance=[1,2,1,2,1,1,70,80,40,65,35,60,75]
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
		check(game.session=="Host" and game.active_slot==0,"host launches from the selected Garden slot")
		check(game.network_dialog.visible and game.network_dialog.lan_choices.get_item_text(0).ends_with(":"+str(game.network_port)),"host sees a shareable endpoint immediately")
		print("MENU HOST READY")
		if not await until(func(): return game.players.size()==2):
			check(false,"menu guest connected");finish(mode);return
		var guest_id: int=game.players.keys()[1]
		if not await until(func(): return game.players[guest_id].profile_ready):
			check(false,"guest profile registered");finish(mode);return
		check(game.players[guest_id].character.name=="Willow" and game.players[guest_id].character.xp[0]==3 and game.players[guest_id].character.appearance==[1,2,1,2,1,1,70,80,40,65,35,60,75],"Join carries the selected slot character")
		game.encounter_number=game.GRAFT_ROOM
		game.depth=4
		game.map_seed=91247
		game.reset_encounter()
		game.scouts.clear()
		for player in game.players.values():
			player.wild=true
			player.pos=game.battlefield.graft
		game.players[1].pos+=Vector3.LEFT*.5
		game.players[guest_id].carried_parts[4]=1
		game.players[guest_id].graft_choice=4
		game.enemy_pos=game.battlefield.graft+Vector3(0,0,1.0)
		game.enemy_ready_at=Time.get_ticks_msec()+60000
		var enemy_start: Vector3=game.enemy_pos
		if not await until(func(): return game.players[guest_id].carried_parts[4]==0):
			check(false,"guest graft request reached host");finish(mode);return
		if not await until(func(): return game.enemy_hp==game.encounter_health()-1):
			check(false,"guest strike reached host");finish(mode);return
		check(game.enemy_pos.distance_to(enemy_start)>.04,"guest hit produces authoritative knockback")
		game.players[1].run_upgrades = {"tempo":1}
		game.players[guest_id].run_upgrades = {"power":2}
		game.players[guest_id].power = 2
		await create_timer(2.0).timeout
	else:
		menu.select_slot(0) # Join with character 2 even while world 1 is active.
		menu.request_ip_join()
		menu.network_dialog.address_field.text="127.0.0.1:%d"%menu.network_port
		menu.network_dialog.confirm()
		check(current_scene.active_character_slot==1 and not current_scene.slot_claimed,"guest character selection is independent of the active world")
		game=current_scene
		if not await until(func(): return game.session=="Guest" and game.encounter_number==game.GRAFT_ROOM and game.players.has(game.multiplayer.get_unique_id()) and game.stage.graft_altar.visible):
			check(false,"Join from menu receives a visible live shrine");finish(mode);return
		var id: int=game.multiplayer.get_unique_id()
		check(Array(game.players[id].appearance)==[1,2,1,2,1,1,70,80,40,65,35,60,75],"full slider appearance replicated to guest")
		if not await until(func(): return game.players[id].get("carried_parts",[]).size()>1 and game.players[id].carried_parts[4]==1):
			check(false,"guest receives grafting resource");finish(mode);return
		var enemy_start: Vector3=game.enemy_pos
		check(game.enemy_hp>0 and game.graft_altar_open(),"shrine usable before clearing combat")
		game.send_garden_action("graft_install_4")
		if not await until(func(): return game.players[id].carried_parts[4]==0):
			check(false,"guest sees completed graft attempt");finish(mode);return
		game.send_action(true)
		game.update_projectiles(Time.get_ticks_msec()+1000)
		if not await until(func(): return game.enemy_hp==game.encounter_health()-1):
			check(false,"guest receives hit result");finish(mode);return
		check(game.enemy_pos.distance_to(enemy_start)>.04,"knockback position synchronizes to guest")
		check(not FileAccess.file_exists(storage.paths(slot).garden),"joining does not replace the guest's Garden slot")
		check(await until(func(): return game.players[id].get("run_upgrades",{}).get("power",0)==2, 2.0),"guest receives their upgrade ranks")
		game.toggle_overlay(null) # Dismiss the graft result before opening the summary.
		var tab := InputEventKey.new()
		tab.physical_keycode = KEY_TAB
		tab.pressed = true
		game._input(tab)
		var summary: PanelContainer = game.overlay.get_node("RunSummary")
		check(summary.visible and summary.cards.item_count==1 and summary.cards.get_item_text(0).contains("Stronger Strikes")
			and summary.shown.totals[0][1].contains("+2"), "guest summary reconstructs strike power and lists only their own cards")
	finish(mode)
func finish(mode: String):
	if not failed: print("PASS: menu "+mode+" join, selected character, live shrine and knockback")
	quit(1 if failed else 0)
