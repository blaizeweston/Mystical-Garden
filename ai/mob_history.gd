extends RefCounted
## Short rolling records of damage, built from the simulation event log.

const Events = preload("res://mob_sim/mob_events.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")

const BUCKET_TICKS := 15
const BUCKETS := 12
const ONE_SECOND_BUCKETS := 4

var pool: Pool
var players := 0
var taken := PackedFloat32Array()
var dealt := PackedFloat32Array()
var taken_from := PackedFloat32Array()
var dealt_to := PackedFloat32Array()
var engaged_at := PackedInt32Array()
var last_visible := PackedInt32Array()
var _cursor := 0
var _bucket := 0


func _init(mob_pool: Pool, player_count: int) -> void:
	pool = mob_pool
	players = player_count
	taken.resize(pool.capacity * BUCKETS)
	taken.fill(0.0)
	dealt.resize(pool.capacity * BUCKETS)
	dealt.fill(0.0)
	taken_from.resize(pool.capacity * players * BUCKETS)
	taken_from.fill(0.0)
	dealt_to.resize(pool.capacity * players * BUCKETS)
	dealt_to.fill(0.0)
	engaged_at.resize(pool.capacity)
	engaged_at.fill(-1)
	last_visible.resize(pool.capacity)
	last_visible.fill(-1)


func reset_slot(slot: int) -> void:
	for bucket in BUCKETS:
		taken[slot * BUCKETS + bucket] = 0.0
		dealt[slot * BUCKETS + bucket] = 0.0
		for player in players:
			taken_from[(slot * players + player) * BUCKETS + bucket] = 0.0
			dealt_to[(slot * players + player) * BUCKETS + bucket] = 0.0
	engaged_at[slot] = -1
	last_visible[slot] = -1


func update(events: Events, tick: int) -> void:
	_advance(tick / BUCKET_TICKS)
	for event in events.read_since(_cursor):
		var slot := int(event.slot)
		if pool.generation[slot] != int(event.generation):
			continue
		var bucket := (int(event.tick) / BUCKET_TICKS) % BUCKETS
		var player := int(event.a)
		if event.kind == Events.Kind.DAMAGE_TAKEN:
			taken[slot * BUCKETS + bucket] += float(event.value)
			if player >= 0:
				taken_from[(slot * players + player) * BUCKETS + bucket] += float(event.value)
		elif event.kind == Events.Kind.DAMAGE_DEALT:
			dealt[slot * BUCKETS + bucket] += float(event.value)
			dealt_to[(slot * players + player) * BUCKETS + bucket] += float(event.value)
	_cursor = events.head
	for slot in pool.active:
		if pool.engaged[slot] != 0 and engaged_at[slot] < 0:
			engaged_at[slot] = tick


## Clears each bucket as it comes back around, so a window never holds stale damage.
func _advance(bucket: int) -> void:
	var steps := mini(bucket - _bucket, BUCKETS)
	for step in steps:
		var column := (bucket - step) % BUCKETS
		for slot in pool.capacity:
			taken[slot * BUCKETS + column] = 0.0
			dealt[slot * BUCKETS + column] = 0.0
			for player in players:
				taken_from[(slot * players + player) * BUCKETS + column] = 0.0
				dealt_to[(slot * players + player) * BUCKETS + column] = 0.0
	_bucket = bucket


func bucket_index() -> int:
	return _bucket


func window_sum(table: PackedFloat32Array, row: int, buckets: int) -> float:
	var total := 0.0
	for back in buckets:
		total += table[row * BUCKETS + posmod(_bucket - back, BUCKETS)]
	return total
