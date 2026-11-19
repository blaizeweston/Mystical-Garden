extends RefCounted
## Detached wire data and a projection-only receiver. No Game or gameplay actors.
const Receiver = preload("res://guest_replication.gd")
const Port = preload("res://guest_replication_world.gd")
const Codec = preload("res://world_snapshot.gd")

class World extends Port:
	var people := {}
	var last_world := {}
	var layouts: Array[Dictionary] = []
	var require_layout := false
	var binding := "current-binding"
	var details_applied := 0
	func _init(): super(null)
	func observer() -> Callable: return Callable()
	func local_peer() -> int: return 1
	func floor_number() -> int: return 1
	func requires_layout() -> bool: return require_layout
	func accepts_details(value: String) -> bool: return value==binding
	func apply_layout(layout: Dictionary) -> void: layouts.append(layout)
	func apply_roster(names: Dictionary, host: String, session: String) -> void:
		for peer in people:
			people[peer].display_name=names.get(peer,"Wanderer")
			people[peer].diagnostic_host=host;people[peer].diagnostic_world=session
	func apply_details(details: Dictionary) -> void:
		details_applied+=1
		if people.has(1): people[1].merge(details,true)
	func apply_vitals(updates: Dictionary) -> void:
		for peer in updates:
			if people.has(peer): people[peer].merge(updates[peer],true)
	func apply_world(state: Dictionary) -> void:
		last_world=state;people=state.people

static func person(revision: int = 1, hp: float = 10.0, damage_sequence: int = 0) -> Dictionary:
	return {"pos":Vector3.ZERO,"velocity":Vector3.ZERO,"motion_radius":10.0,"motion_scale":1.0,
		"motion_ack":{"ack":0,"partial_sequence":0,"partial":0.0},"vitals_revision":revision,
		"damage_seq":damage_sequence,"damage_amount":0,"hp":hp,"max_hp":10,"lost_health":0,"wallet":0,
		"pose":0,"core_part":0,"party_slot":0,"wild":false,"fallen":false,"frame":0,"weapon_kind":0,
		"appearance":PackedByteArray(),"skill_ready":true,"skill_two_ready":true,"skill_cooldowns":[0.0,0.0],
		"attack_anim":{"form":"weapon","active":false,"direction":null,"clip":"","delivery":"sweep",
			"phase":0.0,"combo":0,"duration":0,"reach":0.0,"span":0.0}}

static func frame(sequence: int, people: Dictionary, marker: int = 0) -> PackedByteArray:
	var campaign := PackedInt32Array()
	campaign.resize(Codec.CAMPAIGN_WORDS);campaign[9]=1
	return Codec.encode(sequence,people,campaign,PackedFloat32Array(),Vector3.ZERO,99,100,Vector3(marker,0,0),1,0)

static func health_checks(check: Callable) -> void:
	var receiver := Receiver.new(3)
	var world := World.new()
	receiver.receive_frame(world,frame(20,{1:person()}))
	receiver.receive_frame(world,frame(19,{1:person()}))
	receiver.receive_frame(world,frame(20,{1:person()}))
	check.call(receiver.sequence()==20 and receiver.rejected_count()==2,"stale or duplicate movement snapshots rejected")
	receiver.receive_vitals(world,{1:{"revision":2,"hp":9,"max_hp":10,"damage_seq":1,"damage_amount":1}})
	receiver.receive_frame(world,frame(21,{1:person()}))
	var stale: Dictionary=world.people[1]
	check.call(stale.hp==9 and stale.vitals_revision==2 and stale.damage_amount==1 and stale.client_hurt_until>Time.get_ticks_msec(),"reliable damage survives an older movement packet and flashes once")
	var flash: int=stale.client_hurt_until
	receiver.receive_vitals(world,{1:{"revision":2,"hp":9,"max_hp":10,"damage_seq":1,"damage_amount":1}})
	check.call(world.people[1].client_hurt_until==flash,"duplicate health confirmation cannot repeat hit feedback")
	receiver.receive_frame(world,frame(22,{1:person(3,8,2)}))
	receiver.receive_vitals(world,{1:{"revision":2,"hp":9,"max_hp":10,"damage_seq":1,"damage_amount":1}})
	check.call(world.people[1].hp==8,"older reliable health cannot overwrite newer authority state")
	receiver.clear_session()
	receiver.receive_frame(world,frame(0,{1:person(0,10)}))
	check.call(receiver.sequence()==0 and world.people[1].hp==10,"reconnect resets presentation epochs")
