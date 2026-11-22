extends RefCounted
## Species stats and attacks compiled into flat tables from the framework's ability kits
## (mob_sim/data, compiled by definitions/definition_tables.gd).
## Attack slot 0 is the basic attack, 1 the signature, 2 the counter and 3 the special.
## Supports use slot 3 for their escort-less fallback attack.

const Catalog = preload("res://enemy_catalog.gd")
const Balance = preload("res://game_balance.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Tables = preload("res://mob_sim/definitions/definition_tables.gd")

const ATTACKS := 4
const BODY_RADIUS := 0.34
## Mutation bits beyond the catalog's, set at spawn when a slot's unlock rule is met.
const UNLOCK_SIGNATURE := 1 << 8
const UNLOCK_COUNTER := 1 << 9

enum Shape { NONE, SELF_AREA, AIM_AREA, DASH, LEAP, BUFF, SUMMON, PULL }
## When an attack may be used relative to fighting allies: any time, only alone, or only with an escort.
enum Escort { ANY, ALONE, ESCORTED }

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
## Mana pool per species; zero for species without mana.
var mana_pool := PackedFloat32Array()
var mana_per_tick := PackedFloat32Array()
## Mana below the dearest cast in the species' kit, where the scripted brain looks for a safe channel.
var mana_low := PackedFloat32Array()
var can_dodge := PackedByteArray()
## 1 for species that fly on the air layer.
var layer := PackedByteArray()
var dodge_distance := PackedFloat32Array()
var dodge_ticks := PackedInt32Array()
var dodge_cooldown := PackedInt32Array()

var attack_exists := PackedByteArray()
var attack_shape := PackedByteArray()
var attack_delivery := PackedByteArray()
var attack_sight := PackedByteArray()
var attack_escort := PackedByteArray()
var attack_mutation := PackedInt32Array()
var attack_range := PackedFloat32Array()
var attack_min_range := PackedFloat32Array()
var attack_area := PackedFloat32Array()
var attack_windup := PackedInt32Array()
var attack_min_windup := PackedInt32Array()
var attack_recovery := PackedInt32Array()
var attack_cooldown := PackedInt32Array()
var attack_lead := PackedFloat32Array()
var attack_mana_cost := PackedFloat32Array()
## Row in the compiled definition tables, or -1 for an empty slot.
var attack_row := PackedInt32Array()
var tables: RefCounted


func _init() -> void:
	var combat: Dictionary = Balance.values.combat
	group_alert_radius = float(combat.group_alert_radius)
	tables = Tables.shared()
	var definitions: Array = Catalog.all()
	count = definitions.size()
	_allocate()
	for kind in count:
		_compile(kind, definitions[kind], float(combat.aggro_radius))


func _allocate() -> void:
	var total := count * ATTACKS
	for table: PackedByteArray in [attack_exists, attack_shape, attack_delivery, attack_sight, attack_escort]:
		table.resize(total)
		table.fill(0)
	for table: PackedInt32Array in [attack_mutation, attack_windup, attack_min_windup, attack_recovery, attack_cooldown]:
		table.resize(total)
		table.fill(0)
	for table: PackedFloat32Array in [attack_range, attack_min_range, attack_area, attack_lead, attack_mana_cost]:
		table.resize(total)
		table.fill(0.0)
	attack_row.resize(total)
	attack_row.fill(-1)


func _compile(kind: int, definition: Dictionary, aggro_radius: float) -> void:
	var role := str(definition.role)
	ids.append(str(definition.id))
	roles.append(role)
	spawnable.append(int(not definition.get("boss", false)))
	support.append(int(Catalog.is_support(kind)))
	skirmisher.append(int(role == "skirmish"))
	speed.append(float(definition.speed))
	hit_radius.append(float(definition.get("hitbox", {}).get("radius", BODY_RADIUS)))
	vision.append(tables.species_sight[kind] if tables != null else aggro_radius)
	var reach := float(definition.range)
	if tables != null:
		for slot in ATTACKS:
			var row: int = tables.fallback_row[kind] if slot == Enums.Slot.SPECIAL and support[kind] != 0 else tables.row(kind, slot)
			_set_attack(kind, slot, row)
		reach = tables.row_reach[tables.row(kind, Enums.Slot.BASIC)]
	preferred_range.append(reach * 0.85)
	max_range.append(reach)
	_compile_traits(kind)


func _compile_traits(kind: int) -> void:
	var pool_size: float = tables.species_mana_pool[kind] if tables != null else 0.0
	mana_pool.append(pool_size)
	mana_per_tick.append(tables.species_mana_channel[kind] / Clock.TICKS_PER_SECOND if tables != null else 0.0)
	var dearest := 0.0
	for slot in ATTACKS:
		dearest = maxf(dearest, attack_mana_cost[kind * ATTACKS + slot])
	mana_low.append(minf(dearest, pool_size))
	layer.append(int(tables.species_layer[kind] == Enums.Layer.AIR) if tables != null else 0)
	var cooldown: int = tables.species_dodge_cooldown_ms[kind] if tables != null else 0
	can_dodge.append(int(cooldown > 0))
	dodge_distance.append(tables.species_dodge_distance[kind] if tables != null else 0.0)
	dodge_ticks.append(Clock.from_ms(float(tables.species_dodge_ms[kind])) if tables != null else 0)
	dodge_cooldown.append(Clock.from_ms(float(cooldown)))


func _set_attack(kind: int, slot: int, row: int) -> void:
	if not tables.has_ability(row) or tables.row_target[row] == Enums.Target.DROP:
		# Grabbing dropped items needs the host's world, so it stays with the host's own behaviour.
		return
	var at := kind * ATTACKS + slot
	var delivery: int = tables.row_delivery[row]
	attack_row[at] = row
	attack_exists[at] = 1
	attack_shape[at] = _shape(row)
	if slot == Enums.Slot.BASIC:
		var close := delivery == Enums.Delivery.MELEE or delivery == Enums.Delivery.LEAP
		attack_delivery[at] = Contract.Delivery.MELEE if close else Contract.Delivery.RANGED
	else:
		attack_delivery[at] = Contract.Delivery.ANY
	attack_sight[at] = int(tables.row_sight[row] != Enums.Sight.NONE)
	if support[kind] != 0:
		attack_escort[at] = Escort.ALONE if row == tables.fallback_row[kind] else (Escort.ESCORTED if slot == Enums.Slot.BASIC else Escort.ANY)
	if slot == Enums.Slot.SIGNATURE:
		attack_mutation[at] = UNLOCK_SIGNATURE
	elif slot == Enums.Slot.COUNTER:
		attack_mutation[at] = UNLOCK_COUNTER
	attack_range[at] = tables.row_reach[row]
	attack_min_range[at] = tables.row_range_min[row]
	attack_area[at] = tables.row_radius[row]
	attack_windup[at] = Clock.from_ms(float(tables.row_windup_ms[row]))
	attack_min_windup[at] = Clock.from_ms(float(tables.row_min_windup_ms[row])) if tables.row_min_windup_ms[row] > 0 else 0
	attack_recovery[at] = Clock.from_ms(float(tables.row_recovery_ms[row]))
	attack_cooldown[at] = Clock.from_ms(float(tables.row_cooldown_ms[row])) if tables.row_cooldown_ms[row] > 0 else 0
	attack_lead[at] = tables.row_lead[row]
	attack_mana_cost[at] = tables.row_mana_cost[row]


## The coarse shape the brain and the observations see.
func _shape(row: int) -> int:
	match int(tables.row_delivery[row]):
		Enums.Delivery.RITE:
			return Shape.BUFF
		Enums.Delivery.SUMMON:
			return Shape.SUMMON
		Enums.Delivery.PULL:
			return Shape.PULL
		Enums.Delivery.LEAP:
			return Shape.LEAP if tables.row_shape[row] == Enums.Shape.CIRCLE else Shape.DASH
		Enums.Delivery.AIMED:
			return Shape.AIM_AREA
	return Shape.SELF_AREA


func has_attack(kind: int, slot: int, mutations: int) -> bool:
	var at := kind * ATTACKS + slot
	return attack_exists[at] != 0 and (attack_mutation[at] == 0 or (mutations & attack_mutation[at]) != 0)


## The unlock bits a mob earns at spawn. A floor of zero unlocks everything, which training uses.
## evidence holds one bit per DefinitionEnums.Evidence value.
func unlock_bits(kind: int, floor_number: int, evidence: int) -> int:
	if tables == null:
		return 0
	var bits := 0
	for pair in [[Enums.Slot.SIGNATURE, UNLOCK_SIGNATURE], [Enums.Slot.COUNTER, UNLOCK_COUNTER]]:
		var row: int = tables.row(kind, pair[0])
		if not tables.has_ability(row):
			continue
		var needs: int = tables.row_unlock_evidence[row]
		if floor_number <= 0 or (floor_number >= tables.row_unlock_floor[row] and (needs == Enums.Evidence.NONE or evidence & (1 << needs) != 0)):
			bits |= pair[1]
	return bits
