extends Window
signal applied
const Settings=preload("res://app_settings.gd")
var model: RefCounted
var draft: Dictionary={}
var binding_buttons: Dictionary={}
var pending_action: String=""
var pending_slot: int=-1
var notice: Label
var fullscreen: CheckBox
var vsync: CheckBox
var indicator: CheckBox
var fps: OptionButton
var master: HSlider
var effects: HSlider
var music: HSlider
var ambience: HSlider
var developer_context: Node
var developer_title := false
var developer_controls: VBoxContainer
func _ready() -> void:
 title="Settings";size=Vector2i(810,610);min_size=Vector2i(400,250);transient=true;exclusive=true;unresizable=false
 close_requested.connect(cancel)
 get_tree().root.size_changed.connect(fit_to_viewport)
 var frame:=PanelContainer.new()
 add_child(frame)
 frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var style=preload("res://root_ui.gd")
 frame.theme=style.make_theme()
 frame.add_theme_stylebox_override("panel",style.root_style())
 var box:=VBoxContainer.new()
 box.add_theme_constant_override("separation",10)
 frame.add_child(box)
 label(box,"Settings").add_theme_font_size_override("font_size",24)
 var pages:=TabContainer.new()
 pages.name="SettingsCategories"
 box.add_child(pages)
 pages.size_flags_vertical=Control.SIZE_EXPAND_FILL
 pages.add_theme_stylebox_override("panel",style.flat_style(Color("#141d14"),Color("#454e35"),1,4,12))

 var gameplay:=add_page(pages,"Gameplay")
 indicator=check(gameplay,"Show aim direction indicator")
 set_meta("garden_motion_toggle",check(gameplay,"Animate Garden wind, water and fauna"))
 set_meta("garden_cinematic_toggle",check(gameplay,"Play Garden growth scenes"))
 developer_controls = preload("res://developer_settings.gd").new()
 developer_controls.context = developer_context
 developer_controls.settings = self
 developer_controls.title_menu = developer_title
 gameplay.add_child(developer_controls)

 var display:=add_page(pages,"Display")
 fullscreen=check(display,"Fullscreen")
 vsync=check(display,"VSync")
 label(display,"Frame-rate limit")
 fps=OptionButton.new()
 display.add_child(fps)
 for value in Settings.FPS:fps.add_item("Unlimited" if value==0 else str(value)+" FPS",int(value))
 label(display,"VSync may limit the frame rate to your monitor’s refresh rate.")

 var audio:=add_page(pages,"Audio")
 audio.add_theme_constant_override("separation",12)
 master=slider(audio,"Master volume")
 effects=slider(audio,"Sound effects volume")
 music=slider(audio,"Music volume")
 ambience=slider(audio,"Ambience volume")

 var controls:=add_page(pages,"Controls")
 var grid:=GridContainer.new()
 grid.columns=3
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 grid.add_theme_constant_override("h_separation",10)
 grid.add_theme_constant_override("v_separation",13)
 var binding_margin:=MarginContainer.new()
 binding_margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for side in ["left","top","right","bottom"]:
  binding_margin.add_theme_constant_override("margin_"+side,8)
 controls.add_child(binding_margin)
 binding_margin.add_child(grid)
 for text in ["Action","Primary","Alternate"]:label(grid,text)
 for action in Settings.ACTIONS:
  label(grid,Settings.ACTIONS[action]);binding_buttons[action]=[]
  for slot in 2:
   var bind:=Button.new()
   grid.add_child(bind)
   bind.custom_minimum_size=Vector2(130,34)
   bind.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   bind.pressed.connect(func():capture_binding(action,slot))
   preload("res://menu_button_roots.gd").attach(bind,func():return draft.get("ambient_motion",true))
   binding_buttons[action].append(bind)
 label(controls,"Select a binding, then press a key or mouse button. Esc cancels. Backspace clears.")
 button(controls,"Reset Controls",func():draft.bindings=Settings.defaults().bindings;refresh_bindings())
 add_page(pages,"Diagnostics").add_child(preload("res://diagnostics_panel.gd").new())

 notice=label(box,"")
 notice.custom_minimum_size.y=30
 var actions:=HBoxContainer.new()
 actions.name="SettingsActions"
 actions.add_theme_constant_override("separation",8)
 box.add_child(actions)
 button(actions,"Restore Defaults",func():draft=Settings.defaults();refresh())
 button(actions,"Back",cancel)
 button(actions,"Apply",save)
 hide()
func add_page(pages: TabContainer, page_name: String) -> VBoxContainer:
 var scroll:=ScrollContainer.new()
 scroll.name=page_name
 scroll.follow_focus=true
 pages.add_child(scroll)
 var content:=VBoxContainer.new()
 content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(content)
 return content

func label(parent: Node,text: String) -> Label:
 var value=Label.new();value.text=text;value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(value);value.custom_minimum_size.x=160;return value
func button(parent: Node,text: String,action: Callable) -> void:
 var value=Button.new();parent.add_child(value);value.text=text;value.size_flags_horizontal=Control.SIZE_EXPAND_FILL;value.pressed.connect(action)
 preload("res://menu_button_roots.gd").attach(value,func():return draft.get("ambient_motion",true))
func check(parent: Node,text: String) -> CheckBox:
 var value=CheckBox.new();parent.add_child(value);value.text=text;return value
func slider(parent: Node,text: String) -> HSlider:
 label(parent,text);var value=HSlider.new();parent.add_child(value);value.min_value=0;value.max_value=100;value.step=1;return value
func begin(settings: RefCounted) -> void:
 model=settings;draft=model.values.duplicate(true);pending_action="";pending_slot=-1;refresh()
 notice.text=""
 var target:=viewport_limit()
 min_size=Vector2i(400,250).min(target)
 popup_centered(target)

func viewport_limit() -> Vector2i:
 var visible_size:=Vector2i(get_tree().root.get_visible_rect().size)
 return Vector2i(810,610).min((visible_size-Vector2i(40,40)).max(Vector2i.ONE))

func fit_to_viewport() -> void:
 if not visible:
  return
 var limit:=viewport_limit()
 min_size=Vector2i(400,250).min(limit)
 popup_centered(size.min(limit))
func refresh() -> void:
 developer_controls.setup(draft.get("developer_mode",false))
 get_meta("garden_motion_toggle").button_pressed=draft.get("ambient_motion",true)
 get_meta("garden_cinematic_toggle").button_pressed=draft.get("garden_cinematics",true)
 fullscreen.button_pressed=draft.fullscreen;vsync.button_pressed=draft.vsync;indicator.button_pressed=draft.aim_indicator;fps.select(fps.get_item_index(int(draft.fps)));master.value=float(draft.master)*100;effects.value=float(draft.effects)*100
 music.value=float(draft.music)*100
 ambience.value=float(draft.ambience)*100
 refresh_bindings()
func refresh_bindings() -> void:
 for action in binding_buttons:
  for slot in 2:binding_buttons[action][slot].text=Settings.binding_text(draft.bindings[action][slot] if slot<draft.bindings[action].size() else {})
func capture_binding(action: String,slot: int) -> void:
 pending_action=action;pending_slot=slot;notice.text="Binding "+Settings.ACTIONS[action]+": press a key or mouse button. Escape cancels; Backspace clears."
func assign_binding(item: Dictionary) -> bool:
 if pending_action.is_empty():return false
 if not item.is_empty():
  if item.kind=="key" and int(item.code)==KEY_ESCAPE and pending_action!="session_menu":notice.text="Escape is reserved for closing menus.";return false
  for action in draft.bindings:
   for slot in draft.bindings[action].size():
    if action==pending_action and slot==pending_slot:continue
    if draft.bindings[action][slot]==item:notice.text="Already used by "+Settings.ACTIONS[action]+". Clear that binding first.";return false
 var values: Array=draft.bindings[pending_action].duplicate()
 while values.size()<=pending_slot:values.append({})
 values[pending_slot]=item;draft.bindings[pending_action]=values
 pending_action="";pending_slot=-1;refresh_bindings();notice.text="Binding updated. Apply to save.";return true
func _input(event: InputEvent) -> void:
 if not visible:return
 if not pending_action.is_empty():
  if event is InputEventKey and event.pressed and not event.echo:
   if event.keycode==KEY_ESCAPE:pending_action="";refresh_bindings();notice.text="Binding cancelled.";get_viewport().set_input_as_handled();return
   assign_binding({} if event.keycode==KEY_BACKSPACE else {"kind":"key","code":int(event.physical_keycode if event.physical_keycode else event.keycode)});get_viewport().set_input_as_handled()
  elif event is InputEventMouseButton and event.pressed and int(event.button_index) in [1,2,3,8,9]:assign_binding({"kind":"mouse","code":int(event.button_index)});get_viewport().set_input_as_handled()
 elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:cancel();get_viewport().set_input_as_handled()
func save() -> void:
 draft.developer_mode = developer_controls.toggle.button_pressed
 draft.ambient_motion=get_meta("garden_motion_toggle").button_pressed
 draft.garden_cinematics=get_meta("garden_cinematic_toggle").button_pressed
 if not pending_action.is_empty():notice.text="Finish or cancel the current binding first.";return
 draft.fullscreen=fullscreen.button_pressed;draft.vsync=vsync.button_pressed;draft.aim_indicator=indicator.button_pressed;draft.fps=fps.get_selected_id();draft.master=master.value/100.;draft.effects=effects.value/100.
 draft.music=music.value/100.0
 draft.ambience=ambience.value/100.0
 if model.save_settings(draft)!=OK:notice.text="Could not save settings. Your previous settings are preserved.";return
 applied.emit();hide()
func cancel() -> void:
 pending_action="";pending_slot=-1;hide()
