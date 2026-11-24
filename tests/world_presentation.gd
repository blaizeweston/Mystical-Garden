extends SceneTree
const View=preload("res://world_presentation.gd")
const Exploration=preload("res://exploration.gd")
var failed:=false
class StageView extends Node3D:
	var camera:=Camera3D.new()
	var attack_ring:=Node3D.new()
	var support_rings:Array[Node3D]=[Node3D.new()]
	var experimental_exit:Node3D=Node3D.new()
	var visual_field:=RefCounted.new()
	var heart_unlocked:Array=[]
	var calls:Array=[]
	var sight:Array=[]
	func _init():
		add_child(camera);add_child(attack_ring);add_child(support_rings[0]);add_child(experimental_exit)
	func apply_exploration_sight(at:Vector3,wild:bool,radius:float,gate_seen:bool):
		sight=[at,wild,radius,gate_seen];calls.append("sight")
	func update_plots(_plots:Array):calls.append("plots")
	func update_heart_progress(heart:Dictionary):heart_unlocked=heart.unlocked.duplicate();calls.append("heart")
	func update_garden(knowledge:int,technologies:int):calls.append(["garden",knowledge,technologies])
class DeathView extends Node3D:
	var calls:Array=[]
	var received:Array=[]
	func sync(events:Array,key:String,observer:Vector3):received=[events.duplicate(true),key,observer];calls.append("deaths")
class CombatView extends Node3D:
	var calls:Array=[]
	var received:Array=[]
	func sync(events:Array,warnings:Array,key:String,observer:Vector3):received=[events.duplicate(true),warnings.duplicate(true),key,observer];calls.append("combat")
class AudioView extends Node:
	var calls:Array=[]
	var received:Array=[]
	func sync(events:Array,key:String,wild:bool,observer:Vector3,peer:int,now:int):received=[events.duplicate(true),key,wild,observer,peer,now];calls.append("audio")
class MapView extends Node:
	var calls:Array=[]
	var expanded:=false
	var thief_routes:Array=[]
	var received:Array=[]
	var looked_at:=Vector3.INF
	func update_floor(field:RefCounted,key:String,observer:Vector3,camera:Camera3D,wild:bool,cache_available:bool,overlay_open:bool,graft_open:bool,items:Array):
		received=[field,key,observer,camera,wild,cache_available,overlay_open,graft_open,items.duplicate(true)];calls.append("map")
	func seen(at:Vector3)->bool:looked_at=at;return false
class SoundView extends Node:
	var calls:Array=[]
	var received:Array=[]
	func update_mix(delta:float,wild:bool,site:int,floor_number:int,boss:bool,observer:Vector3,unlocked:Array):
		received=[delta,wild,site,floor_number,boss,observer,unlocked.duplicate(true)];calls.append("mix")
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failed=true;printerr("FAIL world presentation: ",message)
func run():
	var calls:Array=[]
	var stage:=StageView.new();var deaths:=DeathView.new();var combat:=CombatView.new();var map:=MapView.new();var audio:=AudioView.new();var sound:=SoundView.new()
	for node in [stage,deaths,combat,map,audio,sound]:node.calls=calls;root.add_child(node)
	var view:=View.new(stage,deaths,combat,map,audio,sound)
	view.prepare([])
	check(stage.has_meta("enemy_attack_poses") and stage.has_meta("glasscap_positions"),"warning preparation targets scene metadata without Game")
	var frame:Dictionary={"site":1,"floor":4,"seed":99,"wild":true,"local_id":2,"observer":Vector3(2,0,3),"advance":Vector3(9,0,8),
		"deaths":[{"id":1}],"events":[{"id":7,"kind":"audio"}],"warnings":[],"thief_routes":[{"id":3,"pos":Vector3.ONE}],
		"cache_available":true,"overlay_open":false,"graft_open":true,"ground_items":[{"id":"drop-1"}]}
	var before:=frame.duplicate(true)
	view.present_effects(frame)
	check(calls==["deaths","audio","combat","map","sight"],"death, audio, combat, map and sight retain their order")
	check(deaths.received[1]=="1:4:99:true" and audio.received[1]==deaths.received[1] and combat.received[2]==deaths.received[1],"all transient renderers share the existing floor/participation key")
	check(map.received[1]=="1:4:99" and map.looked_at==frame.advance and not stage.sight[3],"map reset and gate visibility use the correct captured floor identity and point")
	check(not stage.attack_ring.visible and not stage.support_rings[0].visible and map.thief_routes.size()==1,"legacy rings stay hidden and chase routes reach the map")
	check(audio.received[4]==2 and audio.received[5]>0 and combat.received[0]==frame.events and map.received[8]==frame.ground_items,"audio recipient/time and event/item projections reach their existing consumers")
	check(frame==before,"presentation never mutates input facts")
	frame.wild=false;frame.deaths=[];calls.clear();view.present_effects(frame)
	check(combat.received[0].is_empty() and audio.received[0]==frame.events and deaths.received[1]=="1:4:99:false","Garden audio remains available while combat geometry is suppressed")
	stage.experimental_exit.free();calls.clear();view.present_effects(frame)
	check(stage.sight[3],"a scene without an experimental exit retains its previous sight fallback")
	calls.clear()
	view.present_garden(.016,{"plots":[],"heart":{"unlocked":["heart","irrigation"],"clearing":2},"wild":false,"site":1,"floor":4,"boss":false,"observer":Vector3.ZERO,"knowledge":30,"technologies":3})
	check(calls==["plots","heart","mix",["garden",30,5]] and sound.received[6]==["heart","irrigation"],"plots, Heart, sound and Garden retain order and the freshly displayed research state")
	map.expanded=true
	check(view.map_expanded() and view.sight_radius()==Exploration.SIGHT,"public inspection returns scalar presentation values")
	for node in [stage,deaths,combat,map,audio,sound]:node.free()
	if not failed:print("PASS: independent world presentation order, keys, map/sight, audio context, detached facts and Garden synchronization")
	quit(1 if failed else 0)
