extends Control
# Decorative overlay. The Button remains responsible for input, focus and selection.
const DURATION := 0.42
const BORDER_GAP := 2.8
const BARK := Color("#6e5733")
const GRAIN := Color("#d5bb7b")
var button: Button
var motion_enabled: Callable
var growth := 0.0
var highlighted := false
var animation: Tween
var perimeter := PackedVector2Array()
var tendrils: Array[Dictionary] = []

static func watch(scope: Node, motion: Callable) -> void:
 var scene := scope.get_tree()
 var decorate := func(reference: WeakRef):
  var target := reference.get_ref() as Button
  if target != null:
   attach(target, motion)
 var on_added := func(node: Node):
  if node is Button and scope.is_ancestor_of(node):
   decorate.call_deferred(weakref(node))
 scene.node_added.connect(on_added)
 scope.tree_exiting.connect(func(): scene.node_added.disconnect(on_added), CONNECT_ONE_SHOT)
 for child in scope.get_children(true):
  decorate_branch(child, motion)

static func decorate_branch(node: Node, motion: Callable) -> void:
 if node is Button:
  attach(node, motion)
 if node is Control or node is CanvasLayer or node is Window:
  for child in node.get_children(true):
   decorate_branch(child, motion)

static func attach(target: Button, motion: Callable) -> void:
 if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion() or target.has_node("ReachingRoots"):
  return
 var roots: Control = load("res://menu_button_roots.gd").new()
 roots.name = "ReachingRoots"
 roots.button = target
 roots.motion_enabled = motion
 roots.mouse_filter = Control.MOUSE_FILTER_IGNORE
 target.add_child(roots)
 roots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
 button.focus_entered.connect(update_highlight)
 button.focus_exited.connect(update_highlight)
 button.mouse_entered.connect(update_highlight)
 button.mouse_exited.connect(update_highlight)
 button.toggled.connect(func(_pressed: bool): update_highlight())
 button.visibility_changed.connect(update_highlight)
 button.draw.connect(update_highlight)
 resized.connect(invalidate_paths)
 update_highlight()

func update_highlight() -> void:
 var selected := button.toggle_mode and button.button_pressed and not (button is CheckBox or button is CheckButton)
 var active := button.is_visible_in_tree() and not button.disabled and (
  button.is_hovered() or button.has_focus() or selected)
 if not motion_enabled.call() or not button.is_visible_in_tree() or button.disabled:
  if animation != null:
   animation.kill()
   animation = null
  highlighted = active
  var settled := 1.0 if active else 0.0
  if growth != settled:
   set_growth(settled)
  return
 if active == highlighted:
  return
 highlighted = active
 if animation != null:
  animation.kill()
 animation = create_tween()
 animation.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 animation.tween_method(set_growth, growth, 1.0 if active else 0.0, DURATION if active else 0.15)

func set_growth(amount: float) -> void:
 growth = amount
 if growth > 0.0 and perimeter.is_empty():
  rebuild_paths()
 queue_redraw()

func invalidate_paths() -> void:
 perimeter.clear()
 tendrils.clear()
 if growth > 0.0:
  rebuild_paths()
 queue_redraw()

func rebuild_paths() -> void:
 if size.x < 14.0 or size.y < 14.0:
  return

 # One root follows the upper half of the frame. Its mirrored partner takes the lower half.
 var curve := Curve2D.new()
 curve.bake_interval = 1.8
 var corner := minf(7.0, minf(size.x,size.y)*0.24)
 var handle := corner * 0.5523
 var left := -BORDER_GAP
 var right := size.x + BORDER_GAP
 var top := -BORDER_GAP
 curve.add_point(Vector2(left, size.y * 0.5 + 1.0))
 curve.add_point(Vector2(left, top + corner), Vector2.ZERO, Vector2(0.0, -handle))
 curve.add_point(Vector2(left + corner, top), Vector2(-handle, 0.0))
 curve.add_point(Vector2(right - corner, top), Vector2.ZERO, Vector2(handle, 0.0))
 curve.add_point(Vector2(right, top + corner), Vector2(0.0, -handle))
 curve.add_point(Vector2(right, size.y * 0.5 - 1.0))

 var length := curve.get_baked_length()
 var branch_scale := clampf(minf(size.x / 75.0, size.y / 40.0), 0.5, 1.0)
 var point_count := maxi(16, ceili(length / 1.8))
 for index in point_count + 1:
  var distance := length * index / point_count
  var at := curve.sample_baked(distance)
  var direction := (curve.sample_baked(distance + 1.0) - curve.sample_baked(distance - 1.0)).normalized()
  var outward := Vector2(direction.y, -direction.x)
  var grain := 0.45 + sin(distance * 0.22) * 0.32 + sin(distance * 0.47) * 0.13
  perimeter.append(at + outward * grain)

 var branch_count := clampi(roundi(length / 27.0), 5, 11)
 for branch in branch_count:
  var start := lerpf(0.10, 0.88, float(branch) / float(branch_count - 1))
  var index := roundi(start * point_count)
  var direction := (perimeter[index + 1] - perimeter[index - 1]).normalized()
  var outward := Vector2(direction.y, -direction.x)
  var bend := -1.0 if branch % 3 == 1 else 1.0
  var lengthwise := (9.0 + float((branch * 7) % 9)) * branch_scale
  var points := PackedVector2Array()
  for step in 13:
   var t := float(step) / 12.0
   points.append(perimeter[index] + direction * bend * lengthwise * t
    + outward * (sin(t * 1.65) * (3.5 + branch % 3 * 0.65) * branch_scale))
  tendrils.append({"points": points, "start": start, "width": 1.7})

  # Finer offshoots emerge from the stronger tendrils.
  if branch % 2 == 0:
   var fork := PackedVector2Array()
   for step in 9:
    var t := float(step) / 8.0
    fork.append(points[5] + direction * bend * (7.0 * t - sin(t * PI) * 3.0) * branch_scale
     + outward * (sin(t * 1.7) * 2.9) * branch_scale)
   tendrils.append({"points": fork, "start": start + 0.05, "width": 1.05})
 queue_redraw()

func _draw() -> void:
 if growth <= 0.0 or perimeter.is_empty():
  return
 draw_root(perimeter, growth, 3.9)
 for tendril in tendrils:
  var amount := clampf((growth - float(tendril.start)) / 0.11, 0.0, 1.0)
  draw_root(tendril.points, amount, tendril.width)

func draw_root(points: PackedVector2Array, amount: float, width: float) -> void:
 if amount <= 0.0:
  return
 var tip := amount * (points.size() - 1)
 var end := int(tip)
 var grown := points.slice(0, end + 1)
 if end < points.size() - 1 and tip > end:
  grown.append(points[end].lerp(points[end + 1], tip - end))
 if grown.size() < 2:
  return

 var edges := PackedVector2Array()
 var grain := PackedVector2Array()
 var other_side := PackedVector2Array()
 for index in grown.size():
  var tangent := (grown[mini(index + 1, grown.size() - 1)] - grown[maxi(0, index - 1)]).normalized()
  var normal := Vector2(tangent.y, -tangent.x)
  var progress := float(index) / (points.size() - 1)
  var tip_taper := minf(1.0, float(grown.size() - 1 - index) * 0.45)
  var half_width := width * 0.5 * (1.0 - progress * 0.72) * lerpf(0.12, 1.0, tip_taper)
  var bark_ripple := 0.86 + sin(index * 0.71) * 0.14
  edges.append(grown[index] + normal * half_width * bark_ripple)
  other_side.append(grown[index] - normal * half_width)
  grain.append(grown[index] + normal * half_width * (0.23 + sin(index * 0.54) * 0.24))
 draw_ribbon(edges, other_side)
 draw_polyline(grain, GRAIN, minf(width * 0.39, 1.1), true)
 for index in edges.size():
  edges[index] = size - edges[index]
  other_side[index] = size - other_side[index]
 for index in grain.size():
  grain[index] = size - grain[index]
 draw_ribbon(edges, other_side)
 draw_polyline(grain, GRAIN, minf(width * 0.39, 1.1), true)

func draw_ribbon(left: PackedVector2Array, right: PackedVector2Array) -> void:
 # Each segment is a small quad. A growing root can bend back across itself;
 # treating the entire ribbon as one simple polygon makes triangulation fail.
 # Primitives retain the same taper and pigment and allow those overlaps.
 var pigment := PackedColorArray([BARK])
 for index in left.size() - 1:
  draw_primitive(PackedVector2Array([left[index], left[index + 1], right[index + 1], right[index]]), pigment, PackedVector2Array())
