extends SceneTree
const Gate = preload("res://persistence_writer_integration.gd")
const Actions = preload("res://combat_action_events.gd")
const Tx = preload("res://game_transaction.gd")
const G = "user://saves/slot_1/garden.cfg"
var phase: String

func check(ok: bool, detail: String) -> bool:
	if not ok:
		printerr("FAIL: ",detail)
		quit(1)
	return ok

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not check(OS.get_environment("MYSTICAL_VALIDATION_FIXTURE")=="expedition_suspend" and DirAccess.dir_exists_absolute("user://release-fixtures"),"isolated save root"): return
	phase = OS.get_cmdline_user_args()[0]
	set_meta(Gate.VALIDATION_ROUTE,true)
	var title: Node = load("res://main_menu.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	if phase=="write":
		title.new_button.pressed.emit()
		title.creator.name_field.text = "Run Keeper"
		title.creator.confirmed.emit()
		if current_scene==title: title.new_button.pressed.emit()
	else:
		if not check(title.continue_button.text=="Continue Expedition" and not title.continue_button.disabled,"title offers saved fight"): return
		title.continue_button.pressed.emit()
	var game := current_scene
	if not check(game!=title and game.persistence_session.owns_leases(),"world opened: "+title.notice.text): return
	game.set_physics_process(false)
	var actor: Dictionary = game.players[1]
	if phase=="write":
		# A local host may have left an earlier co-op session in this process.
		actor[game.Session.STATE] = game.network_session.restore_expedition_host(7)
		actor.pos = game.Stage.HEART
		game.handle_loadout_action(1,actor,"learn_0_64")
		actor.pos = game.stage.gate_position()
		game.expedition_transitions.enter(1)
		if not check(game.participation.contains(1),"entered the expedition"): return
		game.encounter.set_hp(-1,2)
		game.tactics.position = game.battlefield.leader
		actor.carried_items["seed_thorn_bloom"] = 2
		actor.pos = game.battlefield.entry
		game.tactics.winding_up = true
		game.tactics.strike_at = game.CombatClock.now()+1750
		game.expedition_statistics.count(game.participation.run_id(),game.local_character.identity,"cards",3)
		var cast := Actions.begin(game,1,"form",{}, {},["weapon_contact"],game.CombatClock.now()+3000)
		if not check(game.weapon_attacks.try_start(game.weapon_attack_world,1,actor.pos,game.CombatClock.now()) and game.weapon_attacks.pending_count()==1,"ordinary weapon attack admitted"): return
		actor.test_pending_action = cast
		game.tactics.memory.test_pending_action = cast
		game.set_meta(&"guarded_gameplay_test_fault",func(step: String,path: String):return ERR_FILE_CANT_WRITE if step=="stage" and path==G+".txn_stage" else OK)
		if not check(not game.Continuation.suspend(game) and game.progress.suspended_expedition.is_empty() and game.participation.active(),"failed save keeps fight playable"): return
		game.remove_meta(&"guarded_gameplay_test_fault")
		game.save_and_quit(false)
		if not check(current_scene!=game,"Save & Quit returned to title: "+game.status): return
	elif phase=="read":
		if not check(game.participation.contains(1) and game.encounter.hp(-1)==2 and game.tactics.position.is_equal_approx(game.battlefield.leader),"same encounter, position and HP restored: "+game.status): return
		if not check(actor.carried_items.get("seed_thorn_bloom")==2 and actor.pos.is_equal_approx(game.battlefield.entry),"carried named seeds and player position intact"): return
		if not check(game.tactics.winding_up and absi(game.tactics.strike_at-game.CombatClock.now()-1750)<700,"enemy windup remaining time"): return
		if not check(actor.test_pending_action is Actions and is_same(game.tactics.memory.test_pending_action,actor.test_pending_action),"one-use action identity shared across restored owners"): return
		if not check(game.weapon_attacks.pending_count()==1,"one pending weapon attack restored"): return
		var shot: Dictionary = game.weapon_attacks.views()[0]
		if not check(game.weapon_attack_world.current(1,shot.epoch,shot.life,shot.binding),"restored weapon attack belongs to the same living attacker"): return
		game.weapon_attacks.advance(game.weapon_attack_world,game.CombatClock.now()+5000)
		if not check(game.weapon_attacks.is_empty(),"pending weapon attack completed"): return
		if not check(game.expedition_statistics.savepoint().rows[game.local_character.identity].cards==3,"statistics preserved"): return
		if not check(game.progress.suspended_expedition.is_empty(),"resumed save consumed"): return
		game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		if not check(game.expedition_saved_for_exit and not game.progress.suspended_expedition.is_empty(),"ordinary window close saved the fight"): return
	else:
		if not check(game.participation.contains(1) and game.weapon_attacks.is_empty() and actor.carried_items.get("seed_thorn_bloom")==2,"window-close save retained carried loot and consumed attack"): return
		game.expedition_transitions.abandon(1)
		if not check(not game.participation.active(),"explicit abandonment still works"): return
		game.return_to_main_menu()
		if not check(current_scene!=game and current_scene.continue_button.text=="Continue","ended run cannot be replayed"): return
	print("verified ",phase)
	quit()
