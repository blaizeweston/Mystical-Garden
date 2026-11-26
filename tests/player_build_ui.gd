extends SceneTree
const Classes = preload("res://class_catalog.gd")
const Character = preload("res://character_profile.gd")
const Parts = preload("res://weapon_parts.gd")
const Items = preload("res://item_catalog.gd")
const Build = preload("res://affinity_build.gd")
const ViewFacts = preload("res://ui/gameplay/player_build_projection.gd")
var failed := false
var requests: Array = []
var refreshes := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL player build UI: ",message)

func _initialize() -> void:
	call_deferred("run")

func connect_view(view: Control) -> void:
	view.refresh_requested.connect(func(): refreshes+=1)
	view.requested.connect(func(command: String, data: Dictionary): requests.append({"command":command,"data":data.duplicate(true)}))
	root.add_child(view)

func loadout_facts(class_id: int, profile: Dictionary) -> Dictionary:
	var build := Build.resolve(class_id,0,[0,0,0],profile)
	return {"class_id":class_id,"weapon_kind":0,"prepared":true,"counts":Parts.empty_counts(),
		"equipment":[0,0,0],"cargo":Parts.empty_counts(),"profile":ViewFacts.class_profile(profile,class_id),
		"stats":Build.native_stats(build),"card_totals":{},"at_gate":true,"class_allowed":true,
		"cargo_limit":6,"party_size":1,"travel":{},"notice":""}

func run() -> void:
	# These real panels have no Game/World, player registry or save owner.
	var inventory = load("res://inventory_panel.gd").new()
	connect_view(inventory)
	var profile := Character.blank()
	var facts := {"wild":false,"carry":[],"pouch":[],"equipment":[0,0,0],
		"stash":[{"item":Items.seed_id(0),"quantity":2,"bucket":"stash","key":"stash|seed|0"}],"shared":[],
		"affinity_build":Build.resolve(0,0,[0,0,0],profile),"notice":"fixture notice"}
	var original := JSON.stringify(facts)
	inventory.present(facts)
	check(inventory.grid.get_child_count()==40 and inventory.heading.text=="Garden inventory","standalone inventory renders the real storage controls")
	inventory.select_all.pressed.emit()
	inventory.transfer_button.pressed.emit()
	check(requests.back()=={"command":"inventory_transfer","data":{"source":"stash","target":"shared","item":Items.seed_id(0),"quantity":2}},"transfer produces only a scoped request")
	check(JSON.stringify(facts)==original and inventory.shown[0].quantity==2,"a request cannot debit the supplied inventory snapshot")
	facts.stash[0].quantity=9
	check(inventory.state.stash[0].quantity==2,"inventory retains a detached display model")
	var before := requests.size()
	inventory.move_stack("stash",{"type":"garden_item_stack","source":"stash","item":Items.seed_id(0),"quantity":2,"key":"stash|seed|0"})
	check(requests.size()==before,"same-bucket visual ordering does not submit an inventory transaction")

	var loadout = load("res://loadout_panel.gd").new()
	connect_view(loadout)
	for class_id in Classes.DEFINITIONS.size():
		profile=Character.blank()
		var data := loadout_facts(class_id,profile)
		loadout.present(data)
		check(loadout.focus_options.visible and loadout.depart_button.disabled
			and loadout.focus_previews.all(func(label): return "cooldown" in label.text)
			and loadout.focus_buttons.all(func(button): return button.tooltip_text.length()>30),
			"zero-XP %s describes every native starting focus"%Classes.DEFINITIONS[class_id].name)
		loadout.focus_buttons[1].pressed.emit()
		check(requests.back()=={"command":"garden_action","data":{"action":"learn_%d_%d"%[class_id,Classes.ConnectedTree.REQUEST_OFFSET+1]}},"focus selection requests the existing host command")
		check(Classes.connected_tree(class_id).focus(profile).is_empty() and loadout.depart_button.disabled,"focus intent cannot grant itself progression")
		var tree = Classes.connected_tree(class_id)
		profile[tree.profile_key]=tree.state([tree.nodes[1].id])
		data=loadout_facts(class_id,profile)
		loadout.present(data)
		check(not loadout.focus_options.visible and not loadout.depart_button.disabled,"an accepted focus enables native empty-slot departure")
		loadout.depart_button.pressed.emit()
		check(requests.back().command=="depart","departure is requested without changing a participant record")
	var data := loadout_facts(0,profile)
	data.counts[1]=2
	loadout.present(data)
	loadout.select_part(0,1)
	loadout.present(data)
	check(loadout.displayed_parts[0]==1 and data.equipment==[0,0,0] and data.counts[1]==2,"optimistic equipment feedback does not equip or consume anything")
	loadout.pending_until=0
	loadout.present(data)
	check(loadout.displayed_parts==[0,0,0],"an unconfirmed equipment choice expires back to the owner projection")

	var summary = load("res://run_summary_panel.gd").new()
	connect_view(summary)
	var stats: Dictionary = Build.native_stats(Build.resolve(0,0,[0,0,0],profile))
	stats.affinity_build=Build.resolve(0,0,[0,0,0],profile)
	var summary_facts := {"active":true,"stats":stats,"class_id":0,"weapon_kind":0,
		"base_hp":100,"max_hp":80,"dodge_ms":850,"copies":[],"grafts":{},"kill_heal_limit":24,
		"skills":[preload("res://skill_catalog.gd").resolve(0,0,profile),preload("res://skill_catalog.gd").resolve(0,1,profile)]}
	summary.present(summary_facts)
	var shown: Dictionary = summary.shown.duplicate(true)
	check(shown.totals.any(func(row): return row[0]=="Attack speed" and "attacks/sec" in row[1])
		and shown.totals.any(func(row):return row[0]=="Max HP" and row[1].begins_with("80 HP")),"standalone Tab view resolves supplied combat facts")
	summary_facts.stats.interval=1
	check(summary.shown==shown,"later caller mutations cannot change displayed stats")
	summary.close_button.pressed.emit()
	check(requests.back().command=="close","closing a panel has no domain side effects")
	check(refreshes>0,"panel reads are explicit refresh requests")
	for panel in [inventory,loadout,summary]: panel.free()
	await process_frame
	if not failed: print("PASS: standalone inventory, five-class focus/loadout, accepted-vs-requested equipment and detached Tab stats without Game")
	quit(1 if failed else 0)
