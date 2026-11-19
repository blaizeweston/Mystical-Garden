extends SceneTree
## Independent processes exercise the actual compatibility handshake and registry.
const Session = preload("res://network_session.gd")
const World = preload("res://session_world.gd")
const Contract = preload("res://network_contract.gd")
const Compatibility = preload("res://network_compatibility.gd")
var game: Node
var role: String
var base: String
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		printerr("FAIL network contract co-op ",role,": ",message)
	return ok

func mark(key: String) -> void:
	var file := FileAccess.open(base+"-"+key,FileAccess.WRITE)
	check(file != null,"fixture marker "+key)
	if file != null: file.store_string("ok")

func marked(key: String) -> bool:
	return FileAccess.file_exists(base+"-"+key)

func until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+14000
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await process_frame
	return predicate.call()

func run() -> void:
	role = OS.get_cmdline_user_args()[0]
	base = "res://.godot/ar14-network-contract-"+OS.get_cmdline_user_args()[1]
	game = load("res://world.tscn").instantiate()
	game.progress.path = base+"-"+role+".garden"
	game.local_character.path = base+"-"+role+".character"
	game.guest_character.path = base+"-"+role+".guest"
	root.add_child(game)
	if role == "host": await host()
	else: await guest()
	if is_instance_valid(game):
		World.offline(game)
		game.queue_free()
	await process_frame
	if not failed: print("PASS: explicit network contract ",role," mismatch refusal, current join, duplicate registration and owner binding")
	quit(1 if failed else 0)

func host() -> void:
	if not check(World.host(game) == OK,"ordinary host opens"): return
	mark("host")
	if not check(await until(func(): return marked("refused")),"guest observes incompatible contract refusal"): return
	if not check(await until(func(): return game.network_session.peers() == [1]),"incompatible peer leaves no authorized registry entry"): return
	check(game.players.size() == 1,"incompatible schema never registers a player")
	check(game.network_compatibility.failure_reason == Compatibility.UPDATE_MESSAGE,"host records the actual contract mismatch refusal")
	mark("match")
	if not check(await until(func(): return game.network_session.peers().size() == 2 and game.network_session.peers().all(func(peer): return game.network_session.ready(peer))),"matching explicit contract admits the guest"): return
	var peers: Array[int] = game.network_session.peers()
	var remote: int = peers[0] if peers[1] == 1 else peers[1]
	var actor: Dictionary = game.players[remote]
	var binding: int = game.network_session.binding(remote)
	var character: String = game.network_session.identity(remote)
	var before: String = JSON.stringify(actor.character)
	World.register(game,remote,"another-character",{"name":"forged"},game.progress.ContentIDs.manifest(),game.Network.PROTOCOL)
	check(game.network_session.binding(remote) == binding and game.network_session.identity(remote) == character
		and JSON.stringify(actor.character) == before,"replayed registration cannot replace an accepted character")
	check(Session.peer_for(actor) == remote and Session.ready_for(actor)
		and not game.network_session.connection_key(remote).is_empty(),"host actor uses its sole accepted peer binding")
	mark("accepted")
	if not check(await until(func(): return marked("guest-done")),"guest confirms owner recovery"): return
	if not check(await until(func(): return game.network_session.peers() == [1]),"normal disconnect retires the remote session binding"): return
	check(Session.peer_for(actor) == 0 and not Session.ready_for(actor),"detached actor cannot authorize later requests")
	mark("done")

func guest() -> void:
	if not check(await until(func(): return marked("host")),"host ready"): return
	var current := Contract.signature(game.get_script().get_script_method_list())
	game.network_compatibility.signature = "session-0/obsolete-contract"
	if not check(World.join(game,"127.0.0.1") == OK,"incompatible transport connection attempted"): return
	var failed_attempt: String = game.network_session.session_identity()
	var compatibility_refusal: String = game.Network.join_failure("compatibility","127.0.0.1",game.network_session.port(),false)
	if not check(await until(func(): return game.network_session.role() == "Solo" and game.status in [Compatibility.UPDATE_MESSAGE,compatibility_refusal]),"old contract is clearly refused before play"): return
	check(game.network_session.transport() == null,"refused connection is torn down")
	check(game.players.has(1) and game.network_session.ready(1),"refusal restores an authorized solo actor")
	mark("refused")
	if not check(await until(func(): return marked("match")),"host confirms no admission"): return
	game.network_compatibility.signature = current
	if not check(World.join(game,"127.0.0.1") == OK,"current contract connects"): return
	game.network_compatibility.finish_failed_check(failed_attempt)
	check(game.network_session.role() == "Connecting","a deferred failure from the prior connection cannot close this retry")
	if not check(await until(func(): return game.network_session.role() == "Guest" and game.guest_replication.has_details()),"matching contract receives reliable owner details"): return
	var peer: int = game.multiplayer.get_unique_id()
	check(game.network_session.accepted_identity() == game.guest_character.identity
		and game.network_session.permits_details(str(game.players[peer].get("session_binding",""))),
		"recovered owner details match this connection and character")
	if not check(await until(func(): return marked("accepted")),"host verifies duplicate registration"): return
	mark("guest-done")
	World.leave(game,"Contract test complete")
	check(game.network_session.role() == "Solo" and game.players.has(1) and game.network_session.ready(1),"leaving a guest session restores a valid solo binding")
	if not check(await until(func(): return marked("done")),"host confirms disconnect cleanup"): return
