extends RefCounted
## Round expansion joins without removing any previously reclaimed footprint.
## A round outward/inward offset fills sharp inward seams; union with the input
## keeps all existing land, including arbitrary placed building footprints.

const CORNER_RADIUS_METRES := 0.75

static func rounded_joins(outline: PackedVector2Array) -> PackedVector2Array:
	if outline.size() < 3:
		return outline.duplicate()
	var expanded := Geometry2D.offset_polygon(outline, CORNER_RADIUS_METRES, Geometry2D.JOIN_ROUND)
	if expanded.size() != 1:
		return outline.duplicate()
	var closed := Geometry2D.offset_polygon(expanded[0], -CORNER_RADIUS_METRES, Geometry2D.JOIN_ROUND)
	if closed.size() != 1:
		return outline.duplicate()
	var preserved := Geometry2D.merge_polygons(outline, closed[0])
	return preserved[0] if preserved.size() == 1 else outline.duplicate()
