extends PanelContainer
var world: Node
var opened := true
var tabs := TabContainer.new()
var pages := {}
var message := Label.new()
var fight: Button
var selector := OptionButton.new()
var amount := SpinBox.new()
var arrangement := OptionButton.new()
var endless := CheckButton.new()
var metrics := Label.new()
var editor: Control

func _ready() -> void:
	position=Vector2(14,42)
	custom_minimum_size=Vector2(560,410)
	var body:=VBoxContainer.new()
	add_child(body)
	var title:=Label.new()
	title.text="Developer Testing Arena"
	body.add_child(title)
	tabs.custom_minimum_size.y=285
	body.add_child(tabs)
	for key in ["Testing","Enemies","Statistics"]:
		var scroll:=ScrollContainer.new()
		scroll.name=key
		tabs.add_child(scroll)
		var page:=VBoxContainer.new()
		page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		pages[key]=page
	for key in world.session.settings:
		var control:=CheckButton.new()
		control.text={"invincible":"Player invincibility","no_cooldowns":"Bypass ability cooldowns","movement":"Allow enemy movement","attacks":"Allow enemy attacks"}[key]
		control.button_pressed=world.session.settings[key]
		control.toggled.connect(func(value):world.set_control(key,value))
		pages.Testing.add_child(control)
	command(pages.Testing,"Restore health",world.restore_health)
	command(pages.Testing,"Reset ability cooldowns",world.reset_abilities)
	command(pages.Testing,"Clear lingering effects",func():world.session.rebuild("effects"))
	command(pages.Testing,"Reset round",world.session.rebuild)
	var repeat:=CheckButton.new()
	repeat.text="Repeat equipped skill effect during play"
	repeat.toggled.connect(func(value):world.replay_effect=value)
	pages.Testing.add_child(repeat)
	var search:=LineEdit.new()
	search.placeholder_text="Search enemies, elites, bosses and targets"
	search.text_changed.connect(populate)
	pages.Enemies.add_child(search)
	pages.Enemies.add_child(selector)
	populate("")
	for item in world.PracticeEncounter.FORMATIONS: arrangement.add_item(item)
	pages.Enemies.add_child(arrangement)
	amount.prefix="Quantity "
	amount.min_value=1
	amount.max_value=world.EncounterRoster.Config.MAX_SCOUTS
	pages.Enemies.add_child(amount)
	endless.text="Infinite health for training targets"
	endless.button_pressed=true
	pages.Enemies.add_child(endless)
	command(pages.Enemies,"Spawn selection in a fresh encounter",spawn)
	command(pages.Enemies,"Clear enemies",world.clear_enemies)
	pages.Statistics.add_child(metrics)
	command(pages.Statistics,"Reset statistics",func():world.reset_statistics();show_stats())
	tabs.tab_changed.connect(func(_index):show_stats())
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message)
	var footer:=HBoxContainer.new()
	body.add_child(footer)
	fight=command(footer,"Resume testing",toggle)
	command(footer,"Return to Developer Garden",world.session.close)
	fight.grab_focus()
	show_stats()

func command(parent: Control, caption: String, callback: Callable) -> Button:
	var button:=Button.new()
	button.text=caption
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func populate(term: String) -> void:
	selector.clear()
	for row in world.PracticeEncounter.entries():
		var caption: String=row.type+" - "+row.name
		if not term.is_empty() and not caption.containsn(term): continue
		selector.add_item(caption)
		selector.set_item_metadata(selector.item_count-1,row)

func spawn() -> void:
	if selector.selected<0: return
	var row: Dictionary=selector.get_selected_metadata()
	var reason: String=world.spawn_selection(row.type,row.kind,int(amount.value),arrangement.get_item_text(arrangement.selected),endless.button_pressed)
	message.text=reason if not reason.is_empty() else "Spawned %d. Resume testing to fight."%int(amount.value)

func show_stats() -> void:
	var view: Dictionary=world.round_stats()
	if view.is_empty(): return
	var row: Dictionary=view.players[0]
	var lines:=PackedStringArray(["Elapsed   %d s"%int(view.elapsed_ms/1000.0)])
	for pair in [["Damage dealt","damage"],["Enemies defeated","kills"],["Effective healing","healing"],["Damage taken","taken"],["Damage prevented","prevented"]]:
		lines.append("%s   %s"%[pair[0],row[pair[1]]])
	for key in row.affinity: lines.append("%s damage   %s"%[str(key).capitalize(),row.affinity[key]])
	metrics.text="\n".join(lines)

func toggle() -> void:
	opened=not opened
	visible=opened
	world.mouse_controls.release(world)
	if opened:
		show_stats()
		fight.grab_focus()
