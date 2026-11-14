extends RefCounted
## Pointy-top axial coordinates. Vector2.y represents world Z.

const SQRT_3 := 1.7320508075688772
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const CORNERS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(0, -2),
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(0, 2),
]

static func center_key(cell: Vector2i) -> Vector2i:
	return Vector2i(2 * cell.x + cell.y, 3 * cell.y) * 2

static func corner_key(cell: Vector2i, corner: int) -> Vector2i:
	return center_key(cell) + CORNERS[corner] * 2

static func edge_key(cell: Vector2i, edge: int) -> Vector2i:
	return center_key(cell) + CORNERS[edge] + CORNERS[(edge + 1) % 6]

static func key_to_world(key: Vector2i, spacing: float) -> Vector2:
	return Vector2(key.x, key.y / SQRT_3) * spacing * 0.25

static func cell_to_world(cell: Vector2i, spacing: float) -> Vector2:
	return key_to_world(center_key(cell), spacing)

static func world_to_cell(point: Vector2, spacing: float) -> Vector2i:
	var r := 2.0 * point.y / (spacing * SQRT_3)
	var q := point.x / spacing - r * 0.5
	var base := Vector2i(floori(q), floori(r))
	var best := base
	var closest := INF
	# The nearest center is one of the four corners of the enclosing axial rhombus.
	# Iterate in (q,r) order so shared boundary points have a stable owner.
	for x in range(base.x, base.x + 2):
		for y in range(base.y, base.y + 2):
			var candidate := Vector2i(x, y)
			var delta := Vector2(q - x + (r - y) * 0.5, (r - y) * SQRT_3 * 0.5)
			var distance := delta.length_squared()
			if distance < closest - 0.000001:
				closest = distance
				best = candidate
	return best

static func disk(radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			cells.append(Vector2i(q, r))
	return cells