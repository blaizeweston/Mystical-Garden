extends SceneTree
const Classes = preload("res://class_catalog.gd")
const Character = preload("res://character_profile.gd")
const Seeds = preload("res://seed_catalog.gd")
const ViewFacts = preload("res://ui/gameplay/player_build_projection.gd")
var failed := false
var requests: Array = []
var refreshes: Array = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL progression UI: ",message)

func _initialize() -> void:
	call_deferred("run")

func facts_for(profile: Dictionary, class_id: int = 0) -> Dictionary:
	var known := Seeds.counts(false)
	known[0]=true
	var parts := Seeds.counts()
	parts[0]=2
	return {"class_id":class_id,"profile":ViewFacts.progression_profile(profile),
		"known_seeds":known,"seed_stock":Seeds.counts(),"shared_parts":parts,
		"heart":{"unlocked":["heart"],"insight":4},
		"knowledge":4,"memories":[0,0,0],
		"at_altar":true,"may_learn":true,"may_respec":true,"is_host":true,
		"may_start_research":true,"research_refusal":"","stories":{},"notice":""}

func run() -> void:
	# The complete view and its stories child run without a world, actor or save owner.
	var panel = load("res://progression_panel.gd").new()
	panel.refresh_requested.connect(func(selection): refreshes.append(selection.duplicate(true)))
	panel.requested.connect(func(command, data): requests.append({"command":command,"data":data.duplicate(true)}))
	root.add_child(panel)
	panel.set_process(false)
	var profile := Character.blank()
	var facts := facts_for(profile)
	panel.present(facts)
	check(panel.tabs.tab_count==4 and panel.nodes.size()==Seeds.DEFINITIONS.size(),"four tabs and the complete canonical seed lineage render independently")
	check(panel.tree.node_at("0").icon is Texture2D and panel.tree.node_at("1").icon==null,"only discovered seeds reveal their portraits")
	panel.select_node("0")
	panel.present(facts)
	check("Growth:" in panel.details.text and "Thorn Bloom" in panel.details.text,"selection retains the actual discovered-seed detail")
	facts.known_seeds[0]=false
	check(panel.known_flags()[0],"caller changes cannot mutate retained discovery facts")
	var detached: Array=panel.known_flags()
	detached[0]=false
	check(panel.known_flags()[0],"returned seed arrays cannot mutate the view model")

	for class_id in Classes.DEFINITIONS.size():
		profile=Character.blank()
		facts=facts_for(profile,class_id)
		panel.tabs.current_tab=2
		panel.change_tab(2)
		panel.present(facts)
		var connected = Classes.connected_tree(class_id)
		check(panel.inspected_class==class_id and panel.nodes.size()==connected.nodes.size()+1,"the class tab adopts the current class and shows every connected node")
		var first := "class_%d_%d"%[class_id,connected.REQUEST_OFFSET]
		panel.select_node(first)
		panel.present(facts)
		check(not panel.learn_button.disabled and "cooldown" in str(panel.tree.node_at(first).summary).to_lower(),"an unplayed class has a meaningful, free native focus preview")
		var prior := JSON.stringify(profile)
		panel.learn_button.pressed.emit()
		check(requests.back()=={"command":"garden_action","data":{"action":"learn_%d_%d"%[class_id,connected.REQUEST_OFFSET]}},"learning emits the existing host-validated command")
		check(JSON.stringify(profile)==prior and connected.focus(profile).is_empty(),"clicking a focus cannot award progression")
		profile[connected.profile_key]=connected.state([connected.nodes[0].id])
		facts=facts_for(profile,class_id)
		panel.present(facts)
		check(panel.tree.node_at(first).unlocked,"accepted domain progression is reflected on the chosen path")
		for i in connected.nodes.size():
			var node: Dictionary=connected.nodes[i]
			var drawn: Dictionary=panel.tree.node_at("class_%d_%d"%[class_id,connected.REQUEST_OFFSET+i])
			check(drawn.parents.size()==maxi(1,node.parents.size()),"displayed graph preserves canonical prerequisite connections")
		panel.refund_button.pressed.emit()
		check(requests.back().data.action=="respec_%d"%class_id,"refund remains an explicit existing domain command")
		var other := (class_id+1)%Classes.DEFINITIONS.size()
		panel.class_pick.item_selected.emit(other)
		panel.present(facts)
		check(panel.inspected_class==other,"ordinary refresh preserves an explicitly inspected class")
		panel.open_from_crafting()
		panel.present(facts)
		check(panel.inspected_class==class_id and requests.back().command=="open_progression","crafting entry requests its frame and returns inspection to the active class")
		panel.close_button.pressed.emit()
		check(requests.back()=={"command":"close_progression","data":{"from_crafting":true}},"close supplies an intention; the root decides live crafting eligibility")

	panel.tabs.current_tab=1
	facts=facts_for(Character.blank())
	panel.chosen="heart_cultivation_grounds"
	panel.present(facts)
	check(not panel.heart_start_button.disabled,"host can purchase useful research")
	panel.heart_start_button.pressed.emit()
	check(requests.back().data.action=="heart_start_cultivation_grounds","research submits only the selected identity")
	facts.is_host=false
	facts.may_start_research=false
	panel.present(facts)
	var count := requests.size()
	panel.heart_start_button.pressed.emit()
	check(panel.heart_start_button.disabled and requests.size()==count,"a guest cannot issue a host research-start command")

	panel.tabs.current_tab=3
	var entries: Array=[]
	for i in 15: entries.append({"name":"Discovery %d"%i,"description":"A returned seed","hint":"Look by the Heart"})
	facts.stories={"entries":entries}
	panel.present(facts)
	check(panel.care.visible and "Discovery 14" in panel.care.stories.text and "Discovery 0\n" not in panel.care.stories.text,"the story child renders only the latest twelve supplied discoveries")
	entries[14].name="Caller mutation"
	check("Caller mutation" not in panel.care.stories.text,"story text is not linked to caller-owned state")
	check(refreshes.any(func(s):return s.tab==2) and refreshes.any(func(s):return s.chosen=="heart_cultivation_grounds"),"refresh requests contain only the current display selection")

	# Let the existing deferred, version-checked scrollbar work finish before teardown.
	for frame in 5: await process_frame
	panel.queue_free()
	await process_frame
	if not failed: print("PASS: detached seeds, research, all five class trees, stories, explicit commands and one shared offering planner without Game")
	quit(1 if failed else 0)
