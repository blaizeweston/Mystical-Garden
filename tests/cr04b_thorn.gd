extends SceneTree

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
	game.enemy_hp=500
	game.enemy_pos=Vector3(0,0,-1.3)
	game.enemy_mutations=0
	game.boss_kind=-1
	game.enemy_winding_up=false
	game.leader_brain.clear()
	game.scouts.clear()
	game.projectile_queue.clear()
	game.trait_events.clear()
	Core.reset(game)
	if game.has_meta(Thorn.FIELDS):game.remove_meta(Thorn.FIELDS)
	game.set_meta(Clock.CLOCK,0.0)
	p.erase(Thorn.FORM_READY)
	p.weapon=0
	p.secondary=0
	p.catalyst=0
	p.frame=0
	p.pos=Vector3.ZERO
	p[PlayerVitals.STATE] = p[PlayerVitals.STATE].with_hp(90)
	p.facing=Vector3.FORWARD
	p.core_ready_at=0
	p.core_cast_until=0
	p.cast_until=0
	p.strike_at=0
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.Q, 0)
	p[Cooldowns.STATE] = p[Cooldowns.STATE].with_deadline(Cooldowns.R, 0)
	p.hurt_until=0
	p.guard_charges=0
	p.guard_until=0

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
	p.wild=true
	var ally: Dictionary=game.players[2]
	ally.wild=true
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
			check(is_equal_approx(game.leader_brain.get(Thorn.SLOW,0.0),q.slow) and game.enemy_hp==500,"existing occupant is immediately slowed with no separate impact damage")
			var original: Vector3=game.enemy_pos
			game.enemy_pos=Vector3(0,0,-3.4)
			Thorn.tick(game,Clock.advance(game,.5),now)
			check(not game.leader_brain.has(Thorn.SLOW) and game.leader_brain.has(Thorn.BLEED),"exit removes field slow alone")
			game.enemy_pos=original
			game.scouts.append(game.make_scout(0,original+Vector3.RIGHT,0))
			Thorn.tick(game,Clock.advance(game,.24),now)
			check(game.enemy_hp==500-q.tick_hp and game.scouts[0].has(Thorn.BLEED),"re-entry maintains original tick and a later entrant receives its own wound")
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
			game.enemy_pos=Vector3(0,0,-4)
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
		game.use_class_skill(1,p,0)
		check(Thorn.active_fields(game,Clock.now(game)).size()==1,"native group heal plants one patch")
		game.update_support_effects(now+1500)
		check(Thorn.active_fields(game,Clock.now(game)).size()==1,"renewal ticks do not grow more patches")
		reset(p)
		p.catalyst=part
		p.frame=2
		var retreat_index: int=game.Classes.DEFINITIONS[2].nodes.find_custom(func(node):return node.id=="10")
		var old_mask: int=p.character.upgrades[2]
		p.character.upgrades[2]=1<<retreat_index
		game.use_class_skill(1,p,1)
		var departure:=Thorn.active_fields(game,Clock.now(game))
		check(departure.size()==1 and departure[0].center==Vector3.ZERO and p.pos.length()>.5,"native Ranger retreat leaves a departure patch")
		p.character.upgrades[2]=old_mask
		reset(p)
		p.catalyst=part
		game.use_class_skill(1,p,0)
		check(Thorn.active_fields(game,Clock.now(game)).is_empty(),"Ward grant does not plant")
		game.apply_enemy_hit(1,p,now,1.0,0,game.enemy_pos)
		check(Thorn.active_fields(game,Clock.now(game)).size()==1,"actual Ward block plants lingering growth once")

	reset(p)
	var ordinary:=event(1,"catalyst","part_1","actual_block",now)
	var refined:=event(2,"catalyst","part_5","actual_block",now)
	var point: Vector3=game.enemy_pos
	for key in ["first","second"]:
		ordinary.publish(game,"actual_block","ward",key,now,{"center":point})
	refined.publish(game,"actual_block","ward","other",now,{"center":point+Vector3.RIGHT*1.8})
	check(game.leader_brain.get(Thorn.BLEED,{}).size()==2 and is_equal_approx(Frost.motion_scale(game.leader_brain,now),.73),"overlap resolves strongest slow and one wound per source and slot")
	var fire:=event(1,"form","part_6","weapon_contact",now)
	fire.publish(game,"weapon_contact","hit","leader",now,{"enemy":-1})
	game.leader_brain[Frost.BRITTLE]={"expires":now+10000,"slow":.08}
	Water.cleanse(p)
	check(game.leader_brain.has(Fire.BURNING) and game.leader_brain.has(Frost.BRITTLE) and game.leader_brain.has(Thorn.BLEED),"Fire, Frost, Thorn and ordinary Slow cleanse stay independent")
	game.enemy_pos=point+Vector3.LEFT
	Thorn.tick(game,Clock.advance(game,.72),now)
	check(game.enemy_hp==500-4-4-6 and is_equal_approx(Frost.motion_scale(game.leader_brain,now),.82),"leaving stronger growth retains the remaining slow and both scheduled wounds")
	game.queue_free()
	await process_frame
	if not failed:print("PASS: Thorn affinity mapping, real casts/weapon/Class/Ward, occupancy, overlap, cadence and limits")
	quit(int(failed))
