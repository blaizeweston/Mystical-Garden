extends SceneTree
## Shared-status contracts use actual family handlers, event admission and HP.
const Events = preload("res://combat_action_events.gd")
const Build = preload("res://affinity_build.gd")
const Thorn = preload("res://thorn_affinity.gd")
const Frost = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Sources = preload("res://affinity_status_source.gd")
const Life = preload("res://player_lifecycle.gd")
const Expedition = preload("res://tests/support/expedition_case.gd")
var game: Node
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL shared affinity: ",message)

func reset() -> void:
	game.encounter.set_hp(-1,10000)
	game.encounter.clear_scouts()
	game.tactics.memory.clear()
	game.tactics.position=Vector3(0,0,-1)
	game.tactics.boss_kind=-1
	game.set_meta(Clock.CLOCK,0.0)
	if game.has_meta(Thorn.FIELDS): game.remove_meta(Thorn.FIELDS)
	for player in game.players.values():
		player.weapon=0;player.secondary=0;player.catalyst=0

func event(peer: int, slot: String, item: String, overrides: Dictionary = {}) -> RefCounted:
	var material := Build.slot(slot,int(game.Items.get_item(item).legacy_part))
	var potency: Dictionary=material.potency_profile.values.duplicate(true)
	potency.merge(overrides,true)
	return Events.begin(game,peer,slot,material,potency,["core_action","weapon_contact","class_contact"],0x7fffffffffffffff)

func run() -> void:
	game=load("res://world.tscn").instantiate()
	root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	for peer in [2,3,4]: game.add_player(peer)
	for player in game.players.values():
		Expedition.set_membership(game,player,true)
		player.pos=Vector3.ZERO
	verify_frost()
	verify_bleed()
	game.queue_free()
	await process_frame
	if not failed: print("PASS: shared affinity status buildup, frozen contributions, cadence, four contributors, expiry and stale identities")
	quit(int(failed))

func verify_frost() -> void:
	reset()
	var ordinary := "plant_part_plant_frostbell"
	var now := Time.get_ticks_msec()
	var first := event(1,"core",ordinary,{"max_shatter_hp":9})
	var second := event(2,"form",ordinary,{"max_shatter_hp":12})
	Frost.apply(game,first,-1,2,now)
	var partial := Frost.state(game.tactics.memory,now)
	check(partial.stacks.size()==2 and partial.stacks[0].numerator==9000,
		"two stacks freeze thirds of the first player's maximum")
	check(is_equal_approx(Frost.motion_scale(game.tactics.memory,now),.84),"two stacks preserve their native slowing progression")
	Frost.apply(game,second,-1,1,now)
	check(game.enemy_health()==9990 and Frost.state(game.tactics.memory,now).is_empty(),"9/3 + 9/3 + 12/3 ruptures once for 10")
	check(not Frost.rooted(game.tactics.memory,now),"baseline rupture grants no root")
	Frost.apply(game,event(1,"core",ordinary,{"max_shatter_hp":10}),-1,2,now)
	Frost.apply(game,event(2,"form",ordinary,{"max_shatter_hp":12}),-1,1,now)
	check(game.enemy_health()==9979,"fractional thirds round once at final rupture: 32/3 becomes 11")
	Frost.apply(game,first,-1,1,now)
	game.players[1][Life.STATE]=Life.start_life()
	Frost.tick(game,now+1)
	check(not game.tactics.memory.has(Frost.BRITTLE),"previous-life stack cannot join a later rupture")
	Frost.apply(game,first,-1,3,now+2)
	check(game.enemy_health()==9979,"a stale source cannot reapply stacks")

func verify_bleed() -> void:
	reset()
	var now := Time.get_ticks_msec()
	var at: Vector3=game.tactics.position
	for slot in ["core","form","catalyst"]:
		Thorn.patch(game,event(1,slot,"part_1"),at,1.0,now)
	var status: Dictionary=game.tactics.memory[Thorn.BLEED]
	check(status.contributors.size()==1 and Thorn.cap_units(status)==12000,
		"Core/Form/Catalyst share one player cap, counted once")
	check(Thorn.potency_units(status)==7200,"slot applications add 25%, 10% and 25% to one buildup")
	Thorn.patch(game,event(2,"core","part_5"),at,1.0,now)
	check(status.contributors.size()==2 and Thorn.cap_units(status)==30000,
		"mixed ordinary/refined contributors add their individual caps")
	var before: int=game.enemy_health()
	Thorn.tick(game,Clock.advance(game,.9),now)
	check(game.enemy_health()==before-11 and int(status.remainder)==700,
		"one aggregate tick carries fractional damage instead of rounding each source")
	var after: int=game.enemy_health()
	Thorn.tick(game,Clock.now(game),now)
	check(game.enemy_health()==after,"repeating the same tick cannot damage again")
	reset()
	for peer in [1,2,3,4]: Thorn.patch(game,event(peer,"core","part_1"),at,1.0,now)
	for index in 4: Thorn.tick(game,Clock.advance(game,1.01),now)
	status=game.tactics.memory[Thorn.BLEED]
	check(status.contributors.size()==4 and Thorn.cap_units(status)==48000 and Thorn.potency_units(status)==48000,
		"four players build one effect to the sum of their four caps")
	var key := Sources.key(Sources.capture(event(4,"core","part_1")))
	game.network_session.release_peer(4)
	Thorn.tick(game,Clock.advance(game,.01),now)
	check(not status.contributors.has(key) and Thorn.cap_units(status)==36000,
		"disconnect removes that contributor without transferring its cap")
	Thorn.tick(game,Clock.advance(game,15.0),now)
	check(not game.tactics.memory.has(Thorn.BLEED) and not game.has_meta(Thorn.FIELDS),
		"expired fields and all accumulated contributions retire")
