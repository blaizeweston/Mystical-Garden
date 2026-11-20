@tool
extends PanelContainer
## Scene-editable padding with the existing shared root artwork and margins.
## Layout and text live in the scene; root_ui.gd remains the styling authority.
const Style = preload("res://root_ui.gd")

@export var content_padding := Vector2(20,14):
	set(value):
		content_padding = value
		if is_inside_tree(): _apply_frame()

func _ready() -> void:
	_apply_frame()

func _apply_frame() -> void:
	var frame := Style.root_style()
	frame.content_margin_left = maxf(18.0,content_padding.x)
	frame.content_margin_right = maxf(18.0,content_padding.x)
	frame.content_margin_top = maxf(16.0,content_padding.y)
	frame.content_margin_bottom = maxf(16.0,content_padding.y)
	add_theme_stylebox_override("panel",frame)
