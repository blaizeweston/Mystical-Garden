extends Control

const Session = preload("res://network_session.gd")
# Compact cosmetic view of authoritative public player state. No input capture.
const Orb=preload("res://health_orb.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")
const ROW_SIZE:=Vector2(184,44)
const VOTING_ROW_HEIGHT:=58.0
const SPACING:=5.0
var rows: Array=[]
var row_height:=ROW_SIZE.y
var loadout_left:=INF
var panel_style: StyleBoxFlat
var faces: Dictionary={}
static func members(players: Dictionary,local_id: int,travel_members: Array=[]) -> Array:
 var result: Array=[]
 if players.size()<2:return result
 var votes: Dictionary={}
 for voter in travel_members:
  if voter.has("id"): votes[voter.id]=voter.ready
 for id in players:
  if int(id)==local_id and not votes.has(id):continue
  var p: Dictionary=players[id]
  if not Session.ready_for(p,true) or Session.rejecting_for(p):continue
  var profile: Dictionary=p.get("character",{})
  var appearance=profile.get("appearance",p.get("appearance",[]))
  var display_name: String=str(profile.get("name",p.get("display_name","Wanderer"))).replace("\n"," ").replace("\r"," ").replace("\t"," ")
  var hp := PlayerVitals.current_hp(p)
  var row: Dictionary={"id":int(id),"slot":int(Session.slot_for(p,id)),"name":display_name,"hp":maxf(0,hp),"max_hp":maxi(1,PlayerVitals.maximum_hp(p)),"lost_health":int(p.get("lost_health",0)),"fallen":PlayerLifecycle.fallen(p) or hp<=0,"appearance":Array(appearance)}
  if votes.has(id):
   row.ready=votes[id]
   row.local=int(id)==local_id
  result.append(row)
 result.sort_custom(func(a,b):return a.slot<b.slot if a.slot!=b.slot else a.id<b.id)
 return result
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;position=Vector2(20,77)
 panel_style=StyleBoxFlat.new();panel_style.bg_color=Color("#142019c9");panel_style.border_color=Color("#697853");panel_style.set_border_width_all(1);panel_style.set_corner_radius_all(6)
func update_party(party: Array,wild: bool) -> void:
 rows=party
 var voting:=rows.any(func(row):return row.has("ready"))
 var beside_workbench:=voting and is_finite(loadout_left)
 var width:=clampf(loadout_left-position.x-4.0,0.0,ROW_SIZE.x) if beside_workbench else ROW_SIZE.x
 visible=not rows.is_empty() and (wild or voting) and width>16
 z_index=1 if beside_workbench else 0
 row_height=VOTING_ROW_HEIGHT if voting and width==ROW_SIZE.x else ROW_SIZE.y
 size=Vector2(width,rows.size()*(row_height+SPACING))
 queue_redraw()
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
 var hood: bool=appearance[preload("res://character_appearance.gd").HOOD]==1
 draw_colored_polygon(PackedVector2Array([center+Vector2(-13,13),center+Vector2(-8,5),center+Vector2(8,5),center+Vector2(13,13)]),cloak.lightened(.15))
 if hood:draw_style_box(make_face(cloak),Rect2(center+Vector2(-11,-14),Vector2(22,29)))
 elif appearance[3]==2:draw_style_box(make_face(hair),Rect2(center+Vector2(-10,-12),Vector2(20,25)))
 draw_style_box(make_face(skin),Rect2(center+Vector2(-8,-10),Vector2(16,20)))
 if not hood:draw_colored_polygon(PackedVector2Array([center+Vector2(-10,-2),center+Vector2(-9,-12),center+Vector2(-4,-15),center+Vector2(3,-13),center+Vector2(9,-12),center+Vector2(10,-1),center+Vector2(5,-7),center+Vector2(2,-4),center+Vector2(-2,-7)]),hair)
 for x in [-3.0,3.0]:draw_circle(center+Vector2(x,0),1.1,Color("#201d19"))
 if not hood and appearance[3]==1:draw_circle(center+Vector2(10,-7),3,hair)
func make_face(color: Color) -> StyleBoxFlat:
 var key:=color.to_html()
 if not faces.has(key):
  var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(5);faces[key]=style
 return faces[key]
func _draw() -> void:
 if panel_style==null or rows.is_empty():return
 var font:=ThemeDB.fallback_font
 var compact:=size.x<ROW_SIZE.x
 var text_left:=8 if compact else 46
 for i in rows.size():
  var row: Dictionary=rows[i];var at:=Vector2(0,i*(row_height+SPACING));draw_style_box(panel_style,Rect2(at,Vector2(size.x,row_height)))
  if not compact: portrait(at+Vector2(23,22),row.appearance,row.fallen)
  var display_name: String="You · "+str(row.name) if row.get("local",false) else row.name
  var name_width:=int(size.x)-2*text_left if compact else 100
  while font.get_string_size(display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x>name_width and display_name.length()>1:display_name=display_name.left(display_name.length()-2)+"…"
  draw_string(font,at+Vector2(text_left,16),display_name,HORIZONTAL_ALIGNMENT_LEFT,name_width,12,Color("#ddd5b9"))
  if not compact: Orb.paint(self,at+Vector2(161,22),12.0,0.0 if row.fallen else row.hp,row.max_hp,row.get("lost_health",0))
  var vitals: String="Fallen" if row.fallen else "%d / %d HP"%[int(row.hp),row.max_hp]
  if not compact or not row.has("ready"):
   draw_string(font,at+Vector2(text_left,row_height-10),vitals,HORIZONTAL_ALIGNMENT_LEFT,name_width,10,Color("#baae97"))
  if row.has("ready"):
   var status: String="Ready" if row.ready else "Not ready"
   var color:=Color("#b6e59b") if row.ready else Color("#e0c49b")
   draw_string(font,at+Vector2(text_left,33),status,HORIZONTAL_ALIGNMENT_LEFT,name_width,12,color)
