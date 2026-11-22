extends RefCounted
## Flat, read-only tables compiled from the enemy definitions for the simulation tick.
## Species index s matches catalog kind s. Ability rows are per species and slot: row = s * SLOTS + slot.
## Each species also has a fallback row for supports without escorts: row = fallback_row[s].
## Catalog values are resolved here, so the tick never parses JSON, compares strings or follows ids.

const Ability = preload("res://mob_sim/definitions/ability_def.gd")
const DefinitionSet = preload("res://mob_sim/definitions/definition_set.gd")
const Enums = preload("res://mob_sim/definitions/definition_enums.gd")
const Loader = preload("res://mob_sim/definitions/definition_loader.gd")

const SLOTS := Enums.SLOTS
## Set in row_flags when the radius grows with Reach and Spores mutations, as catalog radii do.
const ROW_RADIUS_GROWS := 1
const ROW_INTERRUPTIBLE := 2

static var _cached: RefCounted

var species_count := 0
var row_count := 0
var handler_names := PackedStringArray()

# Species tables, one entry per species.
var species_speed := PackedFloat32Array()
var species_body_radius := PackedFloat32Array()
var species_damage := PackedFloat32Array()
var species_layer := PackedByteArray()
var species_support := PackedByteArray()
var species_escort_min := PackedByteArray()
var species_escort_radius := PackedFloat32Array()
var species_boss := PackedByteArray()
var species_movement := PackedByteArray()
var species_sight := PackedFloat32Array()
var species_darkvision := PackedFloat32Array()
var species_hearing := PackedFloat32Array()
var species_smell := PackedFloat32Array()
var species_glow := PackedFloat32Array()
var species_armour := PackedByteArray()
var species_evasion := PackedFloat32Array()
var species_dodge_distance := PackedFloat32Array()
var species_dodge_ms := PackedInt32Array()
var species_dodge_cooldown_ms := PackedInt32Array()
var species_mana_pool := PackedFloat32Array()
var species_mana_channel := PackedFloat32Array()
var species_channel_damage_taken := PackedFloat32Array()
var fallback_row := PackedInt32Array()

# Ability rows. A row whose ability is NO_ABILITY is an empty slot.
var row_ability := PackedInt32Array()
var row_flags := PackedByteArray()
var row_delivery := PackedByteArray()
var row_target := PackedByteArray()
var row_sight := PackedByteArray()
var row_shape := PackedByteArray()
var row_anchor := PackedByteArray()
var row_lead := PackedFloat32Array()
var row_reach := PackedFloat32Array()
var row_range_min := PackedFloat32Array()
var row_windup_ms := PackedInt32Array()
var row_min_windup_ms := PackedInt32Array()
var row_recovery_ms := PackedInt32Array()
var row_cooldown_ms := PackedInt32Array()
var row_mana_cost := PackedFloat32Array()
var row_radius := PackedFloat32Array()
var row_width := PackedFloat32Array()
var row_span := PackedFloat32Array()
var row_along := PackedFloat32Array()
var row_spot_radius := PackedFloat32Array()
var row_area_count := PackedByteArray()
var row_spacing := PackedFloat32Array()
var row_offset_start := PackedInt32Array()
var row_offset_count := PackedByteArray()
var row_effect_start := PackedInt32Array()
var row_effect_count := PackedByteArray()
var row_unlock_floor := PackedInt32Array()
var row_unlock_evidence := PackedByteArray()
var row_elite_radius := PackedFloat32Array()
var row_elite_span := PackedFloat32Array()
## Index into handler_names, or -1.
var row_handler := PackedInt32Array()
## Shared spot offsets, x then y, addressed by row_offset_start.
var offsets := PackedFloat32Array()

# Effects, addressed by row_effect_start.
var effect_kind := PackedByteArray()
var effect_scale := PackedFloat32Array()
var effect_duration_ms := PackedInt32Array()
var effect_delay_ms := PackedInt32Array()
var effect_step_ms := PackedInt32Array()
var effect_radius := PackedFloat32Array()
var effect_hazard := PackedByteArray()
var effect_count := PackedByteArray()
var effect_distance := PackedFloat32Array()
var effect_interval_ms := PackedInt32Array()
var effect_arc := PackedFloat32Array()
var effect_offset := PackedFloat32Array()
var effect_species := PackedInt32Array()
var effect_handler := PackedInt32Array()

# Mutations, indexed by bit position.
var mutation_range_bonus := PackedFloat32Array()
var mutation_radius_bonus := PackedFloat32Array()
var mutation_speed_scale := PackedFloat32Array()
var mutation_armour := PackedByteArray()
var mutation_enables := PackedByteArray()

var vault_range_min := 0.0
var vault_range := 0.0
var vault_windup_ms := 0
var vault_unlock_floor := 1


## Returns the project's compiled tables, building them on first use. Fails loudly on bad data.
static func shared() -> RefCounted:
	if _cached == null:
		var definitions := Loader.shared()
		if not definitions.ok():
			push_error("Enemy definitions are invalid:\n" + "\n".join(definitions.errors))
			return null
		_cached = compile(definitions, float(preload("res://game_balance.gd").values.combat.aggro_radius))
	return _cached


static func compile(definitions: DefinitionSet, aggro_radius: float) -> RefCounted:
	var tables: RefCounted = new()
	tables._build(definitions, aggro_radius)
	return tables


func row(species: int, slot: int) -> int:
	return species * SLOTS + slot


func has_ability(row_index: int) -> bool:
	return row_ability[row_index] != Enums.NO_ABILITY


func _build(definitions: DefinitionSet, aggro_radius: float) -> void:
	handler_names = PackedStringArray(Loader.HANDLERS)
	species_count = definitions.species.size()
	row_count = species_count * SLOTS + species_count
	_build_mutations(definitions)
	vault_range_min = definitions.vault_range_min
	vault_range = definitions.vault_range
	vault_windup_ms = definitions.vault_windup_ms
	vault_unlock_floor = definitions.vault_unlock_floor
	var fallback := definitions.ability(definitions.support_fallback)
	for kind in species_count:
		var species = definitions.species[kind]
		var entry: Dictionary = definitions.catalog[kind]
		var traits = species.traits
		species_speed.append(float(entry.speed))
		species_body_radius.append(float(entry.get("hitbox", {}).get("radius", 0.5)))
		species_damage.append(float(entry.damage))
		species_layer.append(traits.layer)
		species_support.append(int(bool(entry.get("support", false)) or str(entry.role) == "chant"))
		species_escort_min.append(int(entry.get("escort_min", 0)))
		species_escort_radius.append(float(entry.get("escort_radius", 0.0)))
		species_boss.append(int(bool(entry.get("boss", false))))
		var movement := 0
		for kind_value in species.movement:
			movement |= 1 << kind_value
		species_movement.append(movement)
		species_sight.append(aggro_radius if is_nan(traits.sight) else traits.sight)
		species_darkvision.append(traits.darkvision)
		species_hearing.append(traits.hearing)
		species_smell.append(traits.smell)
		species_glow.append(traits.glow)
		species_armour.append(int(traits.armour))
		species_evasion.append(traits.evasion)
		species_dodge_distance.append(traits.dodge_distance)
		species_dodge_ms.append(traits.dodge_ms)
		species_dodge_cooldown_ms.append(traits.dodge_cooldown_ms)
		species_mana_pool.append(traits.mana_pool)
		species_mana_channel.append(traits.mana_channel_per_second)
		species_channel_damage_taken.append(traits.channel_damage_taken)
	for kind in species_count:
		var species = definitions.species[kind]
		for slot in SLOTS:
			_append_row(definitions, kind, species.kit[slot])
	for kind in species_count:
		fallback_row.append(row_ability.size())
		_append_row(definitions, kind, fallback.id if species_support[kind] != 0 else "")


func _append_row(definitions: DefinitionSet, kind: int, id: String) -> void:
	var entry: Dictionary = definitions.catalog[kind]
	var ability: Ability = definitions.ability(id) if not id.is_empty() else null
	var empty := ability == null
	row_ability.append(Enums.NO_ABILITY if empty else definitions.ability_index(id))
	if empty:
		ability = Ability.new()
		ability.shape = preload("res://mob_sim/definitions/shape_def.gd").new()
	var shape = ability.shape
	var flags := 0
	if not empty and is_nan(shape.radius):
		flags |= ROW_RADIUS_GROWS
	if ability.interruptible:
		flags |= ROW_INTERRUPTIBLE
	row_flags.append(flags)
	row_delivery.append(ability.delivery)
	row_target.append(ability.target)
	row_sight.append(ability.sight)
	row_shape.append(shape.kind)
	row_anchor.append(shape.anchor)
	row_lead.append(ability.lead)
	row_reach.append(float(entry.range) if is_nan(ability.reach) else ability.reach)
	row_range_min.append(ability.range_min)
	var windup := int(entry.windup) if is_nan(ability.windup_ms) else int(ability.windup_ms)
	row_windup_ms.append(windup + ability.windup_bonus_ms)
	row_min_windup_ms.append(ability.min_windup_ms)
	var recovery := int(entry.recovery) if is_nan(ability.recovery_ms) else int(ability.recovery_ms)
	row_recovery_ms.append(recovery + ability.recovery_bonus_ms)
	row_cooldown_ms.append(ability.cooldown_ms)
	row_mana_cost.append(ability.mana_cost)
	row_radius.append(float(entry.radius) if is_nan(shape.radius) else shape.radius)
	row_width.append(shape.width)
	row_span.append(shape.span)
	row_along.append(shape.along)
	row_spot_radius.append(shape.spot_radius)
	row_area_count.append(shape.area_count())
	row_spacing.append(shape.spacing)
	row_offset_start.append(offsets.size() >> 1)
	row_offset_count.append(shape.offsets.size())
	for offset in shape.offsets:
		offsets.append(offset.x)
		offsets.append(offset.y)
	row_effect_start.append(effect_kind.size())
	row_effect_count.append(ability.effects.size())
	for effect in ability.effects:
		effect_kind.append(effect.kind)
		effect_scale.append(effect.scale)
		effect_duration_ms.append(effect.duration_ms)
		effect_delay_ms.append(effect.delay_ms)
		effect_step_ms.append(effect.step_ms)
		effect_radius.append(effect.radius)
		effect_hazard.append(effect.hazard)
		effect_count.append(effect.count)
		effect_distance.append(effect.distance)
		effect_interval_ms.append(effect.interval_ms)
		effect_arc.append(effect.arc)
		effect_offset.append(effect.offset.x)
		effect_offset.append(effect.offset.y)
		effect_species.append(definitions.species_index(effect.species) if not effect.species.is_empty() else -1)
		effect_handler.append(handler_names.find(effect.handler) if not effect.handler.is_empty() else -1)
	row_unlock_floor.append(ability.unlock_floor)
	row_unlock_evidence.append(ability.unlock_evidence)
	row_elite_radius.append(ability.elite_radius_bonus)
	row_elite_span.append(ability.elite_span_bonus)
	row_handler.append(handler_names.find(ability.handler) if not ability.handler.is_empty() else -1)


func _build_mutations(definitions: DefinitionSet) -> void:
	var bits := 0
	for modifier in definitions.mutations:
		bits = maxi(bits, modifier.bit)
	var size := 0
	while (1 << size) <= bits:
		size += 1
	mutation_range_bonus.resize(size)
	mutation_radius_bonus.resize(size)
	mutation_speed_scale.resize(size)
	mutation_speed_scale.fill(1.0)
	mutation_armour.resize(size)
	mutation_enables.resize(size)
	for modifier in definitions.mutations:
		var index := 0
		while (1 << index) != modifier.bit:
			index += 1
		mutation_range_bonus[index] = modifier.range_bonus
		mutation_radius_bonus[index] = modifier.radius_bonus
		mutation_speed_scale[index] = modifier.speed_scale
		mutation_armour[index] = int(modifier.armour)
		var enables := 0
		for kind_value in modifier.enables:
			enables |= 1 << kind_value
		mutation_enables[index] = enables


## Hash of every table. Equal fingerprints mean identical compiled data.
func fingerprint() -> int:
	var parts := []
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			parts.append(get(property.name))
	return hash(parts)
