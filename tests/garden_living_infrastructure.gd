extends "res://tests/garden_layout_persistence.gd"
const Growth = preload("res://cultivation_growth.gd")
const Coverage = preload("res://garden_irrigation.gd")

func check_root_attachment(garden: Node) -> void:
	var view = garden.infrastructure
	var first: int = view.paths.keys().min()
	var start: Vector3 = view.paths[first][0]
	var width: float = 0.77 + garden.heart.stage * 0.112
	var attached := false
	for socket: Array in view.HeartRoots.SOCKETS:
		var a: Vector3 = socket[0]
		var b: Vector3 = socket[1]
		if start.is_equal_approx(a.lerp(b, 0.30) * Vector3(width, 1, width)):
			attached = true
	check(attached, "the first structure limb starts inside an authored Heart buttress")
	check(view.mesh.get_surface_count() == 1 and view.mesh.surface_get_material(0).shader == garden.heart.sculpt_bark.shader, "established roots wear the Heart sculpt's bark")

func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.godot/vd/"):
		quit(1)
		return
	var game := await world()
	if game==null: quit(1);return
	var g = game.progress
	var garden = game.stage.experimental_garden
	var pawn: Vector2 = garden.planar(game.players[1].pos)
	g.knowledge=100
	for tech in ["flowering","clearing_1","irrigation","irrigation"]: game.garden_action(1,"heart_start_"+tech)
	var intake := Placement.stored_id(garden,"intake")
	var sprinkler := Placement.stored_id(garden,"sprinkler")
	check(intake>0 and sprinkler>0 and g.structures.instances.size()==6 and g.structures.instances[intake].paid.is_empty() and g.structures.instances[sprinkler].paid.is_empty(),"irrigation grants exactly two free stored structures")
	check(not garden.construct("intake",g.structures.revision) and not garden.retire_structure(intake,g.structures.revision,true),"intake is unique and unrefundable")
	check(garden.infrastructure.paths.size()==4 and not g.irrigation.supplied,"every starting bed and the altar are already connected")
	check_root_attachment(garden)
	check(not garden.place("intake",Vector2.ZERO,0,intake),"inland intake rejected")
	var bank: Vector2=garden.planar(Water.anchor(game.stage))
	if Placement.deploy_irrigation(garden,"intake",bank)==0:
		check(false,"ordinary placement finds a real dry shoreline")
		game.free();quit(1);return
	var origin: Vector2=garden.planar(game.stage.bed_position(0))
	if Placement.deploy_irrigation(garden,"sprinkler",origin)==0:
		check(false,"sprinkler placed near starting bed");game.free();quit(1);return
	var pos: Vector2=g.structures.instances[sprinkler].at
	check(g.irrigation.watered_slots.has(0) and garden.infrastructure.paths.size()==6 and garden.infrastructure.spray.mesh!=null,"placed intake supplies the bed and visual spray")
	var wood: ArrayMesh = garden.infrastructure.mesh
	check(wood.get_surface_count() == 2, "a new limb grows separately from the established bark")
	if wood.get_surface_count() == 2:
		var bark: ShaderMaterial = wood.surface_get_material(1)
		check(bark.shader == garden.heart.sculpt_bark.shader and bark.get_shader_parameter("growing_root") and is_zero_approx(bark.get_shader_parameter("root_progress")), "placement starts the frontier bark reveal")
		garden.infrastructure._growth.custom_step(1.0)
		check(is_equal_approx(bark.get_shader_parameter("root_progress"), 1.0), "the new limb finishes growing")
	var mask: Dictionary=g.irrigation.watered_slots.duplicate()
	var paths: Dictionary=garden.infrastructure.paths.duplicate(true)
	garden.infrastructure.rebuild(garden.construction.records,garden.state,garden.heart.stage,garden.network,garden.game.progress.irrigation.supplied)
	check(paths==garden.infrastructure.paths and paths.values().any(func(path):return Vector2(path[0].x,path[0].z).length()>0.1),"deterministic branching paths")
	check(garden.infrastructure.find_children("*","CollisionObject3D",true,false).is_empty(),"roots and spray add no collision")
	var boundary := Coverage.new()
	boundary.bed_centers={0:Vector2(3.5,0),1:Vector2(3.5001,0)}
	check(boundary.beds_in_range(Vector2.ZERO)==[0],"horizontal boundary includes 3.5 m exactly")
	garden.funds.energy=24
	g.garden_development.energy=24
	var old_revision: int=g.structures.revision
	check(garden.construct("sprinkler",old_revision) and not garden.construct("sprinkler",old_revision) and garden.funds.energy==0,"additional sprinkler costs 24 once")
	var second := Placement.deploy_irrigation(garden,"sprinkler",origin)
	check(second>0 and g.irrigation.beds_in_range(g.structures.instances[second].at).has(0),"both sprinklers reach bed one")
	game.players[1].pos=game.stage.bed_position(0)
	game.seed_reserve(game.players[1]).stock[0]+=1
	check(game.cultivation.plant_seed(1,0),"plant within existing coverage")
	var bed: Dictionary=g.plots[0]
	g.advance_growth(8)
	check(is_equal_approx(bed.age,10) and not Growth.watered(bed),"new crop with overlapping sources gains exactly 1.25x without a care flag")
	check(game.cultivation.projection(1).beds[0].sprinkler,"inspection reports effective watering")
	game.players[1].pos=Vector3(0,0,1.5)
	garden.begin_placement("sprinkler",sprinkler)
	garden.build_target=pos
	garden._show_ghost()
	check(garden.coverage_preview.mesh!=null and game.status.contains("Water supplied") and game.status.contains("Beds:"),"preview shows supply and the covered beds")
	garden._cancel_placement()
	check(garden.coverage_preview.mesh==null,"coverage is only drawn in Build")
	check(garden.retire_structure(second,g.structures.revision,true) and garden.funds.energy==24 and not garden.retire_structure(second,g.structures.revision,true) and not garden.infrastructure.paths.has(second),"actual payment refunded once and root retired")
	var moved: Vector2=Placement.find(garden.construction,"bed",-pos,0,pawn,garden.bed_ids[0])
	check(moved.distance_to(pos)>Coverage.RADIUS_M and garden.place("bed",moved,0,garden.bed_ids[0]) and not g.irrigation.watered_slots.has(0),"moving the growing bed removes automatic watering")
	g.advance_growth(8)
	check(is_equal_approx(bed.age,18),"outside coverage grows at baseline")
	var returning := Placement.find(garden.construction,"bed",pos,0,pawn,garden.bed_ids[0])
	check(returning.distance_to(pos)<=Coverage.RADIUS_M and garden.place("bed",returning,0,garden.bed_ids[0]) and g.irrigation.watered_slots.has(0),"redeploy the growing bed on valid covered land")
	mask=g.irrigation.watered_slots.duplicate()
	var distant: Vector2=Placement.find(garden.construction,"sprinkler",-origin,0,pawn,sprinkler)
	check(garden.place("sprinkler",distant,0,sprinkler) and not g.irrigation.watered_slots.has(0) and garden.place("sprinkler",pos,0,sprinkler),"relocation recalculates source coverage")
	check(garden.retire_structure(sprinkler,g.structures.revision,false) and not g.irrigation.watered_slots.has(0) and garden.place("sprinkler",pos,0,sprinkler),"storing and redeploying the sprinkler restores coverage")
	Growth.water(bed)
	g.advance_growth(8,true)
	check(is_equal_approx(bed.age,38),"manual plus automatic still uses one multiplier and doubles in Wilds")
	var shore: Vector2=g.structures.instances[intake].at
	check(garden.retire_structure(intake,g.structures.revision,false) and not g.irrigation.supplied and not garden.infrastructure.paths.has(intake) and garden.infrastructure.spray.mesh==null,"storing intake stops supply and spray immediately")
	g.advance_growth(8)
	check(is_equal_approx(bed.age,48) and Growth.watered(bed),"manual watering survives removal of supply")
	check(garden.place("intake",shore,0,intake) and g.irrigation.watered_slots==mask,"redeploy intake restores coverage")
	game.garden_action(1,"heart_start_nursery")
	g.advance_growth(8,true)
	check(is_equal_approx(bed.age,76),"Nursery 1.4x, Wilds 2x and watering 1.25x")
	game.stage.update_heart_progress(game.heart_state())
	var saved_stage: int = garden.heart.stage
	var saved_paths: Dictionary=garden.infrastructure.paths.duplicate(true)
	var old_path: String=g.path
	check(g.save_garden()==OK,"save real structures")
	game.free()
	game=await world(false)
	if game==null:quit(1);return
	g=game.progress;garden=game.stage.experimental_garden
	game.stage.update_heart_progress(game.heart_state())
	check(garden.infrastructure.mesh.get_surface_count() == 1, "reloaded branches are fully grown")
	check(saved_stage == garden.heart.stage,"restore the rendered Heart stage")
	check(equivalent(saved_paths,garden.infrastructure.paths) and g.irrigation.watered_slots==mask and Growth.watered(g.plots[0]),"reopen reconstructs roots and coverage, retaining manual care")
	var legacy:=ConfigFile.new()
	check(legacy.load(old_path)==OK,"read disposable pre-migration fixture")
	var historical: Dictionary=legacy.get_value("construction","inventory")
	for id: int in historical.instances.keys():
		if historical.instances[id].kind in ["intake","sprinkler"]: historical.instances.erase(id)
	historical.version=1
	legacy.set_value("construction","inventory",historical)
	var legacy_path:=base+".hg02"
	check(legacy.save(legacy_path)==OK,"create historical save")
	var restored = game.Progress.new()
	restored.path=legacy_path
	var original_spent: int=g.heart.spent
	var original_energy: int=g.garden_development.energy
	var before_bytes := FileAccess.get_file_as_bytes(legacy_path)
	var blocked_backup := legacy_path+".pre-irrigation-v2.bak"
	check(restored.load_garden()==OK and DirAccess.make_dir_absolute(blocked_backup)==OK,"prepare blocked migration backup in disposable fixture")
	check(restored.save_garden()!=OK and FileAccess.get_file_as_bytes(legacy_path)==before_bytes,"failed conversion write preserves the original Garden")
	check(DirAccess.remove_absolute(blocked_backup)==OK,"release disposable backup obstruction")
	for pass_index in 3:
		check(restored.load_garden()==OK and restored.heart.spent==original_spent and restored.garden_development.energy==original_energy,"migration preserves balances")
		check(restored.structures.instances.size()==historical.instances.size()+2 and restored.structures.instances.values().filter(func(e):return e.kind in ["intake","sprinkler"] and not e.placed and e.paid.is_empty()).size()==2,"HG02 owner gets each free grant once")
		if pass_index==1: check(restored.save_garden()==OK,"commit converted stock")
	var backup:=ConfigFile.new()
	check(backup.load(legacy_path+".pre-irrigation-v2.bak")==OK and backup.get_value("construction","inventory").version==1,"preserve pre-upgrade bytes")
	game.free()
	if not failed: print("PASS: living roots, water supply, overlapping sprinklers, manual watering, historic grants and save reconstruction")
	quit(int(failed))
