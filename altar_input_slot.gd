extends "res://inventory_slot.gd"
var offering_index: int=-1
func drag_payload() -> Dictionary:
 if offering_index<0: return super.drag_payload()
 return {"type":"garden_item_stack","source":entry.get("origin","stash"),"item":entry.get("item",""),"quantity":1,"offering_index":offering_index,"key":""}
func _gui_input(event: InputEvent) -> void:
 if offering_index>=0 and not entry.is_empty() and event.is_action_pressed("ui_accept"):
  view.clear_input(offering_index);accept_event();return
 if offering_index>=0 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  # A simple click removes a reservation. Moving the mouse starts a drag instead.
  if event.double_click: view.clear_input(offering_index);accept_event();return
 super._gui_input(event)
