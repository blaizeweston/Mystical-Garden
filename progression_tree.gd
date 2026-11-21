extends Control
# Shared circular botanical-node renderer. Unlock rules stay in the adapters.
signal node_selected(id: String)
signal node_hovered(id: String)
const NODE_RADIUS := 25.0
var nodes: Array = []
var selected := ""
var hovered := ""
var grown := {}
var clock := 0.0
func _ready() -> void:
	custom_minimum_size=Vector2(700,360)
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	mouse_exited.connect(func(): set_hover(""))
func set_nodes(values: Array) -> void:
	nodes=values
	var extent:=Vector2(700,360)
	for node in nodes:
		extent=extent.max(Vector2(node.position)+Vector2(40,45))
		if node.unlocked and not grown.has(node.id):
			grown[node.id]=clock
	custom_minimum_size=extent
	queue_redraw()
func _process(delta: float) -> void:
	clock+=delta
	if is_visible_in_tree(): queue_redraw()
func node_at(id: String) -> Dictionary:
	for node in nodes:
		if node.id==id: return node
	return {}
func hit_node(at: Vector2) -> String:
	for node in nodes:
		if at.distance_squared_to(node.position)<=pow(NODE_RADIUS+7.0,2):
			return node.id
	return ""
func set_hover(id: String) -> void:
	if id==hovered: return
	hovered=id
	node_hovered.emit(id)
	queue_redraw()
func _get_tooltip(at: Vector2) -> String:
	var node:=node_at(hit_node(at))
	return str(node.get("summary",str(node.label)+"\n"+str(node.detail).split("\n\n")[0])) if not node.is_empty() else ""
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		set_hover(hit_node(event.position))
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var id:=hit_node(event.position)
		if not id.is_empty():
			selected=id
			node_selected.emit(id)
			accept_event()
			queue_redraw()
func root_points(a: Vector2,b: Vector2,seed_value: int) -> PackedVector2Array:
	var points:=PackedVector2Array()
	var side:=1.0 if seed_value%2==0 else -1.0
	var start:=a+Vector2(side*19,-20)
	var end:=b+Vector2(-side*20,21)
	var c1:=start+Vector2(side*48,-45)
	var c2:=end+Vector2(-side*45,45)
	for i in 49:
		var t:=i/48.0
		var u:=1.0-t
		var p:=u*u*u*start+3*u*u*t*c1+3*u*t*t*c2+t*t*t*end
		p.x+=sin(t*TAU)*sin(t*PI)*7.0
		points.append(p)
	return points
func bark(points: PackedVector2Array,width: float=8.0) -> void:
	if points.size()<2: return
	draw_polyline(points,Color("#0a0c08"),width+5,true)
	draw_polyline(points,Color("#514027"),width+1,true)
	draw_polyline(points,Color("#76603a"),width*0.62,true)
	var grain:=PackedVector2Array()
	for i in points.size():
		var previous: Vector2=points[maxi(0,i-1)]
		var next: Vector2=points[mini(points.size()-1,i+1)]
		var normal: Vector2=(next-previous).normalized().orthogonal()
		grain.append(points[i]+normal*(sin(i*0.49)*width*0.19+width*0.16))
	draw_polyline(grain,Color("#b3a364"),1.3,true)
	for i in range(8,points.size()-3,12):
		var normal: Vector2=(points[i+1]-points[i-1]).normalized().orthogonal()
		var side: float=-1.0 if i%3==0 else 1.0
		var curl:=PackedVector2Array()
		for step in 17:
			var t:=step/16.0
			var angle:=t*PI*1.45
			var radius:=13.0*(1.0-t*0.65)
			curl.append(points[i]+normal*side*(8.0+sin(angle)*radius)+normal.orthogonal()*(cos(angle)*radius-13.0))
		draw_polyline(curl,Color("#413820"),3.6,true)
		draw_polyline(curl,Color("#928353"),1.1,true)
		var leaf:=PackedVector2Array([points[i]+normal*side*4,points[i]+normal*side*14+normal.orthogonal()*5,points[i]+normal*side*9-normal.orthogonal()*4])
		draw_colored_polygon(leaf,Color("#68724a"))
func node_vine(center: Vector2,seed_value: int) -> void:
	var wrap_container:=PackedVector2Array()
	for i in 49:
		var a:=TAU*i/48.0+0.6
		var radius:=30.0+sin(a*3+seed_value)*1.5
		wrap_container.append(center+Vector2(cos(a),sin(a))*radius)
	bark(wrap_container,5.5)
	# A tapered shoot reaches above the wrapping vine, like the reference.
	var shoot:=PackedVector2Array()
	for i in 22:
		var t:=i/21.0
		shoot.append(center+Vector2(19-sin(t*PI)*14,-23-t*21))
	draw_polyline(shoot,Color("#2c2a19"),5.0,true)
	draw_polyline(shoot,Color("#9b8a50"),1.4,true)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#0d160fe8"))
	for node in nodes:
		for parent_id in node.parents:
			var parent:=node_at(str(parent_id))
			if parent.is_empty():continue
			if not node.unlocked or not parent.unlocked:
				if node.get("show_route",false):
					var trace:=root_points(parent.position,node.position,absi(str(node.id).hash()))
					draw_polyline(trace,Color("#8e7949") if parent.unlocked and node.get("available",false) else Color("#363e2c"),2.0,true)
				continue
			var points:=root_points(parent.position,node.position,absi(str(node.id).hash()))
			var amount:=clampf((clock-float(grown.get(node.id,0.0)))*1.4,0.0,1.0)
			bark(points.slice(0,maxi(2,int(points.size()*amount))),8)
	for node in nodes:
		var center: Vector2=node.position
		var active: bool=node.unlocked
		draw_circle(center+Vector2(0,3),NODE_RADIUS+4,Color("#050805a0"))
		draw_circle(center,NODE_RADIUS+2,Color("#75613a") if active else Color("#a8975d") if node.get("available",false) else Color("#384133"))
		draw_circle(center,NODE_RADIUS,Color("#141d12") if active else Color("#101711"))
		if active:
			var icon: Texture2D=node.get("icon")
			if icon!=null:
				draw_texture_rect(icon,Rect2(center-Vector2(27,27),Vector2(54,54)),false)
			else:
				# Reusable botanical rune for Heart and class nodes.
				draw_arc(center,14,0.2,TAU-0.5,28,Color(node.get("color","#b5bd83")),2,true)
				draw_line(center+Vector2(0,12),center-Vector2(0,12),Color("#b5bd83"),2,true)
				for side in [-1.0,1.0]:
					draw_colored_polygon(PackedVector2Array([center,center+Vector2(side*12,-9),center+Vector2(side*10,1)]),Color("#82905c"))
			node_vine(center,absi(str(node.id).hash()%20))
		else:
			draw_arc(center,15,0.2,TAU-0.5,24,Color("#414c3a"),1,true)
			draw_string(ThemeDB.fallback_font,center+Vector2(-4,5),"+" if node.get("available",false) else "?",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#68715d"))
		var caption: String=node.get("caption","")
		if not caption.is_empty():
			var font:=ThemeDB.fallback_font
			var width:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			var at:=center+Vector2(-width*.5,49)
			draw_string_outline(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,4,Color("#0d160f"))
			draw_string(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(node.get("color","#c4be83")))
		if float(node.get("progress",0.0))>0 and not active:
			draw_arc(center,NODE_RADIUS+7,-PI/2,-PI/2+TAU*clampf(float(node.progress),0,1),48,Color("#d8bd78"),3.0,true)
		if selected==node.id or hovered==node.id:
			draw_arc(center,NODE_RADIUS+10,0,TAU,48,Color("#ead59b") if selected==node.id else Color("#ada77b"),1.6,true)
