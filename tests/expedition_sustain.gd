extends SceneTree
const OutgoingHits = preload("res://outgoing_hits.gd")
const HitSession = preload("res://network_session.gd")
const ClassActions = preload("res://native_class_actions.gd")
const UIFixture = preload("res://tests/support/gameplay_ui_case.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")

const Cooldowns = preload("res://player_cooldowns.gd")

const Preview = preload("res://combat_balance_preview.gd")
const Sustain = preload("res://expedition_sustain.gd")
const Core = preload("res://core_combat.gd")
const Orb = preload("res://health_orb.gd")
const Cards=preload("res://affinity_cards.gd")

var game: Node
var player: Dictionary
var ally: Dictionary
var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, detail: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL CB-07: ",detail)


func run() -> void:
	Preview.heal_rng.seed=58397
	game=load("res://world.tscn").instantiate()
	game.progress.path="res://.godot/cb07-sustain-"+str(Time.get_ticks_usec())+".cfg"
	game.local_character.path=game.progress.path+".character"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	player=game.players[1]
	game.add_player(2)
	ally=game.players[2]
	gate_recovery()
	kill_budget()
	drains()
	revival()
	overlap()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: CB-07 repeated floors, actual kill budget, summon exclusion, revive after max HP upgrades and deduplicated healing feedback")
	quit(1 if failed else 0)


func arena() -> void:
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	ExpeditionCase.set_world(game, {"destination": 0})
	ExpeditionCase.set_world(game, {"depth": 1})
	ExpeditionCase.set_world(game, {"encounter_number": 1})
	ExpeditionCase.set_world(game, {"difficulty_cycle": 0})
	game.tactics.boss_kind=-1
	game.encounter.set_hp(-1, 800)
	game.tactics.position=Vector3(0,0,-2)
	game.tactics.winding_up=false
	game.enemy_mutations=0
	game.battlefield.configure(0,1,0)

	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.encounter.clear_scouts()
	game.enemy_traits.clear()
	game.trait_events.clear()
	game.combat_events.clear()
	game.tactics.memory.clear()
	Core.reset(game)
	for actor in [player,ally]:
		ExpeditionCase.set_membership(game,actor,true)
		Cards.clear(actor)
		actor[Cooldowns.STATE] = actor[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0).with_deadline(Cooldowns.R, 0)
		actor[PlayerVitals.STATE] = PlayerVitals.Health.new(30.0, 100)
		actor.merge({"wild":true,PlayerLifecycle.STATE:PlayerLifecycle.start_life(),"lost_health":0,"pos":Vector3.ZERO,
			"renewal_until":0,Protection.STATE:actor[Protection.STATE].clear_guard(),Conditions.STATE:actor[Conditions.STATE].clear_grace(),"weapon":0,
			"catalyst":0,"secondary":0,"core_ready_at":0,"core_cast_until":0,"cast_until":0,
			"frame":0,"weapon_kind":0,"facing":Vector3.FORWARD},true)
	SessionCase.set_ready(game, ally, false)
	player.character=game.Character.blank()
	var tree=game.Classes.connected_tree(0)
	player.character[tree.profile_key]=tree.state(["vanguard"])


func gate_recovery() -> void:
	arena()
	ExpeditionCase.set_world(game, {"encounter_number": 41})
	ExpeditionCase.set_world(game, {"depth": 5})
	ExpeditionCase.set_world(game, {"difficulty_cycle": 2})
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(48)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(50)
	check(Sustain.recovery_center_hp(false,2)==16 and Sustain.recovery_center_hp(true,2)==26,"floor and biome recovery scale at different depths")
	check(Sustain.recovery_center_hp(false,40)==19,"deep recovery has a fixed midpoint cap")
	var view:=UIFixture.summary(game,player,game.weapon_stats(player))
	check(view.totals.has(["Next gate recovery","14–18 HP"]),"entering a guardian floor previews the ordinary gate range")
	var expected := [[42,14,18],[43,24,28]]
	for step in expected:
		game.encounter.set_hp(-1, 0)
		game.encounter.clear_scouts()
		player.pos=game.battlefield.advance
		ally.pos=player.pos
		if game.upgrade_checkpoint_open():
			game.checkpoint_pending=true
			game.checkpoint_ready={1:game.participation.floor(),2:game.participation.floor()}
		var before:=int(PlayerVitals.current_hp(player))
		var ally_before:=int(PlayerVitals.current_hp(ally))
		ExpeditionCase.Transitions.commit_checkpoint(game, 1,true)
		var gained:=int(PlayerVitals.current_hp(player))-before
		check(game.participation.floor()==step[0] and gained in range(step[1],step[2]+1),"normal gate commit rolls the displayed recovery range")
		check(int(PlayerVitals.current_hp(ally))-ally_before==gained,"gate recovery shares its roll")
		IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(player), 28)
		IncomingPlayerHit.apply_health_loss(game, 2, PlayerLifecycle.generation(ally), 28)
	check(PlayerVitals.current_hp(player)<48 and PlayerVitals.current_hp(player)>0,"two gates offset part of two deep contacts without resetting attrition")


func add_enemy(at: Vector3, summoned: bool=false) -> Dictionary:
	var mob: Dictionary=game.make_scout(0,at,game.encounter.scout_count()+1)
	mob.summoned=summoned
	game.encounter.register_scout(mob)
	return mob


func finish_scout(summoned: bool, now: int) -> void:
	game.encounter.clear_scouts()
	add_enemy(Vector3(0,0,-1),summoned)
	OutgoingHits.hit_world(game, HitSession.peer_for(player), 0, player.pos, {"damage":9.0,"heal_on_kill":1.0,"knockback":-.35}, now)


func kill_budget() -> void:
	arena()
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(99)
	finish_scout(false,1000)
	check(PlayerVitals.current_hp(player)==100 and Sustain.kill_remaining(player,game.participation.epoch())==23,"overheal spends only actual HP")
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(20)
	var state := Preview.heal_rng.state
	finish_scout(true,2000)
	check(PlayerVitals.current_hp(player)==20 and Preview.heal_rng.state==state,"a summoned kill cannot roll or consume the budget")
	for index in 5:
		finish_scout(false,3000+index*100)
	check(PlayerVitals.current_hp(player)==43 and Sustain.kill_remaining(player,game.participation.epoch())==0,"large packs cannot exceed the per-floor kill heal budget")
	var stats: Dictionary=game.weapon_stats(player)
	# Detached presentation facts exercise the existing kill-healing budget.
	stats.heal_on_kill=1.0
	stats.kill_heal_remaining=Sustain.kill_remaining(player,game.participation.epoch())
	check(stats.kill_heal_remaining==0,"owner projection exposes the exhausted budget")
	var view:=UIFixture.summary(game,player,stats)
	check(view.totals.has(["Kill healing left this floor","0 / 24 HP"]),"Tab shows the exhausted floor budget")
	ExpeditionCase.set_world(game, {"combat_epoch": game.participation.epoch() + (1)})
	check(Sustain.kill_remaining(player,game.participation.epoch())==24,"the next floor renews the budget")


func drains() -> void:
	arena()
	game.tactics.position=Vector3(15,0,0)
	player.frame=3
	var tree=game.Classes.connected_tree(3)
	player.character[tree.profile_key]=tree.state(["blood_harvester"])
	var summon:=add_enemy(Vector3(0,0,-1),true)
	ClassActions.cast_world(game, 1, 1)
	check(game.encounter.hp_for(summon)<summon.max_hp and PlayerVitals.current_hp(player)==30,"Siphon Cut damages a summon without drawing health")


func revival() -> void:
	arena()
	ExpeditionCase.set_world(game, {"encounter_number": 3})
	game.encounter.set_hp(-1, 0)
	player.pos=game.battlefield.advance
	ally.pos=player.pos
	var copies: Array[Dictionary]=[
		{"id":"run_health","rarity":"Common","amount":3,"floor":3,"acquisition_id":1},
		{"id":"run_health","rarity":"Common","amount":3,"floor":6,"acquisition_id":2},
		{"id":"run_health","rarity":"Uncommon","amount":5,"floor":9,"acquisition_id":3},
		{"id":"run_health","rarity":"Epic","amount":9,"floor":12,"acquisition_id":4},
	]
	player[Cards.STATE]=Cards.Ledger.new(copies)
	player[PlayerVitals.STATE]=player[PlayerVitals.STATE].with_native_max_hp(game.Life.native_maximum(game,player))
	check(PlayerVitals.maximum_hp(player)==120 and PlayerVitals.current_hp(player)==30,"actual acquired contributions grant capacity without free healing")
	IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(player), int(PlayerVitals.current_hp(player)))
	check(Sustain.restore(game,player,12,"fixture")==0 and PlayerLifecycle.fallen(player),"ordinary healing cannot revive a fallen player")
	check(game.spectator_view.focus_id(1)==2 and game.spectator_view.caption.text.contains("30 / 100 HP") and game.spectator_view.panel.position.y>=110,"spectating shows ally health below the floor tracker")
	check(game.Life.revive(game,2,1) and PlayerVitals.maximum_hp(player)==100 and PlayerVitals.current_hp(player)==100 and player.lost_health==20,"revival retains earned capacity and seals exactly 20 HP")
	check(Orb.fractions(PlayerVitals.current_hp(player),PlayerVitals.maximum_hp(player),player.lost_health).is_equal_approx(Vector2(5.0/6.0,5.0/6.0)),"sealed segment is measured from the upgraded ceiling")
	check(game.spectator_view.focus_id(1)==1 and not game.spectator_view.panel.visible,"revive returns camera and HUD control")


func overlap() -> void:
	arena()
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_native_max_hp(80)
	player.lost_health=20
	player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(78)
	check(Sustain.restore(game,player,12,"fixture")==2,"healing reports actual restoration after the cap")
	IncomingPlayerHit.apply_health_loss(game, 1, PlayerLifecycle.generation(player), 2)
	check(PlayerVitals.current_hp(player)==78,"coincident heals and hits preserve the final net value")
	var events: Array=game.combat_events_snapshot()
	game.combat_visuals.sync(events+events,[],"cb07-feedback",player.pos)
	var labels: Array=game.combat_visuals.feedback.labels.map(func(entry):return entry.node.text)
	check(labels.count("+2")==1 and labels.count("−2")==1 and not labels.has("+12"),"feedback distinguishes applied heal and damage exactly once")
	var orb:=Orb.new()
	orb.update({"hp":78,"max_hp":80,"lost_health":20,"wild":true},1000)
	orb.update({"hp":80,"max_hp":80,"lost_health":20,"wild":true},1150)
	check(orb.from_hp==78 and orb.changed_at==1150,"the main orb retains the healing highlight")
	orb.update({"hp":0,"max_hp":80,"lost_health":20,"wild":true,"fallen":true},1160)
	check(orb.hp==0 and orb.from_hp==0 and orb.changed_at==0,"falling clears stale orb effects")
