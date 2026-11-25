extends MarginContainer
var world: Node
var opened := true
var box := VBoxContainer.new()
var fight := Button.new()

func _ready() -> void:
	position = Vector2(16,64)
	add_theme_constant_override("margin_left",10)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Developer Testing Arena"
	box.add_child(title)
	fight.text = "Start testing"
	fight.pressed.connect(toggle)
	box.add_child(fight)
	var leave := Button.new()
	leave.text = "Return to Developer Garden"
	leave.pressed.connect(world.session.close)
	box.add_child(leave)
	fight.grab_focus()

func toggle() -> void:
	opened = not opened
	visible = opened
	world.mouse_controls.release(world)
	if opened: fight.grab_focus()
