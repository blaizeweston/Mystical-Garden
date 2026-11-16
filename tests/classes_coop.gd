extends SceneTree
const Aim=preload("res://ability_aim.gd")
var game: Node
var failed:=false
func check(value: bool,message: String):
	if not value: failed=true;printerr("FAIL class co-op: ",message)
func _initialize(): call_deferred("run")
func until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+18000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func run():
	var mode: String=OS.get_cmdline_user_args()[0]
	game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/class_coop_"+mode+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	game.local_character.path=game.progress.path+".character"
	game.guest_character.path=game.progress.path+".guest"
	root.add_child(game)
	if mode=="host":
		check(game.host_game()==OK,"host opens")
		print("CLASS HOST READY")
		if not await until(func(): return game.players.size()==2): check(false,"guest joins");quit(1);return
		var id: int=game.players.keys()[1]
		if not await until(func(): return game.players[id].profile_ready): check(false,"profile arrives");quit(1);return
		var p: Dictionary=game.players[id]
		check(p.frame==4 and p.weapon_kind==2 and p.character.upgrades[4]==1,"portable active class, weapon and choices arrive")
		p.pos=game.Stage.HEART
		var reserve: Dictionary=game.seed_reserve(p)
		for part in [1,2,3,18]: reserve.parts[part]=1
		for kind in 3: game.progress.discover(kind)
		if not await until(func(): return p.frame==2 and p.character.upgrades[2]==(1<<13)): check(false,"guest learns at Heart");quit(1);return
		p.pos=game.Stage.GATE
		if not await until(func(): return p.cargo_plan[18]==1 and p.prepared_catalyst==3):
			check(false,"guest preparation actions arrive");quit(1);return
		check(p.frame==2 and p.weapon_kind==2 and p.character.upgrades[2]==(1<<13),"host validates class, basic weapon and learned choice")
		p.pos=game.Stage.GATE
		game.players[1].pos=game.Stage.GATE
		game.enter_wilds(1,game.players[1])
		game.enter_wilds(id,p)
		check(p.wild and p.carried_parts[18]==1 and p.graft_part==0 and reserve.parts[18]==0,"packed trophy enters as cargo")
		check([p.weapon,p.secondary,p.catalyst]==[1,2,3] and reserve.parts[1]==0,"three materials crafted authoritatively")
		game.encounter_number=game.GRAFT_ROOM
		game.depth=4
		# This fixture checks class/loadout RPCs, not randomized elite evasion.
		game.map_seed=1
		game.reset_encounter()
		game.scouts.clear()
		game.enemy_kind=0
		game.enemy_mutations=0
		game.enemy_growth=0
		game.enemy_winding_up=false
		game.rooted_until=Time.get_ticks_msec()+60000
		game.enemy_hp=100
		p.pos=game.battlefield.graft
		p.character.monsters[1]=100
		game.enemy_pos=p.pos+Vector3(0,0,1)
		check(game.battlefield.clear_line(p.pos,game.enemy_pos),"fixture has a clear attack line")
		game.enemy_ready_at=Time.get_ticks_msec()+60000
		game.rng.seed=2
		if not await until(func(): return p.graft_part==18):
			check(false,"guest monster graft succeeds");quit(1);return
		check(p.secondary==2 and p.catalyst==3 and p.carried_parts[18]==0,"fourth slot preserves plant slots")
		check(await until(func(): return game.enemy_hp<100),"guest weapon strike reaches host")
		check(await until(func():return game.trait_events.any(func(e):return e.kind=="decoy" and e.owner==id)),"guest release creates the host-owned snare")
		await create_timer(.7).timeout
		check(p.character.upgrades[2]==(1<<13),"class upgrades cannot be changed during expedition")
	else:
		game.guest_character.data.active_class=4
		game.guest_character.data.xp[4]=200
		game.guest_character.data.xp[2]=200
		game.guest_character.data.upgrades[4]=1
		game.guest_character.data.loadouts[4].weapon=2
		game.guest_character.save_profile()
		check(game.join_game()==OK,"guest connects")
		if not await until(func():
			var id: int=game.multiplayer.get_unique_id()
			return game.session=="Guest" and game.players.has(id) and game.players[id].get("stored_parts",[]).size()==game.Parts.DEFINITIONS.size() and game.players[id].stored_parts[18]==1):
			check(false,"extended stash snapshot arrives");quit(1);return
		var id: int=game.multiplayer.get_unique_id()
		for action in ["class_2","learn_2_13"]:
			game.send_garden_action(action)
		if not await until(func(): return game.players[id].pos.distance_to(game.Stage.GATE)<.2): check(false,"guest moves to Gate for preparation");quit(1);return
		for action in ["loadweapon_2","loadpart_0_1","loadpart_1_2","loadpart_2_3","pack_18"]: game.send_garden_action(action)
		if not await until(func(): return game.players[id].wild and game.encounter_number==game.GRAFT_ROOM and game.players[id].get("catalyst",0)==3 and game.client_details_key==str([game.destination,game.encounter_number,game.map_seed])):
			check(false,"crafted expedition snapshot arrives");quit(1);return
		check(game.players[id].frame==2 and game.players[id].weapon_kind==2 and game.players[id].catalyst==3 and game.players[id].graft_part==0,"class and all plant slots synchronize")
		game.send_garden_action("graft_install_18")
		if not await until(func(): return game.players[id].get("graft_part",0)==18):
			check(false,"monster graft snapshot arrives");quit(1);return
		check(game.players[id].weapon_stats.recovery>=650,"grafted monster effects synchronize")
		game.send_garden_action("learn_2_2")
		game.send_action(true)
		game.update_projectiles(Time.get_ticks_msec()+1000)
		check(await until(func(): return game.enemy_hp<100),"guest sees strike result")
		check(game.guest_character.data.upgrades[2]==(1<<13),"class choices saved to guest character")
		var local: Dictionary=game.players[id]
		var preview:=Aim.footprint(game,local,game.stage.visual_field,0,Vector3.BACK,1.0)
		check(preview.valid and preview.shapes.any(func(s):return s.kind=="area"),"guest sees aimed snare footprint")
		game.send_garden_action(Aim.request(game,local,0,Vector2.DOWN,1.0))
		check(await until(func():return game.received_combat_events.any(func(e):return e.event.kind=="subclass_release" and e.event.shape=="snare" and e.event.combo==id)),"guest receives the authoritative snare animation")
		game.toggle_overlay(game.loadout_menu)
		game.loadout_view.refresh()
	if not failed: print("PASS: class co-op "+mode)
	quit(1 if failed else 0)
