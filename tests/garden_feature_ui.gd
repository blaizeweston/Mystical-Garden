extends SceneTree
## Real feature controls run without Game, a player registry or persistence access.
const Shell = preload("res://ui/gameplay/gameplay_ui.tscn")
const Grafts = preload("res://expedition_grafts.gd")
const Items = preload("res://item_catalog.gd")
var failed := false
var requests: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Garden feature UI: ", message)

func run() -> void:
	var ui = Shell.instantiate()
	root.add_child(ui)
	ui.requested.connect(func(command: String, data: Dictionary):
		requests.append({"command":command,"data":data.duplicate(true)}))
	var graft = load("res://affinity_grafting_panel.gd").new()
	var altar = load("res://garden_altar_panel.gd").new()
	var planting = load("res://planting_panel.gd").new()
	ui.mount_feature("graft",graft)
	ui.mount_feature("altar",altar)
	ui.mount_feature("planting",planting)
	await process_frame

	var trophy := {"id":"monster_0","cost":1,"name":"Trophy","carried":2}
	var offer := {"run":19,"floor":8,"revision":4,"remaining":6,"limit":6,"used":false,
		"status":"Choose one improvement.","materials":[trophy],"options":[
			{"id":"strike","name":"Offensive reinforcement","unique":false,"count":0,
			"text":"Strengthens basic attacks.","detail":"Costs one carried trophy.","values":"+2 damage","reason":""}]}
	var original := JSON.stringify(offer)
	ui.show_graft(offer)
	graft.selected="strike"
	graft.trophy="monster_0"
	graft.show_selection()
	check(not graft.confirm.disabled and "Trophy" in graft.confirm.text,"graft choices render an explicit payable trophy")
	graft.confirm.pressed.emit()
	var action: String = requests.back().data.action
	var decoded := Grafts.decode_request(action)
	check(requests.back().command=="garden_action" and int(decoded.get("run",-1))==19
		and int(decoded.get("floor",-1))==8 and int(decoded.get("revision",-1))==4
		and decoded.get("id")=="strike" and decoded.get("item")=="monster_0",
		"graft intent preserves the displayed run, floor, revision and selected material: "+str(decoded))
	check(JSON.stringify(offer)==original and graft.busy,"a pending purchase cannot spend the supplied snapshot")
	var count := requests.size()
	graft.send_purchase()
	check(requests.size()==count,"a pending purchase is not submitted twice")
	offer.materials[0].carried=0
	check(graft.data.materials[0].carried==2,"graft presentation is detached from the caller's data")
	ui.present_world_access("graft",false)
	check(not ui.is_overlay_open(),"world eligibility closes a graft screen after leaving its Altar")

	var seed := Items.seed_id(0)
	var facts := {"revision":0,"draft":[{},{}],"recipes":[],"unknown":1,
		"species_known":1,"species_total":24,"stash":[{"item":seed,"quantity":2}],"shared":[],
		"preview":{"known":false,"can_combine":false,"text":"Choose ingredients."},"message":"Ready"}
	ui.show_altar(facts)
	check(altar.grid.get_child_count()==28,"Altar renders its inventory without a world reference")
	facts.stash[0].quantity=9
	check(altar.available(seed,"stash")==2,"Altar inventory projection is detached")
	altar.move_stack("offering_0",{"type":"garden_item_stack","source":"stash","item":seed})
	check(requests.back().command=="altar_action" and requests.back().data.operation=="preview"
		and requests.back().data.revision==1 and requests.back().data.draft[0].item==seed,
		"dragging reserves an ingredient through a revision-bound preview request")
	check(altar.available(seed,"stash")==1 and altar.data.stash[0].quantity==2,
		"a draft reserves display availability without debiting inventory")
	var reply: Dictionary = altar.data.duplicate(true)
	reply.revision=1
	reply.draft=altar.draft.duplicate(true)
	reply.preview.can_combine=true
	ui.update_altar(reply)
	reply.draft[0].item="unidentified_seed"
	check(altar.draft[0].item==seed,"accepted preview drafts are detached")
	altar.combine_button.pressed.emit()
	check(requests.back().data.operation=="combine" and requests.back().data.revision==2
		and altar.busy and altar.combine_button.disabled,"confirmation submits one revisioned operation and awaits authority")
	count=requests.size()
	altar.request("combine")
	check(requests.size()==count,"the Altar cannot resubmit while awaiting a mutation result")
	ui.update_altar({"revision":1,"draft":[{},{}]})
	check(altar.revision==2 and altar.busy and altar.draft[0].item==seed,"an older reply cannot replace the current request")
	ui.present_world_access("graft",false)
	check(ui.panel_is_open("altar"),"one feature's eligibility cannot close another feature")
	ui.present_world_access("altar",false)
	check(not ui.is_overlay_open(),"Altar access is determined outside the view")

	var stock := [2,0,1]
	var shared := [1,0,0]
	ui.show_planting(2,stock,true,shared)
	stock[0]=8
	shared[0]=9
	check(planting.grid.get_child_count()==2 and planting.counts[0]==2 and planting.communal[0]==1,"planting has one choice per available species and detached personal/shared counts")
	planting.grid.get_child(0).pressed.emit()
	check(not planting.confirm.disabled and "Base growth " in planting.details.text and "Personal 2 · Shared 1" in planting.details.text,"a selected seed shows current authored cultivation details and both source quantities")
	check(planting.source_pick.item_count==2 and planting.source_pick.get_selected_metadata()=="shared","shared and personal seeds can be selected explicitly")
	ui.present_planting_access(false)
	count=requests.size()
	planting.confirm.pressed.emit()
	check(requests.size()==count and planting.confirm.disabled,"a save hold prevents planting requests without exposing the persistence owner")
	ui.present_planting_access(true)
	planting.confirm.pressed.emit()
	check(requests.back()=={"command":"garden_action","data":{"action":"plant_at_2_0_shared"}},"planting submits the chosen bed, species and shared source without granting a crop")
	planting.source_pick.select(1)
	planting.confirm.pressed.emit()
	check(requests.back()=={"command":"garden_action","data":{"action":"plant_at_2_0_stash"}},"personal planting submits the explicit personal source")
	check(planting.counts[0]==2 and planting.communal[0]==1,"a planting intent cannot spend a seed")
	var cancel: Button = planting.find_children("*","Button",true,false).filter(func(button): return button.text=="Cancel · Esc")[0]
	count=requests.size()
	cancel.pressed.emit()
	check(not ui.is_overlay_open() and requests.size()==count,"Cancel closes the shell without sending a domain command")
	ui.show_planting(3,[1],false)
	ui.show_planting(3,[1],false)
	count=requests.size()
	planting.grid.get_child(0).pressed.emit()
	planting.confirm.pressed.emit()
	check(requests.size()==count and planting.grid.get_child(0).disabled and planting.confirm.disabled,
		"reopening a blocked picker cannot bypass its supplied save hold")
	ui.free()
	await process_frame
	if not failed: print("PASS: standalone Garden Altar, graft and planting views; detached inventory/quotes; revision-bound intents; save holds; close and proximity lifecycle")
	quit(1 if failed else 0)
