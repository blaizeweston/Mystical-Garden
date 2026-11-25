extends RefCounted
## Guest-only accepted network data and reconciliation. Never receives Game or
## mutable gameplay actors. Applying a projection cannot issue gameplay actions.
const World = preload("res://guest_replication_world.gd")
const Codec = preload("res://world_snapshot.gd")
const Identity = preload("res://network_action_identity.gd")
const Clock = preload("res://combat_clock.gd")
const Journal = preload("res://diagnostic_journal.gd")
const EVENT_LIMIT := 100
const EVENT_TAIL_SECONDS := 0.2
const DAMAGE_FLASH_MS := 250
const DEFAULT_CAMPAIGN := [0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0]
const DEFAULT_INVENTORY := [0,0,0,[false,false,false],0,0]
var _initial_hp: int
var _leader_hp: int
var _scouts := PackedFloat32Array()
var _campaign := PackedInt32Array(DEFAULT_CAMPAIGN)
var _carried := 0
var _pouch := false
var _briar := false
var _details := {}
var archive: Dictionary = {}
var archive_digest := ""
var _details_key := ""
var _details_at := -1
var _garden: Array = initial_garden()
var _inventory: Array = DEFAULT_INVENTORY.duplicate(true)
var _events: Array[Dictionary] = []
var _vitals := {}
var _flash := {}
var _sequence := -1
var _rejected := 0
var _gaps := 0
var _names := {}
var _diagnostic_host := ""
var _diagnostic_world := ""

func _init(initial_leader_hp: int) -> void:
	_initial_hp = initial_leader_hp
	_leader_hp = initial_leader_hp

static func initial_garden() -> Array:
	return [0,false,false,[false,false,false],[false,false,false],[0,0,0],0,false,0,false,0,false,PackedByteArray([0,0,0,0,0,0,0,0,0])]

func clear_session() -> void:
	_leader_hp = _initial_hp
	_scouts.clear();_campaign = PackedInt32Array(DEFAULT_CAMPAIGN)
	_carried = 0;_pouch = false;_briar = false
	archive = {};archive_digest = ""
	_details.clear();_details_key = "";_details_at = -1
	_garden = initial_garden();_inventory = DEFAULT_INVENTORY.duplicate(true)
	_events.clear();_vitals.clear();_flash.clear();_names.clear()
	_sequence = -1;_rejected = 0;_gaps = 0
	_diagnostic_host = "";_diagnostic_world = ""

func sequence() -> int: return _sequence
func rejected_count() -> int: return _rejected
func gap_count() -> int: return _gaps
func has_details() -> bool: return not _details.is_empty()
func details_key() -> String: return _details_key
func details() -> Dictionary: return _details.duplicate(true)
func received_events() -> Array: return _events.duplicate(true)
func details_age_ms(now: int) -> int: return now-_details_at if _details_at>=0 else 0
func scouts() -> PackedFloat32Array: return _scouts.duplicate()
func campaign() -> PackedInt32Array: return _campaign.duplicate()
func campaign_word(index: int) -> int: return _campaign[index] if index>=0 and index<_campaign.size() else 0
func inventory() -> Array: return _inventory.duplicate(true)
func carried_count() -> int: return _carried
func pouch_filled() -> bool: return _pouch
func briar_bound() -> bool: return _briar

## Progress fields 0–16 only. The potentially large generated layout (field 17)
## is delivered separately to the terrain owner; ordinary UI never copies it.
func garden_progress() -> Array: return _garden.duplicate(true)

func enemy_hp(target: int = -1) -> int:
	if target == -1: return _leader_hp
	var offset := target*Codec.Encounter.PACK_STRIDE+2
	return int(_scouts[offset]) if target>=0 and offset<_scouts.size() else 0

func living_scouts() -> int:
	var count := 0
	for offset in range(2,_scouts.size(),Codec.Encounter.PACK_STRIDE): count+=int(_scouts[offset]>0)
	return count

func receive_frame(world: World, frame: PackedByteArray, recovery: bool = false) -> void:
	var witness := world.observer()
	var received_at := Time.get_ticks_usec() if witness.is_valid() else 0
	var state := Codec.decode(frame)
	if state.is_empty():
		if received_at>0: witness.call({"phase":"invalid","at":received_at,"bytes":frame.size()})
		return
	var received_sequence: int = state.sequence
	var drop: Vector3 = state.drop
	if received_at>0:
		witness.call({"phase":"repair_receive" if recovery else "receive","sequence":received_sequence,
			"marker":int(drop.x),"at":received_at,"bytes":frame.size()})
	if recovery and received_sequence<=_sequence: return
	if not _accept_sequence(received_sequence):
		if received_at>0: witness.call({"phase":"stale","sequence":received_sequence,"marker":int(drop.x),"at":Time.get_ticks_usec()})
		if is_instance_valid(Journal.current) and Journal.current.detail:
			Journal.event("network","stale_snapshot",{"sequence":received_sequence,"last_sequence":_sequence})
		return
	for peer in state.people:
		_merge_health(int(peer),state.people[peer])
		_name_person(peer,state.people[peer])
	var local_peer := world.local_peer()
	if state.people.has(local_peer):
		var public: Dictionary = state.people[local_peer]
		state.people[local_peer] = _details.duplicate(true)
		state.people[local_peer].merge(public,true)
	_leader_hp = state.hp;_scouts = state.scouts.duplicate();_campaign = state.campaign.duplicate()
	_carried = state.carried;_pouch = (int(state.flags)&4)!=0;_briar = (int(state.flags)&8)!=0
	world.apply_world(state)
	if received_at>0:
		witness.call({"phase":"repair_apply" if recovery else "apply","sequence":received_sequence,"marker":int(drop.x),
			"at":Time.get_ticks_usec(),"apply_us":Time.get_ticks_usec()-received_at,
			"people":state.people.size(),"floor":world.floor_number(),"enemy_hp":_leader_hp})

func receive_details(world: World, payload: PackedByteArray, garden_bytes: PackedByteArray, inventory_data: Array, key: String) -> void:
	var decoded: Variant = bytes_to_var(payload.decompress_dynamic(262144,FileAccess.COMPRESSION_DEFLATE))
	var garden: Variant = bytes_to_var(garden_bytes.decompress_dynamic(262144 if world.requires_layout() else 65536,FileAccess.COMPRESSION_DEFLATE))
	if not decoded is Dictionary or not garden is Array or garden.size()<13: return
	if not world.accepts_details(str(decoded.get(Identity.BINDING_KEY,""))): return
	if world.requires_layout():
		if garden.size()!=18 or not garden[17] is Dictionary: return
		world.apply_layout(garden[17].duplicate(true))
	_names = decoded.get("snapshot_roster",{}).duplicate(true)
	_diagnostic_host = decoded.get("diagnostic_host","")
	_diagnostic_world = decoded.get("diagnostic_world","")
	world.apply_roster(_names.duplicate(true),_diagnostic_host,_diagnostic_world)
	decoded.erase("snapshot_roster")
	var recovery: PackedByteArray = decoded.get("snapshot_recovery",PackedByteArray())
	decoded.erase("snapshot_recovery")
	_details = decoded.duplicate(true);_details_key = key;_details_at = Clock.now()
	_inventory = inventory_data.duplicate(true);_garden = garden.slice(0,17).duplicate(true)
	world.apply_details(_details.duplicate(true))
	if not recovery.is_empty(): receive_frame(world,recovery,true)

func receive_vitals(world: World, states: Dictionary) -> void:
	Journal.event("network","vitals_received",{"states":states,"snapshot_sequence":_sequence})
	var updates := {}
	for peer in states:
		if not states[peer] is Dictionary: continue
		_accept_vital(int(peer),states[peer])
		if _vitals.has(int(peer)): updates[peer] = _health_projection(int(peer))
	world.apply_vitals(updates)

func receive_event(event: Dictionary, key: String) -> void:
	_events.append({"event":event.duplicate(true),"key":key,"born":Clock.now()})
	while _events.size()>EVENT_LIMIT: _events.pop_front()

func events(key: String, now: int, owner_events: Array) -> Array:
	var result := []
	for entry in _events.duplicate():
		var age: float = maxf(0,float(entry.event.get("age",0)))+(now-int(entry.born))/1000.0
		if age>float(entry.event.duration)+EVENT_TAIL_SECONDS: _events.erase(entry);continue
		if entry.key!=key: continue
		var event: Dictionary = entry.event.duplicate(true)
		event.age = age;result.append(event)
	if _details_key==key: result.append_array(owner_events.duplicate(true))
	return result

func _accept_sequence(received_sequence: int) -> bool:
	if received_sequence<0: return true # Local wire fixtures, never transmitted by the host.
	if received_sequence<=_sequence: _rejected+=1;return false
	if _sequence>=0: _gaps+=maxi(0,received_sequence-_sequence-1)
	_sequence = received_sequence
	return true

func _accept_vital(peer: int, state: Dictionary) -> void:
	var previous: Dictionary = _vitals.get(peer,{})
	if int(state.get("revision",0))<=int(previous.get("revision",-1)): return
	if not previous.is_empty() and int(state.get("damage_seq",0))>int(previous.get("damage_seq",0)):
		_flash[peer] = Time.get_ticks_msec()+DAMAGE_FLASH_MS
	_vitals[peer] = state.duplicate(true)

## Only fresh decoded wire records enter here, never mutable gameplay actors.
func _merge_health(peer: int, wire: Dictionary) -> void:
	var revision := int(wire.get("vitals_revision",0))
	if revision>int(_vitals.get(peer,{}).get("revision",-1)):
		_accept_vital(peer,{"revision":revision,"hp":wire.hp,"max_hp":wire.get("max_hp",10),
			"fallen":wire.get("fallen",false),"lost_health":wire.get("lost_health",0),
			"damage_seq":wire.get("damage_seq",0),"damage_amount":wire.get("damage_amount",0)})
	if _vitals.has(peer) and int(_vitals[peer].revision)>=revision: wire.merge(_health_projection(peer),true)
	wire.client_hurt_until = int(_flash.get(peer,0))

func _health_projection(peer: int) -> Dictionary:
	var state: Dictionary = _vitals[peer]
	var result := {"hp":state.hp,"max_hp":state.max_hp,"damage_seq":state.damage_seq,
		"vitals_revision":state.revision,"damage_amount":state.get("damage_amount",0),
		"client_hurt_until":int(_flash.get(peer,0))}
	for key in ["fallen","lost_health"]:
		if state.has(key): result[key] = state[key]
	return result

func _name_person(peer: int, wire: Dictionary) -> void:
	wire.display_name = _names.get(peer,"Wanderer")
	wire.diagnostic_host = _diagnostic_host;wire.diagnostic_world = _diagnostic_world
