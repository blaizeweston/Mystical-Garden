extends RefCounted
## Builds each mob's observation row from what it can sense. Offsets come only from the schema.
## Fields the schema marks as masked stay at zero until their mechanics exist.

const Batch = preload("res://mob_sim/mob_decision_batch.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const History = preload("res://ai/mob_history.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Schema = preload("res://ai/mob_schema.gd")
const Species = preload("res://mob_sim/mob_species.gd")
const Fields = preload("res://mob_sim/mob_fields.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Tables = preload("res://mob_sim/definitions/definition_tables.gd")

const WALL_RANGE := 12.0
const COVER_RADII := [3.0, 6.0]
const COVER_ANGLES := 8
const COVER_CLEARANCE := 0.6
const FACING_DOT := 0.5
const NEVER_SEEN_SECONDS := 60.0
const RANGED_ROLE_REACH := 3.0

## Shared field names of the ally and leader blocks, in binding order.
const MATE_FIELDS := ["present", "dx", "dy", "distance", "hp_fraction", "hp_lost_1s", "damage_dealt_1s", "is_elite",
	"role_melee", "role_ranged", "role_support", "behaviour", "enemy_target", "message"]
enum Mate { PRESENT, DX, DY, DISTANCE, HP, HP_LOST, DEALT, ELITE, MELEE, RANGED, SUPPORT, BEHAVIOUR, TARGET, MESSAGE }

var schema: Schema
var errors := PackedStringArray()
var history: History
var seen_hp := PackedFloat32Array()
var seen_max_hp := PackedFloat32Array()
var seen_vx := PackedFloat32Array()
var seen_vz := PackedFloat32Array()

var _out := PackedFloat32Array()
var _row_base := 0
var _vision := 1.0
var _bound: Dictionary = {}
var _role_index: Dictionary = {}
var _caps: Schema.Block
var _ability: Schema.Block
var _dyn: Schema.Block
var _status: Schema.Block
var _intent: Schema.Block
var _archetype: Schema.Block
var _counts: Schema.Block
var _walls: Schema.Block
var _cover: Schema.Block
var _hazard: Schema.Block
var _enemy: Schema.Block
var _ally: Schema.Block
var _leader: Schema.Block
var _player: Schema.Block
var _totals: Schema.Block
var _ally_at := PackedInt32Array()
var _leader_at := PackedInt32Array()
var _leader_cooldown := 0
var _f: Dictionary = {}


func _init(model_schema: Schema) -> void:
	schema = model_schema
	_caps = schema.blocks.self_capabilities
	_ability = schema.blocks.self_ability
	_dyn = schema.blocks.self_dynamic
	_status = schema.blocks.self_status
	_intent = schema.blocks.self_intent
	_archetype = schema.blocks.self_archetype
	_counts = schema.blocks.context_counts
	_walls = schema.blocks.context_walls
	_cover = schema.blocks.context_cover
	_hazard = schema.blocks.context_hazard
	_enemy = schema.blocks.enemy
	_ally = schema.blocks.ally
	_leader = schema.blocks.leader
	_player = schema.global_blocks.player
	_totals = schema.global_blocks.totals
	for index in schema.archetypes.size():
		_role_index[schema.archetypes[index]] = index
	_bind_all()


## Every live schema field must have a source here, and no masked field may have one.
func _bind_all() -> void:
	_bind(_caps, ["walk_speed", "size", "max_hp", "vision_range", "auto_damage", "auto_range", "auto_cooldown", "fly_speed", "armour",
		"hearing_range", "smell_range", "darkvision_range", "evasion", "can_dodge", "uses_mana", "glow_radius"])
	_bind(_ability, ["exists", "damage", "range", "cooldown_total", "cooldown_remaining", "effect_sign", "area_radius", "windup_time"])
	_bind(_dyn, ["hp_fraction", "hp_change_1s", "hp_change_3s", "damage_dealt_1s", "damage_dealt_3s", "auto_cooldown_remaining",
		"time_since_behaviour_change", "behaviour_progress", "time_in_combat", "time_since_sight_lost", "is_leader", "intelligence",
		"resource_fraction", "dodge_cooldown", "channeling", "dodging", "light_level", "is_airborne"])
	_bind(_status, ["stunned", "slowed", "rooted", "buffed", "damage_over_time"])
	_bind(_intent, ["behaviour", "target"])
	_bind(_archetype, ["archetype"])
	_bind(_counts, ["allies_nearby", "enemies_nearby", "enemy_total_hp", "enemy_hp_fraction", "ally_total_hp", "ally_hp_fraction"])
	_bind(_walls, ["wall_distance"])
	_bind(_cover, ["present", "dx", "dy", "distance", "blocks_target_sight"])
	_bind(_hazard, ["present", "dx", "dy", "radius", "time_to_impact", "hostile", "mob_is_inside"])
	_bind(_enemy, ["present", "visible", "time_since_seen", "dx", "dy", "distance", "relative_vx", "relative_vy", "hp_fraction", "max_hp",
		"downed", "facing_me", "has_sight_of_me", "damage_they_dealt_me", "damage_i_dealt_them", "allies_targeting", "melee_damage",
		"ranged_damage", "melee_range", "ranged_range", "speed", "attack_speed", "dodge_cooldown", "armour", "winding_up", "dodging",
		"light_level"])
	_bind(_ally, MATE_FIELDS)
	_bind(_leader, MATE_FIELDS + ["ability_cooldown"])
	_bind(_player, ["present", "alive", "x", "z", "vx", "vz", "hp_fraction", "max_hp"])
	_bind(_totals, ["alive_by_archetype", "mob_total_hp", "party_total_hp", "episode_time", "objective_progress"])
	for label: String in MATE_FIELDS:
		_ally_at.append(_ally.at(label))
		_leader_at.append(_leader.at(label))
	_leader_cooldown = _leader.at("ability_cooldown")
	for block: Schema.Block in schema.ordered_blocks + schema.ordered_global:
		for label: String in block.fields:
			var has_source := _bound.has(block.name + "." + label)
			if has_source == bool(block.masked[label]):
				errors.append("%s.%s %s" % [block.name, label, "is masked but has a source" if has_source else "is live but has no source"])


func _bind(block: Schema.Block, labels: Array) -> void:
	for label: String in labels:
		if block.at(label) < 0:
			errors.append("Unknown field %s.%s" % [block.name, label])
		_bound[block.name + "." + label] = true
		_f[block.name + "." + label] = block.at(label)


func _at(key: String) -> int:
	return int(_f[key])


func bind_pool(pool: Pool, players: int) -> void:
	if history != null:
		return
	history = History.new(pool, players)
	var sensed := pool.capacity * players
	for table: PackedFloat32Array in [seen_hp, seen_max_hp, seen_vx, seen_vz]:
		table.resize(sensed)
		table.fill(0.0)


func reset_slot(slot: int) -> void:
	if history != null:
		history.reset_slot(slot)


func _put(index: int, value: float) -> void:
	var field := index - _row_base
	var kind := schema.scale_kind[field]
	if kind == Schema.ScaleKind.VISION:
		value /= _vision
	elif kind == Schema.ScaleKind.DIVIDE:
		value *= schema.scale_inverse[field]
	elif kind == Schema.ScaleKind.LOG1P:
		value = log(1.0 + maxf(value, 0.0)) * schema.scale_inverse[field]
	_out[index] = clampf(value, -schema.clip, schema.clip)


## Returns one row per mob in batch.slots.
func build(batch: Batch, events: Events) -> PackedFloat32Array:
	bind_pool(batch.pool, batch.contract.players)
	var tick := batch.clock.tick
	history.update(events, tick)
	var count := batch.slots.size()
	_out = PackedFloat32Array()
	_out.resize(count * schema.observation_size)
	_out.fill(0.0)
	if count == 0:
		return _out
	var query := PackedFloat32Array()
	for slot in batch.slots:
		query.append(slot)
	var nav: RefCounted = batch.perception.nav
	var walls: PackedFloat32Array = nav.wall_rays(query, WALL_RANGE)
	var targeting := _count_targeting(batch)
	for index in count:
		_write_row(batch, index, batch.slots[index], walls, targeting, tick)
	return _out


func _count_targeting(batch: Batch) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(batch.contract.players + 1)
	counts.fill(0)
	for slot in batch.pool.active:
		counts[batch.pool.enemy_target[slot]] += 1
	return counts


func _write_row(batch: Batch, index: int, slot: int, walls: PackedFloat32Array, targeting: PackedInt32Array, tick: int) -> void:
	var base := index * schema.observation_size
	var kind := batch.pool.species[slot]
	_row_base = base
	_vision = batch.species.vision[kind]
	_write_capabilities(batch, base, slot, kind)
	_write_abilities(batch, base, slot, kind, tick)
	_write_enemies(batch, base, slot, targeting, tick)
	_write_dynamic(batch, base, slot, kind, tick)
	_write_status(batch, base, slot, tick)
	_write_intent(batch, base, slot, kind)
	_write_mates(batch, base, slot, tick)
	_write_counts(batch, base, slot)
	var rays := int(_walls.sizes.wall_distance)
	for ray in rays:
		_put(base + _walls.offset + _at("context_walls.wall_distance") + ray, walls[index * rays + ray])
	_write_cover(batch, base, slot)
	_write_mechanics(batch, base, slot, kind, tick)
	_write_hazards(batch, base, slot, kind, tick)
	_write_player_stats(batch, base, slot, tick)


## Traits, mana, dodge, light and flight, as write_mechanics in native/mob_obs.c.
func _write_mechanics(batch: Batch, base: int, slot: int, kind: int, tick: int) -> void:
	var pool := batch.pool
	var table := batch.species
	var tables = Tables.shared()
	var flies: bool = table.layer[kind] != 0
	var full: float = table.mana_pool[kind]
	_put(base + _caps.offset + _at("self_capabilities.fly_speed"), pool.speed[slot] if flies else 0.0)
	_put(base + _caps.offset + _at("self_capabilities.armour"), float(pool.armour[slot] != 0))
	_put(base + _caps.offset + _at("self_capabilities.hearing_range"), tables.species_hearing[kind])
	_put(base + _caps.offset + _at("self_capabilities.smell_range"), tables.species_smell[kind])
	_put(base + _caps.offset + _at("self_capabilities.darkvision_range"), tables.species_darkvision[kind])
	_put(base + _caps.offset + _at("self_capabilities.evasion"), tables.species_evasion[kind])
	_put(base + _caps.offset + _at("self_capabilities.can_dodge"), float(table.can_dodge[kind] != 0))
	_put(base + _caps.offset + _at("self_capabilities.uses_mana"), float(full > 0.0))
	_put(base + _caps.offset + _at("self_capabilities.glow_radius"), table.glow[kind])
	var at := base + _dyn.offset
	_put(at + _at("self_dynamic.resource_fraction"), pool.mana[slot] / full if full > 0.0 else 1.0)
	if table.can_dodge[kind] != 0:
		_put(at + _at("self_dynamic.dodge_cooldown"), Clock.to_seconds(maxi(0, pool.dodge_ready_at[slot] - tick)))
	_put(at + _at("self_dynamic.channeling"), float(tick < pool.channel_until[slot]))
	_put(at + _at("self_dynamic.dodging"), float(tick < pool.dodge_until[slot]))
	_put(at + _at("self_dynamic.light_level"), batch.perception.nav.sense_light_at(pool.xz[slot * 2], pool.xz[slot * 2 + 1]))
	_put(at + _at("self_dynamic.is_airborne"), float(flies))
	_put(base + _status.offset + _at("self_status.damage_over_time"), float(tick < pool.dot_until[slot]))


## The nearest ground areas that have not ended, closest edge first and ties by index, as write_hazards in
## native/mob_obs.c. Distances use Vector2, which is single precision like the native code.
func _write_hazards(batch: Batch, base: int, slot: int, kind: int, tick: int) -> void:
	var fields = batch.fields
	var at := Vector2(batch.pool.xz[slot * 2], batch.pool.xz[slot * 2 + 1])
	var found := []
	for index in fields.count():
		if tick < fields.until[index]:
			found.append([at.distance_to(Vector2(fields.x[index], fields.z[index])) - fields.radius[index], index])
	found.sort()
	var flies: bool = batch.species.layer[kind] != 0
	for chosen in mini(found.size(), _hazard.repeat):
		var index: int = found[chosen][1]
		var write := base + _hazard.offset + chosen * _hazard.stride
		var offset := Vector2(fields.x[index], fields.z[index]) - at
		var radius: float = fields.radius[index]
		var ground: bool = fields.flags[index] & Fields.FLAG_GROUND != 0
		_put(write + _at("context_hazard.present"), 1.0)
		_put(write + _at("context_hazard.dx"), offset.x)
		_put(write + _at("context_hazard.dy"), offset.y)
		_put(write + _at("context_hazard.radius"), radius)
		_put(write + _at("context_hazard.time_to_impact"), Clock.to_seconds(maxi(0, fields.activate[index] - tick)))
		_put(write + _at("context_hazard.hostile"), float(fields.owner[index] == Fields.Owner.PLAYERS and not (ground and flies)))
		_put(write + _at("context_hazard.mob_is_inside"), float(offset.x * offset.x + offset.y * offset.y <= radius * radius))


## Player combat stats, known once a player is sensed; wind-ups and dodges only while in sight.
func _write_player_stats(batch: Batch, base: int, slot: int, tick: int) -> void:
	var party := batch.party
	var senses := batch.perception
	for player in batch.contract.players:
		var row := slot * batch.contract.players + player
		if party.present[player] == 0 or senses.seen_tick[row] < 0:
			continue
		var at := base + _enemy.offset + player * _enemy.stride
		var stat := player * Party.STAT_COUNT
		var timer := player * Party.TIMER_COUNT
		var sees := senses.sees(slot, player)
		_put(at + _at("enemy.melee_damage"), party.stats[stat + Party.Stat.MELEE_DAMAGE])
		_put(at + _at("enemy.ranged_damage"), party.stats[stat + Party.Stat.RANGED_DAMAGE])
		_put(at + _at("enemy.melee_range"), party.stats[stat + Party.Stat.MELEE_RANGE])
		_put(at + _at("enemy.ranged_range"), party.stats[stat + Party.Stat.RANGED_RANGE])
		_put(at + _at("enemy.speed"), party.stats[stat + Party.Stat.SPEED])
		_put(at + _at("enemy.attack_speed"), party.stats[stat + Party.Stat.ATTACK_SPEED])
		_put(at + _at("enemy.armour"), party.stats[stat + Party.Stat.ARMOUR])
		_put(at + _at("enemy.dodge_cooldown"), Clock.to_seconds(maxi(0, party.timers[timer + Party.Clocks.DODGE_READY] - tick)))
		_put(at + _at("enemy.winding_up"), float(sees and tick < party.timers[timer + Party.Clocks.WINDUP_UNTIL]))
		_put(at + _at("enemy.dodging"), float(sees and tick < party.timers[timer + Party.Clocks.DODGE_UNTIL]))
		_put(at + _at("enemy.light_level"), senses.nav.sense_light_at(senses.seen_x[row], senses.seen_z[row]))


func _write_capabilities(batch: Batch, base: int, slot: int, kind: int) -> void:
	var at := base + _caps.offset
	var table := batch.species
	_put(at + _at("self_capabilities.walk_speed"), batch.pool.speed[slot])
	_put(at + _at("self_capabilities.size"), table.hit_radius[kind])
	_put(at + _at("self_capabilities.max_hp"), batch.pool.max_hp[slot])
	_put(at + _at("self_capabilities.vision_range"), table.vision[kind])
	if table.has_attack(kind, 0, batch.pool.mutations[slot]):
		_put(at + _at("self_capabilities.auto_damage"), batch.pool.damage[slot])
		_put(at + _at("self_capabilities.auto_range"), table.attack_range[kind * Species.ATTACKS] + batch.pool.reach_bonus[slot])
		_put(at + _at("self_capabilities.auto_cooldown"), Clock.to_seconds(table.attack_recovery[kind * Species.ATTACKS]))


func _write_abilities(batch: Batch, base: int, slot: int, kind: int, tick: int) -> void:
	var table := batch.species
	for ability in _ability.repeat:
		var attack := ability + 1
		if not table.has_attack(kind, attack, batch.pool.mutations[slot]):
			continue
		var at := base + _ability.offset + ability * _ability.stride
		var row := kind * Species.ATTACKS + attack
		var shape := table.attack_shape[row]
		var helpful := shape == Species.Shape.BUFF or shape == Species.Shape.SUMMON
		var ready: int = maxi(batch.pool.ready_at[slot], batch.pool.cooldown_until[slot * batch.pool.attacks + attack])
		_put(at + _at("self_ability.exists"), 1.0)
		_put(at + _at("self_ability.damage"), 0.0 if helpful else batch.pool.damage[slot])
		_put(at + _at("self_ability.range"), table.attack_range[row] + batch.pool.reach_bonus[slot])
		_put(at + _at("self_ability.cooldown_total"), Clock.to_seconds(table.attack_recovery[row]))
		_put(at + _at("self_ability.cooldown_remaining"), Clock.to_seconds(maxi(0, ready - tick)))
		_put(at + _at("self_ability.effect_sign"), 1.0 if helpful else -1.0)
		_put(at + _at("self_ability.area_radius"), table.attack_area[row])
		_put(at + _at("self_ability.windup_time"), Clock.to_seconds(table.attack_windup[row]))


func _write_dynamic(batch: Batch, base: int, slot: int, kind: int, tick: int) -> void:
	var at := base + _dyn.offset
	var pool := batch.pool
	var max_hp: float = pool.max_hp[slot]
	_put(at + _at("self_dynamic.hp_fraction"), pool.hp[slot] / max_hp)
	_put(at + _at("self_dynamic.hp_change_1s"), -history.window_sum(history.taken, slot, History.ONE_SECOND_BUCKETS) / max_hp)
	_put(at + _at("self_dynamic.hp_change_3s"), -history.window_sum(history.taken, slot, History.BUCKETS) / max_hp)
	_put(at + _at("self_dynamic.damage_dealt_1s"), history.window_sum(history.dealt, slot, History.ONE_SECOND_BUCKETS))
	_put(at + _at("self_dynamic.damage_dealt_3s"), history.window_sum(history.dealt, slot, History.BUCKETS))
	if batch.species.has_attack(kind, 0, pool.mutations[slot]):
		_put(at + _at("self_dynamic.auto_cooldown_remaining"), Clock.to_seconds(maxi(0, pool.ready_at[slot] - tick)))
	var since := tick - pool.behaviour_since[slot]
	_put(at + _at("self_dynamic.time_since_behaviour_change"), Clock.to_seconds(since))
	var hold := maxi(1, Clock.from_ms(batch.contract.hold_ms[pool.behaviour[slot]]))
	_put(at + _at("self_dynamic.behaviour_progress"), minf(1.0, float(since) / hold))
	if history.engaged_at[slot] >= 0:
		_put(at + _at("self_dynamic.time_in_combat"), Clock.to_seconds(tick - history.engaged_at[slot]))
	var last_seen: int = history.last_visible[slot]
	_put(at + _at("self_dynamic.time_since_sight_lost"), Clock.to_seconds(tick - last_seen) if last_seen >= 0 else NEVER_SEEN_SECONDS)
	_put(at + _at("self_dynamic.is_leader"), float(pool.is_leader(slot)))
	_put(at + _at("self_dynamic.intelligence"), pool.intelligence[slot])


func _write_status(batch: Batch, base: int, slot: int, tick: int) -> void:
	var at := base + _status.offset
	var pool := batch.pool
	_put(at + _at("self_status.stunned"), float(tick < pool.stun_until[slot]))
	_put(at + _at("self_status.slowed"), float(tick < pool.slow_until[slot]))
	_put(at + _at("self_status.rooted"), float(tick < pool.root_until[slot]))
	_put(at + _at("self_status.buffed"), float(tick < pool.haste_until[slot]))


func _write_intent(batch: Batch, base: int, slot: int, kind: int) -> void:
	var pool := batch.pool
	var contract := batch.contract
	var behaviour := pool.behaviour[slot]
	_out[base + _intent.offset + _at("self_intent.behaviour") + behaviour] = 1.0
	var target := 0
	if contract.target_kind[behaviour] == Contract.TargetKind.ALLY:
		target = contract.players + pool.ally_target[slot] if pool.ally_target[slot] > 0 else 0
	else:
		target = pool.enemy_target[slot]
	_out[base + _intent.offset + _at("self_intent.target") + target] = 1.0
	var role: int = _role_index.get(batch.species.roles[kind], -1)
	if role >= 0:
		_out[base + _archetype.offset + _at("self_archetype.archetype") + role] = 1.0


func _write_enemies(batch: Batch, base: int, slot: int, targeting: PackedInt32Array, tick: int) -> void:
	var pool := batch.pool
	var party := batch.party
	var senses := batch.perception
	var x := pool.xz[slot * 2]
	var z := pool.xz[slot * 2 + 1]
	var sees_any := false
	for player in batch.contract.players:
		var row := slot * batch.contract.players + player
		var known: bool = senses.seen_tick[row] >= 0
		if party.present[player] == 0 or not known:
			continue
		var at := base + _enemy.offset + player * _enemy.stride
		var sees := senses.sees(slot, player)
		if sees:
			sees_any = true
			seen_hp[row] = party.hp[player]
			seen_max_hp[row] = party.max_hp[player]
			seen_vx[row] = party.vx[player]
			seen_vz[row] = party.vz[player]
		var dx := senses.seen_x[row] - x
		var dz := senses.seen_z[row] - z
		var distance := sqrt(dx * dx + dz * dz)
		_put(at + _at("enemy.present"), 1.0)
		_put(at + _at("enemy.visible"), float(sees))
		_put(at + _at("enemy.time_since_seen"), Clock.to_seconds(tick - senses.seen_tick[row]))
		_put(at + _at("enemy.dx"), dx)
		_put(at + _at("enemy.dy"), dz)
		_put(at + _at("enemy.distance"), distance)
		_put(at + _at("enemy.relative_vx"), seen_vx[row])
		_put(at + _at("enemy.relative_vy"), seen_vz[row])
		_put(at + _at("enemy.hp_fraction"), seen_hp[row] / maxf(1.0, seen_max_hp[row]))
		_put(at + _at("enemy.max_hp"), seen_max_hp[row])
		_put(at + _at("enemy.downed"), float(party.alive[player] == 0))
		var toward_me := Vector2(-dx, -dz).normalized().dot(Vector2(seen_vx[row], seen_vz[row]).normalized())
		_put(at + _at("enemy.facing_me"), float(sees and toward_me >= FACING_DOT))
		_put(at + _at("enemy.has_sight_of_me"), float(sees))
		_put(at + _at("enemy.damage_they_dealt_me"), history.window_sum(history.taken_from, row, History.BUCKETS))
		_put(at + _at("enemy.damage_i_dealt_them"), history.window_sum(history.dealt_to, row, History.BUCKETS))
		_put(at + _at("enemy.allies_targeting"), targeting[player + 1] - int(pool.enemy_target[slot] == player + 1))
	if sees_any:
		history.last_visible[slot] = tick


func _write_mates(batch: Batch, base: int, slot: int, tick: int) -> void:
	for index in _ally.repeat:
		var other := batch.perception.ally(slot, index)
		if other >= 0 and batch.pool.alive[other] != 0:
			_write_mate(batch, base + _ally.offset + index * _ally.stride, _ally_at, slot, other)
	var leader := batch.pool.leader_of(slot)
	if leader < 0:
		return
	_write_mate(batch, base + _leader.offset, _leader_at, slot, leader)
	for ability in _leader.sizes.ability_cooldown:
		var ready: int = batch.pool.cooldown_until[leader * batch.pool.attacks + ability + 1]
		_put(base + _leader.offset + _leader_cooldown + ability, Clock.to_seconds(maxi(0, ready - tick)))


func _write_mate(batch: Batch, at: int, fields: PackedInt32Array, slot: int, other: int) -> void:
	var pool := batch.pool
	var kind := pool.species[other]
	var dx := pool.xz[other * 2] - pool.xz[slot * 2]
	var dz := pool.xz[other * 2 + 1] - pool.xz[slot * 2 + 1]
	_put(at + fields[Mate.PRESENT], 1.0)
	_put(at + fields[Mate.DX], dx)
	_put(at + fields[Mate.DY], dz)
	_put(at + fields[Mate.DISTANCE], sqrt(dx * dx + dz * dz))
	_put(at + fields[Mate.HP], pool.hp[other] / pool.max_hp[other])
	_put(at + fields[Mate.HP_LOST], history.window_sum(history.taken, other, History.ONE_SECOND_BUCKETS) / pool.max_hp[other])
	_put(at + fields[Mate.DEALT], history.window_sum(history.dealt, other, History.ONE_SECOND_BUCKETS))
	_put(at + fields[Mate.ELITE], float(pool.is_leader(other)))
	var support: bool = batch.species.support[kind] != 0
	var ranged: bool = batch.species.max_range[kind] > RANGED_ROLE_REACH
	_put(at + fields[Mate.MELEE], float(not support and not ranged))
	_put(at + fields[Mate.RANGED], float(not support and ranged))
	_put(at + fields[Mate.SUPPORT], float(support))
	_out[at + fields[Mate.BEHAVIOUR] + pool.behaviour[other]] = 1.0
	_out[at + fields[Mate.TARGET] + pool.enemy_target[other]] = 1.0
	_out[at + fields[Mate.MESSAGE] + pool.message_a[other]] = 1.0
	_out[at + fields[Mate.MESSAGE] + batch.contract.message_symbols + pool.message_b[other]] = 1.0


func _write_counts(batch: Batch, base: int, slot: int) -> void:
	var at := base + _counts.offset
	var pool := batch.pool
	var allies := 0
	var ally_hp := pool.hp[slot]
	var ally_max := pool.max_hp[slot]
	for index in batch.contract.allies:
		var other := batch.perception.ally(slot, index)
		if other >= 0 and pool.alive[other] != 0:
			allies += 1
			ally_hp += pool.hp[other]
			ally_max += pool.max_hp[other]
	var enemies := 0
	var enemy_hp := 0.0
	var enemy_max := 0.0
	for player in batch.contract.players:
		var row := slot * batch.contract.players + player
		if batch.perception.seen_tick[row] >= 0 and batch.party.present[player] != 0:
			enemies += 1
			enemy_hp += seen_hp[row]
			enemy_max += seen_max_hp[row]
	_put(at + _at("context_counts.allies_nearby"), allies)
	_put(at + _at("context_counts.enemies_nearby"), enemies)
	_put(at + _at("context_counts.enemy_total_hp"), enemy_hp)
	_put(at + _at("context_counts.enemy_hp_fraction"), enemy_hp / enemy_max if enemy_max > 0.0 else 0.0)
	_put(at + _at("context_counts.ally_total_hp"), ally_hp)
	_put(at + _at("context_counts.ally_hp_fraction"), ally_hp / ally_max)


## Reports the two closest open spots, preferring those the mob's current target cannot see.
func _write_cover(batch: Batch, base: int, slot: int) -> void:
	var nav: RefCounted = batch.perception.nav
	var origin := Vector2(batch.pool.xz[slot * 2], batch.pool.xz[slot * 2 + 1])
	var points := PackedVector2Array()
	for radius: float in COVER_RADII:
		for step in COVER_ANGLES:
			var point := origin + Vector2.from_angle(step * TAU / COVER_ANGLES) * radius
			if nav.clearance(point.x, point.y) >= COVER_CLEARANCE:
				points.append(point)
	if points.is_empty():
		return
	var blocked := PackedByteArray()
	blocked.resize(points.size())
	blocked.fill(0)
	var player := batch.pool.enemy_target[slot] - 1
	if player >= 0 and batch.perception.knows(slot, player):
		var row := slot * batch.contract.players + player
		var queries := PackedFloat32Array()
		for point in points:
			queries.append_array(PackedFloat32Array([batch.perception.seen_x[row], batch.perception.seen_z[row], point.x, point.y, 0.0]))
		var clear: PackedByteArray = nav.sight_clear_batch(queries)
		for index in points.size():
			blocked[index] = int(clear[index] == 0)
	var chosen := 0
	for wanted: int in [1, 0]:
		for index in points.size():
			if chosen < _cover.repeat and blocked[index] == wanted:
				_write_cover_slot(base + _cover.offset + chosen * _cover.stride, points[index] - origin, wanted)
				chosen += 1


func _write_cover_slot(at: int, offset: Vector2, blocks_sight: int) -> void:
	_put(at + _at("context_cover.present"), 1.0)
	_put(at + _at("context_cover.dx"), offset.x)
	_put(at + _at("context_cover.dy"), offset.y)
	_put(at + _at("context_cover.distance"), offset.length())
	_put(at + _at("context_cover.blocks_target_sight"), blocks_sight)


## The critic's true view of the encounter. It is used only in training and never reaches a shipped mob.
func build_global(batch: Batch) -> PackedFloat32Array:
	var row := PackedFloat32Array()
	row.resize(schema.global_size)
	row.fill(0.0)
	var party := batch.party
	var party_hp := 0.0
	for player in batch.contract.players:
		var at := _player.offset + player * _player.stride
		_global(row, at + _at("player.present"), party.present[player])
		_global(row, at + _at("player.alive"), party.alive[player])
		_global(row, at + _at("player.x"), party.x[player])
		_global(row, at + _at("player.z"), party.z[player])
		_global(row, at + _at("player.vx"), party.vx[player])
		_global(row, at + _at("player.vz"), party.vz[player])
		_global(row, at + _at("player.hp_fraction"), party.hp[player] / maxf(1.0, party.max_hp[player]))
		_global(row, at + _at("player.max_hp"), party.max_hp[player])
		party_hp += party.hp[player]
	var mob_hp := 0.0
	var alive := PackedInt32Array()
	alive.resize(int(_totals.sizes.alive_by_archetype))
	alive.fill(0)
	for slot in batch.pool.active:
		mob_hp += batch.pool.hp[slot]
		var role: int = _role_index.get(batch.species.roles[batch.pool.species[slot]], -1)
		if role >= 0:
			alive[role] += 1
	for role in alive.size():
		_global(row, _totals.offset + _at("totals.alive_by_archetype") + role, alive[role])
	_global(row, _totals.offset + _at("totals.mob_total_hp"), mob_hp)
	_global(row, _totals.offset + _at("totals.party_total_hp"), party_hp)
	_global(row, _totals.offset + _at("totals.episode_time"), Clock.to_seconds(batch.clock.tick))
	# Protect the supports: the share of supports spawned this episode that are still alive.
	var supports := 0
	for slot in batch.pool.active:
		supports += int(batch.species.support[batch.pool.species[slot]] != 0)
	var spawned := batch.pool.supports_spawned
	_global(row, _totals.offset + _at("totals.objective_progress"), float(supports) / spawned if spawned > 0 else 1.0)
	return row


func _global(row: PackedFloat32Array, index: int, value: float) -> void:
	row[index] = schema.scaled(schema.global_kind[index], schema.global_inverse[index], value)
