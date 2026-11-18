extends Control

const Frames = preload("res://weapon_frames.gd")
const ClassIcons = preload("res://class_skill_icons.gd")
const Orb = preload("res://health_orb.gd")
const FRAME = preload("res://assets/ui/root_frame.png")
const POOL_SHADER = preload("res://health_pool.gdshader")
const Exploration = preload("res://exploration.gd")
const INK := Color("#e6ddbd")
const MUTED := Color("#acaa8a")
const GREEN := Color("#90af6a")

const ACCENT := Color("#c9b26a")
const BTN_BG := Color("#20301f")
const BTN_BG_HOVER := Color("#2f4a2b")
const BTN_BG_PRESSED := Color("#1a2718")
const BTN_BG_DISABLED := Color("#1b211a")
const BTN_BORDER := Color("#5d6f44")
const BTN_BORDER_HOVER := Color("#b7c489")
const SHADOW := Color("#05080460")

static func flat_style(bg: Color, border: Color, border_w: int = 2, radius: int = 7, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 6
	s.content_margin_right = pad + 6
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = true
	s.shadow_color = SHADOW
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", flat_style(BTN_BG, BTN_BORDER))
	t.set_stylebox("hover", "Button", flat_style(BTN_BG_HOVER, BTN_BORDER_HOVER))
	t.set_stylebox("pressed", "Button", flat_style(BTN_BG_PRESSED, ACCENT))
	t.set_stylebox("hover_pressed", "Button", flat_style(BTN_BG_HOVER, ACCENT))
	t.set_stylebox("focus", "Button", flat_style(BTN_BG_HOVER, ACCENT))
	t.set_stylebox("disabled", "Button", flat_style(BTN_BG_DISABLED, Color("#3a4432")))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color("#f3ecc9"))
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", Color("#f3ecc9"))
	t.set_color("font_disabled_color", "Button", Color("#6b7360"))
	t.set_font_size("font_size", "Button", 15)
	t.set_color("font_color", "CheckBox", MUTED)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", ACCENT)
	t.set_font_size("font_size", "CheckBox", 14)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color("#0a0f07b4"))
	t.set_constant("outline_size", "Label", 3)
	return t

static func style_title(l: Label, color: Color = Color("#ece0ad")) -> void:
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#1c2a12c8"))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color("#c9b26a40"))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 10)
static var frame_texture: Texture2D
static var compact_texture: Texture2D
var party_panel=preload("res://party_hud.gd").new()
var floor_track=preload("res://expedition_track.gd").new()
var state := {}
var skill_hover: Array[Control]=[]
var core_icon: Texture2D
var core_icon_path: String=""
var health_orb := Orb.new()
var health_pool := ColorRect.new()
var pool_vitals := Label.new()
var pool_capacity := Label.new()
var pool_material := ShaderMaterial.new()
var chart_expanded := false
var frame_style: StyleBoxTexture
var slot_style: StyleBoxTexture

static func root_style(compact: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if frame_texture == null:
		var image := FRAME.get_image()
		image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		frame_texture = ImageTexture.create_from_image(image)
	if compact and compact_texture == null:
		var image := FRAME.get_image()
		image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		compact_texture = ImageTexture.create_from_image(image)
	style.texture = compact_texture if compact else frame_texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 12.0 if compact else 24.0)
		style.set_content_margin(side, 18.0)
	return style

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(party_panel)
	add_child(floor_track)
	for slot_index in 3:
		var hover:=Control.new()
		hover.name="SkillTooltip%d"%slot_index
		hover.mouse_filter=Control.MOUSE_FILTER_PASS
		hover.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		hover.offset_left=192.0+100.0*slot_index
		hover.offset_right=hover.offset_left+98
		hover.offset_top=-101
		hover.offset_bottom=-24
		hover.hide()
		add_child(hover)
		skill_hover.append(hover)
	frame_style = root_style()
	slot_style = root_style(true)
	setup_health_pool()
	resized.connect(layout_health_pool)

func update_state(new_state: Dictionary) -> void:
	state = new_state
	health_orb.update(state,Time.get_ticks_msec())
	update_health_pool()
	floor_track.update_track(int(state.get("floor",1)),bool(state.get("wild",false)))
	party_panel.update_party(state.get("party",[]),bool(state.get("wild",false)))
	var active: bool=state.get("wild",false) and not state.get("fallen",false)
	var core: Dictionary=state.get("core",{})
	var tips: Array=state.get("skill_tooltips",["",""]).duplicate()
	tips.append(core.get("tooltip",""))
	for index in skill_hover.size():
		var target:=skill_hover[index]
		var tip := str(tips[index])
		target.visible=active and not tip.is_empty()
		if target.visible:
			tip+="\nHold to aim. Release to cast."
		if target.tooltip_text!=tip: target.tooltip_text=tip
	var path: String=core.get("icon","")
	if path!=core_icon_path:
		core_icon_path=path
		core_icon=load(path) if not path.is_empty() else null
	queue_redraw()

func setup_health_pool() -> void:
	health_pool.name = "HealthPool"
	health_pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_pool.hide()
	pool_material.shader = POOL_SHADER
	pool_material.set_shader_parameter("bark", FRAME)
	health_pool.material = pool_material
	add_child(health_pool)
	for label in [pool_vitals, pool_capacity]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color("#140a08"))
		label.add_theme_constant_override("outline_size", 5)
		health_pool.add_child(label)
	pool_vitals.add_theme_color_override("font_color", Color("#f4e5c8"))
	pool_vitals.add_theme_font_size_override("font_size", 17)
	pool_capacity.add_theme_color_override("font_color", Orb.CAP)
	pool_capacity.add_theme_font_size_override("font_size", 12)

func set_chart_expanded(expanded: bool) -> void:
	if chart_expanded != expanded:
		chart_expanded = expanded
		layout_health_pool()

func update_health_pool() -> void:
	var fill := Orb.fractions(health_orb.hp, health_orb.maximum, health_orb.lost)
	var previous := Orb.fractions(health_orb.from_hp, health_orb.maximum, health_orb.lost)
	var flash := 1.0 - clampf(float(Time.get_ticks_msec() - health_orb.changed_at) / Orb.CHANGE_MS, 0.0, 1.0)
	pool_material.set_shader_parameter("health", fill.x)
	pool_material.set_shader_parameter("capacity", fill.y)
	pool_material.set_shader_parameter("previous", previous.x)
	pool_material.set_shader_parameter("flash", flash)
	var vitals := "%d / %d HP" % [int(health_orb.hp), health_orb.maximum]
	if pool_vitals.text != vitals:
		pool_vitals.text = vitals
	var sealed := "−%d max HP" % health_orb.lost if health_orb.lost > 0 else ""
	if pool_capacity.text != sealed:
		pool_capacity.text = sealed
	if not health_pool.visible:
		health_pool.show()
	layout_health_pool()

func layout_health_pool() -> void:
	var active := bool(state.get("wild", false))
	var chart := Exploration.chart_bounds(size, chart_expanded)
	var diameter := minf(166.0, size.x * 0.16)
	var right := chart.position.x - 8.0 if active else size.x - 16.0
	var bottom := size.y - 12.0
	var action_end := 672.0 if not state.get("core", {}).is_empty() else 572.0
	if active and (chart_expanded or right - diameter < action_end + 8.0):
		# Move above the map when the horizontal gap is too narrow.
		right = Exploration.chart_bounds(size, false).position.x - 8.0
		bottom = chart.position.y - 8.0
	health_pool.position = Vector2(right - diameter, bottom - diameter)
	health_pool.size = Vector2.ONE * diameter
	pool_vitals.position = Vector2(0, diameter * 0.55)
	pool_vitals.size.x = diameter
	pool_capacity.position = Vector2(0, diameter * 0.69)
	pool_capacity.size.x = diameter

func text(canvas: Control, at: Vector2, value: String, font_size: int = 14, color: Color = INK) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, at + Vector2(1, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.45))
	canvas.draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.03, 0.05, 0.03, 0.9))
	canvas.draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func slot(canvas: Control, rect: Rect2, key: String, name_text: String, ready: bool, glyph: String) -> void:
	canvas.draw_style_box(slot_style, rect)
	var center := rect.get_center()
	canvas.draw_circle(center - Vector2(0, 8), 15, Color("#34492b") if ready else Color("#292821"))
	text(canvas, center + Vector2(-7, -2), glyph, 21, Color("#c6d5a3") if ready else MUTED)
	text(canvas, rect.position + Vector2(11, 26), key, 11, MUTED)
	text(canvas, rect.position + Vector2(11, rect.size.y - 19), name_text, 12, INK if ready else MUTED)
	if not ready:
		canvas.draw_rect(Rect2(rect.position + Vector2(9, rect.size.y - 7), Vector2(rect.size.x - 18, 2)), Color("#6c5d3d"))

func _draw() -> void:
	if state.is_empty():
		return
	var damage_flash=clampf(float(state.get("damage_flash",0)),0,1)
	if damage_flash>0:
		for border in [Rect2(0,0,size.x,10),Rect2(0,size.y-10,size.x,10),Rect2(0,0,10,size.y),Rect2(size.x-10,0,10,size.y)]:
			draw_rect(border,Color(.7,.12,.08,damage_flash*.5))
	text(self, Vector2(24, 30), str(state.location), 15)
	text(self, Vector2(24, 49), str(state.encounter), 12, MUTED)
	var active := bool(state.wild)
	if active:
		var summary_key := preload("res://app_settings.gd").hint("run_summary")
		if summary_key != "Unbound":
			text(self, Vector2(24, 67), summary_key + " · Expedition", 12, MUTED)
		var affinity_feed: String = state.get("affinity_feedback", "")
		if not affinity_feed.is_empty() and not state.get("fallen",false):
			text(self, Vector2(24, 86), affinity_feed, 13, Color("#ded0f4"))
	var bottom := size.y - (150 if active else 100)
	var core: Dictionary=state.get("core",{})
	var has_core: bool=active and not state.get("fallen",false) and not core.is_empty()
	draw_style_box(frame_style, Rect2(12, bottom, (660 if has_core else 560) if active else 360, 138 if active else 88))
	if not active:
		text(self, Vector2(30, bottom + 50), "Seeds %d · Knowledge %d available · I Storage" % [int(state.carried),int(state.get("insight",0))], 12, GREEN)
		return
	if state.get("fallen",false):
		text(self,Vector2(30,bottom+75),"FALLEN · awaiting a teammate",15,MUTED)
		return
	slot(self, Rect2(24, bottom + 49, 82, 77), preload("res://app_settings.gd").hint("attack").to_upper(), "Strike", active, "✦")
	slot(self, Rect2(108, bottom + 49, 82, 77), preload("res://app_settings.gd").hint("dodge").to_upper(), "Dodge", active and bool(state.dodge_ready), "»")
	var names: Array=state.get("skill_names",[Frames.DEFINITIONS[int(state.frame)].skill,"Skill II"])
	var cooldowns: Array=state.get("skill_cooldowns",[0.0,0.0])
	skill_slot(self,Rect2(192,bottom+49,98,77),preload("res://app_settings.gd").hint("class_skill"),str(names[0]),float(cooldowns[0]),bool(state.skill_ready))
	skill_slot(self,Rect2(292,bottom+49,98,77),preload("res://app_settings.gd").hint("class_skill_two"),str(names[1]),float(cooldowns[1]),bool(state.get("skill_two_ready",true)))
	if has_core:
		draw_core_slot(Rect2(392,bottom+49,98,77),core)
	var satchel_x:=504 if has_core else 404
	text(self, Vector2(satchel_x, bottom + 33), "SATCHEL" if active else "GARDEN", 12, MUTED)
	text(self, Vector2(satchel_x, bottom + 56), "Seeds   %d" % int(state.carried), 14)
	text(self, Vector2(satchel_x, bottom + 77), "Pouch   %d / 1" % int(state.pouch) if active else "Stored materials · I", 12, GREEN)
	text(self, Vector2(satchel_x, bottom + 98), "Essence   %d" % int(state.wallet) if active else "Knowledge   %d" % int(state.knowledge), 12, Color("#d2bd77"))

func draw_core_slot(rect: Rect2,core: Dictionary) -> void:
	draw_style_box(slot_style,rect)
	var remaining: float=core.remaining
	var ready:=remaining<=0.0
	var tint:=Color.WHITE if ready else Color(.78,.78,.69,.72)
	var center:=rect.get_center()
	if core_icon!=null:
		draw_texture_rect(core_icon,Rect2(center-Vector2(17,25),Vector2(34,34)),false,tint)
	else:
		text(self,center-Vector2(6,2),"❧",16,GREEN)
	var key:=preload("res://app_settings.gd").hint("core_skill")
	text(self,rect.position+Vector2(9,17),key,11,INK)
	if remaining>0.0:
		text(self,rect.position+Vector2(62,17),"%.1f"%remaining,11,MUTED)
	var label: String=core.name
	var font:=ThemeDB.fallback_font
	var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	text(self,Vector2(center.x-width*.5,rect.end.y-15),label,11,INK if ready else MUTED)


func skill_slot(canvas: Control,rect: Rect2,key: String,label: String,remaining: float,ready: bool) -> void:
	canvas.draw_style_box(slot_style,rect)
	var center:=rect.get_center()
	var icon := ClassIcons.icon(label.trim_suffix(" •"))
	if icon != null:
		var tint := Color.WHITE if ready else Color(.63,.65,.61,.78)
		canvas.draw_texture_rect(icon,Rect2(center-Vector2(18,27),Vector2(36,36)),false,tint)
	text(canvas,rect.position+Vector2(10,18),key,11,MUTED)
	if not ready:
		var value := "%.1f" % remaining
		var width := ThemeDB.fallback_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		text(canvas,rect.position+Vector2(rect.size.x-width-8,18),value,11,MUTED)
	var words:=label.split(" ")
	if words.size()>1:
		var first: String=words[0]
		var rest: String=" ".join(words.slice(1))
		text(canvas,rect.position+Vector2(10,rect.size.y-23),first,11,INK if ready else MUTED)
		text(canvas,rect.position+Vector2(10,rect.size.y-10),rest,11,INK if ready else MUTED)
	else:
		text(canvas,rect.position+Vector2(10,rect.size.y-15),label,11,INK if ready else MUTED)
	if not ready:
		canvas.draw_rect(Rect2(rect.position+Vector2(9,rect.size.y-6),Vector2(rect.size.x-18,2)),Color("#6c5d3d"))

static func panel(parent: Node, color: Color, margin: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := root_style()
	style.content_margin_left = maxf(18.0, margin.x)
	style.content_margin_right = maxf(18.0, margin.x)
	style.content_margin_top = maxf(16.0, margin.y)
	style.content_margin_bottom = maxf(16.0, margin.y)
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

static func button(parent: Control, caption: String, action: Callable, focus: int = Control.FOCUS_ALL) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = focus
	button.pressed.connect(action)
	parent.add_child(button)
	return button
