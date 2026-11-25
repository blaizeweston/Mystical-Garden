extends SceneTree
const TuningCase = preload("res://tests/support/dev03_tuning_case.gd")
const Developer = preload("res://developer_mode.gd")

func _initialize() -> void:
	call_deferred("run")

static func isolated() -> bool:
	var data := OS.get_user_data_dir().replace("\\","/").simplify_path()
	var fixtures := ProjectSettings.globalize_path("res://.godot/vd/").replace("\\","/").simplify_path().trim_suffix("/") + "/"
	return DisplayServer.get_name() == "headless" and data.begins_with(fixtures) and OS.get_environment("MYSTICAL_VALIDATION_FIXTURE") == "dev02_lifecycle"

func check(ok: bool, reason: String) -> bool:
	if not ok:
		printerr("FAIL DEV02 ",reason)
		quit(1)
	return ok

func run() -> void:
	if not check(isolated(),"requires disposable project validation storage"): return
	var args := OS.get_cmdline_user_args()
	if args.size() == 0:
		var token := Crypto.new().generate_random_bytes(8).hex_encode()
		for phase in ["write","resume","guarded"]:
			if phase=="guarded":
				var isolated_root:=ProjectSettings.globalize_path("res://.godot/vd/g-"+token)
				if not check(not DirAccess.dir_exists_absolute(isolated_root) and DirAccess.make_dir_recursive_absolute(isolated_root)==OK,"fresh guarded directory"): return
				for key in ["APPDATA","LOCALAPPDATA","XDG_DATA_HOME"]: OS.set_environment(key,isolated_root)
			var output := []
			var code := OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/dev02_lifecycle.gd","--quit-after","650","--",token,phase]),output,true)
			var log_text := "\n".join(output)
			if not check(code == 0 and "verified "+phase in log_text and not "ERROR:" in log_text,log_text): return
		print("PASS: isolated Developer Garden, arena controls and build rebuild, live tuning, preset restart, extraction and reset")
		quit()
		return
	if not check(args.size()==2 and args[0].length()==16 and args[0].is_valid_hex_number(),"fixture token"): return
	var menu: Node = load("res://main_menu.tscn").instantiate()
	var base := "user://release-fixtures/dev02-"+args[0]
	if args[1]=="guarded":
		await guarded_round_trip(menu,args[0])
		return
	menu.storage.root_path = base
	menu.settings_path = base.path_join("settings.cfg")
	menu.import_legacy = false
	menu.restore_last_selection = false
	root.add_child(menu)
	current_scene = menu
	var manifest := base.path_join("ordinary.cfg")
	var hashes := ConfigFile.new()
	if args[1] == "write":
		if not check(menu.storage.new_world(1)==OK and menu.characters.create(1,"Keeper",1,[])==OK,"ordinary controls"): return
		for path in [menu.storage.paths(1).garden,menu.characters.paths(1).character]:
			hashes.set_value("ordinary",path,FileAccess.get_sha256(path))
		if not check(hashes.save(manifest)==OK,"canary"): return
	elif not check(args[1]=="resume" and hashes.load(manifest)==OK,"manifest"): return
	menu.app_settings.values.developer_mode = true
	menu.app_settings.save_settings(menu.app_settings.values)
	if not check(Developer.open_garden(menu,false)==OK,"developer launch"): return
	var garden := current_scene
	var actor: Dictionary = garden.players[1]
	if args[1]=="write":
		var setup: String=TuningCase.garden(garden)
		if not check(setup.is_empty(),setup): return
		setup=TuningCase.coverage(garden)
		if not check(setup.is_empty(),setup): return
		var g: String = FileAccess.get_sha256(garden.progress.path)
		var c: String = FileAccess.get_sha256(garden.local_character.path)
		if not check(Developer.enter_arena(garden),"practice launch"): return
		var session := garden.get_node("TestingArena")
		if not check(not Developer.can_edit(garden),"parked Garden rejects resource commands"): return
		var arena: Node = session.combat
		if not check(arena.is_practice_world() and arena.participation.active() and not arena.persistence_session.can_write(),"practice authority"): return
		if not check(arena.workbench.editor.options.item_count>0,"unfiltered list shows eligible upgrades"): return
		var start:=InputEventJoypadButton.new()
		start.button_index=JOY_BUTTON_START
		start.pressed=true
		arena._input(start)
		if not check(not arena.workbench.opened,"controller closes workbench"): return
		arena._input(start)
		if not check(arena.workbench.opened and arena.workbench.tabs.get_tab_count()==6,"controller opens combat and tuning panels"): return
		if not check(arena.session_world.host()==ERR_UNAVAILABLE and arena.session_world.join("127.0.0.1")==ERR_UNAVAILABLE,"practice offline"): return
		var tuning_error: String=TuningCase.arena(arena)
		if not check(tuning_error.is_empty(),tuning_error): return
		session.rebuild()
		await process_frame
		await process_frame
		arena=session.combat
		var combat_error: String = preload("res://tests/support/dev02_combat_case.gd").verify(arena)
		if not check(combat_error.is_empty(),combat_error): return
		session.rebuild()
		await process_frame
		await process_frame
		if not check(not is_instance_valid(arena) and session.combat.is_practice_world(),"fresh round"): return
		var build_error: String=await preload("res://tests/support/dev02_build_case.gd").verify(session)
		if not check(build_error.is_empty(),build_error): return
		session.close()
		await process_frame
		await process_frame
		if not check(current_scene==garden and not garden.participation.active() and FileAccess.get_sha256(garden.progress.path)==g and FileAccess.get_sha256(garden.local_character.path)==c,"arena round trip leaves files intact"): return
		actor.pos = garden.Stage.HEART
		garden.handle_loadout_action(1,actor,"learn_0_64")
		actor.pos = garden.stage.gate_position()
		garden.expedition_transitions.enter(1)
		if not check(garden.participation.contains(1) and not Developer.enter_arena(garden),"active run protected"): return
		var wild_error:=TuningCase.wild(garden)
		if not check(wild_error.is_empty(),wild_error): return
		garden.save_and_quit(false)
		if not check(current_scene!=garden and garden.expedition_saved_for_exit,"suspend"): return
	else:
		if not check(garden.participation.contains(1) and garden.progress.suspended_expedition.is_empty(),"restart resumes the developer's actual run"): return
		var resumed:=TuningCase.restarted(garden)
		if not check(resumed.is_empty(),resumed): return
		var counters: Dictionary = garden.progress.archive.garden.duplicate(true)
		garden.encounter.clear_scouts()
		garden.encounter.set_hp(-1,0)
		garden.encounter_rewarded = true
		while garden.participation.floor() % garden.EXTRACTION_INTERVAL != 0:
			garden.participation.advance(garden.participation.epoch(),garden.ROUTE_ROOMS-1)
			garden.participation.begin_floor(0)
		actor.pos = garden.battlefield.advance
		garden.expedition_transitions.checkpoint(1,false)
		if not check(not garden.participation.active() and garden.progress.archive.garden!=counters,"developer extraction and archive"): return
		garden.return_to_main_menu()
		var title := current_scene
		title.app_settings.values.developer_mode = true
		if not check(Developer.open_garden(title,true)==OK and current_scene.progress.archive.garden!=garden.progress.archive.garden,"developer reset"): return
		current_scene.return_to_main_menu()
	for path in hashes.get_section_keys("ordinary"):
		if not check(FileAccess.get_sha256(path)==hashes.get_value("ordinary",path),"ordinary save changed"): return
	print("verified ",args[1])
	quit()

func guarded_round_trip(menu: Node, token: String) -> void:
	var expected:=ProjectSettings.globalize_path("res://.godot/vd/g-"+token).replace("\\","/").simplify_path()+"/"
	if not check(OS.get_user_data_dir().replace("\\","/").simplify_path().begins_with(expected),"guarded canonical paths require the new disposable profile"): return
	menu.guarded_persistence=true
	menu.import_legacy=false
	menu.restore_last_selection=false
	root.add_child(menu)
	current_scene=menu
	menu.app_settings.values.developer_mode=true
	if not check(menu.app_settings.save_settings(menu.app_settings.values)==OK and Developer.open_garden(menu,false)==OK,"guarded developer launch"): return
	var garden:=current_scene
	var before: String=FileAccess.get_sha256(garden.progress.path)
	if not check(garden.persistence_session.owns_leases() and Developer.enter_arena(garden),"guarded arena entry"): return
	var session:=garden.get_node("TestingArena")
	session._process(1.0)
	session.close()
	await process_frame
	await process_frame
	if not check(garden==current_scene and garden.persistence_session.owns_leases() and before==FileAccess.get_sha256(garden.progress.path),"guarded lease and Garden retained"): return
	garden.return_to_main_menu()
	await process_frame
	print("verified guarded")
	quit()
