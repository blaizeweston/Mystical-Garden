extends VBoxContainer
## Read-only station content. All controls switch views locally.
const Records = preload("res://living_archive.gd")
const Format = preload("res://ui/gameplay/expedition_summary.gd")
const Campaign = preload("res://campaign.gd")
const CATEGORIES := ["Botanical","Expeditions","Combat","Garden Development"]
var scope := TabBar.new()
var categories := TabBar.new()
var scroll := ScrollContainer.new()
var grid := GridContainer.new()
var facts := {}

func _ready() -> void:
	for label_text in ["The Garden","My Character"]: scope.add_tab(label_text)
	for label_text in CATEGORIES: categories.add_tab(label_text)
	for bar in [scope,categories]:
		add_child(bar)
		bar.focus_mode = Control.FOCUS_ALL
		bar.tab_changed.connect(func(_index): scroll.scroll_vertical=0; _draw_rows())
	scroll.custom_minimum_size = Vector2(520,235).min(get_viewport_rect().size * Vector2(.76,.44))
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.gui_input.connect(_scroll_input)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid.columns=2
	grid.add_theme_constant_override("h_separation",18)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var note := Label.new()
	note.text="Activity totals start with the Living Archive update."
	note.add_theme_font_size_override("font_size",13)
	add_child(note)

func _scroll_input(event: InputEvent) -> void:
	if not scroll.has_focus(): return
	var direction := int(event.is_action_pressed("ui_down",true)) - int(event.is_action_pressed("ui_up",true))
	if direction == 0: return
	var previous := scroll.scroll_vertical
	scroll.scroll_vertical += direction * 36
	if scroll.scroll_vertical != previous: scroll.accept_event()

func open() -> void:
	facts={}
	scope.current_tab=0
	categories.current_tab=0
	_draw_rows()
	scope.grab_focus.call_deferred()

func present(data: Dictionary) -> void:
	if facts==data: return
	facts=data
	_draw_rows()

func _line(caption: String, value: Variant) -> void:
	var label := Label.new()
	label.text=caption
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var amount := Label.new()
	if value is Array: amount.text="%s / %s"%[Format.number(value[0]),Format.number(value[1])]
	elif value is float or value is int: amount.text=Format.number(value)
	else: amount.text=str(value)
	amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(amount)

func _duration(ms: int) -> String:
	var seconds:=floori(ms / 1000.0)
	return "%dh %02dm %02ds"%[floori(seconds/3600.0),floori(seconds/60.0)%60,seconds%60]

func _draw_rows() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	if facts.is_empty():
		_line("Reading Archive records…","")
		return
	var shared := scope.current_tab==0
	var row: Dictionary=facts.garden if shared else facts.personal
	var current: Dictionary=facts.current
	match categories.current_tab:
		0:
			if shared:
				_line("Species discovered",current.species)
				_line("Current seed recipes",current.recipes.seed)
				_line("Material synthesis recipes",current.recipes.synthesis)
				_line("Refinement recipes",current.recipes.refinement)
				if current.retired: _line("Retired seed recipes recorded",current.retired)
			var labels := {"plants":"Mature plants harvested","seed_harvests":"Seed harvests","seeds":"Seeds propagated","parts":"Ordinary parts harvested","refined":"Refined parts harvested","wild":"Wild specimens harvested","crosses":"Successful seed combinations"}
			for key in labels: _line(labels[key],row.get(key,0))
		1:
			_line("Recorded expeditions" if shared else "Recorded participations",row.get("runs",0))
			_line("Expeditions with extraction" if shared else "Successful extractions",row.get("extracts",0))
			_line("Abandoned participations",row.get("abandons",0))
			if shared: _line("Party wipes",row.get("wipes",0))
			_line("Total expedition time" if shared else "Total participation time",_duration(row.get("time_ms",0)))
			if shared: _line("Combined character participation",_duration(row.get("participant_ms",0)))
			_line("Longest expedition" if shared else "Longest participation",_duration(row.get("longest_ms",0)))
			var deepest: int = row.get("deepest",0)
			if shared and current.best_clear > deepest:
				_line("Deepest encounter reached","At least " + Format.number(current.best_clear))
			else: _line("Deepest encounter reached",deepest)
			_line("Deepest encounter cleared",maxi(current.best_clear,row.get("cleared",0)) if shared else row.get("cleared",0))
			_line("Resource units secured by Returning Roots",row.get("roots",0))
			if shared:
				_line("Best extraction including historical runs",current.best_extraction)
				for site in Campaign.BIOME_COUNT:
					_line(Campaign.NAMES[site]+" guardian memories","%d / %d%s"%[current.guardians[site],Campaign.MEMORY_REQUIREMENTS[site]," · Decoded" if current.decoded[site] else ""])
				for discovery in current.returns: _line(str(discovery),"Recorded")
		2:
			for key in Records.COMBAT:
				var label: String=Format.LABELS[key]
				if key=="prevented" and shared: label="Damage prevented on party members"
				_line(label,row.get(key,0))
			for effect in Records.AFFINITIES:
				if row.get(effect,0)>0: _line(effect+" damage",row[effect])
		3:
			if shared:
				var labels := {"knowledge":"Lifetime Knowledge earned","available":"Spendable Knowledge","research":"Active research completed","frontiers":"Purchased frontiers","land":"Reclaimed territory (cells)","beds":"Owned planting beds","cultivation":"Owned cultivation structures","placed":"Placed structures","stored":"Stored structures","stage":"Heart development stage"}
				for key in labels: _line(labels[key],current[key])
			_line("Growth Energy earned from contributions",row.get("energy",0))
			_line("Structures constructed with payment",row.get("built",0))
