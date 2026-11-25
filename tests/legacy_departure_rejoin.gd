extends "res://tests/expedition_results_rejoin.gd"
## Exercise the ordinary disconnect writer with a real undeletable cleanup
## file. The guarded control and this fixture share the reconnecting client.

func start() -> bool:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.godot/vd/"):
		check(false,"disposable data root required")
		return false
	if not host and not await until(func():return marked("hosting")): return false
	world = load("res://world.tscn").instantiate()
	var prefix := "user://release-fixtures/" + ("host" if host else "client")
	world.progress.path = prefix + ".garden"
	world.local_character.path = prefix + ".character"
	world.guest_character.path = prefix + ".guest"
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	if not host and not FileAccess.file_exists(world.guest_character.path):
		world.guest_character.data.name = "Guest"
		check(world.guest_character.save_profile()==OK,"initialize guest profile")
	return not failed

func host_run() -> void:
	check(world.session_world.host()==OK,"ordinary host listens")
	mark("hosting")
	if not await until(func():return world.players.size()==2 and world.players.values().all(func(p):return SessionCase.ready(p))):
		check(false,"initial admission"); return
	var peer: int = world.players.keys().filter(func(id):return id!=1)[0]
	var identity := SessionCase.identity(world.players[peer])
	for actor: Dictionary in world.players.values():
		var tree = world.Classes.connected_tree(actor.frame)
		actor.character[tree.profile_key] = tree.state([tree.nodes[0].id])
		actor.pos = world.stage.gate_position()
	world.expedition_transitions.enter(1)
	mark("vote",str(world.participation.travel_epoch()))
	if not await until(func():return world.participation.contains(peer)):
		check(false,"guest entered Wilds"); return
	var seeds_before: int = world.seed_reserve(world.players[peer]).unknown.size()
	world.players[peer].safe_items = [{"item":"unidentified_seed","quantity":1,"seeds":[0]}]
	var rules: Dictionary = world.Director.config()
	var chance: float = rules.trophy_chance
	var cap: float = rules.trophy_cap
	rules.trophy_chance = 1.0
	rules.trophy_cap = 1.0
	world._queue_monster_reward("ordinary-disconnect",0,0,Vector3.ZERO,false)
	rules.trophy_chance = chance
	rules.trophy_cap = cap
	var receipt: Dictionary = world.monster_rewards.pending_receipts()[0]
	var host_award: Dictionary = receipt.rewards.filter(func(award): return award.id==1)[0]
	mark("drop")
	if not await until(func():return not world.players.has(peer)):
		check(false,"guest disconnected"); return
	check(world.parked_explorers.has(identity) and world.expedition_statistics.result_for(identity).is_empty(),"disconnected seat held without finalization")
	check(world.wallet_for(world.players[1]).earned_sparks()==host_award.essence and world.monster_rewards.status(receipt.key)==world.MonsterRewards.Phase.COMMITTED,"pending kill credited once")
	var lock := FileAccess.open(world.progress.path+".recovery",FileAccess.WRITE)
	check(lock != null,"cleanup file open across settlement")
	world.expedition_transitions.abandon(1)
	var report: Dictionary = world.expedition_statistics.result_for(identity)
	check(report.get("outcome")=="Disconnected" and not world.participation.active() and world.parked_explorers.is_empty(),"terminal save settles the parked character")
	check(not world.persistence_session.can_write(),"cleanup pending holds new admissions")
	check(world.progress.reserve(identity).unknown.size()==seeds_before+1,"one protected seed banked to the departing character")
	var garden := FileAccess.get_sha256(world.progress.path)
	var profile: Dictionary = world.progress.character_records.get(identity,{}).get("profile",{})
	check(not profile.is_empty() and profile.xp[0]>0 and profile.monsters[0]==1,"absent guest receives pre-disconnect kill")
	check(not world.recover_departure_cleanup() and FileAccess.get_sha256(world.progress.path)==garden,"held retry cannot reapply protected cargo")
	lock.close()
	world._handle_ui_request("save",{})
	check(world.persistence_session.can_write(),"cleanup released write hold")
	check(FileAccess.get_sha256(world.progress.path)==garden and world.progress.character_records[identity].profile==profile and world.expedition_statistics.result_for(identity)==report,"cleanup retains exactly one result")
	mark("readmit")
	check(await until(func():return marked("viewed")),"readmitted guest receives their report")

func run() -> void:
	host = OS.get_cmdline_user_args()[0]=="host"
	if await start():
		if host: await host_run()
		else: await guest_run()
	if is_instance_valid(world):
		world.session_world.offline()
		world.free()
	if not failed: print("PASS: ordinary committed disconnect, cleanup and bound Garden readmission")
	quit(int(failed))
