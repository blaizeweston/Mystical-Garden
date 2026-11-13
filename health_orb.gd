extends RefCounted
## The full circle represents the expedition's health ceiling before revival loss.
const Preview = preload("res://combat_balance_preview.gd")
const SHELL := Color("#1b1515")
const EMPTY := Color("#3b2022")
const BLOOD := Color("#ab302f")
const LOW := Color("#d34733")
const RIM := Color("#b78a55")
const CAP := Color("#ddaf70")
const RECOVERY := Color("#a7e3a5")
const CHANGE_MS := 330

var hp := -1.0
var from_hp := 0.0
var maximum := 0
var lost := 0
var wild := false
var fallen := false
var changed_at := 0


func update(state: Dictionary, now: int) -> void:
	var value := float(state.get("hp", 0))
	var new_max := int(state.get("max_hp", 0))
	var new_lost := int(state.get("lost_health", 0))
	var in_wilds := bool(state.get("wild", false))
	var is_fallen := bool(state.get("fallen", false))
	if hp < 0 or new_max != maximum or new_lost != lost or in_wilds != wild or is_fallen != fallen:
		from_hp = value
		changed_at = 0
	elif value != hp:
		from_hp = hp
		changed_at = now
	hp = value
	maximum = new_max
	lost = new_lost
	wild = in_wilds
	fallen = is_fallen


func draw(canvas: Control, center: Vector2, radius: float, now: int) -> void:
	var flash := 1.0 - clampf(float(now - changed_at) / CHANGE_MS, 0.0, 1.0)
	paint(canvas, center, radius, hp, maximum, lost, from_hp, flash)


static func fractions(health: float, max_hp: int, lost_hp: int) -> Vector2:
	var full := float(maxi(1, max_hp + maxi(0, lost_hp)))
	var cap := clampf(float(max_hp) / full, 0.0, 1.0)
	return Vector2(clampf(health / full, 0.0, cap), cap)


static func paint(canvas: Control, center: Vector2, radius: float, health: float, max_hp: int,
		lost_hp: int, previous: float = 0.0, flash: float = 0.0) -> void:
	var fill := fractions(health, max_hp, lost_hp)
	var inner := radius - 1.6
	canvas.draw_circle(center + Vector2(0, 1), radius + 1.6, Color("#090808cf"), true, -1, true)
	canvas.draw_circle(center, radius, SHELL, true, -1, true)
	segment(canvas, center, inner, fill.y, EMPTY)
	var blood := LOW if health <= max_hp * .25 else BLOOD
	var old := fractions(previous, max_hp, lost_hp).x
	if flash > 0 and old > fill.x:
		segment(canvas, center, inner, old, EMPTY.lerp(Color("#efa67b"), .78 * flash))
	segment(canvas, center, inner, fill.x, blood)
	if flash > 0 and old < fill.x:
		segment(canvas, center, inner, fill.x, blood.lerp(RECOVERY, .9 * flash))
		segment(canvas, center, inner, old, blood)
	if fill.x > 0.0 and fill.x < 1.0:
		level_line(canvas, center, inner, fill.x, blood.lightened(.28), 1.0)
	if lost_hp > 0:
		level_line(canvas, center, inner, fill.y, CAP, 1.0)
	canvas.draw_arc(center, radius - .65, 0, TAU, 48, RIM, 1.3, true)
	if radius >= 20:
		canvas.draw_arc(center, radius - 4, -2.8, -1.2, 14, Color("#f4d8b150"), 1.3, true)


static func segment(canvas: Control, center: Vector2, radius: float, amount: float, color: Color) -> void:
	if amount <= 0.0:
		return
	if amount >= 1.0:
		canvas.draw_circle(center, radius, color, true, -1, true)
		return
	var start := asin(1.0 - amount * 2.0)
	var points := PackedVector2Array()
	for index in 49:
		var angle := lerpf(start, PI - start, index / 48.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(points, color)


static func level_line(canvas: Control, center: Vector2, radius: float, amount: float, color: Color, width: float) -> void:
	var y := (1.0 - 2.0 * amount) * radius
	var half := sqrt(maxf(0.0, radius * radius - y * y))
	canvas.draw_line(center + Vector2(-half, y), center + Vector2(half, y), color, width, true)
