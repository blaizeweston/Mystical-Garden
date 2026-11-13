extends Window

const Settings = preload("res://network_settings.gd")
signal applied(address: String, port: int, join: bool)

var address_field: LineEdit
var port_field: SpinBox
var feedback: Label
var submit: Button
var joining := false
var close_on_apply := true
var share_port := 0
var form: GridContainer
var address_label: Label
var instructions: Label
var share: VBoxContainer
var lan_choices: OptionButton
var public_address: LineEdit
var close_button: Button


func _ready() -> void:
	transient = true
	unresizable = true
	min_size = Vector2i(560,0)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",preload("res://root_ui.gd").root_style())
	var content := VBoxContainer.new()
	panel.add_child(content)
	content.add_theme_constant_override("separation",12)

	instructions = wrap_label(content)
	form = GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation",16)
	form.add_theme_constant_override("v_separation",8)
	content.add_child(form)
	address_label = Label.new()
	address_label.text = "Host address"
	form.add_child(address_label)
	address_field = LineEdit.new()
	address_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_field.placeholder_text = "192.168.1.20 or 192.168.1.20:24576"
	address_field.max_length = 80
	form.add_child(address_field)
	var port_label := Label.new()
	port_label.text = "UDP port"
	form.add_child(port_label)
	port_field = SpinBox.new()
	port_field.min_value = 1024
	port_field.max_value = 65535
	port_field.step = 1
	form.add_child(port_field)

	share = VBoxContainer.new()
	share.add_theme_constant_override("separation",8)
	content.add_child(share)
	wrap_label(share).text = "Same network"
	var lan_row := HBoxContainer.new()
	share.add_child(lan_row)
	lan_choices = OptionButton.new()
	lan_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_row.add_child(lan_choices)
	var copy_lan := Button.new()
	copy_lan.text = "Copy address"
	lan_row.add_child(copy_lan)
	copy_lan.pressed.connect(func(): copy_endpoint(lan_choices.get_item_text(lan_choices.selected)))
	wrap_label(share).text = "Over the internet"
	var internet_row := HBoxContainer.new()
	share.add_child(internet_row)
	public_address = LineEdit.new()
	public_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_address.placeholder_text = "Public IP or IP:port"
	public_address.max_length = 64
	internet_row.add_child(public_address)
	var copy_public := Button.new()
	copy_public.text = "Copy address"
	internet_row.add_child(copy_public)
	copy_public.pressed.connect(func(): copy_endpoint(public_address.text))
	wrap_label(share).text = "Allow the game through the host firewall. If your router requires forwarding, send its UDP port to the host port above. Share the router’s public IP and port."

	feedback = wrap_label(content)
	feedback.custom_minimum_size.y = 34
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)
	close_button = Button.new()
	close_button.custom_minimum_size = Vector2(110,40)
	buttons.add_child(close_button)
	close_button.pressed.connect(dismiss)
	submit = Button.new()
	submit.custom_minimum_size = Vector2(140,40)
	buttons.add_child(submit)
	submit.pressed.connect(confirm)
	close_requested.connect(dismiss)
	address_field.text_submitted.connect(func(_text): confirm())
	public_address.text_submitted.connect(func(_text): copy_public.pressed.emit())
	hide()


func wrap_label(parent: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func begin(host: String, port: int, join: bool, character_name: String = "", failure: String = "") -> void:
	joining = join
	share.hide()
	form.show()
	address_label.visible = join
	address_field.visible = join
	address_field.text = host
	port_field.value = port
	feedback.text = failure
	title = ("Join as " + character_name if not character_name.is_empty() else "Join by IP") if join else "Hosting port"
	instructions.text = "Paste the address your host shared, or enter their IP and UDP port." if join else "Choose the UDP port your Garden will listen on when you host."
	submit.show()
	submit.text = "Connect" if join else "Save port"
	close_button.text = "Cancel"
	open_dialog(Vector2i(580,240))
	if join:
		address_field.grab_focus()
		address_field.select_all()
	else:
		port_field.get_line_edit().grab_focus()


func begin_host(port: int, addresses: Array[String], garden: String, open_to_guests: bool) -> void:
	share_port = port
	joining = false
	form.hide()
	share.show()
	submit.hide()
	close_button.text = "Done"
	title = "Share your Garden"
	var availability := "Up to three friends can join while the party is in the Garden." if open_to_guests else "New guests can join after the party returns from the Wilds."
	instructions.text = "%s is hosting on UDP %d.\n%s" % [garden,port,availability]
	lan_choices.clear()
	for host in addresses:
		lan_choices.add_item(Settings.format_endpoint(host,port))
	if lan_choices.item_count == 0:
		lan_choices.add_item(Settings.format_endpoint("127.0.0.1",port))
		feedback.text = "No local network address found. The displayed address is for this PC."
	else:
		feedback.text = ""
	lan_choices.select(0)
	public_address.clear()
	open_dialog(Vector2i(580,340))
	close_button.grab_focus()


func open_dialog(dialog_size: Vector2i) -> void:
	exclusive = true
	popup_centered(dialog_size)


func dismiss() -> void:
	hide()
	exclusive = false


func confirm() -> void:
	port_field.apply()
	var endpoint: Dictionary = Settings.parse_endpoint(address_field.text,int(port_field.value)) if joining else {"address":address_field.text,"port":int(port_field.value),"error":""}
	if not endpoint.error.is_empty():
		feedback.text = endpoint.error
		return
	if close_on_apply: dismiss()
	applied.emit(endpoint.address,endpoint.port,joining)


func copy_endpoint(value: String) -> void:
	var endpoint := Settings.parse_endpoint(value,share_port)
	if not endpoint.error.is_empty():
		feedback.text = "Enter a valid IP address to share."
		return
	var formatted := Settings.format_endpoint(endpoint.address,endpoint.port)
	DisplayServer.clipboard_set(formatted)
	feedback.text = "Copied " + formatted
