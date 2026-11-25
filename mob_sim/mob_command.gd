extends RefCounted
## Each fight's commander: the one mob every other mob listens to through the leader channels (the observation's
## "leader" block: its two message channels, position, health, behaviour and target).
##
## The elite commands while it is alive. Without one, the brightest mob does (highest intelligence; the lowest
## slot breaks ties), and when the commander dies the brightest survivor takes over. The commander carries
## MobPool.FLAG_LEADER (an elite keeps FLAG_ELITE either way) and follows no one; every other mob has it as its
## leader. Followers only listen: an idle follower wanders near its own spawn unless its commander is an elite,
## which keeps its pack close as before (mob_executors). The commander's messages hold for
## rules.commander_message_ms before they can change (MobRules), and it shares its followers' reward (MobRewards).
##
## On when the contract's rules.commander is true. MobSim refreshes it every tick, before anyone decides.

const Pool = preload("res://mob_sim/mob_pool.gd")

var pool: Pool
var enabled := false
## The commanding slot, or -1 when no mob is alive.
var commander := -1
var _generation := 0


func _init(mob_pool: Pool, on: bool) -> void:
	pool = mob_pool
	enabled = on


## Keeps exactly one commander among the living and points every other mob at it.
func refresh() -> void:
	if not enabled:
		return
	var current := commander if commander >= 0 and pool.alive[commander] != 0 and pool.generation[commander] == _generation else -1
	var chosen := -1
	for slot in pool.active:
		if pool.flags[slot] & Pool.FLAG_ELITE != 0:
			chosen = slot
			break
	if chosen < 0:
		chosen = current
	if chosen < 0:
		var best := -1.0
		for slot in pool.active:
			if pool.intelligence[slot] > best or (pool.intelligence[slot] == best and slot < chosen):
				best = pool.intelligence[slot]
				chosen = slot
	if current >= 0 and chosen != current and pool.flags[current] & Pool.FLAG_ELITE == 0:
		pool.flags[current] &= ~Pool.FLAG_LEADER
	commander = chosen
	if chosen < 0:
		return
	_generation = pool.generation[chosen]
	pool.flags[chosen] |= Pool.FLAG_LEADER
	pool.leader[chosen] = -1
	for slot in pool.active:
		if slot != chosen and pool.leader_of(slot) != chosen:
			pool.set_leader(slot, chosen)


## Whether a slot is the current commander.
func commands(slot: int) -> bool:
	return enabled and slot == commander and slot >= 0 and pool.alive[slot] != 0 and pool.generation[slot] == _generation


## How many living mobs follow the commander.
func follower_count() -> int:
	if commander < 0:
		return 0
	var count := 0
	for slot in pool.active:
		count += int(slot != commander and pool.leader_of(slot) == commander)
	return count
