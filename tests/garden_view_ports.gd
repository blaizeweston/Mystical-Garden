extends SceneTree
const View=preload("res://garden_interaction_view.gd")
const Shell=preload("res://ui/gameplay/gameplay_ui.tscn")
const Catalog=preload("res://garden_interaction_catalog.gd")
const Crops=preload("res://garden_crop_catalog.gd")
const Returns=preload("res://garden_return_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
var failed:=false
var requests:Array=[]
var frames:Dictionary={}

class DisplayStage extends Node3D:
	const PLOTS=preload("res://stage.gd").PLOTS
	const HEART=preload("res://stage.gd").HEART
	var garden_edge:=Node3D.new()
	var heart_tree:Node3D
	var heart_unlocked:Array=["heart"]
	var experimental_garden:Node3D
	var bed_locations:Array=PLOTS.slice(0,3)
	func _ready():add_child(garden_edge)
	func bed_position(slot:int)->Vector3:return bed_locations[slot]
	func bed_positions()->Array:return bed_locations.duplicate()
	func station_position(_station:String)->Vector3:return Vector3(6,0,1)
	func root_tube(surface:SurfaceTool,_points:Array[Vector3],_start:float,_end:float):
		for point in [Vector3.ZERO,Vector3(.02,0,0),Vector3(0,.02,0)]:
			surface.set_normal(Vector3.UP);surface.set_uv(Vector2.ZERO);surface.add_vertex(point)

func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failed=true;printerr("FAIL Garden view ports: ",message)
func payload(index:int)->Dictionary:return JSON.parse_string(requests[index].data.action.trim_prefix("garden:"))
func run():
	# No Game, actor registry, gameplay owner or persistence context is installed.
	var stage:=DisplayStage.new();root.add_child(stage)
	var ui=Shell.instantiate();root.add_child(ui)
	var view=View.new();view.configure(stage,ui)
	view.refresh_requested.connect(func(kind:String,_selection:Dictionary):view.present_feature(kind,frames.get(kind,{})))
	view.requested.connect(func(command:String,data:Dictionary):requests.append({"command":command,"data":data.duplicate(true)}))
	root.add_child(view);view.set_process(false)
	for child in view.get_children():child.set_process(false)
	var point:Dictionary=Catalog.point("heart_root_scar")
	var positions:Dictionary={}
	for definition in Catalog.POINTS:positions[definition.id]=definition.position
	frames.interaction={"context":"solo:1:a","present":true,"position":point.position,"wild":false,"nearest":point.id,
		"near_stations":[],"nearest_station":"","development":false,"motion":true,"point_positions":positions,
		"data":{"version":1,"catalog":Catalog.signature,"revision":7,"available":[point.id],"observations":[],"clues":{},"returns":{},"focus":{"serial":1,"point":point.id}}}
	frames.crop={"context":"solo:1:a","present":true,"wild":false,"nearby_plot":-1,"position":point.position,"development":false,"motion":true,"data":{"version":2,"catalog":Crops.signature,"beds":[],"focus":{}}}
	var untouched:=frames.duplicate(true)
	view._process(0)
	check(view.panel.visible and view.title.text==point.name and view.cue_until==0,"first display opens the requested inspection without replaying an old cue")
	view.observe.pressed.emit();view.observe.pressed.emit()
	check(requests.size()==1 and payload(0).revision==7 and payload(0).point==point.id and payload(0).action=="observe","one pending observation emits only its current revision-bound request")
	check(frames==untouched,"views cannot mutate the supplied world facts")
	var relationship:Dictionary=Catalog.POINTS.filter(func(entry):return entry.get("visual","")=="relationship")[0]
	var old_roots:Mesh=view.points[relationship.id].get_node("Roots").mesh
	stage.bed_locations[0]+=Vector3(1,0,0)
	frames.interaction.structure_revision=1
	view._process(0)
	check(view.points[relationship.id].get_node("Roots").mesh!=old_roots,"a detached placement revision refreshes relationship art using current bed positions")
	frames.interaction.data.revision=8;frames.interaction.data.observations=[point.observation]
	view._process(0)
	check(view.cue_until>0 and view.observe.disabled and view.observe.text=="Recorded in this Garden","a new revision shows its cue and recorded state without granting anything")
	ui.close_panels();frames.interaction.context="guest:2:b";frames.interaction.data.focus={}
	view._process(0)
	check(view.cue_until==0 and not view.pending and not view.panel.visible,"a new session establishes a baseline without reopening or replaying the old observation")
	var known:Array=[];known.resize(24);known.fill(false);known[0]=true
	var counts:Array=Parts.empty_counts();counts[Parts.HOOK]=1
	var costs:Array=[];costs.resize(24);costs.fill(2)
	frames.station={"present":true,"status":"Ready","counts":counts,"discoveries":known,"reclamation_costs":costs}
	frames.interaction.near_stations=["monster_studies"];frames.interaction.nearest_station="monster_studies"
	frames.interaction.data.focus={"serial":2,"point":"monster_studies"}
	view._process(0)
	check(view.station_panel.visible and not view.station_controls.apply.disabled,"a stored trophy enables the Offering Altar view")
	view.station_controls.apply.pressed.emit()
	check(requests.size()==2 and requests[1].data.action=="care_offer_"+str(Parts.HOOK) and frames.station.counts[Parts.HOOK]==1,"station UI requests an offering without spending its displayed inventory")
	ui.close_panels()
	var bed:Dictionary={"slot":0,"species":0,"cycle":"crop-a","revision":3,"stage":2,"opportunity":"patient_bud","compatible":true,"available":true,"preserved":false,
		"remaining":30.0,"growth_rate":1.0,"garden_remaining":30.0,"wild_remaining":15.0,"chance":.1,"base_chance":.1,"preserve_chance":.25,"extra_seconds":15.0,
		"watered":false,"spring_ready":true,"water_available":true,"flower_enabled":true}
	frames.crop.position=stage.bed_position(0);frames.crop.nearby_plot=0;frames.crop.data.beds=[bed];frames.crop.data.spring_water=true;frames.crop.data.focus={"serial":1,"slot":0}
	var crop=view.get_node("Crops");crop._process(0)
	check(crop.panel.visible and crop.title.text.contains("BED 1") and crop.outcome.text.contains("30s"),"crop inspector resolves its content labels and supplied growth times")
	crop.preserve.pressed.emit();crop.preserve.pressed.emit()
	check(requests.size()==3 and payload(2).cycle=="crop-a" and payload(2).revision==3 and payload(2).action=="preserve_bud","crop choice captures its cycle, stage and revision and refuses a repeated pending click")
	ui.close_panels();crop.context_prompt()
	check(crop.quick_water.visible,"watering control follows the nearby eligible crop and carried water facts")
	crop.quick_water.pressed.emit()
	check(payload(3).action=="water_crop" and payload(3).revision==3,"quick watering emits an ordinary Garden request")
	crop.flower_shortcut()
	check(payload(4).action=="flower_crop" and frames.crop.data.beds[0].stage==2,"the flower shortcut requests the real crop without changing its displayed maturity")
	frames.crop.context="guest:2:new";frames.crop.data.focus={};crop._process(0)
	check(crop.waiting_until==0 and crop.last_bed.is_empty() and not crop.panel.visible,"a new crop context retires pending inspector state")
	frames["return"]={"context":"guest:2:b","wild":false,"motion":false,"diagnostic_source":"host_snapshot","pending":[],"data":{"version":1,"catalog":Returns.signature,"entries":[Returns.DEFINITIONS[0].duplicate(true)]}}
	var discoveries=view.get_node("ReturnLife");discoveries._process(.2)
	check(discoveries.traces.lantern_homecoming.visible and discoveries.heart.visible,"committed discoveries produce only their existing visual traces")
	frames.ambience={"wild":false,"motion":true,"water_position":Vector3(6.6,0,-.15),"position":Vector3(6.6,0,-.15),"development":false,"data":{"available":["spring_water"],"returns":{}}}
	var ambience=view.get_node("Ambience");ambience._process(.2)
	check(ambience.colonies.sheltered_spring.visible and ambience.colonies.sheltered_spring.multimesh.instance_count==8,"ambience uses the bounded authored local colony")
	frames.ambience.motion=false;ambience._process(.2)
	check(not ambience.colonies.sheltered_spring.visible,"ambient-motion settings hide local life without affecting gameplay")
	view.free();stage.free();ui.free()
	if not failed:print("PASS: standalone Garden views, detached frames, observation and crop identities, station intentions, context cleanup and cosmetic return/ambience")
	quit(1 if failed else 0)
