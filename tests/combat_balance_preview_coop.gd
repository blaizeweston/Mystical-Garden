extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Preview = preload("res://combat_balance_preview.gd")
const Orb = preload("res://health_orb.gd")
const Aim = preload("res://ability_aim.gd")
const Core = preload("res://core_combat.gd")

var game: Node
var role: String
var base: String
var failed := false


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL combat balance co-op ", role, ": ", detail)


func mark(key: String, value: String="ok") -> void:
	var file:=FileAccess.open(base+"-"+key,FileAccess.WRITE)
	file.store_string(value)


func reported_hp(key: String) -> int:
	return int(FileAccess.get_file_as_string(base+"-"+key)) if marked(key) else -1


func marked(key: String) -> bool:
	return FileAccess.file_exists(base+"-"+key)


func until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+12000
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await process_frame
	return predicate.call()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args:=OS.get_cmdline_user_args()
	role=args[0]
	base="res://.godot/combat-preview-net-"+args[1]
	Preview.enabled=role=="host"
	Preview.playtest=true
	game=load("res://world.tscn").instantiate()
	game.progress.path=base+"-"+role+".cfg"
	game.local_character.path=base+"-"+role+".character"
	game.guest_character.path=base+"-"+role+".guest"
	root.add_child(game)
	if role=="host":
		await host()
	else:
		await guest()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: combat balance ",role," scale handshake, exact damage and healing, party orbs, revival, subclass casting, Core healing and rolled hit feedback")
	quit(1 if failed else 0)


func host() -> void:
	check(game.host_game()==OK,"host starts")
	if not await until(func():return marked("rejected")):
		check(false,"guest proves the mixed-mode rejection")
		return
	check(game.players.size()==1,"mixed scale never registers a peer")
	if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):
		check(false,"matching preview guest registers")
		return
	var id: int=game.players.keys().filter(func(peer):return peer!=1)[0]
	var local: Dictionary=game.players[1]
	var remote: Dictionary=game.players[id]
	for player in [local,remote]:
		ExpeditionCase.set_membership(game, player, true)
		player.pos=Vector3.ZERO
		player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(100)
	ExpeditionCase.set_world(game, {"encounter_number": 10})
	ExpeditionCase.set_world(game, {"destination": 1})
	ExpeditionCase.set_world(game, {"depth": 4})
	ExpeditionCase.set_world(game, {"map_seed": 91681})
	game.reset_encounter()
	game.encounter.clear_scouts()
	game.tactics.stagger_until=Time.get_ticks_msec()+45000
	game.enemy_mutations=0
	game.tactics.position=Vector3(0,0,1.4)
	check(game.tactics.boss_kind==game.Bosses.Lair.Routes.ORCHARD and game.enemy_health()==960,"two-player Orchard scales with party size")
	if not await until(func():return marked("ready")):
		check(false,"guest sees the Orchard and preview state")
		return
	remote[PlayerVitals.STATE] = remote[PlayerVitals.STATE].with_hp(20)
	remote.renewal_until=Time.get_ticks_msec()+4000
	remote.renewal_tick=Time.get_ticks_msec()
	game.update_support_effects(Time.get_ticks_msec())
	remote.renewal_until=0
	check(int(PlayerVitals.current_hp(remote))-20 in range(3,6),"host rolls Renewal in the displayed band")
	mark("renewal-result",str(int(PlayerVitals.current_hp(remote))))
	check(await until(func():return marked("healed")),"guest sees the exact host roll")
	IncomingPlayerHit.apply_health_loss(game, id, PlayerLifecycle.generation(remote), int(PlayerVitals.current_hp(remote)))
	check(await until(func():return marked("fallen")),"guest sees the downed state")
	check(game.Life.revive(game,1,id),"host revives guest")
	check(await until(func():return marked("revived")),"guest sees the reduced capacity")
	local[PlayerVitals.STATE] = local[PlayerVitals.STATE].with_hp(20)
	remote[PlayerVitals.STATE] = remote[PlayerVitals.STATE].with_hp(25)
	remote.run_upgrades["class_4_0"]=1
	mark("class-ready")
	check(await until(func():return int(PlayerVitals.current_hp(remote))-25 in range(18,23)),"guest Oracle casts an 18–22 HP party heal on the host")
	var class_gain:=int(PlayerVitals.current_hp(remote))-25
	check(int(PlayerVitals.current_hp(local))-20==class_gain,"the direct heal roll is shared by both players")
	mark("class-result",str(class_gain))
	check(await until(func():return marked("class-heal")),"guest sees the same class heal and cooldown")
	remote.weapon=game.Parts.index_of("plant:tide_lily")
	remote.catalyst=game.Parts.index_of("plant:dewcap")
	remote.run_upgrades["core_riptide"]=1
	remote.cast_until=0
	mark("wave-ready")
	check(await until(func():return int(PlayerVitals.current_hp(remote))-25-class_gain in range(18,23)),"guest Riptide restores the catalyst-adjusted 18–22 HP on its return")
	var wave_gain:=int(PlayerVitals.current_hp(remote))-25-class_gain
	check(int(PlayerVitals.current_hp(local))-20-class_gain==wave_gain,"the returning wave shares the same roll")
	mark("wave-result",str(wave_gain))
	check(await until(func():return marked("wave-heal")),"guest sees the authoritative Core heal")
	var overlap_hp:=int(PlayerVitals.current_hp(remote))
	game.Life.Sustain.restore(game,remote,6,"fixture")
	IncomingPlayerHit.apply_health_loss(game, id, PlayerLifecycle.generation(remote), 6)
	check(int(PlayerVitals.current_hp(remote))==overlap_hp,"heal and damage in one host step cancel in the pool")
	mark("overlap",str(overlap_hp))
	check(await until(func():return marked("overlap-seen")),"guest displays both actual changes")
	var boss_hit: float=game.Director.Balance.boss_hit(game,game.Enemies.get_kind(game.tactics.boss_kind),"orchard_march")
	IncomingPlayerHit.resolve_world(game, id, PlayerLifecycle.generation(remote), Time.get_ticks_msec(), boss_hit)
	check(int(PlayerVitals.current_hp(remote))==25+class_gain+wave_gain-26,"Orchard march applies a native 26 HP hit")
	mark("boss-hit",str(int(PlayerVitals.current_hp(remote))))
	check(await until(func():return marked("boss-hit-seen")),"guest confirms exact boss damage")
	local.frame=2
	local.weapon_kind=1
	local.graft_part=game.Parts.monster_part(4)
	local.aim_direction=Vector3.BACK
	local.facing=Vector3.BACK
	local.mouse_aim=true
	local.strike_at=0
	game.strike_enemy(1,local,local.pos)
	check(await until(func():return marked("strike")),"guest renders authoritative rolled contact")
	mark("finished")
	check(await until(func():return game.players.size()==1),"guest exits cleanly")


func guest() -> void:
	game.guest_character.data.active_class=4
	game.guest_character.data.upgrades[4]=1<<14
	game.guest_character.save_profile()
	check(game.join_game()==OK,"guest starts mixed-mode attempt")
	if not await until(func():return game.session=="Solo" and game.status.contains("combat balance mode")):
		check(false,"mixed HP scale receives a specific compatibility message")
		return
	mark("rejected")
	Preview.enabled=true
	check(game.join_game()==OK,"guest retries with matching preview")
	if not await until(func():return game.session=="Guest" and game.tactics.boss_kind==20 and int(game.players.get(game.multiplayer.get_unique_id(),{}).get("max_hp",0))==100):
		check(false,"guest receives Orchard state in preview units")
		return
	var id: int=game.multiplayer.get_unique_id()
	check(game.encounter_health()==960,"guest receives matching Orchard maximum")
	mark("ready")
	check(await until(func():return reported_hp("renewal-result")==int(game.players[id].hp)),"Renewal arrives with the exact host roll")
	mark("healed")
	check(await until(func():return game.players[id].fallen and game.players[id].hp==0),"downed state arrives")
	mark("fallen")
	check(await until(func():return game.players[id].hp==80 and game.players[id].lost_health==20),"revival and cap arrive together")
	check(Orb.fractions(game.players[id].hp,game.players[id].max_hp,game.players[id].lost_health).is_equal_approx(Vector2(.8,.8)),"guest orb shows lost capacity")
	check(await until(func():return game.player_hud.party_panel.rows.any(func(row):return row.id==1 and row.max_hp==100)),"small orb has the host's exact state")
	mark("revived")
	var local: Dictionary=game.players[id]
	check(await until(func():return marked("class-ready") and game.player_hud.skill_hover[0].tooltip_text.contains("Heal living allies: 18–22 HP")),"guest tooltip reflects synchronized class healing")
	game.send_garden_action(Aim.request(game,local,0,Vector2.UP,0.0))
	check(await until(func():
		var amount:=reported_hp("class-result")
		return amount in range(18,23) and game.players[id].hp==25+amount and game.players[1].hp==20+amount and not game.players[id].skill_ready
	),"guest sees the exact host roll for both targets and the used skill")
	var class_gain:=reported_hp("class-result")
	mark("class-heal")
	check(await until(func():return marked("wave-ready") and game.player_hud.skill_hover[2].tooltip_text.contains("Returning wave · Restores 18–22 HP")),"guest sees the resolved Core return-heal tooltip")
	game.send_garden_action(Core.request(game,local,Vector2.UP,2.4))
	check(await until(func():
		var amount:=reported_hp("wave-result")
		return amount in range(18,23) and game.players[id].hp==25+class_gain+amount and game.players[1].hp==20+class_gain+amount
	),"guest sees the exact host roll for both wave targets")
	mark("wave-heal")
	check(await until(func():
		if not marked("overlap") or int(game.players[id].hp)!=reported_hp("overlap"):return false
		var texts: Array=game.combat_visuals.feedback.labels.map(func(label):return label.node.text)
		return texts.count("+6")==1 and texts.count("−6")==1
	),"coincident heal and hit are each displayed once at identical final HP")
	mark("overlap-seen")
	check(await until(func():return marked("boss-hit") and int(game.players[id].hp)==reported_hp("boss-hit") and int(game.players[id].damage_amount)==26),"scaled boss damage replicates as native HP")
	mark("boss-hit-seen")
	check(await until(func():return game.combat_visuals.active.values().any(func(effect):
		var event: Dictionary=effect.event
		return event.kind=="impact" and event.shape=="hit" and event.amount>=26 and event.amount<=34
	)),"visible damage uses the host's roll")
	mark("strike")
	check(await until(func():return marked("finished")),"host finishes preview fixture")
	game.leave_game("Preview test complete")
