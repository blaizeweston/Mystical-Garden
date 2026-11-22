extends RefCounted
## The concrete geometry of one released ability, built from its kit row, and the hit test for each part.
## Shapes match the legacy hit rules in enemy_attack_hits.gd: plain circles, charge lanes with contact
## padding, bent lanes, sectors and pulls, each needing a clear line to the target. Releases are rare,
## so this stays in GDScript; the per-tick work is in the native systems.

const Enums = preload("res://mob_sim/definitions/definition_enums.gd")

## Matches EnemyAttackHits.CONTACT_PADDING.
const CONTACT_PADDING := 0.35
## How far a bent lane swings out to the side, from EnemyVariants.seam.
const BEND_OFFSET := 1.3
const BEND_ALONG := 0.53

enum Part { CIRCLE, LANE, SECTOR, PULL }

## One hit area. LANE uses from, to and width; SECTOR uses from, facing, radius and span;
## PULL hits within radius of center when the line from anchor is clear.
class Area extends RefCounted:
	var part: int = Part.CIRCLE
	var center := Vector2.ZERO
	var radius := 0.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var width := 0.0
	var facing := Vector2.RIGHT
	var span := 0.0
	var anchor := Vector2.ZERO

	static func circle(at: Vector2, size: float) -> Area:
		var area := Area.new()
		area.center = at
		area.radius = size
		return area


var slot := -1
var generation := 0
var row := -1
var attack := 0
var player := -1
var origin := Vector2.ZERO
var aim := Vector2.ZERO
var landing := Vector2.ZERO
var damage := 0.0
var areas: Array[Area] = []
## Centres of the spots or trail points, where hazards from this release appear.
var points := PackedVector2Array()
## Hazards this release placed, as MobAbilities.Hazard objects.
var hazards: Array = []


## Builds the areas for a release. origin is where the mob started, landing where it ended,
## grow is extra radius from mutations, and flip mirrors side offsets so neighbours spread out.
func build(tables, world: RefCounted, grow: float, elite: bool, flip: bool) -> void:
	var shape: int = tables.row_shape[row]
	var radius: float = tables.row_radius[row] + (grow if tables.row_flags[row] & tables.ROW_RADIUS_GROWS else 0.0)
	if elite:
		radius += tables.row_elite_radius[row]
	var forward := (aim - origin).normalized()
	if forward.is_zero_approx():
		forward = Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x) * (-1.0 if flip else 1.0)
	var anchor_point := _anchor(tables.row_anchor[row])
	if tables.row_delivery[row] == Enums.Delivery.PULL:
		var area := Area.new()
		area.part = Part.PULL
		area.center = aim
		area.radius = radius
		area.anchor = origin
		areas.append(area)
		return
	match shape:
		Enums.Shape.CIRCLE:
			areas.append(Area.circle(anchor_point, radius))
			points.append(anchor_point)
		Enums.Shape.SECTOR:
			var area := Area.new()
			area.part = Part.SECTOR
			area.from = origin
			area.facing = forward
			area.radius = radius
			area.span = tables.row_span[row] + (tables.row_elite_span[row] if elite else 0.0)
			areas.append(area)
		Enums.Shape.LINE:
			areas.append(_lane(origin, landing, tables.row_width[row]))
			areas.append(Area.circle(landing, radius + CONTACT_PADDING))
		Enums.Shape.BENT_LINE:
			var via := origin.lerp(landing, BEND_ALONG) + side * BEND_OFFSET
			if world.line_clear(origin.x, origin.y, via.x, via.y, 0.0) == 0 or world.line_clear(via.x, via.y, landing.x, landing.y, 0.0) == 0:
				via = origin.lerp(landing, 0.5)
			areas.append(_lane(origin, via, tables.row_width[row]))
			areas.append(_lane(via, landing, tables.row_width[row]))
			areas.append(Area.circle(landing, radius + CONTACT_PADDING))
		Enums.Shape.SPOTS:
			var center := origin.lerp(aim, tables.row_along[row])
			var start: int = tables.row_offset_start[row]
			var spot_radius: float = tables.row_spot_radius[row]
			for index in tables.row_offset_count[row]:
				var offset := Vector2(tables.offsets[(start + index) * 2], tables.offsets[(start + index) * 2 + 1])
				var point := center + side * offset.x + forward * offset.y
				if point.is_equal_approx(center) or world.line_clear(center.x, center.y, point.x, point.y, 0.0) != 0:
					areas.append(Area.circle(point, spot_radius))
					points.append(point)
		Enums.Shape.TRAIL:
			var count: int = tables.row_area_count[row]
			var spacing: float = tables.row_spacing[row]
			if spacing > 0.0:
				count = clampi(floori(origin.distance_to(landing) / spacing) + 1, 1, count)
			for index in count:
				var point := landing if count == 1 else origin.lerp(landing, float(index) / (count - 1))
				areas.append(Area.circle(point, tables.row_spot_radius[row]))
				points.append(point)


func _anchor(kind: int) -> Vector2:
	match kind:
		Enums.Anchor.SELF:
			return origin
		Enums.Anchor.LANDING:
			return landing
	return aim


func _lane(from_point: Vector2, to_point: Vector2, lane_width: float) -> Area:
	var area := Area.new()
	area.part = Part.LANE
	area.from = from_point
	area.to = to_point
	area.width = lane_width
	return area


## True when a target at point is inside any area with a clear line, matching the legacy hit rules.
func hits(point: Vector2, world: RefCounted) -> bool:
	for area in areas:
		if _hits_area(area, point, world):
			return true
	return false


static func _hits_area(area: Area, point: Vector2, world: RefCounted) -> bool:
	match area.part:
		Part.CIRCLE:
			return point.distance_to(area.center) <= area.radius and _clear(world, area.center, point)
		Part.LANE:
			var nearest := Geometry2D.get_closest_point_to_segment(point, area.from, area.to)
			return point.distance_to(nearest) <= area.width + CONTACT_PADDING and _clear(world, nearest, point)
		Part.SECTOR:
			var offset := point - area.from
			if offset.length() > area.radius:
				return false
			var inside := offset.length() <= 0.001 or offset.normalized().dot(area.facing) >= cos(area.span * 0.5)
			return inside and _clear(world, area.from, point)
		Part.PULL:
			return point.distance_to(area.center) <= area.radius and _clear(world, area.anchor, point)
	return false


static func _clear(world: RefCounted, from: Vector2, to: Vector2) -> bool:
	return from.is_equal_approx(to) or world.line_clear(from.x, from.y, to.x, to.y, 0.0) != 0
