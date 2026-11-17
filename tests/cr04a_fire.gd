extends SceneTree

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")
const PlayerLifecycle = preload("res://player_lifecycle.gd")

const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Rules = preload("res://combat_ruleset.gd")
const Fire = preload("res://fire_combat.gd")
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
		printerr("FAIL Fire: ", label)


func reset() -> void:
	game.encounter.set_hp(-1, 500)
	game.enemy_mutations = 0
	game.tactics.boss_kind = -1
	game.tactics.position = Vector3(0,0,-1.25)
	game.tactics.winding_up = false
	game.tactics.memory.clear()
	game.encounter.clear_scouts()
	game.set_meta(Clock.CLOCK, 0.0)
	Core.reset(game)


func run() -> void:
	game = preload("res://world.tscn").instantiate()
	game.set_meta(Rules.META, Rules.ID)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	game.battlefield.barriers.clear()
	game.add_player(2)
	for player in game.players.values():
		ExpeditionCase.set_membership(game, player, true)
		player[PlayerVitals.STATE] = player[PlayerVitals.STATE].with_hp(90)
		player.pos = Vector3.ZERO
	for pair in [["part_6","plant_part_rare_ember_fern"],["part_7","plant_part_rare_cinder_vine"],["part_15","plant_part_rare_sun_spire"]]:
		for item in pair:
			var part_id: int = game.Items.get_item(item).legacy_part
			for slot in ["core","form","catalyst"]:
				var resolved := Builds.slot(slot,part_id)
				check(resolved.executable and resolved.affinity_core_skill_id=="ember_wake", item+" has Ember Wake family in "+slot)
	for item in ["part_6","plant_part_rare_ember_fern"]:
		var part: int = game.Items.get_item(item).legacy_part
		var p: Dictionary = game.players[1]
		var q: Dictionary = Builds.slot("core",part).potency_profile.values
		var now := Time.get_ticks_msec()
		reset()
		p.weapon=part
		p.secondary=0
		p.catalyst=0
		p.core_ready_at=0
		p.core_cast_until=0
		p.cast_until=0
		game.garden_action(1,Core.request(game,p,Vector2.UP,1.25))
		var cast: Dictionary = game.get_meta(Core.STATE,{}).get(1,{})
		check(not cast.is_empty(),"real B starts Ember Wake")
		if not cast.is_empty():
			Core.tick(game,cast.armed)
			check(game.enemy_health()==500-q.impact_hp-q.tick_hp,"one impact and immediate first tick")
			game.tactics.position=Vector3(3,0,-1.25)
			Clock.advance(game,.75)
			Core.tick(game,int(cast.armed)+750)
			Fire.tick(game,750,int(cast.armed)+750)
			check(game.enemy_health()==500-q.impact_hp-2*q.tick_hp,"burn persists outside the field")
			game.tactics.position=Vector3(0,0,-1.25)
			Clock.advance(game,.1)
			Core.tick(game,int(cast.armed)+850)
			check(game.enemy_health()==500-q.impact_hp-2*q.tick_hp and game.tactics.memory[Fire.BURNING]["1/core"].next==1500,
				"re-entry refreshes without replaying impact or postponing scheduled tick")
		reset()
		p.weapon=0
		p.secondary=part
		p.core_cast_until=0
		p.cast_until=0
		p.strike_at=0
		p.facing=Vector3.FORWARD
		game.strike_enemy(1,p,p.pos)
		var shot: Dictionary=game.projectile_queue.front()
		game.update_projectiles(int(shot.due)+1)
		check(game.tactics.memory.get(Fire.BURNING,{}).get("1/form",{}).get("hp",0)==q.tick_hp,"real direct hit applies Form potency")
		var after: int=game.enemy_health()
		Events.contact(game,shot.stats,-1,now)
		Events.contact(game,shot.stats,-1,now,true)
		check(game.enemy_health()==after,"duplicate contact and secondary damage do not burn")
		var material := Builds.slot("form",part)
		var refresh := Events.begin(game,1,"form",material,q,["weapon_contact"],now+15000)
		Clock.advance(game,.5)
		refresh.publish(game,"weapon_contact","new","leader",now,{"enemy":-1})
		check(game.enemy_health()==after and game.tactics.memory[Fire.BURNING]["1/form"].next==750,"same source refresh preserves cadence")
		var other := Events.begin(game,2,"form",material,q,["weapon_contact"],now+15000)
		other.publish(game,"weapon_contact","new","leader",now,{"enemy":-1})
		check(game.enemy_health()==after-q.tick_hp,"another player has an independent Form")
		p.secondary=0
		p.catalyst=part
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
		game.use_class_skill(1,p,1)
		check(game.tactics.memory.get(Fire.BURNING,{}).get("1/catalyst",{}).get("hp",0)==q.tick_hp,"native offensive class contact adds separate Catalyst burn")
		reset()
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
		p.hurt_until=0
		p.guard_until=0
		p.guard_charges=0
		game.use_class_skill(1,p,0)
		var hp_before: float=p[PlayerVitals.STATE].hp()
		IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(p), Time.get_ticks_msec(), 1.0, 0, game.tactics.position)
		check(game.enemy_health()==500-q.burst_hp-q.tick_hp and p[PlayerVitals.STATE].hp()==hp_before,"Ward uses selected Catalyst without changing native prevention")
		reset()
		p.frame=4
		p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(50)
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
		var ally: Dictionary=game.players[2]
		ally.guard_until=0
		ally.hurt_until=0
		game.use_class_skill(1,p,0)
		check(ally.has(Fire.RESPONSE),"native Oracle renewal grants Fire response with caster provenance")
		var frost=preload("res://frost_combat.gd")
		var hit_now:=Time.get_ticks_msec()
		frost.with_attacker(game,-1,IncomingPlayerHit.resolve_world.bind(game, 2, PlayerLifecycle.generation(ally), hit_now, 1.0, 0, game.tactics.position))
		check(not ally.has(Fire.RESPONSE) and game.tactics.memory.get(Fire.BURNING,{}).get("1/catalyst",{}).get("hp",0)==q.tick_hp,"survived incoming enemy hit uses source once")
		var after_response: int=game.enemy_health()
		ally.hurt_until=0
		frost.with_attacker(game,-1,IncomingPlayerHit.resolve_world.bind(game, 2, PlayerLifecycle.generation(ally), hit_now, 1.0, 0, game.tactics.position))
		check(game.enemy_health()==after_response,"spent Ember Response does not stockpile")
		p.frame=0
	game.queue_free()
	await process_frame
	if not failed: print("PASS: Fire mappings, Core field, Form refresh, independent sources, Catalyst and wards")
	quit(int(failed))
