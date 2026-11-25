extends RefCounted
## Integration port only. Garden services retain authorization and state.
## Views receive detached facts; no actor or mutable owner crosses this API.
const Interactions = preload("res://garden_interaction_service.gd")
const Returns = preload("res://garden_return_service.gd")
const Growth = preload("res://garden_growth_service.gd")
const Participation = preload("res://expedition_participation.gd")
var _world: WeakRef

func _init(world: Node) -> void:
	_world=weakref(world)

func bind(view: Node) -> void:
	view.refresh_requested.connect(func(kind: String, selection: Dictionary):
		view.present_feature(kind,frame(kind,selection)))
	view.interfaces_requested.connect(func():view.capture_interfaces(interface_layers()))
	view.requested.connect(request)

func _current_world() -> Node:
	var world: Node=_world.get_ref()
	return world if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() else null

func frame(kind: String, selection: Dictionary={}) -> Dictionary:
	var world:=_current_world()
	if world==null or not is_instance_valid(world.stage):return {}
	var peer: int=world.local_player_id()
	var actor: Dictionary=world.players.get(peer,{})
	match kind:
		"interaction":return _interaction_frame(world,peer,actor)
		"crop":return _crop_frame(world,peer,actor)
		"station":return _station_frame(world,actor,str(selection.get("station","")))
		"return":return _return_frame(world,peer,actor,str(selection.get("context","")))
		"ambience":return _ambience_frame(world,peer,actor)
		"cinematic":return _cinematic_frame(world,peer,actor)
	return {}

func _interaction_frame(world: Node, peer: int, actor: Dictionary) -> Dictionary:
	var data = world.garden_commands.observation_projection(peer)
	data.returns=world.garden_commands.return_projection(peer)
	data.cultivation={"spring_water":world.cultivation.water_carried(peer)}
	var near_stations: Array[String]=[]
	if not actor.is_empty():
		for station in world.Stage.HEART_STATIONS:
			if world.at_garden_station(actor,station):near_stations.append(station)
	var positions: Dictionary={}
	for point in Interactions.Catalog.POINTS:
		positions[point.id]=world.garden_commands.point_position(point,actor.get("pos",Vector3.INF)) if point.id!="spring_water" or data.get("available",[]).has(point.id) else point.position
	var garden=world.stage.experimental_garden
	return {"data":data.duplicate(true),"present":not actor.is_empty(),
		"structure_revision":maxi(garden.layout_revision,garden.remote_revision) if garden!=null else -1,
		"position":actor.get("pos",Vector3.INF),"wild":Participation.is_wild(actor),
		"context":str([world.network_session.role(),peer,data.get("epoch","")]),
		"nearest":world.garden_commands.nearest(peer,data),
		"nearest_station":world.garden_commands.station_near(peer) if not actor.is_empty() else "",
		"near_stations":near_stations,"point_positions":positions,
		"development":world.stage.experimental_garden!=null,
		"motion":world.app_settings.values.get("ambient_motion",true)}

func _crop_frame(world: Node, peer: int, actor: Dictionary) -> Dictionary:
	var data:Dictionary=world.cultivation.projection(peer)
	return {"data":data.duplicate(true),"present":not actor.is_empty(),
		"position":actor.get("pos",Vector3.INF),"wild":Participation.is_wild(actor),
		"context":str([world.network_session.role(),peer,world.garden_commands.projection_epoch(peer)]),
		"nearby_plot":world.nearby_plot(actor.get("pos",Vector3.INF)),
		"development":world.stage.experimental_garden!=null,
		"motion":world.app_settings.values.get("ambient_motion",true)}

func _station_frame(world: Node, actor: Dictionary, station: String) -> Dictionary:
	if actor.is_empty():return {}
	var result: Dictionary={"present":true,"status":world.status}
	if station=="living_archive":
		result.decoded=world.heart_state().get("decoded",[false,false,false]).duplicate()
		result.campaign=(world.campaign_snapshot() if world.multiplayer.is_server() else world.guest_replication.campaign()).duplicate()
		return result
	if station=="monster_studies": result.studied=world.heart_state().get("offered",[]).duplicate()
	var garden: Array=world.garden_snapshot() if world.multiplayer.is_server() else world.guest_replication.garden_progress()
	if garden.size()<=13:return result
	result.counts=(world.stored_counts(actor) if world.multiplayer.is_server() else actor.get("stored_parts",world.Parts.empty_counts())).duplicate()
	result.discoveries=garden[13].duplicate()
	var costs: Array[int]=[]
	for species in world.Seeds.NAMES.size():costs.append(world.reclamation_cost(species))
	result.reclamation_costs=costs
	return result

func _return_frame(world: Node, peer: int, actor: Dictionary, parent_context: String) -> Dictionary:
	return {"data":world.garden_commands.return_projection(peer).duplicate(true),
		"pending":Growth.projection(world,peer).get("pending",[]).duplicate(true),
		"context":str([world.network_session.role(),peer,parent_context]),
		"wild":Participation.is_wild(actor),"motion":world.app_settings.values.get("ambient_motion",true),
		"diagnostic_source":"host_world" if world.multiplayer.is_server() else "host_snapshot"}

func _ambience_frame(world: Node, peer: int, actor: Dictionary) -> Dictionary:
	var data = world.garden_commands.observation_projection(peer)
	data.returns=world.garden_commands.return_projection(peer)
	return {"data":data.duplicate(true),
		"water_position":preload("res://garden_water.gd").anchor(world.stage),"position":actor.get("pos",Vector3.INF),
		"wild":Participation.is_wild(actor),"development":world.stage.experimental_garden!=null,
		"motion":world.app_settings.values.get("ambient_motion",true)}

func _cinematic_frame(world: Node, peer: int, actor: Dictionary) -> Dictionary:
	var data:=Growth.projection(world,peer)
	var pending: Array=data.get("pending",[])
	var expansion: bool=not pending.is_empty() and pending[0].get("kind")=="expansion"
	var garden=world.stage.experimental_garden
	var building_menu_open: bool=garden!=null and (garden.development_dialog.visible or garden.offering_dialog.visible)
	return {"context":str(world.network_session.role()=="Guest")+":"+str(peer),
		"pending":pending.duplicate(true),"player_present":not actor.is_empty(),
		"player_position":actor.get("pos",world.Stage.SPAWN),"blocked":world.persistence_session.is_blocked(),
		"safe":not Participation.is_wild(actor) and data.get("ready",false) and world.network_session.role()!="Connecting",
		"skip_playback":(world.has_meta(&"experimental_terrain") and not expansion) or not world.app_settings.values.get("garden_cinematics",true) or not world.app_settings.values.get("ambient_motion",true),
		"can_start":not building_menu_open and not world.ui.is_overlay_open() and world.settings_dialog!=null and not world.settings_dialog.visible}

## Presentation Nodes are separate from the detached data frames.
func interface_layers() -> Array:
	var world:=_current_world()
	return world.get_children().filter(func(child):return child is CanvasLayer) if world!=null else []

func request(command: String, data: Dictionary) -> void:
	var world:=_current_world()
	if world==null:return
	match command:
		"garden_action":world.send_garden_action(str(data.action))
		"research_audio":preload("res://event_audio.gd").play_research(world,data)
