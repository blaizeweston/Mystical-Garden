extends RefCounted
## Connects the schema and live simulation arrays to the native observation builder and policy.
## The lists below follow the enums in mob_sim/native/mob_obs.h. Offsets still come from the schema.

const Batch = preload("res://mob_sim/mob_decision_batch.gd")
const Builder = preload("res://ai/mob_observation_builder.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const History = preload("res://ai/mob_history.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Schema = preload("res://ai/mob_schema.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const MATE_LABELS := ["present", "dx", "dy", "distance", "hp_fraction", "hp_lost_1s", "damage_dealt_1s", "is_elite",
	"role_melee", "role_ranged", "role_support", "behaviour", "enemy_target", "message"]

## Follows MoField.
const FIELD_KEYS := [
	["self_capabilities", ["walk_speed", "size", "max_hp", "vision_range", "auto_damage", "auto_range", "auto_cooldown"]],
	["self_ability", ["exists", "damage", "range", "cooldown_total", "cooldown_remaining", "effect_sign", "area_radius", "windup_time"]],
	["self_dynamic", ["hp_fraction", "hp_change_1s", "hp_change_3s", "damage_dealt_1s", "damage_dealt_3s", "auto_cooldown_remaining",
		"time_since_behaviour_change", "behaviour_progress", "time_in_combat", "time_since_sight_lost", "is_leader", "intelligence"]],
	["self_status", ["stunned", "slowed", "rooted", "buffed"]],
	["self_intent", ["behaviour", "target"]],
	["self_archetype", ["archetype"]],
	["context_counts", ["allies_nearby", "enemies_nearby", "enemy_total_hp", "enemy_hp_fraction", "ally_total_hp", "ally_hp_fraction"]],
	["context_walls", ["wall_distance"]],
	["context_cover", ["present", "dx", "dy", "distance", "blocks_target_sight"]],
	["enemy", ["present", "visible", "time_since_seen", "dx", "dy", "distance", "relative_vx", "relative_vy", "hp_fraction", "max_hp",
		"downed", "facing_me", "has_sight_of_me", "damage_they_dealt_me", "damage_i_dealt_them", "allies_targeting"]],
	["ally", MATE_LABELS],
	["leader", MATE_LABELS + ["ability_cooldown"]],
]

var schema: Schema
var world: RefCounted
var history: History
var error := ""
var _configured := false


func _init(model_schema: Schema, nav_world: RefCounted) -> void:
	schema = model_schema
	world = nav_world


## Tells the native policy where each encoder reads from in an observation row.
static func policy_layout(model_schema: Schema, capacity: int) -> PackedFloat32Array:
	var layout := PackedFloat32Array([model_schema.observation_size, 0])
	var ranges := 0
	for block in model_schema.ordered_blocks:
		if block.encoder == "self":
			layout.append(block.offset)
			layout.append(block.stride * block.repeat)
			ranges += 1
	layout[1] = ranges
	var enemy: Schema.Block = model_schema.blocks.enemy
	var ally: Schema.Block = model_schema.blocks.ally
	var leader: Schema.Block = model_schema.blocks.leader
	var logits := 0
	for size in model_schema.contract.head_sizes:
		logits += size
	layout.append_array(PackedFloat32Array([enemy.offset, enemy.stride, enemy.repeat, ally.offset, ally.stride, ally.repeat,
		leader.offset, leader.stride, logits, int(model_schema.network.recurrent_hidden), capacity]))
	return layout


func reset_slot(slot: int) -> void:
	world.obs_reset_slot(slot)
	if history != null:
		history.reset_slot(slot)


func _field_offsets() -> PackedInt32Array:
	var offsets := PackedInt32Array()
	for entry: Array in FIELD_KEYS:
		var block: Schema.Block = schema.blocks[entry[0]]
		for label: String in entry[1]:
			offsets.append(block.offset + block.at(label))
	return offsets


func _configure(batch: Batch) -> bool:
	var pool := batch.pool
	var table := batch.species
	var contract := batch.contract
	history = History.new(pool, contract.players)
	var roles := PackedInt32Array()
	for role in table.roles:
		roles.append(schema.archetypes.find(role))
	var hold := PackedInt32Array()
	for milliseconds in contract.hold_ms:
		hold.append(Clock.from_ms(milliseconds))
	var dims := PackedInt32Array([pool.capacity, contract.players, contract.allies, pool.attacks, table.count, contract.behaviour_count,
		contract.message_symbols, schema.observation_size, History.BUCKETS, History.ONE_SECOND_BUCKETS, schema.blocks.self_ability.repeat,
		schema.blocks.context_cover.repeat, Species.Shape.BUFF, Species.Shape.SUMMON, Contract.TargetKind.ALLY,
		Pool.FLAG_LEADER | Pool.FLAG_ELITE])
	var strides := PackedInt32Array([schema.blocks.self_ability.stride, schema.blocks.enemy.stride, schema.blocks.ally.stride,
		schema.blocks.context_cover.stride])
	var reals := PackedFloat32Array([schema.clip, Builder.WALL_RANGE, Builder.COVER_CLEARANCE, Builder.FACING_DOT,
		Builder.NEVER_SEEN_SECONDS, Builder.RANGED_ROLE_REACH, Clock.TICKS_PER_SECOND])
	var status: int = world.obs_configure([dims, _field_offsets(), strides, schema.scale_kind, schema.scale_inverse, reals,
		table.vision, table.hit_radius, table.max_range, table.support, roles,
		table.attack_exists, table.attack_mutation, table.attack_shape, table.attack_range, table.attack_area,
		table.attack_windup, table.attack_recovery, hold, contract.target_kind])
	if status != OK:
		error = "The native observation builder refused its configuration."
	_configured = status == OK
	return _configured


## Returns one observation row per mob in batch.slots.
func build(batch: Batch, events: Events) -> PackedFloat32Array:
	if not _configured and not _configure(batch):
		return PackedFloat32Array()
	var tick := batch.clock.tick
	history.update(events, tick)
	var pool := batch.pool
	var party := batch.party
	var senses := batch.perception
	return world.obs_build([PackedInt32Array([tick, history.bucket_index()]), batch.slots, pool.active, pool.alive, pool.generation,
		pool.species, pool.flags, pool.mutations, pool.leader, pool.leader_generation,
		pool.xz, pool.hp, pool.max_hp, pool.speed, pool.damage, pool.reach_bonus, pool.intelligence,
		pool.behaviour, pool.enemy_target, pool.ally_target, pool.message_a, pool.message_b, pool.behaviour_since,
		pool.ready_at, pool.cooldown_until, pool.stun_until, pool.root_until, pool.slow_until, pool.haste_until,
		senses.visible, senses.seen_x, senses.seen_z, senses.seen_tick, senses.allies,
		party.present, party.alive, party.hp, party.max_hp, party.vx, party.vz,
		history.taken, history.dealt, history.taken_from, history.dealt_to, history.engaged_at])
