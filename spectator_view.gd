extends Node
## Owns spectator selection and controls; receives no gameplay actor records.
signal refresh_requested(local_id: int)
var _ui: Node
var _facts: Dictionary={}
var _target_id:=0
var _local_id:=0
var _was_fallen:=false
var panel: PanelContainer
var caption: Label
var next_button: Button

func configure(ui: Node) -> void:
	_ui=ui

func present(facts: Dictionary) -> void:
	_facts=facts.duplicate(true)

func target_peer() -> int:
	return _target_id

func hide_panel() -> void:
	panel.hide()

func _ready() -> void:
	var layer:=CanvasLayer.new();layer.layer=4;add_child(layer)
	panel=PanelContainer.new();layer.add_child(panel);panel.add_theme_stylebox_override("panel",preload("res://root_ui.gd").root_style(true))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);panel.position=Vector2(330,65)
	var column:=VBoxContainer.new();panel.add_child(column)
	caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.custom_minimum_size=Vector2(410,0);column.add_child(caption)
	next_button=Button.new();next_button.text="Watch next ally";column.add_child(next_button);next_button.pressed.connect(cycle)
	panel.hide()

func cycle() -> void:
	refresh_requested.emit(_local_id)
	var ids: Array=[]
	for person in _facts.get("living",[]):ids.append(int(person.id))
	if ids.is_empty():_target_id=0;return
	_target_id=ids[(ids.find(_target_id)+1)%ids.size()]

func focus_id(local_id: int) -> int:
	_local_id=local_id
	refresh_requested.emit(local_id)
	var fallen:=bool(_facts.get("fallen",false))
	panel.position=Vector2((get_viewport().get_visible_rect().size.x-430)/2.0,114)
	panel.visible=fallen and not _ui.is_overlay_open()
	# The committed report can arrive before the snapshot that moves its
	# recipient out of the Wilds. Keep it open through the waiting-state edge.
	if fallen and not _was_fallen and not _ui.panel_is_open("expedition_results"):
		_ui.close_panels()
	_was_fallen=fallen
	if not fallen:_target_id=0;return local_id
	var living: Array=_facts.get("living",[])
	var target: Dictionary={}
	for person in living:
		if int(person.id)==_target_id:target=person;break
	if target.is_empty():
		target=living[0] if not living.is_empty() else {}
		_target_id=int(target.get("id",0))
	var watched:=str(target.get("name","ally"))
	if not target.is_empty():watched+=" · %d / %d HP"%[int(target.hp),int(target.max_hp)]
	caption.text="FALLEN · Watching %s\nA teammate can revive you nearby with E.\nRevival sacrifices %d maximum HP until the Garden."%[watched,int(_facts.get("revive_cost",0))]
	next_button.visible=living.size()>1
	return _target_id if _target_id!=0 else local_id
