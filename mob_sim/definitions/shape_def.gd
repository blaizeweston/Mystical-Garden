extends RefCounted
## The geometry an ability tests at release. The same shape drives its warning and its hits.

const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Reader = preload("res://mob_sim/definitions/definition_reader.gd")

const FIELDS := ["kind", "radius", "width", "span", "anchor", "along", "offsets", "spot_radius", "count", "spacing"]

var kind: int = Enums.Shape.CIRCLE
## Area radius. NAN means the species' catalog radius, including mutation growth.
var radius := NAN
## Line width for charges.
var width := 0.0
## Sector angle in radians.
var span := 0.0
## Where the shape is centred.
var anchor: int = Enums.Anchor.TARGET
## Fraction of the way from the mob to the anchor where spots or trails centre. One means the anchor.
var along := 1.0
## Spot offsets: x sideways from the aim line, y along it.
var offsets := PackedVector2Array()
var spot_radius := 0.0
## Evenly spaced points for trails and spot lines without offsets.
var count := 0
## Minimum spacing between trail points.
var spacing := 0.0


static func parse(data: Dictionary, reader: Reader) -> RefCounted:
	var shape: RefCounted = new()
	reader.only(data, FIELDS)
	shape.kind = reader.choice(data, "kind", Enums.SHAPE_NAMES, 0, true)
	shape.radius = reader.number_or_catalog(data, "radius", NAN, 0.1, 12.0)
	shape.width = reader.number(data, "width", 0.0, 0.0, 6.0)
	shape.span = reader.number(data, "span", 0.0, 0.0, TAU)
	shape.anchor = reader.choice(data, "anchor", Enums.ANCHOR_NAMES)
	shape.along = reader.number(data, "along", 1.0, 0.0, 1.0)
	shape.offsets = reader.offsets(data, "offsets")
	shape.spot_radius = reader.number(data, "spot_radius", 0.0, 0.0, 6.0)
	shape.count = int(reader.number(data, "count", 0, 0, 8))
	shape.spacing = reader.number(data, "spacing", 0.0, 0.0, 12.0)
	match shape.kind:
		Enums.Shape.SECTOR:
			if shape.span <= 0.0:
				reader.fail("a sector needs 'span'")
		Enums.Shape.LINE, Enums.Shape.BENT_LINE:
			if shape.width <= 0.0:
				reader.fail("a line needs 'width'")
		Enums.Shape.SPOTS:
			if shape.offsets.is_empty() and shape.count <= 0:
				reader.fail("spots need 'offsets' or 'count'")
			if shape.spot_radius <= 0.0:
				reader.fail("spots need 'spot_radius'")
		Enums.Shape.TRAIL:
			if shape.count <= 0:
				reader.fail("a trail needs 'count'")
	return shape


## Number of separate hit areas this shape produces.
func area_count() -> int:
	match kind:
		Enums.Shape.SPOTS:
			return offsets.size() if not offsets.is_empty() else count
		Enums.Shape.TRAIL:
			return count
	return 1
