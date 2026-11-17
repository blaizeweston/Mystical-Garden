extends SceneTree

const SessionCase = preload("res://tests/support/session_case.gd")

const ExpeditionCase = preload("res://tests/support/expedition_case.gd")

const Storm = preload("res://storm_affinity.gd")
const Events = preload("res://combat_action_events.gd")
const Builds = preload("res://affinity_build.gd")
const Mode = preload("res://combat_ruleset.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failed=true; printerr("FAIL Storm: ",label)

func action(game: Node, slot: String, part: int, channels: Array) -> RefCounted:
	var material := Builds.slot(slot,part)
	return Events.begin(game,1,slot,material,material.potency_profile.values,channels,Time.get_ticks_msec()+10000)

func run() -> void:
	var game := preload("res://world.tscn").instantiate()
	game.set_meta(Mode.META,Mode.ID)
	game.progress.path="user://cr04c-storm/garden.cfg"
	game.local_character.path="user://cr04c-storm/player.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var p: Dictionary=game.players[1]
	ExpeditionCase.set_membership(game, p, true)
	p.pos=Vector3.ZERO
	game.encounter.set_hp(-1, 100)
	game.tactics.position=Vector3(1,0,0)
	game.encounter.clear_scouts()
	for at in [Vector3(2.2,0,0),Vector3(2.2,0,0),Vector3(6.7,0,0)]:
		var scout: Dictionary=game.make_scout(0,at,game.encounter.scout_count()+1)
		scout.hp=100
		game.encounter.register_scout(scout)
	var ordinary:=11
	var refined: int=game.Items.get_item("plant_part_rare_storm_reed").legacy_part
	var now:=Time.get_ticks_msec()
	check(Storm.nearest(game,Vector3(1,0,0),3.0,{"leader":true})==0,"equal range takes stable host index")
	var core:=action(game,"core",ordinary,["core_action"])
	game.encounter.set_hp(-1, 1)
	core.publish(game,"core_action","contact","leader",now,{"enemy":-1,"origin":p.pos,"point":game.tactics.position})
	check(game.enemy_health()==0 and game.encounter.hp(0)==85 and game.encounter.hp(1)==89 and game.encounter.hp(2)==100,"kill continues from impact with falloff, unique contacts and no long-range jump")
	game.encounter.set_hp(-1, 100)
	game.encounter.set_hp(0, 0)
	game.encounter.set_hp(1, 0)
	game.encounter.set_hp(2, 100)
	var charged:=action(game,"catalyst",refined,["class_action"])
	charged.publish(game,"class_action","heal","",now,{"response":"recipient_charge","recipients":[1]})
	var expires: int=p[Storm.CHARGE].until
	preload("res://affinity_time.gd").advance(game,.4)
	var weaker:=action(game,"catalyst",ordinary,["class_action"])
	weaker.publish(game,"class_action","heal","",now,{"response":"recipient_charge","recipients":[1]})
	check(p[Storm.CHARGE].quality=="refined" and p[Storm.CHARGE].until==expires,"weaker healing cannot replace or extend a refined charge")
	var form:=action(game,"form",ordinary,["weapon_contact","secondary"])
	var stats: Dictionary={Events.CONTEXT:form}
	Events.contact(game,stats,-1,now,false,game.tactics.position)
	check(game.enemy_health()==77 and not p.has(Storm.CHARGE),"Form and separate charge both resolve on one direct contact")
	Events.contact(game,stats,-1,now,false,game.tactics.position)
	Events.contact(game,stats,2,now,true)
	check(game.enemy_health()==77 and game.encounter.hp(2)==100,"repeat and secondary contact cannot discharge")
	var Core=preload("res://core_combat.gd")
	SessionCase.set_ready(game, p, true)
	p.frame=2;p.weapon_kind=0;p.weapon=ordinary;p.pos=Vector3.ZERO
	game.tactics.position=Vector3(3.2,0,0);game.encounter.set_hp(-1, 100)
	game.battlefield.procedural=false
	game.battlefield.barriers.assign([Rect2(1.4,-2.0,1.0,4.0)])
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	var cast: Dictionary=game.get_meta(Core.STATE,{}).get(1,{})
	if not cast.is_empty():
		Core.tick(game,int(cast.release))
		Core.tick(game,int(cast.armed))
	check(game.enemy_health()==100,"actual projectile cannot start Chain Spark behind a solid wall")
	game.battlefield.barriers.clear()
	p.core_ready_at=0;p.core_cast_until=0;p.cast_until=0
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	cast=game.get_meta(Core.STATE,{}).get(1,{})
	if not cast.is_empty():
		Core.tick(game,int(cast.release))
		Core.tick(game,int(cast.armed))
	check(game.enemy_health()==78,"same native projectile starts useful damage against a valid single target")
	p.core_ready_at=0;p.core_cast_until=0;p.cast_until=0;p.weapon=refined
	game.encounter.set_hp(-1, 100)
	Core.command(game,1,p,Core.request(game,p,Vector2.RIGHT))
	cast=game.get_meta(Core.STATE,{}).get(1,{})
	if not cast.is_empty():
		Core.tick(game,int(cast.release))
		Core.tick(game,int(cast.armed))
	check(game.enemy_health()==70,"refined Core increases originating damage at the same reach")
	p.erase(Storm.FORM_READY)
	game.encounter.set_hp(-1, 100)
	var sharper:=action(game,"form",refined,["weapon_contact"])
	Events.contact(game,{Events.CONTEXT:sharper},-1,now,false,game.tactics.position)
	check(game.enemy_health()==87,"refined Form increases first-contact damage")
	for material in [ordinary,refined]:
		game.encounter.set_hp(-1, 100)
		var ward:=action(game,"catalyst",material,["actual_block"])
		ward.publish(game,"actual_block","ward","1",now,{"recipient":1,"center":game.tactics.position})
		check(game.enemy_health()==(88 if material==ordinary else 83),"burst potency comes from the selected Storm Ward")
	game.queue_free()
	await process_frame
	if not failed: print("PASS: Storm chain, falloff, stable ties, lethal continuation, source-owned charge and independent Form")
	quit(int(failed))
