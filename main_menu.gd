extends Control
const Slots = preload("res://save_slots.gd")
const Network=preload("res://network_settings.gd")
var network_address:="127.0.0.1"
var network_port:=Network.DEFAULT_PORT
var host_port:=Network.DEFAULT_PORT
var network_dialog: Window
const Characters=preload("res://character_slots.gd")
var characters:=Characters.new()
var app_settings:=preload("res://app_settings.gd").new()
var settings_path: String="user://settings.cfg"
var settings_dialog: Window
var delete_character_button: Button
var character_deletion: ConfirmationDialog
var pending_character_delete: int=-1
var pending_character_digest: String=""
var selected_character:=0
var restore_last_character:=true
var character_buttons: Array[Button]=[]
var character_grid: GridContainer
var create_character_button: Button
var creator: Window
var creating_slot:=-1
var start_garden_after_creation := false
var pending_new_world:=-1
const RootUI = preload("res://root_ui.gd")
var storage := Slots.new()
var selected := 0
var transitioning := false
var content_valid:=true
var refresh_clock := 0.0
var import_legacy := true
var restore_last_selection := true
var return_message := ""
var slot_buttons: Array[Button] = []
var delete_button: Button
var deletion_confirmation: ConfirmationDialog
var pending_delete: int=-1
var continue_button: Button
var new_button: Button
var join_button: Button
var host_choice: CheckBox
var notice: Label
var confirmation: ConfirmationDialog
var pages: Array[VBoxContainer]=[]
var navigation: Array[Button]=[]
var play_character: Label
var coop_character: Label
var character_return_page:=0

func _ready() -> void:
	get_tree().auto_accept_quit = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = RootUI.make_theme()
	if RootUI.Orb.Preview.playtest and storage.root_path=="user://saves":
		storage.root_path=RootUI.Orb.Preview.STORAGE_PATH.path_join("saves")
		settings_path=RootUI.Orb.Preview.STORAGE_PATH.path_join("settings.cfg")
		import_legacy=false
		if return_message.is_empty(): return_message="Combat Balance Preview"
	app_settings.path=settings_path;app_settings.load_settings();app_settings.apply()
	if DisplayServer.get_name() != "headless":
		preload("res://title_music.gd").enter.call_deferred(self)
	settings_dialog=preload("res://settings_panel.gd").new()
	settings_dialog.developer_context=self
	settings_dialog.developer_title=true
	add_child(settings_dialog)
	var error := storage.prepare(import_legacy)
	characters.root_path=storage.root_path.path_join("characters")
	if error==OK: error=characters.prepare(storage)
	if restore_last_character: selected_character=characters.last_slot()
	var endpoint:=Network.load_settings(storage.root_path)
	network_address=endpoint.address
	network_port=endpoint.port
	host_port=endpoint.host_port
	var retry: Dictionary=get_meta("join_return",{})
	if not retry.is_empty():
		network_address=retry.address
		network_port=retry.port
	var backdrop := ColorRect.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
float hash(vec2 p){return fract(sin(dot(p,vec2(41.3,289.1)))*43758.5453);}
void fragment() {
	vec2 p = UV;
	float glow = exp(-length((p-vec2(0.5,0.42))*vec2(1.2,1.0))*3.2);
	float mist = sin(p.x*8.0+TIME*0.08)*sin(p.y*6.0-TIME*0.05)*0.014;
	mist += sin(p.x*17.0-TIME*0.11)*sin(p.y*13.0+TIME*0.07)*0.006;
	vec3 col = mix(vec3(0.02,0.035,0.022), vec3(0.14,0.21,0.09), glow) + mist;
	float motes = 0.0;
	for(int i=0;i<3;i++){
		float fi=float(i);
		vec2 g = p*vec2(9.0+fi*4.0, 9.0+fi*4.0);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		vec2 c = vec2(hash(cell), hash(cell+7.3));
		c.y = fract(c.y - TIME*(0.015+fi*0.01));
		float d = length(f-c);
		motes += (1.0-smoothstep(0.0,0.08,d))*(0.35+0.3*fi);
	}
	col += vec3(0.9,0.85,0.55)*motes*0.07;
	float vig = (1.0-smoothstep(0.35,0.95,length(p-vec2(0.5))));
	col *= mix(0.72, 1.0, vig);
	COLOR = vec4(col, 1.0);
}
"""



	var material := ShaderMaterial.new()
	material.shader = shader
	backdrop.material = material
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var center:=CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout:=HBoxContainer.new()
	layout.add_theme_constant_override("separation",28)
	center.add_child(layout)
	var sidebar:=VBoxContainer.new()
	sidebar.custom_minimum_size.x=220
	sidebar.add_theme_constant_override("separation",12)
	layout.add_child(sidebar)
	var title:=label(sidebar,"MYSTICAL\nGARDEN",38,Color("#ece0ad"))
	RootUI.style_title(title)
	var title_space:=Control.new()
	title_space.custom_minimum_size.y=16
	sidebar.add_child(title_space)
	for index in 3:
		var entry:=button(sidebar,["Play","Characters","Co-op"][index],func():show_page(index))
		entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
		entry.toggle_mode=true
		navigation.append(entry)
	var sidebar_space:=Control.new()
	sidebar_space.size_flags_vertical=Control.SIZE_EXPAND_FILL
	sidebar.add_child(sidebar_space)
	button(sidebar,"Settings",func():settings_dialog.begin(app_settings)).alignment=HORIZONTAL_ALIGNMENT_LEFT
	button(sidebar,"Quit to Desktop",func():get_tree().quit()).alignment=HORIZONTAL_ALIGNMENT_LEFT

	var panel:=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",RootUI.root_style())
	layout.add_child(panel)
	var content:=VBoxContainer.new()
	content.custom_minimum_size=Vector2(700,480)
	content.add_theme_constant_override("separation",12)
	panel.add_child(content)
	for name_text in ["Play","Characters","Co-op"]:
		var page:=VBoxContainer.new()
		page.size_flags_vertical=Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation",12)
		content.add_child(page)
		pages.append(page)
		label(page,name_text,29,RootUI.INK)

	var play:=pages[0]
	play_character=character_row(play,0)
	var garden_row:=HBoxContainer.new()
	play.add_child(garden_row)
	garden_row.add_theme_constant_override("separation",10)
	for index in Slots.COUNT:
		var slot_card:=Button.new()
		garden_row.add_child(slot_card)
		slot_card.custom_minimum_size=Vector2(216,102)
		slot_card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		slot_card.toggle_mode=true
		slot_card.pressed.connect(func():select_slot(index))
		slot_buttons.append(slot_card)
	var actions:=HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	play.add_child(actions)
	continue_button=button(actions,"Continue",continue_game)
	new_button=button(actions,"New Garden",new_game)
	continue_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	new_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var management:=HBoxContainer.new()
	play.add_child(management)
	host_choice=CheckBox.new()
	host_choice.text="Host this Garden in co-op"
	host_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	management.add_child(host_choice)
	delete_button=button(management,"Delete Garden…",request_delete_save)

	var roster:=pages[1]
	var character_scroll:=ScrollContainer.new()
	roster.add_child(character_scroll)
	character_scroll.custom_minimum_size.y=132
	character_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	character_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	character_scroll.follow_focus=true
	var roster_margin:=MarginContainer.new()
	roster_margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","top","right","bottom"]:
		roster_margin.add_theme_constant_override("margin_"+side,8)
	character_scroll.add_child(roster_margin)
	character_grid=GridContainer.new()
	roster_margin.add_child(character_grid)
	character_grid.columns=3
	character_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	character_grid.add_theme_constant_override("h_separation",10)
	character_grid.add_theme_constant_override("v_separation",15)
	var character_actions:=HBoxContainer.new()
	roster.add_child(character_actions)
	create_character_button=button(character_actions,"Create Character",request_create_character)
	create_character_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	delete_character_button=button(character_actions,"Delete Character…",request_delete_character)
	button(roster,"Back",back_from_characters).size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	creator=preload("res://character_creator.gd").new()
	add_child(creator)
	creator.submitted.connect(create_character)

	var coop:=pages[2]
	coop_character=character_row(coop,2)
	join_button=button(coop,"Join by IP",request_ip_join)
	label(coop,"Paste the address your friend shared to join their Garden.",15,RootUI.MUTED)
	var host_row:=HBoxContainer.new()
	coop.add_child(host_row)
	button(host_row,"Choose Garden to Host",func():host_choice.button_pressed=true;show_page(0))
	button(host_row,"Hosting Port",func():network_dialog.begin("",host_port,false))
	label(coop,"To host, choose a Garden and enable co-op before starting or continuing.",15,RootUI.MUTED)
	network_dialog=preload("res://network_panel.gd").new()
	add_child(network_dialog)
	network_dialog.applied.connect(apply_network_settings)

	notice=label(content,return_message,14,Color("#c4c697"))
	notice.custom_minimum_size.y=42
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	show_page(0)
	character_deletion=ConfirmationDialog.new();add_child(character_deletion);character_deletion.title="Delete this character?";character_deletion.ok_button_text="Delete Character";character_deletion.cancel_button_text="Keep Character"
	character_deletion.confirmed.connect(confirm_delete_character)
	character_deletion.canceled.connect(func():pending_character_delete=-1;pending_character_digest="")
	confirmation=ConfirmationDialog.new()
	add_child(confirmation)
	confirmation.title="Start a new Garden?"
	confirmation.ok_button_text="Start New Game"
	confirmation.confirmed.connect(func(): create_and_launch(true))
	deletion_confirmation=ConfirmationDialog.new()
	add_child(deletion_confirmation)
	deletion_confirmation.title="Delete this Garden?"
	deletion_confirmation.ok_button_text="Delete Garden"
	deletion_confirmation.cancel_button_text="Keep Save"
	deletion_confirmation.confirmed.connect(confirm_delete_save)
	deletion_confirmation.canceled.connect(func(): pending_delete=-1)
	if error!=OK:
		notice.text="Could not prepare save slots. Your existing files were left in place."
	if restore_last_selection:
		selected = storage.last_slot()
		if storage.is_active(selected):
			for candidate in Slots.COUNT:
				if not storage.is_active(candidate):
					selected = candidate
					break
	if characters.is_active(selected_character):
		for candidate in characters.count():
			if characters.summary(candidate).exists and not characters.is_active(candidate): selected_character=candidate;break
	refresh_characters()
	select_slot(selected)

	navigation[0].grab_focus()
	call_deferred("validate_build")
	preload("res://menu_button_roots.gd").watch(self,func():return app_settings.values.get("ambient_motion",true))
	if not retry.is_empty():
		show_page(2)
		if retry.open:
			network_dialog.begin(network_address,network_port,true,characters.summary(selected_character).name,return_message)

func show_page(index: int) -> void:
	if index!=1:character_return_page=index
	for i in pages.size():
		pages[i].visible=i==index
		navigation[i].set_pressed_no_signal(i==index)
	if is_instance_valid(navigation[index]):navigation[index].grab_focus()

func character_row(page: VBoxContainer,return_page: int) -> Label:
	var row:=HBoxContainer.new()
	page.add_child(row)
	var summary:=label(row,"",16,RootUI.INK)
	summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	summary.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	button(row,"Choose Character",func():character_return_page=return_page;show_page(1))
	return summary

func back_from_characters() -> void:
	show_page(character_return_page)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not pages[0].visible:
		if pages[1].visible:back_from_characters()
		else:show_page(0)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	refresh_clock += delta
	if refresh_clock >= 1.0 and not transitioning:
		refresh_clock = 0.0
		refresh_characters()
		select_slot(selected)


func label(parent: Node,value: String,font_size: int,color: Color) -> Label:
	var node:=Label.new()
	parent.add_child(node)
	node.text=value
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	return node

func button(parent: Node,text: String,callback: Callable) -> Button:
	var node:=Button.new()
	parent.add_child(node)
	node.text=text
	node.custom_minimum_size=Vector2(175,44)
	node.pressed.connect(callback)
	return node

func select_slot(slot: int) -> void:
	selected=slot
	for i in Slots.COUNT:
		var data:=storage.summary(i)
		slot_buttons[i].button_pressed=i==selected
		slot_buttons[i].text="SLOT %d\n\n" % (i+1) + (
			"In use in another window" if data.active else "Save needs attention" if data.error!=OK else
			"Knowledge %d · %d plots\nDeepest encounter %d" % [data.knowledge,data.plots,data.best] if data.exists else
			"Empty Garden\nA fresh beginning")
	var current:=storage.summary(selected)
	var character:=characters.summary(selected_character)
	var ready: bool=character.exists and character.error==OK and not character.active
	continue_button.disabled=not content_valid or not ready or not current.exists or current.error!=OK or current.active
	delete_button.disabled=transitioning or current.active or not current.exists
	new_button.disabled=not content_valid or character.error!=OK or character.active or current.active
	join_button.disabled=not content_valid or not ready
	host_choice.disabled=current.active

func character_ready() -> bool:
	var data:=characters.summary(selected_character)
	return data.exists and data.error==OK and not data.active

func refresh_characters() -> void:
	if character_buttons.size()!=characters.count():
		for child in character_grid.get_children(): child.free()
		character_buttons.clear()
		for i in characters.count():
			var option:=Button.new();character_grid.add_child(option)
			option.toggle_mode=true;option.clip_text=true;option.custom_minimum_size=Vector2(210,84);option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			option.pressed.connect(func():select_character(i));character_buttons.append(option)
	for i in character_buttons.size():
		var data:=characters.summary(i)
		character_buttons[i].button_pressed=i==selected_character
		character_buttons[i].tooltip_text=data.name
		character_buttons[i].text="CHARACTER %d\n%s\n%s"%[i+1,data.name,"In use in another window" if data.active else "Profile needs attention" if data.error!=OK else "%s · Level %d"%[data.class_name,data.level] if data.exists else "Create your traveller"]
	var chosen:=characters.summary(selected_character)
	var summary: String="Playing as %s · %s · Level %d"%[chosen.name,chosen.class_name,chosen.level] if character_ready() else "Choose an available character to play."
	play_character.text=summary
	coop_character.text=summary
	delete_character_button.disabled=chosen.active or not chosen.exists or transitioning
	create_character_button.disabled=chosen.active or chosen.error!=OK or transitioning
	create_character_button.text="Create Character" if not chosen.exists else "Customize: %s · %s"%[chosen.name,chosen.class_name]

func select_character(slot: int) -> void:
	if slot<0 or slot>=characters.count(): return
	selected_character=slot;characters.remember(slot);refresh_characters();select_slot(selected)

func request_create_character(start_garden := false) -> void:
	if transitioning or create_character_button.disabled: return
	creating_slot=selected_character
	start_garden_after_creation=start_garden
	var profile=preload("res://character_profile.gd").new();profile.path=characters.paths(creating_slot).character
	if characters.summary(creating_slot).exists and profile.load_profile()==OK: creator.begin(profile.data)
	else: creator.begin()

func create_character(character_name: String,class_id: int,appearance: Array) -> void:
	var target:=creating_slot;creating_slot=-1
	var start_garden:=start_garden_after_creation;start_garden_after_creation=false
	var error: Error=characters.update(target,character_name,class_id,appearance) if characters.summary(target).exists else characters.create(target,character_name,class_id,appearance)
	if error!=OK: notice.text="Could not create this character (error %d). Existing profiles are preserved."%error
	else: selected_character=target;characters.remember(target);notice.text="%s is ready. Choose a Garden to start, continue, or join."%characters.summary(target).name
	refresh_characters();select_slot(selected)
	if error==OK and start_garden: new_game.call_deferred()

func new_game() -> void:
	if transitioning or new_button.disabled: return
	if not character_ready():
		request_create_character(true)
		return
	var data:=storage.summary(selected)
	if data.exists:
		pending_new_world=selected
		confirmation.dialog_text="Replace Garden Slot %d with a new world? Characters keep their progression. The old Garden will be backed up."%(selected+1)
		confirmation.popup_centered(Vector2i(520,180))
	else: create_and_launch(false)

func create_and_launch(confirmed: bool) -> void:
	if transitioning or not character_ready(): return
	if confirmed and pending_new_world>=0: selected=pending_new_world;pending_new_world=-1
	var error:=storage.new_world(selected,confirmed)
	if error!=OK: notice.text="Could not create this Garden (error %d)."%error;select_slot(selected);return
	launch(false)

func continue_game() -> void:
	if not continue_button.disabled: launch(false)

func join_game() -> void:
	if not transitioning and not join_button.disabled: launch(true)

func launch(join: bool) -> void:
	preload("res://diagnostic_journal.gd").event("menu","world_launch",{"join":join,"world_slot":selected,"character_slot":selected_character})
	if transitioning:
		return
	if not character_ready(): notice.text="Choose an available character first.";return
	var profile_error:=characters.claim(selected_character)
	if profile_error!=OK: notice.text="This character is already in use. Choose another character.";refresh_characters();select_slot(selected);return
	if not join:
		var slot_error:=storage.claim(selected)
		if slot_error!=OK:
			characters.release(selected_character);notice.text="This Garden is already in use. Choose another Garden.";select_slot(selected);return
	transitioning=true
	if network_dialog.visible:
		network_dialog.dismiss()
	storage.remember_slot(selected);characters.remember(selected_character)
	var location:=storage.paths(selected)
	var game=load("res://world.tscn").instantiate()
	game.settings_path=settings_path
	game.network_address=network_address;game.network_port=network_port if join else host_port
	game.active_slot=selected
	game.active_character_slot=selected_character;game.character_slot_claimed=true;game.character_storage_root=characters.root_path
	game.slot_claimed=not join
	game.slot_storage_root=storage.root_path
	game.progress.path=location.garden
	game.local_character.path=characters.paths(selected_character).character
	game.guest_character.path=characters.paths(selected_character).character
	game.joined_from_title=join
	get_tree().root.add_child(game)
	get_tree().current_scene=game
	preload("res://title_music.gd").set_playing(get_tree(),false)
	if join:
		var error: int=game.join_game()
		if error!=OK:
			game.return_to_main_menu(game.status)
	elif host_choice.button_pressed:
		game.host_button.pressed.emit()
	queue_free()


func request_delete_save() -> void:
	if transitioning or delete_button.disabled: return
	var data:=storage.summary(selected)
	if data.active or not data.exists: return
	pending_delete=selected
	deletion_confirmation.dialog_text="Delete Garden Slot %d? Its world progress will be removed, with a recovery copy kept. Your characters and their progression will remain available."%(pending_delete+1)
	deletion_confirmation.popup_centered(Vector2i(560,200))

func confirm_delete_save() -> void:
	var target:=pending_delete
	pending_delete=-1
	if transitioning or target<0: return
	var error:=storage.delete_world(target,true)
	if error==OK: notice.text="Garden Slot %d deleted. Your characters are preserved."%(target+1)
	elif error==ERR_BUSY: notice.text="Slot %d is in use in another window. Close that game before deleting it."%(target+1)
	else: notice.text="Could not delete Slot %d (error %d). Recovery files remain in the slot's backups folder."%[target+1,error]
	select_slot(selected)

func validate_build() -> void:
	var errors: Array=preload("res://content_validator.gd").validate()
	if errors.is_empty(): return
	content_valid=false
	notice.text="This build has invalid content. Please use a validated game copy. Details are in the game log."
	for message in errors: push_error(str(message))
	new_button.disabled=true;continue_button.disabled=true;join_button.disabled=true

func request_ip_join() -> void:
	if not transitioning and not join_button.disabled: network_dialog.begin(network_address,network_port,true,characters.summary(selected_character).name)

func apply_network_settings(address: String,port: int,join: bool) -> void:
	var error:=Network.save_settings(storage.root_path,address,port,join)
	if join:
		network_address=address
		network_port=port
		join_game()
	else:
		host_port=port
		notice.text="Hosting port set to UDP %d."%port if error==OK else "The hosting port could only be set for this session."

func request_delete_character() -> void:
	if transitioning or delete_character_button.disabled:return
	var data=characters.summary(selected_character)
	if data.active or not data.exists:return
	pending_character_delete=selected_character
	pending_character_digest=FileAccess.get_sha256(characters.paths(selected_character).character)
	character_deletion.dialog_text="Delete %s in Character Slot %d? Their class progression and familiarity will be removed. Gardens remain unchanged. A recovery copy will be kept."%[data.name,selected_character+1]
	character_deletion.popup_centered(Vector2i(570,210))
func confirm_delete_character() -> void:
	var target=pending_character_delete;var digest=pending_character_digest;pending_character_delete=-1;pending_character_digest=""
	if transitioning or target<0:return
	var error=characters.delete_character(target,true,digest)
	notice.text="Character Slot %d deleted. Your Gardens are preserved."%(target+1) if error==OK else "That character changed or is in use. Reopen the confirmation." if error==ERR_BUSY else "Could not delete this character. Existing files are preserved (error %d)."%error
	refresh_characters();select_slot(selected)
