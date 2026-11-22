extends RefCounted
## One consequence of a released ability, such as damage, a root or a hazard.

const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Reader = preload("res://mob_sim/definitions/definition_reader.gd")

const FIELDS := ["kind", "scale", "ms", "delay_ms", "step_ms", "radius", "hazard", "count", "distance", "interval_ms", "arc", "species", "handler", "offset"]

var kind: int = Enums.Effect.DAMAGE
## Damage or heal multiplier on the species' authored hit.
var scale := 1.0
## Duration of a root, haste, hazard or guard.
var duration_ms := 0
## Delay before a hazard or follow-up becomes active.
var delay_ms := 0
## Extra delay added for each later hazard in the same release.
var step_ms := 0
## Effect radius. Zero means the ability's own shape radius.
var radius := 0.0
var hazard: int = Enums.Hazard.NONE
## Summons, extra pulses or decoys created.
var count := 0
## Pull distance per release.
var distance := 0.0
## Time between repeated pulses.
var interval_ms := 0
## Guard arc as the minimum facing dot product.
var arc := 0.0
## Species id created by a summon.
var species := ""
## Where a follow-up lands: x sideways from the aim line, y along it, from the mob.
var offset := Vector2.ZERO
## Named behaviour class for effects whose rules are richer than data, such as a corpse tether.
var handler := ""


static func parse(data: Dictionary, reader: Reader) -> RefCounted:
	var effect: RefCounted = new()
	reader.only(data, FIELDS)
	effect.kind = reader.choice(data, "kind", Enums.EFFECT_NAMES, 0, true)
	effect.scale = reader.number(data, "scale", 1.0, 0.0, 10.0)
	effect.duration_ms = int(reader.number(data, "ms", 0, 0, 60000))
	effect.delay_ms = int(reader.number(data, "delay_ms", 0, 0, 10000))
	effect.step_ms = int(reader.number(data, "step_ms", 0, 0, 5000))
	effect.radius = reader.number(data, "radius", 0.0, 0.0, 12.0)
	effect.hazard = reader.choice(data, "hazard", Enums.HAZARD_NAMES)
	effect.count = int(reader.number(data, "count", 0, 0, 8))
	effect.distance = reader.number(data, "distance", 0.0, 0.0, 6.0)
	effect.interval_ms = int(reader.number(data, "interval_ms", 0, 0, 5000))
	effect.arc = reader.number(data, "arc", 0.0, -1.0, 1.0)
	effect.species = reader.text(data, "species")
	effect.handler = reader.text(data, "handler")
	var offset := reader.offsets({"offset": [data["offset"]]} if data.has("offset") else {}, "offset")
	if not offset.is_empty():
		effect.offset = offset[0]
	match effect.kind:
		Enums.Effect.HAZARD:
			if effect.hazard == Enums.Hazard.NONE:
				reader.fail("a hazard effect needs a 'hazard' kind")
			if effect.duration_ms <= 0:
				reader.fail("a hazard effect needs 'ms'")
		Enums.Effect.ROOT, Enums.Effect.HASTE_ALLIES, Enums.Effect.GUARD:
			if effect.duration_ms <= 0 and effect.kind != Enums.Effect.GUARD:
				reader.fail("this effect needs 'ms'")
		Enums.Effect.REPEAT:
			if effect.count <= 0 or effect.interval_ms <= 0:
				reader.fail("a repeat needs 'count' and 'interval_ms'")
		Enums.Effect.SUMMON:
			if effect.count <= 0:
				reader.fail("a summon needs 'count'")
		Enums.Effect.PULL:
			if effect.distance <= 0.0:
				reader.fail("a pull needs 'distance'")
	return effect
