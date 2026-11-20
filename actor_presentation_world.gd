extends RefCounted
## Read-only integration port for avatars, spectator UI and ground-item visuals.
## Gameplay owners stay authoritative. Only detached visual facts leave this port.
const Participation=preload("res://expedition_participation.gd")
const Lifecycle=preload("res://player_lifecycle.gd")
const Vitals=preload("res://player_vitals.gd")
const Session=preload("res://network_session.gd")
const Life=preload("res://expedition_life.gd")
const WeaponActions=preload("res://player_weapon_actions.gd")
const WeaponMotion=preload("res://weapon_motion.gd")
var _world: WeakRef

func _init(world: Node) -> void:
	_world=weakref(world)

func _current_world() -> Node:
	var world: Node=_world.get_ref()
	return world if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() else null

func people(local_id: int, now: int) -> Dictionary:
	var world:=_current_world()
	if world==null:return {}
	var source: Dictionary=world.players
	if not world.multiplayer.is_server():
		source=world.net_motion.render_players(source,local_id,now)
		source=preload("res://avatar_motion_view.gd").people(source,local_id,world.mouse_controls.local_aim)
	var result: Dictionary={}
	for peer in source:result[peer]=_avatar(world,source[peer],now)
	return result

func avatar(peer: int, now: int) -> Dictionary:
	var world:=_current_world()
	if world==null or not world.players.has(peer):return {}
	return _avatar(world,world.players[peer],now)

func _avatar(world: Node, actor: Dictionary, now: int) -> Dictionary:
	var wild:=Participation.is_wild(actor)
	var pose:=int(actor.get("pose",0))
	var yaw:=deg_to_rad(float(pose & 511))
	var swing:=float(pose >> 9)/24.0
	if actor.has("facing"):
		var facing: Vector3=actor.facing
		yaw=atan2(facing.x,facing.z)
		if actor.has(WeaponActions.STATE):swing=actor[WeaponActions.STATE].swing_fraction(now)
	var animation: Dictionary=actor.get("attack_anim",{}).duplicate(true)
	if actor.has(WeaponActions.STATE):animation=world.attack_animation_snapshot(actor,now)
	var fallen:=Lifecycle.fallen(actor)
	if fallen:animation.active=false
	var effect: Dictionary={}
	for field in ["seq","event_driven","pos","radius","color"]:
		if actor.get("skill_fx",{}).has(field):effect[field]=actor.skill_fx[field]
	var result: Dictionary={"pos":actor.get("pos",Vector3.ZERO),"velocity":actor.get("velocity",Vector3.INF),
		"name":str(actor.get("display_name",actor.get("character",{}).get("name","Wanderer"))),
		"appearance":Array(actor.get("character",{}).get("appearance",actor.get("appearance",[0,0,0,0,0]))).duplicate(),
		"party_slot":Session.slot_for(actor,0),"wild":wild,"fallen":fallen,"yaw":yaw,"swing":swing,
		"attack_anim":animation,"frame":int(actor.get("frame",0)),"weapon_kind":int(actor.get("weapon_kind",0)),
		"weapon_form":WeaponMotion.form(actor),"core_part":int(actor.get("core_part",actor.get("weapon",0) if wild else actor.get("prepared",0))),
		"skill_fx":effect.duplicate(true),"cache_claimed":bool(actor.get("cache_claimed",false))}
	if actor.has("aim_direction"):result.aim_direction=actor.aim_direction
	return result

func position(peer: int, fallback: Vector3=Vector3.ZERO) -> Vector3:
	var world:=_current_world()
	return world.players.get(peer,{}).get("pos",fallback) if world!=null else fallback

func spectator_frame(local_id: int) -> Dictionary:
	var world:=_current_world()
	if world==null:return {}
	var actor: Dictionary=world.players.get(local_id,{})
	var living: Array=[]
	for peer in Life.living_ids(world):
		var person: Dictionary=world.players[peer]
		living.append({"id":peer,"name":str(person.get("character",{}).get("name",person.get("display_name","ally"))),
			"hp":Vitals.current_hp(person),"max_hp":Vitals.maximum_hp(person)})
	return {"fallen":Participation.is_wild(actor) and Lifecycle.fallen(actor),"living":living,"revive_cost":Life.Preview.revive_cost()}

func drop_frame(selected_peer: int, sight_radius: float) -> Dictionary:
	var world:=_current_world()
	if world==null:return {}
	var local_id: int=world.local_player_id()
	var actor: Dictionary=world.players.get(local_id,{})
	if actor.is_empty():return {}
	var drops: Array=world.inventory_floor_snapshot(actor) if world.multiplayer.is_server() else actor.get("ground_items",[])
	var observer: int=selected_peer if Lifecycle.fallen(actor) and selected_peer!=0 else local_id
	return {"wild":Participation.is_wild(actor),"drops":drops.duplicate(true),
		"observer":position(observer,actor.pos),"sight_radius":sight_radius}
