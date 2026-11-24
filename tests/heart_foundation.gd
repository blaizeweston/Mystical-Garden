extends SceneTree
## Upgrade a real pre-HG01 Garden and verify the committed projection on disk.
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Heart foundation: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/hg01-" + str(Time.get_ticks_usec()) + ".cfg"
	game.local_character.path = game.progress.path + ".character"
	root.add_child(game)
	game.set_physics_process(false)
	var g = game.progress
	var h = g.heart
	game.players[1].pos = game.Stage.HEART
	game.garden_action(1, "research")
	check(not g.flowering_unlocked, "opening research does not auto-select the free node")
	game.garden_action(1, "heart_start_irrigation")
	game.garden_action(1, "heart_start_cultivation_grounds")
	game.garden_action(1, "heart_start_invalid")
	check(h.unlocked == ["heart"] and h.spent == 0, "missing prerequisites, lifetime Knowledge and invalid IDs refused")
	g.knowledge = 8
	game.garden_action(1, "heart_start_cultivation_grounds")
	game.garden_action(1, "heart_start_cultivation_grounds")
	check(h.has("cultivation_grounds") and h.spent == 4 and h.available_insight(g) == 4 and g.knowledge == 8 and g.plots.size()==3, "one debit and build permission")
	g.knowledge = 8
	h.spent = 7
	game.garden_action(1, "heart_start_clearing_1")
	check(not h.has("clearing_1") and h.spent == 7, "insufficient spendable Knowledge refused")
	game.garden_action(1, "heart_start_flowering")
	check(g.flowering_unlocked and h.spent == 7, "selected free Flowering immediately usable")
	var old_layout: Dictionary = game.stage.experimental_garden._capture_development()
	old_layout.version = 1
	old_layout.buildings=[]
	old_layout.next_id=5
	for id: int in g.structures.instances:
		var e: Dictionary=g.structures.instances[id]
		if e.placed: old_layout.buildings.append([id,e.kind,e.at,e.yaw,e.slot if e.kind=="bed" else null])
	old_layout.energy = 61
	old_layout.queue = [{"knowledge":4,"required":80,"done":79.0,"name":"first"},{"knowledge":7,"required":100,"done":0.0,"name":"second"}]
	g.knowledge = 50
	g.parts[0] = 33
	g.plots[0].species = 0
	preload("res://cultivation_growth.gd").initialize(g.plots[0])
	g.plots[0].age = 17.0
	check(g.save_garden() == OK, "save populated disposable Garden")
	var file := ConfigFile.new()
	check(file.load(g.path) == OK, "read fixture")
	file.erase_section("construction")
	file.set_value("garden_development","state",old_layout)
	file.set_value("heart","state",{"version":2,"spent":14,"unlocked":["heart","flowering","monster_studies"],"paid":["flowering","monster_studies","plot_4","clearing_1","infusion"],"active":"plot_4","work":{"plot_4":12},"offered":[]})
	var path: String = g.path + ".legacy"
	check(file.save(path) == OK, "write historical save")
	var old_bytes := FileAccess.get_file_as_bytes(path)
	var loaded = game.Progress.new()
	loaded.path = path
	for attempt in 2:
		check(loaded.load_garden() == OK, "load existing v2 record")
		check(loaded.knowledge == 61 and loaded.heart.spent == 9 and loaded.heart.available_insight(loaded)==52, "unpaid Knowledge and five-point spend refund each apply once")
		check(loaded.flowering_unlocked and loaded.heart.has("cultivation_grounds") and loaded.heart.has("clearing_1") and loaded.heart.has("monster_studies") and not loaded.heart.has("living_archive") and not loaded.heart.has("infusion"), "funded and already-owned projects survive, unbought Archive stays locked")
		check(loaded.garden_development.energy == 61 and not loaded.garden_development.has("queue") and loaded.structures.instances.size()==6 and loaded.parts[0]==33 and loaded.plots.size()==3 and loaded.plots[0].age==17.0, "no repeated energy, material debit, lost crop or changed structures")
	check(FileAccess.get_file_as_bytes(path)==old_bytes, "loading never writes conversion")
	check(loaded.save_garden()==OK and FileAccess.get_file_as_bytes(path+".pre-immediate-heart-v3.bak")==old_bytes,"first normal save backs up original bytes")
	check(loaded.load_garden()==OK and loaded.knowledge==61 and loaded.heart.spent==9 and not loaded.heart.serialize().has("paid"), "reopening modern projection cannot replay entitlements")
	# Older developer grants can have an unlocked ID without a matching debit.
	var legacy_heart := ConfigFile.new()
	legacy_heart.set_value("heart","state",{"version":2,"spent":2,"unlocked":["plot_4","infusion"],"paid":["plot_4"]})
	loaded.heart.load_state(legacy_heart,loaded)
	check(loaded.heart.spent==2 and not loaded.heart.has("infusion"), "an unfunded Infusion unlock refunds nothing")
	legacy_heart.set_value("heart","state",{"version":2,"spent":4,"paid":["plot_4","infusion","infusion"]})
	loaded.heart.load_state(legacy_heart,loaded)
	check(loaded.heart.spent==2 and loaded.knowledge==61, "ambiguous historical spending refunds only the two evidenced points")
	# HG01 layout with a moved, planted fourth bed, six paid permits and an existing Seed Cache.
	old_layout.version = 2
	old_layout.erase("queue")
	old_layout.next_id = 7
	old_layout.buildings.append([5,"bed",Vector2(-5.2,1.9),0.27,3])
	old_layout.buildings.append([6,"archive",Vector2(6.2,2.2),0.18,null])
	var plots: Array = file.get_value("garden","plots_v2").duplicate(true)
	plots.append(plots[0].duplicate(true))
	file.set_value("garden","plots_v2",plots)
	file.set_value("garden_development","state",old_layout)
	var permits := ["heart","seed_archive","monster_studies","plot_4","plot_5","plot_6","plot_7","plot_8","plot_9"]
	file.set_value("heart","state",{"version":3,"spent":27,"unlocked":permits,"offered":[]})
	loaded.path=g.path+".hg01"
	check(file.save(loaded.path)==OK,"write HG01 placement fixture")
	for step in 3:
		check(loaded.load_garden()==OK,"read HG01 or committed HG02 projection")
		var entries: Array=loaded.structures.instances.values()
		check(entries.filter(func(e):return e.kind=="bed" and e.placed).size()==4 and entries.filter(func(e):return e.kind=="bed" and not e.placed).size()==5,"six permits cover exactly one placed plus five stored beds")
		var revision: int=loaded.structures.revision
		loaded.Structures.grant_research(loaded.structures,"seed_archive")
		check(loaded.structures.revision==revision,"existing station prevents a second grant even without a research receipt")
		check(entries.filter(func(e):return e.kind=="archive").size()==1 and entries.filter(func(e):return e.kind=="study" and not e.placed).size()==1,"existing unique is retained and the unused station is granted once")
		check(loaded.structures.instances[5].at.is_equal_approx(Vector2(-5.2,1.9)) and loaded.structures.instances[5].slot==3 and loaded.plots[3].age==17 and loaded.garden_development.energy==61 and loaded.heart.spent==27 and loaded.knowledge==50,"moved crop, original debit, currencies and identity survive migration")
		check(entries.all(func(e):return e.paid.is_empty()),"historical structures have no invented receipts")
		if step==1: check(loaded.save_garden()==OK,"commit migrated inventory")
	game.free()
	if not failed: print("PASS: immediate research, accounting, multiple funded projects, layout and assimilation migration")
	quit(int(failed))
