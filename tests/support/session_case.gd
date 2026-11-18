extends RefCounted
## Synthetic fixture setup only. Live registration uses SessionWorld's host path.
## This helper supplies scalar connection facts through the actual owner APIs.
const Session = preload("res://network_session.gd")
const World = preload("res://session_world.gd")
const ROLE_FACTS := &"ar14_fixture_session_facts"


static func returned_to_guarded_title(scene: Object) -> bool:
	if not is_instance_valid(scene) or not scene.has_method("persistence_return_view"): return false
	return bool(scene.persistence_return_view().get("guarded", false))

static func has_guarded_session(world: Object) -> bool:
	if not is_instance_valid(world): return false
	var owner: RefCounted = world.get("persistence_session")
	return owner != null and owner.is_guarded()

static func role(world: Node) -> String:
	if not is_instance_valid(world): return ""
	var owner: RefCounted = world.get("network_session")
	return owner.role() if owner != null else ""

static func ready(actor: Dictionary, fallback := false) -> bool:
	return Session.ready_for(actor,fallback)

static func identity(actor: Dictionary) -> String:
	return Session.inventory_owner(actor)

static func _peer(world: Node, actor: Dictionary) -> int:
	for peer in world.players:
		if is_same(world.players[peer],actor): return int(peer)
	return 0

static func _install(world: Node, peer: int, actor: Dictionary, accepted: bool, character: String) -> void:
	var owner: RefCounted = world.network_session
	owner.release_peer(peer)
	var local := peer == 1 and accepted
	var link = owner.admit_peer(peer,Time.get_ticks_msec(),character if local else "",local)
	assert(link != null,"Fixture exceeds the supported peer count")
	actor[Session.STATE] = link
	for field in ["profile_ready","seed_owner","party_slot","joined_at","rejecting","request_budget"]:
		actor.erase(field)
	if accepted and not local:
		assert(owner.bind_character(peer,character,owner.binding(peer)),"Fixture character must be unique")

static func install_registration(world: Node, peer: int, actor: Dictionary) -> void:
	var accepted := bool(actor.get("profile_ready",Session.ready_for(actor)))
	var character := str(actor.get("seed_owner",""))
	if character.is_empty():
		character = Session.identity_for(actor) if Session.peer_for(actor) == peer else ""
	if character.is_empty(): character = world.local_character.identity if peer == 1 else "fixture-character-"+str(peer)
	_install(world,peer,actor,accepted,character)

static func set_ready(world: Node, actor: Dictionary, accepted: bool) -> void:
	var peer := _peer(world,actor)
	if peer == 0:
		actor.profile_ready = accepted # A detached fixture record, not live authority.
		return
	if Session.peer_for(actor) == peer and Session.ready_for(actor) == accepted: return
	var character := Session.identity_for(actor)
	if character.is_empty(): character = world.local_character.identity if peer == 1 else "fixture-character-"+str(peer)
	_install(world,peer,actor,accepted,character)

static func set_identity(world: Node, actor: Dictionary, character: String) -> void:
	var peer := _peer(world,actor)
	if peer == 0:
		actor.seed_owner = character # A detached fixture record awaiting installation.
		return
	if Session.peer_for(actor) == peer and Session.identity_for(actor) == character: return
	# Supplying a validated fixture character is the accepted binding operation.
	_install(world,peer,actor,true,character)

static func set_role(world: Node, value: String) -> void:
	var owner: RefCounted = world.network_session
	if owner.role() == value: return
	# Only scalar setup facts cross this test-only role switch. No actor, reward,
	# inventory, participation or save payload is copied into another authority.
	var facts: Dictionary = world.get_meta(ROLE_FACTS,{})
	if owner.role() in ["Solo","Host"]:
		facts = {}
		for peer in world.players:
			var actor: Dictionary = world.players[peer]
			facts[peer] = {"ready":Session.ready_for(actor),"identity":Session.identity_for(actor)}
		world.set_meta(ROLE_FACTS,facts)
	owner.reset_solo()
	if value == "Guest":
		assert(owner.start_join("127.0.0.1",owner.port(),Time.get_ticks_msec()) == OK)
		assert(owner.transport_connected(Time.get_ticks_msec()))
		assert(owner.accept_guest(Time.get_ticks_msec(),"fixture-guest-binding",world.guest_character.identity))
		owner.finish_recovery()
		return
	if value == "Host": assert(owner.start_host(owner.port()) == OK)
	else: assert(value == "Solo","Fixture must use a supported session role")
	for peer in world.players:
		var actor: Dictionary = world.players[peer]
		var entry: Dictionary = facts.get(peer,{"ready":true,"identity":"fixture-character-"+str(peer)})
		_install(world,int(peer),actor,bool(entry.ready),str(entry.identity))
