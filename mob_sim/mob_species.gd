extends RefCounted
## Species stats and attacks compiled from the enemy catalog into flat tables.
## Attack slot 0 is the basic attack. Slots 1 to 3 are abilities 1 to 3.

const Catalog = preload("res://enemy_catalog.gd")
const Balance = preload("res://game_balance.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")

const ATTACKS := 4
const BODY_RADIUS := 0.34
const DESPERATE_RANGE := 1.15
const DESPERATE_AREA := 0.95
const VAULT_RANGE := 3.0
const VAULT_MIN_RANGE := 1.5
const VAULT_WINDUP_MS := 1000
const VAULT_ROLES := ["swipe", "charge", "pounce", "skirmish"]

enum Shape { NONE, SELF_AREA, AIM_AREA, DASH, LEAP, BUFF, SUMMON, PULL }

## Each role fills one attack slot. Sight marks attacks that need a clear line at release.
const ROLES := {
	"swipe": {"slot": 0, "shape": Shape.SELF_AREA, "delivery": Contract.Delivery.MELEE, "sight": true},
	"skirmish": {"slot": 0, "shape": Shape.SELF_AREA, "delivery": Contract.Delivery.MELEE, "sight": true},
	"stomp": {"slot": 0, "shape": Shape.SELF_AREA, "delivery": Contract.Delivery.MELEE, "sight": true},
	"volley": {"slot": 0, "shape": Shape.AIM_AREA, "delivery": Contract.Delivery.RANGED, "sight": true},
	"charge": {"slot": 1, "shape": Shape.DASH, "delivery": Contract.Delivery.ANY, "sight": true},
	"pounce": {"slot": 1, "shape": Shape.LEAP, "delivery": Contract.Delivery.ANY, "sight": true},
	"snare": {"slot": 1, "shape": Shape.AIM_AREA, "delivery": Contract.Delivery.ANY, "sight": true},
	"artillery": {"slot": 1, "shape": Shape.AIM_AREA, "delivery": Contract.Delivery.ANY, "sight": false},
	"lure": {"slot": 1, "shape": Shape.PULL, "delivery": Contract.Delivery.ANY, "sight": true},
	"chant": {"slot": 1, "shape": Shape.BUFF, "delivery": Contract.Delivery.ANY, "sight": false},
	"shepherd": {"slot": 1, "shape": Shape.BUFF, "delivery": Contract.Delivery.ANY, "sight": false},
	"brood": {"slot": 1, "shape": Shape.SUMMON, "delivery": Contract.Delivery.ANY, "sight": false},
}

var count := 0
var ids := PackedStringArray()
var roles := PackedStringArray()
var spawnable := PackedByteArray()
var support := PackedByteArray()
var skirmisher := PackedByteArray()
var speed := PackedFloat32Array()
var hit_radius := PackedFloat32Array()
var vision := PackedFloat32Array()
var preferred_range := PackedFloat32Array()
var max_range := PackedFloat32Array()
var group_alert_radius := 0.0

var attack_exists := PackedByteArray()
var attack_shape := PackedByteArray()
var attack_delivery := PackedByteArray()
var attack_sight := PackedByteArray()
var attack_lonely := PackedByteArray()
var attack_mutation := PackedInt32Array()
var attack_range := PackedFloat32Array()
var attack_min_range := PackedFloat32Array()
var attack_area := PackedFloat32Array()
var attack_windup := PackedInt32Array()
var attack_recovery := PackedInt32Array()


func _init() -> void:
	var combat: Dictionary = Balance.values.combat
	group_alert_radius = float(combat.group_alert_radius)
	var definitions: Array = Catalog.all()
	count = definitions.size()
	_allocate()
	for kind in count:
		_compile(kind, definitions[kind], float(combat.aggro_radius))


func _allocate() -> void:
	var total := count * ATTACKS
	for table: PackedByteArray in [attack_exists, attack_shape, attack_delivery, attack_sight, attack_lonely]:
		table.resize(total)
		table.fill(0)
	attack_mutation.resize(total)
	attack_mutation.fill(0)
	attack_windup.resize(total)
	attack_windup.fill(0)
	attack_recovery.resize(total)
	attack_recovery.fill(0)
	for table: PackedFloat32Array in [attack_range, attack_min_range, attack_area]:
		table.resize(total)
		table.fill(0.0)


func _compile(kind: int, definition: Dictionary, aggro_radius: float) -> void:
	var role := str(definition.role)
	ids.append(str(definition.id))
	roles.append(role)
	spawnable.append(int(not definition.get("boss", false)))
	support.append(int(Catalog.is_support(kind)))
	skirmisher.append(int(role == "skirmish"))
	speed.append(float(definition.speed))
	hit_radius.append(float(definition.get("hitbox", {}).get("radius", BODY_RADIUS)))
	vision.append(aggro_radius)
	var windup := Clock.from_ms(float(definition.windup))
	var recovery := Clock.from_ms(float(definition.recovery))
	var area := float(definition.radius)
	var reach := float(definition.range)
	var template: Dictionary = ROLES[role]
	_set_attack(kind, int(template.slot), int(template.shape), int(template.delivery), bool(template.sight), reach, area, windup, recovery)
	if Catalog.is_support(kind):
		_set_attack(kind, 0, Shape.SELF_AREA, Contract.Delivery.MELEE, true, DESPERATE_RANGE, DESPERATE_AREA, windup, recovery)
		attack_lonely[kind * ATTACKS] = 1
	if role in VAULT_ROLES:
		_set_attack(kind, 2, Shape.LEAP, Contract.Delivery.ANY, false, VAULT_RANGE, area, Clock.from_ms(VAULT_WINDUP_MS), recovery)
		attack_mutation[kind * ATTACKS + 2] = Catalog.MOBILITY
		attack_min_range[kind * ATTACKS + 2] = VAULT_MIN_RANGE
	preferred_range.append(reach * 0.85)
	max_range.append(reach)


func _set_attack(kind: int, slot: int, shape: int, delivery: int, sight: bool, reach: float, area: float, windup: int, recovery: int) -> void:
	var at := kind * ATTACKS + slot
	attack_exists[at] = 1
	attack_shape[at] = shape
	attack_delivery[at] = delivery
	attack_sight[at] = int(sight)
	attack_range[at] = reach
	attack_area[at] = area
	attack_windup[at] = windup
	attack_recovery[at] = recovery


func has_attack(kind: int, slot: int, mutations: int) -> bool:
	var at := kind * ATTACKS + slot
	return attack_exists[at] != 0 and (attack_mutation[at] == 0 or (mutations & attack_mutation[at]) != 0)
