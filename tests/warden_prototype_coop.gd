extends SceneTree

const Warden = preload("res://warden_tree.gd")
const Combat = preload("res://warden_combat.gd")
const Aim = preload("res://ability_aim.gd")
const CARD := "rootkeeper_second_growth"
const MASK := (1 << 13) | (1 << 16) | (1 << 18)

var game: Node
var base: String
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Warden prototype co-op: ",message)


func mark(key: String) -> void:
	var file := FileAccess.open(base+key,FileAccess.WRITE)
	file.store_string("ok")


func marked(key: String) -> bool:
	return FileAccess.file_exists(base+key)


func until(predicate: Callable, duration: int = 10000) -> bool:
	var expires := Time.get_ticks_msec()+duration
	while not predicate.call() and Time.get_ticks_msec()<expires:
		await process_frame
	return predicate.call()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	base="res://.godot/warden-proto-net-"+args[1]
	game=load("res://world.tscn").instantiate()
	game.progress.path=base+args[0]+".cfg"
	game.local_character.path=game.progress.path+".character"
	game.guest_character.path=game.progress.path+".guest"
	root.add_child(game)
	if args[0]=="host":
		await host()
	else:
		await guest()
	if game.session!="Solo":
		game.leave_game("Warden prototype complete")
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: Warden prototype co-op "+args[0]+" branched profile, real checkpoint purchase, anchor preview and released Quake")
	quit(1 if failed else 0)


func host() -> void:
	check(game.host_game()==OK,"host starts")
	if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return p.profile_ready)):
		check(false,"guest profile arrives")
		return
	var id: int=game.players.keys().filter(func(peer):return peer!=1)[0]
	var player: Dictionary=game.players[id]
	check(player.character.upgrades[0]==MASK and Warden.focus(player.character)=="rootkeeper","guest brings its learned hybrid")
	player.pos=game.Stage.GATE
	game.show_gate_preparation(id)
	if not await until(func():return marked("class-spent")):
		check(false,"guest learns a class node at the Gate")
		return
	check(player.character.upgrades[1]==1<<Warden.OFFSET and player.frame==0,"host spends the guest's point on the inspected class")
	game.encounter.set_hp(-1, 0)
	game.tactics.position=Vector3(0,0,-1.5)
	game.battlefield.configure(game.destination,game.depth,game.map_seed)
	game.battlefield.barriers.clear()
	game.encounter.clear_scouts()
	game.encounter_number=3
	game.encounter_rewarded=true
	game.checkpoint_pending=true
	for member in game.players.values():
		member.wild=true
		member.pos=game.battlefield.advance
	player.weapon=game.Parts.index_of("plant:thorn_bloom")
	player[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(10000, game.wallet_for(player).spent_essence())
	game.present_checkpoint_cards(id)
	if not await until(func():return player.run_upgrades.get(CARD,0)==1 and marked("purchase")):
		check(false,"guest buys the branch card")
		return
	game.checkpoint_pending=false
	game.combat_epoch+=1
	game.encounter_number=4
	game.encounter.set_hp(-1, 100)
	game.tactics.stagger_until=Time.get_ticks_msec()+60000
	player.pos=Vector3.ZERO
	game.players[1].pos=Vector3(0,0,2.0)
	mark("arena")
	if not await until(func():return not Combat.anchor(game,player,Time.get_ticks_msec()).is_empty()):
		check(false,"guest release creates a real anchor")
		return
	game.apply_enemy_hit(id,player,Time.get_ticks_msec(),1,0,game.tactics.position)
	player.pos=Vector3(0,0,4.6)
	mark("move")
	if not await until(func():return game.enemy_health()<100):
		check(false,"guest Quake hits at the anchor beyond personal reach")
		return
	check(player.warden_anchor.uses==1 and Combat.prepared_until(game,player,Time.get_ticks_msec())==0,"purchase preserves anchor once and confirmed Quake consumes preparation")
	check(game.tactics.rooted_until>Time.get_ticks_msec(),"offensive bridge roots the hit from the neutral anchor")
	mark("done")
	check(await until(func():return marked("observed")),"guest receives root feedback")


func guest() -> void:
	game.guest_character.data.xp[0]=350
	game.guest_character.data.upgrades[0]=MASK
	game.guest_character.save_profile()
	check(game.join_game()==OK,"guest connects")
	var id:=game.multiplayer.get_unique_id()
	if not await until(func():return game.loadout_menu.visible and game.at_weapon_gate(game.players.get(id,{}))):
		check(false,"guest crafting menu arrives at the Gate")
		return
	game.progression_view.open_from_crafting()
	game.progression_view.class_pick.select(1)
	game.progression_view.class_pick.item_selected.emit(1)
	game.progression_view.select_node("class_1_%d"%Warden.OFFSET)
	check(not game.progression_view.learn_button.disabled,"the guest can learn in the Class tree")
	game.progression_view.learn_button.pressed.emit()
	if not await until(func():return game.guest_character.data.upgrades[1]==1<<Warden.OFFSET and game.progression_view.learn_button.disabled):
		check(false,"guest receives and displays the learned node after one click")
		return
	game.progression_view.close_button.pressed.emit()
	check(game.loadout_menu.visible,"the guest returns to crafting")
	mark("class-spent")
	if not await until(func():return game.checkpoint_menu.visible and game.checkpoint_cards.get_child_count()>=3):
		check(false,"checkpoint cards arrive")
		return
	var cards: Array=game.checkpoint_cards.find_children("*","Button",true,false)
	await process_frame
	check(cards[0].has_node("ReachingRoots"),"dynamically created checkpoint cards use the menu highlight")
	cards[0].pressed.emit()
	if not await until(func():return game.players.get(id,{}).get("run_upgrades",{}).get(CARD,0)==1):
		check(false,"owner receives the purchased class card")
		return
	mark("purchase")
	if not await until(func():return marked("arena") and game.encounter_number==4 and game.enemy_health()>0 and not game.client_details.is_empty()):
		check(false,"combat state arrives")
		return
	var player: Dictionary=game.players[id]
	game.send_garden_action(Aim.request(game,player,0,Vector2.UP))
	if not await until(func():return marked("move") and game.players[id].get("warden_anchor_point",Vector3.INF)==Vector3.ZERO and game.players[id].pos.z>4.3,3500):
		check(false,"guest sees owner anchor after moving")
		return
	player=game.players[id]
	var preview:=Aim.footprint(game,player,game.stage.visual_field,1,Vector3.FORWARD,4.6)
	check(preview.shapes.any(func(s):return s.kind=="area" and s.at==Vector3.ZERO),"guest preview highlights the host's anchor")
	check(game.player_hud.state.skill_tooltips[0].contains("Second Growth"),"HUD describes the bought skill modifier")
	game.send_garden_action(Aim.request(game,player,1,Vector2.UP))
	check(await until(func():return marked("done") and game.combat_visuals.statuses.active.values().any(func(item):return item.event.shape=="rooted" and item.event.combo==-1)),"guest sees the affected monster's Rooted status")
	mark("observed")
