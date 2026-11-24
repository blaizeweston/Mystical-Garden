extends RefCounted
## Turns what happens in an encounter into rewards for each mob (rewards v2, weights in ai/training/rewards.json).
## Call tick() once after every simulation tick; take(slot) returns the reward a mob earned since its last
## decision. Only training uses this: shipped mobs never compute rewards.
##
## Unit: one player's full health bar is 1.0.
## - Damage a mob deals: +damage per health bar of the player hit.
## - Healing a mob does: +healing per health bar of the mob healed.
## - Downing a player: +player_downed for every mob that hit them within the assist window, and
##   +player_killing_blow, kept whole (no squad share), for the mob whose hit downed them.
## - Finding the party: a small one-off reward the first time a mob sees any player in its life, so mobs that
##   start far away learn to search the floor.
## - Making a player dodge its attack: a small reward, since the player spends its dodge.
## - Dodging a player's hit: a smaller one.
## - Landing an ability (attacks 1 to 3) on a player who was not dodging: a small reward, so abilities that
##   deal no damage (roots, pulls, slows) also pay.
## - Seeing its current target: a trickle per second, capped per decision, so a mob that keeps out of sight (camping
##   in cover) earns less than one that keeps pressure on, while a brief duck into cover costs little.
## - A support ally alive and casting (winding up or channeling): a small trickle per second, for the mob's allies.
## - Health the mob loses: -own_hp_lost per health bar of its own.
## - Losing a support: -support_lost times the support's value, to each of the support's allies.
## - Its own death: -own_death times its value.
## - A party wipe: +party_wipe to every mob alive that hit a player within the wipe assist window. Mobs that kept out
##   of the fight earn nothing for it, so hiding until the others finish the party no longer pays.
## - Changing intent: an optional cost (intent_change, now 0: behaviour holds already stop thrashing).
## A share of every reward (squad mix) goes to the mob's nearest allies, so mobs also value their squad's success.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")

const PATH := "res://ai/training/rewards.json"
## Sight and support trickles are added every TRICKLE_TICKS rather than every tick.
const TRICKLE_TICKS := 6

var sim: RefCounted
var weights: Dictionary = {}
## Share of each reward given to the mob's allies. The trainer moves it from squad_mix_start to squad_mix_end.
var squad_mix := 0.0
## Reward earned since each slot's last take().
var pending := PackedFloat32Array()
## Totals since the last reset, for reports: damage, healing, downs, killing_blows, wipes, found, evaded, dodged, landed, sight, support,
## hp_lost, support_lost, deaths, intent.
var totals := {}
var _cursor := 0
var _was_alive := PackedByteArray()
var _sight_left := PackedFloat32Array()
var _found := PackedByteArray()
## The attack each slot released last, which its hits come from.
var _released := PackedInt32Array()
## Last tick each mob hit each player, by slot * players + player.
var _last_hit := PackedInt32Array()
var _generation := PackedInt32Array()
var _assist_ticks := 0
var _wipe_assist_ticks := 0


func _init(simulation: RefCounted, path: String = PATH) -> void:
	sim = simulation
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	weights = parsed.mob if parsed is Dictionary and parsed.has("mob") else {}
	squad_mix = float(weights.get("squad_mix_start", 0.0))
	var capacity: int = sim.pool.capacity
	var players: int = sim.contract.players
	pending.resize(capacity)
	pending.fill(0.0)
	_sight_left.resize(capacity)
	_sight_left.fill(_sight_cap())
	_found.resize(capacity)
	_found.fill(0)
	_released.resize(capacity)
	_released.fill(-1)
	_generation.resize(capacity)
	_generation.fill(-1)
	_last_hit.resize(capacity * players)
	_last_hit.fill(-1000000)
	_was_alive.resize(players)
	_was_alive.fill(0)
	_assist_ticks = Clock.from_ms(float(weights.get("assist_window_seconds", 5.0)) * 1000.0)
	_wipe_assist_ticks = Clock.from_ms(float(weights.get("wipe_assist_window_seconds", 10.0)) * 1000.0)
	_cursor = sim.events.head
	reset_totals()


func reset_totals() -> void:
	totals = {"damage": 0.0, "healing": 0.0, "downs": 0, "killing_blows": 0, "wipes": 0, "found": 0, "evaded": 0, "dodged": 0, "landed": 0, "sight": 0.0, "support": 0.0, "hp_lost": 0.0,
		"support_lost": 0.0, "deaths": 0, "intent": 0.0}


## The reward a mob earned since it last decided. Resets its sight allowance.
func take(slot: int) -> float:
	var value := pending[slot]
	pending[slot] = 0.0
	_sight_left[slot] = _sight_cap()
	return value


func tick() -> void:
	var now: int = sim.clock.tick
	for event in sim.events.read_since(_cursor):
		_event(event, now)
	_cursor = sim.events.head
	_party(now)
	if now % TRICKLE_TICKS == 0:
		_trickles()


func _event(event: Dictionary, now: int) -> void:
	var slot := int(event.slot)
	var pool = sim.pool
	var players: int = sim.contract.players
	match int(event.kind):
		Events.Kind.SPAWN:
			_generation[slot] = int(event.generation)
			pending[slot] = 0.0
			_found[slot] = 0
			_released[slot] = -1
			for player in players:
				_last_hit[slot * players + player] = -1000000
		Events.Kind.DAMAGE_DEALT:
			var player := int(event.a)
			var bar: float = maxf(1.0, sim.party.max_hp[player])
			_give(slot, float(weights.get("damage_to_player_per_health_bar", 1.0)) * float(event.value) / bar, "damage")
			if player >= 0 and player < players:
				_last_hit[slot * players + player] = now
		Events.Kind.HEALED:
			var target := int(event.a)
			var bar: float = maxf(1.0, pool.max_hp[target])
			_give(slot, float(weights.get("healing_per_health_bar", 0.6)) * float(event.value) / bar, "healing")
		Events.Kind.DAMAGE_TAKEN:
			var bar: float = maxf(1.0, pool.max_hp[slot])
			_give(slot, -float(weights.get("own_hp_lost_per_health_bar", 0.3)) * float(event.value) / bar, "hp_lost")
		Events.Kind.DEATH:
			_give(slot, float(weights.get("own_death_per_mob_value", -0.15)) * _value(slot), "deaths")
			if sim.species.support[pool.species[slot]] != 0:
				var loss := -float(weights.get("support_lost", 1.0)) * _value(slot)
				for other in _allies(slot):
					_give(other, loss, "support_lost")
		Events.Kind.INTENT:
			_give(slot, float(weights.get("intent_change", -0.002)), "intent")
		Events.Kind.RELEASE:
			_released[slot] = int(event.a)
		Events.Kind.HIT:
			var target := int(event.a)
			var dodging: bool = target >= 0 and target < players and \
				int(event.tick) < sim.party.timers[target * Party.TIMER_COUNT + Party.Clocks.DODGE_UNTIL]
			if _released[slot] >= 1 and not dodging:
				_give(slot, float(weights.get("ability_landed", 0.0)), "landed")
		Events.Kind.EVADED:
			_give(slot, float(weights.get("made_player_dodge", 0.0)), "evaded")
		Events.Kind.DODGED:
			_give(slot, float(weights.get("dodged_attack", 0.0)), "dodged")


## Downs and wipes, from the party's alive flags.
func _party(now: int) -> void:
	var party = sim.party
	var players: int = sim.contract.players
	var anyone_left := false
	var anyone_was := false
	for player in players:
		var alive: bool = party.present[player] != 0 and party.alive[player] != 0
		anyone_left = anyone_left or alive
		anyone_was = anyone_was or _was_alive[player] != 0
		if _was_alive[player] != 0 and not alive and party.present[player] != 0:
			var finisher := -1
			var latest := -1000000
			for slot in sim.pool.active:
				var hit := _last_hit[slot * players + player]
				if now - hit <= _assist_ticks:
					_give(slot, float(weights.get("player_downed", 3.0)), "downs")
					if hit > latest:
						latest = hit
						finisher = slot
			if finisher >= 0:
				_keep(finisher, float(weights.get("player_killing_blow", 0.0)), "killing_blows")
		_was_alive[player] = int(alive)
	if anyone_was and not anyone_left:
		for slot in sim.pool.active:
			var helped := false
			for player in players:
				helped = helped or now - _last_hit[slot * players + player] <= _wipe_assist_ticks
			if helped:
				_give(slot, float(weights.get("party_wipe", 5.0)), "wipes")


func _trickles() -> void:
	var pool = sim.pool
	var now: int = sim.clock.tick
	var seconds := float(TRICKLE_TICKS) / Clock.TICKS_PER_SECOND
	var sight := float(weights.get("line_of_sight_per_second", 0.01)) * seconds
	var support := float(weights.get("support_alive_casting_per_second", 0.02)) * seconds
	var found := float(weights.get("first_sight", 0.0))
	var players: int = sim.contract.players
	for slot in pool.active:
		if found > 0.0 and _found[slot] == 0:
			for player in players:
				if sim.party.present[player] != 0 and sim.party.alive[player] != 0 and sim.perception.sees(slot, player):
					_found[slot] = 1
					_give(slot, found, "found")
					break
		var target: int = pool.enemy_target[slot] - 1
		if sight > 0.0 and target >= 0 and _sight_left[slot] > 0.0 and sim.perception.sees(slot, target):
			var earned := minf(sight, _sight_left[slot])
			_sight_left[slot] -= earned
			_give(slot, earned, "sight")
		if support > 0.0 and sim.species.support[pool.species[slot]] != 0 and \
				(pool.windup_until[slot] > 0 or now < pool.channel_until[slot]):
			for other in _allies(slot):
				_give(other, support, "support")


## Adds a reward the mob keeps whole, with no squad share.
func _keep(slot: int, value: float, kind: String) -> void:
	if value == 0.0 or slot < 0 or slot >= pending.size():
		return
	totals[kind] = totals.get(kind, 0) + 1
	pending[slot] += value


## Adds a reward, keeping (1 - squad_mix) for the mob and sharing the rest among its allies.
func _give(slot: int, value: float, kind: String) -> void:
	if value == 0.0 or slot < 0 or slot >= pending.size():
		return
	totals[kind] = totals.get(kind, 0) + (1 if kind in ["downs", "wipes", "deaths", "found", "evaded", "dodged", "landed"] else value)
	var allies := _allies(slot) if squad_mix > 0.0 else PackedInt32Array()
	if allies.is_empty():
		pending[slot] += value
		return
	pending[slot] += value * (1.0 - squad_mix)
	var share := value * squad_mix / allies.size()
	for other in allies:
		pending[other] += share


func _allies(slot: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var perception = sim.perception
	for index in sim.contract.allies:
		var other: int = perception.ally(slot, index)
		if other >= 0 and sim.pool.alive[other] != 0:
			result.append(other)
	return result


func _value(slot: int) -> float:
	var elite: bool = sim.pool.flags[slot] & (Pool.FLAG_ELITE | Pool.FLAG_LEADER) != 0
	return float(weights.get("mob_value_elite" if elite else "mob_value_basic", 1.0))


func _sight_cap() -> float:
	return float(weights.get("line_of_sight_cap_per_decision", 0.005))
