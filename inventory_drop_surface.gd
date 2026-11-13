extends CenterContainer
var game: Node
func _can_drop_data(_at: Vector2,data) -> bool:
 if game==null or game.inventory_view==null or not game.pack_menu.visible: return false
 if game.pack_menu.get_global_rect().has_point(get_global_mouse_position()): return false
 return data is Dictionary and data.get("type","")=="garden_item_stack" and data.get("source","") in ["carry","pouch","stash","shared"]
func _drop_data(_at: Vector2,data) -> void:
 game.send_inventory_action("drop",str(data.source),"",str(data.item),int(data.quantity))
