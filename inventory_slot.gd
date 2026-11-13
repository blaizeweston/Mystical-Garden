extends PanelContainer
const Items=preload("res://item_catalog.gd")
var view: Control
var entry: Dictionary={}
var bucket: String=""
var texture: Texture2D
func setup(owner_view: Control,value: Dictionary,source: String,dimension: int=64) -> void:
 view=owner_view;entry=value;bucket=source
 custom_minimum_size=Vector2(dimension,dimension)
 mouse_filter=Control.MOUSE_FILTER_STOP
 var style:=StyleBoxFlat.new();style.bg_color=Color("#152016");style.set_corner_radius_all(3);style.set_border_width_all(2)
 style.border_color=Items.color(str(entry.item)) if not entry.is_empty() else Color("#43543c")
 add_theme_stylebox_override("panel",style)
 if not entry.is_empty():
  var definition:=Items.get_item(str(entry.item))
  tooltip_text=("Shared Garden\n" if bucket=="shared" else "Personal stash\n" if bucket=="stash" else "")+"%s\n%s · %s\n%s\nTags: %s\nMonster tags: %s\nDrag stack; Shift + drag one."%[definition.name,definition.rarity,definition.category,Items.describe(definition),", ".join(definition.tags),", ".join(definition.monster_tags)]
  var icon:=str(definition.get("icon",""))
  if not icon.is_empty() and ResourceLoader.exists(icon): texture=load(icon)
 queue_redraw()
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
 var marker: String="M" if definition.category=="monster_part" else "S" if definition.category=="seed" else "P" if definition.category=="plant_part" else "•"
 draw_string(ThemeDB.fallback_font,Vector2(5,13),marker,HORIZONTAL_ALIGNMENT_LEFT,-1,10,color)
 var text:=str(entry.quantity)
 var width:=ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
 draw_string_outline(ThemeDB.fallback_font,Vector2(size.x-width-5,size.y-5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color.BLACK)
 draw_string(ThemeDB.fallback_font,Vector2(size.x-width-5,size.y-5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#eee7cb"))
func _gui_input(event: InputEvent) -> void:
 if entry.is_empty(): return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: view.select_entry(entry)
func _get_drag_data(_at: Vector2):
 if entry.is_empty() or bucket=="equipment": return null
 var data:=drag_payload()
 var label:=Label.new();label.text="%s × %d"%[Items.get_item(str(entry.item)).name,int(data.quantity)]
 label.add_theme_color_override("font_color",Items.color(str(entry.item)))
 set_drag_preview(label)
 return data
func drag_payload() -> Dictionary:
 return {"type":"garden_item_stack","source":bucket,"item":entry.get("item",""),"quantity":1 if Input.is_key_pressed(KEY_SHIFT) else int(entry.get("quantity",0)),"key":entry.get("key","")}
func _can_drop_data(_at: Vector2,data) -> bool:
 return view.can_accept(bucket,data)
func _drop_data(_at: Vector2,data) -> void:
 view.move_stack(bucket,data,str(entry.get("key","")))
