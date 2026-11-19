extends RefCounted
## Sole host owner of publication cadence, sequence and recovery-frame cache.
## Receives a focused port, never Game, mutable actors, or an ENet peer.
const Source = preload("res://world_replication_source.gd")
const Codec = preload("res://world_snapshot.gd")
const Clock = preload("res://combat_clock.gd")
const Identity = preload("res://network_action_identity.gd")
const FAST_INTERVAL_SECONDS := 0.05
const DETAILS_INTERVAL_SECONDS := 0.25
const RECOVERY_THROTTLE := ENetPacketPeer.PACKET_THROTTLE_SCALE / 2.0
var _next_fast := 0.0
var _next_details := 0.0
var _sequence := 0
var _latest := PackedByteArray()
var _latest_key := ""
var _publishing := false
var _session_revision := 0
# Last accepted publication facts only; PlayerVitals still owns actual HP.
class HealthRevision:
	var signature: String
	var revision: int
	func _init(value: String, number: int) -> void:
		signature = value
		revision = number
var _health: Dictionary[int, HealthRevision] = {}
var _observing_health := false

func sequence() -> int:
	return _sequence

func clear_session() -> void:
	_session_revision += 1
	_sequence = 0
	_latest.clear()
	_latest_key = ""
	_health.clear()
	# Preserve the existing send phase across host/join teardown. A new world
	# starts with zero clocks; clearing a floor does not restart the sequence.

func publish(source: Source, delta: float, force: bool = false) -> void:
	if _publishing: return
	_publishing = true
	var revision := _session_revision
	observe_health(source)
	var peers := source.peers()
	if peers.is_empty() or revision!=_session_revision:
		_publishing = false
		return
	_next_fast -= delta
	_next_details -= delta
	var witness := source.observer()
	var key := source.state_key()
	if force or _next_fast <= 0.0:
		_next_fast = maxf(0,_next_fast+FAST_INTERVAL_SECONDS)
		_publish_fast(source,peers,key,witness)
	if revision==_session_revision and (force or _next_details <= 0.0):
		_next_details = maxf(0,_next_details+DETAILS_INTERVAL_SECONDS)
		_publish_details(source,peers,key,witness)
	_publishing = false

## Revision belongs to publication, never the mutable actor or savepoint.
func health_revision(peer: int) -> int:
	return _health[peer].revision if _health.has(peer) else 0

## Observe even without connected guests, preserving the existing change rule.
## Returned source facts are detached; this operation cannot change player HP.
func observe_health(source: Source) -> void:
	if _observing_health: return
	_observing_health = true
	var session_revision := _session_revision
	var changes := {}
	var states := source.health_states()
	for peer: int in states:
		var state: Dictionary = states[peer]
		var signature := str([state.hp,state.max_hp,state.wild,state.fallen,state.lost_health,state.damage_seq])
		if _health.has(peer) and _health[peer].signature==signature: continue
		var revision := health_revision(peer)+1
		_health[peer] = HealthRevision.new(signature,revision)
		changes[peer] = {"revision":revision,"hp":state.hp,"max_hp":state.max_hp,
			"fallen":state.fallen,"lost_health":state.lost_health,"damage_seq":state.damage_seq,"damage_amount":state.damage_amount}
	if not changes.is_empty():
		for peer in source.peers():
			if session_revision!=_session_revision: break
			source.send_vitals(peer,changes.duplicate(true))
	_observing_health = false

func _publish_fast(source: Source, peers: PackedInt32Array, key: String, witness: Callable) -> void:
	var revision := _session_revision
	var began := Time.get_ticks_usec() if witness.is_valid() else 0
	var state := source.world_state(Clock.now())
	var shared := Codec.encode(_sequence+1,state.people,state.campaign,state.scouts,
		state.enemy,state.hp,state.maximum,state.drop,state.depth,state.flags)
	if shared.is_empty() or shared.size()>Codec.PAYLOAD_BUDGET:
		source.refuse_frame()
		return
	_sequence += 1
	_latest = shared
	_latest_key = key
	for peer in peers:
		if revision!=_session_revision: return
		var recipient := source.recipient(peer)
		if recipient.is_empty(): continue
		var frame := Codec.for_viewer(shared,recipient.carried,recipient.dropped,recipient.pouch)
		var before := source.transport_stats(peer) if began>0 else {}
		var packed_at := Time.get_ticks_usec() if not before.is_empty() else 0
		var error := source.send_fast(peer,frame)
		if not before.is_empty():
			var enqueued_at := Time.get_ticks_usec()
			var after := source.transport_stats(peer)
			witness.call({"phase":"send","peer":peer,"sequence":_sequence,"at":packed_at,
				"bytes":frame.size(),"marker":int(state.drop.x),"scout_count":state.scouts.size()/float(Codec.Encounter.PACK_STRIDE),
				"encode_us":packed_at-began,"enqueue_us":enqueued_at-packed_at,"error":error,
				"throttle":before.throttle,"counter_before":before.counter,"counter_after":after.get("counter",-1)})

func _publish_details(source: Source, peers: PackedInt32Array, key: String, witness: Callable) -> void:
	var revision := _session_revision
	var garden_bytes := var_to_bytes(source.garden()).compress(FileAccess.COMPRESSION_DEFLATE)
	var roster := source.roster()
	var diagnostic := source.diagnostics()
	var common := source.common_details()
	for peer in peers:
		if revision!=_session_revision: return
		var recipient := source.recipient(peer)
		if recipient.is_empty(): continue
		var details := source.owner_details(peer,common)
		var binding := source.owner_binding(peer)
		details[Identity.BINDING_KEY] = binding.connection
		details[Identity.KEY] = binding.action_identity
		details.snapshot_roster = roster
		details.diagnostic_host = diagnostic.host
		details.diagnostic_world = diagnostic.world
		var transport := source.transport_stats(peer)
		var repairing: bool = not _latest.is_empty() and _latest_key==key \
			and not transport.is_empty() and int(transport.throttle)<=RECOVERY_THROTTLE
		if repairing:
			details.snapshot_recovery = Codec.for_viewer(_latest,recipient.carried,recipient.dropped,recipient.pouch)
		var payload := var_to_bytes(details).compress(FileAccess.COMPRESSION_DEFLATE)
		var result := source.send_details(peer,payload,garden_bytes,source.inventory(peer),key)
		if repairing and witness.is_valid():
			witness.call({"phase":"repair_send","peer":peer,"sequence":_sequence,
				"at":Time.get_ticks_usec(),"bytes":details.snapshot_recovery.size(),"error":result})
