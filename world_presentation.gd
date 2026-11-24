extends RefCounted
## Ordered presentation only. No Game, actor, gameplay owner or mutable profile
## enters this interface. Specialized renderers retain their existing caches.
const Glass = preload("res://glasscap_visuals.gd")
const Attacks = preload("res://enemy_attack.gd")
const Exploration = preload("res://exploration.gd")
var _stage: Node3D
var _deaths: Node3D
var _combat: Node3D
var _map: Node
var _audio: Node
var _soundscape: Node

func _init(stage: Node3D, deaths: Node3D, combat: Node3D, map: Node, audio: Node, soundscape: Node) -> void:
	_stage=stage;_deaths=deaths;_combat=combat;_map=map;_audio=audio;_soundscape=soundscape

func prepare(warnings: Array) -> void:
	Glass.prepare(_stage,warnings)
	_stage.set_meta("enemy_attack_poses",Attacks.poses(warnings))

## Called after avatar/terrain drawing, so map and sight use the current scene.
## Advance is the caller's captured gate point, retaining floor-transition order.
func present_effects(frame: Dictionary) -> void:
	var floor_key := "%d:%d:%d"%[frame.site,frame.floor,frame.seed]
	var key := floor_key+":"+str(frame.wild)
	_deaths.sync(frame.deaths,key,frame.observer)
	_audio.sync(frame.events,key,frame.wild,frame.observer,frame.local_id,Time.get_ticks_msec())
	_combat.sync(frame.events if frame.wild else [],frame.warnings,key,frame.observer)
	_stage.attack_ring.visible=false
	for ring in _stage.support_rings: ring.visible=false
	_map.thief_routes=frame.thief_routes
	_map.update_floor(_stage.visual_field,floor_key,frame.observer,_stage.camera,frame.wild,
		frame.cache_available,frame.overlay_open,frame.graft_open,frame.ground_items)
	_stage.apply_exploration_sight(frame.observer,frame.wild,Exploration.SIGHT,
		_map.seen(frame.advance) if is_instance_valid(_stage.experimental_exit) else true)
	Glass.sync(_stage,frame.observer,Exploration.SIGHT)

## Keep plots -> Heart -> mix -> Garden order. This snapshot is presentation
## data; actual research/crop progression and sound/effect receipts stay owned.
func present_garden(delta: float, frame: Dictionary) -> void:
	_stage.update_plots(frame.plots)
	_stage.update_heart_progress(frame.heart)
	_soundscape.update_mix(delta,frame.wild,frame.site,frame.floor,frame.boss,frame.observer,_stage.heart_unlocked)
	_stage.update_garden(frame.knowledge,frame.technologies+int(frame.heart.get("clearing",0)))

func map_expanded() -> bool: return bool(_map.expanded)
func sight_radius() -> float: return Exploration.SIGHT
