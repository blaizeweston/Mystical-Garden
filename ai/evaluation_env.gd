extends "res://ai/training_env.gd"
## Training episodes for comparing brains (ai/evaluate_policies.gd): the same episode setup as training, from
## the same seed, so every brain meets the same floors, parties and mob groups in the same order. It also
## measures what training's reports leave out:
## - rewards as values, by kind (damage, hp_lost, deaths, ...), not counts;
## - which behaviours mobs choose, awake and before they have sensed anyone;
## - how mobs spend their time: aware of the party or not, and how far from the nearest player;
## - with snapshot on, the state of a fight that reached its time limit (at_limit; see _limit_snapshot).
##
## The brain is the training brain (temperature 1, as in training) or, with use_scripted, the game's scripted
## brain. The episode setup consumes the seeded generator identically either way. Nothing here writes to a
## run folder; recorded rows are kept only when keep_rows is set, for the critic diagnosis.

const ScriptedBrain = preload("res://mob_sim/mob_scripted_brain.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")

## Distance bands (metres to the nearest standing player) for the time mobs spend: up to each limit.
const BANDS := [3.0, 8.0, 16.0]
const BAND_NAMES := ["within_3m", "3_to_8m", "8_to_16m", "beyond_16m"]
## Positions are sampled this often (ticks).
const SAMPLE_TICKS := 6
## A time-limit snapshot shares out the mobs' behaviours over this last stretch of the fight.
const LIMIT_WINDOW_S := 30.0


## Rewards with a running total of the reward given by kind, as values.
class TallyRewards extends "res://ai/mob_rewards.gd":
	var values := {}

	func _give(slot: int, value: float, kind: String) -> void:
		if value != 0.0 and slot >= 0 and slot < pending.size():
			values[kind] = float(values.get(kind, 0.0)) + value
		super(slot, value, kind)

	func _keep(slot: int, value: float, kind: String) -> void:
		if value != 0.0 and slot >= 0 and slot < pending.size():
			values[kind] = float(values.get(kind, 0.0)) + value
		super(slot, value, kind)


## Passes decisions to another brain and counts the behaviours it chose.
class CountingBrain extends "res://mob_sim/mob_brain.gd":
	var inner: RefCounted
	var counts := PackedInt32Array()

	func _init(wrapped: RefCounted, behaviours: int) -> void:
		inner = wrapped
		counts.resize(behaviours)
		counts.fill(0)

	func reset_slot(slot: int) -> void:
		inner.reset_slot(slot)

	func decide(batch: Batch) -> void:
		inner.decide(batch)
		for index in batch.slots.size():
			var behaviour := batch.intents[index * Contract.HEAD_COUNT + Contract.Head.BEHAVIOUR]
			if behaviour < counts.size():
				counts[behaviour] += 1

	func take() -> PackedInt32Array:
		var result := counts.duplicate()
		counts.fill(0)
		return result


var use_scripted := false
var keep_rows := false
## Adds at_limit to the report of a fight that times out. Off, reports are unchanged.
var snapshot := false
var awake_counter: CountingBrain
var idle_counter: CountingBrain


func _new_map() -> bool:
	if not super():
		return false
	var behaviours: int = sim.contract.behaviour_count
	var awake: RefCounted = ScriptedBrain.new() if use_scripted else brain
	var idle: RefCounted = ScriptedBrain.new() if use_scripted else brain
	awake_counter = CountingBrain.new(awake, behaviours)
	idle_counter = CountingBrain.new(idle, behaviours)
	sim.brain = awake_counter
	sim.idle_brain = idle_counter
	return true


## Plays one episode as ai/training_env.gd does and returns its report with the extra measurements.
func run_episode() -> Dictionary:
	if sim == null or episodes_on_map >= int(settings.map_episodes):
		if not _new_map():
			return {}
	else:
		_clear()
	if not keep_rows:
		recorder.clear()
	episodes_on_map += 1
	episodes += 1
	var explore := rng.randf() < float(settings.explore_share)
	var night := rng.randf() < float(settings.night_share)
	var light := _uniform("night_light") if night else 1.0
	var difficulty := _uniform("difficulty")
	var start: Vector2 = open[rng.randi() % open.size()]
	var classes: Array[String] = []
	var size := _fight_size()
	for index in size.x:
		classes.append(settings.classes[rng.randi() % settings.classes.size()])
	party.reset(classes, _near(start, classes.size(), 2.5), difficulty, light)
	if explore or rng.randf() < float(settings.engaged_patrol_share):
		party.plan_patrol(open, int(settings.patrol_legs))
	var tally := TallyRewards.new(sim)
	tally.squad_mix = squad_mix
	rewards = tally
	recorder.rewards = rewards
	brain.episode_start = sim.clock.tick
	awake_counter.take()
	idle_counter.take()
	var spawned := _spawn_mobs(start, explore, size.y)
	var report := {"episode": episodes, "mode": "explore" if explore else "engaged", "floor": floor_number, "night": night,
		"party": classes.size(), "difficulty": snappedf(difficulty, 0.01), "light": snappedf(light, 0.01), "mobs": spawned.count,
		"elite": spawned.elite}
	var limit := Clock.from_ms(float(settings.explore_seconds if explore else settings.engaged_seconds) * 1000.0)
	var cursor := sim.events.head
	var began := sim.clock.tick
	var first_found := -1
	var end := Recorder.End.TERMINAL if bool(settings.get("time_limit_terminal", true)) else Recorder.End.TRUNCATED
	var outcome := "timeout"
	var time := {"mob_seconds": 0.0, "aware": 0.0, "sees": 0.0}
	for name in BAND_NAMES:
		time[name] = 0.0
	var first_contact := -1
	# Snapshot tracking: behaviour counts per sample over the last window, and the last tick each side lost health.
	var recent: Array[PackedInt32Array] = []
	var window := ceili(LIMIT_WINDOW_S * Clock.TICKS_PER_SECOND / SAMPLE_TICKS)
	var taken: float = party.damage_taken
	var dealt: float = party.damage_dealt
	var party_hurt_at := -1
	var mobs_hurt_at := -1
	for step in limit:
		party.before_tick()
		sim.tick()
		party.after_tick()
		rewards.tick()
		for event in sim.events.read_since(cursor):
			if int(event.kind) == Events.Kind.DEATH:
				recorder.close(int(event.slot), Recorder.End.TERMINAL)
		cursor = sim.events.head
		if snapshot:
			if party.damage_taken > taken:
				taken = party.damage_taken
				party_hurt_at = sim.clock.tick
			if party.damage_dealt > dealt:
				dealt = party.damage_dealt
				mobs_hurt_at = sim.clock.tick
			if step % SAMPLE_TICKS == 0:
				recent.append(_behaviour_sample())
				if recent.size() > window:
					recent.pop_front()
		if first_found < 0 and int(rewards.totals.found) > 0:
			first_found = sim.clock.tick - began
		if step % SAMPLE_TICKS == 0:
			if _sample_time(time) and first_contact < 0:
				first_contact = sim.clock.tick - began
		if party.wiped():
			end = Recorder.End.TERMINAL
			outcome = "wipe"
			break
		if sim.pool.active.is_empty():
			end = Recorder.End.TERMINAL
			outcome = "cleared"
			break
	party.before_tick()
	rewards.tick()
	recorder.close_all(end)
	var played := sim.clock.tick - began
	ticks += played
	var values := {}
	for kind: String in tally.values:
		values[kind] = snappedf(float(tally.values[kind]), 0.0001)
	report.merge({"outcome": outcome, "seconds": snappedf(Clock.to_seconds(played), 0.01),
		"first_sight": snappedf(Clock.to_seconds(first_found), 0.01) if first_found >= 0 else -1.0,
		"first_within_3m": snappedf(Clock.to_seconds(first_contact), 0.01) if first_contact >= 0 else -1.0,
		"mobs_killed": spawned.count - sim.pool.active.size(), "downs": classes.size() - party.alive_count(),
		"damage_to_party": snappedf(party.damage_taken, 0.1), "damage_to_mobs": snappedf(party.damage_dealt, 0.1),
		"party_hp": snappedf(_party_hp(), 0.1), "dodged": party.hits_dodged, "reward_counts": rewards.totals.duplicate(),
		"reward_values": values, "awake_behaviours": Array(awake_counter.take()), "idle_behaviours": Array(idle_counter.take())})
	for name: String in time:
		time[name] = snappedf(float(time[name]), 0.01)
	report["time"] = time
	if snapshot and outcome == "timeout":
		report["at_limit"] = _limit_snapshot(recent, party_hurt_at, mobs_hurt_at)
	if keep_rows:
		recorder.episodes.append(report)
	return report


## Adds one sample's mob-seconds to time. Returns true when some mob is within 3 m of a standing player.
func _sample_time(time: Dictionary) -> bool:
	var seconds := float(SAMPLE_TICKS) / Clock.TICKS_PER_SECOND
	var pool = sim.pool
	var players: int = sim.contract.players
	var close := false
	for slot in pool.active:
		var at := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
		var nearest := INF
		var aware := false
		var sees := false
		for player in players:
			if sim.party.present[player] == 0 or sim.party.alive[player] == 0:
				continue
			nearest = minf(nearest, at.distance_to(Vector2(sim.party.x[player], sim.party.z[player])))
			aware = aware or sim.perception.knows(slot, player)
			sees = sees or sim.perception.sees(slot, player)
		time.mob_seconds += seconds
		time.aware += seconds if aware else 0.0
		time.sees += seconds if sees else 0.0
		var band := BANDS.size()
		for index in BANDS.size():
			if nearest <= BANDS[index]:
				band = index
				break
		time[BAND_NAMES[band]] += seconds
		close = close or band == 0
	return close


## How many living mobs are in each behaviour right now.
func _behaviour_sample() -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(sim.contract.behaviour_count)
	counts.fill(0)
	for slot in sim.pool.active:
		var behaviour: int = sim.pool.behaviour[slot]
		if behaviour < counts.size():
			counts[behaviour] += 1
	return counts


## The state of a fight at its time limit:
## - mobs: alive, aware of a standing player, seeing one; the nearest mob-to-player distance (-1 with none);
## - players: standing, each one's health fraction and party mode (StandIns.MODE_NAMES);
## - seconds since the party, and since any mob, last lost health (-1: never this fight);
## - final_behaviours: each behaviour's share of living mob-time over the last LIMIT_WINDOW_S.
func _limit_snapshot(recent: Array[PackedInt32Array], party_hurt_at: int, mobs_hurt_at: int) -> Dictionary:
	var pool = sim.pool
	var now: int = sim.clock.tick
	var aware := 0
	var seeing := 0
	var nearest := INF
	for slot in pool.active:
		var at := Vector2(pool.xz[slot * 2], pool.xz[slot * 2 + 1])
		var knows := false
		var sees := false
		for player in party.count:
			if party.down[player] != 0:
				continue
			nearest = minf(nearest, at.distance_to(party.position[player]))
			knows = knows or sim.perception.knows(slot, player)
			sees = sees or sim.perception.sees(slot, player)
		aware += int(knows)
		seeing += int(sees)
	var health := []
	var modes := []
	for player in party.count:
		health.append(0.0 if party.down[player] != 0 else snappedf(party.hp[player] / maxf(1.0, party.max_hp[player]), 0.01))
		modes.append("down" if party.down[player] != 0 else StandIns.MODE_NAMES[party.mode[player]])
	var totals := PackedInt32Array()
	totals.resize(sim.contract.behaviour_count)
	totals.fill(0)
	var samples := 0
	for counts in recent:
		for behaviour in counts.size():
			totals[behaviour] += counts[behaviour]
			samples += counts[behaviour]
	var shares := {}
	for behaviour in totals.size():
		if totals[behaviour] > 0:
			shares[sim.contract.names[behaviour]] = snappedf(float(totals[behaviour]) / samples, 0.001)
	var since := func(tick: int) -> float: return snappedf(Clock.to_seconds(now - tick), 0.01) if tick >= 0 else -1.0
	return {"mobs_alive": pool.active.size(), "mobs_aware": aware, "mobs_seeing": seeing,
		"nearest": snappedf(nearest, 0.01) if nearest < INF else -1.0, "players_standing": party.alive_count(),
		"player_health": health, "player_modes": modes, "party_hurt_seconds_ago": since.call(party_hurt_at),
		"mobs_hurt_seconds_ago": since.call(mobs_hurt_at), "final_behaviours": shares}


func _party_hp() -> float:
	var total := 0.0
	for player in party.count:
		total += party.max_hp[player]
	return total
