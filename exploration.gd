extends Node

const Field=preload("res://battlefield.gd")
const MINIMUM := Vector2(Field.REGION.position)
const GRID := Field.REGION.size*2
const CELL := 0.5
const SIGHT := 6.8
const COMPACT_CHART := Vector2(184, 196)
const EXPANDED_CHART := Vector2(340, 350)
const CHART_MARGIN := Vector2(14, 14)
var explored := Image.create(GRID.x, GRID.y, false, Image.FORMAT_R8)
var texture: ImageTexture
var fog: ColorRect
var chart: Control
var field: RefCounted
var floor_key := ""
var cells: Array[Vector2i] = []
var player := Vector3.ZERO
var loot := Vector3.ZERO
var cache := Vector3.ZERO
var item_drops: Array=[]
var thief_routes: Array=[]
var thief_tunnels: Dictionary={}
const ThiefView = preload("res://thief_escape_view.gd")
var has_loot := false
var has_cache := false
var has_shrine := false
var expanded := false
var last_reveal := Vector2.INF

class FloorChart extends Control:
	var owner_map: Node
	func _draw() -> void:
		owner_map.draw_chart(self)

func _ready() -> void:
	if not InputMap.has_action("floor_map"):
		InputMap.add_action("floor_map");InputMap.action_add_event("floor_map",preload("res://app_settings.gd").event_for({"kind":"key","code":KEY_M}))
	explored.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(explored)
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = -1
	add_child(fog_layer)
	fog = ColorRect.new()
	fog_layer.add_child(fog)
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D memory_map : filter_linear, repeat_disable;
uniform vec2 memory_minimum;
uniform vec2 memory_extent;
uniform vec2 world_origin;
uniform vec2 world_right;
uniform vec2 world_down;
uniform vec2 observer;
void fragment() {
	vec2 p = world_origin + SCREEN_UV.x * world_right + SCREEN_UV.y * world_down;
	vec2 uv = (p - memory_minimum) / memory_extent;
	float known = texture(memory_map, uv).r;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) { known = 0.0; }
	float near_player = 1.0 - smoothstep(5.7, 6.8, distance(p, observer));
	float opacity = mix(0.995, 0.62, known) * (1.0 - near_player);
	COLOR = vec4(vec3(0.025, 0.022, 0.015), opacity);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("memory_map", texture)
	material.set_shader_parameter("memory_minimum", MINIMUM)
	material.set_shader_parameter("memory_extent", Vector2(GRID)*CELL)
	fog.material = material
	var map_layer := CanvasLayer.new()
	map_layer.layer = 2
	add_child(map_layer)
	chart = FloorChart.new()
	chart.owner_map = self
	map_layer.add_child(chart)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.hide()
	fog.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton: _unhandled_key_input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("floor_map") and not event.is_echo():
		expanded = not expanded
		get_viewport().set_input_as_handled()

func seen(position: Vector3) -> bool:
	var cell := Vector2i(((Vector2(position.x, position.z) - MINIMUM) / CELL).floor())
	return Rect2i(Vector2i.ZERO, GRID).has_point(cell) and explored.get_pixelv(cell).r > 0.5

func update_floor(new_field: RefCounted, key: String, position: Vector3, camera: Camera3D,
		wild: bool, drop: Vector3, pending: bool, cache_pending: bool, menus_open: bool, shrine_available: bool = false, drops: Array=[]) -> void:
	item_drops=drops
	fog.visible = wild
	chart.visible = wild and not menus_open
	if not wild:
		floor_key = ""
		ThiefView.update_tunnels(self,thief_tunnels,[],camera)
		return
	field = new_field
	player = position
	loot = drop
	cache = field.cache
	has_loot = pending
	has_cache = cache_pending and field.has_seed_cache()
	has_shrine = shrine_available
	if key != floor_key:
		floor_key = key
		explored.fill(Color.BLACK)
		cells.clear()
		last_reveal = Vector2.INF
	var center := Vector2(player.x, player.z)
	if last_reveal.distance_to(center) > 0.2:
		var start := Vector2i(((center - Vector2.ONE * SIGHT - MINIMUM) / CELL).floor())
		var end := Vector2i(((center + Vector2.ONE * SIGHT - MINIMUM) / CELL).ceil())
		for x in range(maxi(0, start.x), mini(GRID.x, end.x + 1)):
			for y in range(maxi(0, start.y), mini(GRID.y, end.y + 1)):
				var point := MINIMUM + (Vector2(x, y) + Vector2.ONE * 0.5) * CELL
				if point.distance_to(center) <= SIGHT and explored.get_pixel(x, y).r < 0.5:
					explored.set_pixel(x, y, Color.WHITE)
					if field.inside_floor(Vector3(point.x, 0, point.y)):
						cells.append(Vector2i(x, y))
		texture.update(explored)
		last_reveal = center
	var viewport_size := get_viewport().get_visible_rect().size
	var a := ground_point(camera, Vector2.ZERO)
	var b := ground_point(camera, Vector2(viewport_size.x, 0))
	var c := ground_point(camera, Vector2(0, viewport_size.y))
	var material := fog.material as ShaderMaterial
	material.set_shader_parameter("world_origin", a)
	material.set_shader_parameter("world_right", b - a)
	material.set_shader_parameter("world_down", c - a)
	material.set_shader_parameter("observer", center)
	var bounds := chart_bounds(viewport_size, expanded)
	chart.size = bounds.size
	chart.position = bounds.position
	ThiefView.update_tunnels(self,thief_tunnels,thief_routes,camera)
	chart.queue_redraw()

func ground_point(camera: Camera3D, screen: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var point := origin + direction * (-origin.y / direction.y)
	point -= Vector3(80, 0, 0)
	return Vector2(point.x, point.z)

static func chart_bounds(viewport_size: Vector2, large: bool) -> Rect2:
	var dimensions := EXPANDED_CHART if large else COMPACT_CHART
	return Rect2(viewport_size - dimensions - CHART_MARGIN, dimensions)

func chart_point(position: Vector3, canvas: Control) -> Vector2:
	return Vector2(12, 36) + (Vector2(position.x, position.z) - MINIMUM) / (Vector2(GRID)*CELL) * (canvas.size - Vector2(24, 70))

func draw_chart(canvas: Control) -> void:
	if field == null:
		return
	var bounds := Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_style_box(panel_style(), bounds)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(12, 27), "FLOOR MAP   ·   "+preload("res://app_settings.gd").hint("floor_map"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d4c696"))
	var scale := (canvas.size - Vector2(24, 70)) / Vector2(GRID)
	for cell in cells:
		var at := Vector2(12, 36) + Vector2(cell) * scale
		canvas.draw_rect(Rect2(at, scale + Vector2.ONE * 0.4), Color("#7d725a"))
	for gate in [field.advance]:
		if seen(gate):
			var at := chart_point(gate, canvas)
			canvas.draw_rect(Rect2(at - Vector2.ONE * 3, Vector2.ONE * 6), Color("#79cfbd"), false, 1.5)
	if has_shrine and seen(field.graft):
		var shrine := chart_point(field.graft,canvas)
		canvas.draw_colored_polygon(PackedVector2Array([shrine+Vector2(0,-5),shrine+Vector2(5,4),shrine+Vector2(-5,4)]),Color("#bdc9f0"))
	if has_loot and seen(loot):
		diamond(canvas, chart_point(loot, canvas))
	if has_cache and seen(cache):
		diamond(canvas, chart_point(cache, canvas))
	for item in item_drops:
		var v: Array=item.position
		var point:=Vector3(v[0],v[1],v[2])
		if seen(point): diamond(canvas,chart_point(point,canvas),drop_color(str(item.item)))
	ThiefView.draw_routes(canvas,self,thief_routes)
	var at := chart_point(player, canvas)
	canvas.draw_circle(at, 4.0, Color("#e5fff5"))
	canvas.draw_arc(at, 6.0, 0, TAU, 20, Color("#83bfae"), 1.0)
	canvas.draw_string(font, Vector2(12,canvas.size.y-16),"● You  □ Gate",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#b6c3c6"))
	canvas.draw_string(font, Vector2(12,canvas.size.y-3),"◆ Seeds",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#f1c773"))
	canvas.draw_string(font, Vector2(80,canvas.size.y-3),"◆ Parts",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#62baff"))

func diamond(canvas: Control, p: Vector2,color: Color=Color("#f1c773")) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0,-4), p + Vector2(4,0), p + Vector2(0,4), p + Vector2(-4,0)]), color)

func panel_style() -> StyleBoxTexture:
	return preload("res://root_ui.gd").root_style(true)
static func drop_color(item_id: String) -> Color:
	return Color("#62baff") if preload("res://item_catalog.gd").get_item(item_id).get("category","")=="monster_part" else Color("#f1c773")
