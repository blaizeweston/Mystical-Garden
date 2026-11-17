extends SceneTree

const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Rules = preload("res://combat_ruleset.gd")
const Water = preload("res://water_combat.gd")
const Fire = preload("res://fire_combat.gd")
const Frost = preload("res://frost_combat.gd")
const Clock = preload("res://affinity_time.gd")
const Events = preload("res://combat_action_events.gd")
const Core = preload("res://core_combat.gd")
const Builds = preload("res://affinity_build.gd")
var failed := false
var game: Node


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL Water: ", label)


func event(id: int, slot: String, item: String, channel: String, now: int) -> RefCounted:
	var part: int = game.Items.get_item(item).legacy_part
	var material := Builds.slot(slot,part)
	return Events.begin(game,id,slot,material,material.potency_profile.values,[channel],now+15000)


func reset() -> void:
	game.encounter.set_hp(-1, 500)
	game.enemy_mutations=0
	game.boss_kind=-1
	game.enemy_pos=Vector3(0,0,-1.35)
	game.enemy_winding_up=false
	game.leader_brain.clear()
	game.encounter.clear_scouts()
	game.set_meta(Clock.CLOCK,0.0)
	Core.reset(game)


func run() -> void:
	game=preload("res://world.tscn").instantiate()
	game.set_meta(Rules.META,Rules.ID)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	game.add_player(2)
	var p: Dictionary=game.players[1]
	var ally: Dictionary=game.players[2]
	p.wild=true
	ally.wild=true
	p.pos=Vector3.ZERO
	ally.pos=Vector3(0,0,-1.3)
	for pair in [["part_8","plant_part_rare_dewcap"],["plant_part_plant_tide_lily","plant_part_rare_tide_lily"]]:
		for item in pair:
			for slot in ["core","form","catalyst"]:
				var material := Builds.slot(slot,game.Items.get_item(item).legacy_part)
				check(material.executable and material.affinity_core_skill_id=="dewfall",item+" maps to Dewfall in "+slot)
	for item in ["part_8","plant_part_rare_dewcap"]:
		var part: int=game.Items.get_item(item).legacy_part
		var now:=Time.get_ticks_msec()
		var q: Dictionary=Builds.slot("core",part).potency_profile.values
		reset()
		p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(70)
		ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(60)
		p.slow_until=now+5000
		ally.slow_until=now+5000
		ally.frost_root_until=now+3000
		game.leader_brain[Frost.BRITTLE]={"stacks":[],"expires":now+10000,"slow":.2}
		game.leader_brain.frost_root_until=now+600
		p.weapon=part
		p.secondary=0
		p.catalyst=0
		p.core_ready_at=0
		p.core_cast_until=0
		p.cast_until=0
		game.garden_action(1,Core.request(game,p,Vector2.UP,1.5))
		var cast: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
		check(not cast.is_empty(),"real B starts Dewfall")
		if not cast.is_empty():
			Core.tick(game,cast.armed)
			check(p.slow_until==0 and ally.slow_until>now and p[PlayerVitals.STATE].hp()==70,"cleanse caster at formation, no baseline healing")
			Clock.advance(game,.4)
			Core.tick(game,int(cast.armed)+400)
			check(ally.slow_until==0 and ally.frost_root_until>now and ally[PlayerVitals.STATE].hp()==60 and game.enemy_health()==500-q.impact_hp and game.leader_brain.has(Frost.BRITTLE) and game.leader_brain.frost_root_until==now+600,
				"swept wave cleanses actual ally, damages once, preserves other status and health")
			ally.slow_until=now+10000
			Clock.advance(game,.12)
			Core.tick(game,int(cast.armed)+520)
			check(ally.slow_until>now and game.enemy_health()==500-q.impact_hp,"consumed contacts never repeat on same cast")
		reset()
		p.weapon=0
		p.secondary=part
		p.catalyst=0
		p.core_cast_until=0
		p.cast_until=0
		p.strike_at=0
		p.facing=Vector3.FORWARD
		game.strike_enemy(1,p,p.pos)
		var shot: Dictionary=game.projectile_queue.front()
		game.update_projectiles(int(shot.due)+1)
		check(is_equal_approx(Water.reduction(game.leader_brain,Clock.now(game)),q.reduction),"real Form contact gives exact quality reduction")
		p.secondary=0
		p.catalyst=part
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
		game.use_class_skill(1,p,1)
		check(game.leader_brain.get(Water.DRENCHED,{}).size()==2,"native class contact contributes a separate Drenched Catalyst")
		check(is_equal_approx(Water.reduction(game.leader_brain,Clock.now(game)),q.reduction),"same potency is not multiplied")
		reset()
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
		p.guard_until=0
		p.guard_charges=0
		p.hurt_until=0
		p.slow_until=now+6000
		ally.slow_until=now+6000
		game.use_class_skill(1,p,0)
		game.apply_enemy_hit(1,p,Time.get_ticks_msec(),1.0,0,game.enemy_pos)
		check(p.slow_until==0 and ally.slow_until==0 and p[PlayerVitals.STATE].hp()==70 and is_equal_approx(Water.reduction(game.leader_brain,Clock.now(game)),q.reduction),"Ward wash Drenches enemies and cleanses protected allies")

	reset()
	var now:=Time.get_ticks_msec()
	var scout: Dictionary=game.make_scout(1,Vector3(0,0,2),0,0)
	game.encounter.register_scout(scout)
	var attack=preload("res://enemy_attack.gd")
	var damage: float=game.Director.Balance.scout_hit(game,game.Enemies.get_kind(1),scout)
	var baseline: int=game.Life.Preview.effect_hp(game.Life.Preview.authored_amount(damage))
	p.guard_until=0
	p.guard_charges=0
	p.hurt_until=0
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(90)
	attack.lock(game,scout,"volley",p.pos,now+500)
	var strong := event(1,"core","plant_part_rare_dewcap","core_action",now)
	Water.drench(game,strong,0)
	game.update_scouts(0.0,now+500)
	check(p[PlayerVitals.STATE].hp()==90-roundi(baseline*.70),"locked native ranged attack reads reduction at hit, after commitment")
	Clock.advance(game,2.0)
	var weak := event(2,"form","part_8","weapon_contact",now)
	weak.publish(game,"weapon_contact","new","scout",now,{"enemy":0})
	check(is_equal_approx(Water.reduction(scout,Clock.now(game)),.30),"weaker application cannot override stronger")
	attack.lock(game,scout,"volley",p.pos,now+4400)
	Clock.advance(game,2.3)
	p.hurt_until=0
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(90)
	game.update_scouts(0.0,now+4400)
	check(p[PlayerVitals.STATE].hp()==90-roundi(baseline*.82),"weaker source survives stronger expiry during attack")
	attack.lock(game,scout,"volley",p.pos,now+6500)
	Clock.advance(game,2.1)
	p.hurt_until=0
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(90)
	game.update_scouts(0.0,now+6500)
	check(p[PlayerVitals.STATE].hp()==90-baseline,"all effects expired before impact")
	p.hurt_until=0
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(90)
	Water.drench(game,strong,0)
	game.apply_enemy_hit(1,p,now+7800,damage,0,scout.pos)
	check(p[PlayerVitals.STATE].hp()==90-baseline,"unattributed hazard unaffected by Drenched enemy")

	reset()
	var adapter := {"id":"fixture_ward","trigger":"block","limit":"recipient"}
	var fire := event(1,"catalyst","part_6","actual_block",now)
	var water := event(2,"catalyst","plant_part_rare_dewcap","actual_block",now)
	p.guard_until=0
	p.guard_charges=0
	p.hurt_until=0
	Events.grant_ward(game,p,now+1000,1,fire,adapter,now)
	Events.grant_ward(game,p,now+2000,2,water,adapter,now)
	game.apply_enemy_hit(1,p,now+1,1.0,0,game.enemy_pos)
	check(game.leader_brain.get(Fire.BURNING,{}).has("1/catalyst") and Water.reduction(game.leader_brain,Clock.now(game))==0.0,"earliest mixed Ward selects ordinary Fire")
	game.apply_enemy_hit(1,p,now+2,1.0,0,game.enemy_pos)
	check(is_equal_approx(Water.reduction(game.leader_brain,Clock.now(game)),.30) and p.guard_charges==0,"next actual block is refined Water without removing Fire")
	game.queue_free()
	await process_frame
	if not failed: print("PASS: Water Core, Form, class wash, mixed Ward claims, direct damage and ranged timing")
	quit(int(failed))
