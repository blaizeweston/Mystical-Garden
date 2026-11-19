extends SceneTree
const Conditions = preload("res://player_hit_conditions.gd")
const Protection = preload("res://player_protection.gd")

const WeaponActions = preload("res://player_weapon_actions.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Cooldowns = preload("res://player_cooldowns.gd")

const Rules = preload("res://combat_ruleset.gd")
const Builds = preload("res://affinity_build.gd")
const Core = preload("res://core_combat.gd")
const Thorn = preload("res://thorn_affinity.gd")
const Clock = preload("res://affinity_time.gd")
const Fire = preload("res://fire_combat.gd")
const Frost = preload("res://frost_combat.gd")
const Water = preload("res://water_combat.gd")
const Events = preload("res://combat_action_events.gd")
var game: Node
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed=true
		printerr("FAIL Thorn: ",label)

func event(id: int, slot: String, item: String, channel: String, now: int) -> RefCounted:
	var part: int=game.Items.get_item(item).legacy_part
	var material := Builds.slot(slot,part)
	return Events.begin(game,id,slot,material,material.potency_profile.values,[channel],now+30000)

func reset(p: Dictionary) -> void:
	game.encounter.set_hp(-1, 500)
	game.tactics.position=Vector3(0,0,-1.3)
	game.enemy_mutations=0
	game.tactics.boss_kind=-1
	game.tactics.winding_up=false
	game.tactics.memory.clear()
	game.encounter.clear_scouts()
	game.projectile_queue.clear()
	game.trait_events.clear()
	Core.reset(game)
	if game.has_meta(Thorn.FIELDS):game.remove_meta(Thorn.FIELDS)
	game.set_meta(Clock.CLOCK,0.0)
	p.erase(Thorn.FORM_READY)
	preload("res://oracle_combat.gd").clear(p)
	p[Protection.STATE] = p[Protection.STATE].clear_guard()
	p.weapon=0
	p.secondary=0
	p.catalyst=0
	p.frame=0
	p.character=game.Character.blank()
	var tree=game.Classes.connected_tree(0)
	p.character[tree.profile_key]=tree.state(["rootkeeper"])
	p.pos=Vector3.ZERO
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(90)
	p.facing=Vector3.FORWARD
	p.core_ready_at=0
	p.core_cast_until=0
	p.cast_until=0
	p[WeaponActions.STATE] = p[WeaponActions.STATE].with_ready_at(0)
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	p[Conditions.STATE] = p[Conditions.STATE].clear_grace()
	p[Protection.STATE] = p[Protection.STATE].clear_expedition()
	p[Protection.STATE] = p[Protection.STATE].clear_guard()

func run() -> void:
	game=preload("res://world.tscn").instantiate()

	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.battlefield.configure(0,1,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.add_player(2)
	var p: Dictionary=game.players[1]
	ExpeditionCase.set_membership(game, p, true)
	var ally: Dictionary=game.players[2]
	ExpeditionCase.set_membership(game, ally, true)
	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(90)
	ally.pos=Vector3.ZERO
	var count:=0
	for part in game.Parts.DEFINITIONS.size():
		var identity:=Builds.Affinities.for_part(part)
		if identity.get("primary_affinity")!="thorn":
			continue
		count+=1
		for slot in ["core","form","catalyst"]:
			var material:=Builds.slot(slot,part)
			check(material.executable and material.affinity_core_skill_id=="thorn_line",str(identity.item_id)+" resolves the Thorn family")
	check(count==10,"all five Thorn species have two executable qualities")
	check(Builds.slot("core",game.Items.get_item("part_5").legacy_part).supporting_affinities==["piercing"],"Heartwood Barb remains refined Thorn Bloom")
	var now:=Time.get_ticks_msec()
	for item in ["part_1","part_5"]:
		reset(p)
		var part: int=game.Items.get_item(item).legacy_part
		var q: Dictionary=Builds.slot("core",part).potency_profile.values
		p.weapon=part
		game.garden_action(1,Core.request(game,p,Vector2.UP,1.3))
		var cast: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
		check(not cast.is_empty(),"native B prepares Thorn Line")
		if not cast.is_empty():
			Core.tick(game,cast.armed)
			check(is_equal_approx(game.tactics.memory.get(Thorn.SLOW,0.0),q.slow) and game.enemy_health()==500,"existing occupant is immediately slowed with no separate impact damage")
			var original: Vector3=game.tactics.position
			game.tactics.position=Vector3(0,0,-3.4)
			Thorn.tick(game,Clock.advance(game,.5),now)
			check(not game.tactics.memory.has(Thorn.SLOW) and game.tactics.memory.has(Thorn.BLEED),"exit removes field slow alone")
			game.tactics.position=original
			game.encounter.register_scout(game.make_scout(0,original+Vector3.RIGHT,0))
			Thorn.tick(game,Clock.advance(game,.24),now)
			check(game.enemy_health()==500-q.tick_hp and game.encounter.scout(0).has(Thorn.BLEED),"re-entry maintains original tick and a later entrant receives its own wound")
			check(Thorn.hints(game).size()==1 and game.battlefield.clear_line(Vector3.ZERO,original),"replicated shape leaves ally/navigation routes open")
		reset(p)
		p.secondary=part
		game.strike_enemy(1,p,p.pos)
		var shot: Dictionary=game.projectile_queue.front()
		game.update_projectiles(int(shot.due)+1)
		var fields:=Thorn.active_fields(game,Clock.now(game))
		check(fields.size()==1 and is_equal_approx(fields[0].slow,q.slow),"real first weapon hit creates quality-matched Form patch")
		if not fields.is_empty():
			var point: Vector3=fields[0].center
			game.tactics.position=Vector3(0,0,-4)
			Events.contact(game,shot.stats,-1,now)
			Events.contact(game,shot.stats,-1,now,true)
			fields=Thorn.active_fields(game,Clock.now(game))
			check(fields.size()==1 and fields[0].center==point,"patch remains stationary and duplicate/secondary contacts do not plant")
			for index in [1,2]:
				Clock.advance(game,2.1)
				var form:=event(1,"form",item,"weapon_contact",now)
				form.publish(game,"weapon_contact","hit",str(index),now,{"enemy":-1,"point":point+Vector3.RIGHT*.2*index})
			fields=Thorn.active_fields(game,Clock.now(game))
			check(fields.size()==2 and fields[0].center!=point,"third patch replaces the oldest within the slot limit")
		reset(p)
		p.catalyst=part
		game.use_class_skill(1,p,1)
		check(Thorn.active_fields(game,Clock.now(game)).size()==1,"offensive Q/R maps its effect area once")
		reset(p)
		p.catalyst=part
		p.frame=4
		var oracle=game.Classes.connected_tree(4)
		p.character[oracle.profile_key]=oracle.state(["lifekeeper"])
		p.class_aim=Vector3.FORWARD
		p.class_aim_distance=0.0
		game.use_class_skill(1,p,0)
		p.erase("class_aim")
		p.erase("class_aim_distance")
		check(Thorn.active_fields(game,Clock.now(game)).size()==1,"native group heal plants one patch")
		game.Traits.tick(game,now+1500)
		check(Thorn.active_fields(game,Clock.now(game)).size()==1,"Sanctuary updates do not grow more patches")
		reset(p)
		p.catalyst=part
		p.frame=2
		var ranger=game.Classes.connected_tree(2)
		p.character[ranger.profile_key]=ranger.state(["wayfarer"])
		game.use_class_skill(1,p,0)
		var departure:=Thorn.active_fields(game,Clock.now(game))
		check(departure.size()==1 and departure[0].center==Vector3.ZERO and p.pos.length()>.5,"native Ranger retreat leaves a departure patch")
		reset(p)
		p.catalyst=part
		game.use_class_skill(1,p,0)
		check(Thorn.active_fields(game,Clock.now(game)).is_empty(),"Ward grant does not plant")
		IncomingPlayerHit.resolve_world(game, 1, PlayerLifecycle.generation(p), now, 1.0, 0, game.tactics.position)
		check(Thorn.active_fields(game,Clock.now(game)).size()==1,"actual Ward block plants lingering growth once")

	reset(p)
	var ordinary:=event(1,"catalyst","part_1","actual_block",now)
	var refined:=event(2,"catalyst","part_5","actual_block",now)
	var point: Vector3=game.tactics.position
	for key in ["first","second"]:
		ordinary.publish(game,"actual_block","ward",key,now,{"center":point})
	refined.publish(game,"actual_block","ward","other",now,{"center":point+Vector3.RIGHT*1.8})
	check(game.tactics.memory.get(Thorn.BLEED,{}).size()==2 and is_equal_approx(Frost.motion_scale(game.tactics.memory,now),.73),"overlap resolves strongest slow and one wound per source and slot")
	var fire:=event(1,"form","part_6","weapon_contact",now)
	fire.publish(game,"weapon_contact","hit","leader",now,{"enemy":-1})
	game.tactics.memory[Frost.BRITTLE]={"expires":now+10000,"slow":.08}
	Water.cleanse(p)
	check(game.tactics.memory.has(Fire.BURNING) and game.tactics.memory.has(Frost.BRITTLE) and game.tactics.memory.has(Thorn.BLEED),"Fire, Frost, Thorn and ordinary Slow cleanse stay independent")
	game.tactics.position=point+Vector3.LEFT
	Thorn.tick(game,Clock.advance(game,.72),now)
	check(game.enemy_health()==500-4-4-6 and is_equal_approx(Frost.motion_scale(game.tactics.memory,now),.82),"leaving stronger growth retains the remaining slow and both scheduled wounds")
	verify_bleed_lifecycle(p)
	game.queue_free()
	await process_frame
	if not failed:print("PASS: Thorn affinity mapping, real casts/weapon/Class/Ward, occupancy, overlap, cadence and limits")
	quit(int(failed))


func verify_bleed_lifecycle(player: Dictionary) -> void:
	reset(player)
	var now := Time.get_ticks_msec()
	var old_cast := event(1,"catalyst","part_1","class_contact",now)
	old_cast.publish(game,"class_contact","hit","leader",now,{"enemy":-1,"point":game.tactics.position})
	var original_life: PlayerLifecycle.Life = player[PlayerLifecycle.STATE]
	player[PlayerLifecycle.STATE] = original_life.fall()
	var tick_hp := int(Thorn.QUALITY.ordinary.tick_hp)
	Thorn.tick(game,Clock.advance(game,.72),now)
	check(Thorn.active_fields(game,Clock.now(game)).is_empty() and game.enemy_health()==500-tick_hp,
		"an accepted wound still ticks after the source falls")

	player[PlayerLifecycle.STATE] = PlayerLifecycle.start_life()
	var elapsed := Clock.advance(game,.2)
	var new_cast := event(1,"catalyst","part_1","class_contact",now)
	new_cast.publish(game,"class_contact","hit","leader",now,{"enemy":-1,"point":game.tactics.position})
	var wound: Dictionary = game.tactics.memory.get(Thorn.BLEED,{}).get("1/catalyst",{})
	check(int(wound.get("next",0))==elapsed+Thorn.TICK_MS
		and PlayerLifecycle.matches(player,int(wound.get("life",-1))),
		"a fresh source life starts its own bleed cadence")
	Thorn.tick(game,Clock.advance(game,.55),now)
	check(game.enemy_health()==500-tick_hp,"the replacement cannot inherit the previous tick deadline")
	Thorn.tick(game,Clock.advance(game,.20),now)
	check(game.enemy_health()==500-2*tick_hp,"the new wound ticks at its own deadline")
