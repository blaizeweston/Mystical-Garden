extends "res://tests/garden_layout_persistence.gd"
const Catalog = preload("res://garden_structure_catalog.gd")
const Rules = preload("res://garden_cultivation.gd")
const Care = preload("res://garden_crop_state.gd")
const Growth = preload("res://cultivation_growth.gd")
const Influence = preload("res://garden_irrigation.gd")

func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.godot/vd/"): quit(1);return
	var game := await world()
	if game==null: quit(1);return
	var g = game.progress
	var garden = game.stage.experimental_garden
	var cost_before: int = g.heart.spent
	g.knowledge=1000
	garden.funds.energy=500
	g.garden_development.energy=500
	var actor: Dictionary=game.players[1]
	actor.pos=game.stage.bed_position(0)
	actor.seed_choice=0
	game.seed_reserve(actor).stock[0]+=1
	check(game.cultivation.plant_seed(1,0),"plant before any research")
	g.advance_growth(86400)
	var before: int=game.seed_reserve(actor).stock[0]
	check(game.cultivation.harvest_seeds(1,0).get("changed",false) and game.seed_reserve(actor).stock[0]==before+2,"starting propagation yields two seeds")
	actor.pos=Vector3(0,0,1.5)
	for tech in ["clearing_1","cultivation_grounds","irrigation"]: game.garden_action(1,"heart_start_"+tech)
	var site: Vector2=garden.planar(game.stage.bed_position(0))
	var index=Influence.new()
	index.bed_centers={0:Vector2.ZERO}
	for kind: String in Catalog.DEFINITIONS:
		var definition: Dictionary=Catalog.DEFINITIONS[kind]
		if not definition.has("effect"): continue
		var radius: float=definition.radius_m
		check(index.beds_in_range(Vector2(radius,0),kind)==[0] and index.beds_in_range(Vector2(radius+0.0001,0),kind).is_empty(),"inclusive boundary for "+kind)
		game.garden_action(1,"heart_start_"+str(definition.research))
		game.garden_action(1,"heart_start_"+str(definition.research))
		check(g.structures.instances.values().filter(func(e):return e.kind==kind and e.paid.is_empty()).size()==1,"one research grant "+kind)
		var item_ids: Array=definition.cost.materials.keys()
		if not item_ids.is_empty():
			var item: Dictionary=game.Items.get_item(item_ids[0])
			check(item.get("name","")==("Ironwood Core" if kind=="refinement_grove" else "Pristine Dewcap material"),"canonical refined ingredient "+kind)
			check(not garden.construct(kind,g.structures.revision),"missing material refuses purchase")
			g.add_parts(item.legacy_part,1)
			var energy: int=g.garden_development.energy
			check(garden.construct(kind,g.structures.revision),"purchase with actual materials")
			var id: int=g.structures.next_id-1
			check(g.part_count(item.legacy_part)==0 and g.garden_development.energy==energy-definition.cost.energy,"both prices consumed")
			check(garden.retire_structure(id,g.structures.revision,true) and not garden.retire_structure(id,g.structures.revision,true) and g.garden_development.energy==energy and g.part_count(item.legacy_part)==1,"exact refund once")
		var instances: int=g.structures.instances.size()
		game.garden_action(1,"heart_start_"+kind+"_coverage")
		g.irrigation.resolve(g.structures,g.heart.unlocked)
		check(is_equal_approx(g.irrigation.radius(kind),definition.extended_m) and is_equal_approx(g.irrigation.strength(kind),definition.base),"coverage without effectiveness "+kind)
		game.garden_action(1,"heart_start_"+kind+"_effectiveness")
		g.irrigation.resolve(g.structures,g.heart.unlocked)
		check(g.structures.instances.size()==instances and is_equal_approx(g.irrigation.strength(kind),definition.improved),"upgrades grant no new instance "+kind)
	check(g.heart.spent-cost_before==7+420-10-6,"exact total price of research")
	# A sparse layout and coincident emitters exercise local resolution independently of collision.
	var inventory: Dictionary=g.structures.duplicate(true)
	for e: Dictionary in inventory.instances.values():
		if e.kind=="bed": continue
		e.placed=true;e.at=site
		if e.kind=="bud_sanctuary":e.care_mode="standard"
	var extra: int=g.Structures.add(inventory,"bud_sanctuary",{})
	inventory.instances[extra].placed=true;inventory.instances[extra].at=site
	inventory.instances[extra].care_mode="enhanced"
	index.resolve(inventory,[])
	var base_effects: Dictionary=index.effects[0]
	check(base_effects=={"watering":1.25,"growth":1.30,"refinement":0.15,"seeds":3.0,"familiarity":2.0,"care":1.0},"distinct base effects coexist")
	index.resolve(inventory,g.heart.unlocked)
	var local: Dictionary=index.effects[0]
	check(local.care==2 and local.seeds==4 and local.familiarity==3 and is_equal_approx(local.refinement,.25),"strongest enabled care and independent upgraded benefits")
	var bed:=Rules.planted_bed(0,Care.new_cycle(0))
	bed.stage=2;Growth.water(bed)
	Care.choose(bed,"preserve",.94,"deep_bud")
	check(is_equal_approx(Growth.rate(g,bed,true,true,local.growth),4.2),"improved watering, Vital Roots and expedition multiply")
	bed.stage=3
	check(Rules.harvest_yield(bed,999,.99,local).rare_part>0 and Rules.harvest_yield(bed,999,0,{}).rare_part==0,"same frozen draw compared with 95 and 70 percent")
	var snapshot:=bed.duplicate(true);Care.choose(bed,"preserve",0.0)
	check(bed==snapshot,"care cannot repeat")
	var sanctuary:=Placement.deploy_irrigation(garden,"bud_sanctuary",site)
	check(sanctuary>0 and g.structures.instances[sanctuary].care_mode=="disabled","new sanctuary defaults off")
	actor.pos=game.stage.bed_position(0);game.seed_reserve(actor).stock[0]+=1
	check(game.cultivation.plant_seed(1,0),"plant inside disabled sanctuary")
	g.advance_growth(0.65*Growth.base(g.plots[0]))
	check(Care.available(g.plots[0]),"disabled sanctuary leaves the bud untouched")
	var request: Dictionary=preload("res://garden_crop_view.gd").request(game.cultivation.projection(1).beds[0],"enhance_bud")
	check(game.cultivation.command(1,request).get("changed",false) and g.plots[0].care.opportunity=="deep_bud","manual enhanced care on starting bed")
	var accepted: Dictionary=g.plots[0].care.duplicate()
	actor.pos=Vector3(0,0,1.5)
	var revision: int=g.structures.revision
	check(garden.configure_sanctuary(sanctuary,"standard",revision) and not garden.configure_sanctuary(sanctuary,"enhanced",revision) and g.plots[0].care==accepted,"stale settings and overlaps cannot replace accepted care")
	g.advance_growth(86400);actor.pos=game.stage.bed_position(0)
	game.cultivation.harvest(1,0);game.seed_reserve(actor).stock[0]+=1;game.cultivation.plant_seed(1,0)
	g.advance_growth(86400)
	check(g.plots[0].stage==3 and Care.preserved(g.plots[0]) and g.plots[0].care.opportunity=="patient_bud","long growth update accepts standard care before maturity")
	actor.pos=Vector3(0,0,1.5)
	var living_root:=Placement.deploy_irrigation(garden,"vital_roots",site)
	check(living_root>0,"deploy improved Vital Roots")
	actor.pos=game.stage.bed_position(0)
	game.cultivation.harvest(1,0);game.seed_reserve(actor).stock[0]+=1;game.cultivation.plant_seed(1,0)
	actor.pos=Vector3(0,0,1.5)
	game.growth_clock=0.6
	check(garden.retire_structure(living_root,g.structures.revision,false) and is_equal_approx(g.plots[0].age,.9),"settle 0.6 seconds at 1.50x before storing the source")
	game.growth_clock=0.4
	check(Placement.deploy_irrigation(garden,"vital_roots",site)>0 and is_equal_approx(g.plots[0].age,1.3),"redeployment never accelerates elapsed time outside coverage")
	check(Placement.deploy_irrigation(garden,"pollination_bloom",site)>0,"place improved Pollination Bloom")
	g.advance_growth(86400)
	actor.pos=game.stage.bed_position(0)
	var prior_seeds: int=game.seed_reserve(actor).stock[0]
	check(game.cultivation.harvest_seeds(1,0).get("changed",false) and game.seed_reserve(actor).stock[0]==prior_seeds+4,"actual improved four-seed harvest")
	game.cultivation.plant_seed(1,0);g.advance_growth(86400)
	check(g.save_garden()==OK,"save configured Garden")
	var legacy:=ConfigFile.new()
	check(legacy.load(g.path)==OK,"read historical fixture")
	var old_heart: Dictionary=legacy.get_value("heart","state")
	old_heart.version=4;old_heart.unlocked=["heart","flowering","nursery","living_conduit","irrigation"]
	legacy.set_value("heart","state",old_heart)
	var old_inventory: Dictionary=legacy.get_value("construction","inventory")
	for id: int in old_inventory.instances.keys():
		if old_inventory.instances[id].kind in ["nursery","vital_roots","bud_sanctuary"]:old_inventory.instances.erase(id)
	legacy.set_value("construction","inventory",old_inventory)
	var historical=game.Progress.new();historical.path=base+".hg03"
	check(legacy.save(historical.path)==OK,"write disposable HG03")
	var backup: String=historical.path+".pre-cultivation-v5.bak"
	var original:=FileAccess.get_file_as_bytes(historical.path)
	check(historical.load_garden()==OK and DirAccess.make_dir_absolute(backup)==OK,"prepare a blocked migration backup")
	check(historical.save_garden()!=OK and FileAccess.get_file_as_bytes(historical.path)==original,"failed migration write keeps historical investment and grants retryable")
	check(DirAccess.remove_absolute(backup)==OK,"release disposable backup")
	for pass_index in 3:
		check(historical.load_garden()==OK and historical.heart.spent==old_heart.spent and historical.knowledge==g.knowledge,"migration retains both Knowledge balances")
		check(historical.heart.has("vital_roots") and historical.heart.has("bud_sanctuary_effectiveness") and not historical.heart.has("flowering"),"historical entitlements")
		for kind in ["nursery","vital_roots","bud_sanctuary","intake","sprinkler"]:
			check(historical.structures.instances.values().filter(func(e):return e.kind==kind and e.paid.is_empty()).size()==1,"one historical grant "+kind)
		check(historical.plots[0].care==g.plots[0].care,"accepted historical crop preserved")
		check(historical.save_garden()==OK,"save migration")
	check(FileAccess.get_file_as_bytes(backup)==original,"one verified backup preserves the original Garden")
	game.free()
	if not failed:print("PASS: six cultivation structures, purchases, exact refunds, care, probabilities and historical grants")
	quit(int(failed))
