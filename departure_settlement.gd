extends RefCounted
## Owns the profile and protected cargo of disconnected players until the
## host's settlement has a verified outcome.

enum Phase { ABSENT, WAITING, SETTLING, RETRYABLE, CLEANUP_PENDING, UNCERTAIN }
enum Result { COMMITTED, RESTORED, CLEANUP_PENDING, UNCERTAIN }

class Departure:
	var peer_id: int
	var identity: String
	var phase := Phase.WAITING
	var payload: Dictionary

	func _init(peer: int, profile_id: String, snapshot: Dictionary) -> void:
		peer_id = peer
		identity = profile_id
		payload = snapshot.duplicate(true)

var _records: Array[Departure] = []

func register(peer_id: int, identity: String, snapshot: Dictionary) -> void:
	for record in _records:
		if record.peer_id == peer_id and record.identity == identity:
			return
	_records.append(Departure.new(peer_id, identity, snapshot))

func status(identity: String) -> Phase:
	for record in _records:
		if record.identity == identity:
			return record.phase
	return Phase.ABSENT

func blocks_admission(identity: String) -> bool:
	return status(identity) != Phase.ABSENT

func contains_peer(peer_id: int) -> bool:
	return _records.any(func(record: Departure): return record.peer_id == peer_id)

func count() -> int:
	return _records.size()

func is_empty() -> bool:
	return _records.is_empty()

func has_wild_departure() -> bool:
	return _records.any(func(record: Departure): return _can_stage(record) and record.payload.get("wild", false))

func is_settling() -> bool:
	return _records.any(func(record: Departure): return record.phase == Phase.SETTLING)

## Settlement works on detached copies. A verified rollback can retry
## from the originals even when profile and cargo were already applied.
func stage(identities_waiting_on_rewards: Array[String]) -> Array[Dictionary]:
	var work: Array[Dictionary] = []
	for record in _records:
		if not _can_stage(record) or identities_waiting_on_rewards.has(record.identity):
			continue
		record.phase = Phase.SETTLING
		var actor := record.payload.duplicate(true)
		actor.seed_owner = record.identity
		work.append({"peer_id": record.peer_id, "identity": record.identity, "actor": actor})
	return work

func finish(result: Result) -> void:
	for index in range(_records.size() - 1, -1, -1):
		var record := _records[index]
		if record.phase != Phase.SETTLING:
			continue
		match result:
			Result.COMMITTED:
				_records.remove_at(index)
			Result.RESTORED:
				record.phase = Phase.RETRYABLE
			Result.CLEANUP_PENDING:
				record.phase = Phase.CLEANUP_PENDING
				record.payload.clear()
			Result.UNCERTAIN:
				record.phase = Phase.UNCERTAIN

func release_committed_cleanup() -> void:
	for index in range(_records.size() - 1, -1, -1):
		if _records[index].phase == Phase.CLEANUP_PENDING:
			_records.remove_at(index)

func _can_stage(record: Departure) -> bool:
	return record.phase in [Phase.WAITING, Phase.RETRYABLE]
