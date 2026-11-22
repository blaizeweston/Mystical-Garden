extends RefCounted
## Movement, senses, defence and resource traits for one species.
## Escort rules for supports stay in the enemy catalog.
## Senses, dodge, mana and flight are live.

const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Reader = preload("res://mob_sim/definitions/definition_reader.gd")

const FIELDS := ["layer", "sight", "darkvision", "hearing", "smell", "glow", "armour", "evasion", "dodge", "mana"]
const DODGE_FIELDS := ["distance", "ms", "cooldown_ms"]
const MANA_FIELDS := ["pool", "channel_per_second", "channel_damage_taken"]

var layer: int = Enums.Layer.GROUND
## Sight range in full light. NAN means the shared aggro radius from the combat balance.
var sight := NAN
## Within this range of the mob, darkness counts as light. Sight also reaches this far past the edge of
## any lit area.
var darkvision := 0.0
var hearing := 0.0
var smell := 0.0
## Radius of the light the mob gives off. Glowing mobs light the players near them and are seen in darkness.
var glow := 0.0
## Damage taken is scaled by the shared armour ratio when true. The legacy Bark mutation sets it too.
var armour := false
## Chance to ignore a hit outright.
var evasion := 0.0
var dodge_distance := 0.0
var dodge_ms := 0
var dodge_cooldown_ms := 0
var mana_pool := 0.0
var mana_channel_per_second := 0.0
## Damage multiplier while channeling.
var channel_damage_taken := 1.0


static func parse(data: Dictionary, reader: Reader) -> RefCounted:
	var traits: RefCounted = new()
	reader.only(data, FIELDS)
	traits.layer = reader.choice(data, "layer", Enums.LAYER_NAMES)
	traits.sight = reader.number_or_catalog(data, "sight", NAN, 1.0, 40.0)
	traits.darkvision = reader.number(data, "darkvision", 0.0, 0.0, 40.0)
	traits.hearing = reader.number(data, "hearing", 0.0, 0.0, 40.0)
	traits.smell = reader.number(data, "smell", 0.0, 0.0, 40.0)
	traits.glow = reader.number(data, "glow", 0.0, 0.0, 12.0)
	traits.armour = reader.flag(data, "armour")
	traits.evasion = reader.number(data, "evasion", 0.0, 0.0, 0.9)
	var dodge := reader.dictionary(data, "dodge")
	reader.push("dodge")
	reader.only(dodge, DODGE_FIELDS)
	traits.dodge_distance = reader.number(dodge, "distance", 0.0, 0.0, 6.0, not dodge.is_empty())
	traits.dodge_ms = int(reader.number(dodge, "ms", 0, 0, 2000, not dodge.is_empty()))
	traits.dodge_cooldown_ms = int(reader.number(dodge, "cooldown_ms", 0, 0, 30000, not dodge.is_empty()))
	reader.pop()
	var mana := reader.dictionary(data, "mana")
	reader.push("mana")
	reader.only(mana, MANA_FIELDS)
	traits.mana_pool = reader.number(mana, "pool", 0.0, 0.0, 1000.0, not mana.is_empty())
	traits.mana_channel_per_second = reader.number(mana, "channel_per_second", 0.0, 0.0, 1000.0, not mana.is_empty())
	traits.channel_damage_taken = reader.number(mana, "channel_damage_taken", 1.0, 1.0, 4.0)
	reader.pop()
	if not is_nan(traits.sight) and traits.darkvision > traits.sight:
		reader.fail("'darkvision' is longer than 'sight'")
	return traits


func can_dodge() -> bool:
	return dodge_cooldown_ms > 0


func uses_mana() -> bool:
	return mana_pool > 0.0
