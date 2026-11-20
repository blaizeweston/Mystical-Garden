extends SceneTree
const UI = preload("res://ui/gameplay/gameplay_ui.tscn")
var failed := false
var requests: Array = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL gameplay UI: ",message)

func _initialize() -> void:
	call_deferred("run")

func control(ui: Node, name: String) -> Variant:
	return ui.find_child(name,true,false)

func offer(revision: int) -> Dictionary:
	var choices: Array = []
	for i in 3:
		choices.append({"title":"Fixture upgrade "+str(i),"scope":"Weapon","unique":false,
			"rarity":"Common","description":"Increases basic attack speed.","preview":"Attack speed: 1.00 → 1.04 attacks/sec",
			"detail":"Each acquired copy retains its contribution.","choice":i,"enabled":true})
	return {"revision":revision,"choices":choices,"closed":false,"exhausted":false,
		"acquired":0,"limit":30,"reroll_cost":2,"reroll_enabled":true,"reroll_reason":""}

func run() -> void:
	# A standalone scene has no Game, actor, wallet or persistence context.
	var ui = UI.instantiate()
	check(UI.get_state().get_node_count() > 80,"static layout is authored in the scene before the controller runs")
	check(ui.get_node("Surface/Overlay/SessionMenu/Menu/Title").text == "Game Menu"
		and ui.get_node("Surface/Overlay/CheckpointMenu/Checkpoint/Title").text == "Roots of Strength",
		"a designer can locate and change menu and checkpoint headings directly in the scene")
	root.add_child(ui)
	ui.requested.connect(func(command: String, data: Dictionary): requests.append({"command":command,"data":data.duplicate(true)}))
	await process_frame
	check(not ui.is_overlay_open(),"shell starts closed without a world adapter")
	var rooted: PanelContainer = control(ui,"SessionMenu")
	var old_padding: Vector2 = rooted.content_padding
	rooted.content_padding = Vector2(30,18)
	check(rooted.get_theme_stylebox("panel").get_content_margin(SIDE_LEFT)==30
		and control(ui,"PackMenu").get_theme_stylebox("panel").get_content_margin(SIDE_LEFT)==20,
		"scene padding uses the shared root artwork without changing other frames")
	rooted.content_padding = old_padding
	ui.toggle_panel("session")
	check(ui.panel_is_open("session") and control(ui,"Resume").has_focus(),"session owns keyboard focus")
	ui.toggle_panel("pack")
	check(ui.panel_is_open("pack") and not control(ui,"SessionMenu").visible,"only the selected frame remains open")
	ui.toggle_panel("pack")
	check(not ui.is_overlay_open(),"repeating a panel request closes it")
	var external: PanelContainer = ui.create_overlay_panel(Color.WHITE,Vector2.ZERO)
	ui.toggle_external(external)
	ui.toggle_panel("guide")
	check(not external.visible and ui.panel_is_open("guide"),"feature frames use the same exclusive overlay lifecycle")
	ui.close_panels()
	ui.present_context("E  Heart","Research and class progression")
	check(control(ui,"PromptPanel").visible and control(ui,"DetailLabel").visible,"context appears in the visible HUD")
	ui.toggle_panel("session")
	ui.present_feedback("Save needs reconciliation.",true)
	check(not control(ui,"ToastPanel").visible and control(ui,"MenuNotice").visible,"settlement notice remains visible in the menu")
	ui.toggle_panel("pack")
	ui.present_feedback("Save needs reconciliation.",true)
	check(control(ui,"ToastPanel").visible and control(ui,"ToastPanel").z_index==1,"pending notice remains above other overlays")
	ui.close_panels()
	var state := {"hp":50,"max_hp":100,"wild":false,"party":[]}
	ui.present_hud(state,false)
	state.hp=99
	check(control(ui,"PlayerHud").state.hp==50,"HUD retains detached presentation data")
	var shown := offer(37)
	var original := JSON.stringify(shown)
	ui.show_checkpoint_offer(shown,12,3,false)
	var first: Control = control(ui,"CheckpointCards").get_child(0)
	var take: Button = first.find_children("*","Button",true,false).filter(func(button): return "Take upgrade" in button.text)[0]
	var details: Button = first.find_children("*","Button",true,false).filter(func(button): return button.text=="Details")[0]
	details.button_pressed=true
	check(details.text=="Hide details" and "Each acquired copy" in first.find_children("*","Label",true,false).back().text,"Details exposes the offered copy's conditions")
	ui.close_panels()
	ui.toggle_panel("checkpoint")
	check(ui.checkpoint_revision()==37 and requests.is_empty() and JSON.stringify(shown)==original,"reopening neither rolls nor mutates the host offer")
	ui.show_checkpoint_offer(offer(38),10,3,false)
	take.pressed.emit()
	check(requests.back()=={"command":"checkpoint","data":{"revision":37,"choice":"0"}},"an old button cannot claim a replacement offer revision")
	control(ui,"CheckpointReroll").pressed.emit()
	check(requests.back()=={"command":"checkpoint","data":{"revision":38,"choice":"reroll"}},"reroll requests carry the displayed host revision")
	ui.choose_checkpoint("skip")
	check(requests.back().data=={"revision":38,"choice":"skip"},"keyboard and Skip use the same revision-bound intent")
	var exhausted := offer(39)
	exhausted.exhausted=true
	exhausted.closed=true
	exhausted.choices=[]
	ui.show_checkpoint_offer(exhausted,10,6,false)
	check(control(ui,"CheckpointCards").get_child_count()==0 and not control(ui,"CheckpointReroll").visible
		and control(ui,"CheckpointSkip").text=="Continue at the Gate","exhausted growth preserves the continue flow")
	ui.close_panels()
	ui.present_travel({"kind":"depart","goal":"the Heart","members":[{"name":"Ally","ready":true}],"ready":true},true)
	check(control(ui,"TravelPanel").visible and control(ui,"ReadyButton").disabled
		and control(ui,"ReadyButton").text=="Ready at Heart","ready display uses a detached travel projection")
	control(ui,"UnreadyButton").pressed.emit()
	check(requests.back()=={"command":"ready","data":{"unready":true}},"travel display emits an intention, not a membership mutation")
	ui.present_menu({"session_text":"Solo","role":"Solo","can_host":true,"can_join":true,
		"can_leave":false,"can_save":true,"can_bank":false,"wild":false,"look":[0,0,0,0,0]})
	check(control(ui,"AppearanceMenu").find_children("*","Button",true,false).any(
		func(button): return button.text.begins_with("Skin: ")),"appearance retains its existing skin label")
	ui.present_connection(true,"Checking compatibility · 2 of 4")
	check(control(ui,"ConnectionPanel").visible and "2 of 4" in control(ui,"ConnectionLabel").text,"connection presentation needs no session access")
	ui.show_deposit([{"label":"Mysterious seed 1","id":0},{"label":"Trophy","id":1004}])
	control(ui,"DepositPick").select(1)
	control(ui,"DepositButton").pressed.emit()
	check(requests.back()=={"command":"bank","data":{"value":1004}} and not ui.is_overlay_open(),"courier submits the selected item without editing inventory")
	ui.show_abandon_confirmation()
	var count := requests.size()
	control(ui,"AbandonConfirmation").hide()
	check(requests.size()==count,"cancelling abandonment has no gameplay side effects")
	control(ui,"AbandonConfirmation").confirmed.emit()
	check(requests.back().command=="confirm_abandon","confirmed voluntary exit is delegated to existing transaction integration")
	ui.free()
	await process_frame
	if not failed: print("PASS: standalone gameplay UI ownership, exclusive overlays, detached HUD/travel, revision-bound cards, details, exhaustion and confirmed action requests")
	quit(1 if failed else 0)
