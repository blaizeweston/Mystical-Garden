extends VBoxContainer
## Presentation of one detached host result. TabBar and the close button
## participate in Godot's ordinary keyboard/controller focus navigation.
signal dismissed

const LABELS := {"damage":"Damage dealt","kills":"Enemies defeated","elites":"Elite defeats","bosses":"Boss defeats",
	"taken":"Damage taken","healing":"Effective healing provided","prevented":"Damage prevented on this character",
	"revives":"Allies revived","falls":"Times fallen","xp":"Class XP earned before forfeiture","cards":"Cards acquired","grafts":"Graft improvements"}
var _tabs := TabContainer.new()
var _close := Button.new()

func _ready() -> void:
	add_theme_constant_override("separation",10)
	var title := Label.new()
	title.text = "Expedition Summary"
	title.add_theme_font_size_override("font_size",24)
	add_child(title)
	add_child(_tabs)
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL
	_close.text = "Continue"
	_close.pressed.connect(func(): dismissed.emit())
	add_child(_close)

## Voluntary return to title can retire the entire gameplay scene on the
## same frame as settlement. Carry its already-finalized view across once.
static func show_at_title(menu: Node, report: Dictionary) -> void:
	var dialog := PopupPanel.new()
	dialog.name = "ExpeditionResults"
	menu.add_child(dialog)
	var content := new()
	dialog.add_child(content)
	content.present(report)
	content.dismissed.connect(dialog.hide)
	dialog.popup_hide.connect(dialog.queue_free)
	dialog.popup_centered()
	content.focus_navigation()

func focus_navigation() -> void:
	_tabs.get_tab_bar().grab_focus()

static func number(value: float) -> String:
	var fixed := ("%.2f" % absf(value)).split(".")
	var whole := fixed[0]
	var groups := PackedStringArray()
	while whole.length() > 3:
		groups.insert(0,whole.right(3))
		whole = whole.left(whole.length()-3)
	groups.insert(0,whole)
	var decimal := ("."+fixed[1]).rstrip("0").trim_suffix(".")
	return ",".join(groups) + decimal

func page(caption: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	_tabs.add_child(scroll)
	_tabs.set_tab_title(scroll.get_index(),caption)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",18)
	scroll.add_child(grid)
	return grid

func line(grid: GridContainer, label: String, value: String) -> void:
	var title := Label.new()
	title.text = label
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(title)
	var data := Label.new()
	data.text = value
	data.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(data)

func present(report: Dictionary) -> void:
	for old in _tabs.get_children():
		_tabs.remove_child(old)
		old.queue_free()
	_tabs.custom_minimum_size = Vector2(560,350).min(get_viewport_rect().size * Vector2(.78,.57))
	var overview := page("Overview")
	line(overview,"Party outcome",report.party_outcome)
	line(overview,"Your outcome",report.outcome)
	var seconds := floori(float(report.elapsed_ms)/1000.0)
	line(overview,"Expedition time at departure","%dh %02dm %02ds" % [floori(seconds/3600.0),floori(seconds/60.0)%60,seconds%60])
	line(overview,"Deepest floor",str(report.floor))
	line(overview,"Encounters cleared",str(report.clears))
	line(overview,"Participating characters",str(report.players.size()))
	for key in ["kills","elites","bosses","damage","healing"]: line(overview,"Party · "+LABELS[key],number(report.party[key]))
	for key in ["damage","healing"]:
		if report.party["unattributed_"+key] > 0: line(overview,"Unattributed "+key,number(report.party["unattributed_"+key]))
	for index in report.players.size():
		var row: Dictionary = report.players[index]
		line(overview,row.name+" · "+row.class_name,"%s damage · %s healed" % [number(row.damage),number(row.healing)])
		var grid := page(str(row.name) + (" · You" if index == report.personal_index else ""))
		line(grid,row.class_name,row.outcome)
		for key: String in LABELS: line(grid,LABELS[key],number(row[key]))
		for effect: String in row.affinity: line(grid,effect+" damage",number(row.affinity[effect]))
	_tabs.current_tab = 0
