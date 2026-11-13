extends Control
## Read-only presentation of the authoritative expedition floor; no progression state.
const Config=preload("res://encounter_config.gd")
const INK=Color("#e5d8b3")
var floor_number:=1
var nodes: Array=[]
var growth:=1.0
static func layout(current: int,width: float) -> Array:
 current=maxi(1,current)
 var side_count:=3 if width>=1000 else 2 if width>=760 else 1
 var step:=74.0 if width>=1000 else 68.0
 var result: Array=[]
 for offset in range(-side_count,side_count+1):
  var number:=current+offset
  if number<1:continue
  result.append({"floor":number,"label":str(number) if number<=current else "?","current":offset==0,"reached":number<=current,"upgrade":number%Config.UPGRADE_INTERVAL==0,"extraction":number%Config.EXTRACTION_INTERVAL==0,"position":Vector2(width*.5+offset*step,51),"radius":24.0 if offset==0 else 16.0})
 return result
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 resized.connect(refresh);set_process(false);hide()
func update_track(number: int,wild: bool) -> void:
 var changed:=floor_number!=maxi(1,number)
 var was_visible:=visible
 if changed and visible and wild:growth=0;set_process(true)
 elif not visible or not wild:growth=1;set_process(false)
 floor_number=maxi(1,number);visible=wild
 if changed or was_visible!=wild or nodes.is_empty():refresh()
func refresh() -> void:
 nodes=layout(floor_number,size.x);queue_redraw()
func _process(delta: float) -> void:
 growth=minf(1,growth+delta*2.4);queue_redraw()
 if growth>=1:set_process(false)
func label(at: Vector2,value: String,font_size: int,color: Color) -> void:
 var font:=ThemeDB.fallback_font;var point:=at-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5,0)
 draw_string_outline(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("#090e0bee"))
 draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func root(from: Vector2,to: Vector2,reached: bool,amount: float=1.0) -> void:
 var path:=PackedVector2Array();var distance:=from.distance_to(to)
 for index in 33:
  var t:=index/32.0
  path.append(from.lerp(to,t)+Vector2(0,sin(t*TAU)*4+sin(t*PI*5)*1.3))
 draw_polyline(path,Color("#080c09d9"),8,true)
 draw_polyline(path,Color("#403629") if reached else Color("#34382b99"),5,true)
 var grown:=PackedVector2Array()
 for index in maxi(2,ceili(33*amount)):
  if index>=path.size():break
  grown.append(path[index])
 if reached:
  draw_polyline(grown,Color("#9a8351"),2.4,true)
  var fine:=PackedVector2Array()
  for index in grown.size():fine.append(grown[index]+Vector2(0,sin(index*.27)*1.8-1.5))
  draw_polyline(fine,Color("#c0aa716e"),1,true)
 for index in [8,18,26]:
  if reached and float(index)/32>amount:continue
  var at:=path[index];var sign_value: float=1 if index%2==0 else -1
  draw_polyline(PackedVector2Array([at,at+Vector2(distance*.06,sign_value*5),at+Vector2(distance*.16,sign_value*7)]),Color("#806f46") if reached else Color("#45473699"),1.5,true)
func upgrade_icon(at: Vector2,color: Color) -> void:
 var star:=PackedVector2Array()
 for i in 8:
  var a: float=i*TAU/8-PI/2;star.append(at+Vector2(cos(a),sin(a))*(6.5 if i%2==0 else 2.7))
 draw_colored_polygon(star,color)
func extraction_icon(at: Vector2,color: Color) -> void:
 draw_arc(at+Vector2(0,1),5,PI,TAU,16,color,1.8,true)
 draw_line(at+Vector2(-5,1),at+Vector2(-5,6),color,1.8,true);draw_line(at+Vector2(5,1),at+Vector2(5,6),color,1.8,true)
 draw_line(at+Vector2(0,5),at+Vector2(0,-4),color,1.5,true)
 draw_polyline(PackedVector2Array([at+Vector2(-2.5,-1),at+Vector2(0,-4),at+Vector2(2.5,-1)]),color,1.5,true)
func _draw() -> void:
 if nodes.is_empty():return
 for index in range(1,nodes.size()):
  var previous: Dictionary=nodes[index-1];var current: Dictionary=nodes[index]
  root(previous.position,current.position,current.reached,growth if current.current else 1.0)
 for node in nodes:
  var at: Vector2=node.position;var radius: float=node.radius
  draw_circle(at,radius+3,Color("#0a100de6"))
  draw_circle(at,radius,Color("#24362cef") if node.current else Color("#17221de8"))
  draw_arc(at,radius,0,TAU,48,Color("#bca56b") if node.current else Color("#756440") if node.reached else Color("#4b5140"),2.2 if node.current else 1.4,true)
  # Uneven twining roots embrace the circular node, with tapering offshoots.
  for strand in 2:
   var vine:=PackedVector2Array()
   for i in 37:
    var a: float=-PI*.65+strand*PI+i*PI*1.25/36
    var r: float=radius+1.4+sin(a*3+strand)*1.7;vine.append(at+Vector2(cos(a),sin(a))*r)
   draw_polyline(vine,Color("#b39a61") if node.current else Color("#847044") if node.reached else Color("#4b503c"),2,true)
   var tip: Vector2=vine[vine.size()-1]
   draw_polyline(PackedVector2Array([tip,tip+Vector2(3,-4),tip+Vector2(2,-8)]),Color("#887b4a") if node.reached else Color("#4b503c"),1.2,true)
  var font_size:=18 if node.current else 14
  var text_width:=ThemeDB.fallback_font.get_string_size(node.label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  font_size=mini(font_size,maxi(6,floori(font_size*(radius*2-7)/maxf(1,text_width))))
  label(at+Vector2(0,font_size*.33),node.label,font_size,INK if node.reached else Color("#8c9380"))
  var icon_y: float=at.y+31
  if node.upgrade:upgrade_icon(Vector2(at.x-8 if node.extraction else at.x,icon_y),Color("#d5bb78") if node.reached else Color("#9d9479"))
  if node.extraction:extraction_icon(Vector2(at.x+8,icon_y),Color("#a1d7d3") if node.reached else Color("#829e98"))
 label(Vector2(size.x*.5,16),"FLOOR",10,Color("#bbbc9e"))
 var center:=Vector2(size.x*.5,102)
 upgrade_icon(center+Vector2(-93,-4),Color("#d5bb78"));label(center+Vector2(-49,0),"Upgrade",10,Color("#c4c1a8"))
 extraction_icon(center+Vector2(16,-4),Color("#a1d7d3"));label(center+Vector2(66,0),"Extraction",10,Color("#c4c1a8"))
