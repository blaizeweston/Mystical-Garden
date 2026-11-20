extends SceneTree
const WeaponEventCase = preload("res://tests/support/weapon_event_case.gd")
const WeaponCase = preload("res://tests/support/weapon_attack_case.gd")
const ClassActions = preload("res://native_class_actions.gd")
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

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
	for actor in game.players.values():
		preload("res://oracle_combat.gd").clear(actor)
		actor[Protection.STATE] = actor[Protection.STATE].clear_guard()

		actor[Protection.STATE] = actor[Protection.STATE].clear_expedition()
	game.effect_timeline.clear_native()
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

	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
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
		equip_native_focus(p)
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
		var cast: Dictionary = game.effect_timeline.core_records().get(1,{})
		check(not cast.is_empty(),"real B starts Ember Wake")
		if not cast.is_empty():
			Core.tick(game,cast.armed)
			check(game.enemy_health()==500-q.impact_hp-floori((Fire.APPLICATION_STACKS.core+q.stack_bonus)*Fire.TICK_HP_PER_STACK),"one impact and immediate first tick")
			game.tactics.position=Vector3(3,0,-1.25)
			Clock.advance(game,.75)
			Core.tick(game,int(cast.armed)+750)
			Fire.tick(game,750,int(cast.armed)+750)
			check(game.enemy_health()==500-q.impact_hp-floori((4*(Fire.APPLICATION_STACKS.core+q.stack_bonus)-2*Fire.DECAY_STACKS)*Fire.TICK_HP_PER_STACK),"burn persists outside the field")
			game.tactics.position=Vector3(0,0,-1.25)
			Clock.advance(game,.1)
			Core.tick(game,int(cast.armed)+850)
			check(game.enemy_health()==500-q.impact_hp-floori((4*(Fire.APPLICATION_STACKS.core+q.stack_bonus)-2*Fire.DECAY_STACKS)*Fire.TICK_HP_PER_STACK) and game.tactics.memory[Fire.BURNING].next==1000,
				"re-entry refreshes without replaying impact or postponing scheduled tick")
		reset()
		p.weapon=0
		p.secondary=part
		p.core_cast_until=0
		p.cast_until=0
		p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
		p.facing=Vector3.FORWARD
		var replay_context := WeaponEventCase.start(game,1,p.pos)
		var shot: Dictionary=game.weapon_attacks.views().front()
		WeaponCase.advance(game,int(shot.due)+1)
		check(Fire.count(game.tactics.memory.get(Fire.BURNING,{}))==Fire.APPLICATION_STACKS.form+q.stack_bonus,"real direct hit applies Form potency")
		var after: int=game.enemy_health()
		Events.contact(game,replay_context,-1,now)
		Events.contact(game,replay_context,-1,now,true)
		check(game.enemy_health()==after,"duplicate contact and secondary damage do not burn")
		var material := Builds.slot("form",part)
		var refresh := Events.begin(game,1,"form",material,q,["weapon_contact"],now+15000)
		Clock.advance(game,.5)
		refresh.publish(game,"weapon_contact","new","leader",now,{"enemy":-1})
		check(game.enemy_health()==after-2 and game.tactics.memory[Fire.BURNING].next==750,"source refresh adds stacks while preserving the shared cadence")
		var before_other: int=game.enemy_health()
		var other := Events.begin(game,2,"form",material,q,["weapon_contact"],now+15000)
		other.publish(game,"weapon_contact","new","leader",now,{"enemy":-1})
		check(game.enemy_health()==before_other and game.tactics.memory[Fire.BURNING].contributors.size()==2,"another player contributes without starting another Burning clock")
		p.secondary=0
		p.catalyst=part
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
		var before_catalyst: int=Fire.count(game.tactics.memory[Fire.BURNING])
		ClassActions.cast_world(game, 1, 1)
		check(Fire.count(game.tactics.memory.get(Fire.BURNING,{}))==before_catalyst+Fire.APPLICATION_STACKS.catalyst+q.stack_bonus,"native offensive class contact adds Catalyst stacks to the same effect")
		reset()
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
		p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
		p[Protection.STATE] = p[Protection.STATE].clear_expedition()
		ClassActions.cast_world(game, 1, 0)
		var hp_before: float=p[PlayerVitals.STATE].hp()
		IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(p), Time.get_ticks_msec(), 1.0, 0, game.tactics.position)
		check(game.enemy_health()==500-q.burst_hp-floori((Fire.APPLICATION_STACKS.catalyst+q.stack_bonus)*Fire.TICK_HP_PER_STACK) and p[PlayerVitals.STATE].hp()==hp_before,"Ward uses selected Catalyst without changing native prevention")
		reset()
		p.frame=4
		p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(50)
		p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
		var ally: Dictionary=game.players[2]
		ally[Protection.STATE] = ally[Protection.STATE].clear_guard()
		ally[Conditions.STATE] = ally[Conditions.STATE].clear_grace()
		p.class_aim=Vector3.FORWARD
		p.class_aim_distance=0.0
		ClassActions.cast_world(game, 1, 0)
		p.erase("class_aim")
		p.erase("class_aim_distance")
		check(ally.has(Fire.RESPONSE),"Living Sanctuary opening heal grants Fire response with caster provenance")
		var frost=preload("res://frost_combat.gd")
		var hit_now:=Time.get_ticks_msec()
		var before_native: float=ally[PlayerVitals.STATE].hp()
		frost.with_attacker(game,-1,IncomingPlayerHit.resolve_world.bind(game, 2, PlayerLifecycle.generation(ally), hit_now, 1.0, 0, game.tactics.position))
		check(not ally.has(Fire.RESPONSE) and Fire.count(game.tactics.memory.get(Fire.BURNING,{}))==Fire.APPLICATION_STACKS.catalyst+q.stack_bonus,"survived incoming enemy hit uses source once")
		check(ally[PlayerVitals.STATE].hp()==before_native-10+6,"native Second Breath independently restores 6 HP without changing Fire potency")
		var after_response: int=game.enemy_health()
		ally[Conditions.STATE] = ally[Conditions.STATE].clear_grace()
		frost.with_attacker(game,-1,IncomingPlayerHit.resolve_world.bind(game, 2, PlayerLifecycle.generation(ally), hit_now, 1.0, 0, game.tactics.position))
		check(game.enemy_health()==after_response,"spent Ember Response does not stockpile")
		game.effect_timeline.advance_native(game.native_effects_world,hit_now+1100)
		check(not ally.has(Fire.RESPONSE),"Sanctuary field pulses do not regrant the opening Ember Response")
		p.frame=0
	game.queue_free()
	await process_frame
	if not failed: print("PASS: Fire mappings, Core field, Form refresh, shared sources, Catalyst and wards")
	quit(int(failed))


## Family fixtures use the current native focus kit, never historical learned masks.
func equip_native_focus(player: Dictionary) -> void:
	for class_id in game.Classes.DEFINITIONS.size():
		var tree: RefCounted=game.Classes.connected_tree(class_id)
		var focus: String="rootkeeper" if class_id==0 else "lifekeeper" if class_id==4 else str(tree.nodes[0].id)
		player.character[tree.profile_key]=tree.state([focus])
