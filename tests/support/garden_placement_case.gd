extends RefCounted
## Deterministic fixture setup through the real placement validator, not stale art coordinates.
const Shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
static func find(model: RefCounted, kind: String, preferred: Vector2, yaw: float, pawn: Vector2, moving: int = 0) -> Vector2:
	var outline: PackedVector2Array = model.forest.visible_outline
	var bounds: Rect2 = Shape.shape("fixture", "clearing", outline).bounds
	var candidates: Array[Vector2] = []
	for x in range(floori(bounds.position.x * 2), ceili(bounds.end.x * 2) + 1):
		for y in range(floori(bounds.position.y * 2), ceili(bounds.end.y * 2) + 1):
			var at := Vector2(x, y) * 0.5
			if at.distance_to(preferred) < 0.25 or not Geometry2D.is_point_in_polygon(at, outline): continue
			candidates.append(at)
	candidates.sort_custom(func(a, b):
		var da: float = a.distance_squared_to(preferred)
		var db: float = b.distance_squared_to(preferred)
		return a < b if is_equal_approx(da, db) else da < db)
	for at in candidates:
		if model.validate(kind, at, yaw, pawn, moving).is_empty(): return at
	return Vector2.INF
