extends CanvasLayer
## The arena's time controls, status bar and setup screen.

const Characters = preload("res://neural_arena/arena_characters.gd")
const Config = preload("res://neural_arena/arena_config.gd")
const Entry = preload("res://neural_arena/arena_entry.gd")
const RootUI = preload("res://root_ui.gd")

const SPEED_LABELS := {0.25: "1/4x", 0.5: "1/2x", 1.0: "1x", 2.0: "2x", 4.0: "4x", 8.0: "8x", 16.0: "16x"}

var world: Node
var _bar: PanelContainer
var _info: Label
var _pause: Button
var _step: Button
var _speed_buttons: Dictionary = {}
var _setup: PanelContainer
var _notice: Label
var _mode: OptionButton
var _session: OptionButton
var _address: LineEdit
var _port: SpinBox
var _class: OptionButton
var _bots: SpinBox
var _brain: OptionButton
var _brains: Array = []
var _intelligence: HSlider
var _floor: SpinBox
var _map: OptionButton
var _seed: SpinBox
var _round: SpinBox
var _elite: OptionButton
var _darkness: OptionButton
var _counts: Dictionary = {}
var _total: Label


func _ready() -> void:
	layer = 6
	var surface := Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.theme = RootUI.make_theme()
	add_child(surface)
	_build_bar(surface)
	_build_setup(surface)
	if world.auto_start:
		_setup.hide()
	else:
		show_setup()


func _build_bar(surface: Control) -> void:
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", RootUI.root_style(true))
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.offset_top = 10
	surface.add_child(_bar)
	var column := VBoxContainer.new()
	_bar.add_child(column)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_info)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	_pause = _button(row, "Pause", _toggle_pause)
	_step = _button(row, "Step", _step_once)
	for value: float in SPEED_LABELS:
		_speed_buttons[value] = _button(row, SPEED_LABELS[value], world.set_speed.bind(value))
	_button(row, "Setup", show_setup)
	_button(row, "Exit", world.return_to_main_menu.bind(""))


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _toggle_pause() -> void:
	world.paused = not world.paused


func _step_once() -> void:
	world.paused = true
	world.step_once()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _setup.visible or world.is_guest_session() or world.awaiting_setup:
		return
	if event.is_action_pressed("ui_accept") and world.host_is_bot():
		_toggle_pause()
	elif event is InputEventKey and event.physical_keycode == KEY_F2:
		show_setup()
	elif event is InputEventKey and event.physical_keycode == KEY_PERIOD:
		_step_once()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if world.config.session == Config.SessionKind.JOIN and not world.awaiting_setup and world.network_session.role() == "Solo":
		world.awaiting_setup = true
		show_setup()
		_notice.text = str(world.status)
	var guest: bool = world.is_guest_session()
	_pause.text = "Resume" if world.paused else "Pause"
	_pause.visible = not guest
	_step.visible = not guest and world.real_guest_count() == 0
	var allowed: Array = world.allowed_speeds()
	for value: float in _speed_buttons:
		var button: Button = _speed_buttons[value]
		button.visible = not guest and allowed.has(value) and allowed.size() > 1
		button.disabled = is_equal_approx(world.speed, value)
	_info.text = _status_text(guest)
	if world.host_is_bot():
		world.spectator_view.hide_panel()


func _status_text(guest: bool) -> String:
	if guest:
		return "Neural Arena · %s" % ("Connected to host" if world.network_session.role() == "Guest" else "Connecting...")
	if world.awaiting_setup:
		return "Neural Arena · Choose your setup"
	var seconds: int = world.round_tick / world.CombatClock.TICKS_PER_SECOND
	var line := "Round %d · %d:%02d · Enemies %d · Party %d · %s" % [world.round_index, seconds / 60, seconds % 60,
		world.encounter.living_scout_count(), world.Life.living_ids(world).size(), _brain_label(world.config.brain)]
	if world.paused:
		line += " · PAUSED"
	if not world.round_running and not world.last_result.is_empty():
		line += " · " + str(world.last_result.get("outcome", "")).capitalize()
	return line


func _brain_label(path: String) -> String:
	for entry: Array in Config.available_brains():
		if entry[1] == path:
			return entry[0]
	return path.get_file().get_basename()


func _build_setup(surface: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(center)
	_setup = PanelContainer.new()
	_setup.add_theme_stylebox_override("panel", RootUI.root_style(true))
	_setup.custom_minimum_size = Vector2(860, 590)
	center.add_child(_setup)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_setup.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "Neural Arena Setup"
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	var sections := HBoxContainer.new()
	sections.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 18)
	column.add_child(sections)
	_build_options(sections)
	_build_enemy_list(sections)
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_notice)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	_button(actions, "Close", _close_setup)
	_button(actions, "Exit Arena", world.return_to_main_menu.bind(""))
	_button(actions, "Start", _start)


func _build_options(parent: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	parent.add_child(grid)
	_mode = _option(grid, "Mode", ["Watch the AI fight", "Play against the AI"])
	_session = _option(grid, "Session", ["Solo", "Host multiplayer", "Join multiplayer"])
	_address = LineEdit.new()
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row(grid, "Host address", _address)
	_port = _spin(grid, "Port", 1024, 65535, 1)
	var classes: Array[String] = []
	for class_id in Characters.class_count():
		classes.append(Characters.class_name_of(class_id))
	_class = _option(grid, "Your class", classes)
	_bots = _spin(grid, "AI party members", 0, Config.MAX_PARTY, 1)
	_brains = Config.available_brains()
	var labels: Array[String] = []
	for entry: Array in _brains:
		labels.append(entry[0])
	_brain = _option(grid, "Enemy brain", labels)
	_intelligence = HSlider.new()
	_intelligence.max_value = 1.0
	_intelligence.step = 0.05
	_intelligence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row(grid, "Enemy intelligence", _intelligence)
	_floor = _spin(grid, "Difficulty floor", 1, 60, 1)
	_map = _option(grid, "Map", ["Generated Wilds floor", "Open arena"])
	_seed = _spin(grid, "Map seed", 1, 999999, 1)
	_round = _spin(grid, "Round length (seconds)", 15, 900, 5)
	var elites: Array[String] = ["None"]
	for label: String in _species_ids():
		elites.append(label)
	_elite = _option(grid, "Gate elite", elites)
	_darkness = _option(grid, "Light (new enemies only)", ["Day", "Dusk", "Night"])


func _species_ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in world.Enemies.all():
		if not entry.get("boss", false):
			result.append(str(entry.id))
	return result


func _build_enemy_list(parent: Control) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 330
	parent.add_child(column)
	_total = Label.new()
	column.add_child(_total)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for entry: Dictionary in world.Enemies.all():
		if entry.get("boss", false):
			continue
		var name_label := Label.new()
		name_label.text = str(entry.name)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var count := SpinBox.new()
		count.max_value = Config.MAX_ENEMIES
		count.value_changed.connect(func(_value: float): _refresh_total())
		grid.add_child(count)
		_counts[str(entry.id)] = count


func _row(grid: Control, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	grid.add_child(control)


func _option(grid: Control, text: String, items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		option.add_item(str(item))
	_row(grid, text, option)
	return option


func _spin(grid: Control, text: String, low: float, high: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row(grid, text, spin)
	return spin


func _refresh_total() -> void:
	var total := 0
	for count: SpinBox in _counts.values():
		total += int(count.value)
	_total.text = "Enemies: %d / %d" % [total, Config.MAX_ENEMIES]
	_total.modulate = Color("#f29b8a") if total > Config.MAX_ENEMIES else Color.WHITE


func show_setup() -> void:
	if world.is_guest_session():
		return
	var config: Config = world.config
	world.paused = true
	_mode.select(config.mode)
	_session.select(config.session)
	_address.text = config.address
	_port.value = config.port
	_class.select(config.player_class)
	_bots.value = config.bots
	for index in _brains.size():
		if _brains[index][1] == config.brain:
			_brain.select(index)
	_intelligence.value = config.intelligence
	_floor.value = config.floor_number
	_map.select(0 if config.generated_map else 1)
	_seed.value = config.map_seed
	_round.value = config.round_seconds
	_elite.select(maxi(0, _species_ids().find(config.elite) + 1))
	_darkness.select(maxi(0, ["day", "dusk", "night"].find(config.darkness)))
	for label: String in _counts:
		_counts[label].value = int(config.enemies.get(label, 0))
	_refresh_total()
	_notice.text = "" if Bridge_ready() else "The native extension is not built, so only the current game AI is available."
	_setup.show()
	_bar.hide()


func Bridge_ready() -> bool:
	return world.Bridge.available()


func _close_setup() -> void:
	if world.awaiting_setup:
		return
	_setup.hide()
	_bar.show()
	world.paused = false


func _read_setup() -> Config:
	var config: Config = world.config.duplicate_config()
	config.mode = _mode.selected as Config.Mode
	config.session = _session.selected as Config.SessionKind
	config.address = _address.text.strip_edges()
	config.port = int(_port.value)
	config.player_class = _class.selected
	config.bots = int(_bots.value)
	config.brain = _brains[_brain.selected][1]
	config.intelligence = _intelligence.value
	config.floor_number = int(_floor.value)
	config.generated_map = _map.selected == 0
	config.map_seed = int(_seed.value)
	config.round_seconds = int(_round.value)
	config.elite = "" if _elite.selected == 0 else _species_ids()[_elite.selected - 1]
	config.darkness = ["day", "dusk", "night"][_darkness.selected]
	config.enemies = {}
	for label: String in _counts:
		if int(_counts[label].value) > 0:
			config.enemies[label] = int(_counts[label].value)
	return config


func _problem(config: Config) -> String:
	if config.session == Config.SessionKind.JOIN:
		return "" if not config.address.is_empty() else "Enter the host's address."
	if config.total_enemies() == 0 and config.elite.is_empty():
		return "Choose at least one enemy."
	if config.total_enemies() > Config.MAX_ENEMIES:
		return "Choose %d enemies or fewer." % Config.MAX_ENEMIES
	if config.mode == Config.Mode.WATCH and config.bots < 1:
		return "Watch mode needs at least one AI party member."
	if config.mode == Config.Mode.PLAY and config.bots >= Config.MAX_PARTY:
		return "Play mode has room for %d AI party members." % (Config.MAX_PARTY - 1)
	return ""


func _start() -> void:
	var config := _read_setup()
	var problem := _problem(config)
	if not problem.is_empty():
		_notice.text = problem
		return
	_setup.hide()
	_bar.show()
	world.paused = false
	if world.awaiting_setup:
		world.config = config
		world.begin_session()
	elif config.session != world.config.session or config.port != world.config.port:
		Entry.relaunch(world, config)
	else:
		world.apply_config(config)
