extends RefCounted
## Timed conditions on mobs beyond movement control: damage over time, dodge windows, channeling and armour.
## Stun, root, slow and haste stay in MobPool and MobSim.apply_status. Only burning mobs are visited each
## tick, so an encounter with no damage over time pays nothing.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Tables = preload("res://mob_sim/definitions/definition_tables.gd")

## Damage over time lands four times a second, so each hit is one readable event rather than a stream.
const DOT_INTERVAL_TICKS := 15

var pool: Pool
## Damage multiplier for armoured mobs, from the shared enemy balance.
var armour_ratio := 1.0
## Damage multiplier while channeling, per species.
var channel_damage_taken := PackedFloat32Array()
## Mobs currently taking damage over time, in the order they started.
var burning := PackedInt32Array()


func _init(mob_pool: Pool, species_count: int) -> void:
	pool = mob_pool
	armour_ratio = float(preload("res://enemy_balance.gd").tuning.get("armor_damage_ratio", 1.0))
	var tables = Tables.shared()
	for kind in species_count:
		channel_damage_taken.append(tables.species_channel_damage_taken[kind] if tables != null else 1.0)


## Adds damage per second to a mob's existing damage over time and extends it. Stacks add up; the
## longest duration wins. The latest source is credited.
func apply_dot(slot: int, per_second: float, ticks: int, source_player: int, tick: int) -> void:
	if slot < 0 or slot >= pool.capacity or pool.alive[slot] == 0 or per_second <= 0.0 or ticks <= 0:
		return
	if tick >= pool.dot_until[slot]:
		pool.dot_dps[slot] = 0.0
		pool.dot_next[slot] = tick + DOT_INTERVAL_TICKS
	pool.dot_dps[slot] += per_second
	pool.dot_until[slot] = maxi(pool.dot_until[slot], tick + ticks)
	pool.dot_source[slot] = source_player if source_player >= 0 else Pool.NO_PLAYER
	if not burning.has(slot):
		burning.append(slot)


## Returns the damage over time due this tick, as slot and amount pairs, and retires finished entries.
## MobSim applies them through damage_mob so armour, dodges and deaths follow the usual rules.
func due(tick: int) -> Array:
	var result := []
	var kept := PackedInt32Array()
	for slot in burning:
		if pool.alive[slot] == 0 or pool.dot_dps[slot] <= 0.0:
			continue
		# Each application covers the ticks since the previous one, and the last covers the remainder,
		# so every burning tick deals damage exactly once.
		if tick >= pool.dot_next[slot] or tick >= pool.dot_until[slot]:
			var start := pool.dot_next[slot] - DOT_INTERVAL_TICKS
			var finish := mini(tick, pool.dot_until[slot])
			if finish > start:
				result.append([slot, pool.dot_dps[slot] * (finish - start) / float(Clock.TICKS_PER_SECOND), pool.dot_source[slot]])
			pool.dot_next[slot] = finish + DOT_INTERVAL_TICKS
		if pool.dot_next[slot] - DOT_INTERVAL_TICKS < pool.dot_until[slot]:
			kept.append(slot)
		else:
			pool.dot_dps[slot] = 0.0
	burning = kept
	return result


## Scales incoming damage for dodges, armour and channeling. Zero means the hit was dodged.
func scale_damage(slot: int, amount: float, tick: int) -> float:
	if tick < pool.dodge_until[slot]:
		return 0.0
	if pool.armour[slot] != 0:
		amount *= armour_ratio
	if tick < pool.channel_until[slot]:
		amount *= channel_damage_taken[pool.species[slot]]
	return amount


func clear_slot(slot: int) -> void:
	var index := burning.find(slot)
	if index >= 0:
		burning.remove_at(index)
