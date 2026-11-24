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

var _world: WeakRef

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
	var guarded = game.persistence_session.is_guarded()
	var catalog: Dictionary = game.progress.ContentIDs.manifest()
	if guarded: catalog["guest_projection_receipts"] = game.guest_character.projection_receipts
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
	var reason =admission_error(identity,catalog,protocol)
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
	var recorded=game.progress.character_records.get(identity,{})
	var admission = {}
	if guarded:
		var projection = load("res://guest_profile_projection.gd")
		var origin: String = game.progress.projection_origin
		if origin.is_empty(): origin = Crypto.new().generate_random_bytes(16).hex_encode()
		admission = projection.admit(origin, incoming, receipts, recorded)
		if admission.is_empty():
			reject(id,"The saved guest projection conflicts with this character. Review the saves before joining.",binding)
			return
		incoming = admission.profile
		var result = Transactions.run_gameplay(game, Transactions.Scope.GARDEN, func():
			if not game.network_session.matches(id,binding): return false
			if not preload("res://garden_growth_service.gd").register_receipt(game,identity):
				return false
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
	if not game.players.has(id) or not game.network_session.bind_character(id,identity,binding): return
	game.players[id].character = incoming
	PartyTravel.cancel(game,"Party changed. Confirm readiness again.")
	game.restore_class_loadout(game.players[id])
	if not game.persistence_session.is_guarded(): preload("res://garden_growth_service.gd").register(game,id)
	Journal.event("network","character_registered",{"actor":id,"class_id":incoming.get("active_class",0)})
	if guarded:
		game.players[id].projection_base = admission.base
		game.players[id].projection_delivery = {"revision":admission.projection.revision,"state":"pending","feedback":[]}
	var reply: Dictionary = {"profile":incoming,"origin":game.progress.projection_origin,"projection":admission.projection} if guarded else incoming.duplicate()
	reply.session_binding = game.network_session.connection_key(id)
	reply.session_character = identity
	game.connection_accepted.rpc_id(id,reply)
	game.expedition_statistics.bind_session(game.network_session.session_identity())
	var report: Dictionary = game.expedition_statistics.result_for(identity)
	if not report.is_empty(): game.send_expedition_result(id,identity,report.run,report)


func join(address: String="",port: int=0) -> Error:
	var game = _world.get_ref()
	if game.has_meta(&"experimental_terrain") and not game.network_session.joined_from_title():
		game.status = "Return to the title to join an experimental Garden."
		return ERR_UNAUTHORIZED
	if game.has_meta("developer_garden"):
		game.status="The Developer Garden is single-player."
		return ERR_UNAVAILABLE
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
	leaving.erase(ExpeditionWallet.STATE)
	if not game.multiplayer.is_server() or game.network_session.role()=="Guest" or game.network_session.role()=="Connecting":
		game.network_session.release_peer(id)
		game.participation.detach(id)
		game.players.erase(id)
		game.motions.erase(id)
		return
	if leaving_wild:
		game.expedition_statistics.freeze_departure(game.participation.run_id(),Session.inventory_owner(leaving),Time.get_ticks_msec())
	if Session.ready_for(leaving,false):
		game._capture_pending_departure(id, leaving)
	var may_settle = game.persistence_session.can_write()
	game.network_session.release_peer(id)
	game.participation.detach(id)
	game.players.erase(id)
	game.motions.erase(id)
	game.refresh_drop()
	if may_settle:
		PartyTravel.cancel(game,"A player disconnected. Confirm readiness again to continue.")
		var needs_wipe: bool = (game.participation.active() or leaving_wild) and Life.living_ids(game).is_empty()
		if needs_wipe: game.expedition_transitions.finish_failed()
		elif game.flush_kill_rewards() and not game.persistence_session.is_guarded() and game.persistence_session.can_write():
			game.expedition_transitions.finish_if_empty()
			game.resume_checkpoint_if_ready()


func server_disconnected() -> void:
	var game = _world.get_ref()
	if game.persistence_session.is_stopping(): return
	Journal.event("network","on_server_disconnected",{},"warning")
	if game.network_session.role()=="Connecting" or (game.network_session.role()=="Guest" and game.network_session.join_phase()=="garden"):
		rejected(Network.join_failure(game.network_session.join_phase(),game.network_session.address(),game.network_session.port(),false))
	elif game.network_session.role()=="Guest":
		leave("Host disconnected. Your character progress is preserved.")


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


func admission_error(identity: String,catalog: Dictionary,protocol: int) -> String:
	var game = _world.get_ref()
	return game.network_session.admission_error(identity, protocol == Network.PROTOCOL,
		catalog == game.progress.ContentIDs.manifest(), Character.valid_identity(identity),
		game.local_character.identity, game.departure_settlement.blocks_admission(identity),
		game.participation.active())


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
	var connection := str(profile.get("session_binding",""))
	var identity := str(profile.get("session_character",""))
	if connection.is_empty() or identity != game.guest_character.identity:
		rejected("The host did not provide the current session binding.")
		return
	var payload := profile.duplicate()
	payload.erase("session_binding");payload.erase("session_character")
	if game.persistence_session.is_guarded():
		if not payload.get("origin") is String or not payload.get("projection") is Dictionary or not payload.get("profile") is Dictionary:
			rejected("The host did not provide guarded profile evidence.")
			return
	elif payload.has("projection"):
		rejected("The host and guest must use the same save mode.")
		return
	if not game.network_session.accept_guest(Time.get_ticks_msec(),connection,identity): return
	if game.persistence_session.is_guarded():
		game.set_meta(&"guest_projection_origin",payload.origin)
		var saved: bool = game.save_guest_projection(payload.profile,payload.origin,payload.projection)
		if not saved or not game.persistence_session.can_write():
			rejected(Transactions.feedback_text(game,"Could not finish loading the selected character."))
			return
	Journal.event("network","join_accepted")
	game.status="Joined the host's Garden."
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
