extends RefCounted
## One telegraphed enemy ability: when it may be used, its timing, its shape and its effects.
## Values marked "catalog" in data are NAN here and are filled from the species at compile time.

const Effect = preload("res://mob_sim/definitions/effect_def.gd")
const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Reader = preload("res://mob_sim/definitions/definition_reader.gd")
const Shape = preload("res://mob_sim/definitions/shape_def.gd")

const FIELDS := ["id", "cue", "slot", "delivery", "target", "sight", "lead", "range", "range_min", "windup_ms",
	"windup_bonus_ms", "min_windup_ms", "recovery_ms", "recovery_bonus_ms", "cooldown_ms", "mana_cost",
	"interruptible", "shape", "effects", "unlock", "elite", "handler", "legacy"]
const UNLOCK_FIELDS := ["floor", "evidence"]
const ELITE_FIELDS := ["radius_bonus", "span_bonus"]

var id := ""
## Short warning text shown to players.
var cue := ""
var slot: int = Enums.Slot.BASIC
var delivery: int = Enums.Delivery.MELEE
var target: int = Enums.Target.ENEMY
var sight: int = Enums.Sight.CLEAR
## Seconds of target movement to lead the aim by.
var lead := 0.0
## Reach needed to start the ability. NAN means the catalog range.
var reach := NAN
var range_min := 0.0
var windup_ms := NAN
var windup_bonus_ms := 0
## Floor on the wind-up after scaling, used by learned counter-moves.
var min_windup_ms := 0
var recovery_ms := NAN
var recovery_bonus_ms := 0
var cooldown_ms := 0
var mana_cost := 0.0
var interruptible := false
var shape: Shape
var effects: Array[Effect] = []
## Earliest floor where the ability can appear.
var unlock_floor := 1
## Play-style evidence needed before the ability unlocks.
var unlock_evidence: int = Enums.Evidence.NONE
## Extra size when a gate elite uses the ability.
var elite_radius_bonus := 0.0
var elite_span_bonus := 0.0
## Named behaviour class for rules richer than data, such as choosing a corpse to tether.
var handler := ""
## The legacy variant or response this ability reproduces, for parity checks.
var legacy := ""


static func parse(data: Dictionary, reader: Reader) -> RefCounted:
	var ability: RefCounted = new()
	reader.only(data, FIELDS)
	ability.id = reader.text(data, "id", "", true)
	ability.cue = reader.text(data, "cue")
	ability.slot = reader.choice(data, "slot", Enums.SLOT_NAMES, 0, true)
	ability.delivery = reader.choice(data, "delivery", Enums.DELIVERY_NAMES, 0, true)
	ability.target = reader.choice(data, "target", Enums.TARGET_NAMES)
	ability.sight = reader.choice(data, "sight", Enums.SIGHT_NAMES, Enums.Sight.CLEAR)
	ability.lead = reader.number(data, "lead", 0.0, 0.0, 1.0)
	ability.reach = reader.number_or_catalog(data, "range", NAN, 0.0, 15.0)
	ability.range_min = reader.number(data, "range_min", 0.0, 0.0, 15.0)
	ability.windup_ms = reader.number_or_catalog(data, "windup_ms", NAN, 100, 6000)
	ability.windup_bonus_ms = int(reader.number(data, "windup_bonus_ms", 0, 0, 3000))
	ability.min_windup_ms = int(reader.number(data, "min_windup_ms", 0, 0, 6000))
	ability.recovery_ms = reader.number_or_catalog(data, "recovery_ms", NAN, 100, 8000)
	ability.recovery_bonus_ms = int(reader.number(data, "recovery_bonus_ms", 0, 0, 3000))
	ability.cooldown_ms = int(reader.number(data, "cooldown_ms", 0, 0, 60000))
	ability.mana_cost = reader.number(data, "mana_cost", 0.0, 0.0, 100.0)
	ability.interruptible = reader.flag(data, "interruptible")
	ability.handler = reader.text(data, "handler")
	ability.legacy = reader.text(data, "legacy")
	reader.push("shape")
	ability.shape = Shape.parse(reader.dictionary(data, "shape", true), reader)
	reader.pop()
	var effects := reader.list(data, "effects")
	for index in effects.size():
		reader.push("effects[%d]" % index)
		if typeof(effects[index]) == TYPE_DICTIONARY:
			ability.effects.append(Effect.parse(effects[index], reader))
		else:
			reader.fail("must be an object")
		reader.pop()
	var unlock := reader.dictionary(data, "unlock")
	reader.push("unlock")
	reader.only(unlock, UNLOCK_FIELDS)
	ability.unlock_floor = int(reader.number(unlock, "floor", 1, 1, 200))
	ability.unlock_evidence = reader.choice(unlock, "evidence", Enums.EVIDENCE_NAMES)
	reader.pop()
	var elite := reader.dictionary(data, "elite")
	reader.push("elite")
	reader.only(elite, ELITE_FIELDS)
	ability.elite_radius_bonus = reader.number(elite, "radius_bonus", 0.0, 0.0, 3.0)
	ability.elite_span_bonus = reader.number(elite, "span_bonus", 0.0, 0.0, 1.5)
	reader.pop()
	if not is_nan(ability.reach) and ability.range_min > ability.reach:
		reader.fail("'range_min' is larger than 'range'")
	if ability.slot != Enums.Slot.BASIC and ability.unlock_floor <= 1 and ability.unlock_evidence == Enums.Evidence.NONE and ability.slot != Enums.Slot.SPECIAL:
		reader.fail("signature and counter abilities need an unlock rule")
	return ability


func damages() -> bool:
	for effect in effects:
		if effect.kind == Enums.Effect.DAMAGE:
			return true
	return false
