extends RefCounted
## Godot world adapter for session operations. NetworkSession owns authorization
## and transport state; profile, participation and reward owners keep their data.

const Session = preload("res://network_session.gd")
const Transactions = preload("res://game_transaction.gd")
const Journal = preload("res://diagnostic_journal.gd")
const Network = preload("res://network_settings.gd")
const Character = preload("res://character_profile.gd")
const Participation = preload("res://expedition_participation.gd")
const PartyTravel = preload("res://party_travel.gd")
const ExpeditionWallet = preload("res://expedition_wallet.gd")
const Campaign = preload("res://campaign.gd")
const Life = preload("res://expedition_life.gd")
const Custody = preload("res://inventory_custody.gd")
const CustodyWorld = preload("res://inventory_custody_world.gd")

var _world: WeakRef
var _ticket := ""

func _init(world: Node) -> void:
	_world = weakref(world)


func host(port: int=0) -> Error:
	var game = _world.get_ref()
	if game.persistence_session.is_guarded() and (not game.persistence_session.can_write() or not game.persistence_session.authorizes(game.progress.path)):
		game.status="Hosting requires access to your selected Garden."
		return ERR_UNAUTHORIZED
	if not game.persistence_session.pending_notice().is_empty(): return ERR_BUSY
	if game.has_meta("developer_garden"):
		game.status="The Developer Garden is single-player."
		return ERR_UNAVAILABLE
	if game.is_practice_world(): return ERR_UNAVAILABLE
	Journal.event("network","host_requested",{"port":game.network_session.port() if port==0 else port})
	if game.network_session.role()!="Solo" or game.participation.active(): return ERR_BUSY
	var selected_port =game.network_session.port() if port==0 else port
	if not Network.error("127.0.0.1",selected_port).is_empty(): return ERR_INVALID_PARAMETER
	var result: Error = game.network_session.start_host(selected_port)
	if result!=OK:
		Journal.event("network","host_failed",{"error":result,"port":selected_port},"error")
		game.status="Could not host on UDP port %d. Another host may already be using it."%selected_port;return result
	game.multiplayer.multiplayer_peer=game.network_session.transport()
	game.status="Hosting co-op on UDP port %d. Share your reachable IP with up to three friends."%game.network_session.port()
	Journal.event("network","host_started",{"port":game.network_session.port()})
	game.ui.close_panels();return OK


func joined() -> void:
	var game = _world.get_ref()
	if game.persistence_session.is_guarded() and (game.network_session.role()!="Connecting" or not game.persistence_session.can_write()):
		game._stop_guarded_session("This session lost access to its save. Returning to the title.")
		return
	if not game.network_session.transport_connected(Time.get_ticks_msec()): return
	Journal.event("network","transport_connected")
	game.status = Network.join_progress("character",game.network_session.address(),game.network_session.port())
	game.ui.close_panels()
	var endpoint := Network.format_endpoint(game.network_session.address(),game.network_session.port())
	_ticket = game.guest_character.rejoin_ticket.get(endpoint,"")
	if game.portable_inventory and Custody.locked(game.guest_character.inventory_custody):
		_ticket=game.guest_character.rejoin_ticket.get(game.guest_character.inventory_custody.endpoint,_ticket)
	if _ticket.is_empty(): _ticket = Crypto.new().generate_random_bytes(32).hex_encode()
	_register_guest(false)

func _register_guest(with_custody: bool) -> void:
	var game = _world.get_ref()
	var guarded: bool=game.persistence_session.is_guarded()
	var catalog: Dictionary=game.progress.ContentIDs.manifest()
	catalog["rejoin_ticket"] = _ticket
	if guarded: catalog["guest_projection_receipts"] = game.guest_character.projection_receipts
	if game.portable_inventory:
		var custody: Dictionary=game.guest_character.inventory_custody
		catalog["custody_probe"]=not with_custody
		catalog["custody_pending"]=custody.get("origin","")
		if with_custody:catalog["custody_lock"]=custody
	game.register_character.rpc_id(game.HOST, game.guest_character.identity, game.guest_character.data,catalog,Network.PROTOCOL)


func register(id: int, identity: String, profile: Dictionary,catalog: Dictionary={},protocol: int=0) -> void:
	var game = _world.get_ref()
	if not game.multiplayer.is_server() or not game.players.has(id) \
			or not Session.belongs_to(game.players[id],game.network_session) or Session.peer_for(game.players[id]) != id \
			or game.network_session.ready(id) or game.network_session.rejecting(id):
		return
	var binding: int = game.network_session.binding(id)
	if binding == 0: return
	if game.persistence_session.is_blocked() and not game.persistence_session.is_guarded() and Character.valid_identity(identity) and protocol == Network.PROTOCOL:
		game.recover_departure_cleanup()
	if not game.persistence_session.can_write():
		reject(id, Transactions.feedback_text(game,"The host's Garden is unavailable."),binding)
		return
	if game.persistence_session.is_guarded() and not game.persistence_session.authorizes(game.progress.path):
		reject(id,"The host does not own the selected Garden.",binding)
		return
	var guarded = catalog.has("guest_projection_receipts")
	var receipts: Variant = catalog.get("guest_projection_receipts",{})
	if guarded:
		catalog = catalog.duplicate()
		catalog.erase("guest_projection_receipts")
	var ticket: Variant = catalog.get("rejoin_ticket","")
	catalog = catalog.duplicate()
	catalog.erase("rejoin_ticket")
	var portable:=catalog.has("custody_probe")
	var probe: Variant=catalog.get("custody_probe",false)
	var pending: Variant=catalog.get("custody_pending","")
	var lock: Variant=catalog.get("custody_lock",{})
	for key in ["custody_probe","custody_pending","custody_lock"]:catalog.erase(key)
	if protocol!=Network.PROTOCOL:
		reject(id,"Different multiplayer versions. Use the same updated game build.",binding);return
	if portable!=game.portable_inventory or (portable and not guarded):
		reject(id,"The host and guest must use matching portable inventory sessions.",binding);return
	var prior: Dictionary=game.progress.personal_custody.get(identity,{})
	var recovery: bool=portable and probe==true and pending==CustodyWorld.origin(game) and prior.get("state")=="returned"
	if portable:
		if not probe is bool or not pending is String or (not pending.is_empty() and pending!=CustodyWorld.origin(game)):
			reject(id,"Your personal inventory is held by another Garden.",binding);return
		if not probe and (not Custody.valid_profile(lock) or not Custody.locked(lock) or lock.origin!=CustodyWorld.origin(game) or lock.endpoint=="" or game.players[id].get("custody_offer")!=identity):
			reject(id,"The personal inventory custody offer is invalid.",binding);return
		if not probe and prior.get("state")=="returned" and Custody.matches(prior,lock):recovery=true
	var returning: bool = ticket is String and game.Continuation.authorized(game,identity,ticket)
	var reason = admission_error(identity,catalog,protocol,returning or recovery)
	if not ticket is String or ticket!="" and (ticket.length()!=64 or not ticket.is_valid_hex_number(false)): reason = "Invalid expedition rejoin ticket."
	if var_to_bytes(profile).size()>32768: reason="This character profile is too large."
	if reason.is_empty() and not Character.Experience.supported(profile):
		reason="This character uses an unsupported Class XP format."
	if reason.is_empty() and guarded != game.persistence_session.is_guarded():
		reason="The host and guest must use the same save mode."
	if reason.is_empty() and guarded and not load("res://guest_profile_projection.gd").valid_receipts(receipts):
		reason="Invalid guest profile receipts."
	if reason.is_empty() and not guarded and not game.progress.projection_origin.is_empty():
		reason="This Garden requires guarded profile saves."
	if not reason.is_empty(): reject(id,reason,binding);return
	var incoming: Dictionary=Character.normalize(profile)
	var original_digest := preload("res://guest_profile_projection.gd").digest(incoming)
	var recorded=game.progress.character_records.get(identity,{})
	var admission = {}
	var parked: Dictionary = game.parked_explorers.get(identity,{}) if returning else {}
	if returning:
		var origin: String = game.progress.projection_origin
		var receipt: Dictionary = receipts.get(origin,{}) if guarded else {}
		if not game.Continuation.profile_matches(parked.actor,incoming,recorded,receipt):
			reject(id,"This character changed while disconnected. Your character and expedition seat have been preserved.",binding)
			return
	if guarded:
		var projection = load("res://guest_profile_projection.gd")
		var origin: String = game.progress.projection_origin
		if origin.is_empty(): origin = game.progress.archive.origin
		admission = projection.admit(origin, incoming, receipts, recorded)
		if admission.is_empty():
			reject(id,"The saved guest projection conflicts with this character. Review the saves before joining.",binding)
			return
		if portable and probe:
			# The destination is disclosed only after compatibility and profile
			# validation. The guest durably locks BEFORE sending any item payload.
			game.players[id].custody_offer=identity
			game.connection_accepted.rpc_id(id,{"custody_offer":CustodyWorld.origin(game),"session_character":identity})
			return
		if portable and recovery and Custody.matches(prior,lock):
			game.players[id].custody_recovery_identity=identity
			var envelope:=CustodyWorld.return_envelope(game,identity)
			if recorded.get("projection",{}).get("revision",0)>receipts.get(origin,{}).get("revision",0):
				envelope.recovery_projection={"origin":origin,"projection":recorded.projection,"profile":recorded.profile}
			game.connection_accepted.rpc_id(id,envelope)
			return
		incoming = parked.actor.character.duplicate(true) if returning else admission.profile.duplicate(true)
		game.Progress.Archive.set_slice(incoming,game.progress.archive,identity)
		# Preserve the verified guest base even if its previous Garden sent a slice.
		if projection.digest(incoming) != admission.projection.digest:
			admission.projection = projection.build(incoming,int(admission.projection.revision)+1,admission.base)
			if admission.projection.is_empty():
				reject(id,"Character projection revisions exhausted.",binding)
				return
		var result = Transactions.run_gameplay(game, Transactions.Scope.GARDEN, func():
			if not game.network_session.matches(id,binding): return false
			if not preload("res://garden_growth_service.gd").register_receipt(game,identity):
				return false
			if portable and Custody.admit(game.progress,identity,lock)!="active":return CustodyWorld.fail_serializer(game.progress.path)
			game.progress.projection_origin = origin
			game.progress.character_records[identity] = {"profile":incoming.duplicate(true),"manifest":game.progress.ContentIDs.manifest(),"projection":admission.projection}
			return true)
		if not game.network_session.matches(id,binding): return
		if not result.completed or result.value != true or not game.persistence_session.can_write():
			reject(id,result.notice if not result.notice.is_empty() else "The host could not save your admission to this Garden.",binding)
			return
	elif recorded is Dictionary and recorded.get("profile") is Dictionary:
		if not Character.Experience.supported(recorded.profile):
			reject(id,"The Garden's character record uses an unsupported Class XP format.",binding)
			return
		var recovered: Dictionary=Character.normalize(game.progress.ContentIDs.profile(recorded.profile,recorded.get("manifest",game.progress.ContentIDs.legacy())))
		preload("res://guest_profile_projection.gd").merge_progress(incoming,recovered)
	if not guarded: game.Progress.Archive.set_slice(incoming,game.progress.archive,identity)
	if not game.players.has(id) or not game.network_session.bind_character(id,identity,binding): return
	if returning and not guarded: incoming = parked.actor.character.duplicate(true)
	game.players[id].character = incoming
	game.players[id].admitted_profile_digest = original_digest
	if not ticket.is_empty(): game.players[id].rejoin_digest = ticket.sha256_text()
	PartyTravel.cancel(game,"Party changed. Confirm readiness again.")
	game.restore_class_loadout(game.players[id])
	if not game.persistence_session.is_guarded(): preload("res://garden_growth_service.gd").register(game,id)
	Journal.event("network","character_registered",{"actor":id,"class_id":incoming.get("active_class",0)})
	if guarded:
		game.players[id].projection_base = admission.base
		game.players[id].projection_delivery = {"revision":admission.projection.revision,"state":"pending","feedback":[]}
	if returning: game.Continuation.rejoin(game,id,identity)
	var reply: Dictionary = {"profile":incoming,"origin":game.progress.projection_origin,"projection":admission.projection} if guarded else incoming.duplicate()
	reply.session_binding = game.network_session.connection_key(id)
	reply.session_character = identity
	reply.resumed_expedition = returning
	if portable:
		reply.custody_sequence=lock.sequence
		reply.custody_token=lock.token
		reply.custody_origin=lock.origin
	game.connection_accepted.rpc_id(id,reply)
	game.expedition_statistics.bind_session(game.network_session.session_identity())
	var report: Dictionary = game.expedition_statistics.result_for(identity)
	if not report.is_empty(): game.send_expedition_result(id,identity,report.run,report)


func join(address: String="",port: int=0) -> Error:
	var game = _world.get_ref()
	if game.portable_inventory and not game.network_session.joined_from_title():
		game.status="Return to the title to visit another Garden with personal inventory."
		return ERR_UNAUTHORIZED
	if game.has_meta(&"experimental_terrain") and not game.network_session.joined_from_title():
		game.status = "Return to the title to join an experimental Garden."
		return ERR_UNAUTHORIZED
	if game.has_meta("developer_garden"):
		game.status="The Developer Garden is single-player."
		return ERR_UNAVAILABLE
	if game.is_practice_world(): return ERR_UNAVAILABLE
	Journal.event("network","join_requested",{"port":game.network_session.port() if port==0 else port})
	if game.network_session.role()!="Solo" or game.participation.active() or not game.persistence_session.pending_notice().is_empty():
		return ERR_BUSY
	var host_result =Network.address(game.network_session.address() if address.is_empty() else address)
	var selected_port =game.network_session.port() if port==0 else port
	var problem =Network.error(host_result,selected_port)
	if not problem.is_empty(): game.status=problem;return ERR_INVALID_PARAMETER
	var guarded = game.persistence_session if game.persistence_session.is_guarded() else null
	if guarded != null and not game.persistence_session.can_write():
		game.status="This session no longer owns the selected character."
		return ERR_UNAUTHORIZED
	var loaded: Error = guarded.reload_guest(game.guest_character) if guarded != null else game.guest_character.load_profile()
	if guarded != null and loaded != OK:
		game.status = "Could not read the selected character."
		return loaded
	if loaded!=OK and loaded!=ERR_FILE_NOT_FOUND: game.status="Could not read the selected character.";return loaded
	if game.slot_claimed:
		if guarded != null:
			if not game.save_session_garden(): return ERR_CANT_CREATE
			if not game.persistence_session.pending_notice().is_empty(): return ERR_BUSY
		else:
			var saved = game.progress.save_garden()
			if saved != OK: game.status="Save the Garden before joining another host.";return saved
	if guarded == null and game.guest_character.save_profile() != OK:
		game.status = "Could not save the guest character identity."
		return ERR_CANT_CREATE
	var result: Error = game.network_session.start_join(host_result,selected_port,Time.get_ticks_msec())
	if result != OK:
		Journal.event("network","join_failed",{"error":result},"error")
		game.status = "Could not start the connection. Check the address and port."
		return result
	game.replication.clear_session();game.guest_replication.clear_session();game.net_motion.clear()
	game.participation.detach_all()
	game.players.clear()
	game.motions.clear()
	game.multiplayer.multiplayer_peer = game.network_session.transport()
	if game.has_meta(&"guarded_host_cleanup_notice"): game.remove_meta(&"guarded_host_cleanup_notice")
	if game.has_meta(&"guest_projection_origin"): game.remove_meta(&"guest_projection_origin")
	game.status = Network.join_progress("connect",game.network_session.address(),game.network_session.port())
	game.ui.close_panels()
	return OK


func leave(message: String) -> void:
	var game = _world.get_ref()
	Journal.event("network","leave_requested",{"role":game.network_session.role()})
	if not game.persistence_session.can_write():
		game._stop_guarded_session("This session lost access to its save. Returning to the title.")
		return
	if game.active_character_slot>=0 and game.network_session.role() in ["Guest","Connecting"]:
		game.return_to_main_menu(message);return
	var was_guest = game.network_session.role() == "Guest"
	if game.persistence_session.is_guarded():
		if not game.prepare_guarded_exit(false): return
		if not game.persistence_session.can_write():
			game._finish_title_return(message)
			return
	else:
		if game.character_dirty:
			game.save_local_character()
			if not game.persistence_session.pending_notice().is_empty(): return
		if game.network_session.role() == "Host" and game.participation.active():
			if not game.expedition_transitions.finish_voluntary(): return
			if game.persistence_session.is_blocked():
				game._finish_title_return(message)
				return
	if game.persistence_session.is_guarded(): game.persistence_session.begin_shutdown()
	offline()
	game.replication.clear_session();game.guest_replication.clear_session();game.net_motion.clear()
	game.participation.detach_all()
	game.players.clear()
	game.motions.clear()
	game.participation.select_route(Campaign.GROVE)
	game.expedition_transitions.reset()
	game.network_session.reset_solo()
	game.add_player(game.HOST)
	if game.persistence_session.is_stopping(): game.persistence_session.finish_network_detach()
	if was_guest and game.active_slot >= 0:
		if game.persistence_session.is_guarded():
			if game.persistence_session.reload_guest(game.local_character) != OK:
				game._stop_guarded_session("Could not read the selected character.")
				return
		else:
			game.local_character.load_profile()
		game.players[game.HOST].character = game.local_character.data
	game.status = message


func remove(id: int) -> void:
	var game = _world.get_ref()
	if game.returning_to_title or game.persistence_session.is_stopping():
		game.network_session.release_peer(id)
		game.participation.detach(id)
		game.players.erase(id)
		game.motions.erase(id)
		return
	Journal.event("network","peer_disconnected",{"actor":id})
	var leaving: Dictionary = game.players.get(id, {})
	var leaving_wild = Participation.is_wild(leaving)
	if not game.multiplayer.is_server() or game.network_session.role()=="Guest" or game.network_session.role()=="Connecting":
		game.network_session.release_peer(id)
		game.participation.detach(id)
		game.players.erase(id)
		game.motions.erase(id)
		return
	var parked: bool = leaving_wild and game.Continuation.park(game,id)
	if leaving_wild and not parked:
		game.expedition_statistics.freeze_departure(game.participation.run_id(),Session.inventory_owner(leaving),Time.get_ticks_msec())
	if not parked and Session.ready_for(leaving,false):
		game._capture_pending_departure(id, leaving)
	var may_settle = game.persistence_session.can_write()
	game.network_session.release_peer(id)
	game.participation.detach(id)
	game.players.erase(id)
	game.motions.erase(id)
	if may_settle:
		PartyTravel.cancel(game,"A player disconnected. Confirm readiness again to continue.")
		var needs_wipe: bool = (game.participation.active() or leaving_wild) and Life.living_ids(game).is_empty() and (game.participation.active() or not parked)
		if needs_wipe: game.expedition_transitions.finish_failed()
		elif (game.parked_explorers.is_empty() or game.participation.active()) and game.flush_kill_rewards() and not game.persistence_session.is_guarded() and game.persistence_session.can_write():
			game.expedition_transitions.finish_if_empty()
			game.resume_checkpoint_if_ready()


func server_disconnected() -> void:
	var game = _world.get_ref()
	if game.persistence_session.is_stopping(): return
	if game.portable_inventory:game.set_meta(&"custody_disconnected",true)
	Journal.event("network","on_server_disconnected",{},"warning")
	if game.network_session.role()=="Connecting" or (game.network_session.role()=="Guest" and game.network_session.join_phase()=="garden"):
		rejected(Network.join_failure(game.network_session.join_phase(),game.network_session.address(),game.network_session.port(),false))
	elif game.network_session.role()=="Guest":
		leave("Host disconnected. Personal inventory remains held by the original Garden. Reconnect with this character to recover it." if game.portable_inventory and Custody.locked(game.guest_character.inventory_custody) else "Host disconnected. Rejoin the same host and character when the expedition is available.")


func connection_failed() -> void:
	var game = _world.get_ref()
	if game.persistence_session.is_stopping() or game.network_session.role() != "Connecting": return
	Journal.event("network","on_connection_failed",{},"warning")
	if game.network_compatibility!=null and not game.network_compatibility.failure_reason.is_empty():
		rejected(game.network_compatibility.failure_reason);return
	rejected(Network.join_failure(game.network_session.join_phase(),game.network_session.address(),game.network_session.port(),false))


# Settle through one guarded decision. A first abort or uncertain result leaves
# the world and its notice available. Leaving an already blocked world is read-only.


func offline() -> void:
	var game = _world.get_ref()
	game.network_session.close_transport()
	game.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func admission_error(identity: String,catalog: Dictionary,protocol: int, returning := false) -> String:
	var game = _world.get_ref()
	return game.network_session.admission_error(identity, protocol == Network.PROTOCOL,
		catalog == game.progress.ContentIDs.manifest(), Character.valid_identity(identity),
		game.local_character.identity, game.departure_settlement.blocks_admission(identity),
		(game.participation.active() or not game.parked_explorers.is_empty()) and not returning)


func reject(id: int, reason: String, expected_binding: int = 0) -> void:
	var game = _world.get_ref()
	var binding: int = game.network_session.binding(id) if expected_binding == 0 else expected_binding
	if not game.network_session.reject(id,binding): return
	Journal.event("network","peer_rejected",{"actor":id,"reason":reason},"warning")
	game.connection_rejected.rpc_id(id,reason)
	var rejected_transport: ENetMultiplayerPeer = game.network_session.transport()
	var held_world: WeakRef = weakref(game)
	game.get_tree().create_timer(.25).timeout.connect(func():
		var current = held_world.get_ref()
		if current == null or not current.is_inside_tree() or current.is_queued_for_deletion(): return
		if current.network_session.transport()==rejected_transport and current.multiplayer.is_server() \
				and current.network_session.matches(id,binding) and current.network_session.rejecting(id):
			current.network_session.disconnect_transport_peer(id,binding))


func accepted(profile: Dictionary) -> void:
	var game = _world.get_ref()
	if game.network_session.role()!="Connecting" or not game.persistence_session.can_write(): return
	if game.portable_inventory and profile.has("custody_offer"):
		var destination: Variant=profile.custody_offer
		if profile.get("session_character")!=game.guest_character.identity or not Custody.hex_id(destination,32):
			rejected("Invalid Garden inventory custody offer.");return
		var endpoint:=Network.format_endpoint(game.network_session.address(),game.network_session.port())
		if not CustodyWorld.guest_lock(game,destination,endpoint,_ticket):
			rejected(game.status);return
		_register_guest(true)
		return
	if game.portable_inventory and profile.has("custody_return"):
		var projection: Dictionary=profile.get("recovery_projection",{})
		if not projection.is_empty():
			game.set_meta(&"guest_projection_origin",projection.origin)
			if not game.save_guest_projection(projection.profile,projection.origin,projection.projection):
				rejected("Could not reconcile the saved profile. Inventory custody remains locked.");return
		if not CustodyWorld.accept_guest_return(game,profile,true):
			rejected("Could not recover the returned inventory. Reconnect to the same Garden.");return
		return
	if game.portable_inventory and profile.has("custody_acknowledged"):
		if game.custody_return_origin==profile.custody_acknowledged and game.guest_character.inventory_custody.get("state")=="home" and game.guest_character.inventory_custody.sequence==profile.get("sequence"):
			CustodyWorld.finish_return.call_deferred(game,Session.Exit.TITLE)
		return
	var connection := str(profile.get("session_binding",""))
	var identity := str(profile.get("session_character",""))
	if connection.is_empty() or identity != game.guest_character.identity:
		rejected("The host did not provide the current session binding.")
		return
	var payload := profile.duplicate()
	var resumed: bool = payload.get("resumed_expedition",false)==true
	payload.erase("session_binding");payload.erase("session_character");payload.erase("resumed_expedition")
	if game.portable_inventory:
		var lock: Dictionary=game.guest_character.inventory_custody
		if not Custody.locked(lock) or lock.origin!=payload.get("custody_origin") or lock.token!=payload.get("custody_token") or lock.sequence!=payload.get("custody_sequence"):
			rejected("The host did not confirm the checked-out inventory.");return
		for key in ["custody_origin","custody_token","custody_sequence"]:payload.erase(key)
	if game.persistence_session.is_guarded():
		if not payload.get("origin") is String or not payload.get("projection") is Dictionary or not payload.get("profile") is Dictionary:
			rejected("The host did not provide guarded profile evidence.")
			return
	elif payload.has("projection"):
		rejected("The host and guest must use the same save mode.")
		return
	if not game.network_session.accept_guest(Time.get_ticks_msec(),connection,identity): return
	var endpoint := Network.format_endpoint(game.network_session.address(),game.network_session.port())
	if game.guest_character.rejoin_ticket.get(endpoint,"")!=_ticket:
		if game.persistence_session.is_guarded():
			var stored := Transactions.run_gameplay(game,Transactions.Scope.GUEST_PROFILE,func():
				game.guest_character.rejoin_ticket[endpoint] = _ticket
				return true)
			if not stored.completed or stored.value!=true:
				rejected(Transactions.feedback_text(game,"Could not save your rejoin ticket."))
				return
		else:
			game.guest_character.rejoin_ticket[endpoint] = _ticket
			if game.guest_character.save_profile()!=OK:
				rejected("Could not save your rejoin ticket.")
				return
	if game.persistence_session.is_guarded():
		game.set_meta(&"guest_projection_origin",payload.origin)
		var saved: bool = game.save_guest_projection(payload.profile,payload.origin,payload.projection)
		if not saved or not game.persistence_session.can_write():
			rejected(Transactions.feedback_text(game,"Could not finish loading the selected character."))
			return
	Journal.event("network","join_accepted")
	game.status="Rejoined your expedition." if resumed else "Joined the host's Garden."
	if not game.persistence_session.is_guarded(): game.receive_character(payload)
	game.ui.close_panels()


func rejected(reason: String) -> void:
	var game = _world.get_ref()
	Journal.event("network","connection_rejected",{"reason":reason},"warning")
	game.network_session.clear_deadline()
	if game.active_character_slot>=0 or game.network_session.joined_from_title(): game.return_to_main_menu(reason)
	else: leave(reason)


func update(now: int = -1) -> void:
	var game = _world.get_ref()
	if not is_instance_valid(game.ui): return
	var instant := Time.get_ticks_msec() if now < 0 else now
	var waiting: bool=game.network_session.role()=="Connecting" or (game.network_session.role()=="Guest" and not game.guest_replication.has_details())
	game.ui.present_connection(waiting,Network.join_progress(game.network_session.join_phase(),game.network_session.address(),game.network_session.port()) if waiting else "")
	if waiting:
		var phase: String = game.network_session.join_phase()
		if game.network_session.deadline()>0 and instant>game.network_session.deadline():
			rejected(Network.join_failure(phase,game.network_session.address(),game.network_session.port(),true))
	elif game.network_session.role()=="Guest":
		game.network_session.finish_recovery()
	if game.network_session.role()=="Host":
		for id in game.network_session.timed_out(instant,Network.REGISTER_TIMEOUT_MS):
			reject(id,"Character registration timed out. Check both game versions.")


func allow_remote(id: int, channel: String, limit: int, read_only := false) -> bool:
	var game = _world.get_ref()
	if (not read_only and not game.persistence_session.can_simulate()) or not game.players.has(id): return false
	if not Session.belongs_to(game.players[id],game.network_session) or Session.peer_for(game.players[id]) != id: return false
	return game.network_session.allow(id,channel,limit,Time.get_ticks_msec())
