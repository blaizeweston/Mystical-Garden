extends SceneTree
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Rules = preload("res://combat_ruleset.gd")
const Frost = preload("res://frost_combat.gd")
const Events = preload("res://combat_action_events.gd")
const Builds = preload("res://affinity_build.gd")
const Core = preload("res://core_combat.gd")
const Status = preload("res://combat_status.gd")
var failed := false
var seen: Array[Dictionary] = []
var bursts: Array = []
var game: Node
var ordinary: int
var refined: int


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Frost: ",label)


func run() -> void:
	game = preload("res://world.tscn").instantiate()

	game.settings_path = "user://frost-settings.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_meta(Events.RECORD,func(event): seen.append(event))
	game.set_meta(&"frost_rupture_witness",func(stacks,hp): bursts.append([stacks,hp]))
	ordinary = game.Items.get_item("plant_part_plant_frostbell").legacy_part
	refined = game.Items.get_item("plant_part_rare_frostbell").legacy_part
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	var p: Dictionary = game.players[1]
	equip_native_focus(p)
	ExpeditionCase.set_membership(game, p, true)
	p.pos = Vector3.ZERO
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(90)
	game.add_player(2)
	ExpeditionCase.set_membership(game, game.players[2], true)
	game.players[2][PlayerVitals.STATE] = game.players[2][PlayerVitals.STATE].with_hp(90)
	game.players[2].pos = Vector3.ZERO
	run_core(p,ordinary)
	run_core(p,refined)
	run_form(p,ordinary)
	run_form(p,refined)
	run_form(p,ordinary,2,0)
	run_form(p,refined,2,1)
	run_catalyst(p,ordinary)
	run_catalyst(p,refined)
	run_focus(p)
	run_wards()
	run_mixed()
	game.queue_free()
	await process_frame
	if not failed: print("PASS: Frost gameplay contacts, Core delivery, Ward claim order and shared movement")
	quit(int(failed))


func reset_enemy(at := Vector3(0,0,-1.5)) -> void:
	for actor in game.players.values():
		preload("res://oracle_combat.gd").clear(actor)
		actor[Protection.STATE] = actor[Protection.STATE].clear_guard()

		actor[Protection.STATE] = actor[Protection.STATE].clear_expedition()
	game.trait_events.clear()
	game.encounter.set_hp(-1, 150)
	game.enemy_mutations=0
	game.tactics.boss_kind=-1
	game.tactics.position=at
	game.tactics.winding_up=false
	game.tactics.memory.clear()
	game.encounter.clear_scouts()
	Core.reset(game)
	bursts.clear()
	seen.clear()


func run_core(p: Dictionary, part: int) -> void:
	reset_enemy()
	p.weapon=part
	p.secondary=0
	p.catalyst=0
	p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
	p.core_ready_at=0
	p.core_cast_until=0
	p.cast_until=0
	game.garden_action(1,"core_cast:stale:0:-1:1.5")
	check(p.core_ready_at==0,"stale Core request spends no cooldown")
	var cast_key := Core.request(game,p,Vector2.UP,1.5)
	game.garden_action(1,cast_key)
	var lines: Dictionary = game.get_meta(Core.STATE,{})
	if not lines.has(1):
		check(false,"Rime Bloom gets valid placement through B")
		return
	var cast: Dictionary = lines[1]
	var at: int = cast.armed
	Core.tick(game,at)
	Core.tick(game,at+1)
	var quality: String = "refined" if part==refined else "ordinary"
	var potency: Dictionary = Frost.Balance.QUALITY[quality]
	var open := Frost.state(game.tactics.memory,at)
	check(game.enemy_health()==150-Frost.Balance.BLOOM_OPEN_HP and open.get("stacks",[]).size()==2,"opening damage and two stacks once")
	check(is_equal_approx(Frost.motion_scale(game.tactics.memory,at),1-2*potency.move_slow),"two stacks alter movement immediately")
	var ready: int = p.core_ready_at
	game.garden_action(1,cast_key)
	check(p.core_ready_at==ready,"repeated cast during its cooldown is refused")
	Core.tick(game,at+Frost.Balance.BLOOM_DELAY_MS)
	check(bursts.size()==1 and bursts[0][1]==3*potency.rupture_hp
		and Frost.motion_scale(game.tactics.memory,at+Frost.Balance.BLOOM_DELAY_MS)==0.0 and Frost.state(game.tactics.memory,at+Frost.Balance.BLOOM_DELAY_MS).is_empty(),
		"Core alone ruptures, clears spent stacks and roots for both qualities")
	check(Frost.motion_scale(game.tactics.memory,at+Frost.Balance.BLOOM_DELAY_MS+Frost.Balance.ROOT_MS)==1.0,"root expires independently")


func run_form(p: Dictionary, part: int, frame := 0, weapon_kind := 0) -> void:
	reset_enemy(Vector3(0,0,-1.0))
	p.frame=frame
	p.weapon_kind=weapon_kind
	p.weapon=0
	p.secondary=part
	p.catalyst=0
	p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
	p.facing=Vector3.FORWARD
	game.strike_enemy(1,p,p.pos)
	if game.projectile_queue.is_empty():
		check(false,"Form uses real native strike queue")
		return
	var shot: Dictionary=game.projectile_queue.front()
	check(Frost.state(game.tactics.memory,Time.get_ticks_msec()).is_empty(),"queued attack has not applied Frost")
	var at: int=shot.due+1
	game.update_projectiles(at)
	var current := Frost.state(game.tactics.memory,at)
	if current.is_empty():
		check(false,"eligible real melee contact applies Frost Form")
		return
	var quality: String = "refined" if part==refined else "ordinary"
	check(current.stacks.size()==1 and current.stacks[0].quality==quality,"Form applies the correct quality on contact")
	Events.contact(game,shot.stats,-1,at+1)
	Events.contact(game,shot.stats,-1,at+1,true)
	check(Frost.state(game.tactics.memory,at+1).stacks.size()==1,"duplicate and secondary contacts cannot apply stacks")
	check(Frost.motion_scale(game.tactics.memory,at+Frost.Balance.BRITTLE_MS)==1.0,"unrefreshed Brittle expires")


func run_catalyst(p: Dictionary, part: int) -> void:
	reset_enemy(Vector3(0,0,-1))
	p.weapon=0
	p.secondary=0
	p.catalyst=part
	p.frame=0
	p.weapon_kind=0
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	p.core_cast_until=0
	p.cast_until=0
	game.use_class_skill(1,p,1)
	var current := Frost.state(game.tactics.memory,Time.get_ticks_msec())
	check(current.get("stacks",[]).size()==1 and current.stacks[0].quality==("refined" if part==refined else "ordinary"),"Catalyst-only Q/R emits a native offensive contact with its quality")
	p.frame=4
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(60)
	var ally: Dictionary=game.players[2]
	ally.catalyst=ordinary if part==refined else refined
	ally.hurt_until=0
	ally[Protection.STATE] = ally[Protection.STATE].clear_guard()
	p.class_aim=Vector3.FORWARD
	p.class_aim_distance=0.0
	game.use_class_skill(1,p,0)
	p.erase("class_aim")
	p.erase("class_aim_distance")
	check(ally.has(Frost.RESPONSE),"Living Sanctuary opening heal prepares a response for the ally")
	var now:=Time.get_ticks_msec()
	var hp: float=ally[PlayerVitals.STATE].hp()
	Frost.with_attacker(game,-1,IncomingPlayerHit.resolve_world.bind(game, 2, PlayerLifecycle.generation(ally), now, 1))
	check(ally[PlayerVitals.STATE].hp()<hp and not ally.has(Frost.RESPONSE),"fallback consumes after an actual survivable hit without blocking it")
	check(ally[PlayerVitals.STATE].hp()==hp-10+6,"native Second Breath independently restores 6 HP after the survived direct hit")
	var after := Frost.state(game.tactics.memory,now)
	check(after.get("stacks",[]).size()==2 and after.stacks[1].actor==1 and after.stacks[1].quality==("refined" if part==refined else "ordinary"),"ally uses granting Catalyst quality")
	game.Traits.tick(game,now+1100)
	check(not ally.has(Frost.RESPONSE),"Sanctuary field pulses do not regrant the opening Catalyst response")
	p.frame=0


func run_focus(p: Dictionary) -> void:
	reset_enemy(Vector3(0,0,-1))
	p.frame=0
	p.weapon_kind=0
	p.catalyst=refined
	p.character[game.Classes.Warden.Connected.PROFILE_KEY]=game.Classes.Warden.Connected.state(["vanguard"])
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	p[Protection.STATE] = p[Protection.STATE].clear_expedition()
	p.hurt_until=0
	game.use_class_skill(1,p,0)
	var now:=Time.get_ticks_msec()
	IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(p), now, 1)
	var current:=Frost.state(game.tactics.memory,now)
	check(seen.size()==1 and seen[0].details.adapter=="warden/focus/vanguard/Q"
		and current.get("stacks",[]).size()==1 and current.stacks[0].quality=="refined","real Vanguard Thorn Counter uses the Frost block adapter")
	p.character[game.Classes.Warden.Connected.PROFILE_KEY]=game.Classes.Warden.Connected.state(["rootkeeper"])


func cast_ward(id: int, part: int, now: int) -> RefCounted:
	return Events.class_start(game,id,{"trigger":"block"},now,Builds.slot("catalyst",part))


func run_wards() -> void:
	reset_enemy()
	var p: Dictionary=game.players[2]
	p[Protection.STATE] = p[Protection.STATE].clear_expedition()
	var now:=Time.get_ticks_msec()
	var adapter:={"id":"test_ward","trigger":"block","limit":"recipient"}
	var first := cast_ward(1,ordinary,now)
	var second := cast_ward(2,refined,now)
	Events.grant_ward(game,p,now+500,1,first,adapter,now)
	Events.grant_ward(game,p,now+900,2,second,adapter,now)
	Events.grant_ward(game,p,now+900,2,second,adapter,now)
	check(p[Protection.STATE].claim_count()==2 and p[Protection.STATE].charge_count()==2 and p[Protection.STATE].guard_until_ms()==now+900,"two accepted overlapping grants and native max-merge")
	var hp: float=p[PlayerVitals.STATE].hp()
	p.hurt_until=0
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(p), now, 1)
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(p), now+1, 1)
	check(p[PlayerVitals.STATE].hp()==hp and p[Protection.STATE].charge_count()==0 and p[Protection.STATE].claim_count()==0,"real block charges exhaust and clear ownership")
	check(seen.size()==2 and seen[0].source_actor==1 and seen[0].quality=="ordinary"
		and seen[1].source_actor==2 and seen[1].quality=="refined","soonest Ward response first with originating potency")
	check(not first.publish(game,"actual_block","ward","2",now+2,{"recipient":2,"center":p.pos}),"replayed Ward cannot publish twice")
	seen.clear()
	p[Protection.STATE] = p[Protection.STATE].grant(now+200,1,Time.get_ticks_msec(),game.participation.epoch())
	Events.grant_ward(game,p,now+800,2,cast_ward(1,refined,now),adapter,now)
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(p), now+250, 1)
	check(seen.size()==1 and seen[0].quality=="refined","expired unenhanced claim cannot suppress later grant")
	p[Protection.STATE] = p[Protection.STATE].clear_expedition()
	seen.clear()
	p[Protection.STATE] = p[Protection.STATE].grant(now+500,1,Time.get_ticks_msec(),game.participation.epoch())
	Events.grant_ward(game,p,now+500,2,cast_ward(1,ordinary,now),adapter,now)
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(p), now+10, 1)
	check(seen.is_empty(),"unmodified earlier claim wins equal-expiry tie by host grant order")
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(p), now+11, 1)
	check(seen.size()==1 and seen[0].quality=="ordinary","remaining Ward owns the next block")
	seen.clear()
	p[Protection.STATE] = p[Protection.STATE].clear_expedition()
	var short := cast_ward(1,ordinary,now)
	var long := cast_ward(1,refined,now)
	Events.grant_ward(game,p,now+300,1,short,adapter,now)
	Events.grant_ward(game,p,now+900,2,long,adapter,now)
	Events.grant_ward(game,p,now+1200,2,long,adapter,now)
	check(p[Protection.STATE].claim_count()==2 and p[Protection.STATE].guard_until_ms()==now+1200,"duplicate activation can never renew its response claim")
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(p), now+400, 1)
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(p), now+950, 1)
	check(seen.size()==1 and seen[0].quality=="refined" and p[Protection.STATE].charge_count()==0,"native refresh cannot extend either same-actor enhancement")


func run_mixed() -> void:
	reset_enemy()
	var now:=Time.get_ticks_msec()
	var first := Events.begin(game,1,"form",Builds.slot("form",ordinary),Frost.Balance.QUALITY.ordinary,["weapon_contact"],now+18000)
	var second := Events.begin(game,2,"core",Builds.slot("core",refined),Frost.Balance.QUALITY.refined,["core_action"],now+18000)
	first.publish(game,"weapon_contact","contact","leader",now,{"enemy":-1})
	check(is_equal_approx(Frost.motion_scale(game.tactics.memory,now),.92),"one ordinary stack gives its movement slow")
	var later:=now+Frost.Balance.BRITTLE_MS-1
	var saved_windup: int=game.tactics.strike_at
	game.tactics.winding_up=true
	second.publish(game,"core_action","open","leader",later,{"enemy":-1,"stacks":3,"opening_hp":0})
	check(game.tactics.winding_up and game.tactics.strike_at==saved_windup,"rupture does not cancel or retime existing wind-up")
	check(bursts.size()==1 and bursts[0][1]==18 and bursts[0][0][0].actor==1
		and Frost.state(game.tactics.memory,later).stacks.size()==1 and Frost.state(game.tactics.memory,later).stacks[0].quality=="refined",
		"authoritative FIFO rupture uses mixed-potency contributions and retains excess")
	check(Frost.state(game.tactics.memory,later+Frost.Balance.ROOT_MS+1).stacks.size()==1,"genuine application refreshes retained Brittle")
	var begin:=Time.get_ticks_usec()
	var checksum:=0.0
	for index in 20000:
		checksum+=Frost.motion_scale(game.tactics.memory,later+Frost.Balance.ROOT_MS)
	print("Frost movement query: ",float(Time.get_ticks_usec()-begin)/20000.0," us/query, checksum ",checksum)
	var sync_cost:=Time.get_ticks_usec()
	for index in 250:
		Status.sync(game,later+Frost.Balance.ROOT_MS)
	print("Host status sync (two players, one affected enemy): ", float(Time.get_ticks_usec()-sync_cost)/250.0, " us/update")


## Family fixtures use the current native focus kit, never historical learned masks.
func equip_native_focus(player: Dictionary) -> void:
	for class_id in game.Classes.DEFINITIONS.size():
		var tree: RefCounted=game.Classes.connected_tree(class_id)
		var focus: String="rootkeeper" if class_id==0 else "lifekeeper" if class_id==4 else str(tree.nodes[0].id)
		player.character[tree.profile_key]=tree.state([focus])
