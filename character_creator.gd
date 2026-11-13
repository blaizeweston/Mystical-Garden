extends Window
signal confirmed
var create_button: Button
var close_on_submit := true
const Appearance=preload("res://character_appearance.gd")
const Classes=preload("res://class_catalog.gd")
signal submitted(character_name: String,class_id: int,appearance: Array)
var name_field: LineEdit
var class_choice: OptionButton
var options: Array[OptionButton]=[]
var actor: Dictionary={}
var description: Label
var model_choice: OptionButton
var sliders: Array[HSlider]=[]

func _ready() -> void:
 title="Create a character";transient=true;unresizable=true;min_size=Vector2i(760,540);wrap_controls=false
 var panel:=PanelContainer.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.add_theme_stylebox_override("panel",preload("res://root_ui.gd").root_style())
 var outer:=VBoxContainer.new();panel.add_child(outer);outer.add_theme_constant_override("separation",16)
 var row:=HBoxContainer.new();outer.add_child(row);row.size_flags_vertical=Control.SIZE_EXPAND_FILL
 row.add_theme_constant_override("separation",24)
 var view_container:=SubViewportContainer.new();row.add_child(view_container)
 view_container.custom_minimum_size=Vector2(280,340);view_container.stretch=true
 var viewport:=SubViewport.new();view_container.add_child(viewport)
 viewport.own_world_3d=true;viewport.transparent_bg=true
 actor=preload("res://traveller_avatar.gd").build(viewport)
 actor.model.rotation.y=.38
 var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,1.5,3.6);camera.look_at(Vector3(0,.9,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.15;camera.current=true
 var light:=DirectionalLight3D.new();viewport.add_child(light);light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.3
 var environment:=WorldEnvironment.new();viewport.add_child(environment);environment.environment=Environment.new()
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("#bcc9b2");environment.environment.ambient_light_energy=.7
 var scroll:=ScrollContainer.new();row.add_child(scroll);scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var form:=VBoxContainer.new();scroll.add_child(form);form.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var name_label:=Label.new();form.add_child(name_label);name_label.text="Character name"
 name_field=LineEdit.new();form.add_child(name_field);name_field.max_length=24;name_field.placeholder_text="Name your traveller"
 var class_label:=Label.new();form.add_child(class_label);class_label.text="Class"
 class_choice=OptionButton.new();form.add_child(class_choice)
 for definition in Classes.DEFINITIONS: class_choice.add_item(definition.name)
 class_choice.item_selected.connect(func(_index): update_preview())
 description=Label.new();form.add_child(description);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.custom_minimum_size=Vector2(310,42)
 var grid:=GridContainer.new();form.add_child(grid);grid.columns=2;grid.add_theme_constant_override("h_separation",16)
 for i in Appearance.LABELS.size():
  var label:=Label.new();grid.add_child(label);label.text=Appearance.LABELS[i]
  var choice:=OptionButton.new();grid.add_child(choice);choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  for value in Appearance.OPTIONS[i]: choice.add_item(value)
  choice.item_selected.connect(func(_index):update_preview());options.append(choice)
 model_choice=OptionButton.new();form.add_child(model_choice);model_choice.add_item("Male");model_choice.add_item("Female");model_choice.item_selected.connect(func(_i):update_preview())
 for title_text in Appearance.SLIDERS:
  var label:=Label.new();form.add_child(label);label.text=title_text
  var slider:=HSlider.new();form.add_child(slider);slider.min_value=0;slider.max_value=100;slider.step=1;slider.value=50;slider.custom_minimum_size=Vector2(320,20);slider.value_changed.connect(func(v):label.text=title_text+" · "+str(int(v));update_preview());sliders.append(slider)
 var reset:=Button.new();form.add_child(reset);reset.text="Reset proportions";reset.pressed.connect(func():
  for slider in sliders: slider.value=50
  update_preview())
 var turn_label:=Label.new();form.add_child(turn_label);turn_label.text="Rotate preview"
 var turn:=HSlider.new();form.add_child(turn);turn.min_value=-180;turn.max_value=180;turn.value=22;turn.tooltip_text="Rotate preview";turn.value_changed.connect(func(v):actor.model.rotation.y=deg_to_rad(v))
 name_field.text_changed.connect(func(_text): get_ok_button().disabled=preload("res://character_profile.gd").clean_name(name_field.text).is_empty())
 var buttons:=HBoxContainer.new();outer.add_child(buttons);buttons.alignment=BoxContainer.ALIGNMENT_END
 var cancel:=Button.new();buttons.add_child(cancel);cancel.text="Cancel";cancel.custom_minimum_size=Vector2(130,42);cancel.pressed.connect(dismiss)
 create_button=Button.new();buttons.add_child(create_button);create_button.text="Create Character";create_button.custom_minimum_size=Vector2(190,42);create_button.pressed.connect(func():confirmed.emit())
 confirmed.connect(func():
  if close_on_submit: dismiss()
  submitted.emit(name_field.text,class_choice.selected,appearance()))
 close_requested.connect(dismiss)
 update_preview();hide()

func dismiss() -> void:
 hide();exclusive=false

func get_ok_button() -> Button:
 return create_button

func appearance() -> Array:
 var values: Array=[]
 for option in options: values.append(option.selected)
 values.append(model_choice.selected)
 for slider in sliders: values.append(int(slider.value))
 return values
func update_preview() -> void:
 if not actor.is_empty() and model_choice!=null and sliders.size()==7: Appearance.apply(actor,appearance())
 description.text=Classes.DEFINITIONS[class_choice.selected].description+"\nClass choices can also be changed at the Heart."
func _process(delta: float) -> void:
 if visible and not actor.is_empty():
  actor.phase+=delta*3.0
  preload("res://traveller_avatar.gd").animate(actor,false,0.0,"",{},delta)
func begin(profile: Dictionary={}) -> void:
 var look=Appearance.normalize(profile.get("appearance",[]))
 name_field.text=profile.get("name","");class_choice.select(profile.get("active_class",0))
 for i in options.size(): options[i].select(look[i])
 model_choice.select(look[5])
 for i in sliders.size(): sliders[i].value=look[i+6]
 create_button.text="Save Character" if not profile.is_empty() else "Create Character"
 title="Customize character" if not profile.is_empty() else "Create a character"
 update_preview();get_ok_button().disabled=name_field.text.is_empty();exclusive=true;popup_centered(Vector2i(900,640));name_field.grab_focus()
