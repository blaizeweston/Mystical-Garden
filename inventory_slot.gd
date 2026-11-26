extends PanelContainer
const Items=preload("res://item_catalog.gd")
const UI=preload("res://root_ui.gd")
var view: Control
var entry: Dictionary={}
var bucket: String=""
var texture: Texture2D
var selected := false
func setup(owner_view: Control,value: Dictionary,source: String,dimension: int=64) -> void:
 view=owner_view;entry=value;bucket=source
 custom_minimum_size=Vector2(dimension,dimension)
 mouse_filter=Control.MOUSE_FILTER_STOP
 focus_mode=Control.FOCUS_NONE if entry.is_empty() else Control.FOCUS_ALL
 focus_entered.connect(func():
  if not entry.is_empty():view.select_entry(entry)
  queue_redraw())
 focus_exited.connect(queue_redraw)
 var style:=StyleBoxFlat.new();style.bg_color=Color("#152016");style.set_corner_radius_all(3);style.set_border_width_all(2)
 style.border_color=Items.color(str(entry.item)) if not entry.is_empty() else Color("#43543c")
 add_theme_stylebox_override("panel",style)
 if not entry.is_empty():
  var definition:=Items.get_item(str(entry.item))
  var lines:=PackedStringArray(["%s · %s"%[definition.name,definition.rarity]])
  if bucket in ["stash","shared"]:
   var free:=int(entry.get("free",entry.quantity))
   lines.append("%s · %d available"%["Shared Garden" if bucket=="shared" else "Personal stash",free])
   if free<int(entry.quantity):lines.append("%d reserved for equipment or cargo"%(int(entry.quantity)-free))
  lines.append(Items.describe(definition).get_slice("\nSupporting affinities",0))
  if not definition.tags.is_empty():lines.append("Affinities: "+", ".join(definition.tags))
  if not definition.monster_tags.is_empty():lines.append("Monster traits: "+", ".join(definition.monster_tags))
  tooltip_text="\n".join(lines)
  var icon:=str(definition.get("icon",""))
  if not icon.is_empty() and ResourceLoader.exists(icon): texture=load(icon)
 queue_redraw()
func _make_custom_tooltip(text: String) -> Control:
 return UI.item_tooltip(text,get_viewport_rect().size.x)
func set_selected(value: bool) -> void:
 selected=value;queue_redraw()
func _draw() -> void:
 if entry.is_empty():
  draw_string(ThemeDB.fallback_font,Vector2(size.x/2-5,size.y/2+5),"+" if bucket=="pouch" else "",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#66735a"));return
 var id:=str(entry.item);var definition:=Items.get_item(id);var color:=Items.color(id)
 var middle:=Vector2(size.x/2,size.y/2-3)
 if texture!=null: draw_texture_rect(texture,Rect2(middle-Vector2(22,22),Vector2(44,44)),false)
 elif definition.category=="monster_part":
  for i in 3:
   var start:=middle+Vector2(-13+i*10,12)
   var points:=PackedVector2Array([start,start+Vector2(-2,-12),start+Vector2(6,-25)])
   draw_polyline(points,color,4,true)
 else:
  draw_set_transform(middle,-.25,Vector2(.7,1))
  draw_circle(Vector2.ZERO,15,color.darkened(.2));draw_arc(Vector2.ZERO,13,-PI/2,PI/2,16,color,2,true)
  draw_set_transform(Vector2.ZERO)
  if id=="unidentified_seed": draw_string(ThemeDB.fallback_font,middle+Vector2(-4,5),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#132014"))
 var marker: String="Shared" if bucket=="shared" else "Personal" if bucket=="stash" else "Trophy" if definition.category=="monster_part" else "Seed" if definition.category=="seed" else "Part"
 if bucket!="equipment":draw_string(ThemeDB.fallback_font,Vector2(4,12),marker,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#ddd8bd"))
 var reserved:=int(entry.quantity)-int(entry.get("free",entry.quantity))
 if reserved>0:
  draw_string_outline(ThemeDB.fallback_font,Vector2(4,size.y-5),"R%d"%reserved,HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,Color.BLACK)
  draw_string(ThemeDB.fallback_font,Vector2(4,size.y-5),"R%d"%reserved,HORIZONTAL_ALIGNMENT_LEFT,-1,10,UI.ACCENT)
 var text:=str(entry.quantity)
 var width:=ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
 draw_string_outline(ThemeDB.fallback_font,Vector2(size.x-width-5,size.y-5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color.BLACK)
 draw_string(ThemeDB.fallback_font,Vector2(size.x-width-5,size.y-5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#eee7cb"))
 if selected or has_focus():draw_rect(Rect2(Vector2(1,1),size-Vector2(2,2)),UI.ACCENT,false,3.0)
func _gui_input(event: InputEvent) -> void:
 if entry.is_empty(): return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  grab_focus();view.select_entry(entry)
 elif event.is_action_pressed("ui_accept"):
  view.select_entry(entry);accept_event()
func _get_drag_data(_at: Vector2):
 if entry.is_empty() or bucket=="equipment": return null
 var data:=drag_payload()
 if int(data.quantity)<=0:return null
 var label:=Label.new();label.text="%s × %d"%[Items.get_item(str(entry.item)).name,int(data.quantity)]
 label.add_theme_color_override("font_color",Items.color(str(entry.item)))
 set_drag_preview(label)
 return data
func drag_payload() -> Dictionary:
 var free:=int(entry.get("free",entry.get("quantity",0)))
 return {"type":"garden_item_stack","source":bucket,"item":entry.get("item",""),"quantity":mini(1,free) if Input.is_key_pressed(KEY_SHIFT) else free,"key":entry.get("key","")}
func _can_drop_data(_at: Vector2,data) -> bool:
 return view.can_accept(bucket,data)
func _drop_data(_at: Vector2,data) -> void:
 view.move_stack(bucket,data,str(entry.get("key","")))
