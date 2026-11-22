extends RefCounted
## Turns every mob's current intent into movement and attack starts, using native/mob_exec.c.
## The native pass writes each mob's movement command and proposes attacks that pass every rule
## depending only on simulation state. This script then calls abilities.begin for each proposal
## in mob order, because a host's abilities may add checks of their own, and applies the proposal's
## fallback movement when begin refuses. mob_executors_reference.gd holds the same logic in GDScript.

const Abilities = preload("res://mob_sim/mob_abilities.gd")
const Contract = preload("res://mob_sim/mob_contract.gd")
const Locomotion = preload("res://mob_sim/mob_locomotion.gd")
const Party = preload("res://mob_sim/mob_party.gd")
const Perception = preload("res://mob_sim/mob_perception.gd")
const Pool = preload("res://mob_sim/mob_pool.gd")
const Species = preload("res://mob_sim/mob_species.gd")

## Matches MeExecutor in native/mob_exec.h.
enum Kind { HOLD, IDLE, SEARCH, APPROACH, ATTACK, FLEE, COVER, DEFEND, BLOCK }

const BEHAVIOUR_KINDS := {
	"idle_wander": Kind.IDLE, "search": Kind.SEARCH, "approach": Kind.APPROACH,
	"melee_attack": Kind.ATTACK, "ranged_attack": Kind.ATTACK, "ability_1": Kind.ATTACK, "ability_2": Kind.ATTACK, "ability_3": Kind.ATTACK,
	"flee": Kind.FLEE, "take_cover": Kind.COVER, "hide": Kind.COVER, "defend_ally": Kind.DEFEND, "block_enemy": Kind.BLOCK, "dodge": Kind.HOLD,
}
## Floats per attack proposal: slot, attack, player, then a fallback movement row.
const PROPOSAL_STRIDE := 3 + Locomotion.STRIDE

var contract: Contract
var pool: Pool
var party: Party
var species: Species
var perception: Perception
var abilities: Abilities
var locomotion: Locomotion
var kinds := PackedByteArray()
var error := ""
var _command_size := 0
var _target_size := 0


func _init(rules_contract: Contract, mob_pool: Pool, mob_party: Party, table: Species, senses: Perception, attacks: Abilities, mover: Locomotion) -> void:
	contract = rules_contract
	pool = mob_pool
	party = mob_party
	species = table
	perception = senses
	abilities = attacks
	locomotion = mover
	_command_size = pool.capacity * Locomotion.STRIDE
	_target_size = locomotion.targets.size()
	var attack_slot := PackedInt32Array()
	for label in contract.names:
		if not BEHAVIOUR_KINDS.has(label):
			error = "Behaviour '%s' has no executor." % label
		kinds.append(BEHAVIOUR_KINDS.get(label, Kind.HOLD))
		attack_slot.append(maxi(0, contract.attack_slot[kinds.size() - 1]))
	var dims := PackedInt32Array([pool.capacity, contract.players, contract.allies, Species.ATTACKS, species.count, contract.behaviour_count,
		locomotion.goal_count, int(contract.rules.goal_refresh_ticks), contract.manoeuvres.find("circle_left"),
		contract.manoeuvres.find("circle_right"), contract.manoeuvres.find("get_behind"), contract.manoeuvres.find("keep_max_range")])
	var status: int = locomotion.world.exec_configure([dims, kinds, attack_slot, species.preferred_range, species.max_range, species.support,
		species.attack_exists, species.attack_mutation, species.attack_range, species.attack_min_range, species.attack_sight, species.attack_escort])
	if status != OK and error.is_empty():
		error = "The native executors refused their configuration (%d)." % status
	if not error.is_empty():
		push_error(error)


func has_executor(behaviour: int) -> bool:
	return error.is_empty() and behaviour >= 0 and behaviour < kinds.size() and contract.names[behaviour] in BEHAVIOUR_KINDS


func run(tick: int) -> void:
	var result: PackedFloat32Array = locomotion.world.exec_run([
		PackedInt32Array([tick, locomotion.last_step_tick()]), pool.active, pool.alive, pool.generation, pool.species, pool.mutations,
		pool.leader, pool.leader_generation, pool.xz, pool.spawn_x, pool.spawn_z, pool.reach_bonus,
		pool.behaviour, pool.behaviour_since, pool.enemy_target, pool.ally_target, pool.manoeuvre,
		pool.windup_until, pool.stun_until, pool.ready_at, pool.cooldown_until,
		perception.visible, perception.seen_x, perception.seen_z, perception.seen_tick, perception.allies,
		party.present, party.alive, party.x, party.z, party.vx, party.vz,
		locomotion.commands, locomotion.targets,
		pool.approach_until, pool.approach_x, pool.approach_z, pool.command_until, pool.command_via, pool.command_via_x, pool.command_via_z])
	if result.is_empty():
		push_error("The native executors refused this tick's input.")
		return
	locomotion.commands = result.slice(0, _command_size)
	locomotion.targets = result.slice(_command_size, _command_size + _target_size)
	var base := _command_size + _target_size
	for index in int(result[base]):
		var at := base + 1 + index * PROPOSAL_STRIDE
		var slot := int(result[at])
		if abilities.begin(slot, int(result[at + 1]), int(result[at + 2]), tick):
			continue
		for field in Locomotion.STRIDE:
			locomotion.commands[slot * Locomotion.STRIDE + field] = result[at + 3 + field]
