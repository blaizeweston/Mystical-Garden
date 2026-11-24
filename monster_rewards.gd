extends RefCounted
## Owns one receipt per enemy death. Finished receipts keep only a duplicate
## guard until encounter retirement. Frozen awards never borrow actor state.

const Director = preload("res://combat_director.gd")
const Enemies = preload("res://enemy_catalog.gd")

enum Phase { ABSENT, EXCLUDED, PENDING, STAGED, COMMITTED, CLEANUP_PENDING, UNCERTAIN }
enum Result { COMMITTED, CLEANUP_PENDING, UNCERTAIN }

var _receipts: Dictionary = {}
var _legacy_notices: Array[Dictionary] = []
# Immutable entry-time counters, not a second current-XP balance. They survive
# floor receipt retirement and revival, and share this owner's savepoint.
var _expeditions: Dictionary = {}

func begin_expedition(identity: String, run_id: int, class_xp: Array, familiarity: Array) -> bool:
	if identity.is_empty() or run_id <= 0 or class_xp.is_empty() or familiarity.is_empty(): return false
	var previous: Dictionary = _expeditions.get(identity, {})
	if not previous.is_empty() and (not previous.closed or int(previous.run_id) == run_id): return false
	if pending_profile_ids().has(identity): return false
	_expeditions[identity] = {"run_id":run_id,"xp":class_xp.duplicate(true),"monsters":familiarity.duplicate(true),"closed":false}
	return true

## Claims one voluntary forfeiture. Remove only this character's unbanked
## awards; other party members retain their frozen awards and progression.
func forfeit_expedition(identity: String, run_id: int) -> Dictionary:
	var entry: Dictionary = _expeditions.get(identity, {})
	if entry.is_empty() or entry.closed or int(entry.run_id) != run_id: return {}
	entry.closed = true
	for receipt: Dictionary in _receipts.values():
		if receipt.phase == Phase.PENDING:
			receipt.rewards = receipt.rewards.filter(func(reward): return reward.identity != identity)
	_legacy_notices = _legacy_notices.filter(func(notice): return notice.get("identity", "") != identity)
	return {"xp":entry.xp.duplicate(true),"monsters":entry.monsters.duplicate(true)}

func finish_expedition(identity: String, run_id: int) -> void:
	var entry: Dictionary = _expeditions.get(identity, {})
	if not entry.is_empty() and int(entry.run_id) == run_id: entry.closed = true

## Returns the accepted receipt key, or an empty string for a duplicate death.
## Summons need a key for death-event deduplication but generate no awards.
func admit_kill(epoch: int, spawn_token: String, death: Dictionary, candidates: Array[Dictionary], roll_trophy: Callable, roll_seed: Callable) -> String:
	var key := "%d:%s" % [epoch, spawn_token]
	if _receipts.has(key):
		return ""
	if death.summoned:
		_receipts[key] = {"phase": Phase.EXCLUDED}
		return key

	var config := Director.config()
	var definition := Enemies.get_kind(death.kind)
	var boss := bool(definition.get("boss", false))
	var sparks := int(config.leader_essence_sparks if death.leader else config.kill_essence_sparks) * (6 if boss else 1)
	var xp := int(config.leader_class_xp if death.leader else config.kill_class_xp) * (8 if boss else 1)
	var rewards: Array[Dictionary] = []
	for candidate in candidates:
		if not candidate.profile_ready or not candidate.wild or candidate.fallen:
			continue
		var item := str(roll_trophy.call())
		var boss_seed := boss and float(roll_seed.call()) < float(definition.get("seed_drop_chance", 1.0))
		rewards.append({
			"id": candidate.id, "class": candidate["class"], "identity": candidate.identity,
			"item": item, "essence": sparks, "boss_seed": boss_seed, "xp": xp,
		})
	_receipts[key] = {
		"key": key, "kind": death.kind, "position": death.position, "epoch": epoch,
		"rewards": rewards, "run_rewards_granted": false, "phase": Phase.PENDING,
	}
	return key

## Gross Class XP earned, before any later forfeiture. Called once, only for a
## newly admitted death. Excluded summons have no awards.
func experience_awards(key: String) -> Array:
	return _receipts.get(key,{}).get("rewards",[]).map(func(row): return {"identity":row.identity,"xp":row.xp})

## Claims expedition-only awards before a permanent checkpoint settlement.
func take_run_awards(key: String) -> Dictionary:
	var receipt: Dictionary = _receipts.get(key, {})
	if receipt.get("phase") != Phase.PENDING or receipt.run_rewards_granted:
		return {}
	receipt.run_rewards_granted = true
	return receipt.duplicate(true)

## Stages permanent awards plus any remaining run awards. The detached rows
## say whether their run awards were already applied before this settlement.
func stage_pending() -> Array[Dictionary]:
	var work: Array[Dictionary] = []
	for key in _receipts:
		var receipt: Dictionary = _receipts[key]
		if receipt.phase != Phase.PENDING:
			continue
		work.append(receipt.duplicate(true))
		receipt.phase = Phase.STAGED
		receipt.run_rewards_granted = true
	return work

func finish_settlement(result: Result) -> void:
	for key in _receipts:
		var receipt: Dictionary = _receipts[key]
		if receipt.phase != Phase.STAGED:
			continue
		match result:
			Result.COMMITTED:
				_receipts[key] = {"phase": Phase.COMMITTED}
			Result.CLEANUP_PENDING:
				_receipts[key] = {"phase": Phase.CLEANUP_PENDING}
			Result.UNCERTAIN:
				receipt.phase = Phase.UNCERTAIN

func status(key: String) -> Phase:
	var receipt: Dictionary = _receipts.get(key, {})
	return receipt.get("phase", Phase.ABSENT)

func has_pending() -> bool:
	for key in _receipts:
		if _receipts[key].phase == Phase.PENDING:
			return true
	return false

func pending_count() -> int:
	var count := 0
	for key in _receipts:
		if _receipts[key].phase == Phase.PENDING:
			count += 1
	return count

func pending_receipts() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for key in _receipts:
		if _receipts[key].phase == Phase.PENDING:
			pending.append(_receipts[key].duplicate(true))
	return pending

func pending_profile_ids() -> Array[String]:
	var identities: Array[String] = []
	for key in _receipts:
		var receipt: Dictionary = _receipts[key]
		if receipt.phase != Phase.PENDING:
			continue
		for reward: Dictionary in receipt.rewards:
			var identity: String = reward.identity
			if not identity.is_empty() and not identities.has(identity):
				identities.append(identity)
	return identities

func release_committed_cleanup() -> void:
	for key in _receipts:
		if _receipts[key].phase == Phase.CLEANUP_PENDING:
			_receipts[key].phase = Phase.COMMITTED

func retire_completed() -> void:
	if has_pending():
		return
	for key in _receipts.keys():
		if _receipts[key].phase in [Phase.EXCLUDED, Phase.COMMITTED]:
			_receipts.erase(key)

## Rollback follows the actual outer save boundary, including nested legacy
## settlement. The temporary savepoint is detached and never serialized.
func savepoint() -> Dictionary:
	return {"receipts": _receipts.duplicate(true), "notices": _legacy_notices.duplicate(true), "expeditions": _expeditions.duplicate(true)}

func restore_savepoint(checkpoint: Dictionary) -> void:
	_receipts = checkpoint.receipts.duplicate(true)
	_legacy_notices.assign(checkpoint.notices.duplicate(true))
	_expeditions = checkpoint.get("expeditions", {}).duplicate(true)

func defer_legacy_notices(notices: Array[Dictionary]) -> void:
	_legacy_notices.append_array(notices.duplicate(true))

func take_legacy_notices() -> Array[Dictionary]:
	var notices := _legacy_notices
	_legacy_notices = []
	return notices
