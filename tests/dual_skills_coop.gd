extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")
var game: Node
var failed:=false
func check(value: bool,message: String):
	if not value: failed=true;printerr("FAIL dual-skill co-op: ",message)
func _initialize(): call_deferred("run")
func until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+16000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func run():
	var mode: String=OS.get_cmdline_user_args()[0]
	game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/dual_coop_"+mode+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	game.local_character.path=game.progress.path+".character"
	game.guest_character.path=game.progress.path+".guest"
	root.add_child(game)
	if mode=="host":
		var host: Dictionary=game.players[1]
		host.character.active_class=4
		game.restore_class_loadout(host)
		check(game.host_game()==OK,"server opens")
		print("DUAL HOST READY")
		if not await until(func(): return game.players.size()==2): check(false,"guest joins");quit(1);return
		var id: int=game.players.keys()[1]
		if not await until(func(): return game.players[id].profile_ready): check(false,"profile registers");quit(1);return
		var p: Dictionary=game.players[id]
		check(p.frame==1 and p.character.upgrades[1]==6,"replacement and augmentation choices travel with guest")
		game.encounter.clear_scouts()
		game.battlefield.configure(0,1)
		game.encounter.set_hp(-1, 100)
		game.tactics.position=Vector3.ZERO
		game.tactics.engaged=true
		game.tactics.winding_up=false
		game.tactics.ready_at=Time.get_ticks_msec()+60000
		ExpeditionCase.set_membership(game, host, true)
		host[PlayerVitals.STATE] = host[PlayerVitals.STATE].with_hp(4)
		host.pos=Vector3(.8,0,-1.5)
		ExpeditionCase.set_membership(game, p, true)
		p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(4)
		p.pos=Vector3(0,0,-1.5)
		if not await until(func(): return p[Cooldowns.STATE].deadline(Cooldowns.Q)>0 and p[Cooldowns.STATE].deadline(Cooldowns.R)>0):
			check(false,"both remote skill actions reach host");quit(1);return
		check(game.enemy_health()<100 and game.tactics.rooted_until>Time.get_ticks_msec(),"remote attack and root are authoritative")
		game.send_garden_action("class_skill")
		game.send_garden_action("class_skill_two")
		check(host[Cooldowns.STATE].deadline(Cooldowns.Q)>0 and host[Cooldowns.STATE].deadline(Cooldowns.R)>0,"host also has two independent cooldowns")
		check(PlayerVitals.current_hp(p)>=6 and p.guard_charges>=1,"Oracle heals and wards the guest")
		await create_timer(.8).timeout
	else:
		game.guest_character.data.active_class=1
		game.guest_character.data.xp[1]=int(game.Character.LEVEL_THRESHOLDS.back())
		game.guest_character.data.upgrades[1]=6
		game.guest_character.save_profile()
		check(game.join_game()==OK,"guest connects")
		var id: int=game.multiplayer.get_unique_id()
		if not await until(func(): return game.session=="Guest" and game.players.has(id) and ExpeditionCase.is_wild(game.players[id]) and game.client_details_key == str([game.participation.route(), game.participation.floor(), game.participation.seed()])):
			check(false,"expedition state arrives");quit(1);return
		game.players[id].facing=Vector3.BACK
		var first := InputEventKey.new()
		first.physical_keycode=KEY_Q
		first.pressed=true
		game._unhandled_key_input(first)
		var preview = preload("res://ability_aim.gd").active(game)
		check(preview != null and preview.slot == 0 and preview.drawing.get_surface_count() == 1 and game.players[id].skill_ready,"guest previews first skill without committing")
		first.pressed=false
		game._input(first)
		var second := InputEventKey.new()
		second.physical_keycode=KEY_R
		second.pressed=true
		game._unhandled_key_input(second)
		check(preview != null and preview.slot == 1 and preview.drawing.get_surface_count() == 1 and game.players[id].skill_two_ready,"guest previews second skill without committing")
		second.pressed=false
		game._input(second)
		if not await until(func(): return not game.client_details.is_empty() and not game.players[id].get("skill_ready",true) and not game.players[id].get("skill_two_ready",true)):
			check(false,"both cooldowns synchronize");quit(1);return
		game._process(.016)
		check(game.player_hud.state.skill_names==["Strangling Bloom","Spore Nova"],"HUD resolves portable replacement and augmentation")
		check(game.players[id].skill_cooldowns[0]>0 and game.players[id].skill_cooldowns[1]>0,"relative cooldowns arrive")
		check(await until(func(): return game.players[id].hp>=6),"host support healing arrives")
		var received_casts := func() -> bool:
			var shapes: Array = game.guest_combat_events(game.players[id]).filter(func(event):
				return event.kind == "ability" and int(event.combo) == 1).map(func(event):return event.shape)
			return "heal" in shapes and "ward" in shapes
		check(await until(received_casts),"both host casts reach the guest through combat events")
		check(game.guest_character.data.upgrades[1]==6,"class choices remain saved on guest")
	if not failed: print("PASS: dual-skill co-op "+mode)
	quit(1 if failed else 0)
