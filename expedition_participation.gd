extends RefCounted
## Host owner of expedition membership, floor identity and travel consent.
## Player records hold only a readonly link. Received guest and frozen
## settlement records retain the existing detached wild projection.

const Campaign = preload("res://campaign.gd")
const STATE := "expedition_participation"

class Member extends RefCounted:
	var binding: int
	var active := false
	var waiting := false
	var run_id := 0

	func _init(binding_id: int) -> void:
		binding = binding_id

class Link extends RefCounted:
	var _owner
	var _peer: int
	var _binding: int

	func _init(owner: RefCounted, peer: int, binding: int) -> void:
		_owner = owner
		_peer = peer
		_binding = binding

	func active() -> bool:
		return bool(_owner._binding_active(_peer, _binding))

	func waiting() -> bool:
		return bool(_owner._binding_waiting(_peer, _binding))

	func peer_id() -> int:
		return _peer if _owner._binding_matches(_peer, _binding) else 0

var _members: Dictionary[int, Member] = {}
var _destination := 0
var _depth := 1
var _floor := 1
var _cycle := 0
var _seed := 0
var _epoch := 0
var _run_id := 0
var _advanced_epoch := -1

var _travel_kind := ""
var _travel_members: Array[int] = []
var _travel_votes: Dictionary[int, String] = {}
var _travel_epoch := 0

# High-water marks never roll back, so an aborted admission or transition
# cannot make its reserved identity available to an unrelated future action.
var _last_epoch := 0
var _last_binding := 0
var _last_run_id := 0
var _last_travel_epoch := 0

static func is_wild(record: Dictionary) -> bool:
	var link: Link = record.get(STATE)
	return link.active() if link != null else bool(record.get("wild", false))

static func is_waiting(record: Dictionary) -> bool:
	var link: Link = record.get(STATE)
	return link.waiting() if link != null else false

static func peer_for(record: Dictionary) -> int:
	var link: Link = record.get(STATE)
	return link.peer_id() if link != null else 0

func attach(peer: int) -> Link:
	_last_binding += 1
	_members[peer] = Member.new(_last_binding)
	return Link.new(self, peer, _last_binding)

func attached(peer: int) -> bool:
	return _members.has(peer)

func detach(peer: int) -> void:
	_members.erase(peer)

func detach_all() -> void:
	_members.clear()

func _binding_matches(peer: int, binding: int) -> bool:
	return _members.has(peer) and _members[peer].binding == binding

func _binding_active(peer: int, binding: int) -> bool:
	return _binding_matches(peer, binding) and _members[peer].active

func _binding_waiting(peer: int, binding: int) -> bool:
	return _binding_matches(peer, binding) and _members[peer].waiting

func active() -> bool:
	for member in _members.values():
		if member.active:
			return true
	return false

func contains(peer: int) -> bool:
	return _members.has(peer) and _members[peer].active

func participants() -> Array[int]:
	var result: Array[int] = []
	for peer in _members:
		if _members[peer].active:
			result.append(peer)
	result.sort()
	result.make_read_only()
	return result

func enter(peer: int) -> bool:
	if not _members.has(peer):
		return false
	var member := _members[peer]
	if member.active or member.waiting:
		return false
	if _run_id == 0:
		_last_run_id += 1
		_run_id = _last_run_id
	member.active = true
	member.run_id = _run_id
	return true

func leave(peer: int) -> bool:
	if not contains(peer):
		return false
	var member := _members[peer]
	member.active = false
	member.waiting = active()
	return true

func route() -> int:
	return _destination

func depth() -> int:
	return _depth

func floor() -> int:
	return _floor

func cycle() -> int:
	return _cycle

func seed() -> int:
	return _seed

func epoch() -> int:
	return _epoch

func run_id() -> int:
	return _run_id

func select_route(destination: int) -> bool:
	if destination < 0 or destination >= Campaign.BIOME_COUNT: return false
	_destination = destination
	return true

func reset_run() -> bool:
	if active():
		return false
	_last_run_id += 1
	_run_id = _last_run_id
	_depth = 1
	_floor = 1
	_cycle = 0
	_seed = 0
	_advanced_epoch = -1
	for member in _members.values():
		member.waiting = false
		member.run_id = 0
	return true

func advance(expected_epoch: int, biome_length: int) -> bool:
	if expected_epoch != _epoch or _advanced_epoch == expected_epoch or not active() \
			or biome_length <= 0:
		return false
	_advanced_epoch = expected_epoch
	_floor += 1
	if _depth == biome_length:
		_depth = 1
		if _destination == Campaign.HOLLOW:
			_cycle += 1
		_destination = (_destination + 1) % Campaign.BIOME_COUNT
	else:
		_depth += 1
	return true

func begin_floor(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_seed = seed_value
	_last_epoch += 1
	_epoch = _last_epoch
	_advanced_epoch = -1

## Rebuild the receiving guest's participation projection from an accepted
## protocol-41 snapshot. Facts contain peer -> active only, never actor records.
## The returned links are detached query capabilities, not mutable members.
func project_participants(facts: Dictionary) -> Dictionary:
	for peer in _members.keys():
		if not facts.has(peer): detach(peer)
	var links := {}
	for peer in facts:
		if not _members.has(peer): attach(int(peer))
		var member := _members[int(peer)]
		member.active = bool(facts[peer])
		member.waiting = false # The packet's fallen projection retains that UI flag.
		links[int(peer)] = Link.new(self,int(peer),member.binding)
	links.make_read_only()
	return links

## Only the receiving world invokes this for protocol-41 guest projections.
func project_world(value: Dictionary) -> void:
	if not select_route(int(value.get("destination", _destination))): return
	_depth = int(value.get("depth", _depth))
	_floor = int(value.get("encounter_number", _floor))
	_cycle = int(value.get("difficulty_cycle", _cycle))
	_seed = int(value.get("map_seed", _seed))
	_epoch = int(value.get("combat_epoch", _epoch))
	_last_epoch = maxi(_last_epoch, _epoch)

func world() -> Dictionary:
	var result := {
		"destination": _destination, "depth": _depth, "encounter_number": _floor,
		"difficulty_cycle": _cycle, "map_seed": _seed, "combat_epoch": _epoch,
		"run_id": _run_id,
	}
	result.make_read_only()
	return result

func travel_kind() -> String:
	return _travel_kind

func travel_epoch() -> int:
	return _travel_epoch

func travel_members() -> Array[int]:
	var result := _travel_members.duplicate()
	result.make_read_only()
	return result

func vote_count() -> int:
	return _travel_votes.size()

func has_vote(peer: int) -> bool:
	return _travel_votes.has(peer)

func vote_signature(peer: int) -> String:
	return _travel_votes.get(peer, "")

func clear_travel() -> void:
	_travel_kind = ""
	_travel_members.clear()
	_travel_votes.clear()
	_last_travel_epoch += 1
	_travel_epoch = _last_travel_epoch

func begin_travel(kind: String, members: Array) -> void:
	if _travel_kind == kind and _travel_members == members:
		return
	clear_travel()
	_travel_kind = kind
	_travel_members.assign(members)

func set_vote(peer: int, signature: String) -> bool:
	if _travel_kind.is_empty() or peer not in _travel_members:
		return false
	_travel_votes[peer] = signature
	return true

func retract_vote(peer: int) -> bool:
	return _travel_votes.erase(peer)

func withdraw(peer: int, expected_travel_epoch: int) -> bool:
	if expected_travel_epoch != _travel_epoch:
		return false
	return retract_vote(peer)

func savepoint() -> Dictionary:
	var members := {}
	for peer in _members:
		var member := _members[peer]
		members[peer] = {
			"binding": member.binding, "active": member.active,
			"waiting": member.waiting, "run_id": member.run_id,
		}
	return {
		"world": world().duplicate(), "members": members,
		"advanced_epoch": _advanced_epoch, "travel_kind": _travel_kind,
		"travel_epoch": _travel_epoch, "travel_members": _travel_members.duplicate(),
		"travel_votes": _travel_votes.duplicate(),
	}

func restore_savepoint(state: Dictionary) -> void:
	project_world(state.world)
	_run_id = int(state.world.run_id)
	_last_run_id = maxi(_last_run_id, _run_id)
	_advanced_epoch = int(state.advanced_epoch)
	_members.clear()
	for peer in state.members:
		var item: Dictionary = state.members[peer]
		var member := Member.new(int(item.binding))
		member.active = bool(item.active)
		member.waiting = bool(item.waiting)
		member.run_id = int(item.run_id)
		_members[int(peer)] = member
		_last_binding = maxi(_last_binding, member.binding)
	_travel_kind = str(state.travel_kind)
	_travel_epoch = int(state.travel_epoch)
	_last_travel_epoch = maxi(_last_travel_epoch, _travel_epoch)
	_travel_members.assign(state.travel_members)
	_travel_votes.clear()
	for peer in state.travel_votes:
		_travel_votes[int(peer)] = str(state.travel_votes[peer])
