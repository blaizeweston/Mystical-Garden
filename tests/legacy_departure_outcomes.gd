extends SceneTree
## Real ordinary writer and Windows file handles. Native authorizations run
## against canonical slot paths inside the runner's disposable user directory.
const Batch = preload("res://save_batch.gd")
const Tx = preload("res://game_transaction.gd")
const Fixture = preload("res://tests/support/expedition_case.gd")
const G := "user://saves/slot_1/garden.cfg"
const C := "user://saves/characters/slot_1/character.cfg"
var world: Node
var failed := false
var handles: Array[FileAccess] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, reason: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: ",reason)

func disk() -> Array:
	return [FileAccess.get_sha256(G),FileAccess.get_sha256(C)]

func read(path: String, section: String, key: String) -> Variant:
	var config := ConfigFile.new()
	if config.load(path) != OK: return null
	return config.get_value(section,key)

func lock(path: String, mode: FileAccess.ModeFlags) -> void:
	var held := FileAccess.open(path,mode)
	check(held != null,"opened disposable lock " + path)
	if held != null: handles.append(held)

func unlock() -> void:
	for held in handles: held.close()
	handles.clear()

func open_world() -> void:
	world = load("res://world.tscn").instantiate()
	world.progress.path = G
	world.local_character.path = C
	world.guest_character.path = "user://release-fixtures/unused-guest.cfg"
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.set_physics_process(false)
	check(not world.persistence_session.is_guarded(),"ordinary save route")

func enter(peer: int) -> void:
	var actor: Dictionary = world.players[peer]
	Fixture.set_membership(world,actor,true)
	var run_id: int = world.participation.run_id()
	var identity: String = world.expedition_stat_identity(peer)
	world.monster_rewards.begin_expedition(identity,run_id,actor.character.xp,actor.character.monsters)
	world.expedition_statistics.admit(run_id,identity,"Guest" if peer != 1 else "Host","Warden",1,0)

func departure(fault: String) -> Dictionary:
	return Tx.run_gameplay(world,Tx.Scope.PAIR,func():
		world.progress.knowledge += 7
		# Replace the Garden first, then fail the character replacement.
		world.progress.save_garden()
		if fault in ["cleanup","uncertain"]: lock(G+".recovery",FileAccess.WRITE)
		if fault in ["rollback","uncertain"]: lock(C,FileAccess.READ)
		return world.expedition_transitions.finish_voluntary())

func confirms(result: Dictionary, outcome: Batch.Outcome) -> bool:
	var execution: Variant = result.persistence.get("value")
	return execution is Dictionary and execution.outcome.outcome == outcome

func restart(expect_commit: bool, expected: Array) -> void:
	# A fresh OS process inherits only the disposable data root and the
	# expected hashes. It has no live world, receipts or Finalization.
	var output := []
	var arguments := PackedStringArray(["--headless"])
	var pack := OS.get_environment("MYSTICAL_VALIDATION_PACK")
	if pack.is_empty():
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/legacy_departure_outcomes.gd"])
	else:
		var driver: String = get_script().resource_path
		check(FileAccess.file_exists(pack) and driver.is_absolute_path(), "restart uses the exact tested package and external driver")
		if failed: return
		arguments.append_array(["--path", driver.get_base_dir(), "--main-pack", pack, "--script", driver])
	arguments.append_array(["--","recover",str(expect_commit),expected[0],expected[1]])
	var code := OS.execute(OS.get_executable_path(),arguments,output,true)
	var transcript := "".join(output)
	check(code == 0 and transcript.contains("Recovered original journal") and not transcript.contains("ERROR:"),"independent recovery process: " + transcript)

func run() -> void:
	if OS.get_environment("MYSTICAL_VALIDATION_RUN").is_empty() or not OS.get_user_data_dir().replace("\\","/").contains("/.godot/vd/"):
		printerr("Disposable save root required"); quit(1); return
	var args := OS.get_cmdline_user_args()
	if args.size() == 4 and args[0] == "recover":
		check(read(G+".transaction","transaction","committed") == (args[1]=="true"),"original marker in new process")
		check(Batch.recover(G)==OK and not FileAccess.file_exists(G+".transaction"),"restart reconciles journal")
		check(disk()==[args[2],args[3]],"recovery preserves expected canonical bytes")
		if not failed: print("Recovered original journal")
		# Only the parent writes the runner verdict. It checks this process's output and exit.
		super.quit(int(failed)); return
	for path in [G,C]: DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	open_world()
	var player: Dictionary = world.players[1]
	enter(1)
	var initial_xp: Array = player.character.xp.duplicate()
	var initial_monsters: Array = player.character.monsters.duplicate()
	player.character.xp[0] += 35
	player.character.monsters[0] += 2
	world.grant_run_essence(1,player,15)
	world.progress.knowledge = 12
	var saved := Tx.run_gameplay(world,Tx.Scope.PAIR,func(): return true)
	check(confirms(saved,Batch.Outcome.COMMITTED) and not FileAccess.file_exists(G+".transaction"),"ordinary clean commit")
	var before := disk()
	saved = departure("rollback")
	check(confirms(saved,Batch.Outcome.ABORTED_RESTORED) and not saved.completed and disk()==before,"both canonical files restored after first replacement")
	check(world.participation.contains(1) and player.character.xp[0]==initial_xp[0]+35 and player.character.monsters[0]==initial_monsters[0]+2 and world.progress.knowledge==12 and player[world.ExpeditionWallet.STATE].earned_sparks()==15,"rollback restores participation, XP, familiarity, wallet and Knowledge")
	check(world.ui.visible_expedition_result().is_empty() and world.persistence_session.can_write(),"rollback hides tentative summary and permits retry")
	unlock()
	saved = departure("cleanup")
	var committed := disk()
	var report: Dictionary = world.ui.visible_expedition_result()
	check(confirms(saved,Batch.Outcome.COMMITTED_CLEANUP_PENDING) and saved.completed and saved.value and saved.notice==Tx.CLEANUP_NOTICE,"locked cleanup is a committed departure")
	check(read(G+".transaction","transaction","committed")==true and read(G,"garden","knowledge")==19 and read(C,"character","progress").xp==initial_xp,"commit marker and committed Garden/profile")
	check(not world.participation.active() and report.get("outcome")=="Abandonment" and player.character.monsters==initial_monsters and player[world.ExpeditionWallet.STATE].earned_sparks()==0,"final participation, reward state and unread summary")
	check(not world.persistence_session.can_write() and not world.recover_departure_cleanup(),"held file prevents release")
	check(world.expedition_transitions.finish_voluntary() and not departure("retry").completed and world.progress.knowledge==19 and disk()==committed and world.ui.visible_expedition_result()==report,"duplicate exit and settlement cannot replay")
	world.return_to_main_menu()
	await process_frame
	check(current_scene != null and current_scene.get_node_or_null("ExpeditionResults") != null,"unread summary survives ordinary title return under cleanup hold")
	unlock()
	restart(true,committed)
	current_scene.free()
	open_world()
	enter(1)
	world.players[1].character.xp[0] += 12
	Tx.run_gameplay(world,Tx.Scope.PAIR,func(): return true)
	before = disk()
	saved = departure("uncertain")
	check(confirms(saved,Batch.Outcome.UNCERTAIN) and not saved.completed and not world.persistence_session.can_write(),"failed compensation is uncertain")
	check(disk()!=before and read(G+".transaction","transaction","committed")==false,"partial installation retains rollback evidence")
	check(not world.participation.contains(1) and world.ui.visible_expedition_result().is_empty() and world.persistence_session.pending_notice().contains("uncertain"),"uncertainty neither rewinds nor publishes success")
	var split := disk()
	check(not departure("retry").completed and disk()==split and not world.recover_departure_cleanup(),"uncertain settlement cannot replay or use commit-only cleanup")
	unlock()
	world.free()
	restart(false,before)
	open_world()
	saved = Tx.run_gameplay(world,Tx.Scope.PAIR,func():
		lock(G+".recovery",FileAccess.WRITE)
		return false)
	check(confirms(saved,Batch.Outcome.COMMITTED_CLEANUP_PENDING) and saved.completed and saved.value==false,"business refusal is independent of a committed write")
	committed = disk()
	unlock()
	check(world.recover_departure_cleanup() and disk()==committed and world.persistence_session.can_write(),"canonical in-place cleanup preserves both byte images")
	enter(1)
	check(world.expedition_transitions.finish_voluntary() and world.ui.visible_expedition_result().get("outcome")=="Abandonment" and not FileAccess.file_exists(G+".transaction"),"ordinary clean departure publishes one result")
	world.free()
	if not failed: print("PASS: legacy departure durability, rollback, cleanup, uncertainty, reports and restart recovery")
	quit(int(failed))
