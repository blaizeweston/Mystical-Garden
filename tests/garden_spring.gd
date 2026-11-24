extends SceneTree
const Water=preload("res://garden_water.gd")
const Interactions=preload("res://garden_interaction_service.gd")
const Build=preload("res://assets/terrain_m02/garden_construction.gd")
const Shape=preload("res://assets/terrain_m02/terrain_feature_geometry.gd")
const Expedition=preload("res://tests/support/expedition_case.gd")
var failed:=false
func check(ok:bool,message:String)->void:
	if not ok:failed=true;printerr("FAIL Garden spring: ",message)
func _initialize():call_deferred("run")
func cues(world:Node)->int:
	return world.combat_events.filter(func(event):return event.kind=="audio" and event.shape=="vessel_filled").size()
func run():
	var game=load("res://world.tscn").instantiate()
	var base="res://.godot/garden-water-"+str(Time.get_ticks_usec())
	game.progress.path=base+".garden";game.local_character.path=base+".profile";game.guest_character.path=base+".guest";game.settings_path=base+".settings"
	root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.app_settings.values.garden_cinematics=false
	var p:Dictionary=game.players[1];var garden=game.stage.experimental_garden
	var view=game.get_node("GardenInteractions");view.set_process(false)
	var point:Dictionary=Interactions.Catalog.point("spring_water")
	game._process(.016)
	check(not Build.CATALOG.has("spring") and not garden.STATIONS.has("spring") and not garden.structure_nodes.has("spring"),"watering basin is absent from construction and the world")
	check(not game.stage.garden_edge.has_node("DormantSpringSite") and not game.stage.garden_edge.has_node("ShelteredSpring"),"old dormant/awakened fixture is retired")
	check(game.stage.garden_edge.find_children("GardenPond", "MeshInstance3D", true, false).is_empty()
		and game.stage.garden_edge.find_children("GardenWaterFeature", "Node3D", true, false).is_empty(), "no extra decorative ponds remain")
	var sources: Array = Water._features(game.stage)
	check(sources == garden.state.layout.water and sources.all(func(source): return not str(source.id).begins_with("garden_pool_")), "only generated terrain water authorizes filling")
	var altar: int = garden.station_ids.altar
	var pawn: Vector2 = garden.planar(p.pos)
	var refusal: String = garden.construction.validate("altar",Vector2(6.0,1.5),0.0,pawn,altar)
	check(refusal.is_empty(),"the retired spring site accepts a clear structure: " + refusal)
	refusal = garden.construction.validate("altar",Vector2(5.0,1.0),0.0,pawn,altar)
	check(refusal.contains("another structure"),"spring markers no longer block nearby ground, while actual bed overlap remains protected: " + refusal)
	var bank:=Water.anchor(game.stage)
	check(bank.is_finite() and garden.barrier.walkable(Vector2(bank.x,bank.z)),"visible Garden water has a dry accessible bank before research")
	p.pos=bank
	check(game.cultivation.spring_ready() and game.garden_commands.interact(1) and p.get("spring_water",false),"ordinary interaction fills from natural water before research")
	game.progress.heart.complete(game.progress,"clearing_1");game._process(.016)
	check(game.cultivation.fill_water(1),"manual fill is independent of research")
	p.spring_water=false
	game.progress.heart.complete(game.progress,"flowering");game.progress.heart.complete(game.progress,"irrigation")
	game._process(.016)
	bank=Water.anchor(game.stage);p.pos=bank
	check(game.cultivation.spring_ready() and game.garden_commands.allowed(point),"existing Knowledge prerequisites immediately enable the existing water without construction")
	check(not garden._placement_refusal("spring",0).is_empty() and not garden.place("spring",Vector2.ZERO,0.0),"old basin placement requests cannot resurrect the fixture")
	var before:Dictionary={"parts":game.progress.parts.duplicate(),"stock":game.progress.stock.duplicate(),"knowledge":game.progress.knowledge,"xp":p.character.xp.duplicate(),"rng":game.rng.state}
	var count:=cues(game)
	check(game.garden_commands.nearest(1,game.garden_commands.projection(1))=="spring_water" and view.context_prompt().contains("Fill watering vessel"),"host prompt selects the actual bank")
	game.act(1,false)
	check(p.get("spring_water",false) and cues(game)==count+1,"ordinary interact fills once and emits the existing cue")
	check(game.cultivation.fill_water(1) and cues(game)==count+1,"repeated fill keeps one vessel without duplicate confirmation")
	check(game.progress.parts==before.parts and game.progress.stock==before.stock and game.progress.knowledge==before.knowledge and p.character.xp==before.xp and game.rng.state==before.rng,"filling costs no parts, Knowledge or XP and consumes no RNG")
	view._process(0)
	check(view.points.spring_water.position.distance_to(bank)<.05,"the marker is at the same bank used by authoritative interaction")
	var observation = game.garden_commands.command(1,JSON.stringify({"point":"spring_water","action":"observe","revision":0,"request":"water-observation"}))
	check(observation.get("changed",false) and game.progress.garden_interactions.observations.has("sheltered_water"),"stable historical observation identity remains usable at the new source")
	p.spring_water=false;p.pos=Vector3.ZERO
	check(not game.cultivation.fill_water(1) and not p.spring_water,"remote filling is refused")
	p.pos=Water.center(game.stage)
	check(not garden.barrier.walkable(Vector2(p.pos.x,p.pos.z)) and Water.nearby(game.stage,p.pos).is_empty() and not game.cultivation.fill_water(1),"submerged positions cannot fill and actual water still blocks walking")
	p.pos=bank
	garden.barrier.construction.append(Shape.disk("water-test-solid","wall",Vector2(bank.x,bank.z),.7))
	check(Water.nearby(game.stage,bank).is_empty() and not game.cultivation.fill_water(1),"blocked bank positions are refused")
	garden.barrier.construction.pop_back()
	check(not Water.nearby(game.stage,bank).is_empty(),"clearing an obstruction restores the same bank")
	Expedition.set_membership(game,p,true)
	check(not game.cultivation.fill_water(1),"Wilds participants cannot collect Garden water")
	Expedition.set_membership(game,p,false)
	check(Water.nearby(game.stage,Vector3.INF).is_empty(),"invalid request positions are refused")
	game.progress.save_garden()
	var restored=game.Progress.new();restored.path=game.progress.path
	check(restored.load_garden()==OK and restored.heart.has("irrigation") and restored.garden_interactions.observations.has("sheltered_water"),"research and historical observation survive reload without a basin record")
	game.queue_free();await process_frame
	if not failed:print("PASS: starting Garden water banks, fixture removal, ordinary interaction, one vessel, dry reach, duplicate refusal, unchanged rewards and saved observations")
	quit(1 if failed else 0)
