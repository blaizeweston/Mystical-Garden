extends RefCounted
## Game rules that no brain can learn around: legal actions, hold times, cooldowns and attacker caps.

const Batch = preload("res://mob_sim/mob_decision_batch.gd")
const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Events = preload("res://mob_sim/mob_events.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Perception = preload("res://mob_sim/mob_perception.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")
const Actions = preload("res://mob_sim/mob_actions.gd")
const Command = preload("res://mob_sim/mob_command.gd")

var contract: Contract
var pool: Pool
var party: Party
var species: Species
var perception: Perception
var events: Events
## Mana, channeling and dodging. MobSim sets it; without it mobs never dodge or channel and casts are free.
var actions: Actions
## The fight's commander (MobSim sets it). Its messages hold for commander_message_ticks once they change.
var command: Command
var commander_message_ticks := 0
var hold_ticks := PackedInt32Array()
## The commit head's lengths in ticks; option 0 means the behaviour's own hold.
var commit_ticks := PackedInt32Array()
var max_attackers := 0
var messages_enabled := false
var rejected := 0
## The contract's availability, with hide switched on while darkness is on.
var available := PackedByteArray()
var _hide := -1
var _dodge := -1
var _channel := -1


func _init(rules_contract: Contract, mob_pool: Pool, mob_party: Party, table: Species, senses: Perception, event_log: Events) -> void:
	contract = rules_contract
	pool = mob_pool
	party = mob_party
	species = table
	perception = senses
	events = event_log
	max_attackers = int(contract.rules.max_attackers_per_player)
	messages_enabled = bool(contract.rules.messages_enabled)
	commander_message_ticks = Clock.from_ms(float(contract.rules.get("commander_message_ms", 0)))
	for milliseconds in contract.hold_ms:
		hold_ticks.append(Clock.from_ms(milliseconds))
	for milliseconds in contract.commitments_ms:
		commit_ticks.append(Clock.from_ms(milliseconds))
	_dodge = contract.id("dodge")
	_channel = contract.id("channel")
	_hide = contract.id("hide")
	available = contract.available.duplicate()


## Hiding needs darkness to hide in. Reconfigure the native rules afterwards.
func set_darkness(enabled: bool) -> void:
	if _hide >= 0:
		available[_hide] = int(enabled)


func attack_ready(slot: int, attack: int, tick: int) -> bool:
	var kind := pool.species[slot]
	if not species.has_attack(kind, attack, pool.mutations[slot]):
		return false
	if actions != null and not actions.can_afford(slot, attack):
		return false
	if tick < pool.ready_at[slot] or tick < pool.cooldown_until[slot * pool.attacks + attack] or pool.windup_until[slot] > 0:
		return false
	match species.attack_escort[kind * Species.ATTACKS + attack]:
		Species.Escort.ALONE:
			return not _has_fighter_ally(slot)
		Species.Escort.ESCORTED:
			return _has_fighter_ally(slot)
	return true


func can_claim_attacker(player: int) -> bool:
	return party.attackers[player] < max_attackers


## Support casters only use their desperate swing once no fighter is left to protect them.
func _has_fighter_ally(slot: int) -> bool:
	var leader := pool.leader_of(slot)
	if leader >= 0 and species.support[pool.species[leader]] == 0:
		return true
	for index in contract.allies:
		var other := perception.ally(slot, index)
		if other >= 0 and pool.alive[other] != 0 and species.support[pool.species[other]] == 0:
			return true
	return false


## Configures native/mob_decide.c, which builds masks and runs the scripted brain. Returns an error code.
func configure_native(world: RefCounted) -> int:
	var dims := PackedInt32Array([pool.capacity, contract.players, contract.allies, Species.ATTACKS, species.count, contract.behaviour_count,
		contract.manoeuvre_count, contract.message_symbols, int(messages_enabled), contract.mask_size, Pool.FLAG_LEADER | Pool.FLAG_ELITE,
		contract.id("idle_wander"), contract.id("search"), contract.id("approach"), contract.id("melee_attack"), contract.id("ranged_attack"),
		contract.id("ability_1"), contract.id("ability_2"), contract.id("ability_3"), contract.id("defend_ally"),
		contract.manoeuvres.find("circle_left"), contract.manoeuvres.find("circle_right"), contract.manoeuvres.find("keep_max_range"),
		_dodge if actions != null else -1, _channel if actions != null else -1, contract.id("flee")])
	return world.decide_configure([dims, contract.head_offsets, available, contract.leader_only, contract.target_kind,
		contract.attack_slot, contract.delivery, species.support, species.skirmisher, species.max_range, species.attack_exists,
		species.attack_mutation, species.attack_escort, species.attack_delivery, species.attack_range, species.attack_min_range,
		species.mana_pool, species.mana_low, species.can_dodge, species.attack_mana_cost if actions != null else _free_casts()])


func _free_casts() -> PackedFloat32Array:
	var free := PackedFloat32Array()
	free.resize(species.attack_mana_cost.size())
	free.fill(0.0)
	return free


## Fills batch.masks natively. build_masks_reference holds the same rules in GDScript.
func build_masks(batch: Batch, _tick: int) -> void:
	var built: PackedByteArray = batch.world.decide_masks(batch.native_inputs())
	if built.size() != batch.slots.size() * contract.mask_size:
		push_error("The native mask builder refused this decision's input.")
		return
	batch.masks = built
	hold_orders(batch, _tick)


func build_masks_reference(batch: Batch, tick: int) -> void:
	for index in batch.slots.size():
		_mask_slot(batch, index * contract.mask_size, batch.slots[index], tick)
	hold_orders(batch, tick)


## While a commander's messages hold, its only legal messages are the ones it is sending, so it cannot change
## its orders faster than commander_message_ticks and training does not learn from choices that do nothing.
## Applied after either mask builder.
func hold_orders(batch: Batch, tick: int) -> void:
	if command == null or commander_message_ticks <= 0:
		return
	for index in batch.slots.size():
		var slot := batch.slots[index]
		if not command.commands(slot) or tick >= pool.message_until[slot]:
			continue
		var base := index * contract.mask_size
		for entry: Array in [[Contract.Head.MESSAGE_A, pool.message_a[slot]], [Contract.Head.MESSAGE_B, pool.message_b[slot]]]:
			var offset: int = base + contract.head_offsets[entry[0]]
			for symbol in contract.head_sizes[entry[0]]:
				batch.masks[offset + symbol] = int(symbol == int(entry[1]))


func _mask_slot(batch: Batch, base: int, slot: int, tick: int) -> void:
	var enemy_base := base + contract.head_offsets[Contract.Head.ENEMY_TARGET]
	var ally_base := base + contract.head_offsets[Contract.Head.ALLY_TARGET]
	batch.masks[enemy_base] = 1
	batch.masks[ally_base] = 1
	var has_enemy := false
	# A shepherd's order limits the target to the commanded player while it lasts and that player is known.
	var commanded := -1
	if tick < pool.command_until[slot] and pool.command_player[slot] < contract.players and perception.knows(slot, pool.command_player[slot]):
		commanded = pool.command_player[slot]
	for player in contract.players:
		if perception.knows(slot, player) and (commanded < 0 or player == commanded):
			batch.masks[enemy_base + 1 + player] = 1
			has_enemy = true
	var has_ally := false
	for index in contract.allies:
		if perception.ally(slot, index) >= 0:
			batch.masks[ally_base + 1 + index] = 1
			has_ally = true
	if pool.leader_of(slot) >= 0:
		batch.masks[ally_base + 1 + contract.allies] = 1
		has_ally = true
	for option in contract.manoeuvre_count:
		batch.masks[base + contract.head_offsets[Contract.Head.MANOEUVRE] + option] = 1
	for head: int in [Contract.Head.MESSAGE_A, Contract.Head.MESSAGE_B]:
		batch.masks[base + contract.head_offsets[head]] = 1
		if messages_enabled:
			for symbol in range(1, contract.message_symbols):
				batch.masks[base + contract.head_offsets[head] + symbol] = 1
	# Every commitment length is legal; the brain keeps option 0 for behaviours without commit.
	for option in contract.head_sizes[Contract.Head.COMMIT]:
		batch.masks[base + contract.head_offsets[Contract.Head.COMMIT] + option] = 1
	for behaviour in contract.behaviour_count:
		batch.masks[base + behaviour] = int(_behaviour_legal(slot, behaviour, has_enemy, has_ally, tick))
	_lock_slot(batch, base, slot, tick)


## While an attack winds up or a behaviour holds, the mob is committed: _commit_slot keeps its behaviour, targets
## and manoeuvre, and nothing cuts through, not even a dodge. Those are the only legal options, so a committed
## decision has one choice and training never learns from it. Messages are always free. As mob_decide.c lock_slot.
func _lock_slot(batch: Batch, base: int, slot: int, tick: int) -> void:
	if pool.windup_until[slot] <= 0 and tick >= pool.hold_until[slot]:
		return
	for behaviour in contract.behaviour_count:
		batch.masks[base + behaviour] = 0
	if pool.behaviour[slot] < contract.behaviour_count:
		batch.masks[base + pool.behaviour[slot]] = 1
	var heads := [[Contract.Head.ENEMY_TARGET, pool.enemy_target[slot]], [Contract.Head.ALLY_TARGET, pool.ally_target[slot]],
		[Contract.Head.MANOEUVRE, pool.manoeuvre[slot]]]
	for entry: Array in heads:
		var offset: int = base + contract.head_offsets[entry[0]]
		var size: int = contract.head_sizes[entry[0]]
		for option in size:
			batch.masks[offset + option] = 0
		batch.masks[offset + (int(entry[1]) if int(entry[1]) < size else 0)] = 1
	var commit_offset: int = base + contract.head_offsets[Contract.Head.COMMIT]
	for option in contract.head_sizes[Contract.Head.COMMIT]:
		batch.masks[commit_offset + option] = int(option == 0)


func _behaviour_legal(slot: int, behaviour: int, has_enemy: bool, has_ally: bool, tick: int) -> bool:
	if available[behaviour] == 0:
		return false
	if contract.leader_only[behaviour] != 0 and not pool.is_leader(slot):
		return false
	var kind := contract.target_kind[behaviour]
	if (kind == Contract.TargetKind.ENEMY or kind == Contract.TargetKind.ABILITY) and not has_enemy:
		return false
	if kind == Contract.TargetKind.ALLY and not has_ally:
		return false
	if behaviour == _dodge:
		return actions != null and actions.can_dodge(slot, tick)
	if behaviour == _channel:
		return actions != null and species.mana_pool[pool.species[slot]] > 0.0 and actions.can_channel(slot)
	var attack := contract.attack_slot[behaviour]
	if attack < 0:
		return true
	var wanted := contract.delivery[behaviour]
	if wanted != Contract.Delivery.ANY and species.attack_delivery[pool.species[slot] * Species.ATTACKS + attack] != wanted:
		return false
	return attack_ready(slot, attack, tick)


## Applies a brain's choices. An illegal choice falls back to the current intent or to idle.
func commit(batch: Batch, tick: int) -> void:
	for index in batch.slots.size():
		_commit_slot(batch, index, batch.slots[index], tick)


func _commit_slot(batch: Batch, index: int, slot: int, tick: int) -> void:
	var at := index * Contract.HEAD_COUNT
	var behaviour := batch.intents[at + Contract.Head.BEHAVIOUR]
	var enemy := batch.intents[at + Contract.Head.ENEMY_TARGET]
	var ally := batch.intents[at + Contract.Head.ALLY_TARGET]
	var manoeuvre := batch.intents[at + Contract.Head.MANOEUVRE]
	if not _intent_legal(batch, index, behaviour, enemy, ally, manoeuvre):
		rejected += 1
		behaviour = pool.behaviour[slot]
		enemy = pool.enemy_target[slot]
		ally = pool.ally_target[slot]
		manoeuvre = pool.manoeuvre[slot]
		if not _intent_legal(batch, index, behaviour, enemy, ally, manoeuvre):
			behaviour = contract.id("idle_wander")
			enemy = 0
			ally = 0
			manoeuvre = 0
	var message_a := _message(batch, index, Contract.Head.MESSAGE_A, batch.intents[at + Contract.Head.MESSAGE_A])
	var message_b := _message(batch, index, Contract.Head.MESSAGE_B, batch.intents[at + Contract.Head.MESSAGE_B])
	var reordered := message_a != pool.message_a[slot] or message_b != pool.message_b[slot]
	if reordered and command != null and command.commands(slot) and commander_message_ticks > 0:
		if tick < pool.message_until[slot]:
			message_a = pool.message_a[slot]
			message_b = pool.message_b[slot]
		else:
			pool.message_until[slot] = tick + commander_message_ticks
	pool.message_a[slot] = message_a
	pool.message_b[slot] = message_b
	# A committed mob (winding up, or inside its behaviour's hold) keeps its intent; nothing cuts through.
	if pool.windup_until[slot] > 0 or tick < pool.hold_until[slot]:
		return
	var previous := pool.behaviour[slot]
	var option := batch.intents[at + Contract.Head.COMMIT]
	# Only a target the behaviour uses makes a new intent; the others are fixed and never restart a hold.
	var new_enemy := contract.uses_head(behaviour, Contract.Head.ENEMY_TARGET) and enemy != pool.enemy_target[slot]
	var new_ally := contract.uses_head(behaviour, Contract.Head.ALLY_TARGET) and ally != pool.ally_target[slot]
	var retargeted := new_enemy or new_ally
	if behaviour != previous or retargeted:
		_start_hold(slot, tick, _hold(batch, index, behaviour, option))
		pool.behaviour_since[slot] = tick
		events.push(Events.Kind.INTENT, tick, slot, pool.generation[slot], behaviour, enemy)
	elif _chosen_length(batch, index, behaviour, option):
		# Carrying on with a set commitment holds again for that length; the usual hold (option 0) keeps the
		# old rule, where only a change of intent holds.
		_start_hold(slot, tick, commit_ticks[option])
	pool.behaviour[slot] = behaviour
	pool.enemy_target[slot] = enemy
	pool.ally_target[slot] = ally
	pool.manoeuvre[slot] = manoeuvre
	if behaviour != previous and actions != null:
		actions.on_change(slot, previous, behaviour, tick)


## The hold a behaviour change starts: the chosen commitment for a behaviour with commit, else its own hold.
func _hold(batch: Batch, index: int, behaviour: int, option: int) -> int:
	return commit_ticks[option] if _chosen_length(batch, index, behaviour, option) else hold_ticks[behaviour]


## Whether the commit choice is a legal set length for a behaviour with commit (not the usual hold).
func _chosen_length(batch: Batch, index: int, behaviour: int, option: int) -> bool:
	return contract.commit[behaviour] != 0 and option > 0 and option < commit_ticks.size() and batch.allowed(index, Contract.Head.COMMIT, option)


func _start_hold(slot: int, tick: int, ticks: int) -> void:
	pool.hold_start[slot] = tick
	pool.hold_until[slot] = tick + ticks


func _message(batch: Batch, index: int, head: int, symbol: int) -> int:
	return symbol if symbol < contract.message_symbols and batch.allowed(index, head, symbol) else 0


func _intent_legal(batch: Batch, index: int, behaviour: int, enemy: int, ally: int, manoeuvre: int) -> bool:
	if behaviour >= contract.behaviour_count or enemy >= contract.head_sizes[Contract.Head.ENEMY_TARGET] \
			or ally >= contract.head_sizes[Contract.Head.ALLY_TARGET] or manoeuvre >= contract.manoeuvre_count:
		return false
	if not batch.allowed(index, Contract.Head.BEHAVIOUR, behaviour) or not batch.allowed(index, Contract.Head.ENEMY_TARGET, enemy) \
			or not batch.allowed(index, Contract.Head.ALLY_TARGET, ally):
		return false
	var kind := contract.target_kind[behaviour]
	if (kind == Contract.TargetKind.ENEMY or kind == Contract.TargetKind.ABILITY) and enemy == 0:
		return false
	return kind != Contract.TargetKind.ALLY or ally != 0
