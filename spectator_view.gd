extends Node

const Participation = preload("res://expedition_participation.gd")
const Life=preload("res://expedition_life.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
var game: Node
var target_id:=0
var panel: PanelContainer
var caption: Label
var next_button: Button
var was_fallen:=false
func _ready() -> void:
 game=get_parent()
 var layer:=CanvasLayer.new();layer.layer=4;add_child(layer)
 panel=PanelContainer.new();layer.add_child(panel);panel.add_theme_stylebox_override("panel",preload("res://root_ui.gd").root_style(true))
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);panel.position=Vector2(330,65)
 var column:=VBoxContainer.new();panel.add_child(column)
 caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.custom_minimum_size=Vector2(410,0);column.add_child(caption)
 next_button=Button.new();next_button.text="Watch next ally";column.add_child(next_button);next_button.pressed.connect(cycle)
 panel.hide()
func cycle() -> void:
 var ids:=Life.living_ids(game)
 if ids.is_empty(): target_id=0;return
 target_id=ids[(ids.find(target_id)+1)%ids.size()]
func focus_id(local_id: int) -> int:
 var p: Dictionary=game.players.get(local_id,{})
 var fallen: bool=Participation.is_wild(p) and PlayerLifecycle.fallen(p)
 panel.position=Vector2((game.get_viewport().get_visible_rect().size.x-430)/2.0,114 if Life.Preview.enabled else 65)
 panel.visible=fallen and not game.overlay.visible
 if fallen and not was_fallen: game.toggle_overlay(null)
 was_fallen=fallen
 if not fallen: target_id=0;return local_id
 var ids:=Life.living_ids(game)
 if not ids.has(target_id): target_id=ids[0] if not ids.is_empty() else 0
 var target: Dictionary=game.players.get(target_id,{})
 var cost: String="%d maximum HP"%Life.Preview.revive_cost() if Life.Preview.enabled else "one maximum heart"
 var watched: String=target.get("character",{}).get("name",target.get("display_name","ally"))
 if Life.Preview.enabled and not target.is_empty():
  watched+=" · %d / %d HP"%[int(PlayerVitals.current_hp(target)),PlayerVitals.maximum_hp(target)]
 caption.text="FALLEN · Watching %s\nA teammate can revive you nearby with E.\nRevival sacrifices %s until the Garden."%[watched,cost]
 next_button.visible=ids.size()>1
 return target_id if target_id!=0 else local_id
