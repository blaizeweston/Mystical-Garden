extends PanelContainer
var world: Node
var opened := true
var tabs := TabContainer.new()
var pages := {}
var message := Label.new()
var fight: Button
var selector: OptionButton
var amount: SpinBox
var arrangement: OptionButton
var endless: CheckButton
var metrics: Label
var editor: RefCounted
var tuning_editor: RefCounted
var displayed_sun := NAN

func _ready() -> void:
	position=Vector2(14,42)
	var background:=StyleBoxFlat.new()
	background.bg_color=Color("#171d17")
	background.border_color=Color("#69784c")
	background.set_border_width_all(1)
	for side in [SIDE_TOP,SIDE_BOTTOM,SIDE_LEFT,SIDE_RIGHT]: background.set_content_margin(side,10.0)
	add_theme_stylebox_override("panel",background)
	custom_minimum_size=Vector2(560,410)
	var body:=VBoxContainer.new()
	add_child(body)
	var title:=Label.new()
	var practice: bool=world.is_practice_world()
	title.text="Developer Testing Arena" if practice else "Developer Workbench"
	body.add_child(title)
	tabs.custom_minimum_size.y=clampf(get_viewport_rect().size.y-220,260,495)
	body.add_child(tabs)
	var sections := ["Testing","Enemies","Build","Upgrades","Statistics","Tuning"] if practice else ["Testing","Tuning"]
	for key in sections:
		var scroll:=ScrollContainer.new()
		scroll.name=key
		tabs.add_child(scroll)
		var page:=VBoxContainer.new()
		page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		pages[key]=page
	if practice:
		selector = OptionButton.new()
		amount = SpinBox.new()
		arrangement = OptionButton.new()
		endless = CheckButton.new()
		metrics = Label.new()
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
	else:
		var arena:=command(pages.Testing,"Enter Testing Arena",func():
			if world.developer_tuning.authorized(world) and preload("res://developer_mode.gd").can_enter_arena(world):
				toggle()
				preload("res://developer_mode.gd").enter_arena(world))
		arena.disabled=not preload("res://developer_mode.gd").can_enter_arena(world)
		arena.tooltip_text="Available between expeditions in the Developer Garden."
		tabs.current_tab=1
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message)
	var footer:=HBoxContainer.new()
	body.add_child(footer)
	fight=command(footer,"Resume testing" if practice else "Return to game",toggle)
	if practice:
		command(footer,"Return to Developer Garden",world.session.close)
		editor=preload("res://developer_arena/build_editor.gd").new()
		editor.setup(self)
	tuning_editor=preload("res://developer_arena/tuning_editor.gd").new()
	tuning_editor.setup(self,pages.Tuning)
	tabs.tab_changed.connect(func(_index):tuning_editor.refresh())
	fight.grab_focus()
	show_stats()

func _process(_delta: float) -> void:
	if not visible or tuning_editor == null or tabs.get_current_tab_control().name!="Tuning" or tuning_editor.category.get_current_tab_control().name!="Visuals": return
	var baseline: float=world.stage.production_sun_energy
	if not is_equal_approx(baseline,displayed_sun):
		displayed_sun=baseline
		tuning_editor.refresh()

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
	if not world.is_practice_world(): return
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
		tuning_editor.refresh()
		if not world.is_practice_world():
			pages.Testing.get_child(0).disabled=not preload("res://developer_mode.gd").can_enter_arena(world)
		show_stats()
		fight.grab_focus()
