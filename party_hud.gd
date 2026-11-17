extends Control
# Compact cosmetic view of authoritative public player state. No input capture.
const Orb=preload("res://health_orb.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const ROW_SIZE:=Vector2(184,44)
const SPACING:=5.0
var rows: Array=[]
var panel_style: StyleBoxFlat
var faces: Dictionary={}
static func members(players: Dictionary,local_id: int) -> Array:
 var result: Array=[]
 for id in players:
  if int(id)==local_id:continue
  var p: Dictionary=players[id]
  if not p.get("profile_ready",true) or p.get("rejecting",false):continue
  var profile: Dictionary=p.get("character",{})
  var appearance=profile.get("appearance",p.get("appearance",[]))
  var name: String=str(profile.get("name",p.get("display_name","Wanderer"))).replace("\n"," ").replace("\r"," ").replace("\t"," ")
  var hp := PlayerVitals.current_hp(p)
  result.append({"id":int(id),"slot":int(p.get("party_slot",id)),"name":name,"hp":maxf(0,hp),"max_hp":maxi(1,PlayerVitals.maximum_hp(p)),"lost_health":int(p.get("lost_health",0)),"fallen":bool(p.get("fallen",false)) or hp<=0,"appearance":Array(appearance)})
 result.sort_custom(func(a,b):return a.slot<b.slot if a.slot!=b.slot else a.id<b.id)
 return result.slice(0,3)
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;position=Vector2(20,77 if Orb.Preview.enabled else 65)
 panel_style=StyleBoxFlat.new();panel_style.bg_color=Color("#142019c9");panel_style.border_color=Color("#697853");panel_style.set_border_width_all(1);panel_style.set_corner_radius_all(6)
func update_party(party: Array,wild: bool) -> void:
 rows=party;visible=wild and not rows.is_empty();size=Vector2(ROW_SIZE.x,rows.size()*(ROW_SIZE.y+SPACING));queue_redraw()
func skull(center: Vector2) -> void:
 draw_circle(center+Vector2(0,-2),8,Color("#d7cfb4"));draw_rect(Rect2(center+Vector2(-5,2),Vector2(10,9)),Color("#d7cfb4"))
 for x in [-3.0,3.0]:draw_circle(center+Vector2(x,-3),2.5,Color("#24271f"))
 for x in [-3.0,0.0,3.0]:draw_line(center+Vector2(x,6),center+Vector2(x,10),Color("#24271f"),1.3,true)
func portrait(center: Vector2,look: Array,fallen: bool) -> void:
 draw_circle(center,17,Color("#304036"))
 if fallen:skull(center);return
 var appearance:=preload("res://character_appearance.gd").normalize(look)
 var skin: Color=[Color("#c79b73"),Color("#754b35"),Color("#e5c6a7")][appearance[4]]
 var hair: Color=[Color("#40281b"),Color("#201d1b"),Color("#a4a193")][appearance[2]]
 var cloak: Color=[Color("#34383c"),Color("#455339"),Color("#594431"),Color("#465766")][appearance[0]]
 draw_colored_polygon(PackedVector2Array([center+Vector2(-13,13),center+Vector2(-8,5),center+Vector2(8,5),center+Vector2(13,13)]),cloak.lightened(.15))
 if appearance[3]==2:draw_style_box(make_face(hair),Rect2(center+Vector2(-10,-12),Vector2(20,25)))
 draw_style_box(make_face(skin),Rect2(center+Vector2(-8,-10),Vector2(16,20)))
 draw_colored_polygon(PackedVector2Array([center+Vector2(-10,-2),center+Vector2(-9,-12),center+Vector2(-4,-15),center+Vector2(3,-13),center+Vector2(9,-12),center+Vector2(10,-1),center+Vector2(5,-7),center+Vector2(2,-4),center+Vector2(-2,-7)]),hair)
 for x in [-3.0,3.0]:draw_circle(center+Vector2(x,0),1.1,Color("#201d19"))
 if appearance[3]==1:draw_circle(center+Vector2(10,-7),3,hair)
func make_face(color: Color) -> StyleBoxFlat:
 var key:=color.to_html()
 if not faces.has(key):
  var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(5);faces[key]=style
 return faces[key]
func _draw() -> void:
 if panel_style==null:return
 var font:=ThemeDB.fallback_font
 for i in rows.size():
  var row: Dictionary=rows[i];var at:=Vector2(0,i*(ROW_SIZE.y+SPACING));draw_style_box(panel_style,Rect2(at,ROW_SIZE))
  portrait(at+Vector2(23,22),row.appearance,row.fallen)
  var name: String=row.name
  var name_width:=100 if Orb.Preview.enabled else 125
  while font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x>name_width and name.length()>1:name=name.left(name.length()-2)+"…"
  draw_string(font,at+Vector2(46,16),name,HORIZONTAL_ALIGNMENT_LEFT,name_width+3,12,Color("#ddd5b9"))
  if Orb.Preview.enabled:
   Orb.paint(self,at+Vector2(161,22),12.0,0.0 if row.fallen else row.hp,row.max_hp,row.get("lost_health",0))
   var vitals: String="Fallen" if row.fallen else "%d / %d HP"%[int(row.hp),row.max_hp]
   draw_string(font,at+Vector2(46,34),vitals,HORIZONTAL_ALIGNMENT_LEFT,100,10,Color("#baae97"))
   continue
  draw_style_box(make_face(Color("#29352a")),Rect2(at+Vector2(46,23),Vector2(128,7)))
  var ratio:=0.0 if row.fallen else clampf(float(row.hp)/float(row.max_hp),0,1)
  if ratio>0:draw_style_box(make_face(Color("#b68852") if ratio<=.3 else Color("#8eb375")),Rect2(at+Vector2(46,23),Vector2(128*ratio,7)))
  draw_string(font,at+Vector2(46,40),"Fallen" if row.fallen else "%s / %d"%[str(snappedf(row.hp,.5)),row.max_hp],HORIZONTAL_ALIGNMENT_LEFT,128,9,Color("#baae97"))
