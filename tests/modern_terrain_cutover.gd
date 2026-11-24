extends SceneTree
const Field = preload("res://battlefield.gd")
const Surface = preload("res://assets/terrain_m02/wilds_play_surface.gd")
const NavWorld = preload("res://mob_sim/mob_nav_world.gd")
const Catalog = preload("res://garden_interaction_catalog.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL modern terrain: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var started := Time.get_ticks_msec()
	for kind in [20,21,22,23]:
		for phase in 3:
			var field := Field.new()
			field.configure(0,2,9871,kind,phase)
			check(field.ground is Surface and field.generated.layout.layout_kind=="boss_lair","each boss phase uses the modern terrain pipeline")
			check(field.boss_kind==kind and field.boss_phase==phase and field.connected(),"boss identity and an exit route survive generation")
			for point in [field.entry,field.extraction,field.advance,field.leader,field.graft,field.cache]+field.spawn_points:
				check(not field.occupied(point,Field.CLEARANCE),"boss landmarks and summons retain physical clearance")
			check(field.entry==Vector3(0,0,-21) and field.advance==Vector3(0,0,22),"authored boss travel anchors remain unchanged")
			var twin := Field.new()
			twin.configure(0,2,9871,kind,phase)
			check(field.generated==twin.generated and field.spawn_points==twin.spawn_points,"host and guest reconstruct identical boss terrain")
	var heart := Field.new()
	heart.configure(3,1,7103)
	check(heart.ground is Surface and heart.connected(),"the Heart route also uses modern terrain")
	for index in 3:
		var field := Field.new()
		field.configure(index,index+1,91247+index)
		check(not field.generated.is_empty() and field.connected(),"ordinary biomes use connected modern floors")
		check(field.ground.walkable(Field.planar(field.entry),Field.CLEARANCE) and field.can_spawn(field.leader),"arrival and enemy placement use actual support")
	var open := Field.new()
	var mask := NavWorld.floor_mask(open)
	var blocked := open.ground.Shape.disk("rock","solid",Vector2(2,0),1.0)
	open.ground.blockers.append(blocked)
	var after := NavWorld.floor_mask(open)
	check(mask!=after,"the neural navigation bake observes modern solid footprints")

	var world = load("res://world.tscn").instantiate()
	var base := "res://.godot/modern-terrain-"+str(Time.get_ticks_usec())
	world.progress.path=base+".cfg"
	world.local_character.path=base+".character"
	world.progress.knowledge=0
	for index in range(world.progress.plots.size(),world.Stage.PLOTS.size()):
		world.progress.plots.append(world.progress.empty_plot())
	world.progress.plots[7].species=0
	check(world.progress.save_garden()==OK,"historical crop fixture serializes to its disposable path")
	root.add_child(world)
	world.set_process(false);world.set_physics_process(false)
	world._process(.016)
	var garden = world.stage.experimental_garden
	check(garden!=null and world.progress.player_placed_beds,"a plain world starts with the generated Garden and placed-bed system")
	check(garden.state!=null and garden.construction!=null and garden.funds!=null,"Garden expansion, construction and offerings remain integrated")
	check(garden.state.entrance_clear(),"the new Garden entrance remains traversable")
	world.progress.heart.complete(world.progress,"living_archive")
	world.stage.update_heart_progress(world.heart_state())
	check(world.stage.station_position("living_archive").is_finite(),"native Living Archive retains an on-site interaction")
	check(world.progress.plots.size()==9 and world.progress.plots[7].species==0 and garden.bed_ids.size()==9,"all previously owned beds and their crop contents survive load")
	for index in world.progress.plots.size():
		check(world.stage.bed_position(index).is_finite(),"every owned crop has a usable bed position")
		var at: Vector3=world.stage.bed_position(index)
		var reachable := false
		for i in 16:
			var near := Vector2(at.x,at.z)+Vector2.from_angle(TAU*i/16)*1.4
			reachable=reachable or garden.barrier.walkable(near)
		check(reachable,"owned bed %d retains a walkable interaction approach"%index)
	for point: Dictionary in Catalog.POINTS:
		var reachable := false
		for i in 16:
			var candidate: Vector2=Field.planar(point.position)+Vector2.from_angle(TAU*i/16)*minf(float(point.range)-.1,1.0)
			reachable=reachable or garden.barrier.walkable(candidate)
		check(reachable,"the generated Garden preserves access to "+str(point.id))
	var original: PackedVector2Array=garden.state.outline.duplicate()
	var cost: float=garden.funds.energy
	world.stage.update_garden(400,3)
	check(garden.state.outline==original and garden.funds.energy==cost,"research never replaces player-chosen reclamation with automatic land grants")
	var expanded: PackedVector2Array=garden.state.outline.duplicate()
	world.stage.update_garden(400,3)
	check(garden.state.outline==expanded,"repeated presentation never changes owned land")
	for frame in 5:await process_frame
	world.queue_free();await process_frame
	print("Modern terrain check milliseconds: ",Time.get_ticks_msec()-started)
	if failures==0:print("PASS: modern ordinary/boss/Heart terrain, deterministic reconstruction, native navigation and default Garden systems")
	quit(int(failures>0))
