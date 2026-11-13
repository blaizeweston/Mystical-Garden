extends SceneTree

const Escape = preload("res://thief_escape.gd")
const Elite = preload("res://elite_enemy.gd")
const Support = preload("res://enemy_support.gd")
const Field = preload("res://battlefield.gd")
var game: Node
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL thief escape: ",message)


func trophy(at: Vector3) -> Dictionary:
	return {"id":"owned-trophy","owner":1,"stack":{"item":game.Items.part_id(game.Parts.monster_part(0)),"quantity":2},
		"position":[at.x,0,at.z]}


func start_theft(actor: Dictionary, now: int) -> int:
	actor.ready = 0
	game.wild_item_drops.assign([trophy(actor.pos)])
	game.EnemyBehaviors.tick(game,actor,.016,now)
	check(actor.windup>now and game.wild_item_drops.size()==1,"windup gives players a chance to pick up the trophy")
	var taken_at: int = actor.windup
	game.resolve_scout(actor,game.Enemies.get_kind(Escape.KIND),taken_at)
	check(game.wild_item_drops.is_empty() and actor.has("escape") and game.status.contains("stole a trophy"),"grab commits a route and alerts the party")
	return taken_at


func follow(actor: Dictionary, now: int) -> int:
	for step in 500:
		now += 50
		if actor.get("escape",{}).get("burrow_until",0)>0 or actor.hp<=0:
			break
		game.EnemyBehaviors.tick(game,actor,.05,now)
	return now


func run() -> void:
	game = load("res://world.tscn").instantiate()
	game.progress.path = "res://.godot/thief-escape-"+str(Time.get_ticks_usec())+".cfg"
	game.local_character.path = game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var player: Dictionary = game.players[1]
	player.wild = true
	player.pos = Vector3(0,0,-6)
	game.battlefield.configure(0,1,0)
	game.enemy_hp = 0

	var field := Field.new()
	for seed in [1610,4619,9394]:
		field.configure(1,8,seed)
		var origin: Vector3 = field.spawn_points[0]
		var path := Escape.plan(field,origin)
		check(not path.is_empty(),"procedural floor provides a reachable tunnel")
		for waypoint in path:
			check(field.clear_line(origin,waypoint,Field.CLEARANCE),"the displayed route follows navigable terrain")
			origin = waypoint
		if not path.is_empty():
			check(not field.occupied(path[-1],.6),"tunnel is on the walkable side of the boundary")

	var thief: Dictionary = game.make_scout(Escape.KIND,player.pos,2)
	game.scouts.assign([thief])
	var start := start_theft(thief,1000)
	if not thief.has("escape"):
		game.queue_free()
		quit(1)
		return
	var route := Escape.snapshot(game)
	check(route.size()==1 and route[0].id==0 and route[0].tunnel==thief.escape.tunnel,"owner snapshot exposes thief and exit")
	check(game.player_snapshot(1)[1].thief_routes.size()==1,"actual details packet contains the trail")
	game._process(.016)
	check(game.exploration.thief_routes.size()==1 and game.exploration.thief_tunnels.size()==1 and not game.stage.wild_portal.visible,
		"active thief has a map route and tunnel, and still counts toward clearing")
	var origin: Vector3 = thief.pos
	thief.rooted_until = start+450
	game.EnemyBehaviors.tick(game,thief,.1,start+50)
	check(thief.pos==origin,"root stops a fleeing thief")
	var now := follow(thief,start+450)
	check(thief.escape.burrow_until>now and not game.encounter_cleared(),"arrival starts a vulnerable burrow windup")
	game.apply_weapon_hit(player,0,thief.pos,{"damage":1,"knockback":-.35},now)
	game.EnemyBehaviors.tick(game,thief,.05,now+20)
	check(thief.escape.burrow_until==0,"a stagger interrupts burrowing")
	game.apply_weapon_hit(player,0,thief.pos,{"damage":999,"knockback":-.35},now+200)
	check(thief.hp==0 and Escape.snapshot(game).is_empty() and game.wild_item_drops.any(func(drop): return drop.id=="owned-trophy" and drop.owner==1 and drop.stack.quantity==2),
		"intercepting the thief restores the exact original drop")

	var runner: Dictionary = game.make_scout(Escape.KIND,player.pos,3)
	game.scouts.assign([runner])
	game.enemy_hp = 10
	game.enemy_pos = Vector3(2,0,-6)
	start = start_theft(runner,now+1000)
	now = follow(runner,start)
	var escape_at: int = runner.escape.burrow_until
	check(escape_at>=start+Escape.MIN_CHASE_MS,"the chase gives players time even on a short route")
	var kills: int = game.encounter_kills.size()
	var corpses: int = game.enemy_death_events.size()
	game.EnemyBehaviors.tick(game,runner,.05,escape_at)
	check(runner.hp==0 and runner.escaped and game.wild_item_drops.is_empty() and Escape.snapshot(game).is_empty(),"escaping removes the thief and stolen loot")
	check(game.encounter_kills.size()==kills and game.enemy_death_events.size()==corpses and not game.encounter_cleared(),"escape pays no kill rewards and leaves other foes required")
	check(Support.corpse(game,game.make_scout(15,runner.pos,4),4.0).is_empty(),"escaped thief cannot be consumed as a corpse")

	game.scouts.clear()
	game.enemy_kind = Escape.KIND
	game.enemy_hp = 14
	game.enemy_pos = player.pos
	game.enemy_ready_at = 0
	game.enemy_engaged = true
	game.enemy_stagger_until = 0
	game.rooted_until = 0
	var elite := Elite.state(game)
	elite.hp = game.enemy_hp
	game.wild_item_drops.assign([trophy(elite.pos)])
	game.update_enemy(.016,escape_at+1000)
	check(game.enemy_winding_up,"gate elite tries its normal trophy grab")
	game.resolve_briar_strike(game.enemy_strike_at)
	check(elite.has("escape") and Escape.snapshot(game)[0].id==-1,"elite uses the same marked tunnel")
	now = game.enemy_strike_at
	for step in 500:
		now += 50
		game.update_enemy(.05,now)
		if game.enemy_hp==0:
			break
	check(game.enemy_hp==0 and elite.escaped and game.encounter_cleared(),"elite escape satisfies the real encounter-clear predicate")
	game._process(.016)
	check(game.stage.wild_portal.visible and game.exploration.thief_routes.is_empty() and game.exploration.thief_tunnels.is_empty(),"portal lights and escape markers disappear")
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: navigable thief tunnels, party alert, stagger, loot recovery, scout and elite escape, and portal activation")
	quit(1 if failed else 0)
