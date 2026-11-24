extends SceneTree
const Effects = preload("res://enemy_affinity_effects.gd")

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const IncomingPlayerHit = preload("res://incoming_player_hit.gd")

const PlayerLifecycle = preload("res://player_lifecycle.gd")
const PlayerVitals = preload("res://player_vitals.gd")
const Mode=preload("res://combat_ruleset.gd")
const Builds=preload("res://affinity_build.gd")
const Events=preload("res://combat_action_events.gd")
const Void=preload("res://void_affinity.gd")
const Core=preload("res://core_combat.gd")
const Clock=preload("res://affinity_time.gd")
var failed:=false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failed=true;printerr("FAIL Void: ",label)

func action(game: Node, actor: int, slot: String, part: int, channels: Array) -> RefCounted:
	var material:=Builds.slot(slot,part)
	return Events.begin(game,actor,slot,material,material.potency_profile.values,channels,Time.get_ticks_msec()+10000)

func run() -> void:
	var game:=preload("res://world.tscn").instantiate()

	game.progress.path="user://cr04c-void/garden.cfg"
	game.local_character.path="user://cr04c-void/player.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary=game.players[1]
	ExpeditionCase.set_membership(game, p, true);SessionCase.set_ready(game, p, true);p.pos=Vector3(-4,0,0)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
	game.encounter.set_hp(-1, 200);game.tactics.position=Vector3(1.4,0,0)
	game.encounter.clear_scouts()
	var part: int=game.Items.get_item("part_14").legacy_part
	var refined: int=game.Items.get_item("plant_part_rare_void_willow").legacy_part
	var now:=Time.get_ticks_msec()
	var form:=action(game,1,"form",part,["weapon_contact"])
	game.tactics.winding_up=true
	Events.contact(game,{Events.CONTEXT:form},-1,now,false,game.tactics.position)
	Void.resolve_motion(game,0,now)
	check(game.enemy_health()==190 and game.tactics.position.x>1.39,"committed telegraph resists motion while contact still damages")
	game.tactics.winding_up=false
	p.erase(Void.FORM_READY)
	var stronger:=action(game,1,"form",refined,["weapon_contact"])
	Events.contact(game,{Events.CONTEXT:stronger,"knockback":.75},-1,now,false,game.tactics.position)
	Void.resolve_motion(game,0,now)
	check(game.enemy_health()==175 and not game.has_meta(Void.PENDING) and game.tactics.position.x>1.39,"refined damage survives native knockback conflict")
	game.add_player(2)
	var ally: Dictionary=game.players[2]
	ExpeditionCase.set_membership(game, ally, true);SessionCase.set_ready(game, ally, true);ally.pos=Vector3(7,0,7)
	var old_action:=action(game,2,"form",part,["weapon_contact"])
	Void.queue_motion(game,old_action,-1,Vector3(7,0,0),true,.7)
	ally[PlayerLifecycle.STATE]=PlayerLifecycle.start_life()
	Void.resolve_motion(game,0,now)
	check(is_equal_approx(game.tactics.position.x,1.4),"queued displacement cannot cross into a new source life")
	var second:=action(game,2,"form",part,["weapon_contact"])
	Void.queue_motion(game,second,-1,Vector3(7,0,0),true,.7)
	Void.queue_motion(game,form,-1,Vector3(-7,0,0),true,.7)
	Void.resolve_motion(game,0,now)
	check(is_equal_approx(game.tactics.position.x,.7),"same-tick opposing requests use source order, regardless of enqueue order")
	Void.queue_motion(game,second,-1,Vector3(7,0,0),true,.7)
	Void.resolve_motion(game,100,now)
	check(is_equal_approx(game.tactics.position.x,.7),"later opposite motion refused within rolling window")
	Void.queue_motion(game,form,-1,Vector3(-7,0,0),true,.7)
	Void.resolve_motion(game,100,now)
	check(is_equal_approx(game.tactics.position.x,.3),"multiple players share 1.10 m rolling allowance")
	p.erase(Void.FORM_READY)
	var spent:=action(game,1,"form",part,["weapon_contact"])
	Events.contact(game,{Events.CONTEXT:spent},-1,now,false,game.tactics.position)
	Void.resolve_motion(game,100,now)
	check(game.enemy_health()==165 and is_equal_approx(game.tactics.position.x,.3),"exhausted displacement allowance leaves valid bonus damage")
	game.encounter.set_hp(-1, 175)
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[Rect2(.65,-1,.40,2)])
	var blocked:=Void.safe_motion(game,-1,Vector3(-.45,0,0),Vector3(1.8,0,0))
	check(blocked.x<.65,"displacement trace cannot cross a solid wall")
	preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])

	game.tactics.position=Vector3(1.8,0,0)
	Effects.read(game,-1).erase(Void.ALLOWANCE_STATE)
	p.pos=Vector3(-2,0,0)
	p.weapon=refined
	var escaped: Dictionary=game.make_scout(0,Vector3(1,0,1.4),1)
	escaped.hp=120
	game.encounter.register_scout(escaped)
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT,2.0))
	var line: Dictionary=game.effect_timeline.core_records()[1]
	Core.tick(game,int(line.armed))
	Void.resolve_motion(game,Clock.now(game),int(line.armed))
	check(game.tactics.position.x<1.79 and game.enemy_health()==175 and not Core.hints(game).is_empty(),"real Core gathers with an active hint before damage")
	escaped.pos=Vector3(6,0,0)
	Clock.advance(game,1.2)
	Core.tick(game,int(line.armed)+1200)
	Core.tick(game,int(line.armed)+1201)
	check(game.enemy_health()==146 and game.encounter.hp_for(escaped)==120 and Core.hints(game).is_empty(),"refined collapse hits retained targets once and lets a fleeing target escape")
	Clock.advance(game,1.0)
	for material in [part,refined]:
		game.encounter.set_hp(-1, 200);game.tactics.position=Vector3(1.2,0,0)
		game.tactics.winding_up=true
		var ward:=action(game,1,"catalyst",material,["actual_block"])
		ward.publish(game,"actual_block","ward","1",now,{"recipient":1,"center":Vector3.ZERO})
		Void.resolve_motion(game,Clock.now(game),now)
		check(game.enemy_health()==(188 if material==part else 183) and is_equal_approx(game.tactics.position.x,1.2),
			"Catalyst pulses use source quality and cannot move a committed victim")
	game.tactics.winding_up=false
	game.encounter.set_hp(-1, 200);game.tactics.position=Vector3(1.4,0,0)
	p.core_ready_at=0;p.core_cast_until=0;p.cast_until=0;p.weapon=part
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT,2.0))
	line=game.effect_timeline.core_records()[1]
	Core.tick(game,int(line.armed))
	Clock.advance(game,1.2)
	Core.tick(game,int(line.armed)+1200)
	check(game.enemy_health()==179,"ordinary Core collapse keeps its own potency")
	Void.resolve_motion(game,Clock.now(game),now)
	check(Mode.FAMILIES.size()==9,"nine live families")
	for item in game.Parts.DEFINITIONS.size():
		if not game.Parts.is_plant(item):continue
		var build:=Builds.resolve(0,0,[item,item,item],p.character)
		check(build.core.executable and build.form.executable and build.catalyst.executable and not Builds.core_skill(build).is_empty(),
			"all plant qualities resolve three executable slots")

	var thorn = Mode.Thorn
	var fire = Mode.Fire
	var point := Vector3.ZERO
	var shape := preload("res://core_footprint.gd").area(point,1.0)
	var thorn_part: int=game.Items.get_item("part_1").legacy_part
	var fire_part: int=game.Items.get_item("plant_part_rare_cinder_vine").legacy_part
	var flames:=action(game,1,"core",fire_part,["core_action"])
	var thorns:=action(game,1,"core",thorn_part,["core_action"])
	var floor_ms:=Clock.now(game)
	game.tactics.position=Vector3(1.4,0,0)
	Effects.read(game,-1).erase(Void.ALLOWANCE_STATE)
	check(thorn.grow(game,thorns,point,[shape],now),"real Thorn contact area created")
	var trail: Dictionary={"grown":true,"field_until":floor_ms+3000,"next_maintain":floor_ms,"center":point,
		"shapes":[shape],"stack_ready":{},"affinity_action":flames}
	Void.queue_motion(game,form,-1,Vector3(-6,0,0),true,.7)
	Void.resolve_motion(game,floor_ms,now)
	thorn.tick(game,floor_ms,now)
	fire.field(game,trail,now)
	var after_entry: int=game.enemy_health()
	check(Effects.read(game,-1).has(thorn.SLOW) and Effects.read(game,-1).has(fire.BURNING) and after_entry<179,
		"Void displacement into real effect geometry applies Thorn occupancy and Fire entry")
	Clock.advance(game,.09)
	thorn.tick(game,Clock.now(game),now)
	fire.field(game,trail,now)
	check(game.enemy_health()==after_entry,"no duplicate entry damage while remaining inside")
	game.tactics.position=Vector3(3,0,0)
	thorn.tick(game,Clock.now(game),now)
	check(not Effects.read(game,-1).has(thorn.SLOW) and Effects.read(game,-1).has(thorn.BLEED),"leaving restores normal movement and keeps scheduled Bleed")

	ally[PlayerVitals.STATE] = ally[PlayerVitals.STATE].with_hp(100);ally.pos=Vector3.ZERO
	game.encounter.set_hp(-1, 200);game.tactics.position=Vector3.RIGHT
	Effects.read(game,-1).erase(Void.ALLOWANCE_STATE)
	var earlier:=action(game,1,"catalyst",part,["actual_block"])
	var storm_part: int=game.Items.get_item("plant_part_rare_storm_reed").legacy_part
	var later:=action(game,2,"catalyst",storm_part,["actual_block"])
	var adapter: Dictionary={"id":"test/ward","trigger":"block","limit":"recipient"}
	Events.grant_ward(game,ally,now+3000,1,earlier,adapter,now)
	Events.grant_ward(game,ally,now+5000,2,later,adapter,now)
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), now, 2, 0, game.tactics.position)
	check(ally[PlayerVitals.STATE].hp()==100 and game.enemy_health()==188,"single actual block selects earlier Void claim around the protected ally")
	IncomingPlayerHit.resolve_world(game, 2, PlayerLifecycle.generation(ally), now+1, 2, 0, game.tactics.position)
	check(ally[PlayerVitals.STATE].hp()==100 and game.enemy_health()==171,"next actual block selects separate refined Storm claim")
	Void.resolve_motion(game,Clock.now(game),now)

	for i in 19:
		game.encounter.register_scout(game.make_scout(0,Vector3(3.0+i%5,0,2.0+i/5.0),i+2))
	var elapsed:=Time.get_ticks_usec()
	for i in 120: Mode.Storm.nearest(game,Vector3.ZERO,3.0,{})
	var storm_us:=(Time.get_ticks_usec()-elapsed)/120.0
	elapsed=Time.get_ticks_usec()
	for i in 120: Mode.Spirit.step(game,1,Vector3.LEFT)
	var step_us:=(Time.get_ticks_usec()-elapsed)/120.0
	elapsed=Time.get_ticks_usec()
	for i in 120: Void.safe_motion(game,-1,Vector3(-.7,0,0),Vector3(-1.25,0,0))
	print("AFFINITY_QUERY ",JSON.stringify({"scouts":game.encounter.scout_count(),"iterations":120,"storm_nearest_us":storm_us,"spirit_step_us":step_us,"void_clearance_us":(Time.get_ticks_usec()-elapsed)/120.0}))
	check_crossing(game,p)
	game.queue_free()
	await process_frame
	if not failed: print("PASS: Void motion resistance, native conflict, deterministic overlap, shared allowance, well timing and all nine families")
	quit(int(failed))


func check_crossing(game: Node, p: Dictionary) -> void:
	var experimental = preload("res://battlefield.gd").new()
	var shape = preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
	var confirmed:=false
	game.encounter.clear_scouts()
	game.encounter.set_hp(-1, 0)
	ExpeditionCase.set_membership(game, p, true)
	ExpeditionCase.set_membership(game, game.players[2], false)
	game.battlefield=experimental
	for seed_value in [241,512,16]:
		experimental.configure(game.Campaign.MIRE,3,seed_value)
		if experimental.generated.is_empty(): continue
		var layout: Dictionary=experimental.generated.layout
		for deck in layout.crossings:
			if not deck.has("bridge"): continue
			var ends: PackedVector2Array=deck.bridge
			var center: Vector2=(ends[0]+ends[1])*.5
			var forward: Vector2=(ends[1]-ends[0]).normalized()
			var start: Vector3=experimental.world(center-forward*.7)
			var end: Vector3=experimental.world(center+forward*1.5)
			if not experimental.clear_line(start,end,.34): continue
			for offset in [-2.9,-1.9,-1.4,1.4,1.9,2.9]:
				var wet: Vector2=center+forward.orthogonal()*offset
				if not shape.in_any(layout.water,wet) or shape.in_any(layout.crossings,wet): continue
				var from: Vector3=experimental.world(center)
				var blocked: Vector3=experimental.world(wet)
				if not experimental.occupied(blocked,.34): continue
				p.pos=start
				var stride:=Mode.Spirit.step(game,1,(end-start).normalized())
				check(stride.distance_to(end)<.10,"Phantom Step uses a real generated Mire bridge")
				p.pos=experimental.entry
				var pushed:=Void.safe_motion(game,-1,from,blocked)
				check(pushed.distance_to(blocked)>.12 and not experimental.occupied(pushed,.34),
					"Void stops at impassable water beside the bridge")
				confirmed=true
				break
			if confirmed: break
		if confirmed: break
	check(confirmed,"bounded generated Mire cross-check found a traversable deck beside impassable water")
