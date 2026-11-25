extends "res://tests/garden_layout_persistence.gd"

func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.godot/vd/"):
		quit(1)
		return
	var game := await world()
	if game == null: quit(1);return
	var garden = game.stage.experimental_garden
	var g = game.progress
	g.knowledge=4
	game.garden_action(1,"heart_start_cultivation_grounds")
	game.garden_action(1,"heart_start_cultivation_grounds")
	var granted: int=g.structures.next_id-1
	check(g.heart.spent==4 and g.structures.instances.size()==5 and not g.structures.instances[granted].placed,"one stored reward at the exact purchase price")
	check(not garden.construct("bed",g.structures.revision),"unaffordable construction refused")
	g.knowledge=100
	for tech in ["clearing_1","seed_archive","monster_studies"]:
		game.garden_action(1,"heart_start_"+tech)
		game.garden_action(1,"heart_start_"+tech)
	check(g.structures.instances.size()==7 and not garden.construct("archive",g.structures.revision),"unique stations granted exactly once")
	for kind in ["archive","study"]:
		check(preload("res://tests/support/terrain_case.gd").place_structure(game,kind),"place unlocked "+kind)
	garden.funds.energy=10000
	g.garden_development.energy=10000
	var revision: int=g.structures.revision
	garden.open_development()
	garden.management_tabs.current_tab = 1
	check(garden.management_tabs.get_tab_title(0)=="Inventory" and garden.management_tabs.get_tab_title(1)=="Construct" and garden.management_tabs.get_tab_title(2)=="Placed" and garden.preview_model.mesh!=null and garden.construct_info.text.contains("12 Growth Energy"),"Build tabs show the actual structure and price")
	garden.construct_button.pressed.emit()
	garden.development_dialog.hide()
	check(g.structures.revision==revision+1 and not garden.construct("bed",revision) and garden.funds.energy==9988,"one purchase per reviewed revision")
	var paid: int=g.structures.next_id-1
	var at := Placement.find(garden.construction,"bed",Vector2(2.34,-4.58),0.0,Vector2(0,1.5))
	check(not garden.place("bed",Vector2.ZERO,0,paid) and not g.structures.instances[paid].placed,"invalid placement keeps stored purchase")
	check(garden.place("bed",at,0,paid),"deploy paid bed")
	var slot: int=g.structures.instances[paid].slot
	g.plots[slot].species=0
	preload("res://cultivation_growth.gd").initialize(g.plots[slot])
	preload("res://garden_crop_state.gd").ensure(g.plots[slot])
	g.plots[slot].age=12
	g.advance_growth(0.0)
	var crop: Dictionary=g.plots[slot].duplicate(true)
	check(not garden.retire_structure(paid,g.structures.revision,false) and not garden.retire_structure(paid,g.structures.revision,true),"live crop cannot be stored or lost")
	at=relocation(garden,"bed",paid)
	check(garden.place("bed",at,0.2,paid) and g.plots[slot]==crop,"crop configuration survives relocation")
	g.plots[slot]=g.empty_plot()
	check(garden.retire_structure(paid,g.structures.revision,false) and not game.stage.bed_position(slot).is_finite(),"stored bed has no world presence")
	game.seed_reserve(game.players[1]).stock[0] += 1
	check(not game.cultivation.plant_seed(1,slot) and g.plots[slot].species<0,"stored bed cannot accept a crop")
	check(garden.place("bed",at,0.2,paid) and g.structures.instances[paid].slot==slot and garden.funds.energy==9988,"free redeployment keeps stable identity")
	check(not garden.retire_structure(1,g.structures.revision,true) and not garden.retire_structure(garden.station_ids.altar,g.structures.revision,true),"starting assets cannot be dismantled")
	garden.open_development()
	garden.management_tabs.current_tab=2
	garden.building_picker.select(garden.building_picker.get_item_index(paid))
	garden.dismantle_button.pressed.emit()
	check(garden.refund_dialog.visible and garden.refund_dialog.dialog_text.contains("12 Growth Energy") and g.structures.instances.has(paid),"review the actual payment before permanent removal")
	garden.refund_dialog.confirmed.emit()
	garden.refund_dialog.hide()
	garden.development_dialog.hide()
	check(not g.structures.instances.has(paid) and not garden.retire_structure(paid,g.structures.revision,true) and garden.funds.energy==10000,"refund once")
	# A historically paid instance carries its own receipt across a catalog price change.
	var original_item: String = game.Items.part_id(game.Parts.THORN)
	var prior_parts: int = g.part_count(game.Parts.THORN)
	var historical: int = g.Structures.add(g.structures,"bed",{"energy":17,"materials":{original_item:2}})
	var old_price_revision: int = g.structures.revision
	check(garden.retire_structure(historical,old_price_revision,true) and garden.funds.energy==10017 and g.part_count(game.Parts.THORN)==prior_parts+2,"refund the recorded payment including historical materials")
	check(not garden.retire_structure(historical,old_price_revision,true) and g.part_count(game.Parts.THORN)==prior_parts+2,"retired identity cannot reclaim its receipt")
	game.garden_action(1,"heart_start_irrigation")
	var bed_center: Vector2 = garden.planar(game.stage.bed_position(0))
	check(Placement.deploy_irrigation(garden,"intake",garden.planar(Water.anchor(game.stage)))>0,"supply scale garden")
	for copy in 3:
		if copy>0: check(garden.construct("sprinkler",g.structures.revision),"pay for additional sprinkler")
		check(Placement.deploy_irrigation(garden,"sprinkler",bed_center)>0,"place overlapping sprinklers")
	# Exercise live roots, network payload and crop processing with every field type.
	g.knowledge=1000
	Placement.reclaim_orchard(garden)
	for kind in ["pollination_bloom","nursery","refinement_grove","vital_roots","bud_sanctuary"]:
		game.garden_action(1,"heart_start_"+kind)
		var cost: Dictionary = garden.Build.CATALOG[kind].cost
		for item: String in cost.materials: g.add_parts(game.Items.get_item(item).legacy_part,1)
		check(garden.construct(kind,g.structures.revision),"buy paid "+kind)
		for side in [1,-1]:
			check(Placement.deploy_irrigation(garden,kind,bed_center*side)>0,"place "+kind+" on both sides of the Garden")
	check(Placement.develop(garden,60,true),"twelve, thirty and sixty actually placed beds with unique stations and water access")
	var total: int=garden.bed_ids.size()
	var inventory: Dictionary=g.structures.duplicate(true)
	var energy: int=garden.funds.energy
	var saved_layout: Dictionary=g.garden_development.duplicate(true)
	check(g.save_garden()==OK,"save developed Garden")
	game.free()
	game=await world(false)
	if game==null: quit(1);return
	garden=game.stage.experimental_garden
	check(garden.bed_ids.size()==total and equivalent(game.progress.structures,inventory) and garden.funds.energy==energy and equivalent(game.progress.garden_development,saved_layout),"complete inventory and land survive reopen")
	for kind in ["altar","archive","study"]:
		var station: String=garden.STATIONS[kind]
		var id: int=garden.station_ids[station]
		var entry: Dictionary=game.progress.structures.instances[id].duplicate(true)
		check(garden.retire_structure(id,game.progress.structures.revision,false),"store free station "+kind)
		game._process(.016)
		check(not game.stage.station_position(station).is_finite() and not garden.construction.records.has(id) and not garden.structure_nodes.has(str(id)),"stored station releases its service, footprint and art")
		var destination: Vector2=entry.at
		if not garden._build_refusal(kind,destination,entry.yaw,id).is_empty():
			destination=Placement.find(garden.construction,kind,destination,entry.yaw,Vector2(0,1.5))
		check(destination.is_finite() and garden.place(kind,destination,entry.yaw,id) and garden.funds.energy==energy,"free station redeploys under its original identity")
	game.free()
	if not failed: print("PASS: Garden inventory, placement, costs, sixty beds, uniqueness, retirement, save and recovery")
	quit(int(failed))
