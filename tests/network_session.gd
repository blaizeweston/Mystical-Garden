extends SceneTree
## Peer/transport ownership. Real RPC and persistence boundaries use co-op fixtures.
const Session = preload("res://network_session.gd")
const Settings = preload("res://network_settings.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL network session: ",message)

func run() -> void:
	var owner := Session.new()
	var local := {Session.STATE:owner.admit_peer(1,100,"host-character",true)}
	check(owner.role() == "Solo" and Session.ready_for(local) and Session.peer_for(local) == 1,"local character begins ready in the solo session")
	check(owner.admission_error("guest",true,true,true,"host-character",false,false).is_empty(),"compatible unbound character is eligible")
	check(owner.admission_error("guest",false,true,true,"host-character",false,false).contains("versions"),"protocol mismatch wins before other admission checks")
	check(owner.admission_error("guest",true,false,true,"host-character",false,false).contains("content"),"content mismatch remains explicit")
	check(owner.admission_error("invalid",true,true,false,"host-character",false,false).contains("Invalid"),"invalid identity is refused")
	check(owner.admission_error("host-character",true,true,true,"host-character",false,false).contains("host"),"host identity cannot register twice")
	check(owner.admission_error("guest",true,true,true,"host-character",true,true).contains("saved"),"settlement hold wins before expedition activity")
	check(owner.admission_error("guest",true,true,true,"host-character",false,true).contains("Wilds"),"active expedition cannot admit a new character")
	var unrelated := Session.new()
	check(Session.belongs_to(local,owner) and not Session.belongs_to(local,unrelated),"a link authorizes only its original session owner")
	check(Session.identity_for(local) == "host-character" and Session.inventory_owner(local).is_empty(),
		"character authorization is separate from the host's shared-inventory namespace")
	check(owner.admit_peer(1,101) == null,"duplicate peer admission cannot replace a live binding")
	var remote := {Session.STATE:owner.admit_peer(7,110)}
	var first_binding := owner.binding(7)
	check(not Session.ready_for(remote) and not owner.allow(7,"action",3,200),"unregistered peer cannot act")
	check(not owner.bind_character(7,"host-character",first_binding),"host character cannot be bound by another peer")
	check(not owner.bind_character(7,"remote-character",first_binding+1),"stale registration binding is rejected")
	check(owner.bind_character(7,"remote-character",first_binding),"matching pending connection binds once")
	check(not owner.bind_character(7,"remote-character",first_binding)
		and not owner.bind_character(7,"replacement-character",first_binding),"duplicate registration cannot replace the accepted character")
	check(Session.ready_for(remote) and Session.identity_for(remote) == "remote-character"
		and Session.inventory_owner(remote) == "remote-character" and Session.slot_for(remote) == 1,
		"read-only link exposes the authoritative accepted identity and slot")
	var connection := owner.connection_key(7)
	check(not connection.is_empty() and owner.has_character("remote-character"),"accepted connection has a character-bound key")
	check(owner.admission_error("remote-character",true,true,true,"host-character",false,false).contains("connected"),"owner rejects an already bound character")
	var view := owner.view(7)
	var peers := owner.peers()
	check(view.is_read_only() and peers.is_read_only() and peers == [1,7],"peer projections are detached and read-only")
	check(Session.joined_at(remote) == 110,"arrival time belongs to the owner")
	for index in 3:
		check(owner.allow(7,"action",3,200),"ordinary request budget accepts allowed requests")
	check(not owner.allow(7,"action",3,200) and owner.allow(7,"motion",1,200),"budgets are per connection and request channel")
	check(owner.allow(7,"action",3,1200),"request budget resets at its normal interval")
	check(not owner.mark_departure_saved(7,first_binding+1,"a".repeat(32))
		and not owner.mark_departure_saved(7,first_binding,"bad"),"departure confirmation requires the current binding and a valid nonce")
	check(owner.mark_departure_saved(7,first_binding,"a".repeat(32))
		and owner.departure_receipt(7)=="a".repeat(32),"saved departure receipt is scoped to the accepted connection")
	var released := owner.release_peer(7)
	check(released.is_read_only() and released.identity == "remote-character" and not owner.ready(7),"release preserves only detached departure facts")
	check(Session.peer_for(remote) == 0 and not Session.ready_for(remote) and not owner.has_character("remote-character"),"removed actor link cannot authorize work")
	var replacement := {Session.STATE:owner.admit_peer(7,1300)}
	var next_binding := owner.binding(7)
	check(next_binding > first_binding and not owner.reject(7,first_binding),"peer reuse never reuses a connection generation")
	check(owner.bind_character(7,"replacement-character",next_binding) and owner.connection_key(7) != connection,
		"a different character on a reused peer receives a fresh connection key")
	check(owner.allow(7,"action",1,1300),"replacement peer does not inherit spent budgets")
	check(owner.departure_receipt(7).is_empty(),"reused peer cannot inherit a saved-departure acknowledgement")
	var pending := {Session.STATE:owner.admit_peer(8,100)}
	var third := {Session.STATE:owner.admit_peer(9,1500)}
	check(owner.bind_character(9,"third-character",owner.binding(9)),"fourth participant can register")
	check(owner.admit_peer(10,1501) == null and owner.peers().size() == Settings.MAX_PLAYERS,"fifth participant is refused")
	check(owner.timed_out(1600,1000) == [8],"registration timeout includes only eligible unregistered peers")
	var pending_binding := owner.binding(8)
	check(owner.reject(8,pending_binding) and not owner.reject(8,pending_binding)
		and owner.timed_out(1600,1000).is_empty() and not owner.bind_character(8,"late-character",pending_binding),
		"rejection is claimed once and blocks late registration")
	check(peers == [1,7] and view.identity == "remote-character","old views do not alias the current registry")
	owner.close_transport()
	check(owner.peers().is_empty() and not Session.ready_for(local) and not Session.ready_for(replacement)
		and not Session.ready_for(pending) and not Session.ready_for(third),"transport teardown invalidates every peer capability")
	var fresh = owner.admit_peer(1,1800,"host-character",true)
	check(fresh != null and owner.binding(1) > next_binding,"binding allocation survives teardown")
	owner.reset_solo()
	check(owner.start_join("127.0.0.1",Settings.DEFAULT_PORT,2000) == OK,"join creates the existing transport")
	check(owner.role() == "Connecting" and owner.join_phase() == "connect"
		and owner.deadline() == 2000+Settings.CONNECT_TIMEOUT_MS,"connect phase and deadline have one owner")
	owner.compatibility_started()
	check(owner.join_phase() == "compatibility" and owner.transport_connected(2100),"compatibility proceeds to character registration")
	check(not owner.transport_connected(2101),"duplicate transport callback does not restart registration")
	check(owner.accept_guest(2200,"accepted-binding","guest-character")
		and not owner.accept_guest(2201,"another-binding","another-character"),"host acceptance is applied once")
	check(owner.permits_details("accepted-binding") and not owner.permits_details("old-binding")
		and owner.accepted_identity() == "guest-character","owner details require the accepted connection binding")
	owner.finish_recovery()
	check(owner.role() == "Guest" and owner.deadline() == 0 and owner.join_phase().is_empty(),"recovery completes without a competing deadline")
	owner.reset_solo()
	check(owner.role() == "Solo" and owner.transport() == null and not owner.permits_details("accepted-binding"),"leaving retires accepted owner-detail identity")
	if not failed: print("PASS: session peer ownership, binding, admission limits, request budgets, stale peers, teardown and guest recovery")
	quit(1 if failed else 0)
