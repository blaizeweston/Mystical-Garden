extends RefCounted
## Runs one mob encounter in a fixed order. The host supplies the map, the party and incoming damage.

const Abilities = preload("res://mob_sim/mob_abilities.gd")
const Batch = preload("res://mob_sim/mob_decision_batch.gd")
const Brain = preload("res://mob_sim/mob_brain.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Executors = preload("res://mob_sim/mob_executors.gd")
const ReferenceExecutors = preload("res://mob_sim/mob_executors_reference.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Perception = preload("res://mob_sim/mob_perception.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Rules = preload("res://mob_sim/mob_rules.gd")
const ScriptedBrain = preload("res://mob_sim/mob_scripted_brain.gd")
const ReferenceScriptedBrain = preload("res://mob_sim/mob_scripted_brain_reference.gd")
const Species = preload("res://mob_sim/mob_species.gd")
const SystemTimers = preload("res://mob_sim/perf/system_timers.gd")
const StatusSystem = preload("res://mob_sim/mob_status.gd")
const SimHandlerPort = preload("res://mob_sim/abilities/sim_handler_port.gd")
const Actions = preload("res://mob_sim/mob_actions.gd")

enum Status { STUN, ROOT, SLOW, HASTE }

var contract: Contract
var clock: Clock
var species: Species
var party: Party
var pool: Pool
var events: Events
var locomotion: Locomotion
var perception: Perception
var rules: Rules
var abilities: Abilities
## Native executors, or the GDScript reference after use_reference_executors().
var executors: RefCounted
## Damage over time, dodge windows, channeling and armour.
var status: StatusSystem
## Mana, channeling and dodging.
var actions: Actions
## Per-system timing. Set timers.enabled to measure; results never depend on it.
var timers := SystemTimers.new()
## Decides for mobs that are awake.
var brain: Brain
## Decides for mobs that have sensed nobody for a while, so they skip the costlier brain.
var idle_brain: Brain
var sleep_ticks := 0
var _awake_batch: Batch
var _asleep_batch: Batch


func _init(slots: int, awake_brain: Brain = null) -> void:
	contract = Contract.new()
	clock = Clock.new()
	species = Species.new()
	party = Party.new(contract.players)
	pool = Pool.new(slots, contract.attacks)
	pool.prompt_gap = int(contract.rules.decision_ticks_smart)
	events = Events.new()
	locomotion = Locomotion.new(pool, party, contract)
	locomotion.species_layer = species.layer
	perception = Perception.new(pool, party, species, contract, locomotion.world)
	rules = Rules.new(contract, pool, party, species, perception, events)
	actions = Actions.new(contract, pool, party, species, perception, locomotion)
	rules.actions = actions
	status = StatusSystem.new(pool, species.count)
	abilities = Abilities.new(pool, party, species, rules, events, locomotion)
	abilities.port = SimHandlerPort.new(self)
	executors = Executors.new(contract, pool, party, species, perception, abilities, locomotion)
	brain = awake_brain if awake_brain != null else ScriptedBrain.new()
	idle_brain = ScriptedBrain.new()
	sleep_ticks = Clock.from_ms(float(contract.rules.sleep_after_ms))
	_awake_batch = Batch.new(contract, clock, pool, party, species, perception)
	_asleep_batch = Batch.new(contract, clock, pool, party, species, perception)
	_awake_batch.world = locomotion.world
	_asleep_batch.world = locomotion.world
	if locomotion.world == null or rules.configure_native(locomotion.world) != OK:
		push_error("The native decision helpers could not be configured.")


## Swaps in the GDScript executors. Only the parity test uses this.
func use_reference_executors() -> void:
	var replacement := ReferenceExecutors.new(contract, pool, party, species, perception, abilities, locomotion)
	replacement.abilities = executors.abilities
	executors = replacement


func configure(field: RefCounted) -> int:
	return locomotion.bake(field)


func spawn(request: Pool.Spawn) -> int:
	return spawn_at(pool.first_free(), request)


## Adds a mob to one chosen slot. Returns -1 if the slot is taken or the request is refused.
func spawn_at(chosen: int, request: Pool.Spawn) -> int:
	var smart := int(contract.rules.decision_ticks_smart)
	var dim := int(contract.rules.decision_ticks_dim)
	var interval := roundi(lerpf(dim, smart, clampf(request.intelligence, 0.0, 1.0)))
	request.mutations |= species.unlock_bits(request.species, request.floor_number, request.evidence) if request.species >= 0 and request.species < species.count else 0
	var slot := pool.spawn_at(chosen, request, species, clock.tick, interval)
	if slot < 0:
		return -1
	perception.reset_slot(slot)
	locomotion.place(slot)
	brain.reset_slot(slot)
	idle_brain.reset_slot(slot)
	events.push(Events.Kind.SPAWN, clock.tick, slot, pool.generation[slot], request.species, 0, request.at.x, request.at.y)
	return slot


## Applies damage. Returns the health actually removed. Dodges, armour and channeling scale it unless
## scaled is false, which a host uses when its own combat rules already resolved the amount.
func damage_mob(slot: int, amount: float, source_player: int = -1, scaled: bool = true) -> float:
	if slot < 0 or slot >= pool.capacity or pool.alive[slot] == 0 or amount <= 0.0:
		return 0.0
	pool.prompt_decision(slot, clock.tick)
	pool.hurt_at[slot] = clock.tick
	if scaled:
		amount = status.scale_damage(slot, amount, clock.tick)
	if amount <= 0.0:
		events.push(Events.Kind.DODGED, clock.tick, slot, pool.generation[slot], source_player, 0, pool.xz[slot * 2], pool.xz[slot * 2 + 1])
		return 0.0
	var removed := minf(amount, pool.hp[slot])
	pool.hp[slot] -= removed
	pool.engaged[slot] = 1
	pool.last_sensed[slot] = clock.tick
	if source_player >= 0 and source_player < contract.players and party.present[source_player] != 0:
		var at := slot * contract.players + source_player
		perception.seen_x[at] = party.x[source_player]
		perception.seen_z[at] = party.z[source_player]
		perception.seen_tick[at] = clock.tick
	events.push(Events.Kind.DAMAGE_TAKEN, clock.tick, slot, pool.generation[slot], source_player, 0,
		pool.xz[slot * 2], pool.xz[slot * 2 + 1], removed)
	if pool.hp[slot] <= 0.0:
		_kill(slot, source_player)
	return removed


## Records damage the host resolved against a player, credited to the mob that released the attack.
func record_hit(slot: int, generation: int, player: int, amount: float) -> void:
	events.push(Events.Kind.DAMAGE_DEALT, clock.tick, slot, generation, player, 0, party.x[player], party.z[player], amount)


## Adds damage over time. Stacks add their damage per second; the longest duration wins.
func apply_dot(slot: int, per_second: float, ticks: int, source_player: int = -1) -> void:
	status.apply_dot(slot, per_second, ticks, source_player, clock.tick)


## Makes a mob ignore hits for a few ticks.
func start_dodge(slot: int, ticks: int) -> void:
	if slot >= 0 and slot < pool.capacity and pool.alive[slot] != 0:
		pool.dodge_until[slot] = clock.tick + ticks


## Marks a mob as channeling, so it takes its species' channel damage multiplier until the channel ends.
func start_channel(slot: int, ticks: int) -> void:
	if slot >= 0 and slot < pool.capacity and pool.alive[slot] != 0:
		pool.channel_until[slot] = clock.tick + ticks


func stop_channel(slot: int) -> void:
	if slot >= 0 and slot < pool.capacity:
		pool.channel_until[slot] = 0


func apply_status(slot: int, kind: Status, ticks: int, scale: float = 1.0) -> void:
	if slot < 0 or slot >= pool.capacity or pool.alive[slot] == 0:
		return
	var until := clock.tick + ticks
	match kind:
		Status.STUN:
			pool.stun_until[slot] = maxi(pool.stun_until[slot], until)
		Status.ROOT:
			# Flyers cannot be rooted.
			if species.layer[pool.species[slot]] == 0:
				pool.root_until[slot] = maxi(pool.root_until[slot], until)
		Status.SLOW:
			pool.slow_until[slot] = maxi(pool.slow_until[slot], until)
			pool.slow_scale[slot] = clampf(scale, 0.0, 1.0)
		Status.HASTE:
			pool.haste_until[slot] = maxi(pool.haste_until[slot], until)


## Advances the encounter by one fixed step.
func tick() -> void:
	clock.advance()
	var now := clock.tick
	if timers.enabled:
		_timed_tick(now)
		return
	perception.update(now)
	_decide(now)
	executors.run(now)
	abilities.tick_windups(now)
	tick_status(now)
	locomotion.step(now)


## Applies the damage over time due this tick through damage_mob, so armour, dodges and deaths apply.
func tick_status(now: int) -> void:
	if status.burning.is_empty():
		return
	for entry in status.due(now):
		damage_mob(int(entry[0]), float(entry[1]), int(entry[2]) if int(entry[2]) != Pool.NO_PLAYER else -1)


## The same steps as tick(), charged to each system. Kept separate so untimed ticks pay nothing.
func _timed_tick(now: int) -> void:
	timers.begin_tick()
	perception.update(now)
	timers.lap(SystemTimers.System.PERCEPTION)
	_decide(now)
	timers.lap(SystemTimers.System.DECISION)
	executors.run(now)
	timers.lap(SystemTimers.System.EXECUTORS)
	abilities.tick_windups(now)
	timers.lap(SystemTimers.System.ABILITIES)
	tick_status(now)
	timers.lap(SystemTimers.System.STATUS)
	locomotion.step(now)
	timers.lap(SystemTimers.System.MOVEMENT)
	timers.end_tick()


func state_hash() -> int:
	return hash([clock.tick, pool.state_hash()])


func _kill(slot: int, source_player: int) -> void:
	abilities.cancel(slot)
	status.clear_slot(slot)
	events.push(Events.Kind.DEATH, clock.tick, slot, pool.generation[slot], source_player, 0, pool.xz[slot * 2], pool.xz[slot * 2 + 1])
	locomotion.remove(slot)
	pool.despawn(slot)


func _decide(now: int) -> void:
	var awake := PackedInt32Array()
	var asleep := PackedInt32Array()
	for slot in pool.active:
		if now < pool.next_decision[slot]:
			continue
		pool.mark_decided(slot, now)
		actions.settle(slot, now)
		if now - pool.last_sensed[slot] >= sleep_ticks:
			asleep.append(slot)
		else:
			awake.append(slot)
	perception.refresh_allies(awake, now)
	_run_brain(_awake_batch, awake, brain, now)
	_run_brain(_asleep_batch, asleep, idle_brain, now)


func _run_brain(batch: Batch, due: PackedInt32Array, chosen: Brain, now: int) -> void:
	if due.is_empty():
		return
	batch.prepare(due)
	rules.build_masks(batch, now)
	chosen.decide(batch)
	rules.commit(batch, now)
