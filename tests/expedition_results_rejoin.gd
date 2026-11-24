extends "res://tests/guarded_expedition_coop.gd"
## Drop the transport during a run, fail the first host settlement, then
## readmit the same canonical guest from a fresh client world.
func run() -> void:
	host = OS.get_cmdline_user_args()[0] == "host"
	if not await start():
		quit(1)
		return
	if host: await host_run()
	else: await guest_run()
	if is_instance_valid(world):
		world.session_world.offline()
		world.release_slot()
		world.free()
	if not failed: print("PASS: bound expedition report after disconnect rollback and Garden readmission")
	quit(int(failed))

func host_run() -> void:
	check(world.session_world.host()==OK,"host listens")
	mark("hosting")
	if not await until(func():return world.players.size()==2 and world.players.values().all(func(p):return SessionCase.ready(p))):
		check(false,"initial admission")
		return
	var peer: int = world.players.keys().filter(func(id):return id!=1)[0]
	var identity := SessionCase.identity(world.players[peer])
	for actor: Dictionary in world.players.values():
		var tree = world.Classes.connected_tree(actor.frame)
		actor.character[tree.profile_key] = tree.state([tree.nodes[0].id])
		actor.pos = world.stage.gate_position()
	world.expedition_transitions.enter(1)
	mark("vote",str(world.participation.travel_epoch()))
	if not await until(func():return world.participation.contains(peer)):
		check(false,"guest entered Wilds")
		return
	world.set_meta(&"guarded_gameplay_test_fault",func(phase,_path):return ERR_FILE_CANT_WRITE if phase=="stage" else OK)
	mark("drop")
	if not await until(func():return not world.players.has(peer)):
		check(false,"host sees disconnection")
		return
	check(world.departure_settlement.blocks_admission(identity) and world.expedition_statistics.result_for(identity).is_empty(),"rollback holds readmission and hides tentative result")
	world.remove_meta(&"guarded_gameplay_test_fault")
	check(world.flush_kill_rewards(),"retry commits departure")
	var saved: Dictionary = world.expedition_statistics.result_for(identity)
	check(saved.get("outcome")=="Disconnected" and saved.players.size()==2 and world.participation.contains(1),"one frozen result while host continues")
	world.expedition_transitions.abandon(1)
	check(world.expedition_statistics.result_for(identity)==saved,"host's later termination cannot alter the guest's result")
	mark("readmit")
	check(await until(func():return marked("viewed")),"reconnected guest read own report")

func guest_run() -> void:
	check(world.session_world.join("127.0.0.1")==OK,"guest connects")
	if not await until(func():return world.network_session.role()=="Guest" and marked("vote")):
		check(false,"guest sees vote")
		return
	world.send_garden_action("travel_ready:"+read("vote"))
	if not await until(func():return marked("drop")):
		check(false,"host ready for disconnection")
		return
	var old_binding: String = world.network_session.accepted_connection_key()
	world.session_world.offline()
	world.release_slot()
	world.free()
	if not await until(func():return marked("readmit")):
		check(false,"host opens Garden")
		return
	if not await start():
		check(false,"fresh client opens same disposable character")
		return
	check(world.session_world.join("127.0.0.1")==OK,"returning guest connects")
	if not await until(func():return not world.ui.visible_expedition_result().is_empty()):
		check(false,"guest receives retained result")
		return
	var saved: Dictionary = world.ui.visible_expedition_result()
	check(saved.outcome=="Disconnected" and saved.players[saved.personal_index].name=="Guest","identity-bound report for returning character")
	check(old_binding!=world.network_session.accepted_connection_key(),"new transport binding")
	world.ui.close_panels()
	var delayed := saved.duplicate(true)
	delayed.run += 1
	world.receive_expedition_result(old_binding,world.guest_character.identity,delayed.run,delayed)
	world.receive_expedition_result(world.network_session.accepted_connection_key(),"another-character",delayed.run,delayed)
	check(world.ui.visible_expedition_result().is_empty(),"stale connection cannot reopen a result")
	mark("viewed")
