extends SceneTree

const Preview = preload("res://combat_balance_preview.gd")
const Sustain = preload("res://expedition_sustain.gd")
const Core = preload("res://core_combat.gd")
const Summary = preload("res://run_summary_panel.gd")
const Orb = preload("res://health_orb.gd")

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
	Preview.enabled=true
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
	pulse_and_refresh()
	drains()
	revival()
	overlap()
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: CB-07 repeated floors, pool and Renewal pacing, actual kill budget, summon exclusion, revive after max HP upgrades and deduplicated healing feedback")
	quit(1 if failed else 0)


func arena() -> void:
	game.combat_epoch+=1
	game.destination=0
	game.depth=1
	game.encounter_number=1
	game.difficulty_cycle=0
	game.boss_kind=-1
	game.enemy_hp=800
	game.enemy_pos=Vector3(0,0,-2)
	game.enemy_winding_up=false
	game.enemy_mutations=0
	game.battlefield.configure(0,1,0)
	game.battlefield.procedural=false
	game.battlefield.barriers.clear()
	game.scouts.clear()
	game.enemy_traits.clear()
	game.trait_events.clear()
	game.combat_events.clear()
	game.leader_brain.clear()
	Core.reset(game)
	for actor in [player,ally]:
		actor.merge({"wild":true,"fallen":false,"hp":30,"max_hp":100,"lost_health":0,"pos":Vector3.ZERO,
			"renewal_until":0,"guard_until":0,"hurt_until":0,"run_upgrades":{},"weapon":0,
			"catalyst":0,"secondary":0,"graft_part":0,"core_ready_at":0,"core_cast_until":0,"cast_until":0,
			"skill_at":0,"skill_two_at":0,"frame":0,"weapon_kind":0,"facing":Vector3.FORWARD},true)
	ally.profile_ready=false
	player.character=game.Character.blank()


func gate_recovery() -> void:
	arena()
	game.encounter_number=41
	game.depth=5
	game.difficulty_cycle=2
	player.hp=48
	ally.hp=50
	check(Sustain.recovery_center_hp(false,2)==16 and Sustain.recovery_center_hp(true,2)==26,"floor and biome recovery scale at different depths")
	check(Sustain.recovery_center_hp(false,40)==19,"deep recovery has a fixed midpoint cap")
	var view:=Summary.project(game,player,game.weapon_stats(player))
	check(view.totals.has(["Next gate recovery","14–18 HP"]),"entering a guardian floor previews the ordinary gate range")
	var expected := [[42,14,18],[43,24,28]]
	for step in expected:
		game.enemy_hp=0
		game.scouts.clear()
		player.pos=game.battlefield.advance
		ally.pos=player.pos
		if game.upgrade_checkpoint_open():
			game.checkpoint_pending=true
			game.checkpoint_ready={1:game.encounter_number,2:game.encounter_number}
		var before:=int(player.hp)
		var ally_before:=int(ally.hp)
		game._use_checkpoint(1,true)
		var gained:=int(player.hp)-before
		check(game.encounter_number==step[0] and gained in range(step[1],step[2]+1),"normal gate commit rolls the displayed recovery range")
		check(int(ally.hp)-ally_before==gained,"gate recovery shares its roll")
		game.damage_player(1,player,28)
		game.damage_player(2,ally,28)
	check(player.hp<48 and player.hp>0,"two gates offset part of two deep contacts without resetting attrition")


func add_enemy(at: Vector3, summoned: bool=false) -> Dictionary:
	var mob: Dictionary=game.make_scout(0,at,game.scouts.size()+1)
	mob.summoned=summoned
	game.scouts.append(mob)
	return mob


func finish_scout(summoned: bool, now: int) -> void:
	game.scouts.clear()
	add_enemy(Vector3(0,0,-1),summoned)
	game.apply_weapon_hit(player,0,player.pos,{"damage":9.0,"heal_on_kill":1.0,"knockback":-.35},now)


func kill_budget() -> void:
	arena()
	player.hp=99
	finish_scout(false,1000)
	check(player.hp==100 and Sustain.kill_remaining(player,game.combat_epoch)==23,"overheal spends only actual HP")
	player.hp=20
	var state := Preview.heal_rng.state
	finish_scout(true,2000)
	check(player.hp==20 and Preview.heal_rng.state==state,"a summoned kill cannot roll or consume the budget")
	for index in 5:
		finish_scout(false,3000+index*100)
	check(player.hp==43 and Sustain.kill_remaining(player,game.combat_epoch)==0,"large packs cannot exceed the per-floor kill heal budget")
	player.graft_part=game.Parts.monster_part(6)
	var stats: Dictionary=game.weapon_stats(player)
	check(stats.heal_on_kill>0 and stats.kill_heal_remaining==0,"owner stats expose the remaining budget")
	var view:=Summary.project(game,player,stats)
	check(view.totals.has(["Kill healing left this floor","0 / 24 HP"]),"Tab shows the exhausted floor budget")
	game.combat_epoch+=1
	check(Sustain.kill_remaining(player,game.combat_epoch)==24,"the next floor renews the budget")


func pulse_and_refresh() -> void:
	arena()
	game.enemy_pos=player.pos
	var stats := {"tide_pool":2.0}
	player.tide_ready=0
	game.Traits.after_hit(game,player,-1,stats,1000,false)
	game.Traits.tick(game,1000)
	var amount:=int(player.hp)-30
	check(amount in range(7,10) and ally.hp==player.hp,"boosted Tide pool has a scaled shared pulse")
	check(game.Traits.describe(stats,true).contains("7–9 HP per pulse"),"pool tooltip matches the live scaled band")
	game.Traits.tick(game,1500)
	check(int(player.hp)-30==amount,"pool cannot heal between pulses")
	Sustain.begin_renewal(player,2000,4200,1000)
	Sustain.begin_renewal(player,2650,3000,1000)
	check(player.renewal_tick==3000 and player.renewal_until==6200,"refresh cannot postpone a tick or shorten the effect")
	var before:=int(player.hp)
	game.update_support_effects(3000)
	check(int(player.hp)-before in range(3,6) and player.renewal_tick==4000,"refresh keeps the due Renewal tick")


func drains() -> void:
	arena()
	game.enemy_pos=Vector3(15,0,0)
	player.frame=3
	var summon:=add_enemy(Vector3(0,0,-1),true)
	game.use_class_skill(1,player,1)
	check(summon.hp<summon.max_hp and player.hp==30,"Siphon Cut damages a summon without drawing health")
	arena()
	game.enemy_pos=Vector3(15,0,0)
	player.weapon=game.Parts.index_of("plant:bloodbriar")
	summon=add_enemy(Vector3(0,0,-1.8),true)
	var ordinary:=add_enemy(Vector3(.3,0,-2.3))
	game.garden_action(1,Core.request(game,player,Vector2.UP,2.0))
	var cast: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
	check(not cast.is_empty(),"Blood Siphon commits")
	if cast.is_empty():return
	Core.tick(game,cast.armed)
	check(summon.hp<summon.max_hp and ordinary.hp<ordinary.max_hp and int(player.hp)-30 in range(5,8),"Blood Siphon rolls only around the regular enemy contact")


func revival() -> void:
	arena()
	game.encounter_number=3
	game.enemy_hp=0
	player.pos=game.battlefield.advance
	ally.pos=player.pos
	player.offer_floor=3
	player.last_offer=0
	player[game.ExpeditionWallet.STATE] = game.ExpeditionWallet.Wallet.new(500, game.wallet_for(player).spent_essence())
	player.checkpoint_offers=["class_0_0","power","reach"]
	check(game.buy_upgrade(1,player,0) and player.max_hp==120 and player.hp==50,"checkpoint bonus grants exact new capacity")
	game.damage_player(1,player,int(player.hp))
	check(Sustain.restore(game,player,12,"fixture")==0 and player.fallen,"ordinary healing cannot revive a fallen player")
	check(game.spectator_view.focus_id(1)==2 and game.spectator_view.caption.text.contains("30 / 100 HP") and game.spectator_view.panel.position.y>=110,"spectating shows ally health below the floor tracker")
	check(game.Life.revive(game,2,1) and player.max_hp==100 and player.hp==100 and player.lost_health==20,"revival retains earned capacity and seals exactly 20 HP")
	check(Orb.fractions(player.hp,player.max_hp,player.lost_health).is_equal_approx(Vector2(5.0/6.0,5.0/6.0)),"sealed segment is measured from the upgraded ceiling")
	check(game.spectator_view.focus_id(1)==1 and not game.spectator_view.panel.visible,"revive returns camera and HUD control")


func overlap() -> void:
	arena()
	player.max_hp=80
	player.lost_health=20
	player.hp=78
	check(Sustain.restore(game,player,12,"fixture")==2,"healing reports actual restoration after the cap")
	game.damage_player(1,player,2)
	check(player.hp==78,"coincident heals and hits preserve the final net value")
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
