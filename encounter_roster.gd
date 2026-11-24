extends RefCounted
## Host authority for enemy membership, hit points and defeat on the current floor.
## Slot -1 is the floor's leader. Scout slots stay in packet order until replaced.
## AI uses the tactics record for movement and behavior, without HP or spawn identity.

const Config = preload("res://encounter_config.gd")
const Catalog = preload("res://enemy_catalog.gd")

class Member extends RefCounted:
	var token: int
	var hp: int
	var ended: bool = false
	var tactics: Dictionary

	func _init(spawn_token: int, starting_hp: int, behavior: Dictionary) -> void:
		token = spawn_token
		hp = maxi(0, starting_hp)
		tactics = behavior

var _leader: Member
var _scouts: Array[Member] = []
var _last_token := 0
var _reserved_tokens: Dictionary[int, bool] = {}

func _init(initial_leader_hp: int = 0) -> void:
	_leader = Member.new(0, initial_leader_hp, {})

func _next_token() -> int:
	_last_token += 1
	return _last_token

## Reserve the ID before authored variant selection. A plan can spend it once.
func reserve_token() -> int:
	var spawn_token := _next_token()
	_reserved_tokens[spawn_token] = true
	return spawn_token

func begin_floor(leader_hp: int) -> void:
	_reserved_tokens.clear()
	_leader = Member.new(0, leader_hp, {})
	clear_scouts()

func clear_scouts() -> void:
	_scouts.clear()

## The detached spawn plan is consumed here. Its remaining fields belong to AI.
func register_scout(authored: Dictionary, slot: int = -1) -> int:
	if slot < 0:
		slot = _scouts.size()
	if slot > _scouts.size() or slot >= Config.MAX_SCOUTS:
		return -1
	if scout_slot(authored) >= 0:
		return -1
	var member := _register(authored)
	if slot == _scouts.size():
		_scouts.append(member)
	else:
		_scouts[slot] = member
	return slot

## An elite uses scout-shaped tactics but remains the one leader in the roster.
func register_leader_tactics(authored: Dictionary) -> Dictionary:
	# Attaching the role body enriches the same living enemy; it is not a
	# despawn/spawn. Keep HP, defeat state and captured status identity intact.
	var registered := _register(authored)
	_leader.tactics = registered.tactics
	return _leader.tactics

## Live role-specific body for the gate elite, stored once with the leader member.
func leader_tactics() -> Dictionary:
	return _leader.tactics

func _register(authored: Dictionary) -> Member:
	var spawn_token := int(authored.get("spawn_token", 0))
	if not _reserved_tokens.erase(spawn_token):
		spawn_token = _next_token()
	var member := Member.new(spawn_token, int(authored.get("hp", 0)), authored)
	authored.erase("spawn_token")
	authored.erase("hp")
	return member

func scout_count() -> int:
	return _scouts.size()

func first_open_scout_slot() -> int:
	for slot in _scouts.size():
		if _scouts[slot].hp <= 0:
			return slot
	return _scouts.size()

func scout(slot: int) -> Dictionary:
	return _scouts[slot].tactics if slot >= 0 and slot < _scouts.size() else {}

func scout_slot(tactics: Dictionary) -> int:
	for slot in _scouts.size():
		if is_same(_scouts[slot].tactics, tactics):
			return slot
	return -2

## Freeze only IDs while AI runs. A newly filled slot can act on the next tick.
func scout_tokens() -> PackedInt64Array:
	var result := PackedInt64Array()
	for member in _scouts:
		result.append(member.token)
	return result

## The returned container is detached. Its tactics are still live.
func scout_tactics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member in _scouts:
		result.append(member.tactics)
	return result

func _member(slot: int) -> Member:
	if slot == -1:
		return _leader
	return _scouts[slot] if slot >= 0 and slot < _scouts.size() else null

func _member_for(tactics: Dictionary) -> Member:
	if is_same(_leader.tactics, tactics):
		return _leader
	var slot := scout_slot(tactics)
	return _scouts[slot] if slot >= 0 else null

func hp(slot: int = -1) -> int:
	var member := _member(slot)
	return member.hp if member != null else 0

func hp_for(tactics: Dictionary) -> int:
	var member := _member_for(tactics)
	return member.hp if member != null else int(tactics.get("hp", 0))

func token(slot: int) -> int:
	return _scouts[slot].token if slot >= 0 and slot < _scouts.size() else -1

## Stable text key used by one attack to claim each contacted occupant once.
func contact_key(slot: int) -> String:
	return "leader" if slot == -1 else str(token(slot))

## Both leaders and scouts have a member identity. Keep token()'s historical
## scout-only convention unchanged for its existing callers and packet logic.
func spawn_identity(slot: int) -> int:
	var member := _member(slot)
	return member.token if member != null else -1

func token_for(tactics: Dictionary) -> int:
	var member := _member_for(tactics)
	return member.token if member != null else int(tactics.get("spawn_token", 0))

func alive(slot: int, expected_token: int = -1) -> bool:
	var member := _member(slot)
	return member != null and member.hp > 0 and (expected_token < 0 or member.token == expected_token)

func position(slot: int) -> Vector3:
	return scout(slot).get("pos", Vector3.INF)

## Explicit override for spawn setup and specialized recovery.
func set_hp(slot: int, value: int) -> void:
	var member := _member(slot)
	if member != null:
		member.hp = maxi(0, value)

## Damage is already resolved by combat. Accept it only for the intended occupant.
func apply_damage(slot: int, damage: int, expected_token: int = -1) -> int:
	if damage <= 0 or not alive(slot, expected_token):
		return 0
	var member := _member(slot)
	var applied := mini(damage, member.hp)
	member.hp -= applied
	return applied

func despawn(slot: int) -> void:
	var member := _member(slot)
	if member != null:
		member.hp = 0
		member.ended = true

func death_pending(slot: int, expected_token: int = -1) -> bool:
	var member := _member(slot)
	return member != null and member.hp == 0 and not member.ended \
		and (expected_token < 0 or member.token == expected_token)

func confirm_death(slot: int) -> bool:
	if not death_pending(slot):
		return false
	_member(slot).ended = true
	return true

func living_scout_count() -> int:
	var count := 0
	for member in _scouts:
		count += int(member.hp > 0)
	return count

func cleared() -> bool:
	return _leader.hp <= 0 and living_scout_count() == 0

func scout_view(slot: int) -> Dictionary:
	var member := _member(slot) if slot >= 0 else null
	if member == null:
		return {}
	var view := member.tactics.duplicate(true)
	view["hp"] = member.hp
	view["spawn_token"] = member.token
	return view

func scout_views() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in _scouts.size():
		result.append(scout_view(slot))
	return result

## Scalar projections retain protocol 41's packet order and layout.
func scout_codes() -> PackedInt32Array:
	var result := PackedInt32Array()
	for slot in Config.MAX_SCOUTS:
		var behavior := scout(slot)
		result.append(Catalog.encode(int(behavior.get("kind", 0)), int(behavior.get("mutations", 0)), int(behavior.get("growth", 0))))
	return result

func scout_pack(now: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for member in _scouts:
		var behavior := member.tactics
		result.append_array(PackedFloat32Array([behavior.pos.x, behavior.pos.z, member.hp,
			float(behavior.windup > 0), float(int(now < int(behavior.rooted_until)) | (2 if now < int(behavior.get("haste_until", 0)) else 0)),
			float(behavior.ranged), behavior.blast.x, behavior.blast.z]))
	return result

func savepoint() -> Dictionary:
	var members: Array[Dictionary] = []
	for member in _scouts:
		members.append(_capture(member))
	return {"leader": _capture(_leader), "scouts": members}

func _capture(member: Member) -> Dictionary:
	return {"token": member.token, "hp": member.hp, "ended": member.ended, "tactics": member.tactics.duplicate(true)}

func _restore_member(state: Dictionary) -> Member:
	var member := Member.new(int(state.token), int(state.hp), state.tactics.duplicate(true))
	member.ended = bool(state.ended)
	return member

func restore_savepoint(state: Dictionary) -> void:
	# An aborted plan must never make an ID available to another spawn.
	_reserved_tokens.clear()
	_leader = _restore_member(state.leader)
	_scouts.clear()
	for member in state.scouts:
		_scouts.append(_restore_member(member))
