extends "res://mob_sim/mob_brain.gd"
## Scripted baseline in GDScript. The simulation runs the same logic natively through mob_scripted_brain.gd;
## tests/mob_native_parity.gd requires both to choose identical intents. Change this file and native/mob_decide.c together.

const Contract = preload("res://mob_sim/mob_contract.gd")
const Species = preload("res://mob_sim/mob_species.gd")

const ASSIGNED_WEIGHT := 1.4
const ASSIGNED_LIMIT := 3.0
const UNSEEN_PENALTY := 3.0
const KEEP_TARGET_BONUS := 1.1
const LONG_RANGE := 3.0

var _bound := false
var _idle := 0
var _search := 0
var _approach := 0
var _melee := 0
var _ranged := 0
var _ability_1 := 0
var _ability_2 := 0
var _ability_3 := 0
var _defend := 0
var _circle_left := 0
var _circle_right := 0
var _keep_range := 0
var _assigned := PackedInt32Array()


func decide(batch: Batch) -> void:
	_bind(batch.contract)
	_count_assignments(batch)
	for index in batch.slots.size():
		_decide_slot(batch, index, batch.slots[index])


func _bind(contract: Contract) -> void:
	if _bound:
		return
	_bound = true
	_idle = contract.id("idle_wander")
	_search = contract.id("search")
	_approach = contract.id("approach")
	_melee = contract.id("melee_attack")
	_ranged = contract.id("ranged_attack")
	_ability_1 = contract.id("ability_1")
	_ability_2 = contract.id("ability_2")
	_ability_3 = contract.id("ability_3")
	_defend = contract.id("defend_ally")
	_circle_left = contract.manoeuvres.find("circle_left")
	_circle_right = contract.manoeuvres.find("circle_right")
	_keep_range = contract.manoeuvres.find("keep_max_range")


func _count_assignments(batch: Batch) -> void:
	_assigned.resize(batch.contract.players + 1)
	_assigned.fill(0)
	for slot in batch.pool.active:
		_assigned[batch.pool.enemy_target[slot]] += 1


func _decide_slot(batch: Batch, index: int, slot: int) -> void:
	var player := _pick_target(batch, slot)
	if player < 0:
		batch.write_intent(index, _idle, 0, 0, 0)
		return
	var head := player + 1
	if not batch.perception.sees(slot, player):
		batch.write_intent(index, _search, head, 0, 0)
		return
	var kind := batch.pool.species[slot]
	var manoeuvre := _manoeuvre(batch, slot, kind)
	var distance := batch.pool.distance_to(slot, batch.party.x[player], batch.party.z[player])
	var vault_at := kind * Species.ATTACKS + 2
	if batch.allowed(index, 0, _ability_2) and distance >= batch.species.attack_min_range[vault_at] and distance <= batch.species.attack_range[vault_at]:
		batch.write_intent(index, _ability_2, head, 0, manoeuvre)
		return
	for behaviour in [_ability_1, _melee, _ranged, _ability_3]:
		if batch.allowed(index, 0, behaviour):
			batch.write_intent(index, behaviour, head, 0, manoeuvre)
			return
	var ally := _first_ally(batch, slot)
	if batch.species.support[kind] != 0 and ally > 0 and batch.allowed(index, 0, _defend):
		batch.write_intent(index, _defend, head, ally, 0)
		return
	batch.write_intent(index, _approach, head, 0, manoeuvre)


func _pick_target(batch: Batch, slot: int) -> int:
	var best := INF
	var chosen := -1
	var current := batch.pool.enemy_target[slot] - 1
	for player in batch.contract.players:
		if not batch.perception.knows(slot, player):
			continue
		var at := slot * batch.contract.players + player
		var assigned := _assigned[player + 1] - int(player == current)
		var score := batch.pool.distance_to(slot, batch.perception.seen_x[at], batch.perception.seen_z[at]) \
			+ minf(ASSIGNED_LIMIT, assigned * ASSIGNED_WEIGHT)
		if not batch.perception.sees(slot, player):
			score += UNSEEN_PENALTY
		if player == current:
			score -= KEEP_TARGET_BONUS
		if score < best:
			best = score
			chosen = player
	return chosen


func _manoeuvre(batch: Batch, slot: int, kind: int) -> int:
	if batch.species.skirmisher[kind] != 0:
		return _circle_left if slot % 2 == 0 else _circle_right
	if batch.species.max_range[kind] > LONG_RANGE:
		return _keep_range
	return [0, _circle_left, _circle_right][slot % 3]


func _first_ally(batch: Batch, slot: int) -> int:
	for index in batch.contract.allies:
		if batch.perception.ally(slot, index) >= 0:
			return index + 1
	return 0
