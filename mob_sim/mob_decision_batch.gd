extends RefCounted
## One decision call: the mobs due this tick, their action masks and the intents a brain returns.
## A brain reads simulation values through this view and never receives the game.

const Clock = preload("res://mob_sim/mob_clock.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Perception = preload("res://mob_sim/mob_perception.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")

var contract: Contract
var clock: Clock
var pool: Pool
var party: Party
var species: Species
var perception: Perception

var slots := PackedInt32Array()
## slots.size() * contract.mask_size bytes, in head order. Nonzero means the option is legal.
var masks := PackedByteArray()
## slots.size() * Contract.HEAD_COUNT bytes, in head order.
var intents := PackedByteArray()


func _init(rules_contract: Contract, sim_clock: Clock, mob_pool: Pool, mob_party: Party, table: Species, senses: Perception) -> void:
	contract = rules_contract
	clock = sim_clock
	pool = mob_pool
	party = mob_party
	species = table
	perception = senses


func prepare(due: PackedInt32Array) -> void:
	slots = due
	masks.resize(due.size() * contract.mask_size)
	masks.fill(0)
	intents.resize(due.size() * Contract.HEAD_COUNT)
	intents.fill(0)


func allowed(index: int, head: int, option: int) -> bool:
	return masks[index * contract.mask_size + contract.head_offsets[head] + option] != 0


func write_intent(index: int, behaviour: int, enemy_target: int, ally_target: int, manoeuvre: int, message_a: int = 0, message_b: int = 0) -> void:
	var at := index * Contract.HEAD_COUNT
	intents[at + Contract.Head.BEHAVIOUR] = behaviour
	intents[at + Contract.Head.ENEMY_TARGET] = enemy_target
	intents[at + Contract.Head.ALLY_TARGET] = ally_target
	intents[at + Contract.Head.MANOEUVRE] = manoeuvre
	intents[at + Contract.Head.MESSAGE_A] = message_a
	intents[at + Contract.Head.MESSAGE_B] = message_b
