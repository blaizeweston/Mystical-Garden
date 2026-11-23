extends SceneTree
## Independent host/guest processes use real registration, input RPC and snapshots.
const Actions=preload("res://player_weapon_actions.gd")
const Session=preload("res://network_session.gd")
const Expedition=preload("res://tests/support/expedition_case.gd")
const Field=preload("res://field_traveller.gd")
var game: Node
var role: String
var base: String
var failed:=false
var cast_clips: Array[String]=[]

func check(ok: bool,message: String) -> void:
	if not ok:failed=true;printerr("FAIL Staff co-op ",role,": ",message)
func mark(key: String) -> void:
	var file:=FileAccess.open(base+key,FileAccess.WRITE);file.store_string("ok")
func marked(key: String) -> bool:return FileAccess.file_exists(base+key)
func until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+16000
	while Time.get_ticks_msec()<deadline and not predicate.call():await process_frame
	return predicate.call()
func _initialize() -> void:call_deferred("run")

func record_casts() -> void:
	for received in game.guest_replication.received_events():
		var event: Dictionary=received.event
		if event.kind=="projectile" and event.get("form","")=="staff":
			if not cast_clips.has(event.clip):cast_clips.append(event.clip)
			check(event.pattern=="projectile" and event.has("weapon_release"),"reliable event carries staff-tip release facts")
			check(game.stage.weapon_release_point(event).is_finite(),"guest can resolve source tip")

func run() -> void:
	role=OS.get_cmdline_user_args()[0]
	base="res://.godot/staff-net-"+OS.get_cmdline_user_args()[1]
	game=load("res://world.tscn").instantiate()
	game.progress.path=base+role;game.local_character.path=base+role+".character";game.guest_character.path=base+role+".guest"
	root.add_child(game)
	if role=="host":await host_run()
	else:await guest_run()
	if game.network_session.transport()!=null:game.session_world.leave("Staff animation fixture")
	check(game.network_session.transport()==null,"transport released")
	game.queue_free();await process_frame
	if not failed:print("PASS: Staff co-op ",role," host-selected forward/side, replicated grips/tip launches, unchanged contact, return to ready and disconnect")
	quit(1 if failed else 0)

func host_run() -> void:
	check(game.session_world.host()==OK,"host opens")
	if not await until(func():return game.players.size()==2 and game.players.values().all(func(p):return Session.ready_for(p))):check(false,"registration");return
	var peer: int=game.players.keys().filter(func(id):return id!=1)[0]
	var player: Dictionary=game.players[peer]
	Expedition.set_membership(game,player,true)
	player.frame=1;player.weapon_kind=0;player.weapon=0;player.secondary=0;player.catalyst=0
	player.pos=Vector3.ZERO;player[Actions.STATE]=Actions.State.new()
	game.encounter.set_hp(-1,1000);game.encounter.clear_scouts()
	game.tactics.position=Vector3(0,0,3.0);game.tactics.ready_at=Time.get_ticks_msec()+60000;game.tactics.winding_up=false
	mark("ready")
	check(await until(func():return marked("checked")),"guest verifies both actions")
	check(game.enemy_health()<1000,"host resolves real weapon damage")
	check(player[Actions.STATE].basic_step()==2,"one admitted action per requested cast, no duplicate")
	mark("done")
	check(await until(func():return game.players.size()==1),"guest disconnects cleanly")

func guest_run() -> void:
	game.guest_character.data.appearance=preload("res://character_appearance.gd").DEFAULT.duplicate()
	game.guest_character.data.appearance[5]=1
	game.guest_character.save_profile()
	check(game.session_world.join()==OK,"guest joins")
	var peer:=game.multiplayer.get_unique_id()
	if not await until(func():return marked("ready") and game.network_session.role()=="Guest" and game.guest_replication.has_details() and Expedition.is_wild(game.players.get(peer,{}))):check(false,"authoritative action-ready guest");return
	check(not game.players[peer].has(Actions.STATE),"guest receives projection, no second host timeline")
	var clips: Array[String]=[]
	var returns: Array[String]=[]
	for clip in ["Attack_staff_forward","Attack_staff_side"]:
		var accepted:=false;var rendered:=false;var gripped:=false
		var deadline:=Time.get_ticks_msec()+6000;var next_send:=0
		while Time.get_ticks_msec()<deadline and not (accepted and rendered and gripped):
			record_casts()
			var now:=Time.get_ticks_msec()
			if now>=next_send:next_send=now+50;game.submit_combat.rpc_id(1,Vector2(0,1),true)
			var projection: Dictionary=game.players[peer].get("attack_anim",{})
			accepted=accepted or (projection.get("active",false) and projection.get("clip","")==clip)
			var actor: Dictionary=game.stage.avatar_models.get(peer,{})
			if not actor.is_empty() and str(actor.field_rig.player.current_animation)==clip:
				rendered=true
				var weapon: Node3D=actor.visual_weapon
				gripped=weapon.to_global(weapon.get_meta("handle")).distance_to(Field.hand(actor,false))<.012 and weapon.to_global(weapon.get_meta("support_grip")).distance_to(Field.hand(actor,true))<.012
			await process_frame
		game.submit_combat.rpc_id(1,Vector2(0,1),false)
		check(accepted and rendered and gripped,"replicated reviewed clip and two-hand attachment "+clip)
		if accepted:clips.append(clip)
		var recovery: String="Recover_staff_side" if clip=="Attack_staff_side" else "Recover_staff_forward"
		var ready: String="Ready_staff_authored"
		var saw_recovery:=false;var saw_ready:=false
		deadline=Time.get_ticks_msec()+6000
		while Time.get_ticks_msec()<deadline and not saw_ready:
			record_casts()
			var actor: Dictionary=game.stage.avatar_models.get(peer,{})
			if not actor.is_empty():
				var current:=str(actor.field_rig.player.current_animation)
				saw_recovery=saw_recovery or current==recovery
				saw_ready=current==ready
			await process_frame
		check(saw_recovery and saw_ready,"guest plays return and rests after single "+clip)
		if saw_recovery:returns.append(recovery)
	check(clips==["Attack_staff_forward","Attack_staff_side"] and returns.size()==2,"host alternation and both recoveries")
	check(cast_clips==["Attack_staff_forward","Attack_staff_side"],"both authoritative staff-tip events arrive in order")
	mark("checked");check(await until(func():return marked("done")),"host confirms damage")
