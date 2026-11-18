extends CenterContainer
signal inventory_drop_requested(data: Dictionary)
var _inventory_panel: PanelContainer

func bind_inventory_panel(panel: PanelContainer) -> void:
	_inventory_panel = panel

func _can_drop_data(_at: Vector2, data) -> bool:
	if not is_instance_valid(_inventory_panel) or not _inventory_panel.visible: return false
	if _inventory_panel.get_global_rect().has_point(get_global_mouse_position()): return false
	return data is Dictionary and data.get("type","")=="garden_item_stack" and data.get("source","") in ["carry","pouch","stash","shared"]

func _drop_data(_at: Vector2, data) -> void:
	inventory_drop_requested.emit({"source":str(data.source),"item":str(data.item),"quantity":int(data.quantity)})
