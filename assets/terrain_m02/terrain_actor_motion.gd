extends RefCounted
## Deterministic ground-plane movement. Owners supply their existing legality queries.
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const VERSION := 1 # Session compatibility for shared movement semantics.
const RADIUS_M := 0.34
const SAMPLE_M := 0.13
const CONTACT_GAP_M := 0.001
const NORMAL_SAMPLE_M := 0.003
const MAX_SLIDES := 5 # Bounded collision work, including closed corners.

static func travel(start: Vector2, target: Vector2, radius: float, walkable: Callable, line_clear: Callable = Callable()) -> Vector2:
	if not start.is_finite() or not target.is_finite() or not is_finite(radius) or radius < 0.0: return start
	var length := start.distance_to(target)
	if length <= 0.000001: return start
	var count := maxi(1, ceili(length / SAMPLE_M))
	var last := start
	for index in range(1, count + 1):
		var next := start.lerp(target, float(index) / count)
		if not _legal(last, next, radius, walkable, line_clear):
			var low := 0.0
			var high := 1.0
			for _refinement in 10:
				var middle := (low + high) * 0.5
				if _legal(last, last.lerp(next, middle), radius, walkable, line_clear): low = middle
				else: high = middle
			return last.lerp(next, maxf(0.0, low - CONTACT_GAP_M / last.distance_to(next)))
		last = next
	return target

static func _legal(start: Vector2, target: Vector2, radius: float, walkable: Callable, line_clear: Callable) -> bool:
	return walkable.call(target, radius) and (not line_clear.is_valid() or line_clear.call(start, target, radius))

static func slide(start: Vector2, delta: Vector2, sweep: Callable, clearance: Callable) -> Vector2:
	if not start.is_finite() or not delta.is_finite(): return start
	var point := start
	var remaining := delta
	for _contact in MAX_SLIDES:
		if remaining.length_squared() < 0.00000001: break
		var target := point + remaining
		var next: Vector2 = sweep.call(point, target)
		if next.is_equal_approx(target): return next
		var normal := Vector2(
			clearance.call(next + Vector2.RIGHT * NORMAL_SAMPLE_M) - clearance.call(next - Vector2.RIGHT * NORMAL_SAMPLE_M),
			clearance.call(next + Vector2.DOWN * NORMAL_SAMPLE_M) - clearance.call(next - Vector2.DOWN * NORMAL_SAMPLE_M)).normalized()
		point = next
		if normal.is_zero_approx(): break
		remaining = target - point
		var inward := remaining.dot(normal)
		if inward >= -0.000001: break
		# Preserve only motion along the contacted edge. Never add speed or a push.
		remaining -= normal * inward
	return point

static func obstacles_clearance(point: Vector2, obstacles: Array, limit: float) -> float:
	var distance := limit
	for obstacle: Dictionary in obstacles:
		if obstacle.get("step_over", false): continue
		distance = minf(distance, Shape.signed_distance(obstacle, point, limit))
	return distance

static func water_clearance(point: Vector2, water: Array, decks: Array, limit: float) -> float:
	var deck_distance := -limit
	for deck: Dictionary in decks:
		deck_distance = maxf(deck_distance, -Shape.signed_distance(deck, point, limit))
	var distance := limit
	for wet: Dictionary in water:
		distance = minf(distance, maxf(Shape.signed_distance(wet, point, limit), deck_distance))
	return distance
