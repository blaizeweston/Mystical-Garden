extends RefCounted
## One session's peer authorization and transport lifecycle. This owner receives
## scalar identity facts, never Game, player records, rewards or save payloads.

const Settings = preload("res://network_settings.gd")
const STATE := "network_session"
enum Exit { NONE, TITLE, APPLICATION, SESSION }

class Peer extends RefCounted:
	var binding: int
	var slot: int
	var joined_at: int
	var local: bool
	var identity := ""
	var ready := false
	var rejecting := false
	var budgets: Dictionary = {}
	var departure_receipt := ""

	func _init(token: int, party_slot: int, arrived: int, is_local: bool) -> void:
		binding = token
		slot = party_slot
		joined_at = arrived
		local = is_local

class Link extends RefCounted:
	var _owner
	var _peer: int
	var _binding: int

	func _init(owner: RefCounted, peer: int, binding: int) -> void:
		_owner = owner
		_peer = peer
		_binding = binding

	func peer_id() -> int:
		return _peer if _owner.matches(_peer, _binding) else 0

	func belongs_to(owner: RefCounted) -> bool:
		return is_same(_owner,owner) and _owner.matches(_peer,_binding)

	func ready() -> bool:
		return _owner.ready(peer_id())

	func rejecting() -> bool:
		return _owner.rejecting(peer_id())

	func identity() -> String:
		return _owner.identity(peer_id())

	func inventory_owner() -> String:
		return _owner.inventory_namespace(peer_id())

	func slot() -> int:
		return _owner.slot(peer_id())

	func joined_at() -> int:
		return _owner.arrived_at(peer_id())

var _peers: Dictionary[int, Peer] = {}
var _last_binding := 0
var _session_identity := Crypto.new().generate_random_bytes(16).hex_encode()
var _role := "Solo"
var _transport: ENetMultiplayerPeer
var _address := "127.0.0.1"
var _port := Settings.DEFAULT_PORT
var _deadline := 0
var _join_phase := ""
var _join_cancelled := false
var _joined_from_title := false
var _accepted_connection_key := ""
var _accepted_identity := ""
var _exit_intent: Exit = Exit.NONE
var _exit_nonce := ""
var _exit_confirmed := false

## Voluntary guest departure is correlated with a saved host projection.
## These are connection controls, not reward or character state.
func request_abandonment_exit(intent: Exit) -> String:
	if _role != "Guest" or _transport == null or intent == Exit.NONE: return ""
	if _transport.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return ""
	if _exit_nonce.is_empty(): _exit_nonce = Crypto.new().generate_random_bytes(16).hex_encode()
	_exit_intent = intent
	return _exit_nonce

func abandonment_exit_confirmed() -> bool:
	return _exit_confirmed

func awaiting_abandonment_save() -> bool:
	return not _exit_nonce.is_empty() and not _exit_confirmed

func confirm_abandonment_exit(nonce: String) -> Exit:
	if _role != "Guest" or nonce.is_empty() or nonce != _exit_nonce or _exit_confirmed: return Exit.NONE
	_exit_confirmed = true
	return _exit_intent

func mark_departure_saved(peer: int, expected_binding: int, nonce: String) -> bool:
	if not matches(peer,expected_binding) or not ready(peer) or nonce.length() != 32 or not nonce.is_valid_hex_number(false): return false
	_peers[peer].departure_receipt = nonce
	return true

func departure_receipt(peer: int) -> String:
	return _peers[peer].departure_receipt if ready(peer) else ""

static func belongs_to(record: Dictionary, owner: RefCounted) -> bool:
	var link: Link = record.get(STATE)
	return link != null and link.belongs_to(owner)

static func ready_for(record: Dictionary, fallback := false) -> bool:
	var link: Link = record.get(STATE)
	return link.ready() if link != null else bool(record.get("profile_ready", fallback))

static func rejecting_for(record: Dictionary) -> bool:
	var link: Link = record.get(STATE)
	return link.rejecting() if link != null else bool(record.get("rejecting", false))

static func identity_for(record: Dictionary) -> String:
	var link: Link = record.get(STATE)
	return link.identity() if link != null else str(record.get("seed_owner", ""))

static func inventory_owner(record: Dictionary) -> String:
	var link: Link = record.get(STATE)
	return link.inventory_owner() if link != null else str(record.get("seed_owner", ""))

static func slot_for(record: Dictionary, fallback: int = 0) -> int:
	var link: Link = record.get(STATE)
	return link.slot() if link != null else int(record.get("party_slot", fallback))

static func peer_for(record: Dictionary) -> int:
	var link: Link = record.get(STATE)
	return link.peer_id() if link != null else 0

static func joined_at(record: Dictionary, fallback: int = 0) -> int:
	var link: Link = record.get(STATE)
	return link.joined_at() if link != null else int(record.get("joined_at", fallback))

func role() -> String:
	return _role

func transport() -> ENetMultiplayerPeer:
	return _transport

func address() -> String:
	return _address

func port() -> int:
	return _port

func deadline() -> int:
	return _deadline

func join_phase() -> String:
	return _join_phase

func join_cancelled() -> bool:
	return _join_cancelled

func joined_from_title() -> bool:
	return _joined_from_title

func session_identity() -> String:
	return _session_identity

func configure_endpoint(host: String, selected_port: int) -> void:
	_address = Settings.address(host)
	_port = selected_port

func configure_join_origin(from_title: bool) -> void:
	_joined_from_title = from_title

func start_host(selected_port: int) -> Error:
	if _role != "Solo" or _transport != null: return ERR_BUSY
	if not Settings.error("127.0.0.1", selected_port).is_empty(): return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("*")
	var result := peer.create_server(selected_port, Settings.GUEST_LIMIT)
	if result != OK: return result
	_transport = peer
	_port = selected_port
	_role = "Host"
	_session_identity = Crypto.new().generate_random_bytes(16).hex_encode()
	return OK

func start_join(host: String, selected_port: int, now: int) -> Error:
	if _role != "Solo" or _transport != null: return ERR_BUSY
	if not Settings.error(host, selected_port).is_empty(): return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(host, selected_port)
	if result != OK: return result
	_peers.clear()
	_transport = peer
	_address = host
	_port = selected_port
	_role = "Connecting"
	_join_phase = "connect"
	_deadline = now + Settings.CONNECT_TIMEOUT_MS
	_join_cancelled = false
	_accepted_connection_key = ""
	_accepted_identity = ""
	_session_identity = Crypto.new().generate_random_bytes(16).hex_encode()
	return OK

func transport_connected(now: int) -> bool:
	if _role != "Connecting" or _join_phase == "character": return false
	_join_phase = "character"
	_deadline = now + Settings.REGISTER_TIMEOUT_MS
	return true

func compatibility_started() -> void:
	if _role == "Connecting": _join_phase = "compatibility"

func accept_guest(now: int, connection: String, character: String) -> bool:
	if _role != "Connecting" or connection.is_empty() or character.is_empty(): return false
	_role = "Guest"
	_join_phase = "garden"
	_deadline = now + Settings.REGISTER_TIMEOUT_MS
	_joined_from_title = false
	_accepted_connection_key = connection
	_accepted_identity = character
	return true

func accepted_connection_key() -> String:
	return _accepted_connection_key

func accepted_identity() -> String:
	return _accepted_identity

func permits_details(connection: String) -> bool:
	return _role == "Guest" and not connection.is_empty() and connection == _accepted_connection_key

func finish_recovery() -> void:
	if _role == "Guest":
		_join_phase = ""
		_deadline = 0

func cancel_join() -> void:
	_join_cancelled = true

func clear_deadline() -> void:
	_deadline = 0

func close_transport() -> void:
	_exit_intent = Exit.NONE
	_exit_nonce = ""
	_exit_confirmed = false
	var departing_transport := _transport
	_transport = null
	_peers.clear()
	_accepted_connection_key = ""
	_accepted_identity = ""
	_deadline = 0
	if departing_transport != null: departing_transport.close()
	# Role and join phase remain available to the title's recovery handoff.
	_session_identity = Crypto.new().generate_random_bytes(16).hex_encode()

func reset_solo() -> void:
	close_transport()
	_role = "Solo"
	_join_phase = ""
	_join_cancelled = false
	_joined_from_title = false

func admit_peer(id: int, now: int, character := "", local := false) -> Link:
	if _role not in ["Solo", "Host"] or id <= 0 or _peers.has(id) or _peers.size() >= Settings.MAX_PLAYERS:
		return null
	var used: Array[int] = []
	for peer in _peers.values(): used.append(peer.slot)
	var party_slot := 0
	while party_slot in used: party_slot += 1
	_last_binding += 1
	var member := Peer.new(_last_binding, party_slot, now, local)
	if local:
		member.identity = character
		member.ready = true
	_peers[id] = member
	return Link.new(self, id, member.binding)

## Before reopening a saved fight, bind its local attacks to the original host.
## Remote peers must obtain a fresh binding in the newly opened session.
func restore_expedition_host(saved_binding: int) -> Link:
	if _role not in ["Solo","Host"] or _peers.size()!=1 or not _peers.has(1) or not _peers[1].local or saved_binding<1:
		return null
	_peers[1].binding = saved_binding
	_last_binding = maxi(_last_binding,saved_binding)
	return Link.new(self,1,saved_binding)

func binding(id: int) -> int:
	return _peers[id].binding if _peers.has(id) else 0

func matches(id: int, token: int) -> bool:
	return token > 0 and _peers.has(id) and _peers[id].binding == token

## Admission policy receives only validated identity/compatibility facts.
## Settlement and expedition owners supply their own holds; we do not copy them.
func admission_error(character: String, protocol_matches: bool, content_matches: bool,
		valid_character: bool, host_character: String, settlement_held: bool, expedition_active: bool) -> String:
	if not protocol_matches: return "Different multiplayer versions. Use the same updated game build."
	if not content_matches: return "Different game content. Update all game copies before joining."
	if not valid_character: return "Invalid character identity. Choose another character."
	if character == host_character: return "This character is already the host. Choose a different character."
	if settlement_held: return "This character's last expedition rewards are still being saved."
	if has_character(character): return "This character is already connected."
	if expedition_active: return "The host is in the Wilds. Join after the party returns to the Garden."
	return ""

func bind_character(id: int, character: String, expected_binding: int) -> bool:
	if not matches(id, expected_binding) or _peers[id].ready or _peers[id].rejecting \
			or character.is_empty() or has_character(character): return false
	_peers[id].identity = character
	_peers[id].ready = true
	return true

func identity(id: int) -> String:
	return _peers[id].identity if _peers.has(id) else ""

func inventory_namespace(id: int) -> String:
	return "" if not _peers.has(id) or _peers[id].local else _peers[id].identity

func ready(id: int) -> bool:
	return _peers.has(id) and _peers[id].ready and not _peers[id].rejecting

func rejecting(id: int) -> bool:
	return _peers.has(id) and _peers[id].rejecting

func slot(id: int) -> int:
	return _peers[id].slot if _peers.has(id) else -1

func arrived_at(id: int) -> int:
	return _peers[id].joined_at if _peers.has(id) else 0

func has_character(character: String) -> bool:
	for peer in _peers.values():
		if peer.ready and peer.identity == character: return true
	return false

func peers() -> Array[int]:
	var result: Array[int] = []
	result.assign(_peers.keys())
	result.sort()
	result.make_read_only()
	return result

func view(id: int) -> Dictionary:
	if not _peers.has(id): return {}
	var member := _peers[id]
	var result := {"peer": id, "binding": member.binding, "identity": member.identity,
		"party_slot": member.slot, "joined_at": member.joined_at,
		"profile_ready": member.ready, "rejecting": member.rejecting}
	result.make_read_only()
	return result

func release_peer(id: int) -> Dictionary:
	var result := view(id)
	_peers.erase(id)
	return result

func disconnect_transport_peer(id: int, expected_binding: int) -> bool:
	if _transport == null or _role != "Host" or not matches(id, expected_binding): return false
	_transport.disconnect_peer(id)
	return true

func refuse_unregistered(id: int) -> void:
	if _transport != null and _role == "Host" and not _peers.has(id):
		_transport.disconnect_peer(id)

func reject(id: int, expected_binding: int) -> bool:
	if not matches(id, expected_binding) or _peers[id].rejecting: return false
	_peers[id].rejecting = true
	return true

func timed_out(now: int, timeout_ms: int) -> Array[int]:
	var result: Array[int] = []
	for id in _peers:
		var member := _peers[id]
		if not member.local and not member.ready and not member.rejecting and now - member.joined_at > timeout_ms:
			result.append(id)
	result.sort()
	result.make_read_only()
	return result

func allow(id: int, channel: String, limit: int, now: int) -> bool:
	if not ready(id) or limit < 1: return false
	var member := _peers[id]
	var budget: Array = member.budgets.get(channel, [now, 0])
	if now - int(budget[0]) >= 1000: budget = [now, 0]
	budget[1] += 1
	member.budgets[channel] = budget
	return int(budget[1]) <= limit

func connection_key(id: int) -> String:
	return _session_identity + ":" + str(binding(id)) if ready(id) else ""
